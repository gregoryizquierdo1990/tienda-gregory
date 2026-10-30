-- Migración 60: Función RPC para alimentar al Asistente Gemini con toda la información de la tienda en tiempo real
CREATE OR REPLACE FUNCTION public.get_gemini_store_context()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_res jsonb;
  v_bcv numeric;
  v_catalogo jsonb;
  v_metodos jsonb;
  v_revendedores jsonb;
  v_deudas jsonb;
  v_stock jsonb;
  v_vencimientos jsonb;
  v_pedidos jsonb;
BEGIN
  -- 1. Tasa BCV oficial
  SELECT coalesce(tasa, 889.2553) INTO v_bcv
  FROM public.tasas_bcv
  ORDER BY fecha DESC
  LIMIT 1;

  -- 2. Catálogo de productos con precios PVP, Revendedor, Binance USDT y días
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'nombre', p.nombre,
      'categoria', p.categoria,
      'dias', p.dias,
      'precio_usd_pvp', p.precio_usd,
      'precio_revendedor_usd', p.precio_revendedor,
      'precio_binance_usdt', p.precio_binance,
      'es_combo', coalesce(p.es_combo, false)
    ) ORDER BY p.categoria, p.nombre
  ), '[]'::jsonb) INTO v_catalogo
  FROM public.products p
  WHERE p.activo = true;

  -- 3. Métodos de pago oficiales
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'nombre', m.nombre,
      'tipo', m.tipo,
      'activo', m.activo
    )
  ), '[]'::jsonb) INTO v_metodos
  FROM public.payment_methods m
  WHERE m.activo = true;

  -- 4. Revendedores oficiales y balance
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'nombre', c.nombre,
      'codigo_revendedor', c.codigo_revendedor,
      'telefono', c.telefono,
      'limite_credito_usd', c.limite_credito_usd
    ) ORDER BY c.nombre
  ), '[]'::jsonb) INTO v_revendedores
  FROM public.customers c
  WHERE c.es_revendedor = true;

  -- 5. Deudas de revendedores / cuotas pendientes
  SELECT coalesce(jsonb_agg(d), '[]'::jsonb) INTO v_deudas
  FROM (
    SELECT
      c.nombre AS revendedor,
      count(i.id) AS cuotas_pendientes,
      round(sum(i.monto_usd), 2) AS total_deuda_usd,
      round(sum(CASE WHEN i.fecha_vencimiento < CURRENT_DATE THEN i.monto_usd ELSE 0 END), 2) AS deuda_vencida_usd
    FROM public.order_invoices i
    JOIN public.orders o ON o.id = i.order_id
    JOIN public.customers c ON c.id = o.customer_id
    WHERE i.estado = 'pendiente'
    GROUP BY c.nombre
  ) d;

  -- 6. Stock disponible por plataforma
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'plataforma', s.plataforma,
      'total_perfiles', s.total,
      'vendidos', s.vendidos,
      'disponibles', s.disponibles
    ) ORDER BY s.disponibles DESC
  ), '[]'::jsonb) INTO v_stock
  FROM (
    SELECT
      ma.servicio AS plataforma,
      count(pi.id) AS total,
      count(pi.id) FILTER (WHERE pi.estado = 'vendido') AS vendidos,
      count(pi.id) FILTER (WHERE pi.estado = 'disponible') AS disponibles
    FROM public.mother_accounts ma
    JOIN public.profiles_inventory pi ON pi.mother_account_id = ma.id
    WHERE ma.activo = true
    GROUP BY ma.servicio
  ) s;

  -- 7. Próximos vencimientos de clientes (próximos 4 días)
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'servicio', ma.servicio,
      'perfil', pi.perfil_nombre,
      'cliente', c.nombre,
      'telefono', c.telefono,
      'vence', pi.vence
    ) ORDER BY pi.vence ASC
  ), '[]'::jsonb) INTO v_vencimientos
  FROM public.profiles_inventory pi
  JOIN public.mother_accounts ma ON ma.id = pi.mother_account_id
  LEFT JOIN public.customers c ON c.id = pi.customer_id
  WHERE pi.estado = 'vendido'
    AND pi.vence IS NOT NULL
    AND pi.vence BETWEEN CURRENT_DATE - INTERVAL '1 day' AND CURRENT_DATE + INTERVAL '4 days';

  -- 8. Últimos 20 pedidos
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id_corto', substring(o.id::text, 1, 8),
      'fecha', to_char(o.created_at, 'YYYY-MM-DD HH24:MI'),
      'cliente', coalesce(c.nombre, 'Sin cliente'),
      'revendedor', o.vendedor_nombre,
      'producto', p.nombre,
      'monto_usd', o.monto_usd,
      'monto_bs', o.monto_bs,
      'estado', o.status,
      'referencia', o.referencia
    )
  ), '[]'::jsonb) INTO v_pedidos
  FROM (
    SELECT * FROM public.orders
    ORDER BY created_at DESC
    LIMIT 20
  ) o
  LEFT JOIN public.customers c ON c.id = o.customer_id
  LEFT JOIN public.products p ON p.id = o.product_id;

  -- Consolidación final
  v_res := jsonb_build_object(
    'tasa_bcv', v_bcv,
    'catalogo_productos', v_catalogo,
    'metodos_pago_oficiales', v_metodos,
    'revendedores_oficiales', v_revendedores,
    'deudas_revendedores', v_deudas,
    'stock_por_plataforma', v_stock,
    'vencimientos_proximos_perfiles', v_vencimientos,
    'ultimos_pedidos', v_pedidos
  );

  RETURN v_res;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_gemini_store_context() TO authenticated, service_role, anon;
