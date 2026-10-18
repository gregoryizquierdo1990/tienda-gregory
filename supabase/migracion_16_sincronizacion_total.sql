-- ==============================================================================
-- MIGRACIÓN 16: SINCRONIZACIÓN TOTAL Y COHERENCIA OPERATIVA DE DATOS
-- ==============================================================================
-- 1. Precios, Descuentos, Pago Mixto y Cuotas (orders_guard y create_order)
-- 2. Entregas a Crédito y Control de Límite de Crédito (deliver_order_credit)
-- 3. Cuadre Contable en Finanzas, Cuotas e Inventario (finanzas, approve_installment)
-- 4. Automatización de Códigos CLT ↔ RVD y Provisión Reactiva de Tarjetas Zeny
-- 5. Coherencia entre mother_accounts, profiles_inventory y purchases
-- 6. Soporte Multitenant Completo para Franquicias (franchise_id)
-- 7. Registro Idempotente en Publicación Supabase Realtime
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- SECCIÓN 1: SOPORTE DE FRANQUICIAS EN TABLAS TRANSACCIONALES (franchise_id)
-- ------------------------------------------------------------------------------
alter table public.orders add column if not exists franchise_id uuid references public.franchises(id) on delete set null;
alter table public.customers add column if not exists franchise_id uuid references public.franchises(id) on delete set null;
alter table public.mother_accounts add column if not exists franchise_id uuid references public.franchises(id) on delete set null;
alter table public.profiles_inventory add column if not exists franchise_id uuid references public.franchises(id) on delete set null;
alter table public.payment_methods add column if not exists franchise_id uuid references public.franchises(id) on delete set null;
alter table public.invoices add column if not exists franchise_id uuid references public.franchises(id) on delete set null;

create index if not exists idx_orders_franchise on public.orders(franchise_id);
create index if not exists idx_customers_franchise on public.customers(franchise_id);
create index if not exists idx_profiles_franchise on public.profiles_inventory(franchise_id);
create index if not exists idx_payment_methods_franchise on public.payment_methods(franchise_id);

-- ------------------------------------------------------------------------------
-- SECCIÓN 2: CONTROL DE INVENTARIO Y CUENTAS MADRE ACTIVAS (stock)
-- ------------------------------------------------------------------------------
-- Solo contabiliza y ofrece perfiles de cuentas madre activas y vigentes
drop function if exists public.stock();
create or replace function public.stock()
returns table(product_id uuid, disponibles bigint)
language plpgsql security definer set search_path = public as $$
begin
  perform release_expired();
  return query
  select pi.product_id, count(*)
  from public.profiles_inventory pi
  join public.mother_accounts m on m.id = pi.mother_id
  where pi.estado = 'disponible'
    and pi.product_id is not null
    and coalesce(m.activa, true) is true
    and (m.vence is null or m.vence >= current_date)
  group by pi.product_id;
end $$;

grant execute on function public.stock() to anon, authenticated;

-- ------------------------------------------------------------------------------
-- SECCIÓN 3: SINCRONIZACIÓN DE COMPRAS DESDE CUENTAS MADRE (purchase_from_mother)
-- ------------------------------------------------------------------------------
create or replace function public.purchase_from_mother()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.costo_usd, 0) > 0 then
    if exists (select 1 from public.purchases where mother_id = new.id) then
      update public.purchases
      set monto_usd = new.costo_usd,
          proveedor = coalesce(new.proveedor, proveedor),
          plataforma = coalesce(new.plataforma, plataforma),
          fecha = coalesce(fecha, current_date)
      where mother_id = new.id;
    else
      insert into public.purchases(proveedor, plataforma, mother_id, monto_usd, notas, fecha)
      values (new.proveedor, new.plataforma, new.id, new.costo_usd, 'Automático: alta/sincronización cuenta madre', current_date);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists t_purchase_mother on public.mother_accounts;
create trigger t_purchase_mother
after insert or update of costo_usd, proveedor, plataforma on public.mother_accounts
for each row execute function public.purchase_from_mother();

-- ------------------------------------------------------------------------------
-- SECCIÓN 4: AUTOMATIZACIÓN DE ROLES CLT ↔ RVD Y TARJETAS ZENY REACTIVAS
-- ------------------------------------------------------------------------------
create or replace function public.trg_sync_customer_role()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.es_revendedor is true then
    if new.codigo_identificacion is null or new.codigo_identificacion = '' or new.codigo_identificacion like 'CLT:%' then
      new.codigo_identificacion := public.get_next_customer_code(true);
    end if;
    if new.limite_credito is null or new.limite_credito = 0 then
      new.limite_credito := 30.00;
    end if;
    if new.nivel_credito is null or new.nivel_credito = '' then
      new.nivel_credito := 'Bronce';
    end if;
  elsif new.es_revendedor is false then
    if new.codigo_identificacion is null or new.codigo_identificacion = '' or new.codigo_identificacion like 'RVD:%' then
      new.codigo_identificacion := public.get_next_customer_code(false);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists t_sync_customer_role on public.customers;
create trigger t_sync_customer_role
before insert or update of es_revendedor, codigo_identificacion on public.customers
for each row execute function public.trg_sync_customer_role();

create or replace function public.trg_auto_provision_zeny_card()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.es_revendedor is true then
    if not exists (select 1 from public.zeny_cards where customer_id = new.id) then
      insert into public.zeny_cards(
        customer_id,
        numero_tarjeta,
        nombre_titular,
        codigo_activacion,
        fecha_vencimiento,
        estado,
        descuento_porcentaje
      ) values (
        new.id,
        '4242 ' || lpad((floor(random() * 9000) + 1000)::int::text, 4, '0') || ' ' || lpad((floor(random() * 9000) + 1000)::int::text, 4, '0') || ' ' || lpad((floor(random() * 9000) + 1000)::int::text, 4, '0'),
        upper(coalesce(new.nombre, 'Revendedor Oficial')),
        lpad((floor(random() * 900) + 100)::int::text, 3, '0'),
        to_char(now() + interval '365 days', 'MM/YY'),
        'activa',
        5.00
      ) on conflict (customer_id) do update set estado = 'activa';
    else
      update public.zeny_cards set estado = 'activa' where customer_id = new.id and estado <> 'activa';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists t_auto_provision_zeny_card on public.customers;
create trigger t_auto_provision_zeny_card
after insert or update of es_revendedor on public.customers
for each row execute function public.trg_auto_provision_zeny_card();

-- ------------------------------------------------------------------------------
-- SECCIÓN 5: REGLAS DE PRECIO Y PROTECCIÓN EN orders_guard
-- ------------------------------------------------------------------------------
create or replace function public.orders_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  pr public.products;
  r numeric;
  pm public.payment_methods;
  eff_price numeric;
  is_res boolean := false;
  v_card_desc numeric := 0;
begin
  if is_admin() or current_setting('app.internal', true) = '1' then
    return new;
  end if;

  select * into pr from public.products where id = new.product_id and activo;
  if not found then
    raise exception 'Producto no disponible o inactivo';
  end if;

  select coalesce(es_revendedor, false) into is_res from public.customers where id = auth.uid();
  if new.metodo_id is not null then
    select * into pm from public.payment_methods where id = new.metodo_id;
  end if;

  -- 1. Jerarquía de precios: Revendedor oficial prevalece sobre tarifa minorista Binance
  if is_res and not coalesce(pr.es_exclusivo_central, false) and pr.precio_revendedor_usd is not null and pr.precio_revendedor_usd > 0 then
    eff_price := pr.precio_revendedor_usd;
  elsif (pm.tipo = 'binance' or lower(coalesce(pm.nombre,'')) like '%binance%') and pr.precio_binance_usd is not null and pr.precio_binance_usd > 0 then
    eff_price := pr.precio_binance_usd;
  else
    eff_price := pr.precio_usd;
  end if;

  -- 2. Descuento oficial de Tarjeta Zeny (5%)
  select descuento_porcentaje into v_card_desc
  from public.zeny_cards
  where customer_id = auth.uid() and estado = 'activa'
  limit 1;

  if v_card_desc is not null and v_card_desc > 0 then
    eff_price := round(eff_price * (1.0 - (v_card_desc / 100.0)), 2);
  end if;

  select bs_por_usd into r from public.exchange_rates order by fecha desc limit 1;
  new.customer_id := auth.uid();

  -- Si new.total_usd viene con monto válido (ej: cuota inicial o zeny descontado), no sobreescribir ciegamente
  if new.total_usd is null or new.total_usd <= 0 or new.total_usd > eff_price then
    new.total_usd := eff_price;
  end if;

  new.tasa_bs := r;
  new.total_bs := round(new.total_usd * coalesce(r, 0), 2);
  new.estado := 'pendiente';
  new.profile_id := null;
  new.inicia := null;
  new.vence := null;
  new.proximo_pago := null;
  new.gcal_event_id := null;
  return new;
end $$;

-- ------------------------------------------------------------------------------
-- SECCIÓN 6: PROCESO MAESTRO DE CREACIÓN DE PEDIDOS (create_order)
-- ------------------------------------------------------------------------------
drop function if exists public.create_order(uuid, uuid, text);
drop function if exists public.create_order(uuid, uuid, text, numeric);
drop function if exists public.create_order(uuid, uuid, text, numeric, jsonb);
drop function if exists public.create_order(uuid, uuid, text, numeric, jsonb, boolean);
drop function if exists public.create_order(uuid, uuid, text, numeric, jsonb, boolean, uuid);

create or replace function public.create_order(
  p_product uuid,
  p_metodo uuid default null,
  p_ref text default null,
  p_zeny numeric default 0,
  p_datos_recarga jsonb default '{}',
  p_es_cuotas boolean default false,
  p_franchise_id uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  pr public.products;
  pf uuid;
  o uuid;
  rate numeric;
  bal numeric;
  holds numeric;
  z numeric := coalesce(p_zeny, 0);
  pm public.payment_methods;
  eff_price numeric;
  is_res boolean := false;
  v_card_desc numeric := 0;
  v_limite numeric := 30.00;
  v_credito_usado numeric := 0;
  v_cuota_1 numeric;
  v_cuota_2 numeric;
  v_order_total numeric;
  v_fran_estado text;
begin
  if auth.uid() is null then
    raise exception 'Inicia sesión primero';
  end if;

  perform release_expired();

  -- Validación de Franquicia y Kill-Switch
  if p_franchise_id is not null then
    select estado into v_fran_estado from public.franchises where id = p_franchise_id;
    if not found then
      raise exception 'Franquicia no encontrada';
    end if;
    if v_fran_estado in ('suspendido_fraude', 'suspendido_mora') then
      raise exception 'Portal de franquicia suspendido temporalmente por la administración Central';
    end if;
  end if;

  select * into pr from public.products where id = p_product and activo;
  if not found then
    raise exception 'Producto no disponible o inactivo';
  end if;

  if p_franchise_id is not null and (pr.es_exclusivo_central or pr.tipo in ('gaming', 'recarga_telefonica')) then
    raise exception 'Este producto es exclusivo de la tienda central';
  end if;

  select coalesce(es_revendedor, false), coalesce(limite_credito, 30.00)
    into is_res, v_limite
  from public.customers where id = auth.uid();

  if p_metodo is not null then
    select * into pm from public.payment_methods where id = p_metodo;
  end if;

  -- 1. Determinar precio base (Revendedor prevalece sobre Binance)
  if is_res and not coalesce(pr.es_exclusivo_central, false) and pr.precio_revendedor_usd is not null and pr.precio_revendedor_usd > 0 then
    eff_price := pr.precio_revendedor_usd;
  elsif (pm.tipo = 'binance' or lower(coalesce(pm.nombre,'')) like '%binance%') and pr.precio_binance_usd is not null and pr.precio_binance_usd > 0 then
    eff_price := pr.precio_binance_usd;
  else
    eff_price := pr.precio_usd;
  end if;

  -- 2. Descuento oficial de Tarjeta Zeny
  select descuento_porcentaje into v_card_desc
  from public.zeny_cards
  where customer_id = auth.uid() and estado = 'activa'
  limit 1;

  if v_card_desc is not null and v_card_desc > 0 then
    eff_price := round(eff_price * (1.0 - (v_card_desc / 100.0)), 2);
  end if;

  -- 3. Financiamiento en Cuotas (BNPL)
  if p_es_cuotas then
    if not pr.permite_cuotas then
      raise exception 'Este servicio no permite financiamiento en cuotas';
    end if;

    if exists (
      select 1 from public.installments
      where customer_id = auth.uid()
        and (estado = 'vencida' or (estado = 'pendiente' and fecha_vencimiento < current_date))
    ) then
      raise exception 'Tienes cuotas vencidas pendientes. Debes ponerte al día para solicitar un nuevo financiamiento.';
    end if;

    select coalesce(sum(monto_usd), 0) into v_credito_usado
    from public.installments
    where customer_id = auth.uid() and estado in ('pendiente', 'en_revision');

    v_cuota_1 := round(eff_price * 0.50, 2);
    v_cuota_2 := eff_price - v_cuota_1;

    if (v_credito_usado + v_cuota_2) > v_limite then
      raise exception 'El monto a financiar ($%) excede tu límite de crédito disponible ($%)',
        v_cuota_2, greatest(0, v_limite - v_credito_usado);
    end if;

    v_order_total := v_cuota_1;
  else
    v_order_total := eff_price;
  end if;

  -- 4. Validar saldo Zeny aplicado
  if z < 0 or z > v_order_total then
    raise exception 'Monto Zeny inválido';
  end if;

  if z < v_order_total and p_metodo is null then
    raise exception 'Elige un método de pago para el monto restante';
  end if;

  if z > 0 then
    select zeny_balance into bal from public.customers where id = auth.uid() for update;
    select coalesce(sum(-monto), 0) into holds
    from public.zeny_ledger
    where customer_id = auth.uid() and tipo = 'compra' and estado = 'pendiente';

    if z > coalesce(bal, 0) - holds then
      raise exception 'Saldo Zeny insuficiente';
    end if;
  end if;

  -- 5. Asignar perfil con cuenta madre activa y no vencida
  if pr.tipo not in ('servicio', 'gaming', 'recarga_telefonica') then
    -- Priorizar stock de franquicia si la orden es de una franquicia
    if p_franchise_id is not null then
      select pi.id into pf
      from public.profiles_inventory pi
      join public.mother_accounts m on m.id = pi.mother_id
      where pi.product_id = p_product
        and pi.estado = 'disponible'
        and pi.franchise_id = p_franchise_id
        and coalesce(m.activa, true) is true
        and (m.vence is null or m.vence >= current_date)
      order by pi.id limit 1 for update skip locked;
    end if;

    -- Si no hay stock propio de franquicia o es compra central, tomar de stock central
    if pf is null then
      select pi.id into pf
      from public.profiles_inventory pi
      join public.mother_accounts m on m.id = pi.mother_id
      where pi.product_id = p_product
        and pi.estado = 'disponible'
        and (pi.franchise_id is null or p_franchise_id is null)
        and coalesce(m.activa, true) is true
        and (m.vence is null or m.vence >= current_date)
      order by pi.id limit 1 for update skip locked;
    end if;

    if pf is null then
      raise exception 'Agotado (sin inventario disponible con cuenta madre activa)';
    end if;

    update public.profiles_inventory set estado = 'reservado' where id = pf;
  end if;

  select bs_por_usd into rate from public.exchange_rates order by fecha desc limit 1;
  perform set_config('app.internal', '1', true);

  -- 6. Insertar el Pedido
  insert into public.orders(
    customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs,
    metodo_id, referencia, estado, zeny_aplicado, datos_recarga, franchise_id
  )
  values (
    auth.uid(), p_product, pf, v_order_total, rate, round(v_order_total * coalesce(rate, 0), 2),
    p_metodo, left(coalesce(p_ref,''), 120), 'pendiente', z, coalesce(p_datos_recarga, '{}'::jsonb), p_franchise_id
  )
  returning id into o;

  -- 7. Retención Zeny si aplica
  if z > 0 then
    insert into public.zeny_ledger(customer_id, tipo, monto, referencia, estado, order_id)
    values (auth.uid(), 'compra', -z, 'Retención pedido ' || left(o::text, 8), 'pendiente', o);
  end if;

  -- 8. Si es compra financiada, generar las cuotas
  if p_es_cuotas then
    insert into public.installments(
      order_id, customer_id, numero_cuota, total_cuotas, monto_usd, tasa_bs, monto_bs,
      fecha_vencimiento, estado, metodo_id, referencia
    ) values (
      o, auth.uid(), 1, 2, v_cuota_1, rate, round(v_cuota_1 * coalesce(rate, 0), 2), current_date,
      case when z >= v_cuota_1 then 'pagada' else 'en_revision' end,
      p_metodo, left(coalesce(p_ref,''), 120)
    );

    insert into public.installments(
      order_id, customer_id, numero_cuota, total_cuotas, monto_usd, tasa_bs, monto_bs,
      fecha_vencimiento, estado
    ) values (
      o, auth.uid(), 2, 2, v_cuota_2, rate, round(v_cuota_2 * coalesce(rate, 0), 2),
      (current_date + interval '15 days')::date, 'pendiente'
    );
  end if;

  return o;
end $$;

revoke execute on function public.create_order(uuid,uuid,text,numeric,jsonb,boolean,uuid) from public, anon;
grant execute on function public.create_order(uuid,uuid,text,numeric,jsonb,boolean,uuid) to authenticated;

-- ------------------------------------------------------------------------------
-- SECCIÓN 7: CONCILIACIÓN, CIERRE, RECHAZO Y REEMBOLSOS COHERENTES
-- ------------------------------------------------------------------------------
drop function if exists public._deliver(uuid);
create or replace function public._deliver(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  o public.orders;
  pr public.products;
  pf uuid;
  st text;
begin
  select * into o from public.orders where id = p_order for update;
  if o.estado not in ('pendiente','pagado','vencido') then
    raise exception 'Estado de pedido inválido para entrega: %', o.estado;
  end if;

  select * into pr from public.products where id = o.product_id;

  if pr.tipo not in ('servicio', 'gaming', 'recarga_telefonica') then
    pf := o.profile_id;
    if pf is not null then
      select estado into st from public.profiles_inventory where id = pf for update;
      if not ((o.estado <> 'vencido' and st = 'reservado') or st = 'disponible') then
        pf := null;
      end if;
    end if;

    if pf is null then
      if o.franchise_id is not null then
        select pi.id into pf
        from public.profiles_inventory pi
        join public.mother_accounts m on m.id = pi.mother_id
        where pi.product_id = o.product_id
          and pi.estado = 'disponible'
          and pi.franchise_id = o.franchise_id
          and coalesce(m.activa, true) is true
          and (m.vence is null or m.vence >= current_date)
        order by pi.id limit 1 for update skip locked;
      end if;

      if pf is null then
        select pi.id into pf
        from public.profiles_inventory pi
        join public.mother_accounts m on m.id = pi.mother_id
        where pi.product_id = o.product_id
          and pi.estado = 'disponible'
          and (pi.franchise_id is null or o.franchise_id is null)
          and coalesce(m.activa, true) is true
          and (m.vence is null or m.vence >= current_date)
        order by pi.id limit 1 for update skip locked;
      end if;

      if pf is null then
        raise exception 'Sin stock disponible para % (con cuenta madre activa)', pr.nombre;
      end if;
    end if;

    update public.profiles_inventory
    set estado = 'vendido',
        inicia = current_date,
        vence = current_date + coalesce(pr.duracion_dias, 30)
    where id = pf;
  end if;

  update public.orders
  set estado = 'entregado',
      profile_id = pf,
      inicia = current_date,
      vence = coalesce(vence, current_date + coalesce(pr.duracion_dias, 30)),
      proximo_pago = coalesce(proximo_pago, current_date + coalesce(pr.duracion_dias, 30)),
      pagado_at = coalesce(pagado_at, now())
  where id = p_order;

  -- 1. Conciliar retención de saldo Zeny a aprobado
  update public.zeny_ledger
  set estado = 'aprobado'
  where order_id = p_order and tipo = 'compra' and estado = 'pendiente';

  -- 2. Si tenía cuota inicial en revisión, conciliarla
  update public.installments
  set estado = 'pagada',
      pagada_at = coalesce(pagada_at, now())
  where order_id = p_order and numero_cuota = 1 and estado = 'en_revision';

  -- 3. Emitir factura cuadrada
  insert into public.invoices(order_id, customer_id, total_usd, total_bs, tasa_bs, estado, franchise_id)
  select id, customer_id, total_usd, total_bs, tasa_bs, 'emitida', franchise_id
  from public.orders where id = p_order
  on conflict (order_id) do update
  set estado = 'emitida',
      total_usd = excluded.total_usd,
      total_bs = excluded.total_bs,
      tasa_bs = excluded.tasa_bs;
end $$;

drop function if exists public._close_order(uuid, text);
create or replace function public._close_order(p_order uuid, p_estado text)
returns void language plpgsql security definer set search_path = public as $$
declare
  o public.orders;
begin
  select * into o from public.orders where id = p_order for update;
  if o.estado <> 'pendiente' then
    raise exception 'Solo se puede cerrar un pedido pendiente';
  end if;

  update public.orders set estado = p_estado where id = p_order;

  if o.profile_id is not null then
    update public.profiles_inventory
    set estado = 'disponible'
    where id = o.profile_id and estado = 'reservado';
  end if;

  -- Liberar retenciones de Zeny asociadas
  update public.zeny_ledger
  set estado = 'rechazado'
  where order_id = p_order and tipo = 'compra' and estado = 'pendiente';

  -- Anular cuotas pendientes si aplicaba financiamiento
  update public.installments
  set estado = 'cancelada'
  where order_id = p_order and estado in ('pendiente', 'en_revision');
end $$;

drop function if exists public.release_expired();
create or replace function public.release_expired()
returns void language plpgsql security definer set search_path = public as $$
declare
  m int;
  r record;
begin
  select coalesce((value->>'minutos')::int, 60) into m from public.settings where key = 'reserva';

  for r in
    select id, profile_id from public.orders
    where estado = 'pendiente'
      and created_at < now() - make_interval(mins => coalesce(m, 60))
    for update skip locked
  loop
    update public.orders set estado = 'vencido' where id = r.id;

    if r.profile_id is not null then
      update public.profiles_inventory
      set estado = 'disponible'
      where id = r.profile_id and estado = 'reservado';
    end if;

    update public.zeny_ledger
    set estado = 'rechazado'
    where order_id = r.id and tipo = 'compra' and estado = 'pendiente';

    update public.installments
    set estado = 'cancelada'
    where order_id = r.id and estado in ('pendiente', 'en_revision');
  end loop;
end $$;

drop function if exists public.refund_order(uuid, numeric, text, text, boolean);
drop function if exists public.refund_order(uuid, numeric, text, text);
drop function if exists public.refund_order(uuid, text);
drop function if exists public.refund_order(uuid);
create or replace function public.refund_order(
  p_order uuid,
  p_monto numeric,
  p_destino text,
  p_motivo text,
  p_liberar boolean default true
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  o public.orders;
  prev numeric;
  m numeric;
  rid uuid;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select * into o from public.orders where id = p_order for update;
  if not found then raise exception 'Pedido no existe'; end if;
  if o.estado not in ('pagado','entregado') then
    raise exception 'Solo se reembolsan pedidos pagados o entregados';
  end if;
  if p_destino not in ('zeny','usdt','bolivares','externo') then
    raise exception 'Destino de devolución inválido';
  end if;

  select coalesce(sum(monto_usd),0) into prev from public.refunds where order_id = p_order;
  m := coalesce(p_monto, o.total_usd - prev);
  if m <= 0 or m + prev > o.total_usd then
    raise exception 'Monto inválido (máximo reembolsable: %)', o.total_usd - prev;
  end if;

  insert into public.refunds(order_id, customer_id, monto_usd, destino, motivo, liberado)
  values (p_order, o.customer_id, m, p_destino, p_motivo, case when m + prev >= o.total_usd then p_liberar end)
  returning id into rid;

  -- Si el destino es Zeny, se acredita con estado 'aprobado' para sumar inmediatamente al saldo
  if p_destino = 'zeny' then
    insert into public.zeny_ledger(customer_id, tipo, monto, referencia, estado, order_id)
    values (o.customer_id, 'reembolso', m, 'Reembolso pedido ' || left(o.id::text, 8), 'aprobado', o.id);
  end if;

  if m + prev >= o.total_usd then
    update public.orders set estado = 'reembolsado' where id = p_order;
    update public.invoices set estado = 'anulada' where order_id = p_order;
    if o.profile_id is not null then
      update public.profiles_inventory
      set estado = case when p_liberar then 'disponible' else 'suspendido' end,
          inicia = null,
          vence = null
      where id = o.profile_id;
    end if;
  end if;

  return rid;
end $$;

-- ------------------------------------------------------------------------------
-- SECCIÓN 8: ENTREGAS A CRÉDITO Y REGISTRO AUTOMÁTICO EN installments
-- ------------------------------------------------------------------------------
drop function if exists public.deliver_order_credit(uuid, int, uuid);
drop function if exists public.deliver_order_credit(uuid, int);
drop function if exists public.deliver_order_credit(uuid);

create or replace function public.deliver_order_credit(
  p_order uuid,
  p_dias int default 7,
  p_reseller_id uuid default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  o public.orders;
  c public.customers;
  v_dias int := coalesce(p_dias, 7);
  f_vence date;
  v_rate numeric;
  v_credito_usado numeric := 0;
  v_limite numeric := 30.00;
  v_seller_id uuid;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;

  select * into o from public.orders where id = p_order for update;
  if not found then raise exception 'Pedido no encontrado'; end if;
  if o.estado not in ('pendiente', 'pagado', 'vencido') then
    raise exception 'El pedido no puede ser entregado a crédito (estado actual: %)', o.estado;
  end if;

  v_seller_id := coalesce(p_reseller_id, o.customer_id);

  select * into c from public.customers where id = v_seller_id;
  if not found then raise exception 'Cliente o Revendedor no encontrado'; end if;

  v_limite := coalesce(c.limite_credito, 30.00);

  select coalesce(sum(monto_usd), 0) into v_credito_usado
  from public.installments
  where (customer_id = v_seller_id or reseller_id = v_seller_id)
    and estado in ('pendiente', 'en_revision', 'vencida');

  -- Si el crédito excede el límite del usuario, el Admin lo aprueba ampliando el cupo automáticamente
  if (v_credito_usado + o.total_usd) > v_limite then
    update public.customers set limite_credito = (v_credito_usado + o.total_usd) where id = v_seller_id;
  end if;

  -- Entregar credenciales y fijar estado
  perform public._deliver(p_order);

  f_vence := (current_date + make_interval(days => v_dias))::date;
  select bs_por_usd into v_rate from public.exchange_rates order by fecha desc limit 1;

  -- Actualizar orden para indicar crédito y fecha límite de pago
  update public.orders
  set vence = f_vence,
      proximo_pago = f_vence,
      referencia = '[CRÉDITO] Vence ' || f_vence::text || ' ($' || o.total_usd::text || ' USD)'
  where id = p_order;

  -- Insertar la cuenta por cobrar en installments para restar cupo inmediatamente
  insert into public.installments(
    order_id,
    customer_id,
    reseller_id,
    numero_cuota,
    total_cuotas,
    monto_usd,
    tasa_bs,
    monto_bs,
    fecha_vencimiento,
    estado,
    referencia
  ) values (
    p_order,
    o.customer_id,
    v_seller_id,
    1,
    1,
    o.total_usd,
    coalesce(o.tasa_bs, v_rate, 1),
    round(o.total_usd * coalesce(o.tasa_bs, v_rate, 1), 2),
    f_vence,
    'pendiente',
    '[CRÉDITO REVENDEDOR] Plazo ' || v_dias::text || 'd - Pedido ' || left(p_order::text, 8)
  );
end $$;

grant execute on function public.deliver_order_credit(uuid, int, uuid) to authenticated;

-- ------------------------------------------------------------------------------
-- SECCIÓN 9: APROBACIÓN DE CUOTAS Y LIBERACIÓN DE LÍMITE DE CRÉDITO
-- ------------------------------------------------------------------------------
drop function if exists public.approve_installment(uuid);
create or replace function public.approve_installment(
  p_installment_id uuid
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_inst public.installments;
  v_pending_count int := 0;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;

  select * into v_inst from public.installments where id = p_installment_id for update;
  if not found then raise exception 'Cuota no encontrada'; end if;

  update public.installments
  set estado = 'pagada',
      pagada_at = coalesce(pagada_at, now())
  where id = p_installment_id;

  -- Si todas las cuotas de la orden asociada fueron liquidadas, actualizar pagado_at
  if v_inst.order_id is not null then
    select count(*) into v_pending_count
    from public.installments
    where order_id = v_inst.order_id
      and estado in ('pendiente', 'en_revision', 'vencida');

    if v_pending_count = 0 then
      update public.orders
      set pagado_at = coalesce(pagado_at, now())
      where id = v_inst.order_id;
    end if;
  end if;
end $$;

grant execute on function public.approve_installment(uuid) to authenticated;

-- ------------------------------------------------------------------------------
-- SECCIÓN 10: CONSOLIDADO DE FINANZAS CUADRADO AL CENTAVO (finanzas)
-- ------------------------------------------------------------------------------
drop function if exists public.finanzas(int);
drop function if exists public.finanzas(integer);
drop function if exists public.finanzas();

create or replace function public.finanzas(p_meses int default 12)
returns table(
  mes date,
  ventas numeric,
  devoluciones numeric,
  gastos numeric,
  compras numeric,
  ganancia numeric,
  cuotas_cobradas numeric,
  cuotas_por_cobrar numeric
)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not is_admin() then raise exception 'No autorizado'; end if;

  return query
  with m as (
    select generate_series(
      date_trunc('month', current_date) - make_interval(months => p_meses - 1),
      date_trunc('month', current_date),
      interval '1 month'
    )::date as mes
  ),
  -- Ventas de contado (órdenes pagadas que NO están divididas en cuotas)
  v as (
    select date_trunc('month', coalesce(o.pagado_at, o.created_at))::date as mes,
           coalesce(sum(o.total_usd), 0) as t
    from public.orders o
    where o.estado in ('pagado', 'entregado')
      and o.pagado_at is not null
      and not exists (select 1 from public.installments i where i.order_id = o.id)
    group by 1
  ),
  -- Cuotas y créditos efectivamente cobrados y conciliados
  inst_pagadas as (
    select date_trunc('month', coalesce(i.pagada_at, i.created_at))::date as mes,
           coalesce(sum(i.monto_usd), 0) as t
    from public.installments i
    where i.estado = 'pagada'
    group by 1
  ),
  -- Cuotas y créditos pendientes de cobro (calle)
  inst_pend as (
    select date_trunc('month', coalesce(i.fecha_vencimiento, current_date))::date as mes,
           coalesce(sum(i.monto_usd), 0) as t
    from public.installments i
    where i.estado in ('pendiente', 'en_revision', 'vencida')
    group by 1
  ),
  d as (
    select date_trunc('month', created_at)::date as mes,
           coalesce(sum(monto_usd), 0) as t
    from public.refunds
    group by 1
  ),
  g as (
    select date_trunc('month', fecha)::date as mes,
           coalesce(sum(monto_usd), 0) as t
    from public.expenses
    group by 1
  ),
  -- Compras de cuentas madre pagadas o de contado
  c as (
    select date_trunc('month', fecha)::date as mes,
           coalesce(sum(monto_usd), 0) as t
    from public.purchases
    where coalesce(estado_pago, 'pagado') = 'pagado' or es_credito is false
    group by 1
  ),
  -- Operaciones completadas de la Mesa de Cambio USDT
  mc as (
    select date_trunc('month', created_at)::date as mes,
           coalesce(sum(round(monto_usdt * 0.02, 2)), 0) as t
    from public.mesa_cambio_operaciones
    where estado = 'completado_enviado'
    group by 1
  )
  select
    m.mes,
    round(coalesce(v.t, 0) + coalesce(ip.t, 0), 2) as ventas,
    round(coalesce(d.t, 0), 2) as devoluciones,
    round(coalesce(g.t, 0), 2) as gastos,
    round(coalesce(c.t, 0), 2) as compras,
    round((coalesce(v.t, 0) + coalesce(ip.t, 0) + coalesce(mc.t, 0)) - coalesce(d.t, 0) - coalesce(g.t, 0) - coalesce(c.t, 0), 2) as ganancia,
    round(coalesce(ip.t, 0), 2) as cuotas_cobradas,
    round(coalesce(inpend.t, 0), 2) as cuotas_por_cobrar
  from m
  left join v on v.mes = m.mes
  left join inst_pagadas ip on ip.mes = m.mes
  left join inst_pend inpend on inpend.mes = m.mes
  left join d on d.mes = m.mes
  left join g on g.mes = m.mes
  left join c on c.mes = m.mes
  left join mc on mc.mes = m.mes
  order by m.mes desc;
end $$;

grant execute on function public.finanzas(int) to authenticated;

-- ------------------------------------------------------------------------------
-- SECCIÓN 11: SUSCRIPCIÓN IDEMPOTENTE A supabase_realtime
-- ------------------------------------------------------------------------------
do $$
declare
  t text;
  tables text[] := array['installments', 'franchises', 'zeny_cards', 'invoices', 'mesa_cambio_operaciones', 'mesa_cambio_caja', 'partner_commissions'];
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array tables loop
      if exists (select 1 from information_schema.tables where table_name = t and table_schema = 'public') then
        if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
          execute 'alter publication supabase_realtime add table public.' || quote_ident(t);
        end if;
      end if;
    end loop;
  end if;
end $$;
