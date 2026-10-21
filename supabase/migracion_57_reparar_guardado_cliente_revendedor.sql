-- ==============================================================================
-- MIGRACIÓN 57: REPARACIÓN DEFINITIVA DE GUARDADO DE CLIENTES POR REVENDEDOR
-- Y OPTIMIZACIÓN DE RENOVACIÓN ANTICIPADA CON PAGO MÓVIL
-- ==============================================================================

-- 1. Crear función unificada de actualización de cliente por revendedor (sin max(uuid))
CREATE OR REPLACE FUNCTION public.reseller_update_client_info(
  p_profile_id uuid,
  p_cliente_nombre text,
  p_cliente_telefono text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_is_adm boolean := false;
  v_seller_name text := null;
  v_assigned_cust uuid := null;
  v_clean_name text := nullif(trim(p_cliente_nombre), '');
  v_clean_tel text := nullif(trim(p_cliente_telefono), '');
  v_found boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado';
  END IF;

  v_is_adm := is_admin();
  SELECT nombre INTO v_seller_name FROM customers WHERE id = v_user_id;

  IF NOT v_is_adm THEN
    SELECT pi.assigned_customer_id INTO v_assigned_cust
    FROM profiles_inventory pi
    LEFT JOIN customers c ON c.id = pi.assigned_customer_id
    LEFT JOIN orders o ON o.profile_id = pi.id
    WHERE pi.id = p_profile_id
      AND (
        pi.vendedor_id = v_user_id
        OR c.vendedor_id = v_user_id
        OR o.vendedor_id = v_user_id
        OR pi.assigned_customer_id = v_user_id
        OR o.customer_id = v_user_id
        OR (pi.vendedor IS NOT NULL AND v_seller_name IS NOT NULL AND lower(trim(pi.vendedor)) = lower(trim(v_seller_name)))
        OR EXISTS (
          SELECT 1 FROM public.customers cust
          WHERE cust.id = v_user_id
            AND (
              lower(trim(coalesce(pi.vendedor, ''))) IN (lower(trim(coalesce(cust.nombre, ''))), lower(trim(coalesce(cust.codigo_identificacion, ''))))
              OR (coalesce(cust.codigo_identificacion, '') = 'RVD:1001' AND lower(coalesce(pi.vendedor, '')) LIKE '%pablo%')
            )
        )
      )
    LIMIT 1;

    GET DIAGNOSTICS v_found = ROW_COUNT;
    IF NOT v_found THEN
      RAISE EXCEPTION 'No tienes permisos sobre este perfil';
    END IF;
  ELSE
    SELECT assigned_customer_id INTO v_assigned_cust FROM profiles_inventory WHERE id = p_profile_id;
  END IF;

  -- Actualizar en profiles_inventory
  UPDATE profiles_inventory
  SET cliente_final = v_clean_name,
      cliente_telefono = v_clean_tel
  WHERE id = p_profile_id;

  -- Si está asociado a un customer de cliente final (que no sea el revendedor mismo), actualizar también su nombre y teléfono
  IF v_assigned_cust IS NOT NULL AND v_assigned_cust <> v_user_id THEN
    UPDATE customers
    SET nombre = COALESCE(v_clean_name, nombre),
        telefono = COALESCE(v_clean_tel, telefono)
    WHERE id = v_assigned_cust;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'profile_id', p_profile_id,
    'cliente_final', v_clean_name,
    'cliente_telefono', v_clean_tel
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reseller_update_client_info(uuid, text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.reseller_update_client_info(uuid, text, text) TO authenticated;

-- 2. Compatibilidad retroactiva con reseller_set_cliente_final delegando a la función unificada
CREATE OR REPLACE FUNCTION public.reseller_set_cliente_final(
  p_profile_id uuid,
  p_cliente_nombre text,
  p_cliente_telefono text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  RETURN public.reseller_update_client_info(p_profile_id, p_cliente_nombre, p_cliente_telefono);
END;
$$;

CREATE OR REPLACE FUNCTION public.reseller_set_cliente_final(
  p_profile_id uuid,
  p_cliente_nombre text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  RETURN public.reseller_update_client_info(p_profile_id, p_cliente_nombre, NULL);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reseller_set_cliente_final(uuid, text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.reseller_set_cliente_final(uuid, text, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.reseller_set_cliente_final(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.reseller_set_cliente_final(uuid, text) TO authenticated;

-- 3. Optimización de notify_admin para evitar bloqueos por timeout en webhooks síncronos
CREATE OR REPLACE FUNCTION public.notify_admin(p_kind text, p_msg text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  u text;
  s text;
BEGIN
  SELECT value INTO u FROM secrets WHERE name = 'notify_url';
  SELECT value INTO s FROM secrets WHERE name = 'notify_secret';
  IF u IS NULL OR s IS NULL THEN
    RETURN;
  END IF;

  PERFORM net.http_post(
    url := u,
    headers := jsonb_build_object('Content-Type','application/json','x-notify-secret', s),
    body := jsonb_build_object('kind', p_kind, 'msg', p_msg),
    timeout_milliseconds := 2000
  );
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

REVOKE EXECUTE ON FUNCTION public.notify_admin(text, text) FROM public, anon, authenticated;
