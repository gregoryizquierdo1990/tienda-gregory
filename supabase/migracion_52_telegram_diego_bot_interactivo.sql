-- MIGRACIÓN 52: AUTOMATIZACIÓN E INTERACTIVIDAD DE DIEGO_BOT (TELEGRAM)
-- Vincula el bot @Diego1asistente_bot directamente con las cuentas de clientes y revendedores.
-- Permite login por Email/ID/Teléfono + Contraseña y vinculación en 1 clic.

-- 1. Asegurar columnas de Telegram en customers
ALTER TABLE public.customers
ADD COLUMN IF NOT EXISTS telegram_chat_id bigint,
ADD COLUMN IF NOT EXISTS telegram_username text;

CREATE INDEX IF NOT EXISTS idx_customers_telegram_chat ON public.customers(telegram_chat_id);
CREATE INDEX IF NOT EXISTS idx_customers_codigo_id ON public.customers(codigo_identificacion);

-- 2. Tabla de sesiones de conversación en Telegram
CREATE TABLE IF NOT EXISTS public.telegram_sessions (
  chat_id bigint PRIMARY KEY,
  telegram_user_id bigint,
  telegram_username text,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  step text DEFAULT 'unauthenticated',
  temp_identifier text,
  auth_token text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_telegram_sessions_customer ON public.telegram_sessions(customer_id);
CREATE INDEX IF NOT EXISTS idx_telegram_sessions_auth_token ON public.telegram_sessions(auth_token);

ALTER TABLE public.telegram_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS telegram_sessions_service_role ON public.telegram_sessions;
CREATE POLICY telegram_sessions_service_role ON public.telegram_sessions
FOR ALL USING (auth.role() = 'service_role');

-- 2.1 Helper seguro de descifrado que no lanza excepciones
CREATE OR REPLACE FUNCTION public.safe_dec_text(t text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
BEGIN
  IF t IS NULL THEN
    RETURN NULL;
  END IF;
  IF t LIKE 'enc:%' THEN
    BEGIN
      RETURN pgp_sym_decrypt(decode(substr(t, 5), 'base64'), (SELECT value FROM secrets WHERE name = 'enc_key'));
    EXCEPTION WHEN OTHERS THEN
      RETURN t;
    END;
  ELSE
    RETURN t;
  END IF;
END;
$$;

-- 3. Función RPC: Obtener credenciales activas descifradas para el bot
CREATE OR REPLACE FUNCTION public.bot_get_customer_credentials(p_customer_id uuid)
RETURNS TABLE (
  order_id uuid,
  servicio text,
  tipo text,
  datos_recarga jsonb,
  correo text,
  clave text,
  perfil text,
  pin text,
  inicia date,
  vence date,
  dias_restantes integer,
  estado text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.id AS order_id,
    COALESCE(prod.nombre, ma.plataforma, 'Servicio Digital')::text AS servicio,
    COALESCE(prod.tipo, 'perfil')::text AS tipo,
    COALESCE(o.datos_recarga, '{}'::jsonb) AS datos_recarga,
    COALESCE(safe_dec_text(ma.correo), ma.correo, '')::text AS correo,
    COALESCE(safe_dec_text(ma.clave), ma.clave, '')::text AS clave,
    COALESCE(prof.nombre_perfil, '')::text AS perfil,
    COALESCE(safe_dec_text(prof.pin), prof.pin, '')::text AS pin,
    o.inicia AS inicia,
    o.vence AS vence,
    CASE WHEN o.vence IS NOT NULL THEN (o.vence - CURRENT_DATE)::integer ELSE NULL END AS dias_restantes,
    o.estado::text
  FROM orders o
  LEFT JOIN products prod ON prod.id = o.product_id
  LEFT JOIN profiles_inventory prof ON prof.id = o.profile_id
  LEFT JOIN mother_accounts ma ON ma.id = prof.mother_id
  WHERE o.customer_id = p_customer_id
    AND o.estado IN ('entregado', 'pagado')
    AND (o.vence IS NULL OR o.vence >= CURRENT_DATE - 1)

  UNION ALL

  SELECT 
    prof2.id AS order_id,
    COALESCE(prod2.nombre, ma2.plataforma, 'Servicio Digital')::text AS servicio,
    COALESCE(prod2.tipo, 'perfil')::text AS tipo,
    '{}'::jsonb AS datos_recarga,
    COALESCE(safe_dec_text(ma2.correo), ma2.correo, '')::text AS correo,
    COALESCE(safe_dec_text(ma2.clave), ma2.clave, '')::text AS clave,
    COALESCE(prof2.nombre_perfil, '')::text AS perfil,
    COALESCE(safe_dec_text(prof2.pin), prof2.pin, '')::text AS pin,
    prof2.inicia AS inicia,
    prof2.vence AS vence,
    CASE WHEN prof2.vence IS NOT NULL THEN (prof2.vence - CURRENT_DATE)::integer ELSE NULL END AS dias_restantes,
    prof2.estado::text
  FROM profiles_inventory prof2
  LEFT JOIN products prod2 ON prod2.id = prof2.product_id
  LEFT JOIN mother_accounts ma2 ON ma2.id = prof2.mother_id
  WHERE prof2.assigned_customer_id = p_customer_id
    AND prof2.estado = 'vendido'
    AND (prof2.vence IS NULL OR prof2.vence >= CURRENT_DATE - 1)
    AND prof2.id NOT IN (
      SELECT o2.profile_id FROM orders o2 WHERE o2.customer_id = p_customer_id AND o2.profile_id IS NOT NULL
    )
  ORDER BY vence ASC NULLS LAST;
END;
$$;

-- 4. Función RPC: Resumen de línea de crédito y deudas pendientes
CREATE OR REPLACE FUNCTION public.bot_get_customer_debt_summary(p_customer_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limite numeric := 0;
  v_deuda numeric := 0;
  v_disp numeric := 0;
  v_cuotas jsonb := '[]'::jsonb;
  v_es_revendedor boolean := false;
BEGIN
  SELECT COALESCE(limite_credito, 0), COALESCE(es_revendedor, false)
  INTO v_limite, v_es_revendedor
  FROM customers
  WHERE id = p_customer_id;

  SELECT 
    COALESCE(SUM(i.monto_usd), 0),
    COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', i.id,
        'order_id', i.order_id,
        'monto_usd', i.monto_usd,
        'fecha_vencimiento', i.fecha_vencimiento,
        'estado', i.estado,
        'numero_cuota', i.numero_cuota,
        'total_cuotas', i.total_cuotas,
        'plataforma', COALESCE(ma.plataforma, prod.nombre, 'Servicio'),
        'perfil', prof.nombre_perfil,
        'vencida', (i.fecha_vencimiento < CURRENT_DATE)
      ) ORDER BY i.fecha_vencimiento ASC
    ), '[]'::jsonb)
  INTO v_deuda, v_cuotas
  FROM installments i
  LEFT JOIN orders o ON o.id = i.order_id
  LEFT JOIN products prod ON prod.id = o.product_id
  LEFT JOIN profiles_inventory prof ON prof.id = o.profile_id
  LEFT JOIN mother_accounts ma ON ma.id = prof.mother_id
  WHERE i.customer_id = p_customer_id
    AND i.estado != 'pagada';

  v_disp := GREATEST(0, v_limite - v_deuda);

  RETURN jsonb_build_object(
    'limite_credito', v_limite,
    'deuda_total', v_deuda,
    'credito_disponible', v_disp,
    'es_revendedor', v_es_revendedor,
    'cuotas', v_cuotas
  );
END;
$$;

-- 5. Actualizar respuesta de /start en bot_commands para coincidir con la presentación oficial
UPDATE public.bot_commands 
SET response = 'Hola Mi nombre es Diego_bot Asistente de Gestio de Emprendimiento Gregory Izquierdo en que puedo ayudarte' 
WHERE trigger = '/start';
