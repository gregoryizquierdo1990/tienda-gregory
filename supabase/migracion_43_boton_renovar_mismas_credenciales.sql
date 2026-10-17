-- Migracion 43: Procedimiento Almacenado para Renovación de Perfiles Manteniendo Mismas Credenciales
-- Permite que Revendedores y Clientes Finales renueven su misma suscripción (+30 días)
-- sin acudir a la tienda a comprar un perfil nuevo desde cero.

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
  v_cred_used numeric(12,2) := 0;
  v_order_id uuid;
  v_cli_nom text := 'Cliente';
  v_srv_nom text := 'Servicio Digital';
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

  -- 2. Verificar permisos de acceso al perfil
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

  -- 3. Obtener producto y madre
  select * into v_prod from products where id = v_prof.product_id;
  select * into v_mother from mother_accounts where id = v_prof.mother_id;
  v_srv_nom := coalesce(v_prod.nombre, v_mother.plataforma, 'Servicio Digital');

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

  -- 7. Procesar según método de pago
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
    values (v_user_id, 'compra', -v_precio, 'aprobado', 'Renovación +30d ' || v_srv_nom || ' (Perfil ' || coalesce(v_prof.nombre_perfil, 'P1') || ')');

    -- Actualizar saldo en customers
    update customers set zeny_balance = coalesce(zeny_balance, 0) - v_precio where id = v_user_id;

    -- Actualizar profiles_inventory manteniendo las credenciales
    update profiles_inventory set
      vence = v_next_vence,
      estado = 'vendido',
      no_renueva = false
    where id = p_profile_id;

    -- Sincronizar orders vinculadas
    update orders set
      vence = v_next_vence,
      proximo_pago = v_next_vence
    where profile_id = p_profile_id;

    -- Registrar la orden de renovación completada
    insert into orders (
      customer_id, vendedor_id, profile_id, product_id,
      total_usd, tasa_bs, total_bs, estado,
      referencia, vence, proximo_pago, pagado_at, entregado_at
    ) values (
      v_user_id,
      case when v_is_reseller then v_user_id else v_prof.vendedor_id end,
      p_profile_id,
      v_prof.product_id,
      v_precio,
      v_bcv,
      v_precio * v_bcv,
      'entregado',
      '[RENOVACIÓN ZENY] ' || v_srv_nom || ' (Mismas Credenciales)',
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
      no_renueva = false
    where id = p_profile_id;

    update orders set
      vence = v_next_vence,
      proximo_pago = v_next_vence
    where profile_id = p_profile_id;

    insert into orders (
      customer_id, vendedor_id, profile_id, product_id,
      total_usd, tasa_bs, total_bs, estado,
      referencia, vence, proximo_pago, pagado_at, entregado_at
    ) values (
      v_user_id,
      v_user_id,
      p_profile_id,
      v_prof.product_id,
      v_precio,
      v_bcv,
      v_precio * v_bcv,
      'entregado',
      '[RENOVACIÓN CRÉDITO] Cobrar antes de ' || (current_date + interval '7 days')::date || ' ($' || v_precio || ' USD)',
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
      'mensaje', 'Suscripción renovada a crédito por 30 días.'
    );

  elsif p_metodo = 'transferencia' then
    if p_referencia is null or trim(p_referencia) = '' then
      raise exception 'Debes ingresar el número de referencia de la transferencia o Pago Móvil.';
    end if;

    -- Registrar orden pendiente para que Gregory la concilie
    insert into orders (
      customer_id, vendedor_id, profile_id, product_id,
      metodo_id, total_usd, tasa_bs, total_bs, estado,
      referencia, vence, proximo_pago
    ) values (
      v_user_id,
      case when v_is_reseller then v_user_id else v_prof.vendedor_id end,
      p_profile_id,
      v_prof.product_id,
      p_metodo_id,
      v_precio,
      v_bcv,
      v_precio * v_bcv,
      'pendiente',
      '[RENOVACIÓN PENDIENTE] Ref: ' || trim(p_referencia) || ' (' || v_srv_nom || ')',
      v_next_vence,
      v_next_vence
    ) returning id into v_order_id;

    return jsonb_build_object(
      'success', true,
      'estado', 'pendiente',
      'order_id', v_order_id,
      'nuevo_vencimiento', v_next_vence,
      'total_usd', v_precio,
      'mensaje', 'Solicitud de renovación registrada. Se activará una vez verificado el pago.'
    );

  else
    raise exception 'Método de pago no válido (debe ser zeny, credito o transferencia).';
  end if;
end;
$$;

revoke execute on function public.renovar_suscripcion_perfil(uuid, text, uuid, text) from public, anon;
grant execute on function public.renovar_suscripcion_perfil(uuid, text, uuid, text) to authenticated;
