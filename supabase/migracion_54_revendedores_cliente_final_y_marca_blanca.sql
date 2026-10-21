-- ==============================================================================
-- MIGRACIÓN 54: GESTIÓN DE CLIENTE FINAL POR REVENDEDORES Y MENSAJE MARCA BLANCA
-- 1. Agregar columna cliente_telefono a profiles_inventory
-- 2. Función RPC reseller_set_cliente_final para que el revendedor asigne y personalice sus clientes
-- 3. Actualizar RPC my_reseller_clients para priorizar cliente_final y cliente_telefono
-- ==============================================================================

alter table public.profiles_inventory add column if not exists cliente_telefono text;

-- 2. RPC para que revendedores asignen nombre y teléfono a sus perfiles asignados
create or replace function public.reseller_set_cliente_final(
  p_profile_id uuid,
  p_cliente_nombre text,
  p_cliente_telefono text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_adm boolean := false;
  v_seller_name text := null;
  v_count integer := 0;
  v_clean_name text := nullif(trim(p_cliente_nombre), '');
  v_clean_tel text := nullif(trim(p_cliente_telefono), '');
begin
  if v_user_id is null then
    raise exception 'No autenticado';
  end if;

  v_is_adm := is_admin();
  select nombre into v_seller_name from customers where id = v_user_id;

  if not v_is_adm then
    select count(*) into v_count
    from profiles_inventory pi
    left join customers c on c.id = pi.assigned_customer_id
    left join orders o on o.profile_id = pi.id
    where pi.id = p_profile_id
      and (
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
      );

    if v_count = 0 then
      raise exception 'No tienes permisos sobre este perfil';
    end if;
  end if;

  update profiles_inventory
  set cliente_final = v_clean_name,
      cliente_telefono = coalesce(v_clean_tel, cliente_telefono)
  where id = p_profile_id;

  return jsonb_build_object(
    'success', true,
    'profile_id', p_profile_id,
    'cliente_final', v_clean_name,
    'cliente_telefono', v_clean_tel
  );
end;
$$;

revoke execute on function public.reseller_set_cliente_final(uuid, text, text) from public, anon;
grant execute on function public.reseller_set_cliente_final(uuid, text, text) to authenticated;

-- 3. my_reseller_clients() con cliente_final y cliente_telefono
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
      coalesce(nullif(trim(pi.cliente_final), ''), c.nombre, o_cust.nombre, 'Cliente Tienda') as cliente_nombre,
      coalesce(nullif(trim(pi.cliente_telefono), ''), c.telefono, o_cust.telefono, '') as cliente_telefono,
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
      coalesce(nullif(trim(pi.cliente_final), ''), c.nombre, o_cust.nombre, 'Cliente Asignado') as cliente_nombre,
      coalesce(nullif(trim(pi.cliente_telefono), ''), c.telefono, o_cust.telefono, '') as cliente_telefono,
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
