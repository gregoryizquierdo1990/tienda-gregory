-- ==============================================================================
-- Migración 25: Registro de 4 Revendedores Oficiales, Estructura de Red de Ventas
-- y Función my_reseller_clients() para el Portal del Revendedor
-- Emprendimiento Gregory Izquierdo
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. GARANTIZAR COLUMNAS EN CUSTOMERS, PROFILES_INVENTORY, ORDERS Y TABLA ZENY_CARDS
-- ------------------------------------------------------------------------------
alter table customers add column if not exists debe_cambiar_password boolean default false;
alter table customers add column if not exists nivel_credito text not null default 'Bronce';
alter table customers add column if not exists codigo_identificacion text;
alter table customers add column if not exists limite_credito numeric(10,2) default 0.00;
alter table customers add column if not exists zeny_balance numeric(10,2) default 0.00;
alter table customers add column if not exists es_revendedor boolean default false;
alter table customers add column if not exists es_franquicia boolean default false;
alter table customers add column if not exists vendedor_id uuid references customers(id) on delete set null;
alter table customers add column if not exists vendedor_nombre text;

alter table profiles_inventory add column if not exists vendedor text;
alter table profiles_inventory add column if not exists vendedor_id uuid references customers(id) on delete set null;
alter table profiles_inventory add column if not exists assigned_customer_id uuid references customers(id) on delete set null;

alter table orders add column if not exists vendedor_id uuid references customers(id) on delete set null;

create index if not exists idx_customers_vendedor on customers(vendedor_id);
create index if not exists idx_profiles_vendedor on profiles_inventory(vendedor_id);
create index if not exists idx_profiles_assigned_cust on profiles_inventory(assigned_customer_id);
create index if not exists idx_orders_vendedor on orders(vendedor_id);

-- Asegurar estructura de zeny_cards por si no fue creada previamente
create table if not exists zeny_cards (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade unique,
  numero_tarjeta text not null unique,
  nombre_titular text not null,
  codigo_activacion text not null,
  fecha_vencimiento text not null default '12/31',
  estado text not null default 'activa' check (estado in ('activa', 'por_activar', 'bloqueada', 'vencida')),
  descuento_porcentaje numeric(5,2) not null default 5.00,
  activada_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_zeny_cards_customer on zeny_cards(customer_id);
create index if not exists idx_zeny_cards_numero on zeny_cards(numero_tarjeta);


-- ------------------------------------------------------------------------------
-- 2. REGISTRO Y ACTIVACIÓN DE LOS 4 REVENDEDORES OFICIALES
-- ------------------------------------------------------------------------------
do $$
declare
  v_uid uuid;
  v_enc text;
begin
  -- 1. PABLO GONZALEZ (584129130080, pacun1989@gmail.com, clave temporal: 130080)
  select id into v_uid from auth.users where lower(email) in ('pacun1989@gmail.com', '584129130080@cliente.gregoryizquierdo.xyz');
  v_enc := extensions.crypt('130080', extensions.gen_salt('bf'));
  if v_uid is null then
    v_uid := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_uid, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'pacun1989@gmail.com', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"nombre":"Pablo Gonzalez","telefono":"584129130080","full_name":"Pablo Gonzalez"}'::jsonb, now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','Pablo Gonzalez','telefono','584129130080','full_name','Pablo Gonzalez') where id = v_uid;
  end if;

  insert into customers(id, nombre, email, telefono, es_revendedor, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_uid, 'Pablo Gonzalez', 'pacun1989@gmail.com', '584129130080', true, 'RVD:1001', 100.00, 'Oro', true)
  on conflict (id) do update set
    nombre = 'Pablo Gonzalez',
    email = 'pacun1989@gmail.com',
    telefono = '584129130080',
    es_revendedor = true,
    limite_credito = coalesce(customers.limite_credito, 100.00),
    nivel_credito = coalesce(customers.nivel_credito, 'Oro'),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true),
    codigo_identificacion = coalesce(customers.codigo_identificacion, 'RVD:1001');

  insert into zeny_cards(customer_id, numero_tarjeta, nombre_titular, fecha_vencimiento, codigo_activacion, estado)
  values (v_uid, '4532 9801 0080 3456', 'PABLO GONZALEZ', '10/28', '130080', 'activa')
  on conflict do nothing;


  -- 2. LEANDRO PERDOMO (584122952044, perdomoleandro39@gmail.com, clave temporal: 952044)
  select id into v_uid from auth.users where lower(email) in ('perdomoleandro39@gmail.com', '584122952044@cliente.gregoryizquierdo.xyz');
  v_enc := extensions.crypt('952044', extensions.gen_salt('bf'));
  if v_uid is null then
    v_uid := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_uid, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'perdomoleandro39@gmail.com', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"nombre":"Leandro Perdomo","telefono":"584122952044","full_name":"Leandro Perdomo"}'::jsonb, now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','Leandro Perdomo','telefono','584122952044','full_name','Leandro Perdomo') where id = v_uid;
  end if;

  insert into customers(id, nombre, email, telefono, es_revendedor, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_uid, 'Leandro Perdomo', 'perdomoleandro39@gmail.com', '584122952044', true, 'RVD:1002', 100.00, 'Oro', true)
  on conflict (id) do update set
    nombre = 'Leandro Perdomo',
    email = 'perdomoleandro39@gmail.com',
    telefono = '584122952044',
    es_revendedor = true,
    limite_credito = coalesce(customers.limite_credito, 100.00),
    nivel_credito = coalesce(customers.nivel_credito, 'Oro'),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true),
    codigo_identificacion = coalesce(customers.codigo_identificacion, 'RVD:1002');

  insert into zeny_cards(customer_id, numero_tarjeta, nombre_titular, fecha_vencimiento, codigo_activacion, estado)
  values (v_uid, '4532 9802 2044 3456', 'LEANDRO PERDOMO', '10/28', '952044', 'activa')
  on conflict do nothing;


  -- 3. NELSON BUSTAMANTE (584120266710, clave temporal: 266710)
  select id into v_uid from auth.users where lower(email) in ('584120266710@cliente.gregoryizquierdo.xyz', '04120266710@cliente.gregoryizquierdo.xyz');
  v_enc := extensions.crypt('266710', extensions.gen_salt('bf'));
  if v_uid is null then
    v_uid := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_uid, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584120266710@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"nombre":"Nelson Bustamante","telefono":"584120266710","full_name":"Nelson Bustamante"}'::jsonb, now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','Nelson Bustamante','telefono','584120266710','full_name','Nelson Bustamante') where id = v_uid;
  end if;

  insert into customers(id, nombre, email, telefono, es_revendedor, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_uid, 'Nelson Bustamante', '584120266710@cliente.gregoryizquierdo.xyz', '584120266710', true, 'RVD:1003', 100.00, 'Oro', true)
  on conflict (id) do update set
    nombre = 'Nelson Bustamante',
    telefono = '584120266710',
    es_revendedor = true,
    limite_credito = coalesce(customers.limite_credito, 100.00),
    nivel_credito = coalesce(customers.nivel_credito, 'Oro'),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true),
    codigo_identificacion = coalesce(customers.codigo_identificacion, 'RVD:1003');

  insert into zeny_cards(customer_id, numero_tarjeta, nombre_titular, fecha_vencimiento, codigo_activacion, estado)
  values (v_uid, '4532 9803 6710 3456', 'NELSON BUSTAMANTE', '10/28', '266710', 'activa')
  on conflict do nothing;


  -- 4. JOSUANNY (584129939848, clave temporal: 939848)
  select id into v_uid from auth.users where lower(email) in ('584129939848@cliente.gregoryizquierdo.xyz', '04129939848@cliente.gregoryizquierdo.xyz');
  v_enc := extensions.crypt('939848', extensions.gen_salt('bf'));
  if v_uid is null then
    v_uid := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_uid, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584129939848@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"nombre":"Josuanny","telefono":"584129939848","full_name":"Josuanny"}'::jsonb, now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','Josuanny','telefono','584129939848','full_name','Josuanny') where id = v_uid;
  end if;

  insert into customers(id, nombre, email, telefono, es_revendedor, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_uid, 'Josuanny', '584129939848@cliente.gregoryizquierdo.xyz', '584129939848', true, 'RVD:1004', 100.00, 'Oro', true)
  on conflict (id) do update set
    nombre = 'Josuanny',
    telefono = '584129939848',
    es_revendedor = true,
    limite_credito = coalesce(customers.limite_credito, 100.00),
    nivel_credito = coalesce(customers.nivel_credito, 'Oro'),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true),
    codigo_identificacion = coalesce(customers.codigo_identificacion, 'RVD:1004');

  insert into zeny_cards(customer_id, numero_tarjeta, nombre_titular, fecha_vencimiento, codigo_activacion, estado)
  values (v_uid, '4532 9804 9848 3456', 'JOSUANNY', '10/28', '939848', 'activa')
  on conflict do nothing;
end $$;


-- ------------------------------------------------------------------------------
-- 3. FUNCIÓN RPC: my_reseller_clients()
-- Devuelve a cada revendedor en su portal los accesos descifrados de sus clientes
-- ------------------------------------------------------------------------------
create or replace function my_reseller_clients()
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
  estado text
)
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_seller_name text;
begin
  if auth.uid() is null then return; end if;

  select nombre into v_seller_name from customers where id = auth.uid();

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
    pi.estado as estado
  from profiles_inventory pi
  join mother_accounts m on m.id = pi.mother_id
  left join products p on p.id = pi.product_id
  left join customers c on c.id = pi.assigned_customer_id
  left join orders o on o.profile_id = pi.id and o.estado in ('entregado', 'pagado')
  left join customers o_cust on o_cust.id = o.customer_id
  where (
    pi.vendedor_id = auth.uid()
    or (c.vendedor_id = auth.uid())
    or (o.vendedor_id = auth.uid())
    or (pi.vendedor is not null and v_seller_name is not null and lower(trim(pi.vendedor)) = lower(trim(v_seller_name)))
    or is_admin()
  )
  order by vence asc nulls last;
end;
$$;

revoke execute on function my_reseller_clients() from public, anon;
grant execute on function my_reseller_clients() to authenticated;


-- ------------------------------------------------------------------------------
-- 4. FUNCIÓN RPC: asignar_cliente_a_vendedor(cliente_id, vendedor_id)
-- Permite al Administrador asignar un cliente que compró en la tienda a un vendedor
-- ------------------------------------------------------------------------------
create or replace function asignar_cliente_a_vendedor(p_cliente_id uuid, p_vendedor_id uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_vendedor_nom text := null;
begin
  if not is_admin() then
    raise exception 'No autorizado: se requieren permisos de administrador';
  end if;

  if p_vendedor_id is not null then
    select nombre into v_vendedor_nom from customers where id = p_vendedor_id and es_revendedor;
    if v_vendedor_nom is null then
      raise exception 'El vendedor especificado no existe o no tiene rol de revendedor';
    end if;
  end if;

  update customers
  set vendedor_id = p_vendedor_id,
      vendedor_nombre = v_vendedor_nom
  where id = p_cliente_id;

  -- Actualizar pedidos del cliente
  update orders
  set vendedor_id = p_vendedor_id
  where customer_id = p_cliente_id;

  -- Actualizar inventario de perfiles asignados a este cliente
  update profiles_inventory
  set vendedor_id = p_vendedor_id,
      vendedor = v_vendedor_nom,
      assigned_customer_id = p_cliente_id
  where assigned_customer_id = p_cliente_id
     or id in (select profile_id from orders where customer_id = p_cliente_id and profile_id is not null);

  return jsonb_build_object(
    'success', true,
    'cliente_id', p_cliente_id,
    'vendedor_id', p_vendedor_id,
    'vendedor_nombre', v_vendedor_nom
  );
end;
$$;

grant execute on function asignar_cliente_a_vendedor(uuid, uuid) to authenticated;
