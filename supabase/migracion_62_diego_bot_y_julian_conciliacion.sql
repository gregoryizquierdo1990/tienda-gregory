-- Migración 62: Configuración Integral Diego Bot (Asistente y Reportes) y Julián (Vigilante Conciliador BDV/BNC)
-- =========================================================================================================

-- 1. Agregar columnas para solicitudes de revendedor en customers
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS solicita_revendedor boolean DEFAULT false;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS solicita_revendedor_at timestamptz;

-- 2. Asegurar campos banco_origen y telefono_origen en bdv_pagos_recibidos
ALTER TABLE public.bdv_pagos_recibidos ADD COLUMN IF NOT EXISTS banco_origen text DEFAULT 'BDV';
ALTER TABLE public.bdv_pagos_recibidos ADD COLUMN IF NOT EXISTS telefono_origen text;

-- 3. Actualizar función RPC de conciliación con separación dual BDV/BNC, ventana de 24h y rol del usuario
CREATE OR REPLACE FUNCTION public.conciliar_pedido_bdv(
  p_ref text,
  p_monto numeric,
  p_raw text DEFAULT null,
  p_telefono text DEFAULT null,
  p_banco text DEFAULT 'BDV'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ref_clean text;
  v_order public.orders;
  v_rate numeric := 0;
  v_expected_bs numeric := 0;
  v_diff numeric := 0;
  v_cust_nombre text := '';
  v_cust_tel text := '';
  v_cust_tg bigint := null;
  v_cust_es_rev boolean := false;
  v_prod_nombre text := '';
  v_mother_correo text := '';
  v_mother_clave text := '';
  v_prof_nombre text := '';
  v_prof_pin text := '';
  v_banco_tag text := upper(coalesce(p_banco, 'BDV'));
BEGIN
  -- 1. Limpiar referencia (solo dígitos y tomar al menos 4 dígitos)
  v_ref_clean := regexp_replace(coalesce(p_ref, ''), '[^0-9]', '', 'g');
  IF length(v_ref_clean) < 4 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Referencia bancaria demasiado corta o inválida');
  END IF;

  -- 2. Obtener tasa BCV más reciente
  SELECT bs_por_usd INTO v_rate FROM public.exchange_rates ORDER BY fecha DESC LIMIT 1;
  IF v_rate IS NULL OR v_rate <= 0 THEN
    v_rate := 1;
  END IF;

  -- 3. Buscar orden pendiente en margen de 24 horas que coincida con la referencia y monto
  FOR v_order IN
    SELECT * FROM public.orders
    WHERE estado = 'pendiente'
      AND created_at >= (now() - interval '24 hours')
    ORDER BY created_at DESC
  LOOP
    DECLARE
      v_ord_ref text := regexp_replace(coalesce(v_order.referencia, ''), '[^0-9]', '', 'g');
    BEGIN
      -- Coincidencia: referencia completa, últimos 6 dígitos o últimos 4 dígitos
      IF length(v_ord_ref) >= 4 AND (
        v_ord_ref = v_ref_clean 
        OR right(v_ord_ref, 6) = right(v_ref_clean, 6)
        OR right(v_ord_ref, 4) = right(v_ref_clean, 4)
        OR v_ref_clean LIKE '%' || v_ord_ref || '%'
        OR v_ord_ref LIKE '%' || v_ref_clean || '%'
      ) THEN
        v_expected_bs := round(coalesce(v_order.total_usd, 0) * v_rate, 2);
        v_diff := abs(v_expected_bs - p_monto);

        -- Margen de tolerancia de hasta 3.00 Bs por redondeos en céntimos bancarios
        IF v_diff <= 3.00 OR p_monto >= (v_expected_bs - 3.00) THEN
          -- MATCH ENCONTRADO: Auto-entregar pedido en inventario
          PERFORM public._deliver(v_order.id);

          UPDATE public.orders
          SET conciliado_por = v_banco_tag || '_AUTOMATIZADO',
              referencia = v_ref_clean
          WHERE id = v_order.id;

          -- Registrar en pagos recibidos ya conciliado
          INSERT INTO public.bdv_pagos_recibidos (referencia, monto_bs, telefono_origen, banco_origen, raw_texto, conciliado, conciliado_at, order_id)
          VALUES (v_ref_clean, p_monto, p_telefono, v_banco_tag, p_raw, true, now(), v_order.id);

          -- Obtener datos completos de cliente y rol
          SELECT c.nombre, c.telefono, c.telegram_chat_id, coalesce(c.es_revendedor, false)
          INTO v_cust_nombre, v_cust_tel, v_cust_tg, v_cust_es_rev
          FROM public.customers c WHERE c.id = v_order.customer_id;

          SELECT pr.nombre INTO v_prod_nombre FROM public.products pr WHERE pr.id = v_order.product_id;

          -- Obtener credenciales entregadas
          SELECT 
            coalesce(m.correo, ''),
            coalesce(public.dec_text(m.clave), ''),
            coalesce(prof.nombre_perfil, ''),
            coalesce(prof.pin, '')
          INTO v_mother_correo, v_mother_clave, v_prof_nombre, v_prof_pin
          FROM public.orders o
          JOIN public.profiles_inventory prof ON prof.id = o.profile_id
          LEFT JOIN public.mother_accounts m ON m.id = prof.mother_id
          WHERE o.id = v_order.id;

          RETURN jsonb_build_object(
            'ok', true,
            'matched', true,
            'order_id', v_order.id,
            'banco', v_banco_tag,
            'cliente', coalesce(v_cust_nombre, 'Cliente'),
            'telefono', coalesce(v_cust_tel, ''),
            'telegram_chat_id', v_cust_tg,
            'es_revendedor', v_cust_es_rev,
            'cliente_rol', CASE WHEN v_cust_es_rev THEN 'Revendedor Oficial' ELSE 'Cliente Final' END,
            'producto', coalesce(v_prod_nombre, 'Servicio Digital'),
            'total_usd', v_order.total_usd,
            'monto_bs', p_monto,
            'referencia', v_ref_clean,
            'telefono_origen', coalesce(p_telefono, ''),
            'correo_cuenta', v_mother_correo,
            'clave_cuenta', v_mother_clave,
            'nombre_perfil', v_prof_nombre,
            'pin_perfil', v_prof_pin
          );
        END IF;
      END IF;
    END;
  END LOOP;

  -- 4. Si aún no existe orden pendiente: Guardar en buffer
  INSERT INTO public.bdv_pagos_recibidos (referencia, monto_bs, telefono_origen, banco_origen, raw_texto, conciliado)
  VALUES (v_ref_clean, p_monto, p_telefono, v_banco_tag, p_raw, false);

  RETURN jsonb_build_object(
    'ok', true,
    'matched', false,
    'buffered', true,
    'banco', v_banco_tag,
    'referencia', v_ref_clean,
    'telefono_origen', coalesce(p_telefono, ''),
    'monto_bs', p_monto
  );
END;
$$;
