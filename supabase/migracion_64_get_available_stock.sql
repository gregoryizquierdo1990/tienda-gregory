-- Migración 64: Función RPC para consultar el inventario de suscripciones disponibles en tiempo real por plataforma
CREATE OR REPLACE FUNCTION public.get_available_stock()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_agg(sub) INTO v_result
  FROM (
    SELECT
      coalesce(pr.nombre, m.plataforma, 'Servicio Digital') as plataforma,
      coalesce(pr.tipo, 'pantalla') as tipo,
      coalesce(pr.precio_usd, 0) as precio_usd,
      coalesce(pr.precio_revendedor_usd, 0) as precio_revendedor_usd,
      count(pi.id) filter (where pi.estado = 'disponible') as disponibles,
      count(pi.id) filter (where pi.estado = 'vendido') as vendidos,
      count(pi.id) as total
    FROM public.profiles_inventory pi
    LEFT JOIN public.products pr ON pr.id = pi.product_id
    LEFT JOIN public.mother_accounts m ON m.id = pi.mother_id
    GROUP BY coalesce(pr.nombre, m.plataforma, 'Servicio Digital'), pr.tipo, pr.precio_usd, pr.precio_revendedor_usd
    ORDER BY count(pi.id) filter (where pi.estado = 'disponible') DESC, plataforma ASC
  ) sub;

  RETURN coalesce(v_result, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_available_stock() TO anon, authenticated, service_role;
