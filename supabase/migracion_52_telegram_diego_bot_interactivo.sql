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
    COALESCE(p.nombre, s.nombre, 'Servicio Digital') AS servicio,
    o.tipo::text,
    COALESCE(o.datos_recarga, '{}'::jsonb) AS datos_recarga,
    COALESCE(dec_text(a.correo_cifrado), a.correo) AS correo,
    COALESCE(dec_text(a.clave_cifrada), a.clave) AS clave,
    prof.nombre_perfil AS perfil,
    COALESCE(dec_text(prof.pin_cifrado), prof.pin) AS pin,
    o.fecha_inicio AS inicia,
    o.fecha_vencimiento AS vence,
    (o.fecha_vencimiento - CURRENT_DATE)::integer AS dias_restantes,
    o.estado::text
  FROM orders o
  LEFT JOIN products p ON p.id = o.product_id
  LEFT JOIN services s ON s.id = p.servicio_id
  LEFT JOIN accounts a ON a.id = o.account_id
  LEFT JOIN account_profiles prof ON prof.id = o.profile_id
  WHERE o.customer_id = p_customer_id
    AND o.estado IN ('entregado', 'pagado')
    AND (o.fecha_vencimiento IS NULL OR o.fecha_vencimiento >= CURRENT_DATE - 1)
  ORDER BY o.fecha_vencimiento ASC NULLS LAST;
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
    COALESCE(SUM(monto_usd), 0),
    COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', id,
        'order_id', order_id,
        'monto_usd', monto_usd,
        'fecha_vencimiento', fecha_vencimiento,
        'estado', estado,
        'plataforma', plataforma_nombre,
        'perfil', nombre_perfil,
        'vencida', (fecha_vencimiento < CURRENT_DATE)
      ) ORDER BY fecha_vencimiento ASC
    ), '[]'::jsonb)
  INTO v_deuda, v_cuotas
  FROM installments
  WHERE customer_id = p_customer_id
    AND estado != 'pagada';

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
