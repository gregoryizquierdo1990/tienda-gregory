-- ==============================================================================
-- MIGRACIÓN 48: RESOLUCIÓN DEFINITIVA DE RENOVACIONES A CRÉDITO DE REVENDEDORES,
-- CUADRE DE CUOTAS/INSTALLMENTS EN TIEMPO REAL Y SOPORTE DE COMPRAS A PROVEEDORES
-- ==============================================================================
-- 1. Asegurar todas las columnas en la tabla `purchases` para compras a crédito de cuentas madre
-- 2. Asegurar RLS en `installments` para permitir inserción de cuotas a revendedores autorizados
-- 3. Blindar RPC `renovar_suscripcion_perfil()` con bypass app.internal para orders_guard
-- 4. Ampliar `my_reseller_debts()` para reflejar de inmediato cualquier deuda de crédito mayorista
-- 5. Saneamiento inmediato del perfil de Angelo (Disney+ Premium) asignado a Pablo González (RVD:1001)
-- ==============================================================================

begin;

-- ------------------------------------------------------------------------------
-- SECCIÓN 1: ASEGURAR COLUMNAS EN PURCHASES (COMPRAS A CRÉDITO DE PROVEEDORES)
-- ------------------------------------------------------------------------------
alter table public.purchases add column if not exists monto_bs numeric(14,2) default 0.00;
alter table public.purchases add column if not exists monto_usdt numeric(10,2) default 0.00;
alter table public.purchases add column if not exists es_credito boolean not null default false;
alter table public.purchases add column if not exists dias_credito integer default 0;
alter table public.purchases add column if not exists fecha_limite_pago date;
alter table public.purchases add column if not exists estado_pago text not null default 'pagado';
alter table public.purchases add column if not exists metodo_pago_proveedor text;
alter table public.purchases add column if not exists tasa_usdt_pago numeric(14,2);
alter table public.purchases add column if not exists monto_pagado_bs numeric(16,2);
alter table public.purchases add column if not exists pagado_at timestamptz;
alter table public.purchases add column if not exists comprobante_pago text;
alter table public.profiles_inventory add column if not exists created_at timestamptz default now();

create index if not exists idx_purchases_estado_pago on public.purchases(estado_pago);
create index if not exists idx_purchases_fecha_limite on public.purchases(fecha_limite_pago);
create index if not exists idx_purchases_mother on public.purchases(mother_id);

-- ------------------------------------------------------------------------------
-- SECCIÓN 2: POLÍTICAS RLS EN TABLA INSTALLMENTS (PERMITIR VISIBILIDAD Y OPERACIÓN DE REVENDEDOR)
-- ------------------------------------------------------------------------------
alter table public.installments enable row level security;

drop policy if exists installments_user_select on public.installments;
create policy installments_user_select on public.installments for select to authenticated
  using (customer_id = auth.uid() or reseller_id = auth.uid() or is_admin());

drop policy if exists installments_reseller_insert on public.installments;
create policy installments_reseller_insert on public.installments for insert to authenticated
  with check (
    reseller_id = auth.uid() 
    or customer_id = auth.uid() 
    or is_admin()
  );

drop policy if exists installments_reseller_update on public.installments;
create policy installments_reseller_update on public.installments for update to authenticated
  using (reseller_id = auth.uid() or customer_id = auth.uid() or is_admin())
  with check (reseller_id = auth.uid() or customer_id = auth.uid() or is_admin());

drop policy if exists installments_admin_all on public.installments;
create policy installments_admin_all on public.installments for all to authenticated
  using (is_admin()) with check (is_admin());

-- ------------------------------------------------------------------------------
-- SECCIÓN 3: RPC BLINDADA renovar_suscripcion_perfil()
-- ------------------------------------------------------------------------------
create or replace function public.renovar_suscripcion_perfil(
  p_profile_id uuid,
  p_metodo text, -- 'zeny', 'credito', 'transferencia'
  p_metodo_id uuid default null,
  p_referencia text default null
)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_user_id uuid := auth.uid();
  v_is_adm boolean := false;
  v_prof profiles_inventory%rowtype;
  v_prod products%rowtype;
  v_mother mother_accounts%rowtype;
  v_is_reseller boolean := false;
  v_precio numeric(10,2) := 0;
  v_bcv numeric(12,4) := 1;
  v_cur_vence date;
  v_next_vence date;
  v_zeny_bal numeric(12,2) := 0;
  v_cred_limit numeric(10,2) := 0;
  v_used_cred numeric(10,2) := 0;
  v_order_id uuid;
  v_cli_nom text := 'Cliente';
  v_srv_nom text := 'Servicio Digital';
  v_assigned_cli uuid;
  v_seller_name text;
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para realizar renovaciones.';
  end if;

  -- Activar bypass app.internal para evitar que orders_guard sobrescriba profile_id o estado
  perform set_config('app.internal', '1', true);

  v_is_adm := is_admin();

  -- 1. Obtener perfil
  select * into v_prof from profiles_inventory where id = p_profile_id;
  if not found then
    raise exception 'Perfil no encontrado en inventario.';
  end if;

  v_assigned_cli := v_prof.assigned_customer_id;

  -- 2. Verificar datos del usuario que ejecuta
  select es_revendedor, limite_credito, nombre into v_is_reseller, v_cred_limit, v_seller_name
  from customers where id = v_user_id;

  v_is_reseller := coalesce(v_is_reseller, false);
  v_cred_limit := coalesce(v_cred_limit, 0);

  -- 3. Autorización flexible: Admin siempre puede, Revendedor si está vinculado directa o indirectamente
  if not v_is_adm and not (
    v_prof.vendedor_id = v_user_id
    or v_prof.assigned_customer_id = v_user_id
    or exists (select 1 from orders o where o.profile_id = p_profile_id and (o.customer_id = v_user_id or o.vendedor_id = v_user_id))
    or exists (select 1 from customers c where c.id = v_prof.assigned_customer_id and c.vendedor_id = v_user_id)
    or (v_prof.vendedor is not null and v_seller_name is not null and lower(trim(v_prof.vendedor)) = lower(trim(v_seller_name)))
    or exists (select 1 from customers cust where cust.id = v_user_id and (
         lower(trim(coalesce(v_prof.vendedor, ''))) in (lower(trim(coalesce(cust.nombre, ''))), lower(trim(coalesce(cust.codigo_identificacion, ''))))
         or (coalesce(cust.codigo_identificacion, '') = 'RVD:1001' and lower(coalesce(v_prof.vendedor, '')) like '%pablo%')
       ))
  ) then
    raise exception 'No estás autorizado para renovar este perfil.';
  end if;

  -- 4. Obtener producto y cuenta madre
  select * into v_prod from products where id = v_prof.product_id;
  select * into v_mother from mother_accounts where id = v_prof.mother_id;
  v_srv_nom := coalesce(v_prod.nombre, v_mother.plataforma, 'Servicio Digital');

  -- Nombre del cliente final asignado
  if v_assigned_cli is not null and v_assigned_cli <> v_user_id then
    select coalesce(nombre, email, 'Cliente') into v_cli_nom from customers where id = v_assigned_cli;
  elsif v_prof.nombre_perfil is not null then
    v_cli_nom := v_prof.nombre_perfil;
  else
    v_cli_nom := 'Cliente';
  end if;

  -- 5. Tarifa: mayorista si es revendedor, o precio público estándar
  if v_is_reseller then
    if v_prod.precio_revendedor_usd is not null and v_prod.precio_revendedor_usd > 0 then
      v_precio := v_prod.precio_revendedor_usd;
    else
      -- Búsqueda por plataforma si no estaba cargado en el producto
      select precio_revendedor_usd into v_precio
      from products
      where lower(nombre) like '%' || lower(coalesce(v_mother.plataforma, '')) || '%'
        and precio_revendedor_usd > 0
      order by orden asc limit 1;
      
      v_precio := coalesce(v_precio, 4.50);
    end if;
  else
    v_precio := coalesce(v_prod.precio_usd, 3.00);
  end if;

  -- 6. Tasa BCV
  select bs_por_usd into v_bcv from exchange_rates order by fecha desc limit 1;
  v_bcv := coalesce(v_bcv, 1);

  -- 7. Calcular nuevo vencimiento (+30 días desde la fecha agendada o desde hoy si ya expiró)
  v_cur_vence := coalesce(v_prof.vence, current_date);
  if v_cur_vence < current_date then
    v_next_vence := current_date + interval '30 days';
  else
    v_next_vence := v_cur_vence + interval '30 days';
  end if;

  -- 8. Cerrar órdenes anteriores de este perfil marcándolas como vencidas para evitar conflicto de índice único
  update orders
  set estado = 'vencido',
      no_renueva = false
  where profile_id = p_profile_id
    and estado in ('entregado', 'pagado');

  -- 9. Procesar según método de pago
  if p_metodo = 'zeny' then
    -- Verificar saldo Zeny
    select coalesce(sum(monto), 0) into v_zeny_bal
    from zeny_ledger
    where customer_id = v_user_id and estado in ('aprobado', 'completado');

    if v_zeny_bal < v_precio then
      raise exception 'Saldo Zeny insuficiente. Tu saldo es $% USD y el costo de renovación es $% USD.', v_zeny_bal, v_precio;
    end if;

    -- Descontar saldo Zeny
    insert into zeny_ledger (customer_id, tipo, monto, estado, referencia)
    values (v_user_id, 'compra', -v_precio, 'aprobado', 'Renovación +30d ' || v_srv_nom || ' (' || coalesce(v_cli_nom, 'P1') || ')');

    update customers set zeny_balance = coalesce(zeny_balance, 0) - v_precio where id = v_user_id;

    -- Actualizar profiles_inventory
    update profiles_inventory set
      vence = v_next_vence,
      estado = 'vendido',
      vendedor_id = coalesce(vendedor_id, v_user_id),
      vendedor = coalesce(vendedor, v_seller_name),
      no_renueva = false,
      no_renueva_reportado_at = null,
      no_renueva_motivo = null
    where id = p_profile_id;

    -- Registrar nueva orden de renovación activa
    insert into orders (
      customer_id, vendedor_id, profile_id, product_id,
      total_usd, tasa_bs, total_bs, estado,
      referencia, vence, proximo_pago, pagado_at, entregado_at
    ) values (
      coalesce(v_assigned_cli, v_user_id),
      case when v_is_reseller then v_user_id else v_prof.vendedor_id end,
      p_profile_id,
      v_prof.product_id,
      v_precio,
      v_bcv,
      round(v_precio * v_bcv, 2),
      'entregado',
      '[RENOVACIÓN ZENY] ' || v_srv_nom || ' - ' || coalesce(v_cli_nom, 'Cliente') || ' (Mismas Credenciales)',
      v_next_vence,
      v_next_vence,
      now(),
      now()
    ) returning id into v_order_id;

    -- Factura
    insert into public.invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
    values (v_order_id, coalesce(v_assigned_cli, v_user_id), v_precio, round(v_precio * v_bcv, 2), v_bcv, 'emitida')
    on conflict (order_id) do nothing;

    return jsonb_build_object(
      'success', true,
      'estado', 'entregado',
      'order_id', v_order_id,
      'nuevo_vencimiento', v_next_vence,
      'total_usd', v_precio,
      'mensaje', 'Suscripción renovada exitosamente por 30 días con saldo Zeny.'
    );

  elsif p_metodo = 'credito' then
    if not v_is_reseller and not v_is_adm then
      raise exception 'La opción a crédito solo está disponible para Revendedores Oficiales.';
    end if;

    -- Validar límite de crédito del revendedor
    select coalesce(sum(monto_usd), 0) into v_used_cred
    from public.installments
    where (reseller_id = v_user_id or (customer_id = v_user_id and reseller_id is null))
      and estado in ('pendiente', 'en_revision');

    if v_cred_limit is not null and v_cred_limit > 0 and (v_used_cred + v_precio) > v_cred_limit then
      raise exception 'Límite de crédito superado. Tu límite es $% USD, ya utilizaste $% USD y esta renovación requiere $% USD.', v_cred_limit, v_used_cred, v_precio;
    end if;

    -- Actualizar perfil de inmediato
    update profiles_inventory set
      vence = v_next_vence,
      estado = 'vendido',
      vendedor_id = coalesce(vendedor_id, v_user_id),
      vendedor = coalesce(vendedor, v_seller_name),
      no_renueva = false,
      no_renueva_reportado_at = null,
      no_renueva_motivo = null
    where id = p_profile_id;

    -- Registrar nueva orden entregada a crédito vinculando al revendedor
    insert into orders (
      customer_id, vendedor_id, profile_id, product_id,
      total_usd, tasa_bs, total_bs, estado,
      referencia, vence, proximo_pago, pagado_at, entregado_at
    ) values (
      coalesce(v_assigned_cli, v_user_id),
      v_user_id,
      p_profile_id,
      v_prof.product_id,
      v_precio,
      v_bcv,
      round(v_precio * v_bcv, 2),
      'entregado',
      '[RENOVACIÓN CRÉDITO REVENDEDOR] ' || coalesce(v_cli_nom, 'Cliente') || ' - ' || v_srv_nom || ' ($' || v_precio || ' USD)',
      v_next_vence,
      v_next_vence,
      now(),
      now()
    ) returning id into v_order_id;

    -- Factura
    insert into public.invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
    values (v_order_id, coalesce(v_assigned_cli, v_user_id), v_precio, round(v_precio * v_bcv, 2), v_bcv, 'emitida')
    on conflict (order_id) do nothing;

    -- REGISTRAR LA CUOTA EN INSTALLMENTS PARA QUE APAREZCA EN PORTAL ADMIN Y REVENDEDOR
    insert into public.installments (
      order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
      monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
    ) values (
      v_order_id,
      coalesce(v_assigned_cli, v_user_id),
      v_user_id,
      1, 1,
      v_precio,
      round(v_precio * v_bcv, 2),
      v_bcv,
      (current_date + interval '7 days')::date,
      'pendiente',
      '[CRÉDITO REVENDEDOR] Renovación ' || coalesce(v_cli_nom, 'Cliente') || ' - ' || v_srv_nom || ' ($' || v_precio || ' USD)'
    );

    return jsonb_build_object(
      'success', true,
      'estado', 'entregado',
      'order_id', v_order_id,
      'nuevo_vencimiento', v_next_vence,
      'total_usd', v_precio,
      'mensaje', 'Suscripción renovada exitosamente a crédito (+30 días). Deuda agendada a 7 días en cuentas por pagar.'
    );

  else -- Transferencia / Pago Móvil / Binance
    insert into orders (
      customer_id, vendedor_id, profile_id, product_id, metodo_id,
      total_usd, tasa_bs, total_bs, estado,
      referencia, vence, proximo_pago
    ) values (
      coalesce(v_assigned_cli, v_user_id),
      case when v_is_reseller then v_user_id else v_prof.vendedor_id end,
      p_profile_id,
      v_prof.product_id,
      p_metodo_id,
      v_precio,
      v_bcv,
      round(v_precio * v_bcv, 2),
      'pendiente',
      '[RENOVACIÓN PENDIENTE] ' || coalesce(v_cli_nom, 'Cliente') || ' - ' || v_srv_nom || ' (Ref: ' || coalesce(p_referencia, 'N/A') || ')',
      v_next_vence,
      v_next_vence
    ) returning id into v_order_id;

    return jsonb_build_object(
      'success', true,
      'estado', 'pendiente',
      'order_id', v_order_id,
      'nuevo_vencimiento', v_next_vence,
      'total_usd', v_precio,
      'mensaje', 'Solicitud de renovación registrada. En proceso de verificación.'
    );
  end if;
end;
$$;

revoke execute on function public.renovar_suscripcion_perfil(uuid, text, uuid, text) from public, anon;
grant execute on function public.renovar_suscripcion_perfil(uuid, text, uuid, text) to authenticated;

-- ------------------------------------------------------------------------------
-- SECCIÓN 4: RPC my_reseller_debts() OPTIMIZADA
-- ------------------------------------------------------------------------------
create or replace function public.my_reseller_debts()
returns table (
  id uuid,
  order_id uuid,
  cliente_id uuid,
  cliente_nombre text,
  cliente_telefono text,
  servicio text,
  nombre_perfil text,
  monto_usd numeric,
  monto_bs numeric,
  tasa_bs numeric,
  fecha_vencimiento date,
  estado text,
  referencia text,
  pagada_at timestamptz,
  created_at timestamptz
)
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_user_id uuid := auth.uid();
  v_seller_nom text;
begin
  if v_user_id is null then return; end if;

  select nombre into v_seller_nom from public.customers where id = v_user_id;

  return query
  select distinct
    i.id,
    i.order_id,
    c.id as cliente_id,
    coalesce(c.nombre, 'Cliente Asignado') as cliente_nombre,
    coalesce(c.telefono, '') as cliente_telefono,
    coalesce(p.nombre, m.plataforma, 'Servicio Digital') as servicio,
    coalesce(pi.nombre_perfil, 'Perfil 1') as nombre_perfil,
    i.monto_usd,
    i.monto_bs,
    i.tasa_bs,
    i.fecha_vencimiento,
    i.estado,
    i.referencia,
    i.pagada_at,
    i.created_at
  from public.installments i
  left join public.orders o on o.id = i.order_id
  left join public.customers c on c.id = coalesce(i.customer_id, o.customer_id)
  left join public.products p on p.id = o.product_id
  left join public.profiles_inventory pi on pi.id = o.profile_id
  left join public.mother_accounts m on m.id = pi.mother_id
  where (
    i.reseller_id = v_user_id
    or o.vendedor_id = v_user_id
    or (i.customer_id = v_user_id and exists (select 1 from public.customers cust where cust.id = v_user_id and cust.es_revendedor = true))
    or (v_seller_nom is not null and lower(coalesce(i.referencia, '')) like '%' || lower(trim(v_seller_nom)) || '%')
  )
  order by (i.estado = 'pendiente') desc, (i.estado = 'en_revision') desc, i.fecha_vencimiento asc;
end;
$$;

revoke execute on function public.my_reseller_debts() from public, anon;
grant execute on function public.my_reseller_debts() to authenticated;

-- ------------------------------------------------------------------------------
-- SECCIÓN 5: SANEAMIENTO DIRECTO DE ANGELO (DISNEY+ PREMIUM) CON PABLO GONZÁLEZ
-- ------------------------------------------------------------------------------
do $$
declare
  v_pablo_id uuid;
  v_angelo_prof_id uuid;
  v_angelo_cust_id uuid;
  v_prod_disney_id uuid;
  v_rate numeric := 1;
  v_order_angelo uuid;
begin
  select bs_por_usd into v_rate from public.exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_rate, 1);

  -- 1. Localizar ID de Pablo González
  select id into v_pablo_id from public.customers
  where lower(trim(email)) in ('pacun1989@gmail.com', 'pablo@gregoryizquierdo.xyz')
     or codigo_identificacion in ('PABLO', 'RVD:1001')
     or lower(trim(nombre)) like '%pablo gonzalez%'
  limit 1;

  -- 2. Localizar perfil de Disney+ Premium de Angelo
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

  -- 3. Localizar o registrar a Angelo como cliente final vinculado a Pablo
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

  -- 4. Actualizar el perfil en profiles_inventory extendiéndolo +30 días
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

    -- Cerrar órdenes anteriores
    update public.orders set
      estado = 'vencido',
      no_renueva = false
    where profile_id = v_angelo_prof_id and estado in ('entregado', 'pagado');

    -- Crear orden activa entregada vinculada a Pablo
    perform set_config('app.internal', '1', true);
    
    insert into public.orders (
      customer_id, vendedor_id, profile_id, product_id,
      total_usd, tasa_bs, total_bs, estado,
      referencia, vence, proximo_pago, pagado_at, entregado_at
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
      now(),
      now()
    ) returning id into v_order_angelo;

    -- Crear factura
    insert into public.invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
    values (v_order_angelo, coalesce(v_angelo_cust_id, v_pablo_id), 4.50, round(4.50 * v_rate, 2), v_rate, 'emitida')
    on conflict (order_id) do nothing;

    -- Crear o actualizar la cuota en installments
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
