-- Migración 61: Funciones RPC para obtener credenciales de órdenes entregadas en el panel de administración
CREATE OR REPLACE FUNCTION public.admin_get_order_credentials(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_res jsonb;
BEGIN
  IF NOT (is_admin() OR auth.role() = 'service_role' OR current_user IN ('postgres', 'supabase_admin')) THEN
    RAISE EXCEPTION 'No autorizado: Solo administradores pueden consultar credenciales de órdenes';
  END IF;

  SELECT jsonb_build_object(
    'order_id', o.id,
    'estado', o.estado,
    'inicia', o.inicia,
    'vence', o.vence,
    'dias_restantes', CASE WHEN o.vence IS NOT NULL THEN (o.vence - CURRENT_DATE) ELSE NULL END,
    'servicio', COALESCE(pr.nombre, ma.plataforma, 'Servicio Digital'),
    'plataforma', COALESCE(ma.plataforma, pr.nombre, ''),
    'cliente_nombre', COALESCE(c.nombre, c.email, 'Cliente'),
    'cliente_telefono', COALESCE(c.telefono, ''),
    'cliente_email', COALESCE(c.email, ''),
    'perfil', COALESCE(pi.nombre_perfil, ''),
    'pin', COALESCE(safe_dec_text(pi.pin), ''),
    'correo', COALESCE(safe_dec_text(ma.correo), ''),
    'clave', COALESCE(safe_dec_text(ma.clave), ''),
    'datos_recarga', o.datos_recarga,
    'referencia', o.referencia,
    'total_usd', o.total_usd,
    'total_bs', o.total_bs,
    'profile_id', o.profile_id,
    'mother_id', pi.mother_id
  ) INTO v_res
  FROM orders o
  LEFT JOIN customers c ON c.id = o.customer_id
  LEFT JOIN products pr ON pr.id = o.product_id
  LEFT JOIN profiles_inventory pi ON pi.id = o.profile_id
  LEFT JOIN mother_accounts ma ON ma.id = pi.mother_id
  WHERE o.id = p_order_id;

  RETURN v_res;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_order_credentials(uuid) TO authenticated, anon;

-- Batch helper para el listado de pedidos
CREATE OR REPLACE FUNCTION public.admin_get_orders_credentials(p_order_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_res jsonb;
BEGIN
  IF NOT (is_admin() OR auth.role() = 'service_role' OR current_user IN ('postgres', 'supabase_admin')) THEN
    RAISE EXCEPTION 'No autorizado: Solo administradores pueden consultar credenciales de órdenes';
  END IF;

  SELECT jsonb_object_agg(
    o.id::text,
    jsonb_build_object(
      'order_id', o.id,
      'estado', o.estado,
      'inicia', o.inicia,
      'vence', o.vence,
      'dias_restantes', CASE WHEN o.vence IS NOT NULL THEN (o.vence - CURRENT_DATE) ELSE NULL END,
      'servicio', COALESCE(pr.nombre, ma.plataforma, 'Servicio Digital'),
      'plataforma', COALESCE(ma.plataforma, pr.nombre, ''),
      'perfil', COALESCE(pi.nombre_perfil, ''),
      'pin', COALESCE(safe_dec_text(pi.pin), ''),
      'correo', COALESCE(safe_dec_text(ma.correo), ''),
      'clave', COALESCE(safe_dec_text(ma.clave), '')
    )
  ) INTO v_res
  FROM orders o
  LEFT JOIN products pr ON pr.id = o.product_id
  LEFT JOIN profiles_inventory pi ON pi.id = o.profile_id
  LEFT JOIN mother_accounts ma ON ma.id = pi.mother_id
  WHERE o.id = ANY(p_order_ids)
    AND o.profile_id IS NOT NULL;

  RETURN COALESCE(v_res, '{}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_orders_credentials(uuid[]) TO authenticated, anon;
