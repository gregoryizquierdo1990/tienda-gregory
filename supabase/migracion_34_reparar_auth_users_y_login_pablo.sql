-- ==============================================================================
-- MIGRACIÓN 34: REPARACIÓN DE TOKENS EN AUTH.USERS, IDENTITIES Y ACCESO PABLO GONZALEZ
-- Soluciona el error 500: "database error querying schema" en Supabase Auth
-- ==============================================================================

create extension if not exists "pgcrypto";

begin;

-- 1. REPARAR VALORES NULL EN AUTH.USERS (Causa raíz del error "database error querying schema")
-- Supabase GoTrue lanza un fallo de escaneo en Go si columnas de texto tienen NULL en lugar de ''
do $$
declare
  col text;
  cols text[] := array[
    'confirmation_token', 'recovery_token', 'email_change', 
    'email_change_token_new', 'email_change_token_current', 
    'reauthentication_token', 'phone_change', 'phone_change_token'
  ];
begin
  foreach col in array cols loop
    if exists (
      select 1 from information_schema.columns 
      where table_schema = 'auth' and table_name = 'users' and column_name = col
    ) then
      execute format('update auth.users set %I = coalesce(%I, '''') where %I is null;', col, col, col);
    end if;
  end loop;
end $$;


-- 2. ASEGURAR O ACTUALIZAR A PABLO GONZALEZ (pacun1989@gmail.com y pacun1989@gmai.com)
do $$
declare
  v_enc text;
  v_uid_gmail uuid;
  v_uid_gmai uuid;
begin
  -- Contraseña oficial asignada: 130080
  v_enc := extensions.crypt('130080', extensions.gen_salt('bf'));

  -- --- CUENTA OFICIAL (pacun1989@gmail.com) ---
  select id into v_uid_gmail from auth.users where lower(trim(email)) in ('pacun1989@gmail.com', '584129130080@cliente.gregoryizquierdo.xyz') limit 1;

  if v_uid_gmail is null then
    v_uid_gmail := gen_random_uuid();
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change, email_change_token_new
    ) values (
      v_uid_gmail, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated',
      'pacun1989@gmail.com', v_enc, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('nombre','Pablo Gonzalez','telefono','584129130080','full_name','Pablo Gonzalez'),
      now(), now(), '', '', '', ''
    );
  else
    update auth.users
    set email = 'pacun1989@gmail.com',
        encrypted_password = v_enc,
        email_confirmed_at = coalesce(email_confirmed_at, now()),
        banned_until = null,
        confirmation_token = '',
        recovery_token = '',
        email_change = '',
        email_change_token_new = '',
        raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
        raw_user_meta_data = jsonb_build_object('nombre','Pablo Gonzalez','telefono','584129130080','full_name','Pablo Gonzalez')
    where id = v_uid_gmail;
  end if;

  -- Actualizar perfil en customers
  insert into customers (id, nombre, email, telefono, es_revendedor, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_uid_gmail, 'Pablo Gonzalez', 'pacun1989@gmail.com', '584129130080', true, 'RVD:1001', 0.00, 'Oro', false)
  on conflict (id) do update set
    nombre = 'Pablo Gonzalez',
    email = 'pacun1989@gmail.com',
    telefono = '584129130080',
    es_revendedor = true,
    codigo_identificacion = 'RVD:1001',
    debe_cambiar_password = false;


  -- --- ALIAS TOLERANTE A TYPO (pacun1989@gmai.com) ---
  -- Por si Pablo escribe directamente @gmai.com sin la 'l'
  select id into v_uid_gmai from auth.users where lower(trim(email)) = 'pacun1989@gmai.com' limit 1;

  if v_uid_gmai is null then
    v_uid_gmai := gen_random_uuid();
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change, email_change_token_new
    ) values (
      v_uid_gmai, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated',
      'pacun1989@gmai.com', v_enc, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('nombre','Pablo Gonzalez','telefono','584129130080','full_name','Pablo Gonzalez'),
      now(), now(), '', '', '', ''
    );
  else
    update auth.users
    set encrypted_password = v_enc,
        email_confirmed_at = coalesce(email_confirmed_at, now()),
        banned_until = null,
        confirmation_token = '',
        recovery_token = '',
        email_change = '',
        email_change_token_new = '',
        raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
        raw_user_meta_data = jsonb_build_object('nombre','Pablo Gonzalez','telefono','584129130080','full_name','Pablo Gonzalez')
    where id = v_uid_gmai;
  end if;

  insert into customers (id, nombre, email, telefono, es_revendedor, codigo_identificacion, limite_credito, nivel_credito, debe_cambiar_password)
  values (v_uid_gmai, 'Pablo Gonzalez', 'pacun1989@gmai.com', '584129130080', true, 'RVD:1001', 0.00, 'Oro', false)
  on conflict (id) do update set
    nombre = 'Pablo Gonzalez',
    email = 'pacun1989@gmai.com',
    telefono = '584129130080',
    es_revendedor = true,
    codigo_identificacion = 'RVD:1001',
    debe_cambiar_password = false;

end $$;


-- 3. REPARAR O CREAR IDENTIDADES EN AUTH.IDENTITIES PARA TODOS LOS USUARIOS
do $$
begin
  if exists (
    select 1 from information_schema.columns 
    where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id'
  ) then
    execute '
      insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      select
        u.id,
        u.id,
        u.id::text,
        json_build_object(''sub'', u.id::text, ''email'', u.email)::jsonb,
        ''email'',
        now(),
        now(),
        now()
      from auth.users u
      where not exists (
        select 1 from auth.identities i where i.user_id = u.id and i.provider = ''email''
      )
      on conflict do nothing;
    ';
  else
    execute '
      insert into auth.identities (id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      select
        u.id,
        u.id,
        json_build_object(''sub'', u.id::text, ''email'', u.email)::jsonb,
        ''email'',
        now(),
        now(),
        now()
      from auth.users u
      where not exists (
        select 1 from auth.identities i where i.user_id = u.id and i.provider = ''email''
      )
      on conflict do nothing;
    ';
  end if;
end $$;

commit;
