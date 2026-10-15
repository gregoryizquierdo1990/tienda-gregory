-- ==============================================================================
-- Migración 23: Traslados Flexibles + Políticas Públicas de Mesa de Cambio
-- Emprendimiento Gregory Izquierdo
-- ==============================================================================

-- 1. Políticas RLS en tabla settings para que los clientes vean la tasa real en su teléfono
drop policy if exists pub_settings on settings;
create policy pub_settings on settings for select using (
  key in ('negocio', 'zeny', 'reserva', 'app', 'mesa_cambio_config', 'cuotas_config', 'plantillas_mensajes', 'niveles_beneficios')
);

-- 2. Políticas RLS en tabla transfers
drop policy if exists tr_admin on transfers;
drop policy if exists tr_admin_all on transfers;
create policy tr_admin_all on transfers for all to authenticated
  using (is_admin()) with check (is_admin());

-- 3. Función maestra de traslado y reposición de servicios
create or replace function transfer_service(
  p_from_profile uuid,
  p_to_profile uuid,
  p_motivo text default '',
  p_liberar_anterior boolean default false,
  p_order uuid default null,
  p_nueva_fecha_vence date default null,
  p_permitir_otra_plataforma boolean default true
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_from record;
  v_to record;
  v_from_mat record;
  v_to_mat record;
  v_order record;
  v_order_id uuid := p_order;
  v_customer_id uuid;
  v_vence date;
  v_inicia date;
  v_pass_revelada text := '';
begin
  if not is_admin() then
    raise exception 'No autorizado';
  end if;

  if p_from_profile = p_to_profile then
    raise exception 'El perfil destino no puede ser igual al de origen';
  end if;

  -- Perfil origen
  select * into v_from from profiles_inventory where id = p_from_profile for update;
  if not found then
    raise exception 'Perfil origen no encontrado';
  end if;
  select * into v_from_mat from mother_accounts where id = v_from.mother_id;

  -- Perfil destino
  select * into v_to from profiles_inventory where id = p_to_profile for update;
  if not found then
    raise exception 'Perfil destino no encontrado';
  end if;
  if v_to.estado <> 'disponible' then
    raise exception 'El perfil destino no esta disponible (estado: %)', v_to.estado;
  end if;
  select * into v_to_mat from mother_accounts where id = v_to.mother_id;

  -- Validar plataformas si no se permite cruce
  if not p_permitir_otra_plataforma and v_from_mat.plataforma is distinct from v_to_mat.plataforma then
    raise exception 'El traslado debe ser en la misma plataforma (% / %)', v_from_mat.plataforma, v_to_mat.plataforma;
  end if;

  -- Asociar pedido
  if v_order_id is not null then
    select * into v_order from orders where id = v_order_id for update;
    if found then
      v_customer_id := v_order.customer_id;
    end if;
  else
    select * into v_order from orders
    where profile_id = p_from_profile and estado in ('entregado', 'pagado')
    order by created_at desc limit 1 for update;
    if found then
      v_order_id := v_order.id;
      v_customer_id := v_order.customer_id;
    end if;
  end if;

  -- Fechas
  v_inicia := coalesce(v_from.inicia, current_date);
  if p_nueva_fecha_vence is not null then
    v_vence := p_nueva_fecha_vence;
  elsif v_order.id is not null and v_order.vence is not null then
    v_vence := v_order.vence;
  else
    v_vence := coalesce(v_from.vence, (current_date + interval '30 days')::date);
  end if;

  -- 1. Perfil destino -> vendido
  update profiles_inventory set
    estado = 'vendido',
    inicia = v_inicia,
    vence = v_vence
  where id = p_to_profile;

  -- 2. Perfil origen -> suspendido o disponible
  update profiles_inventory set
    estado = case when p_liberar_anterior then 'disponible' else 'suspendido' end,
    inicia = null,
    vence = null
  where id = p_from_profile;

  -- 3. Actualizar pedido si existe
  if v_order_id is not null then
    update orders set
      profile_id = p_to_profile,
      product_id = coalesce(v_to.product_id, orders.product_id),
      vence = v_vence
    where id = v_order_id;
  end if;

  -- 4. Registrar en transfers
  insert into transfers (order_id, customer_id, from_profile, to_profile, motivo)
  values (v_order_id, v_customer_id, p_from_profile, p_to_profile, p_motivo);

  -- Revelar clave si es enc
  begin
    if v_to_mat.clave like 'enc:%' then
      v_pass_revelada := reveal_secret(v_to_mat.clave);
    else
      v_pass_revelada := v_to_mat.clave;
    end if;
  exception when others then
    v_pass_revelada := v_to_mat.clave;
  end;

  return jsonb_build_object(
    'success', true,
    'mensaje', 'Traslado completado con exito',
    'origen_plataforma', v_from_mat.plataforma,
    'origen_correo', v_from_mat.correo,
    'origen_perfil', v_from.nombre_perfil,
    'destino_plataforma', v_to_mat.plataforma,
    'destino_correo', v_to_mat.correo,
    'destino_clave', v_pass_revelada,
    'destino_perfil', v_to.nombre_perfil,
    'destino_pin', coalesce(v_to.pin, ''),
    'vence', v_vence,
    'order_id', v_order_id,
    'customer_id', v_customer_id
  );
end $$;

-- 4. Compatibilidad con funcion transfer_order previa
create or replace function transfer_order(
  p_order uuid,
  p_new_profile uuid,
  p_motivo text,
  p_liberar_anterior boolean default true
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_pid uuid;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select profile_id into v_pid from orders where id = p_order;
  if not found or v_pid is null then
    raise exception 'El pedido no tiene perfil asignado';
  end if;
  perform transfer_service(v_pid, p_new_profile, p_motivo, p_liberar_anterior, p_order, null, true);
end $$;

revoke execute on function transfer_service(uuid, uuid, text, boolean, uuid, date, boolean) from public;
grant execute on function transfer_service(uuid, uuid, text, boolean, uuid, date, boolean) to authenticated;

revoke execute on function transfer_order(uuid, uuid, text, boolean) from public;
grant execute on function transfer_order(uuid, uuid, text, boolean) to authenticated;
