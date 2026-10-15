-- ==============================================================================
-- Migración 26: Asignación Masiva de Clientes y Perfiles a Revendedores
-- (Pablo, Nelson, Leandro, Josuanny y Directo Tienda)
-- Emprendimiento Gregory Izquierdo
-- ==============================================================================

-- 1. Asegurar columnas en customers, profiles_inventory y orders
alter table customers add column if not exists debe_cambiar_password boolean default false;
alter table customers add column if not exists nivel_credito text not null default 'Bronce';
alter table customers add column if not exists codigo_identificacion text;
alter table customers add column if not exists limite_credito numeric(10,2) default 0.00;
alter table customers alter column limite_credito set default 0.00;
alter table customers add column if not exists zeny_balance numeric(10,2) default 0.00;
alter table customers add column if not exists es_revendedor boolean default false;
alter table customers add column if not exists vendedor_id uuid references customers(id) on delete set null;
alter table customers add column if not exists vendedor_nombre text;
alter table profiles_inventory add column if not exists vendedor text;
alter table profiles_inventory add column if not exists vendedor_id uuid references customers(id) on delete set null;
alter table profiles_inventory add column if not exists assigned_customer_id uuid references customers(id) on delete set null;
alter table orders add column if not exists vendedor_id uuid references customers(id) on delete set null;

do $$
declare
  v_pablo_id uuid;
  v_nelson_id uuid;
  v_josuanny_id uuid;
  v_leandro_id uuid;
  v_cust_id uuid;
  v_seller_id uuid;
  v_seller_nom text;
  v_prof_id uuid;
  v_enc text;
  v_rate numeric;
  v_cod text;
begin
  select bs_por_usd into v_rate from exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_rate, 50.00);

  -- Obtener IDs de los 4 Revendedores Oficiales
  select id into v_pablo_id from customers where lower(email) in ('pacun1989@gmail.com', '584129130080@cliente.gregoryizquierdo.xyz') or codigo_identificacion = 'RVD:1001' limit 1;
  select id into v_nelson_id from customers where lower(email) in ('584120266710@cliente.gregoryizquierdo.xyz') or codigo_identificacion = 'RVD:1003' limit 1;
  select id into v_josuanny_id from customers where lower(email) in ('584129939848@cliente.gregoryizquierdo.xyz') or codigo_identificacion = 'RVD:1004' limit 1;
  select id into v_leandro_id from customers where lower(email) in ('perdomoleandro39@gmail.com', '584122952044@cliente.gregoryizquierdo.xyz') or codigo_identificacion = 'RVD:1002' limit 1;

  -- ----------------------------------------------------------------------------
  -- 2. REGISTRO Y VINCULACIÓN DE LOS 35 CLIENTES ÚNICOS
  -- ----------------------------------------------------------------------------

  -- Cliente: FREDERICK RAMOS (Tel: , Email: frederickramos1604@gmail.com, Vendedor: DIRECTO TIENDA)
  v_seller_id := case 'DIRECTO TIENDA' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'DIRECTO TIENDA' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = 'frederickramos1604@gmail.com';
  v_enc := extensions.crypt('123456', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'frederickramos1604@gmail.com', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','FREDERICK RAMOS','telefono','','full_name','FREDERICK RAMOS'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','FREDERICK RAMOS','telefono','','full_name','FREDERICK RAMOS') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'FREDERICK RAMOS', 'frederickramos1604@gmail.com', '', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'FREDERICK RAMOS',
    telefono = '',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: YOSEMIT (Tel: 573215601336, Email: 573215601336@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '573215601336@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('601336', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '573215601336@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','YOSEMIT','telefono','573215601336','full_name','YOSEMIT'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','YOSEMIT','telefono','573215601336','full_name','YOSEMIT') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'YOSEMIT', '573215601336@cliente.gregoryizquierdo.xyz', '573215601336', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'YOSEMIT',
    telefono = '573215601336',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: ENYERBER ESTEVEZ (Tel: 584128047511, Email: 584128047511@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584128047511@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('047511', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584128047511@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','ENYERBER ESTEVEZ','telefono','584128047511','full_name','ENYERBER ESTEVEZ'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','ENYERBER ESTEVEZ','telefono','584128047511','full_name','ENYERBER ESTEVEZ') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'ENYERBER ESTEVEZ', '584128047511@cliente.gregoryizquierdo.xyz', '584128047511', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'ENYERBER ESTEVEZ',
    telefono = '584128047511',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: MARIANNE AGUDO (Tel: 584245620861, Email: 584245620861@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584245620861@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('620861', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584245620861@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','MARIANNE AGUDO','telefono','584245620861','full_name','MARIANNE AGUDO'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','MARIANNE AGUDO','telefono','584245620861','full_name','MARIANNE AGUDO') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'MARIANNE AGUDO', '584245620861@cliente.gregoryizquierdo.xyz', '584245620861', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'MARIANNE AGUDO',
    telefono = '584245620861',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: VANESSA (Tel: 584242843713, Email: 584242843713@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584242843713@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('843713', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584242843713@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','VANESSA','telefono','584242843713','full_name','VANESSA'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','VANESSA','telefono','584242843713','full_name','VANESSA') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'VANESSA', '584242843713@cliente.gregoryizquierdo.xyz', '584242843713', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'VANESSA',
    telefono = '584242843713',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: DIOGENES (Tel: 584143848858, Email: 584143848858@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584143848858@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('848858', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584143848858@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','DIOGENES','telefono','584143848858','full_name','DIOGENES'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','DIOGENES','telefono','584143848858','full_name','DIOGENES') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'DIOGENES', '584143848858@cliente.gregoryizquierdo.xyz', '584143848858', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'DIOGENES',
    telefono = '584143848858',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: MELYTA (Tel: 584129809304, Email: 584129809304@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584129809304@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('809304', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584129809304@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','MELYTA','telefono','584129809304','full_name','MELYTA'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','MELYTA','telefono','584129809304','full_name','MELYTA') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'MELYTA', '584129809304@cliente.gregoryizquierdo.xyz', '584129809304', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'MELYTA',
    telefono = '584129809304',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: LANDYS (Tel: 584142478459, Email: 584142478459@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584142478459@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('478459', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584142478459@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','LANDYS','telefono','584142478459','full_name','LANDYS'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','LANDYS','telefono','584142478459','full_name','LANDYS') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'LANDYS', '584142478459@cliente.gregoryizquierdo.xyz', '584142478459', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'LANDYS',
    telefono = '584142478459',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: FERNISBEL (Tel: 584141181778, Email: 584141181778@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584141181778@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('181778', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584141181778@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','FERNISBEL','telefono','584141181778','full_name','FERNISBEL'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','FERNISBEL','telefono','584141181778','full_name','FERNISBEL') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'FERNISBEL', '584141181778@cliente.gregoryizquierdo.xyz', '584141181778', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'FERNISBEL',
    telefono = '584141181778',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: TONY MASSIMO (Tel: 584142487511, Email: 584142487511@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584142487511@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('487511', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584142487511@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','TONY MASSIMO','telefono','584142487511','full_name','TONY MASSIMO'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','TONY MASSIMO','telefono','584142487511','full_name','TONY MASSIMO') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'TONY MASSIMO', '584142487511@cliente.gregoryizquierdo.xyz', '584142487511', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'TONY MASSIMO',
    telefono = '584142487511',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: GABRIEL RODRIGUEZ (Tel: 584143893589, Email: 584143893589@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584143893589@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('893589', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584143893589@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','GABRIEL RODRIGUEZ','telefono','584143893589','full_name','GABRIEL RODRIGUEZ'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','GABRIEL RODRIGUEZ','telefono','584143893589','full_name','GABRIEL RODRIGUEZ') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'GABRIEL RODRIGUEZ', '584143893589@cliente.gregoryizquierdo.xyz', '584143893589', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'GABRIEL RODRIGUEZ',
    telefono = '584143893589',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: ARMANDO (Tel: 584120266710, Email: armando.584120266710@cliente.gregoryizquierdo.xyz, Vendedor: NELSON)
  v_seller_id := case 'NELSON' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'NELSON' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = 'armando.584120266710@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('266710', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'armando.584120266710@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','ARMANDO','telefono','584120266710','full_name','ARMANDO'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','ARMANDO','telefono','584120266710','full_name','ARMANDO') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'ARMANDO', 'armando.584120266710@cliente.gregoryizquierdo.xyz', '584120266710', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'ARMANDO',
    telefono = '584120266710',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: CARMEN NACERO (Tel: 584120266710, Email: carmennacero.584120266710@cliente.gregoryizquierdo.xyz, Vendedor: NELSON)
  v_seller_id := case 'NELSON' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'NELSON' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = 'carmennacero.584120266710@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('266710', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'carmennacero.584120266710@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','CARMEN NACERO','telefono','584120266710','full_name','CARMEN NACERO'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','CARMEN NACERO','telefono','584120266710','full_name','CARMEN NACERO') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'CARMEN NACERO', 'carmennacero.584120266710@cliente.gregoryizquierdo.xyz', '584120266710', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'CARMEN NACERO',
    telefono = '584120266710',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: KEIBER NACERO (Tel: 584120266710, Email: keibernacero.584120266710@cliente.gregoryizquierdo.xyz, Vendedor: NELSON)
  v_seller_id := case 'NELSON' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'NELSON' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = 'keibernacero.584120266710@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('266710', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'keibernacero.584120266710@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','KEIBER NACERO','telefono','584120266710','full_name','KEIBER NACERO'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','KEIBER NACERO','telefono','584120266710','full_name','KEIBER NACERO') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'KEIBER NACERO', 'keibernacero.584120266710@cliente.gregoryizquierdo.xyz', '584120266710', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'KEIBER NACERO',
    telefono = '584120266710',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: ARIANA HERRERA (Tel: 584128592774, Email: 584128592774@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584128592774@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('592774', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584128592774@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','ARIANA HERRERA','telefono','584128592774','full_name','ARIANA HERRERA'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','ARIANA HERRERA','telefono','584128592774','full_name','ARIANA HERRERA') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'ARIANA HERRERA', '584128592774@cliente.gregoryizquierdo.xyz', '584128592774', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'ARIANA HERRERA',
    telefono = '584128592774',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: MARIANELA ESPINOZA (Tel: 584142773768, Email: 584142773768@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584142773768@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('773768', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584142773768@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','MARIANELA ESPINOZA','telefono','584142773768','full_name','MARIANELA ESPINOZA'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','MARIANELA ESPINOZA','telefono','584142773768','full_name','MARIANELA ESPINOZA') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'MARIANELA ESPINOZA', '584142773768@cliente.gregoryizquierdo.xyz', '584142773768', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'MARIANELA ESPINOZA',
    telefono = '584142773768',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: ISAAC TOVAR (Tel: 18133779985, Email: 18133779985@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '18133779985@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('779985', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '18133779985@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','ISAAC TOVAR','telefono','18133779985','full_name','ISAAC TOVAR'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','ISAAC TOVAR','telefono','18133779985','full_name','ISAAC TOVAR') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'ISAAC TOVAR', '18133779985@cliente.gregoryizquierdo.xyz', '18133779985', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'ISAAC TOVAR',
    telefono = '18133779985',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: SILVA (Tel: 584129939848, Email: silva.584129939848@cliente.gregoryizquierdo.xyz, Vendedor: JOSUANNY)
  v_seller_id := case 'JOSUANNY' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'JOSUANNY' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = 'silva.584129939848@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('939848', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'silva.584129939848@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','SILVA','telefono','584129939848','full_name','SILVA'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','SILVA','telefono','584129939848','full_name','SILVA') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'SILVA', 'silva.584129939848@cliente.gregoryizquierdo.xyz', '584129939848', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'SILVA',
    telefono = '584129939848',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: YOSESTYLE (Tel: 584129939848, Email: yosestyle.584129939848@cliente.gregoryizquierdo.xyz, Vendedor: JOSUANNY)
  v_seller_id := case 'JOSUANNY' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'JOSUANNY' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = 'yosestyle.584129939848@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('939848', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'yosestyle.584129939848@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','YOSESTYLE','telefono','584129939848','full_name','YOSESTYLE'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','YOSESTYLE','telefono','584129939848','full_name','YOSESTYLE') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'YOSESTYLE', 'yosestyle.584129939848@cliente.gregoryizquierdo.xyz', '584129939848', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'YOSESTYLE',
    telefono = '584129939848',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: MELVIN AMUNDARAIN (Tel: 584142302384, Email: 584142302384@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584142302384@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('302384', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584142302384@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','MELVIN AMUNDARAIN','telefono','584142302384','full_name','MELVIN AMUNDARAIN'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','MELVIN AMUNDARAIN','telefono','584142302384','full_name','MELVIN AMUNDARAIN') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'MELVIN AMUNDARAIN', '584142302384@cliente.gregoryizquierdo.xyz', '584142302384', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'MELVIN AMUNDARAIN',
    telefono = '584142302384',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: MANUEL GONZALEZ (Tel: 584264078565, Email: 584264078565@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584264078565@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('078565', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584264078565@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','MANUEL GONZALEZ','telefono','584264078565','full_name','MANUEL GONZALEZ'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','MANUEL GONZALEZ','telefono','584264078565','full_name','MANUEL GONZALEZ') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'MANUEL GONZALEZ', '584264078565@cliente.gregoryizquierdo.xyz', '584264078565', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'MANUEL GONZALEZ',
    telefono = '584264078565',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: ELIS (Tel: 584124494241, Email: 584124494241@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584124494241@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('494241', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584124494241@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','ELIS','telefono','584124494241','full_name','ELIS'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','ELIS','telefono','584124494241','full_name','ELIS') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'ELIS', '584124494241@cliente.gregoryizquierdo.xyz', '584124494241', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'ELIS',
    telefono = '584124494241',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: CAROLINA HERRERA (Tel: 584142725342, Email: 584142725342@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584142725342@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('725342', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584142725342@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','CAROLINA HERRERA','telefono','584142725342','full_name','CAROLINA HERRERA'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','CAROLINA HERRERA','telefono','584142725342','full_name','CAROLINA HERRERA') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'CAROLINA HERRERA', '584142725342@cliente.gregoryizquierdo.xyz', '584142725342', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'CAROLINA HERRERA',
    telefono = '584142725342',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: ANGELO (Tel: 584242782146, Email: 584242782146@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584242782146@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('782146', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584242782146@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','ANGELO','telefono','584242782146','full_name','ANGELO'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','ANGELO','telefono','584242782146','full_name','ANGELO') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'ANGELO', '584242782146@cliente.gregoryizquierdo.xyz', '584242782146', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'ANGELO',
    telefono = '584242782146',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: YUGLISLELO PEREZ (Tel: 584242322095, Email: 584242322095@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584242322095@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('322095', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584242322095@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','YUGLISLELO PEREZ','telefono','584242322095','full_name','YUGLISLELO PEREZ'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','YUGLISLELO PEREZ','telefono','584242322095','full_name','YUGLISLELO PEREZ') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'YUGLISLELO PEREZ', '584242322095@cliente.gregoryizquierdo.xyz', '584242322095', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'YUGLISLELO PEREZ',
    telefono = '584242322095',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: DOUGLAS PARRA (Tel: 584125872676, Email: 584125872676@cliente.gregoryizquierdo.xyz, Vendedor: DIRECTO TIENDA)
  v_seller_id := case 'DIRECTO TIENDA' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'DIRECTO TIENDA' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584125872676@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('872676', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584125872676@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','DOUGLAS PARRA','telefono','584125872676','full_name','DOUGLAS PARRA'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','DOUGLAS PARRA','telefono','584125872676','full_name','DOUGLAS PARRA') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'DOUGLAS PARRA', '584125872676@cliente.gregoryizquierdo.xyz', '584125872676', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'DOUGLAS PARRA',
    telefono = '584125872676',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: DIRWIN CARABALLO (Tel: 584120904544, Email: 584120904544@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584120904544@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('904544', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584120904544@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','DIRWIN CARABALLO','telefono','584120904544','full_name','DIRWIN CARABALLO'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','DIRWIN CARABALLO','telefono','584120904544','full_name','DIRWIN CARABALLO') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'DIRWIN CARABALLO', '584120904544@cliente.gregoryizquierdo.xyz', '584120904544', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'DIRWIN CARABALLO',
    telefono = '584120904544',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: CARLOS LEON (Tel: 584143725323, Email: 584143725323@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584143725323@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('725323', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584143725323@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','CARLOS LEON','telefono','584143725323','full_name','CARLOS LEON'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','CARLOS LEON','telefono','584143725323','full_name','CARLOS LEON') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'CARLOS LEON', '584143725323@cliente.gregoryizquierdo.xyz', '584143725323', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'CARLOS LEON',
    telefono = '584143725323',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: GEPETO (Tel: 584129251463, Email: 584129251463@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584129251463@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('251463', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584129251463@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','GEPETO','telefono','584129251463','full_name','GEPETO'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','GEPETO','telefono','584129251463','full_name','GEPETO') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'GEPETO', '584129251463@cliente.gregoryizquierdo.xyz', '584129251463', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'GEPETO',
    telefono = '584129251463',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: MARIA (Tel: 584241415188, Email: 584241415188@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584241415188@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('415188', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584241415188@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','MARIA','telefono','584241415188','full_name','MARIA'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','MARIA','telefono','584241415188','full_name','MARIA') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'MARIA', '584241415188@cliente.gregoryizquierdo.xyz', '584241415188', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'MARIA',
    telefono = '584241415188',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: VICTORIA GUEVARA (Tel: 584242407603, Email: 584242407603@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584242407603@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('407603', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584242407603@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','VICTORIA GUEVARA','telefono','584242407603','full_name','VICTORIA GUEVARA'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','VICTORIA GUEVARA','telefono','584242407603','full_name','VICTORIA GUEVARA') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'VICTORIA GUEVARA', '584242407603@cliente.gregoryizquierdo.xyz', '584242407603', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'VICTORIA GUEVARA',
    telefono = '584242407603',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: EVERT IZQUIERDO (Tel: 593978678921, Email: 593978678921@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '593978678921@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('678921', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '593978678921@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','EVERT IZQUIERDO','telefono','593978678921','full_name','EVERT IZQUIERDO'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','EVERT IZQUIERDO','telefono','593978678921','full_name','EVERT IZQUIERDO') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'EVERT IZQUIERDO', '593978678921@cliente.gregoryizquierdo.xyz', '593978678921', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'EVERT IZQUIERDO',
    telefono = '593978678921',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: ROYMEL (Tel: 584120229689, Email: 584120229689@cliente.gregoryizquierdo.xyz, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584120229689@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('229689', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584120229689@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','ROYMEL','telefono','584120229689','full_name','ROYMEL'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','ROYMEL','telefono','584120229689','full_name','ROYMEL') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'ROYMEL', '584120229689@cliente.gregoryizquierdo.xyz', '584120229689', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'ROYMEL',
    telefono = '584120229689',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: JOSLEX (Tel: 584122952044, Email: 584122952044@cliente.gregoryizquierdo.xyz, Vendedor: LEANDRO)
  v_seller_id := case 'LEANDRO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'LEANDRO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from auth.users where lower(email) = '584122952044@cliente.gregoryizquierdo.xyz';
  v_enc := extensions.crypt('952044', extensions.gen_salt('bf'));
  if v_cust_id is null then
    v_cust_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_cust_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', '584122952044@cliente.gregoryizquierdo.xyz', v_enc, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre','JOSLEX','telefono','584122952044','full_name','JOSLEX'), now(), now());
  else
    update auth.users set encrypted_password = v_enc, raw_user_meta_data = jsonb_build_object('nombre','JOSLEX','telefono','584122952044','full_name','JOSLEX') where id = v_cust_id;
  end if;

  v_cod := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
  insert into customers(id, nombre, email, telefono, vendedor_id, vendedor_nombre, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_cust_id, 'JOSLEX', '584122952044@cliente.gregoryizquierdo.xyz', '584122952044', v_seller_id, v_seller_nom, v_cod, 0.00, 'Bronce', true)
  on conflict (id) do update set
    nombre = 'JOSLEX',
    telefono = '584122952044',
    vendedor_id = v_seller_id,
    vendedor_nombre = v_seller_nom,
    limite_credito = coalesce(customers.limite_credito, 0.00),
    debe_cambiar_password = coalesce(customers.debe_cambiar_password, true);

  -- Cliente: PABLO GONZALEZ (Tel: 584129130080, Email: pacun1989@gmail.com, Vendedor: PABLO)
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  v_cust_id := v_pablo_id;

  -- ----------------------------------------------------------------------------
  -- 3. VINCULACIÓN EXACTA DE LOS 46 PERFILES DE INVENTARIO Y PEDIDOS
  -- ----------------------------------------------------------------------------

  -- Fila 1: FREDERICK RAMOS | CRUNCHYROLL PERFIL | Perfil: FREDERICK | Vendedor: DIRECTO TIENDA
  v_seller_id := case 'DIRECTO TIENDA' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'DIRECTO TIENDA' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = 'frederickramos1604@gmail.com' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'CRUNCHYROLL') and lower(trim(pi.nombre_perfil)) like '%frederick%' order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 2: YOSEMIT | PERFIL EXTRA NETFLIX | Perfil: YOSEMIT | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '573215601336@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) like lower('%YOSEMIT%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 3: ENYERBER ESTEVEZ | FLUJOTV | Perfil: ENYERBER | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584128047511@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'FLUJOTV') and lower(trim(pi.nombre_perfil)) like lower('%ENYERBER%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 4: MARIANNE AGUDO | PERFIL EXTRA NETFLIX | Perfil: MARIANNE | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584245620861@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) like lower('%MARIANNE%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 5: MARIANNE AGUDO | PERFIL EXTRA NETFLIX | Perfil: NANI 1 | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584245620861@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) in ('nani 1', 'nani1') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 6: MARIANNE AGUDO | PERFIL EXTRA NETFLIX | Perfil: NANI 2 | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584245620861@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) in ('nani 2', 'nani2') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 7: VANESSA | PARAMOUNT PERFIL | Perfil: VANESSA | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584242843713@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PARAMOUNT') and lower(trim(pi.nombre_perfil)) like lower('%VANESSA%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 8: VANESSA | MAX ESTANDAR PERFIL | Perfil: VANESSA | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584242843713@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'MAX ESTANDAR') and lower(trim(pi.nombre_perfil)) like lower('%VANESSA%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 9: DIOGENES | PERFIL EXTRA NETFLIX | Perfil: DIOGENES 1 | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584143848858@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) in ('diogenes 1', 'diogenes1') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 10: DIOGENES | PERFIL EXTRA NETFLIX | Perfil: DIOGENES 2 | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584143848858@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) in ('diogenes 2', 'diogenes2') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 11: MELYTA | PERFIL EXTRA NETFLIX | Perfil: MELYTA 1 | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584129809304@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) in ('melyta 1', 'melyta1') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 12: MELYTA | PERFIL EXTRA NETFLIX | Perfil: MELYTA 2 | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584129809304@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) in ('melyta 2', 'melyta2') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 13: LANDYS | PERFIL EXTRA NETFLIX | Perfil: LANDYS | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584142478459@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) like lower('%LANDYS%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 14: LANDYS | PERFIL EXTRA NETFLIX | Perfil: ENDRIS | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584142478459@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) like '%endris%' order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 15: LANDYS | MAX ESTANDAR PERFIL | Perfil: ENDRIS | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584142478459@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'MAX ESTANDAR') and lower(trim(pi.nombre_perfil)) like lower('%ENDRIS%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 16: FERNISBEL | DISNEY PREMIUM PERFIL | Perfil: FERNISBEL | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584141181778@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'DISNEY PREMIUM') and lower(trim(pi.nombre_perfil)) like lower('%FERNISBEL%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 17: TONY MASSIMO | TELELATINO PERFIL | Perfil: TONY | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584142487511@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'TELELATINO') and lower(trim(pi.nombre_perfil)) like lower('%TONY%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 18: TONY MASSIMO | TELELATINO PERFIL | Perfil: MARIA RODRIGUEZ | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584142487511@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'TELELATINO') and lower(trim(pi.nombre_perfil)) like '%maria%rodriguez%' order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 19: GABRIEL RODRIGUEZ | FLUJOTV PERFIL | Perfil: GABRIEL | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584143893589@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'FLUJOTV') and lower(trim(pi.nombre_perfil)) like lower('%GABRIEL%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 20: ARMANDO | DISNEY PREMIUM PERFIL | Perfil: ARMANDO | Vendedor: NELSON
  v_seller_id := case 'NELSON' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'NELSON' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = 'armando.584120266710@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'DISNEY PREMIUM') and lower(trim(pi.nombre_perfil)) like lower('%ARMANDO%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 21: CARMEN NACERO | PERFIL EXTRA NETFLIX | Perfil: CARMEN NACERO | Vendedor: NELSON
  v_seller_id := case 'NELSON' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'NELSON' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = 'carmennacero.584120266710@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) like lower('%CARMEN NACERO%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 22: KEIBER NACERO | PERFIL EXTRA NETFLIX | Perfil: KEIBER NACERO | Vendedor: NELSON
  v_seller_id := case 'NELSON' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'NELSON' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = 'keibernacero.584120266710@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) like lower('%KEIBER NACERO%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 23: ARIANA HERRERA | NETFLIX PERFIL | Perfil: ARIANA | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584128592774@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma in ('NETFLIX', 'PERFIL EXTRA NETFLIX')) and lower(trim(pi.nombre_perfil)) like '%ariana%' order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 24: MARIANELA ESPINOZA | PERFIL EXTRA NETFLIX | Perfil: MARIANELA ESPINOZA | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584142773768@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) like lower('%MARIANELA ESPINOZA%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 25: ISAAC TOVAR | DISNEY PREMIUM PERFIL | Perfil: ISAAC | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '18133779985@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'DISNEY PREMIUM') and lower(trim(pi.nombre_perfil)) like lower('%ISAAC%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 26: ISAAC TOVAR | MAX ESTANDAR PERFIL | Perfil: ISAAC | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '18133779985@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'MAX ESTANDAR') and lower(trim(pi.nombre_perfil)) like lower('%ISAAC%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 27: SILVA | PERFIL EXTRA NETFLIX | Perfil: SILVIA | Vendedor: JOSUANNY
  v_seller_id := case 'JOSUANNY' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'JOSUANNY' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = 'silva.584129939848@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) like '%silvi%' order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 28: YOSESTYLE | PERFIL EXTRA NETFLIX | Perfil: YOSESTYLE | Vendedor: JOSUANNY
  v_seller_id := case 'JOSUANNY' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'JOSUANNY' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = 'yosestyle.584129939848@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) like lower('%YOSESTYLE%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 29: MELVIN AMUNDARAIN | FLUJOTV PERFIL | Perfil: MELVIN 1 | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584142302384@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'FLUJOTV') and lower(trim(pi.nombre_perfil)) in ('melvin 1', 'melvin1') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 30: MELVIN AMUNDARAIN | FLUJOTV PERFIL | Perfil: MELVIN 2 | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584142302384@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'FLUJOTV') and lower(trim(pi.nombre_perfil)) in ('melvin 2', 'melvin2') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 31: MANUEL GONZALEZ | TELELATINO PERFIL | Perfil: MANUEL | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584264078565@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'TELELATINO') and lower(trim(pi.nombre_perfil)) like lower('%MANUEL%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 32: ELIS | PERFIL EXTRA NETFLIX | Perfil: ELIS | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584124494241@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) like lower('%ELIS%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 33: CAROLINA HERRERA | CUENTA COMPLETA FLUJOTV | Perfil: CAROLINA HERRERA | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584142725342@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'FLUJOTV' and (correo = 'Conec744' or lower(trim(pi.nombre_perfil)) like '%carolina%')) order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 34: ANGELO | DISNEY PREMIUM PERFIL | Perfil: ANGELO | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584242782146@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'DISNEY PREMIUM') and lower(trim(pi.nombre_perfil)) like lower('%ANGELO%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 35: ANGELO | MAX ESTANDAR PERFIL | Perfil: ANGELO | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584242782146@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'MAX ESTANDAR') and lower(trim(pi.nombre_perfil)) like lower('%ANGELO%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 36: YUGLISLELO PEREZ | DISNEY PREMIUM PERFIL | Perfil: YUGLIS PEREZ | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584242322095@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'DISNEY PREMIUM') and lower(trim(pi.nombre_perfil)) like lower('%YUGLIS PEREZ%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 37: DOUGLAS PARRA | DISNEY PREMIUM PERFIL | Perfil: DOUGLAS PARRA | Vendedor: DIRECTO TIENDA
  v_seller_id := case 'DIRECTO TIENDA' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'DIRECTO TIENDA' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584125872676@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'DISNEY PREMIUM') and lower(trim(pi.nombre_perfil)) like lower('%DOUGLAS PARRA%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 38: DIRWIN CARABALLO | CRUNCRYROLL PERFIL | Perfil: DIRWIN | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584120904544@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'CRUNCHYROLL') and lower(trim(pi.nombre_perfil)) like '%dirwin%' order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 39: CARLOS LEON | PARAMOUNT PERFIL | Perfil: CARLOS | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584143725323@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PARAMOUNT') and lower(trim(pi.nombre_perfil)) like lower('%CARLOS%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 40: GEPETO | PARAMOUNT PERFIL | Perfil: GEPE | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584129251463@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PARAMOUNT') and lower(trim(pi.nombre_perfil)) like '%gepe%' order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 41: MARIA | FLUJOTV PERFIL | Perfil: MARIA | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584241415188@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'FLUJOTV') and lower(trim(pi.nombre_perfil)) = 'maria' order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 42: VICTORIA GUEVARA | PRIME VIDEO PERFIL | Perfil: MARIA VICTORIA | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584242407603@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PRIME VIDEO') and lower(trim(pi.nombre_perfil)) like '%victoria%' order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 43: EVERT IZQUIERDO | PERFIL EXTRA NETFLIX | Perfil: EVERT | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '593978678921@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX') and lower(trim(pi.nombre_perfil)) like lower('%EVERT%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 44: ROYMEL | DISNEY PREMIUM PERFIL | Perfil: ROYMEL | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584120229689@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'DISNEY PREMIUM') and lower(trim(pi.nombre_perfil)) like lower('%ROYMEL%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 45: JOSLEX | CRUNCRYROLL PERFIL | Perfil: JOSLEX | Vendedor: LEANDRO
  v_seller_id := case 'LEANDRO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'LEANDRO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = '584122952044@cliente.gregoryizquierdo.xyz' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'CRUNCHYROLL') and lower(trim(pi.nombre_perfil)) like lower('%JOSLEX%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

  -- Fila 46: PABLO GONZALEZ | FLUJOTV PERFIL | Perfil: PABLO | Vendedor: PABLO
  v_seller_id := case 'PABLO' when 'PABLO' then v_pablo_id when 'NELSON' then v_nelson_id when 'JOSUANNY' then v_josuanny_id when 'LEANDRO' then v_leandro_id else null end;
  v_seller_nom := case 'PABLO' when 'PABLO' then 'Pablo Gonzalez' when 'NELSON' then 'Nelson Bustamante' when 'JOSUANNY' then 'Josuanny' when 'LEANDRO' then 'Leandro Perdomo' else null end;
  select id into v_cust_id from customers where lower(email) = 'pacun1989@gmail.com' limit 1;
  v_prof_id := null;
  select pi.id into v_prof_id from profiles_inventory pi where pi.mother_id in (select id from mother_accounts where plataforma = 'FLUJOTV') and lower(trim(pi.nombre_perfil)) like lower('%PABLO%') order by pi.id limit 1;
  if v_prof_id is not null then
    update profiles_inventory
    set assigned_customer_id = v_cust_id,
        vendedor_id = v_seller_id,
        vendedor = v_seller_nom,
        estado = 'vendido'
    where id = v_prof_id;

    if exists (select 1 from orders where profile_id = v_prof_id) then
      update orders set customer_id = v_cust_id, vendedor_id = v_seller_id, estado = 'entregado' where profile_id = v_prof_id;
    else
      insert into orders (customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, referencia, estado, vendedor_id, inicia, vence)
      select v_cust_id, pi.product_id, v_prof_id, coalesce(pr.precio_usd, 3.50), v_rate, coalesce(pr.precio_usd, 3.50) * v_rate, 'MIGRACION-ASIGNACION', 'entregado', v_seller_id, pi.inicia, pi.vence
      from profiles_inventory pi left join products pr on pr.id = pi.product_id where pi.id = v_prof_id;
    end if;
  end if;

end $$;
