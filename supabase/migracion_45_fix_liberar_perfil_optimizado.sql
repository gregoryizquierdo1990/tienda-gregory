-- ==============================================================================
-- MIGRACIÓN 45: Optimización de función liberar_perfil_inventario (Sin bloqueos)
-- ==============================================================================
-- 1. Elimina 'for update' que provocaba deadlocks o bloqueos indefinidos en sesiones concurrentes.
-- 2. Asegura limpieza atómica de flags de no_renueva en profiles_inventory y orders.
-- 3. Limpia cliente asignado, fechas y deja el perfil en stock disponible para venta inmediata.

create or replace function public.liberar_perfil_inventario(
  p_profile_id uuid,
  p_nuevo_pin text default null,
  p_nuevo_nombre text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_orders_updated int := 0;
  v_profile_exists boolean := false;
begin
  if not is_admin() then
    raise exception 'No autorizado. Solo administradores pueden liberar perfiles.';
  end if;

  select exists(select 1 from profiles_inventory where id = p_profile_id) into v_profile_exists;
  if not v_profile_exists then
    raise exception 'Perfil no encontrado en inventario.';
  end if;

  -- 1. Actualizar el perfil a disponible y limpiar asignaciones y banderas de no renovación
  update profiles_inventory
  set 
    estado = 'disponible',
    inicia = null,
    vence = null,
    assigned_customer_id = null,
    pin = coalesce(nullif(trim(p_nuevo_pin), ''), pin),
    nombre_perfil = coalesce(nullif(trim(p_nuevo_nombre), ''), nombre_perfil),
    no_renueva = false,
    no_renueva_reportado_at = null,
    no_renueva_motivo = null,
    no_renueva_por = null
  where id = p_profile_id;

  -- 2. Marcar las órdenes activas vinculadas como vencidas
  update orders
  set estado = 'vencido',
      no_renueva = false
  where profile_id = p_profile_id
    and estado in ('entregado', 'pagado');
  get diagnostics v_orders_updated = row_count;

  return jsonb_build_object(
    'ok', true,
    'profile_id', p_profile_id,
    'orders_closed', v_orders_updated,
    'mensaje', 'Perfil liberado con éxito. Ya está en stock y disponible para la venta en la tienda.'
  );
end;
$$;

revoke execute on function public.liberar_perfil_inventario(uuid, text, text) from public, anon;
grant execute on function public.liberar_perfil_inventario(uuid, text, text) to authenticated;
