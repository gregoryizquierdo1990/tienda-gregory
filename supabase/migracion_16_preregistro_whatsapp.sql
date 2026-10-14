-- ==============================================================================
-- MIGRACIÓN 16: PRE-REGISTRO RÁPIDO DE CLIENTES DESDE WHATSAPP & RESETEO DE CLAVE
-- ==============================================================================
-- 1. Permite registrar clientes solo con Nombre y WhatsApp.
-- 2. Clave inicial = últimos 6 dígitos de su número telefónico.
-- 3. Flag 'debe_cambiar_password' para obligar a cambiar la contraseña al entrar.
-- 4. Captura opcional de correo para campañas de marketing y promociones.
-- 5. Función administrativa 'resetear_clave_cliente' para devolver la clave a los
--    últimos 6 dígitos y obligar a configurar nueva clave en el siguiente inicio.
-- ==============================================================================

create extension if not exists pgcrypto with schema extensions;

-- Agregar columna para obligar el cambio de contraseña en primer ingreso o tras reseteo
alter table customers add column if not exists debe_cambiar_password boolean default false;

-- ------------------------------------------------------------------------------
-- 1. PRE-REGISTRO WHATSAPP (ADMIN)
-- ------------------------------------------------------------------------------
create or replace function preregistrar_cliente_whatsapp(
  p_nombre text,
  p_telefono text,
  p_limite_credito numeric default 0.00,
  p_saldo_zeny numeric default 0.00
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_clean_tel text;
  v_email text;
  v_pass text;
  v_enc_pass text;
  v_user_id uuid;
  v_existing_id uuid;
  v_codigo text;
  v_msg text;
  v_card_num text;
  v_cvv text;
begin
  -- Solo el administrador puede pre-registrar clientes
  if not is_admin() then
    raise exception 'No autorizado: solo el administrador puede pre-registrar clientes';
  end if;

  if trim(p_nombre) = '' or p_nombre is null then
    raise exception 'El nombre del cliente es obligatorio';
  end if;

  -- Limpiar teléfono dejando solo números
  v_clean_tel := regexp_replace(coalesce(p_telefono, ''), '\D', '', 'g');
  if length(v_clean_tel) < 7 then
    raise exception 'El número de teléfono debe tener al menos 7 dígitos (ej: 04121234567)';
  end if;

  -- Correo virtual del cliente para Supabase Auth
  v_email := v_clean_tel || '@cliente.gregoryizquierdo.xyz';

  -- Contraseña: los últimos 6 dígitos del teléfono
  v_pass := right(v_clean_tel, 6);
  if length(v_pass) < 6 then
    v_pass := lpad(v_pass, 6, '0');
  end if;
  v_enc_pass := extensions.crypt(v_pass, extensions.gen_salt('bf'));

  -- Verificar si el usuario ya existe en auth.users
  select id into v_existing_id from auth.users where email = v_email;

  if v_existing_id is not null then
    v_user_id := v_existing_id;
    -- Actualizar contraseña y metadata si ya existía
    update auth.users
    set encrypted_password = v_enc_pass,
        raw_user_meta_data = jsonb_build_object('nombre', p_nombre, 'telefono', p_telefono, 'full_name', p_nombre),
        updated_at = now()
    where id = v_user_id;

    update customers
    set nombre = coalesce(p_nombre, nombre),
        telefono = coalesce(p_telefono, telefono),
        debe_cambiar_password = true
    where id = v_user_id;
  else
    -- Crear nuevo usuario en auth.users
    v_user_id := gen_random_uuid();
    insert into auth.users (
      id,
      instance_id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    ) values (
      v_user_id,
      '00000000-0000-0000-0000-000000000000'::uuid,
      'authenticated',
      'authenticated',
      v_email,
      v_enc_pass,
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('nombre', p_nombre, 'telefono', p_telefono, 'full_name', p_nombre),
      now(),
      now()
    );

    v_codigo := 'CLT:' || lpad(floor(1000 + random() * 9000)::text, 4, '0');
    insert into customers (id, nombre, email, telefono, limite_credito, zeny_balance, codigo_identificacion, debe_cambiar_password)
    values (v_user_id, p_nombre, v_email, p_telefono, coalesce(p_limite_credito, 0.00), coalesce(p_saldo_zeny, 0.00), v_codigo, true)
    on conflict (id) do update
    set nombre = excluded.nombre,
        telefono = excluded.telefono,
        debe_cambiar_password = true,
        codigo_identificacion = coalesce(customers.codigo_identificacion, v_codigo);
  end if;

  -- Crear o actualizar tarjeta digital Zeny para el cliente
  v_card_num := '4532 98' || right(v_clean_tel, 10);
  if length(replace(v_card_num, ' ', '')) <> 16 then
    v_card_num := '4532 ' || lpad(right(v_clean_tel, 12), 12, '0');
    v_card_num := substring(v_card_num, 1, 4) || ' ' || substring(v_card_num, 5, 4) || ' ' || substring(v_card_num, 9, 4) || ' ' || substring(v_card_num, 13, 4);
  end if;
  v_cvv := right(v_clean_tel, 3);

  insert into zeny_cards (
    customer_id,
    numero_tarjeta,
    nombre_titular,
    codigo_activacion,
    fecha_vencimiento,
    estado,
    descuento_porcentaje
  ) values (
    v_user_id,
    v_card_num,
    upper(p_nombre),
    v_cvv,
    to_char(now() + interval '365 days', 'MM/YY'),
    'activa',
    5.00
  ) on conflict (customer_id) do update
  set nombre_titular = upper(p_nombre),
      fecha_vencimiento = coalesce(zeny_cards.fecha_vencimiento, to_char(now() + interval '365 days', 'MM/YY'));

  -- Mensaje de bienvenida para WhatsApp con advertencia de cambio de clave
  v_msg := '¡Hola ' || p_nombre || '! 👋 Bienvenido a la plataforma oficial de *Emprendimiento Gregory Izquierdo*.' || chr(10) || chr(10) ||
           'Ya tenemos tu cuenta lista para que consultes el catálogo en vivo, tus pantallas y vencimientos:' || chr(10) ||
           '🌐 *Tienda Web:* https://gregoryizquierdo.xyz' || chr(10) ||
           '👤 *Usuario:* ' || p_telefono || chr(10) ||
           '🔑 *Contraseña temporal:* ' || v_pass || ' (los últimos 6 dígitos de tu WhatsApp)' || chr(10) || chr(10) ||
           '⚠️ *Aviso de Seguridad:* Al iniciar sesión por primera vez, el sistema te solicitará cambiar esta clave por tu contraseña personal de preferencia.' || chr(10) || chr(10) ||
           '💳 En tu panel ya tienes asignada tu *Tarjeta Digital Zeny* para comprar y acumular puntos. ¡Cualquier duda estamos a la orden por aquí!';

  return jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'nombre', p_nombre,
    'telefono', p_telefono,
    'email_virtual', v_email,
    'password_inicial', v_pass,
    'mensaje_whatsapp', v_msg
  );
end;
$$;

grant execute on function preregistrar_cliente_whatsapp(text, text, numeric, numeric) to authenticated;

-- ------------------------------------------------------------------------------
-- 2. RESETEO DE CLAVE POR EL ADMINISTRADOR
-- ------------------------------------------------------------------------------
-- Devuelve la clave del cliente a los últimos 6 dígitos de su teléfono
-- y activa la bandera 'debe_cambiar_password' para obligarlo a personalizarla.
-- ------------------------------------------------------------------------------
create or replace function resetear_clave_cliente(
  p_customer_id uuid
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_nombre text;
  v_telefono text;
  v_email text;
  v_clean_tel text;
  v_pass text;
  v_enc_pass text;
  v_msg text;
begin
  if not is_admin() then
    raise exception 'No autorizado: solo el administrador puede resetear contraseñas de clientes';
  end if;

  select nombre, telefono, email into v_nombre, v_telefono, v_email
  from customers where id = p_customer_id;

  if not found then
    raise exception 'Cliente no encontrado';
  end if;

  v_clean_tel := regexp_replace(coalesce(v_telefono, ''), '\D', '', 'g');
  if length(v_clean_tel) >= 6 then
    v_pass := right(v_clean_tel, 6);
  else
    v_pass := '123456';
  end if;

  v_enc_pass := extensions.crypt(v_pass, extensions.gen_salt('bf'));

  -- Actualizar auth.users
  update auth.users
  set encrypted_password = v_enc_pass,
      updated_at = now()
  where id = p_customer_id;

  -- Marcar en customers que debe cambiar clave
  update customers
  set debe_cambiar_password = true
  where id = p_customer_id;

  -- Preparar mensaje de WhatsApp listo para enviar
  v_msg := '¡Hola ' || coalesce(v_nombre, 'Cliente') || '! 👋 Se ha restablecido tu acceso a la plataforma oficial de *Emprendimiento Gregory Izquierdo*.' || chr(10) || chr(10) ||
           '🌐 *Tienda Web:* https://gregoryizquierdo.xyz' || chr(10) ||
           '👤 *Usuario:* ' || coalesce(v_telefono, v_email) || chr(10) ||
           '🔑 *Contraseña temporal:* ' || v_pass || ' (los últimos 6 dígitos de tu teléfono)' || chr(10) || chr(10) ||
           '⚠️ *Aviso de Seguridad:* Al iniciar sesión, el sistema te solicitará ingresar una nueva clave personal para proteger tu cuenta y saldo Zeny.' || chr(10) || chr(10) ||
           '¡Estamos para servirte!';

  return jsonb_build_object(
    'success', true,
    'customer_id', p_customer_id,
    'nombre', v_nombre,
    'telefono', v_telefono,
    'password_temporal', v_pass,
    'mensaje_whatsapp', v_msg
  );
end;
$$;

grant execute on function resetear_clave_cliente(uuid) to authenticated;

-- ------------------------------------------------------------------------------
-- 3. COMPLETAR PRIMER CAMBIO DE CLAVE & EMAIL MARKETING OPCIONAL
-- ------------------------------------------------------------------------------
-- Llamado por el propio cliente autenticado tras actualizar su contraseña.
-- Desactiva 'debe_cambiar_password' y si proporcionó email personal, lo registra.
-- ------------------------------------------------------------------------------
create or replace function completar_primer_cambio_clave(
  p_nuevo_email text default null
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_user_id uuid := auth.uid();
  v_email_clean text;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  v_email_clean := trim(coalesce(p_nuevo_email, ''));

  if v_email_clean <> '' and v_email_clean like '%@%.%' and not v_email_clean like '%@cliente.gregoryizquierdo.xyz' then
    update customers
    set email = v_email_clean,
        debe_cambiar_password = false
    where id = v_user_id;

    update auth.users
    set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('marketing_email', v_email_clean)
    where id = v_user_id;
  else
    update customers
    set debe_cambiar_password = false
    where id = v_user_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'customer_id', v_user_id,
    'email_registrado', case when v_email_clean <> '' and v_email_clean like '%@%.%' then v_email_clean else null end
  );
end;
$$;

grant execute on function completar_primer_cambio_clave(text) to authenticated;
