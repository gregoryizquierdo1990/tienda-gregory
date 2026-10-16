-- ==============================================================================
-- MIGRACIÓN 41: Función Oficial para Liberar Perfiles Vencidos para la Venta
-- ==============================================================================
-- Permite al Administrador liberar un perfil que venció (o no renovó):
-- 1. Cambia el estado del perfil en profiles_inventory a 'disponible'.
-- 2. Limpia fechas de inicio, vencimiento y cliente asignado.
-- 3. Opcionalmente actualiza el PIN o nombre del perfil si se cambió en la plataforma.
-- 4. Cierra las órdenes activas anteriores marcándolas como 'vencido'.
-- 5. Automáticamente se suma al stock disponible de la tienda para nuevos clientes.

create or replace function public.liberar_perfil_inventario(
  p_profile_id uuid,
  p_nuevo_pin text default null,
  p_nuevo_nombre text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_prof profiles_inventory;
  v_orders_updated int := 0;
begin
  if not is_admin() then
    raise exception 'No autorizado. Solo administradores pueden liberar perfiles.';
  end if;

  select * into v_prof from profiles_inventory where id = p_profile_id for update;
  if not found then
    raise exception 'Perfil no encontrado en inventario.';
  end if;

  -- 1. Actualizar el perfil a disponible
  update profiles_inventory
  set 
    estado = 'disponible',
    inicia = null,
    vence = null,
    assigned_customer_id = null,
    pin = coalesce(nullif(trim(p_nuevo_pin), ''), pin),
    nombre_perfil = coalesce(nullif(trim(p_nuevo_nombre), ''), nombre_perfil)
  where id = p_profile_id;

  -- 2. Marcar las órdenes activas vinculadas como vencidas
  update orders
  set estado = 'vencido'
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
