-- ==============================================================================
-- MIGRACIÓN 49: RESOLUCIÓN DEFINITIVA DE RENOVACIONES POR PAGO MÓVIL / TRANSFERENCIA,
-- CONCILIACIÓN EN _deliver() PARA PERFILES EXISTENTES, ENTREGA DIRECTA A CRÉDITO DESDE PANEL ADMIN
-- Y SANEAMIENTO MARIANNE AGUDO + ANGELO
-- ==============================================================================
-- 1. Asegurar columnas created_at en profiles_inventory y entregado_at en orders
-- 2. Actualizar `_deliver(p_order uuid)` para soportar renovaciones de perfiles existentes
--    (evitando que resetee a NULL o intente buscar stock nuevo cuando ya hay un profile_id).
-- 3. Actualizar `my_reseller_clients()` para retornar el estado de órdenes pendientes
--    de verificación (`tiene_pendiente`, `orden_pendiente_id`, `orden_pendiente_ref`).
-- 4. Nueva RPC `admin_deliver_profile_credit()` para entregar perfiles a crédito directamente
--    a cualquier cliente desde el Panel Administrativo sin necesidad de pedido previo.
-- 5. Nueva RPC `admin_deliver_profile_cash()` para entregar perfiles al contado directamente.
-- 6. Saneamiento inmediato de Marianne Agudo (Perfil Extra Netflix) con Pago Móvil entregado.
-- 7. Saneamiento de Angelo (Disney+ Premium) con cuota a crédito agendada.
-- ==============================================================================

begin;

-- Asegurar columnas necesarias en profiles_inventory y orders
alter table public.profiles_inventory add column if not exists created_at timestamptz default now();
alter table public.orders add column if not exists entregado_at timestamptz default now();

-- ------------------------------------------------------------------------------
-- SECCIÓN 1: REFACTORIZACIÓN DEFINITIVA DE _deliver(p_order uuid)
-- ------------------------------------------------------------------------------
drop function if exists public._deliver(uuid);

create or replace function public._deliver(p_order uuid)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare
  o public.orders;
  pr public.products;
  pf uuid;
  st text;
  v_cur_vence date;
  v_new_vence date;
  v_duracion int := 30;
  v_is_renewal boolean := false;
begin
  -- 1. Bloquear y validar orden
  select * into o from public.orders where id = p_order for update;
  if not found then
    raise exception 'Pedido no encontrado.';
  end if;

  if o.estado not in ('pendiente', 'pagado', 'vencido') then
    raise exception 'Estado de pedido inválido para entrega: %', o.estado;
  end if;

  -- 2. Obtener producto y duración
  select * into pr from public.products where id = o.product_id;
  v_duracion := coalesce(pr.duracion_dias, 30);

  if pr.tipo not in ('servicio', 'gaming', 'recarga_telefonica') then
    pf := o.profile_id;

    -- CASO A: El pedido ya trae un perfil asignado (es una renovación o perfil reservado)
    if pf is not null then
      select estado, vence into st, v_cur_vence
      from public.profiles_inventory
      where id = pf for update;

      if st is not null then
        v_is_renewal := true;

        -- Calcular nuevo vencimiento (+30 días desde la fecha actual si está activo, o desde hoy si expiró)
        if v_cur_vence is not null and v_cur_vence >= current_date then
          v_new_vence := v_cur_vence + v_duracion;
        else
          v_new_vence := current_date + v_duracion;
        end if;

        -- Actualizar el perfil existente
        update public.profiles_inventory
        set estado = 'vendido',
            vence = v_new_vence,
            assigned_customer_id = coalesce(assigned_customer_id, o.customer_id),
            vendedor_id = coalesce(vendedor_id, o.vendedor_id),
            no_renueva = false,
            no_renueva_reportado_at = null,
            no_renueva_motivo = null
        where id = pf;

        -- Marcar pedidos anteriores entregados de este mismo perfil como vencidos para evitar conflicto de índice único
        update public.orders
        set estado = 'vencido',
            no_renueva = false
        where profile_id = pf
          and id <> p_order
          and estado in ('entregado', 'pagado');
      else
        -- El perfil referenciado no existe en la base de datos
        pf := null;
      end if;
    end if;

    -- CASO B: Compra nueva desde catálogo sin perfil pre-asignado
    if pf is null then
      -- B1: Buscar stock propio de franquicia si aplica
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

      -- B2: Buscar stock central disponible
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
        raise exception 'Sin stock disponible para % (con cuenta madre activa)', coalesce(pr.nombre, 'Servicio');
      end if;

      v_new_vence := current_date + v_duracion;

      update public.profiles_inventory
      set estado = 'vendido',
          inicia = current_date,
          vence = v_new_vence,
          assigned_customer_id = coalesce(assigned_customer_id, o.customer_id),
          vendedor_id = coalesce(vendedor_id, o.vendedor_id),
          no_renueva = false,
          no_renueva_reportado_at = null,
          no_renueva_motivo = null
      where id = pf;
    end if;
  else
    -- Servicios sin perfiles físicos (gaming, saldo móvil)
    v_new_vence := current_date + v_duracion;
  end if;

  -- 3. Actualizar la orden a entregado con fechas sincronizadas
  update public.orders
  set estado = 'entregado',
      estado_recarga = 'recargado',
      profile_id = pf,
      inicia = coalesce(inicia, current_date),
      vence = coalesce(v_new_vence, vence, current_date + v_duracion),
      proximo_pago = coalesce(v_new_vence, proximo_pago, current_date + v_duracion),
      pagado_at = coalesce(pagado_at, now())
  where id = p_order;

  -- 4. Conciliar saldo Zeny retenido en compra
  update public.zeny_ledger
  set estado = 'aprobado'
  where order_id = p_order and tipo = 'compra' and estado = 'pendiente';

  -- 5. Si tenía cuota inicial en revisión, conciliarla
  update public.installments
  set estado = 'pagada',
      pagada_at = coalesce(pagada_at, now())
  where order_id = p_order and numero_cuota = 1 and estado = 'en_revision';

  -- 6. Emitir factura cuadrada
  insert into public.invoices(order_id, customer_id, total_usd, total_bs, tasa_bs, estado, franchise_id)
  select id, customer_id, total_usd, total_bs, tasa_bs, 'emitida', franchise_id
  from public.orders where id = p_order
  on conflict (order_id) do nothing;
end;
$$;

revoke execute on function public._deliver(uuid) from public, anon;
grant execute on function public._deliver(uuid) to authenticated;

-- ------------------------------------------------------------------------------
-- SECCIÓN 2: RPC my_reseller_clients() CON DETECCIÓN DE PAGOS PENDIENTES
-- ------------------------------------------------------------------------------
drop function if exists public.my_reseller_clients();

create or replace function public.my_reseller_clients()
returns table (
  profile_id uuid,
  cliente_id uuid,
  cliente_nombre text,
  cliente_telefono text,
  cliente_email text,
  servicio text,
  plataforma text,
  nombre_perfil text,
  pin text,
  correo text,
  clave text,
  vence date,
  estado text,
  no_renueva boolean,
  tiene_pendiente boolean,
  orden_pendiente_id uuid,
  orden_pendiente_ref text
)
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_user_id uuid := auth.uid();
  v_is_adm boolean := false;
  v_seller_name text := null;
begin
  if v_user_id is null then return; end if;

  v_is_adm := is_admin();
  select nombre into v_seller_name from customers where id = v_user_id;

  if v_is_adm then
    -- Administrador: clientes y perfiles de venta directa en tienda
    return query
    select distinct
      pi.id as profile_id,
      coalesce(c.id, o.customer_id) as cliente_id,
      coalesce(c.nombre, o_cust.nombre, 'Cliente Tienda') as cliente_nombre,
      coalesce(c.telefono, o_cust.telefono, '') as cliente_telefono,
      coalesce(c.email, o_cust.email, '') as cliente_email,
      coalesce(p.nombre, m.plataforma) as servicio,
      m.plataforma as plataforma,
      pi.nombre_perfil as nombre_perfil,
      case when pi.pin like 'enc:%' then dec_text(pi.pin) else pi.pin end as pin,
      m.correo as correo,
      case when m.clave like 'enc:%' then dec_text(m.clave) else m.clave end as clave,
      coalesce(pi.vence, o.vence) as vence,
      pi.estado as estado,
      coalesce(pi.no_renueva, false) as no_renueva,
      (ord_pend.p_id is not null) as tiene_pendiente,
      ord_pend.p_id as orden_pendiente_id,
      ord_pend.p_ref as orden_pendiente_ref
    from profiles_inventory pi
    join mother_accounts m on m.id = pi.mother_id
    left join products p on p.id = pi.product_id
    left join customers c on c.id = pi.assigned_customer_id
    left join orders o on o.profile_id = pi.id and o.estado in ('entregado', 'pagado')
    left join customers o_cust on o_cust.id = o.customer_id
    left join lateral (
      select o2.id as p_id, o2.referencia as p_ref
      from public.orders o2
      where o2.profile_id = pi.id and o2.estado = 'pendiente'
      order by o2.created_at desc limit 1
    ) ord_pend on true
    where (
      (pi.vendedor_id is null and coalesce(c.vendedor_id, o.vendedor_id) is null)
      or lower(trim(coalesce(pi.vendedor, ''))) in ('directo tienda', 'tienda', 'directo')
      or lower(trim(coalesce(c.vendedor_nombre, o_cust.vendedor_nombre, ''))) in ('directo tienda', 'tienda', 'directo')
    )
    order by vence asc nulls last;

  else
    -- Revendedor (Pablo, Nelson, etc.): Sus clientes y perfiles asignados
    return query
    select distinct
      pi.id as profile_id,
      coalesce(c.id, o.customer_id) as cliente_id,
      coalesce(c.nombre, o_cust.nombre, 'Cliente Asignado') as cliente_nombre,
      coalesce(c.telefono, o_cust.telefono, '') as cliente_telefono,
      coalesce(c.email, o_cust.email, '') as cliente_email,
      coalesce(p.nombre, m.plataforma) as servicio,
      m.plataforma as plataforma,
      pi.nombre_perfil as nombre_perfil,
      case when pi.pin like 'enc:%' then dec_text(pi.pin) else pi.pin end as pin,
      m.correo as correo,
      case when m.clave like 'enc:%' then dec_text(m.clave) else m.clave end as clave,
      coalesce(pi.vence, o.vence) as vence,
      pi.estado as estado,
      coalesce(pi.no_renueva, false) as no_renueva,
      (ord_pend.p_id is not null) as tiene_pendiente,
      ord_pend.p_id as orden_pendiente_id,
      ord_pend.p_ref as orden_pendiente_ref
    from profiles_inventory pi
    join mother_accounts m on m.id = pi.mother_id
    left join products p on p.id = pi.product_id
    left join customers c on c.id = pi.assigned_customer_id
    left join orders o on o.profile_id = pi.id and o.estado in ('entregado', 'pagado')
    left join customers o_cust on o_cust.id = o.customer_id
    left join lateral (
      select o2.id as p_id, o2.referencia as p_ref
      from public.orders o2
      where o2.profile_id = pi.id and o2.estado = 'pendiente'
      order by o2.created_at desc limit 1
    ) ord_pend on true
    where (
      pi.vendedor_id = v_user_id
      or c.vendedor_id = v_user_id
      or o.vendedor_id = v_user_id
      or pi.assigned_customer_id = v_user_id
      or o.customer_id = v_user_id
      or (pi.vendedor is not null and v_seller_name is not null and lower(trim(pi.vendedor)) = lower(trim(v_seller_name)))
      or exists (
        select 1 from public.customers cust
        where cust.id = v_user_id
          and (
            lower(trim(coalesce(pi.vendedor, ''))) in (lower(trim(coalesce(cust.nombre, ''))), lower(trim(coalesce(cust.codigo_identificacion, ''))))
            or (coalesce(cust.codigo_identificacion, '') = 'RVD:1001' and lower(coalesce(pi.vendedor, '')) like '%pablo%')
          )
      )
    )
    order by vence asc nulls last;
  end if;
end;
$$;

revoke execute on function public.my_reseller_clients() from public, anon;
grant execute on function public.my_reseller_clients() to authenticated;

-- ------------------------------------------------------------------------------
-- SECCIÓN 3: RPC admin_deliver_profile_credit() PARA ENTREGA DIRECTA A CRÉDITO DESDE PANEL ADMIN
-- ------------------------------------------------------------------------------
create or replace function public.admin_deliver_profile_credit(
  p_profile_id uuid,
  p_customer_id uuid,
  p_dias int default 7,
  p_monto_usd numeric default null,
  p_notas text default null
)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_prof profiles_inventory%rowtype;
  v_cust customers%rowtype;
  v_prod products%rowtype;
  v_mother mother_accounts%rowtype;
  v_rate numeric := 1;
  v_precio numeric := 0;
  v_dias int := coalesce(p_dias, 7);
  v_f_vence date;
  v_f_credito date;
  v_order_id uuid;
  v_srv_name text;
  v_cred_usado numeric := 0;
  v_clv_plain text;
  v_pin_plain text;
begin
  if not is_admin() then
    raise exception 'Solo el Administrador puede realizar entregas directas a crédito.';
  end if;

  perform set_config('app.internal', '1', true);

  -- 1. Obtener perfil
  select * into v_prof from profiles_inventory where id = p_profile_id for update;
  if not found then
    raise exception 'Perfil no encontrado en inventario.';
  end if;

  -- 2. Obtener cliente
  select * into v_cust from customers where id = p_customer_id for update;
  if not found then
    raise exception 'Cliente no encontrado.';
  end if;

  -- 3. Obtener producto y cuenta madre
  select * into v_prod from products where id = v_prof.product_id;
  select * into v_mother from mother_accounts where id = v_prof.mother_id;
  v_srv_name := coalesce(v_prod.nombre, v_mother.plataforma, 'Servicio Digital');

  -- 4. Determinar precio en USD
  if p_monto_usd is not null and p_monto_usd > 0 then
    v_precio := p_monto_usd;
  elsif coalesce(v_cust.es_revendedor, false) and v_prod.precio_revendedor_usd is not null and v_prod.precio_revendedor_usd > 0 then
    v_precio := v_prod.precio_revendedor_usd;
  else
    v_precio := coalesce(v_prod.precio_usd, 5.00);
  end if;

  -- 5. Tasa BCV
  select bs_por_usd into v_rate from exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_rate, 1);

  -- 6. Fechas: vencimiento de la cuenta y límite del crédito
  v_f_vence := (current_date + coalesce(v_prod.duracion_dias, 30))::date;
  v_f_credito := (current_date + make_interval(days => v_dias))::date;

  -- 7. Actualizar cupo si es necesario
  select coalesce(sum(monto_usd), 0) into v_cred_usado
  from installments
  where (customer_id = p_customer_id or reseller_id = p_customer_id)
    and estado in ('pendiente', 'en_revision');

  if (v_cred_usado + v_precio) > coalesce(v_cust.limite_credito, 0) then
    update customers set limite_credito = (v_cred_usado + v_precio) where id = p_customer_id;
  end if;

  -- 8. Actualizar perfil en profiles_inventory
  update profiles_inventory set
    estado = 'vendido',
    inicia = current_date,
    vence = v_f_vence,
    assigned_customer_id = p_customer_id,
    vendedor_id = case when coalesce(v_cust.es_revendedor, false) then p_customer_id else null end,
    vendedor = case when coalesce(v_cust.es_revendedor, false) then coalesce(v_cust.nombre, 'Revendedor') else 'Directo Tienda' end,
    no_renueva = false,
    no_renueva_reportado_at = null,
    no_renueva_motivo = null
  where id = p_profile_id;

  -- 9. Cerrar órdenes activas anteriores de este perfil
  update orders set estado = 'vencido', no_renueva = false
  where profile_id = p_profile_id and estado in ('entregado', 'pagado');

  -- 10. Crear orden entregada a crédito
  insert into orders (
    customer_id, vendedor_id, profile_id, product_id,
    total_usd, tasa_bs, total_bs, estado,
    referencia, inicia, vence, proximo_pago, pagado_at
  ) values (
    p_customer_id,
    case when coalesce(v_cust.es_revendedor, false) then p_customer_id else null end,
    p_profile_id,
    v_prof.product_id,
    v_precio,
    v_rate,
    round(v_precio * v_rate, 2),
    'entregado',
    '[CRÉDITO ADMIN] ' || coalesce(v_cust.nombre, 'Cliente') || ' - ' || v_srv_name || ' ($' || v_precio || ' USD a ' || v_dias || 'd)',
    current_date,
    v_f_credito,
    v_f_credito,
    now()
  ) returning id into v_order_id;

  -- 11. Factura
  insert into invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
  values (v_order_id, p_customer_id, v_precio, round(v_precio * v_rate, 2), v_rate, 'emitida')
  on conflict (order_id) do nothing;

  -- 12. Insertar deuda en installments (Cobranza / Línea de Crédito)
  insert into installments (
    order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
    monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
  ) values (
    v_order_id,
    p_customer_id,
    case when coalesce(v_cust.es_revendedor, false) then p_customer_id else null end,
    1, 1,
    v_precio,
    round(v_precio * v_rate, 2),
    v_rate,
    v_f_credito,
    'pendiente',
    '[CRÉDITO ADMIN] ' || v_srv_name || ' (' || coalesce(v_prof.nombre_perfil, 'P1') || ') - ' || coalesce(v_cust.nombre, 'Cliente')
  );

  -- Desencriptar credenciales para retorno inmediato
  v_clv_plain := case when v_mother.clave like 'enc:%' then dec_text(v_mother.clave) else v_mother.clave end;
  v_pin_plain := case when v_prof.pin like 'enc:%' then dec_text(v_prof.pin) else v_prof.pin end;

  return jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'servicio', v_srv_name,
    'perfil', coalesce(v_prof.nombre_perfil, 'Perfil 1'),
    'correo', v_mother.correo,
    'clave', v_clv_plain,
    'pin', coalesce(v_pin_plain, 'Sin PIN'),
    'cliente_nombre', coalesce(v_cust.nombre, 'Cliente'),
    'cliente_telefono', coalesce(v_cust.telefono, ''),
    'monto_usd', v_precio,
    'monto_bs', round(v_precio * v_rate, 2),
    'fecha_limite_pago', v_f_credito,
    'vence_servicio', v_f_vence,
    'dias_credito', v_dias
  );
end;
$$;

revoke execute on function public.admin_deliver_profile_credit(uuid, uuid, int, numeric, text) from public, anon;
grant execute on function public.admin_deliver_profile_credit(uuid, uuid, int, numeric, text) to authenticated;

-- ------------------------------------------------------------------------------
-- SECCIÓN 4: RPC admin_deliver_profile_cash() PARA ENTREGA CONTADO DESDE PANEL ADMIN
-- ------------------------------------------------------------------------------
create or replace function public.admin_deliver_profile_cash(
  p_profile_id uuid,
  p_customer_id uuid,
  p_monto_usd numeric default null,
  p_metodo_id uuid default null,
  p_referencia text default null
)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_prof profiles_inventory%rowtype;
  v_cust customers%rowtype;
  v_prod products%rowtype;
  v_mother mother_accounts%rowtype;
  v_rate numeric := 1;
  v_precio numeric := 0;
  v_f_vence date;
  v_order_id uuid;
  v_srv_name text;
  v_clv_plain text;
  v_pin_plain text;
begin
  if not is_admin() then
    raise exception 'Solo el Administrador puede realizar entregas directas.';
  end if;

  perform set_config('app.internal', '1', true);

  select * into v_prof from profiles_inventory where id = p_profile_id for update;
  if not found then raise exception 'Perfil no encontrado.'; end if;

  select * into v_cust from customers where id = p_customer_id for update;
  if not found then raise exception 'Cliente no encontrado.'; end if;

  select * into v_prod from products where id = v_prof.product_id;
  select * into v_mother from mother_accounts where id = v_prof.mother_id;
  v_srv_name := coalesce(v_prod.nombre, v_mother.plataforma, 'Servicio Digital');

  if p_monto_usd is not null and p_monto_usd > 0 then
    v_precio := p_monto_usd;
  elsif coalesce(v_cust.es_revendedor, false) and v_prod.precio_revendedor_usd is not null and v_prod.precio_revendedor_usd > 0 then
    v_precio := v_prod.precio_revendedor_usd;
  else
    v_precio := coalesce(v_prod.precio_usd, 5.00);
  end if;

  select bs_por_usd into v_rate from exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_rate, 1);

  v_f_vence := (current_date + coalesce(v_prod.duracion_dias, 30))::date;

  update profiles_inventory set
    estado = 'vendido',
    inicia = current_date,
    vence = v_f_vence,
    assigned_customer_id = p_customer_id,
    vendedor_id = case when coalesce(v_cust.es_revendedor, false) then p_customer_id else null end,
    vendedor = case when coalesce(v_cust.es_revendedor, false) then coalesce(v_cust.nombre, 'Revendedor') else 'Directo Tienda' end,
    no_renueva = false,
    no_renueva_reportado_at = null,
    no_renueva_motivo = null
  where id = p_profile_id;

  update orders set estado = 'vencido', no_renueva = false
  where profile_id = p_profile_id and estado in ('entregado', 'pagado');

  insert into orders (
    customer_id, vendedor_id, profile_id, product_id, metodo_id,
    total_usd, tasa_bs, total_bs, estado,
    referencia, inicia, vence, proximo_pago, pagado_at
  ) values (
    p_customer_id,
    case when coalesce(v_cust.es_revendedor, false) then p_customer_id else null end,
    p_profile_id,
    v_prof.product_id,
    p_metodo_id,
    v_precio,
    v_rate,
    round(v_precio * v_rate, 2),
    'entregado',
    coalesce(p_referencia, '[VENTA DIRECTA ADMIN] ' || coalesce(v_cust.nombre, 'Cliente') || ' - ' || v_srv_name || ' ($' || v_precio || ' USD)'),
    current_date,
    v_f_vence,
    v_f_vence,
    now()
  ) returning id into v_order_id;

  insert into invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
  values (v_order_id, p_customer_id, v_precio, round(v_precio * v_rate, 2), v_rate, 'emitida')
  on conflict (order_id) do nothing;

  v_clv_plain := case when v_mother.clave like 'enc:%' then dec_text(v_mother.clave) else v_mother.clave end;
  v_pin_plain := case when v_prof.pin like 'enc:%' then dec_text(v_prof.pin) else v_prof.pin end;

  return jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'servicio', v_srv_name,
    'perfil', coalesce(v_prof.nombre_perfil, 'Perfil 1'),
    'correo', v_mother.correo,
    'clave', v_clv_plain,
    'pin', coalesce(v_pin_plain, 'Sin PIN'),
    'cliente_nombre', coalesce(v_cust.nombre, 'Cliente'),
    'cliente_telefono', coalesce(v_cust.telefono, ''),
    'monto_usd', v_precio,
    'monto_bs', round(v_precio * v_rate, 2),
    'vence_servicio', v_f_vence
  );
end;
$$;

revoke execute on function public.admin_deliver_profile_cash(uuid, uuid, numeric, uuid, text) from public, anon;
grant execute on function public.admin_deliver_profile_cash(uuid, uuid, numeric, uuid, text) to authenticated;

-- ------------------------------------------------------------------------------
-- SECCIÓN 5: SANEAMIENTO DIRECTO EN PRODUCCIÓN: MARIANNE AGUDO Y ANGELO
-- ------------------------------------------------------------------------------
do $$
declare
  v_pablo_id uuid;
  v_rate numeric := 1;

  -- Variables Marianne Agudo
  v_marianne_prof_id uuid;
  v_marianne_cust_id uuid;
  v_prod_netflix_id uuid;
  v_order_marianne uuid;
  v_pend_order_marianne uuid;

  -- Variables Angelo
  v_angelo_prof_id uuid;
  v_angelo_cust_id uuid;
  v_prod_disney_id uuid;
  v_order_angelo uuid;
begin
  select bs_por_usd into v_rate from public.exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_rate, 1);

  -- 1. Localizar ID de Pablo González (RVD:1001)
  select id into v_pablo_id from public.customers
  where lower(trim(email)) in ('pacun1989@gmail.com', 'pablo@gregoryizquierdo.xyz')
     or codigo_identificacion in ('PABLO', 'RVD:1001')
     or lower(trim(nombre)) like '%pablo gonzalez%'
  limit 1;

  -- ============================================================================
  -- CASO 1: MARIANNE AGUDO (PERFIL EXTRA NETFLIX) - PAGO MÓVIL
  -- ============================================================================
  select id into v_prod_netflix_id from public.products
  where lower(nombre) like '%perfil extra netflix%'
     or lower(nombre) like '%netflix perfil extra%'
     or lower(nombre) like '%netflix extra%'
  order by id limit 1;

  select pi.id into v_marianne_prof_id
  from public.profiles_inventory pi
  join public.mother_accounts m on m.id = pi.mother_id
  where (lower(m.correo) = 'solucionservnet+ext603@gmail.com' or lower(pi.nombre_perfil) like '%marianne%')
  order by pi.vence desc nulls last, pi.id desc limit 1;

  select id into v_marianne_cust_id from public.customers
  where lower(trim(nombre)) like '%marianne agudo%'
     or telefono like '%4245621381%'
     or email like '%4245621381%'
  limit 1;

  if v_marianne_cust_id is null and v_pablo_id is not null then
    insert into public.customers (
      nombre, telefono, email, vendedor_id, vendedor_nombre, codigo_identificacion
    ) values (
      'MARIANNE AGUDO', '584245621381', '584245621381@cliente.gregoryizquierdo.xyz', v_pablo_id, 'Pablo Gonzalez', 'CLT:005'
    ) returning id into v_marianne_cust_id;
  elsif v_marianne_cust_id is not null and v_pablo_id is not null then
    update public.customers set
      vendedor_id = v_pablo_id,
      vendedor_nombre = 'Pablo Gonzalez'
    where id = v_marianne_cust_id;
  end if;

  if v_marianne_prof_id is not null then
    update public.profiles_inventory set
      vence = (current_date + interval '30 days')::date,
      estado = 'vendido',
      vendedor_id = v_pablo_id,
      vendedor = 'Pablo Gonzalez',
      assigned_customer_id = coalesce(v_marianne_cust_id, assigned_customer_id),
      no_renueva = false,
      no_renueva_reportado_at = null,
      no_renueva_motivo = null
    where id = v_marianne_prof_id;

    select id into v_pend_order_marianne
    from public.orders
    where (profile_id = v_marianne_prof_id or lower(referencia) like '%marianne%')
      and estado = 'pendiente'
    order by created_at desc limit 1;

    perform set_config('app.internal', '1', true);

    if v_pend_order_marianne is not null then
      update public.orders set
        estado = 'entregado',
        profile_id = v_marianne_prof_id,
        customer_id = coalesce(v_marianne_cust_id, customer_id),
        vendedor_id = v_pablo_id,
        vence = (current_date + interval '30 days')::date,
        proximo_pago = (current_date + interval '30 days')::date,
        pagado_at = coalesce(pagado_at, now())
      where id = v_pend_order_marianne;

      insert into public.invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
      select id, customer_id, total_usd, total_bs, tasa_bs, 'emitida'
      from public.orders where id = v_pend_order_marianne
      on conflict (order_id) do nothing;
    else
      update public.orders set
        estado = 'vencido',
        no_renueva = false
      where profile_id = v_marianne_prof_id and estado in ('entregado', 'pagado');

      insert into public.orders (
        customer_id, vendedor_id, profile_id, product_id,
        total_usd, tasa_bs, total_bs, estado,
        referencia, vence, proximo_pago, pagado_at
      ) values (
        coalesce(v_marianne_cust_id, v_pablo_id),
        v_pablo_id,
        v_marianne_prof_id,
        v_prod_netflix_id,
        7.00,
        v_rate,
        round(7.00 * v_rate, 2),
        'entregado',
        '[RENOVACIÓN PAGO MÓVIL] MARIANNE AGUDO - Perfil Extra Netflix ($7.00 USD - Conciliado)',
        (current_date + interval '30 days')::date,
        (current_date + interval '30 days')::date,
        now()
      ) returning id into v_order_marianne;

      insert into public.invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
      values (v_order_marianne, coalesce(v_marianne_cust_id, v_pablo_id), 7.00, round(7.00 * v_rate, 2), v_rate, 'emitida')
      on conflict (order_id) do nothing;
    end if;
  end if;

  -- ============================================================================
  -- CASO 2: ANGELO (DISNEY+ PREMIUM) - LÍNEA DE CRÉDITO REVENDEDOR
  -- ============================================================================
  select pi.id, pi.product_id into v_angelo_prof_id, v_prod_disney_id
  from public.profiles_inventory pi
  join public.mother_accounts m on m.id = pi.mother_id
  where (lower(m.correo) = 'gotimottyfy471@asfubllst.com' or lower(pi.nombre_perfil) like '%angelo%')
    and (lower(m.plataforma) like '%disney%' or lower(pi.nombre_perfil) like '%angelo%')
  order by pi.vence desc nulls last, pi.id desc limit 1;

  if v_prod_disney_id is null then
    select id into v_prod_disney_id from public.products
    where lower(nombre) like '%disney%' limit 1;
  end if;

  select id into v_angelo_cust_id from public.customers
  where lower(trim(nombre)) like '%angelo%' or telefono like '%4242762146%'
  limit 1;

  if v_angelo_cust_id is null and v_pablo_id is not null then
    insert into public.customers (
      nombre, telefono, email, vendedor_id, vendedor_nombre, codigo_identificacion
    ) values (
      'ANGELO', '584242762146', '584242762146@cliente.gregoryizquierdo.xyz', v_pablo_id, 'Pablo Gonzalez', 'CLT:004'
    ) returning id into v_angelo_cust_id;
  elsif v_angelo_cust_id is not null and v_pablo_id is not null then
    update public.customers set
      vendedor_id = v_pablo_id,
      vendedor_nombre = 'Pablo Gonzalez'
    where id = v_angelo_cust_id;
  end if;

  if v_angelo_prof_id is not null then
    update public.profiles_inventory set
      vence = (current_date + interval '30 days')::date,
      estado = 'vendido',
      vendedor_id = v_pablo_id,
      vendedor = 'Pablo Gonzalez',
      assigned_customer_id = coalesce(v_angelo_cust_id, assigned_customer_id),
      no_renueva = false,
      no_renueva_reportado_at = null,
      no_renueva_motivo = null
    where id = v_angelo_prof_id;

    update public.orders set
      estado = 'vencido',
      no_renueva = false
    where profile_id = v_angelo_prof_id and estado in ('entregado', 'pagado');

    perform set_config('app.internal', '1', true);

    insert into public.orders (
      customer_id, vendedor_id, profile_id, product_id,
      total_usd, tasa_bs, total_bs, estado,
      referencia, vence, proximo_pago, pagado_at
    ) values (
      coalesce(v_angelo_cust_id, v_pablo_id),
      v_pablo_id,
      v_angelo_prof_id,
      v_prod_disney_id,
      4.50,
      v_rate,
      round(4.50 * v_rate, 2),
      'entregado',
      '[RENOVACIÓN CRÉDITO REVENDEDOR] ANGELO - Disney+ Premium ($4.50 USD)',
      (current_date + interval '30 days')::date,
      (current_date + interval '30 days')::date,
      now()
    ) returning id into v_order_angelo;

    insert into public.invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
    values (v_order_angelo, coalesce(v_angelo_cust_id, v_pablo_id), 4.50, round(4.50 * v_rate, 2), v_rate, 'emitida')
    on conflict (order_id) do nothing;

    if not exists (select 1 from public.installments where reseller_id = v_pablo_id and lower(referencia) like '%angelo%') then
      insert into public.installments (
        order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
        monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
      ) values (
        v_order_angelo,
        coalesce(v_angelo_cust_id, v_pablo_id),
        v_pablo_id,
        1, 1,
        4.50,
        round(4.50 * v_rate, 2),
        v_rate,
        (current_date + interval '7 days')::date,
        'pendiente',
        '[CRÉDITO REVENDEDOR] Renovación ANGELO - Disney+ Premium ($4.50 USD)'
      );
    end if;
  end if;

end $$;

commit;
