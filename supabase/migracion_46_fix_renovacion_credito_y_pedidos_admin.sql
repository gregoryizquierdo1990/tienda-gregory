-- ==============================================================================
-- MIGRACIÓN 46: Fix Integral de Renovación a Crédito de Revendedores y Registro en Cuotas
-- ==============================================================================
-- 1. Asegura la columna 'reseller_id' en 'installments' y actualiza políticas RLS.
-- 2. Resuelve el conflicto con el índice único 'orders_profile_activo':
--    Al renovar un perfil, la orden del ciclo anterior se marca como 'vencido',
--    permitiendo insertar la nueva orden del nuevo ciclo sin violar la unicidad.
-- 3. Registra automáticamente la deuda en 'installments' cuando un revendedor
--    utiliza su línea de crédito para renovar un perfil (con plazo de 7 días).
-- 4. Vincula la línea de crédito de $30.00 USD y los perfiles iniciales a Pablo González.
-- 5. Sincroniza la deuda de las renovaciones recientes realizadas por Pablo González
--    o cualquier revendedor para que aparezcan en Cobranza Cuotas y Pedidos.

-- ------------------------------------------------------------------------------
-- PASO 1: Estructura de Tablas y Columnas Requeridas (Idempotente)
-- ------------------------------------------------------------------------------
alter table public.customers add column if not exists limite_credito numeric(10,2) default 0.00;
alter table public.customers add column if not exists es_revendedor boolean default false;
alter table public.customers add column if not exists codigo_identificacion text;
alter table public.customers add column if not exists zeny_balance numeric(12,2) default 0.00;

alter table public.orders add column if not exists vendedor_id uuid references public.customers(id);
alter table public.orders add column if not exists no_renueva boolean default false;
alter table public.orders add column if not exists no_renueva_reportado_at timestamptz;
alter table public.orders add column if not exists no_renueva_motivo text;

alter table public.profiles_inventory add column if not exists no_renueva boolean default false;
alter table public.profiles_inventory add column if not exists no_renueva_reportado_at timestamptz;
alter table public.profiles_inventory add column if not exists no_renueva_motivo text;

alter table public.installments add column if not exists reseller_id uuid references public.customers(id);
create index if not exists idx_installments_reseller on public.installments(reseller_id, estado);

-- ------------------------------------------------------------------------------
-- PASO 2: Políticas de Seguridad RLS en Installments
-- ------------------------------------------------------------------------------
alter table public.installments enable row level security;

drop policy if exists installments_user_select on public.installments;
create policy installments_user_select on public.installments for select to authenticated
  using (customer_id = auth.uid() or reseller_id = auth.uid() or is_admin());

drop policy if exists installments_admin_all on public.installments;
create policy installments_admin_all on public.installments for all to authenticated
  using (is_admin()) with check (is_admin());

-- ------------------------------------------------------------------------------
-- PASO 3: RPC my_reseller_debts()
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
begin
  if v_user_id is null then return; end if;

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
  )
  order by (i.estado = 'pendiente') desc, (i.estado = 'en_revision') desc, i.fecha_vencimiento asc;
end;
$$;

revoke execute on function public.my_reseller_debts() from public, anon;
grant execute on function public.my_reseller_debts() to authenticated;

-- ------------------------------------------------------------------------------
-- PASO 4: RPC pagar_deuda_revendedor()
-- ------------------------------------------------------------------------------
create or replace function public.pagar_deuda_revendedor(
  p_installment_id uuid,
  p_metodo text, -- 'zeny' o 'transferencia'
  p_metodo_id uuid default null,
  p_referencia text default null
)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_user_id uuid := auth.uid();
  v_inst public.installments%rowtype;
  v_zeny_bal numeric(12,2) := 0;
  v_seller_nom text := 'Revendedor';
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para pagar deudas.';
  end if;

  select * into v_inst from public.installments where id = p_installment_id;
  if not found then
    raise exception 'Registro de crédito no encontrado.';
  end if;

  -- Verificar pertenencia
  if not is_admin() and v_inst.reseller_id <> v_user_id and v_inst.customer_id <> v_user_id then
    raise exception 'No estás autorizado para pagar este crédito.';
  end if;

  if v_inst.estado = 'pagada' then
    raise exception 'Esta cuenta por pagar ya fue saldada previamente.';
  end if;

  select nombre into v_seller_nom from public.customers where id = v_user_id;

  if p_metodo = 'zeny' then
    -- Verificar saldo Zeny
    select coalesce(sum(monto), 0) into v_zeny_bal
    from public.zeny_ledger
    where customer_id = v_user_id and estado in ('aprobado', 'completado');

    if v_zeny_bal < v_inst.monto_usd then
      raise exception 'Saldo Zeny insuficiente. Tu saldo es $% USD y el monto a pagar es $% USD.', v_zeny_bal, v_inst.monto_usd;
    end if;

    -- Descontar del zeny_ledger
    insert into public.zeny_ledger (customer_id, tipo, monto, estado, referencia)
    values (v_user_id, 'compra', -v_inst.monto_usd, 'aprobado', 'Pago de Crédito Mayorista: ' || coalesce(v_inst.referencia, 'Cuota'));

    -- Actualizar balance en customers
    update public.customers set zeny_balance = coalesce(zeny_balance, 0) - v_inst.monto_usd where id = v_user_id;

    -- Marcar cuota como pagada
    update public.installments set
      estado = 'pagada',
      pagada_at = now(),
      referencia = coalesce(referencia, '') || ' [PAGADO CON ZENY]'
    where id = p_installment_id;

    -- Actualizar orden si aplica
    if v_inst.order_id is not null then
      update public.orders set
        referencia = coalesce(referencia, '') || ' [CRÉDITO SALDADO ZENY]'
      where id = v_inst.order_id;
    end if;

    return jsonb_build_object(
      'success', true,
      'estado', 'pagada',
      'mensaje', 'Deuda saldada exitosamente con saldo Zeny.'
    );

  elsif p_metodo = 'transferencia' then
    if p_referencia is null or trim(p_referencia) = '' then
      raise exception 'Debes ingresar el número de referencia bancaria.';
    end if;

    update public.installments set
      estado = 'en_revision',
      metodo_id = p_metodo_id,
      referencia = coalesce(referencia, '') || ' [REF PAGO: ' || trim(p_referencia) || ']'
    where id = p_installment_id;

    return jsonb_build_object(
      'success', true,
      'estado', 'en_revision',
      'mensaje', 'Comprobante de pago registrado. Gregory verificará la referencia.'
    );

  else
    raise exception 'Método no soportado (debe ser zeny o transferencia).';
  end if;
end;
$$;

revoke execute on function public.pagar_deuda_revendedor(uuid, text, uuid, text) from public, anon;
grant execute on function public.pagar_deuda_revendedor(uuid, text, uuid, text) to authenticated;

-- ------------------------------------------------------------------------------
-- PASO 5: RPC renovar_suscripcion_perfil()
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
  v_order_id uuid;
  v_cli_nom text := 'Cliente';
  v_srv_nom text := 'Servicio Digital';
  v_assigned_cli uuid;
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para realizar renovaciones.';
  end if;

  v_is_adm := is_admin();

  -- 1. Obtener perfil
  select * into v_prof from profiles_inventory where id = p_profile_id;
  if not found then
    raise exception 'Perfil no encontrado en inventario.';
  end if;

  v_assigned_cli := v_prof.assigned_customer_id;

  -- 2. Verificar datos de usuario y permisos
  select es_revendedor, limite_credito, nombre into v_is_reseller, v_cred_limit, v_cli_nom
  from customers where id = v_user_id;

  if not v_is_adm and not (
    v_prof.vendedor_id = v_user_id
    or v_prof.assigned_customer_id = v_user_id
    or exists (select 1 from orders o where o.profile_id = p_profile_id and (o.customer_id = v_user_id or o.vendedor_id = v_user_id))
    or exists (select 1 from customers c where c.id = v_prof.assigned_customer_id and c.vendedor_id = v_user_id)
  ) then
    raise exception 'No estás autorizado para renovar este perfil.';
  end if;

  -- 3. Obtener producto y cuenta madre
  select * into v_prod from products where id = v_prof.product_id;
  select * into v_mother from mother_accounts where id = v_prof.mother_id;
  v_srv_nom := coalesce(v_prod.nombre, v_mother.plataforma, 'Servicio Digital');

  -- Nombre del cliente final asignado para referencia clara
  if v_assigned_cli is not null and v_assigned_cli <> v_user_id then
    select coalesce(nombre, email, 'Cliente') into v_cli_nom from customers where id = v_assigned_cli;
  end if;

  -- 4. Definir precio (Tarifa mayorista si es revendedor, o precio público estándar)
  if v_is_reseller and v_prod.precio_revendedor_usd is not null and v_prod.precio_revendedor_usd > 0 then
    v_precio := v_prod.precio_revendedor_usd;
  else
    v_precio := coalesce(v_prod.precio_usd, 3.00);
  end if;

  -- 5. Tasa BCV
  select bs_por_usd into v_bcv from exchange_rates order by fecha desc limit 1;
  v_bcv := coalesce(v_bcv, 1);

  -- 6. Calcular nuevo vencimiento (+30 días desde la fecha agendada o desde hoy si ya expiró)
  v_cur_vence := coalesce(v_prof.vence, current_date);
  if v_cur_vence < current_date then
    v_next_vence := current_date + interval '30 days';
  else
    v_next_vence := v_cur_vence + interval '30 days';
  end if;

  -- 7. Cerrar órdenes anteriores de este perfil marcándolas como vencidas para evitar conflicto de índice único
  update orders
  set estado = 'vencido',
      no_renueva = false
  where profile_id = p_profile_id
    and estado in ('entregado', 'pagado');

  -- 8. Procesar según método de pago
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

    -- Actualizar perfil de inmediato
    update profiles_inventory set
      vence = v_next_vence,
      estado = 'vendido',
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
      'mensaje', 'Solicitud de renovación registrada. En proceso de conciliación por Gregory.'
    );
  end if;
end;
$$;

revoke execute on function public.renovar_suscripcion_perfil(uuid, text, uuid, text) from public, anon;
grant execute on function public.renovar_suscripcion_perfil(uuid, text, uuid, text) to authenticated;

-- ------------------------------------------------------------------------------
-- PASO 6: Asignación de Línea de Crédito a Pablo González y Carga de Deudas
-- ------------------------------------------------------------------------------
do $$
declare
  v_pablo_id uuid;
  v_rate numeric := 1;
  r record;
begin
  select bs_por_usd into v_rate from public.exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_rate, 1);

  -- Localizar a Pablo González de forma tolerante a tildes, mayúsculas y correos
  select id into v_pablo_id from public.customers
  where lower(trim(email)) in ('pacun1989@gmail.com', 'pacun1989@gmai.com', 'pablo@gregoryizquierdo.xyz', '584129130080@cliente.gregoryizquierdo.xyz')
     or codigo_identificacion in ('PABLO', 'RVD:1001')
     or (lower(trim(nombre)) like '%pablo%' and lower(trim(nombre)) like '%gonzalez%')
  order by (email = 'pacun1989@gmail.com') desc
  limit 1;

  if v_pablo_id is not null then
    -- 1. Asegurar límite de crédito en $30.00 USD para Pablo
    update public.customers set
      limite_credito = 30.00,
      es_revendedor = true,
      codigo_identificacion = coalesce(nullif(codigo_identificacion, ''), 'RVD:1001')
    where id = v_pablo_id;

    -- 2. Vincular pedidos de clientes asignados a Pablo (Evert, Fernisbel, Tony)
    update public.orders set
      vendedor_id = v_pablo_id
    where lower(referencia) like '%pablo gonzalez%'
       or lower(referencia) like '%[crédito pablo%'
       or customer_id in (
         select id from public.customers
         where lower(nombre) like '%evert%'
            or lower(nombre) like '%fernisbel%'
            or lower(nombre) like '%tony%'
       );

    -- 3. Vincular cuotas existentes en installments para que pertenezcan a Pablo como reseller_id
    update public.installments set
      reseller_id = v_pablo_id
    where lower(referencia) like '%pablo gonzalez%'
       or lower(referencia) like '%[crédito pablo%'
       or order_id in (
         select id from public.orders where vendedor_id = v_pablo_id
       );

    -- 4. Asegurar que existan las 3 cuotas exactas de los 3 perfiles si faltara alguna
    -- A. EVERT IZQUIERDO ($7.00 USD)
    if not exists (select 1 from public.installments where reseller_id = v_pablo_id and lower(referencia) like '%evert%') then
      insert into public.installments (
        order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
        monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
      )
      select
        o.id, o.customer_id, v_pablo_id, 1, 1,
        7.00, round(7.00 * v_rate, 2), v_rate, '2026-10-30'::date, 'pendiente',
        '[CRÉDITO PABLO GONZALEZ] EVERT IZQUIERDO - NETFLIX ($7.00 USD)'
      from public.orders o
      where o.vendedor_id = v_pablo_id and (lower(o.referencia) like '%evert%' or exists (select 1 from customers c where c.id = o.customer_id and lower(c.nombre) like '%evert%'))
      limit 1;
    end if;

    -- B. FERNISBEL ($4.50 USD)
    if not exists (select 1 from public.installments where reseller_id = v_pablo_id and lower(referencia) like '%fernisbel%') then
      insert into public.installments (
        order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
        monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
      )
      select
        o.id, o.customer_id, v_pablo_id, 1, 1,
        4.50, round(4.50 * v_rate, 2), v_rate, '2026-10-30'::date, 'pendiente',
        '[CRÉDITO PABLO GONZALEZ] FERNISBEL - DISNEY ($4.50 USD)'
      from public.orders o
      where o.vendedor_id = v_pablo_id and (lower(o.referencia) like '%fernisbel%' or exists (select 1 from customers c where c.id = o.customer_id and lower(c.nombre) like '%fernisbel%'))
      limit 1;
    end if;

    -- C. TONY MASSIMO ($4.50 USD)
    if not exists (select 1 from public.installments where reseller_id = v_pablo_id and lower(referencia) like '%tony%') then
      insert into public.installments (
        order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
        monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
      )
      select
        o.id, o.customer_id, v_pablo_id, 1, 1,
        4.50, round(4.50 * v_rate, 2), v_rate, '2026-10-30'::date, 'pendiente',
        '[CRÉDITO PABLO GONZALEZ] TONY MASSIMO - TELELATINO ($4.50 USD)'
      from public.orders o
      where o.vendedor_id = v_pablo_id and (lower(o.referencia) like '%tony%' or exists (select 1 from customers c where c.id = o.customer_id and lower(c.nombre) like '%tony%'))
      limit 1;
    end if;

    -- 5. Sincronizar CUALQUIER orden reciente de crédito de Pablo que no tenga cuota
    for r in
      select o.id as ord_id, o.customer_id as cust_id, o.total_usd as monto, o.referencia as ref, o.created_at
      from public.orders o
      where o.vendedor_id = v_pablo_id
        and (lower(o.referencia) like '%[crédito%' or lower(o.referencia) like '%[renovación crédito%')
        and not exists (select 1 from public.installments i where i.order_id = o.id)
    loop
      insert into public.installments (
        order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
        monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
      ) values (
        r.ord_id,
        r.cust_id,
        v_pablo_id,
        1, 1,
        r.monto,
        round(r.monto * v_rate, 2),
        v_rate,
        (current_date + interval '7 days')::date,
        'pendiente',
        coalesce(r.ref, '[CRÉDITO PABLO GONZALEZ] Renovación de servicio')
      );
    end loop;

  end if;

  -- 6. Para cualquier otra orden a crédito en el sistema con vendedor_id asignado, asociar reseller_id en installments
  update public.installments i
  set reseller_id = o.vendedor_id
  from public.orders o
  where o.id = i.order_id and o.vendedor_id is not null and i.reseller_id is null;

end $$;
