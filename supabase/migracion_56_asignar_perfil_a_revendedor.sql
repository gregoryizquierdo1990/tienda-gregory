-- ==============================================================================
-- MIGRACIÓN 56: ASIGNACIÓN Y GESTIÓN DE PERFILES A REVENDEDORES DESDE EL PANEL ADMIN
-- 1. Función RPC admin_assign_profile_reseller para vincular/desvincular perfiles y clientes a revendedores
-- 2. Corrección y sincronización automática de vendedor_id para perfiles históricos
-- ==============================================================================

-- 1. Sincronizar perfiles existentes que tengan 'PABLO' con su vendedor_id correspondiente
update public.profiles_inventory
set vendedor_id = 'b7fa01a4-baf1-4818-a81b-4fcbbfbeae0c',
    vendedor = 'Pablo Gonzalez'
where lower(trim(coalesce(vendedor, ''))) in ('pablo', 'pablo gonzalez')
  and (vendedor_id is null or vendedor_id != 'b7fa01a4-baf1-4818-a81b-4fcbbfbeae0c');

-- 2. RPC para que el Administrador asigne perfiles a revendedores
create or replace function public.admin_assign_profile_reseller(
  p_profile_id uuid,
  p_reseller_id uuid,
  p_cliente_final text default null,
  p_cliente_telefono text default null,
  p_marcar_vendido boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_is_adm boolean := false;
  v_reseller_name text := null;
  v_reseller_code text := null;
  v_cur_estado text;
  v_clean_client text := nullif(trim(p_cliente_final), '');
  v_clean_tel text := nullif(trim(p_cliente_telefono), '');
begin
  -- Solo administradores pueden ejecutar esta función
  v_is_adm := is_admin();
  if not v_is_adm then
    raise exception 'Acceso denegado: solo el administrador puede asignar perfiles a revendedores.';
  end if;

  select estado into v_cur_estado from public.profiles_inventory where id = p_profile_id;
  if v_cur_estado is null then
    raise exception 'El perfil especificado no existe.';
  end if;

  if p_reseller_id is not null then
    -- Obtener datos del revendedor
    select nombre, codigo_identificacion
    into v_reseller_name, v_reseller_code
    from public.customers
    where id = p_reseller_id;

    if v_reseller_name is null then
      raise exception 'El revendedor seleccionado no existe o no tiene nombre registrado.';
    end if;

    -- Asignar perfil al revendedor
    update public.profiles_inventory
    set vendedor_id = p_reseller_id,
        vendedor = v_reseller_name,
        cliente_final = coalesce(v_clean_client, cliente_final),
        cliente_telefono = coalesce(v_clean_tel, cliente_telefono),
        estado = case when p_marcar_vendido and v_cur_estado = 'disponible' then 'vendido' else estado end,
        inicia = case when p_marcar_vendido and v_cur_estado = 'disponible' and inicia is null then current_date else inicia end,
        vence = case when p_marcar_vendido and v_cur_estado = 'disponible' and vence is null then (current_date + interval '30 days')::date else vence end
    where id = p_profile_id;

    -- Sincronizar órdenes asociadas
    update public.orders
    set vendedor_id = p_reseller_id,
        vendedor_nombre = v_reseller_name
    where profile_id = p_profile_id;

    return jsonb_build_object(
      'success', true,
      'profile_id', p_profile_id,
      'vendedor_id', p_reseller_id,
      'vendedor', v_reseller_name,
      'cliente_final', v_clean_client,
      'cliente_telefono', v_clean_tel,
      'message', format('Perfil asignado con éxito al revendedor %s', v_reseller_name)
    );
  else
    -- Desasignar: devolver a Tienda Central (Gregory / Venta Directa)
    update public.profiles_inventory
    set vendedor_id = null,
        vendedor = null,
        cliente_final = coalesce(v_clean_client, cliente_final),
        cliente_telefono = coalesce(v_clean_tel, cliente_telefono)
    where id = p_profile_id;

    update public.orders
    set vendedor_id = null,
        vendedor_nombre = null
    where profile_id = p_profile_id;

    return jsonb_build_object(
      'success', true,
      'profile_id', p_profile_id,
      'vendedor_id', null,
      'vendedor', null,
      'cliente_final', v_clean_client,
      'cliente_telefono', v_clean_tel,
      'message', 'Perfil transferido a Tienda Central (sin revendedor asignado)'
    );
  end if;
end;
$$;

revoke execute on function public.admin_assign_profile_reseller(uuid, uuid, text, text, boolean) from public, anon;
grant execute on function public.admin_assign_profile_reseller(uuid, uuid, text, text, boolean) to authenticated;
