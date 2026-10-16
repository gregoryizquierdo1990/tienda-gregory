-- ==============================================================================
-- MIGRACIÓN 42: Control de Vencimientos para Revendedores y Reporte de No Renovación
-- ==============================================================================

-- 1. Agregar columnas en profiles_inventory y orders para rastrear reportes de no renovación
alter table public.profiles_inventory add column if not exists no_renueva boolean default false;
alter table public.profiles_inventory add column if not exists no_renueva_reportado_at timestamptz;
alter table public.profiles_inventory add column if not exists no_renueva_motivo text;
alter table public.profiles_inventory add column if not exists no_renueva_por text;

alter table public.orders add column if not exists no_renueva boolean default false;
alter table public.orders add column if not exists no_renueva_reportado_at timestamptz;

-- 2. Actualizar función liberar_perfil_inventario para resetear las banderas de no_renueva
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

  -- 1. Actualizar el perfil a disponible y limpiar datos de asignación y banderas
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

-- 3. RPC Oficial: reportar_no_renovacion_perfil
-- Permite al revendedor o al administrador reportar que su cliente no renovará el servicio
create or replace function public.reportar_no_renovacion_perfil(
  p_profile_id uuid,
  p_motivo text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_user_id uuid := auth.uid();
  v_caller_name text := 'Revendedor';
  v_prof profiles_inventory;
begin
  if v_user_id is null then
    raise exception 'No autenticado.';
  end if;

  select coalesce(nombre, email, 'Revendedor') into v_caller_name from customers where id = v_user_id;

  select * into v_prof from profiles_inventory where id = p_profile_id for update;
  if not found then
    raise exception 'Perfil no encontrado.';
  end if;

  -- Verificar autorización: admin, o asignado al revendedor, o vendedor del perfil, o comprador en orders
  if not is_admin() then
    if coalesce(v_prof.assigned_customer_id, '00000000-0000-0000-0000-000000000000'::uuid) <> v_user_id 
       and coalesce(v_prof.vendedor_id, '00000000-0000-0000-0000-000000000000'::uuid) <> v_user_id 
       and not exists (
         select 1 from orders o 
         where o.profile_id = p_profile_id 
           and (o.customer_id = v_user_id or o.vendedor_id = v_user_id)
       ) then
      raise exception 'No tienes permisos sobre este perfil.';
    end if;
  end if;

  -- Marcar perfil como no renueva
  update profiles_inventory
  set 
    no_renueva = true,
    no_renueva_reportado_at = now(),
    no_renueva_motivo = coalesce(p_motivo, 'El cliente no desea renovar'),
    no_renueva_por = coalesce(v_caller_name, 'Revendedor')
  where id = p_profile_id;

  -- Marcar en órdenes vinculadas
  update orders
  set 
    no_renueva = true,
    no_renueva_reportado_at = now()
  where profile_id = p_profile_id
    and estado in ('entregado', 'pagado');

  return jsonb_build_object(
    'ok', true,
    'profile_id', p_profile_id,
    'mensaje', 'Reportado con éxito. El administrador ha sido notificado para liberar el perfil.'
  );
end;
$$;

revoke execute on function public.reportar_no_renovacion_perfil(uuid, text) from public, anon;
grant execute on function public.reportar_no_renovacion_perfil(uuid, text) to authenticated;

-- 4. Actualizar función my_reseller_clients() con la columna no_renueva
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
  no_renueva boolean
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
    -- Administrador: SOLO clientes y perfiles de DIRECTO TIENDA
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
      coalesce(pi.no_renueva, false) as no_renueva
    from profiles_inventory pi
    join mother_accounts m on m.id = pi.mother_id
    left join products p on p.id = pi.product_id
    left join customers c on c.id = pi.assigned_customer_id
    left join orders o on o.profile_id = pi.id and o.estado in ('entregado', 'pagado')
    left join customers o_cust on o_cust.id = o.customer_id
    where (
      (pi.vendedor_id is null and coalesce(c.vendedor_id, o.vendedor_id) is null)
      or lower(trim(coalesce(pi.vendedor, ''))) in ('directo tienda', 'tienda', 'directo')
      or lower(trim(coalesce(c.vendedor_nombre, o_cust.vendedor_nombre, ''))) in ('directo tienda', 'tienda', 'directo')
    )
    order by vence asc nulls last;

  else
    -- Revendedor (Pablo, Nelson, etc.): Sus clientes asignados y compras
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
      coalesce(pi.no_renueva, false) as no_renueva
    from profiles_inventory pi
    join mother_accounts m on m.id = pi.mother_id
    left join products p on p.id = pi.product_id
    left join customers c on c.id = pi.assigned_customer_id
    left join orders o on o.profile_id = pi.id and o.estado in ('entregado', 'pagado')
    left join customers o_cust on o_cust.id = o.customer_id
    where (
      pi.vendedor_id = v_user_id
      or c.vendedor_id = v_user_id
      or o.vendedor_id = v_user_id
      or pi.assigned_customer_id = v_user_id
      or o.customer_id = v_user_id
      or (pi.vendedor is not null and v_seller_name is not null and lower(trim(pi.vendedor)) = lower(trim(v_seller_name)))
    )
    order by vence asc nulls last;
  end if;
end;
$$;

revoke execute on function public.my_reseller_clients() from public, anon;
grant execute on function public.my_reseller_clients() to authenticated;
