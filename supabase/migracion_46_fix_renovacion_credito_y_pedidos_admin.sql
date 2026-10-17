-- ==============================================================================
-- MIGRACIÓN 46: Fix de Renovación a Crédito de Revendedores y Registro en Cuotas
-- ==============================================================================
-- 1. Resuelve el conflicto con el índice único 'orders_profile_activo':
--    Al renovar un perfil, la orden del ciclo anterior se marca como 'vencido',
--    permitiendo insertar la nueva orden del nuevo ciclo sin violar la unicidad.
-- 2. Registra automáticamente la deuda en 'installments' cuando un revendedor
--    utiliza su línea de crédito para renovar un perfil (con plazo de 7 días).
-- 3. Sincroniza la deuda de las renovaciones recientes realizadas por Pablo González
--    o cualquier revendedor para que aparezcan en Cobranza Cuotas y Pedidos.

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

-- ==============================================================================
-- 2. Asegurar que cualquier renovación previa a crédito de Pablo quede registrada
-- ==============================================================================
do $$
declare
  v_pablo_id uuid;
  v_rate numeric := 1;
  r record;
begin
  select bs_por_usd into v_rate from public.exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_rate, 1);

  select id into v_pablo_id from public.customers
  where lower(trim(email)) in ('pacun1989@gmail.com', 'pablo@gregoryizquierdo.xyz')
     or codigo_identificacion in ('PABLO', 'RVD:1001')
     or lower(trim(nombre)) like '%pablo gonzalez%'
  limit 1;

  if v_pablo_id is not null then
    -- Buscar órdenes de crédito de Pablo que no tengan cuota en installments
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
end $$;
