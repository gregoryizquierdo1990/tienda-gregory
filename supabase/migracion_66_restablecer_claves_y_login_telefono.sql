-- ==============================================================================
-- MIGRACIÓN 66: FUNCIONES DE RESETEO DE CLAVE Y LOGIN INTELIGENTE POR TELÉFONO
-- ==============================================================================

-- 1. Función para resolver el email real de auth a partir del teléfono del usuario
CREATE OR REPLACE FUNCTION obtener_email_login(p_telefono TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_clean TEXT;
  v_email TEXT;
BEGIN
  v_clean := regexp_replace(coalesce(p_telefono, ''), '\D', '', 'g');
  IF length(v_clean) < 7 THEN
    RETURN NULL;
  END IF;

  SELECT email INTO v_email
  FROM customers
  WHERE regexp_replace(telefono, '\D', '', 'g') IN (v_clean, '58' || ltrim(v_clean, '0'), '0' || regexp_replace(v_clean, '^58', ''))
    AND email IS NOT NULL
    AND email <> ''
  LIMIT 1;

  RETURN v_email;
END;
$$;

GRANT EXECUTE ON FUNCTION obtener_email_login(TEXT) TO anon, authenticated;

-- 2. Función administrativa para resetear clave de clientes / revendedores a los últimos 6 dígitos de su teléfono
CREATE OR REPLACE FUNCTION resetear_clave_cliente(
  p_customer_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions AS $$
DECLARE
  v_nombre TEXT;
  v_telefono TEXT;
  v_email TEXT;
  v_clean_tel TEXT;
  v_pass TEXT;
  v_enc_pass TEXT;
  v_msg TEXT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'No autorizado: solo el administrador puede resetear contraseñas de clientes';
  END IF;

  SELECT nombre, telefono, email INTO v_nombre, v_telefono, v_email
  FROM customers WHERE id = p_customer_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cliente no encontrado';
  END IF;

  v_clean_tel := regexp_replace(coalesce(v_telefono, ''), '\D', '', 'g');
  IF length(v_clean_tel) >= 6 THEN
    v_pass := right(v_clean_tel, 6);
  ELSE
    v_pass := '123456';
  END IF;

  v_enc_pass := extensions.crypt(v_pass, extensions.gen_salt('bf', 10));

  -- Actualizar auth.users
  UPDATE auth.users
  SET encrypted_password = v_enc_pass,
      updated_at = now()
  WHERE id = p_customer_id;

  -- Marcar en customers que debe cambiar clave
  UPDATE customers
  SET debe_cambiar_password = TRUE
  WHERE id = p_customer_id;

  -- Preparar mensaje de WhatsApp listo para enviar
  v_msg := '¡Hola ' || coalesce(v_nombre, 'Cliente') || '! 👋 Se ha restablecido tu acceso a la plataforma oficial de *Emprendimiento Gregory Izquierdo*.' || chr(10) || chr(10) ||
           '🌐 *Tienda Web:* https://gregoryizquierdo.xyz' || chr(10) ||
           '👤 *Usuario:* ' || coalesce(v_email, v_telefono) || chr(10) ||
           '🔑 *Contraseña temporal:* ' || v_pass || ' (los últimos 6 dígitos de tu WhatsApp)' || chr(10) || chr(10) ||
           '⚠️ *Aviso de Seguridad:* Al iniciar sesión, el sistema te solicitará ingresar una nueva clave personal para proteger tu cuenta y saldo Zeny.' || chr(10) || chr(10) ||
           '¡Estamos para servirte!';

  RETURN jsonb_build_object(
    'success', true,
    'customer_id', p_customer_id,
    'nombre', v_nombre,
    'telefono', v_telefono,
    'email', v_email,
    'password_temporal', v_pass,
    'mensaje_whatsapp', v_msg
  );
END;
$$;

GRANT EXECUTE ON FUNCTION resetear_clave_cliente(UUID) TO authenticated;

-- 3. Función llamada por el usuario autenticado al personalizar su contraseña obligatoria
CREATE OR REPLACE FUNCTION completar_primer_cambio_clave(
  p_nuevo_email TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_email_clean TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  v_email_clean := trim(coalesce(p_nuevo_email, ''));

  IF v_email_clean <> '' AND v_email_clean LIKE '%@%.%' AND NOT v_email_clean LIKE '%@cliente.gregoryizquierdo.xyz' THEN
    UPDATE customers
    SET email = v_email_clean,
        debe_cambiar_password = FALSE
    WHERE id = v_user_id;

    UPDATE auth.users
    SET raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('marketing_email', v_email_clean)
    WHERE id = v_user_id;
  ELSE
    UPDATE customers
    SET debe_cambiar_password = FALSE
    WHERE id = v_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'customer_id', v_user_id,
    'email_registrado', CASE WHEN v_email_clean <> '' AND v_email_clean LIKE '%@%.%' THEN v_email_clean ELSE NULL END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION completar_primer_cambio_clave(TEXT) TO authenticated;
