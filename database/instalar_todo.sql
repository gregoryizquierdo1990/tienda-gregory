-- ==============================================================================
-- INSTALAR_TODO.SQL
-- Emprendimiento Gregory Izquierdo - Script Maestro de Instalación Consolidado
-- Ejecutable con un solo clic en: pgAdmin, DBeaver, Supabase SQL Editor, psql
-- ==============================================================================

\echo '>>> INICIANDO INSTALACIÓN MAESTRA DE EMPRENDIMIENTO GREGORY IZQUIERDO <<<'

-- [PASO 0]: Extensiones y Capa de Compatibilidad Auth
-- ==============================================================================
-- 00_COMPATIBILIDAD_AUTH_Y_EXTENSIONES.SQL
-- Emprendimiento Gregory Izquierdo - Suite de Instalación PostgreSQL Independiente
-- Permite correr la plataforma en cualquier PostgreSQL (Docker, VPS, RDS, Neon) o Supabase
-- ==============================================================================

-- 1. Extensiones Criptográficas y de Identificadores UUID
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Capa de Compatibilidad de Autenticación (Auth Shim)
-- En Supabase, la tabla auth.users y auth.uid() son provistas por GoTrue.
-- En PostgreSQL estándar o VPS, este bloque asegura que existan exactamente con la misma
-- estructura, permitiendo foreign keys, triggers y consultas sin cambios en el código.
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE,
  raw_user_meta_data JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Función auth.uid() universal:
-- Funciona con Supabase JWT, o con variables de sesión 'request.jwt.claim.sub' o 'app.current_user_id'
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_sub text;
BEGIN
  v_sub := nullif(current_setting('request.jwt.claim.sub', true), '');
  IF v_sub IS NOT NULL THEN
    RETURN v_sub::uuid;
  END IF;
  v_sub := nullif(current_setting('app.current_user_id', true), '');
  IF v_sub IS NOT NULL THEN
    RETURN v_sub::uuid;
  END IF;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$;

-- 3. Capa de Compatibilidad para Llamadas HTTP Asíncronas (pg_net Shim)
-- En Supabase existe la extensión pg_net con net.http_post().
-- En PostgreSQL puro sin pg_net, este stub evita que fallen los triggers de órdenes e incidencias.
CREATE SCHEMA IF NOT EXISTS net;

CREATE OR REPLACE FUNCTION net.http_post(
  url text,
  headers jsonb DEFAULT '{}'::jsonb,
  body jsonb DEFAULT '{}'::jsonb,
  timeout_milliseconds integer DEFAULT 2000
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
BEGIN
  -- Stub seguro: en PostgreSQL sin pg_net, absorbe la petición sin romper la transacción de la orden.
  RETURN 1;
END;
$$;


-- [PASO 1]: Tablas, Llaves Foráneas, Vistas e Índices
-- ==============================================================================
-- 01_TABLAS_E_INDICES.SQL
-- Emprendimiento Gregory Izquierdo - Suite de Instalación PostgreSQL Independiente
-- Estructura DDL Consolidada Definitiva (35 Tablas + Índices)
-- ==============================================================================

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE TABLE IF NOT EXISTS public.admins (
  email TEXT NOT NULL,
  CONSTRAINT admins_pkey PRIMARY KEY (email)
);

CREATE TABLE IF NOT EXISTS public.secrets (
  name TEXT NOT NULL,
  value TEXT NOT NULL,
  CONSTRAINT secrets_pkey PRIMARY KEY (name)
);

CREATE TABLE IF NOT EXISTS public.settings (
  key TEXT NOT NULL,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT settings_pkey PRIMARY KEY (key)
);

CREATE TABLE IF NOT EXISTS public.exchange_rates (
  fecha DATE DEFAULT CURRENT_DATE NOT NULL,
  bs_por_usd NUMERIC NOT NULL,
  fuente TEXT DEFAULT 'BCV'::text,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT exchange_rates_pkey PRIMARY KEY (fecha)
);

CREATE TABLE IF NOT EXISTS public.customers (
  id UUID NOT NULL,
  nombre TEXT,
  email TEXT,
  telefono TEXT,
  zeny_balance NUMERIC DEFAULT 0 NOT NULL,
  gcontact_id TEXT,
  creado TIMESTAMPTZ DEFAULT now(),
  limite_credito NUMERIC DEFAULT 0.00 NOT NULL,
  nivel_credito TEXT DEFAULT 'Bronce'::text NOT NULL,
  es_revendedor BOOLEAN DEFAULT false NOT NULL,
  codigo_identificacion TEXT,
  debe_cambiar_password BOOLEAN DEFAULT false,
  es_franquicia BOOLEAN DEFAULT false,
  vendedor_id UUID,
  vendedor_nombre TEXT,
  franchise_id UUID,
  telegram_chat_id BIGINT,
  telegram_username TEXT,
  es_demo BOOLEAN DEFAULT false,
  CONSTRAINT customers_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.categories (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  nombre TEXT NOT NULL,
  orden INTEGER DEFAULT 0,
  activo BOOLEAN DEFAULT true,
  CONSTRAINT categories_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.products (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  category_id UUID,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  tipo TEXT DEFAULT 'pantalla'::text NOT NULL,
  precio_usd NUMERIC NOT NULL,
  duracion_dias INTEGER DEFAULT 30 NOT NULL,
  garantia_dias INTEGER DEFAULT 30,
  imagen_url TEXT,
  activo BOOLEAN DEFAULT true,
  orden INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  precio_revendedor_usd NUMERIC,
  precio_binance_usd NUMERIC,
  permite_cuotas BOOLEAN DEFAULT false,
  es_exclusivo_central BOOLEAN DEFAULT false NOT NULL,
  campos_requeridos JSONB DEFAULT '[]'::jsonb NOT NULL,
  operadora_o_juego TEXT,
  costo_usdt NUMERIC DEFAULT 0.00,
  costo_bs NUMERIC DEFAULT 0.00,
  comision_revendedor_usd NUMERIC DEFAULT 0.00,
  ganancia_tienda_usd NUMERIC DEFAULT 0.00,
  reparto_bs_pablo NUMERIC DEFAULT 0.00,
  reparto_bs_negocio NUMERIC DEFAULT 0.00,
  reparto_bs_gregory NUMERIC DEFAULT 0.00,
  reparto_usdt_pablo NUMERIC DEFAULT 0.00,
  reparto_usdt_negocio NUMERIC DEFAULT 0.00,
  reparto_usdt_gregory NUMERIC DEFAULT 0.00,
  CONSTRAINT products_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.banners (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  titulo TEXT,
  texto TEXT,
  imagen_url TEXT,
  enlace TEXT,
  orden INTEGER DEFAULT 0,
  activo BOOLEAN DEFAULT true,
  inicio DATE,
  fin DATE,
  CONSTRAINT banners_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.franchises (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  subdominio TEXT NOT NULL,
  nombre_comercial TEXT NOT NULL,
  titular_nombre TEXT NOT NULL,
  titular_cedula_rif TEXT,
  titular_telefono TEXT NOT NULL,
  titular_correo TEXT NOT NULL,
  titular_ciudad TEXT,
  logo_url TEXT,
  color_primario TEXT DEFAULT '#00d4ff'::text NOT NULL,
  canon_mensual_usd NUMERIC DEFAULT 25.00 NOT NULL,
  estado TEXT DEFAULT 'activo'::text NOT NULL,
  fecha_inicio DATE DEFAULT CURRENT_DATE NOT NULL,
  fecha_vencimiento_canon DATE DEFAULT (CURRENT_DATE + '30 days'::interval) NOT NULL,
  modulos_activos JSONB DEFAULT '{"gemini": false, "cuotas_bnpl": false, "bot_telegram": false, "vencimientos": true}'::jsonb NOT NULL,
  contrato_texto TEXT,
  contrato_aceptado BOOLEAN DEFAULT true NOT NULL,
  contrato_aceptado_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  notas_internas TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  saldo_billetera_usd NUMERIC DEFAULT 0.00 NOT NULL,
  nivel_volumen TEXT DEFAULT 'bronce'::text NOT NULL,
  compras_mes_usd NUMERIC DEFAULT 0.00 NOT NULL,
  kyc_datos JSONB DEFAULT '{}'::jsonb,
  kyc_estado TEXT DEFAULT 'verificado'::text,
  CONSTRAINT franchises_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.mother_accounts (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  plataforma TEXT NOT NULL,
  correo TEXT NOT NULL,
  clave TEXT,
  proveedor TEXT,
  costo_usd NUMERIC DEFAULT 0,
  vence DATE,
  max_perfiles INTEGER DEFAULT 5,
  notas TEXT,
  activa BOOLEAN DEFAULT true,
  franchise_id UUID,
  CONSTRAINT mother_accounts_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.profiles_inventory (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  mother_id UUID,
  product_id UUID,
  nombre_perfil TEXT,
  pin TEXT,
  vendedor TEXT,
  inicia DATE,
  vence DATE,
  estado TEXT DEFAULT 'disponible'::text NOT NULL,
  vendedor_id UUID,
  assigned_customer_id UUID,
  no_renueva BOOLEAN DEFAULT false,
  no_renueva_reportado_at TIMESTAMPTZ,
  no_renueva_motivo TEXT,
  no_renueva_por TEXT,
  franchise_id UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  cliente_final TEXT,
  cliente_telefono TEXT,
  CONSTRAINT profiles_inventory_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.payment_methods (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  nombre TEXT NOT NULL,
  tipo TEXT,
  datos JSONB DEFAULT '{}'::jsonb,
  activo BOOLEAN DEFAULT true,
  orden INTEGER DEFAULT 0,
  franchise_id UUID,
  CONSTRAINT payment_methods_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.orders (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  customer_id UUID,
  product_id UUID,
  profile_id UUID,
  total_usd NUMERIC NOT NULL,
  tasa_bs NUMERIC,
  total_bs NUMERIC,
  metodo_id UUID,
  referencia TEXT,
  comprobante_url TEXT,
  estado TEXT DEFAULT 'pendiente'::text NOT NULL,
  inicia DATE,
  vence DATE,
  proximo_pago DATE,
  gcal_event_id TEXT,
  pagado_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  zeny_aplicado NUMERIC DEFAULT 0 NOT NULL,
  conciliado_por TEXT,
  conciliado_at TIMESTAMPTZ,
  datos_recarga JSONB DEFAULT '{}'::jsonb NOT NULL,
  estado_recarga TEXT DEFAULT 'pendiente'::text,
  vendedor_id UUID,
  no_renueva BOOLEAN DEFAULT false,
  no_renueva_reportado_at TIMESTAMPTZ,
  no_renueva_motivo TEXT,
  franchise_id UUID,
  entregado_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT orders_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.invoices (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  numero BIGINT NOT NULL,
  order_id UUID,
  customer_id UUID,
  total_usd NUMERIC,
  total_bs NUMERIC,
  tasa_bs NUMERIC,
  estado TEXT DEFAULT 'emitida'::text NOT NULL,
  emitida TIMESTAMPTZ DEFAULT now(),
  franchise_id UUID,
  CONSTRAINT invoices_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.installments (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  order_id UUID NOT NULL,
  customer_id UUID,
  numero_cuota INTEGER DEFAULT 1 NOT NULL,
  total_cuotas INTEGER DEFAULT 2 NOT NULL,
  monto_usd NUMERIC NOT NULL,
  monto_bs NUMERIC,
  tasa_bs NUMERIC,
  fecha_vencimiento DATE DEFAULT CURRENT_DATE NOT NULL,
  estado TEXT DEFAULT 'pendiente'::text NOT NULL,
  metodo_id UUID,
  referencia TEXT,
  comprobante_url TEXT,
  pagada_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  reseller_id UUID,
  CONSTRAINT installments_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.zeny_cards (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  customer_id UUID NOT NULL,
  numero_tarjeta TEXT NOT NULL,
  nombre_titular TEXT NOT NULL,
  codigo_activacion TEXT NOT NULL,
  fecha_vencimiento TEXT DEFAULT '12/31'::text NOT NULL,
  estado TEXT DEFAULT 'activa'::text NOT NULL,
  descuento_porcentaje NUMERIC DEFAULT 5.00 NOT NULL,
  activada_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT zeny_cards_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.zeny_ledger (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  customer_id UUID NOT NULL,
  tipo TEXT NOT NULL,
  monto NUMERIC NOT NULL,
  referencia TEXT,
  estado TEXT DEFAULT 'aprobado'::text,
  created_at TIMESTAMPTZ DEFAULT now(),
  order_id UUID,
  CONSTRAINT zeny_ledger_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.refunds (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  order_id UUID NOT NULL,
  customer_id UUID,
  monto_usd NUMERIC NOT NULL,
  destino TEXT,
  motivo TEXT,
  liberado BOOLEAN,
  created_at TIMESTAMPTZ DEFAULT now(),
  metodo_reembolso TEXT DEFAULT 'zeny'::text,
  referencia_soporte TEXT,
  destinatario_datos TEXT,
  accion_perfil TEXT DEFAULT 'liberar'::text,
  diferencia_precio_usd NUMERIC DEFAULT 0.00,
  tasa_cambio NUMERIC,
  monto_bs NUMERIC,
  CONSTRAINT refunds_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.expenses (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  fecha DATE DEFAULT CURRENT_DATE NOT NULL,
  concepto TEXT NOT NULL,
  categoria TEXT,
  monto_usd NUMERIC NOT NULL,
  notas TEXT,
  CONSTRAINT expenses_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.purchases (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  fecha DATE DEFAULT CURRENT_DATE NOT NULL,
  proveedor TEXT,
  plataforma TEXT,
  mother_id UUID,
  monto_usd NUMERIC NOT NULL,
  notas TEXT,
  monto_bs NUMERIC DEFAULT 0.00,
  monto_usdt NUMERIC DEFAULT 0.00,
  es_credito BOOLEAN DEFAULT false NOT NULL,
  dias_credito INTEGER DEFAULT 0,
  fecha_limite_pago DATE,
  estado_pago TEXT DEFAULT 'pagado'::text NOT NULL,
  metodo_pago_proveedor TEXT,
  tasa_usdt_pago NUMERIC,
  monto_pagado_bs NUMERIC,
  pagado_at TIMESTAMPTZ,
  comprobante_pago TEXT,
  CONSTRAINT purchases_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.faqs (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  pregunta TEXT,
  respuesta TEXT,
  orden INTEGER DEFAULT 0,
  activo BOOLEAN DEFAULT true,
  CONSTRAINT faqs_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.login_log (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  customer_id UUID,
  email TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT login_log_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.incidents (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  customer_id UUID,
  order_id UUID,
  asunto TEXT,
  detalle TEXT,
  captura_url TEXT,
  estado TEXT DEFAULT 'abierta'::text,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT incidents_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.google_integrations (
  service TEXT NOT NULL,
  enabled BOOLEAN DEFAULT false,
  config JSONB DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT google_integrations_pkey PRIMARY KEY (service)
);

CREATE TABLE IF NOT EXISTS public.bot_commands (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  trigger TEXT NOT NULL,
  response TEXT NOT NULL,
  orden INTEGER DEFAULT 0,
  activo BOOLEAN DEFAULT true,
  CONSTRAINT bot_commands_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.transfers (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  order_id UUID,
  customer_id UUID,
  from_profile UUID,
  to_profile UUID,
  motivo TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT transfers_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  endpoint TEXT NOT NULL,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  user_id UUID,
  CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.recargas_puntos (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  nombre TEXT NOT NULL,
  apellido TEXT NOT NULL,
  email TEXT NOT NULL,
  clave_acceso TEXT,
  pais TEXT DEFAULT 'Venezuela'::text NOT NULL,
  estado_region TEXT DEFAULT 'Distrito Capital'::text NOT NULL,
  telefono TEXT NOT NULL,
  nombre_taquilla TEXT NOT NULL,
  usuario_recargas247 TEXT,
  canon_mensual_usd NUMERIC DEFAULT 5.00 NOT NULL,
  fecha_vencimiento_canon DATE DEFAULT (CURRENT_DATE + 30) NOT NULL,
  comision_deposito_pct NUMERIC DEFAULT 3.00 NOT NULL,
  saldo_actual_247 NUMERIC DEFAULT 0 NOT NULL,
  estado TEXT DEFAULT 'activo'::text NOT NULL,
  notas TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT recargas_puntos_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.recargas_abonos (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  punto_id UUID NOT NULL,
  monto_depositado_usd NUMERIC NOT NULL,
  comision_distribuidor_pct NUMERIC DEFAULT 3.00 NOT NULL,
  ganancia_gregory_usd NUMERIC DEFAULT 0 NOT NULL,
  saldo_acreditado_usd NUMERIC DEFAULT 0 NOT NULL,
  monto_bs NUMERIC,
  tasa_bcv NUMERIC,
  metodo_pago TEXT NOT NULL,
  referencia TEXT NOT NULL,
  comprobante_url TEXT,
  estado TEXT DEFAULT 'pendiente'::text NOT NULL,
  notas_admin TEXT,
  abonado_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT recargas_abonos_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.mesa_cambio_caja (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  tipo TEXT NOT NULL,
  monto_usdt NUMERIC NOT NULL,
  tasa_compra_bs NUMERIC,
  costo_total_bs NUMERIC,
  saldo_posterior_usdt NUMERIC NOT NULL,
  operacion_id UUID,
  notas TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT mesa_cambio_caja_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.mesa_cambio_operaciones (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  customer_id UUID,
  cliente_nombre TEXT,
  cliente_telefono TEXT,
  monto_usdt NUMERIC NOT NULL,
  tasa_bs NUMERIC NOT NULL,
  total_bs NUMERIC NOT NULL,
  destino_tipo TEXT DEFAULT 'binance_id'::text NOT NULL,
  destino_valor TEXT NOT NULL,
  metodo_pago TEXT DEFAULT 'Pago Móvil'::text NOT NULL,
  referencia_bancaria TEXT NOT NULL,
  estado TEXT DEFAULT 'pendiente'::text NOT NULL,
  notas_admin TEXT,
  enviado_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT mesa_cambio_operaciones_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.partner_commissions (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  order_id UUID,
  customer_id UUID,
  vendedor_id UUID NOT NULL,
  product_id UUID,
  servicio_nombre TEXT NOT NULL,
  monto_cobrado_usd NUMERIC DEFAULT 0.00 NOT NULL,
  precio_revendedor_usd NUMERIC DEFAULT 0.00 NOT NULL,
  costo_proveedor_usd NUMERIC DEFAULT 0.00 NOT NULL,
  ganancia_vendedor_usd NUMERIC DEFAULT 0.00 NOT NULL,
  ganancia_gregory_usd NUMERIC DEFAULT 0.00 NOT NULL,
  ganancia_negocio_usd NUMERIC DEFAULT 0.00 NOT NULL,
  tasa_bs NUMERIC DEFAULT 1.0000 NOT NULL,
  ganancia_vendedor_bs NUMERIC DEFAULT 0.00 NOT NULL,
  estado TEXT DEFAULT 'pendiente'::text NOT NULL,
  liquidada_at TIMESTAMPTZ,
  referencia_pago TEXT,
  notas TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  metodo_origen TEXT DEFAULT 'bolivares'::text NOT NULL,
  ganancia_gregory_bs NUMERIC DEFAULT 0.00,
  ganancia_negocio_bs NUMERIC DEFAULT 0.00,
  metodo_pago TEXT,
  pagado_usd NUMERIC,
  pagado_bs NUMERIC,
  pagado_gregory_usd NUMERIC,
  pagado_gregory_bs NUMERIC,
  CONSTRAINT partner_commissions_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.telegram_sessions (
  chat_id BIGINT NOT NULL,
  telegram_user_id BIGINT,
  telegram_username TEXT,
  customer_id UUID,
  step TEXT DEFAULT 'idle'::text,
  temp_identifier TEXT,
  auth_token TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT telegram_sessions_pkey PRIMARY KEY (chat_id)
);

CREATE TABLE IF NOT EXISTS public.franchise_applications (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  business_name TEXT NOT NULL,
  owner_name TEXT NOT NULL,
  cedula_rif TEXT,
  phone TEXT NOT NULL,
  email TEXT NOT NULL,
  telegram_user TEXT,
  ciudad TEXT,
  subdominio_deseado TEXT,
  redes_sociales TEXT,
  doc_frontal_url TEXT,
  doc_reverso_url TEXT,
  selfie_doc_url TEXT,
  comprobante_domicilio_url TEXT,
  kyc_estado TEXT DEFAULT 'pendiente'::text NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT franchise_applications_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.franchise_wallet_ledger (
  id UUID DEFAULT gen_random_uuid() NOT NULL,
  franchise_id UUID,
  tipo TEXT NOT NULL,
  monto_usd NUMERIC NOT NULL,
  saldo_previo_usd NUMERIC DEFAULT 0.00 NOT NULL,
  saldo_posterior_usd NUMERIC DEFAULT 0.00 NOT NULL,
  descripcion TEXT,
  referencia TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT franchise_wallet_ledger_pkey PRIMARY KEY (id)
);

-- ------------------------------------------------------------------------------
-- LLAVES FORÁNEAS (RELACIONES ENTRE TABLAS)
-- ------------------------------------------------------------------------------
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_customers_franchise_id_franchises') THEN
    ALTER TABLE public.customers ADD CONSTRAINT fk_customers_franchise_id_franchises FOREIGN KEY (franchise_id) REFERENCES public.franchises(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_customers_vendedor_id_customers') THEN
    ALTER TABLE public.customers ADD CONSTRAINT fk_customers_vendedor_id_customers FOREIGN KEY (vendedor_id) REFERENCES public.customers(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_franchise_wallet_ledger_franchise_id_franchises') THEN
    ALTER TABLE public.franchise_wallet_ledger ADD CONSTRAINT fk_franchise_wallet_ledger_franchise_id_franchises FOREIGN KEY (franchise_id) REFERENCES public.franchises(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_incidents_customer_id_customers') THEN
    ALTER TABLE public.incidents ADD CONSTRAINT fk_incidents_customer_id_customers FOREIGN KEY (customer_id) REFERENCES public.customers(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_incidents_order_id_orders') THEN
    ALTER TABLE public.incidents ADD CONSTRAINT fk_incidents_order_id_orders FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_installments_reseller_id_customers') THEN
    ALTER TABLE public.installments ADD CONSTRAINT fk_installments_reseller_id_customers FOREIGN KEY (reseller_id) REFERENCES public.customers(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_installments_metodo_id_payment_methods') THEN
    ALTER TABLE public.installments ADD CONSTRAINT fk_installments_metodo_id_payment_methods FOREIGN KEY (metodo_id) REFERENCES public.payment_methods(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_installments_order_id_orders') THEN
    ALTER TABLE public.installments ADD CONSTRAINT fk_installments_order_id_orders FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_installments_customer_id_customers') THEN
    ALTER TABLE public.installments ADD CONSTRAINT fk_installments_customer_id_customers FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invoices_order_id_orders') THEN
    ALTER TABLE public.invoices ADD CONSTRAINT fk_invoices_order_id_orders FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invoices_customer_id_customers') THEN
    ALTER TABLE public.invoices ADD CONSTRAINT fk_invoices_customer_id_customers FOREIGN KEY (customer_id) REFERENCES public.customers(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invoices_franchise_id_franchises') THEN
    ALTER TABLE public.invoices ADD CONSTRAINT fk_invoices_franchise_id_franchises FOREIGN KEY (franchise_id) REFERENCES public.franchises(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mesa_cambio_caja_operacion_id_mesa_cambio_operaciones') THEN
    ALTER TABLE public.mesa_cambio_caja ADD CONSTRAINT fk_mesa_cambio_caja_operacion_id_mesa_cambio_operaciones FOREIGN KEY (operacion_id) REFERENCES public.mesa_cambio_operaciones(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mesa_cambio_operaciones_customer_id_customers') THEN
    ALTER TABLE public.mesa_cambio_operaciones ADD CONSTRAINT fk_mesa_cambio_operaciones_customer_id_customers FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mother_accounts_franchise_id_franchises') THEN
    ALTER TABLE public.mother_accounts ADD CONSTRAINT fk_mother_accounts_franchise_id_franchises FOREIGN KEY (franchise_id) REFERENCES public.franchises(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_orders_franchise_id_franchises') THEN
    ALTER TABLE public.orders ADD CONSTRAINT fk_orders_franchise_id_franchises FOREIGN KEY (franchise_id) REFERENCES public.franchises(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_orders_profile_id_profiles_inventory') THEN
    ALTER TABLE public.orders ADD CONSTRAINT fk_orders_profile_id_profiles_inventory FOREIGN KEY (profile_id) REFERENCES public.profiles_inventory(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_orders_product_id_products') THEN
    ALTER TABLE public.orders ADD CONSTRAINT fk_orders_product_id_products FOREIGN KEY (product_id) REFERENCES public.products(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_orders_metodo_id_payment_methods') THEN
    ALTER TABLE public.orders ADD CONSTRAINT fk_orders_metodo_id_payment_methods FOREIGN KEY (metodo_id) REFERENCES public.payment_methods(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_orders_customer_id_customers') THEN
    ALTER TABLE public.orders ADD CONSTRAINT fk_orders_customer_id_customers FOREIGN KEY (customer_id) REFERENCES public.customers(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_partner_commissions_order_id_orders') THEN
    ALTER TABLE public.partner_commissions ADD CONSTRAINT fk_partner_commissions_order_id_orders FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_partner_commissions_customer_id_customers') THEN
    ALTER TABLE public.partner_commissions ADD CONSTRAINT fk_partner_commissions_customer_id_customers FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_partner_commissions_vendedor_id_customers') THEN
    ALTER TABLE public.partner_commissions ADD CONSTRAINT fk_partner_commissions_vendedor_id_customers FOREIGN KEY (vendedor_id) REFERENCES public.customers(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_partner_commissions_product_id_products') THEN
    ALTER TABLE public.partner_commissions ADD CONSTRAINT fk_partner_commissions_product_id_products FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_payment_methods_franchise_id_franchises') THEN
    ALTER TABLE public.payment_methods ADD CONSTRAINT fk_payment_methods_franchise_id_franchises FOREIGN KEY (franchise_id) REFERENCES public.franchises(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_products_category_id_categories') THEN
    ALTER TABLE public.products ADD CONSTRAINT fk_products_category_id_categories FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_profiles_inventory_product_id_products') THEN
    ALTER TABLE public.profiles_inventory ADD CONSTRAINT fk_profiles_inventory_product_id_products FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_profiles_inventory_assigned_customer_id_customers') THEN
    ALTER TABLE public.profiles_inventory ADD CONSTRAINT fk_profiles_inventory_assigned_customer_id_customers FOREIGN KEY (assigned_customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_profiles_inventory_franchise_id_franchises') THEN
    ALTER TABLE public.profiles_inventory ADD CONSTRAINT fk_profiles_inventory_franchise_id_franchises FOREIGN KEY (franchise_id) REFERENCES public.franchises(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_profiles_inventory_mother_id_mother_accounts') THEN
    ALTER TABLE public.profiles_inventory ADD CONSTRAINT fk_profiles_inventory_mother_id_mother_accounts FOREIGN KEY (mother_id) REFERENCES public.mother_accounts(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_purchases_mother_id_mother_accounts') THEN
    ALTER TABLE public.purchases ADD CONSTRAINT fk_purchases_mother_id_mother_accounts FOREIGN KEY (mother_id) REFERENCES public.mother_accounts(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_recargas_abonos_punto_id_recargas_puntos') THEN
    ALTER TABLE public.recargas_abonos ADD CONSTRAINT fk_recargas_abonos_punto_id_recargas_puntos FOREIGN KEY (punto_id) REFERENCES public.recargas_puntos(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_refunds_order_id_orders') THEN
    ALTER TABLE public.refunds ADD CONSTRAINT fk_refunds_order_id_orders FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_refunds_customer_id_customers') THEN
    ALTER TABLE public.refunds ADD CONSTRAINT fk_refunds_customer_id_customers FOREIGN KEY (customer_id) REFERENCES public.customers(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_telegram_sessions_customer_id_customers') THEN
    ALTER TABLE public.telegram_sessions ADD CONSTRAINT fk_telegram_sessions_customer_id_customers FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_transfers_order_id_orders') THEN
    ALTER TABLE public.transfers ADD CONSTRAINT fk_transfers_order_id_orders FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_transfers_customer_id_customers') THEN
    ALTER TABLE public.transfers ADD CONSTRAINT fk_transfers_customer_id_customers FOREIGN KEY (customer_id) REFERENCES public.customers(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_transfers_to_profile_profiles_inventory') THEN
    ALTER TABLE public.transfers ADD CONSTRAINT fk_transfers_to_profile_profiles_inventory FOREIGN KEY (to_profile) REFERENCES public.profiles_inventory(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_transfers_from_profile_profiles_inventory') THEN
    ALTER TABLE public.transfers ADD CONSTRAINT fk_transfers_from_profile_profiles_inventory FOREIGN KEY (from_profile) REFERENCES public.profiles_inventory(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_zeny_cards_customer_id_customers') THEN
    ALTER TABLE public.zeny_cards ADD CONSTRAINT fk_zeny_cards_customer_id_customers FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_zeny_ledger_order_id_orders') THEN
    ALTER TABLE public.zeny_ledger ADD CONSTRAINT fk_zeny_ledger_order_id_orders FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_zeny_ledger_customer_id_customers') THEN
    ALTER TABLE public.zeny_ledger ADD CONSTRAINT fk_zeny_ledger_customer_id_customers FOREIGN KEY (customer_id) REFERENCES public.customers(id);
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- VISTAS CONSOLIDADAS
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.my_zeny_cards AS
SELECT 
  id,
  customer_id,
  numero_tarjeta,
  nombre_titular,
  fecha_vencimiento,
  estado,
  descuento_porcentaje,
  activada_at,
  created_at,
  CASE
    WHEN is_admin() THEN codigo_activacion
    WHEN (estado = 'activa'::text) THEN codigo_activacion
    ELSE '***'::text
  END AS codigo_activacion
FROM public.zeny_cards;

CREATE OR REPLACE VIEW public.public_franchises AS
SELECT 
  id,
  subdominio,
  nombre_comercial,
  titular_nombre,
  titular_telefono,
  titular_correo,
  logo_url,
  color_primario,
  estado
FROM public.franchises;


-- ------------------------------------------------------------------------------
-- ÍNDICES DE RENDIMIENTO Y BÚSQUEDA
-- ------------------------------------------------------------------------------
CREATE UNIQUE INDEX customers_codigo_identificacion_key ON public.customers USING btree (codigo_identificacion);
CREATE INDEX idx_customers_codigo_id ON public.customers USING btree (codigo_identificacion);
CREATE INDEX idx_customers_franchise ON public.customers USING btree (franchise_id);
CREATE INDEX idx_customers_telegram_chat ON public.customers USING btree (telegram_chat_id);
CREATE INDEX idx_customers_vendedor ON public.customers USING btree (vendedor_id);
CREATE UNIQUE INDEX franchises_subdominio_key ON public.franchises USING btree (subdominio);
CREATE INDEX idx_franchises_estado ON public.franchises USING btree (estado);
CREATE INDEX idx_franchises_subdomain ON public.franchises USING btree (subdominio);
CREATE INDEX idx_incidents_customer ON public.incidents USING btree (customer_id);
CREATE INDEX idx_incidents_order ON public.incidents USING btree (order_id);
CREATE INDEX idx_installments_reseller ON public.installments USING btree (reseller_id, estado);
CREATE INDEX idx_invoices_customer ON public.invoices USING btree (customer_id);
CREATE UNIQUE INDEX invoices_order_id_key ON public.invoices USING btree (order_id);
CREATE INDEX idx_mesa_cambio_caja_fecha ON public.mesa_cambio_caja USING btree (created_at DESC);
CREATE INDEX idx_mesa_cambio_customer ON public.mesa_cambio_operaciones USING btree (customer_id);
CREATE INDEX idx_mesa_cambio_estado ON public.mesa_cambio_operaciones USING btree (estado);
CREATE UNIQUE INDEX mother_accounts_plataforma_correo_key ON public.mother_accounts USING btree (plataforma, correo);
CREATE INDEX idx_orders_customer ON public.orders USING btree (customer_id);
CREATE INDEX idx_orders_franchise ON public.orders USING btree (franchise_id);
CREATE INDEX idx_orders_metodo ON public.orders USING btree (metodo_id);
CREATE INDEX idx_orders_pendientes ON public.orders USING btree (created_at) WHERE (estado = 'pendiente'::text);
CREATE INDEX idx_orders_product ON public.orders USING btree (product_id);
CREATE INDEX idx_orders_vence ON public.orders USING btree (vence) WHERE (estado = 'entregado'::text);
CREATE INDEX idx_orders_vendedor ON public.orders USING btree (vendedor_id);
CREATE UNIQUE INDEX orders_profile_activo ON public.orders USING btree (profile_id) WHERE ((profile_id IS NOT NULL) AND (estado = ANY (ARRAY['pendiente'::text, 'pagado'::text, 'entregado'::text])));
CREATE INDEX idx_partner_commissions_estado ON public.partner_commissions USING btree (estado);
CREATE INDEX idx_partner_commissions_order ON public.partner_commissions USING btree (order_id);
CREATE INDEX idx_partner_commissions_vendedor ON public.partner_commissions USING btree (vendedor_id);
CREATE UNIQUE INDEX partner_commissions_order_id_key ON public.partner_commissions USING btree (order_id);
CREATE INDEX idx_payment_methods_franchise ON public.payment_methods USING btree (franchise_id);
CREATE INDEX idx_products_category ON public.products USING btree (category_id);
CREATE INDEX idx_profiles_assigned_cust ON public.profiles_inventory USING btree (assigned_customer_id);
CREATE INDEX idx_profiles_franchise ON public.profiles_inventory USING btree (franchise_id);
CREATE INDEX idx_profiles_mother ON public.profiles_inventory USING btree (mother_id);
CREATE INDEX idx_profiles_product_estado ON public.profiles_inventory USING btree (product_id, estado);
CREATE INDEX idx_profiles_vendedor ON public.profiles_inventory USING btree (vendedor_id);
CREATE INDEX idx_purchases_estado_pago ON public.purchases USING btree (estado_pago);
CREATE INDEX idx_purchases_fecha_limite ON public.purchases USING btree (fecha_limite_pago);
CREATE INDEX idx_purchases_mother ON public.purchases USING btree (mother_id);
CREATE UNIQUE INDEX push_subscriptions_endpoint_key ON public.push_subscriptions USING btree (endpoint);
CREATE INDEX idx_recargas_abonos_estado ON public.recargas_abonos USING btree (estado);
CREATE INDEX idx_recargas_abonos_punto ON public.recargas_abonos USING btree (punto_id);
CREATE INDEX idx_recargas_puntos_email ON public.recargas_puntos USING btree (email);
CREATE INDEX idx_recargas_puntos_estado ON public.recargas_puntos USING btree (estado);
CREATE INDEX idx_recargas_puntos_tel ON public.recargas_puntos USING btree (telefono);
CREATE UNIQUE INDEX recargas_puntos_email_key ON public.recargas_puntos USING btree (email);
CREATE INDEX idx_refunds_customer ON public.refunds USING btree (customer_id);
CREATE INDEX idx_refunds_order ON public.refunds USING btree (order_id);
CREATE INDEX idx_telegram_sessions_auth_token ON public.telegram_sessions USING btree (auth_token);
CREATE INDEX idx_telegram_sessions_customer ON public.telegram_sessions USING btree (customer_id);
CREATE INDEX idx_transfers_customer ON public.transfers USING btree (customer_id);
CREATE INDEX idx_transfers_from ON public.transfers USING btree (from_profile);
CREATE INDEX idx_transfers_order ON public.transfers USING btree (order_id);
CREATE INDEX idx_transfers_to ON public.transfers USING btree (to_profile);
CREATE INDEX idx_zeny_cards_customer ON public.zeny_cards USING btree (customer_id);
CREATE INDEX idx_zeny_cards_numero ON public.zeny_cards USING btree (numero_tarjeta);
CREATE UNIQUE INDEX zeny_cards_customer_id_key ON public.zeny_cards USING btree (customer_id);
CREATE UNIQUE INDEX zeny_cards_numero_tarjeta_key ON public.zeny_cards USING btree (numero_tarjeta);
CREATE INDEX idx_ledger_customer ON public.zeny_ledger USING btree (customer_id);
CREATE INDEX idx_ledger_order ON public.zeny_ledger USING btree (order_id);


-- [PASO 2]: Funciones y Procedimientos Almacenados (RPCs)
-- ==============================================================================
-- 02_FUNCIONES_Y_RPCS.SQL
-- Emprendimiento Gregory Izquierdo - Suite de Instalación PostgreSQL Independiente
-- 67 Funciones Maestras y Procedimientos Almacenados (RPCs) Consolidados
-- ==============================================================================

SET search_path = public, extensions;

-- Función: _close_order
CREATE OR REPLACE FUNCTION public._close_order(p_order uuid, p_estado text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  o public.orders;
begin
  select * into o from public.orders where id = p_order for update;
  if o.estado <> 'pendiente' then
    raise exception 'Solo se puede cerrar un pedido pendiente';
  end if;

  update public.orders set estado = p_estado where id = p_order;

  if o.profile_id is not null then
    update public.profiles_inventory
    set estado = 'disponible'
    where id = o.profile_id and estado = 'reservado';
  end if;

  -- Liberar retenciones de Zeny asociadas
  update public.zeny_ledger
  set estado = 'rechazado'
  where order_id = p_order and tipo = 'compra' and estado = 'pendiente';

  -- Anular cuotas pendientes si aplicaba financiamiento
  update public.installments
  set estado = 'cancelada'
  where order_id = p_order and estado in ('pendiente', 'en_revision');
end $function$;

-- Función: _deliver
CREATE OR REPLACE FUNCTION public._deliver(p_order uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  o public.orders;
  pr public.products;
  pf uuid;
  st text;
  v_cur_vence date;
  v_new_vence date;
  v_duracion int := 30;
  v_is_renewal boolean := false;
begin
  -- 1. Bloquear y validar orden
  select * into o from public.orders where id = p_order for update;
  if not found then
    raise exception 'Pedido no encontrado.';
  end if;

  if o.estado not in ('pendiente', 'pagado', 'vencido') then
    raise exception 'Estado de pedido inválido para entrega: %', o.estado;
  end if;

  -- 2. Obtener producto y duración
  select * into pr from public.products where id = o.product_id;
  v_duracion := coalesce(pr.duracion_dias, 30);

  if pr.tipo not in ('servicio', 'gaming', 'recarga_telefonica') then
    pf := o.profile_id;

    -- CASO A: El pedido ya trae un perfil asignado (es una renovación o perfil reservado)
    if pf is not null then
      select estado, vence into st, v_cur_vence
      from public.profiles_inventory
      where id = pf for update;

      if st is not null then
        v_is_renewal := true;

        -- Calcular nuevo vencimiento (+30 días desde la fecha actual si está activo, o desde hoy si expiró)
        if v_cur_vence is not null and v_cur_vence >= current_date then
          v_new_vence := v_cur_vence + v_duracion;
        else
          v_new_vence := current_date + v_duracion;
        end if;

        -- Actualizar el perfil existente
        update public.profiles_inventory
        set estado = 'vendido',
            vence = v_new_vence,
            assigned_customer_id = coalesce(assigned_customer_id, o.customer_id),
            vendedor_id = coalesce(vendedor_id, o.vendedor_id),
            no_renueva = false,
            no_renueva_reportado_at = null,
            no_renueva_motivo = null
        where id = pf;

        -- Marcar pedidos anteriores entregados de este mismo perfil como vencidos para evitar conflicto de índice único
        update public.orders
        set estado = 'vencido',
            no_renueva = false
        where profile_id = pf
          and id <> p_order
          and estado in ('entregado', 'pagado');
      else
        -- El perfil referenciado no existe en la base de datos
        pf := null;
      end if;
    end if;

    -- CASO B: Compra nueva desde catálogo sin perfil pre-asignado
    if pf is null then
      -- B1: Buscar stock propio de franquicia si aplica
      if o.franchise_id is not null then
        select pi.id into pf
        from public.profiles_inventory pi
        join public.mother_accounts m on m.id = pi.mother_id
        where pi.product_id = o.product_id
          and pi.estado = 'disponible'
          and pi.franchise_id = o.franchise_id
          and coalesce(m.activa, true) is true
          and (m.vence is null or m.vence >= current_date)
        order by pi.id limit 1 for update skip locked;
      end if;

      -- B2: Buscar stock central disponible
      if pf is null then
        select pi.id into pf
        from public.profiles_inventory pi
        join public.mother_accounts m on m.id = pi.mother_id
        where pi.product_id = o.product_id
          and pi.estado = 'disponible'
          and (pi.franchise_id is null or o.franchise_id is null)
          and coalesce(m.activa, true) is true
          and (m.vence is null or m.vence >= current_date)
        order by pi.id limit 1 for update skip locked;
      end if;

      if pf is null then
        raise exception 'Sin stock disponible para % (con cuenta madre activa)', coalesce(pr.nombre, 'Servicio');
      end if;

      v_new_vence := current_date + v_duracion;

      update public.profiles_inventory
      set estado = 'vendido',
          inicia = current_date,
          vence = v_new_vence,
          assigned_customer_id = coalesce(assigned_customer_id, o.customer_id),
          vendedor_id = coalesce(vendedor_id, o.vendedor_id),
          no_renueva = false,
          no_renueva_reportado_at = null,
          no_renueva_motivo = null
      where id = pf;
    end if;
  else
    -- Servicios sin perfiles físicos (gaming, saldo móvil)
    v_new_vence := current_date + v_duracion;
  end if;

  -- 3. Actualizar la orden a entregado con fechas sincronizadas
  update public.orders
  set estado = 'entregado',
      estado_recarga = 'recargado',
      profile_id = pf,
      inicia = coalesce(inicia, current_date),
      vence = coalesce(v_new_vence, vence, current_date + v_duracion),
      proximo_pago = coalesce(v_new_vence, proximo_pago, current_date + v_duracion),
      pagado_at = coalesce(pagado_at, now())
  where id = p_order;

  -- 4. Conciliar saldo Zeny retenido en compra
  update public.zeny_ledger
  set estado = 'aprobado'
  where order_id = p_order and tipo = 'compra' and estado = 'pendiente';

  -- 5. Si tenía cuota inicial en revisión, conciliarla
  update public.installments
  set estado = 'pagada',
      pagada_at = coalesce(pagada_at, now())
  where order_id = p_order and numero_cuota = 1 and estado = 'en_revision';

  -- 6. Emitir factura cuadrada
  insert into public.invoices(order_id, customer_id, total_usd, total_bs, tasa_bs, estado, franchise_id)
  select id, customer_id, total_usd, total_bs, tasa_bs, 'emitida', franchise_id
  from public.orders where id = p_order
  on conflict (order_id) do nothing;
end;
$function$;

-- Función: activate_zeny_card
CREATE OR REPLACE FUNCTION public.activate_zeny_card(p_numero text, p_codigo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  card zeny_cards;
begin
  if auth.uid() is null then
    raise exception 'Inicia sesión primero';
  end if;
  select * into card from zeny_cards where customer_id = auth.uid() for update;
  if not found then
    raise exception 'No tienes una tarjeta asignada';
  end if;
  if card.estado = 'activa' then
    raise exception 'Tu tarjeta ya se encuentra activa';
  end if;
  if replace(card.numero_tarjeta, ' ', '') <> replace(p_numero, ' ', '') or card.codigo_activacion <> trim(p_codigo) then
    raise exception 'Código de activación incorrecto. Solicita tu código al administrador por WhatsApp.';
  end if;
  update zeny_cards set estado = 'activa', activada_at = coalesce(activada_at, now()) where id = card.id;
end;
$function$;

-- Función: admin_assign_profile_reseller
CREATE OR REPLACE FUNCTION public.admin_assign_profile_reseller(p_profile_id uuid, p_reseller_id uuid, p_cliente_final text DEFAULT NULL::text, p_cliente_telefono text DEFAULT NULL::text, p_marcar_vendido boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_is_adm boolean := false;
  v_reseller_name text := null;
  v_reseller_code text := null;
  v_cur_estado text;
  v_clean_client text := nullif(trim(p_cliente_final), '');
  v_clean_tel text := nullif(trim(p_cliente_telefono), '');
begin
  -- Solo administradores pueden ejecutar esta función
  v_is_adm := is_admin();
  if not v_is_adm then
    raise exception 'Acceso denegado: solo el administrador puede asignar perfiles a revendedores.';
  end if;

  select estado into v_cur_estado from public.profiles_inventory where id = p_profile_id;
  if v_cur_estado is null then
    raise exception 'El perfil especificado no existe.';
  end if;

  if p_reseller_id is not null then
    -- Obtener datos del revendedor
    select nombre, codigo_identificacion
    into v_reseller_name, v_reseller_code
    from public.customers
    where id = p_reseller_id;

    if v_reseller_name is null then
      raise exception 'El revendedor seleccionado no existe o no tiene nombre registrado.';
    end if;

    -- Asignar perfil al revendedor
    update public.profiles_inventory
    set vendedor_id = p_reseller_id,
        vendedor = v_reseller_name,
        cliente_final = coalesce(v_clean_client, cliente_final),
        cliente_telefono = coalesce(v_clean_tel, cliente_telefono),
        estado = case when p_marcar_vendido and v_cur_estado = 'disponible' then 'vendido' else estado end,
        inicia = case when p_marcar_vendido and v_cur_estado = 'disponible' and inicia is null then current_date else inicia end,
        vence = case when p_marcar_vendido and v_cur_estado = 'disponible' and vence is null then (current_date + interval '30 days')::date else vence end
    where id = p_profile_id;

    -- Sincronizar órdenes asociadas
    update public.orders
    set vendedor_id = p_reseller_id,
        vendedor_nombre = v_reseller_name
    where profile_id = p_profile_id;

    return jsonb_build_object(
      'success', true,
      'profile_id', p_profile_id,
      'vendedor_id', p_reseller_id,
      'vendedor', v_reseller_name,
      'cliente_final', v_clean_client,
      'cliente_telefono', v_clean_tel,
      'message', format('Perfil asignado con éxito al revendedor %s', v_reseller_name)
    );
  else
    -- Desasignar: devolver a Tienda Central (Gregory / Venta Directa)
    update public.profiles_inventory
    set vendedor_id = null,
        vendedor = null,
        cliente_final = coalesce(v_clean_client, cliente_final),
        cliente_telefono = coalesce(v_clean_tel, cliente_telefono)
    where id = p_profile_id;

    update public.orders
    set vendedor_id = null,
        vendedor_nombre = null
    where profile_id = p_profile_id;

    return jsonb_build_object(
      'success', true,
      'profile_id', p_profile_id,
      'vendedor_id', null,
      'vendedor', null,
      'cliente_final', v_clean_client,
      'cliente_telefono', v_clean_tel,
      'message', 'Perfil transferido a Tienda Central (sin revendedor asignado)'
    );
  end if;
end;
$function$;

-- Función: admin_create_franchise
CREATE OR REPLACE FUNCTION public.admin_create_franchise(p_subdominio text, p_nombre_comercial text, p_titular_nombre text, p_titular_cedula_rif text DEFAULT ''::text, p_titular_telefono text DEFAULT ''::text, p_titular_correo text DEFAULT ''::text, p_titular_ciudad text DEFAULT ''::text, p_canon_mensual_usd numeric DEFAULT 25.00, p_notas_internas text DEFAULT ''::text, p_contrato_texto text DEFAULT ''::text, p_modalidad_inventario text DEFAULT 'hibrido'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_franchise record;
  v_clean_sub text;
BEGIN
  v_clean_sub := lower(regexp_replace(trim(p_subdominio), '[^a-z0-9-]', '', 'g'));
  
  IF length(v_clean_sub) < 2 THEN
    RETURN jsonb_build_object('error', 'El subdominio debe tener al menos 2 caracteres alfanuméricos.');
  END IF;

  IF exists(SELECT 1 FROM public.franchises WHERE lower(subdominio) = v_clean_sub) THEN
    RETURN jsonb_build_object('error', 'El subdominio "' || v_clean_sub || '" ya está en uso. Por favor elige otro.');
  END IF;

  INSERT INTO public.franchises (
    subdominio,
    nombre_comercial,
    titular_nombre,
    titular_cedula_rif,
    titular_telefono,
    titular_correo,
    titular_ciudad,
    canon_mensual_usd,
    notas_internas,
    contrato_texto,
    estado,
    saldo_billetera_usd,
    nivel_volumen,
    compras_mes_usd,
    kyc_estado,
    contrato_aceptado,
    contrato_aceptado_at
  ) VALUES (
    v_clean_sub,
    trim(p_nombre_comercial),
    trim(p_titular_nombre),
    trim(coalesce(p_titular_cedula_rif, '')),
    trim(coalesce(p_titular_telefono, '')),
    trim(coalesce(p_titular_correo, '')),
    trim(coalesce(p_titular_ciudad, '')),
    coalesce(p_canon_mensual_usd, 25.00),
    trim(coalesce(p_notas_internas, '')),
    p_contrato_texto,
    'activo',
    0.00,
    'bronce',
    0.00,
    'verificado',
    true,
    now()
  )
  RETURNING * INTO v_franchise;

  RETURN jsonb_build_object(
    'success', true,
    'franchise', to_jsonb(v_franchise)
  );
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('error', 'El subdominio ya está registrado.');
WHEN OTHERS THEN
  RETURN jsonb_build_object('error', SQLERRM);
END;
$function$;

-- Función: admin_delete_order
CREATE OR REPLACE FUNCTION public.admin_delete_order(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_profile_id uuid;
  v_order_estado text;
begin
  if not is_admin() then
    raise exception 'Solo administradores pueden eliminar pedidos.';
  end if;

  select profile_id, estado into v_profile_id, v_order_estado
  from public.orders where id = p_order_id for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Pedido no encontrado');
  end if;

  -- Si el pedido retenía un perfil reservado o pendiente y se elimina, liberar el perfil
  if v_profile_id is not null then
    if not exists (
      select 1 from public.orders
      where profile_id = v_profile_id and id <> p_order_id and estado in ('entregado', 'pagado')
    ) then
      update public.profiles_inventory
      set estado = 'disponible',
          assigned_customer_id = null
      where id = v_profile_id and estado in ('reservado', 'pendiente');
    end if;
  end if;

  -- Limpiar dependencias asociadas a este pedido
  delete from public.installments where order_id = p_order_id;
  delete from public.invoices where order_id = p_order_id;
  delete from public.refunds where order_id = p_order_id;
  delete from public.transfers where order_id = p_order_id;
  update public.incidents set order_id = null where order_id = p_order_id;
  update public.zeny_ledger set order_id = null where order_id = p_order_id;

  -- Eliminar la orden
  delete from public.orders where id = p_order_id;

  return jsonb_build_object('success', true, 'order_id', p_order_id);
end $function$;

-- Función: admin_deliver_profile_cash
CREATE OR REPLACE FUNCTION public.admin_deliver_profile_cash(p_profile_id uuid, p_customer_id uuid, p_monto_usd numeric DEFAULT NULL::numeric, p_metodo_id uuid DEFAULT NULL::uuid, p_referencia text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_prof profiles_inventory%rowtype;
  v_cust customers%rowtype;
  v_prod products%rowtype;
  v_mother mother_accounts%rowtype;
  v_rate numeric := 1;
  v_precio numeric := 0;
  v_f_vence date;
  v_order_id uuid;
  v_srv_name text;
  v_clv_plain text;
  v_pin_plain text;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Solo el Administrador puede realizar entregas directas.';
  END IF;

  PERFORM set_config('app.internal', '1', true);

  SELECT * INTO v_prof FROM profiles_inventory WHERE id = p_profile_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Perfil no encontrado.'; END IF;

  SELECT * INTO v_cust FROM customers WHERE id = p_customer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Cliente no encontrado.'; END IF;

  SELECT * INTO v_prod FROM products WHERE id = v_prof.product_id;
  SELECT * INTO v_mother FROM mother_accounts WHERE id = v_prof.mother_id;
  v_srv_name := coalesce(v_prod.nombre, v_mother.plataforma, 'Servicio Digital');

  IF p_monto_usd IS NOT NULL AND p_monto_usd > 0 THEN
    v_precio := p_monto_usd;
  ELSIF coalesce(v_cust.es_revendedor, false) AND v_prod.precio_revendedor_usd IS NOT NULL AND v_prod.precio_revendedor_usd > 0 THEN
    v_precio := v_prod.precio_revendedor_usd;
  ELSE
    v_precio := coalesce(v_prod.precio_usd, 5.00);
  END IF;

  SELECT bs_por_usd INTO v_rate FROM exchange_rates ORDER BY fecha DESC LIMIT 1;
  v_rate := coalesce(v_rate, 1);

  v_f_vence := (current_date + coalesce(v_prod.duracion_dias, 30))::date;

  UPDATE profiles_inventory SET
    estado = 'vendido',
    inicia = current_date,
    vence = v_f_vence,
    assigned_customer_id = p_customer_id,
    cliente_final = coalesce(nullif(trim(v_cust.nombre), ''), v_cust.email, 'Cliente'),
    vendedor_id = CASE WHEN coalesce(v_cust.es_revendedor, false) THEN p_customer_id ELSE null END,
    vendedor = CASE WHEN coalesce(v_cust.es_revendedor, false) THEN coalesce(v_cust.nombre, 'Revendedor') ELSE null END,
    no_renueva = false,
    no_renueva_reportado_at = null,
    no_renueva_motivo = null
  WHERE id = p_profile_id;

  UPDATE orders SET estado = 'vencido', no_renueva = false
  WHERE profile_id = p_profile_id AND estado IN ('entregado', 'pagado');

  INSERT INTO orders (
    customer_id, vendedor_id, profile_id, product_id, metodo_id,
    total_usd, tasa_bs, total_bs, estado,
    referencia, inicia, vence, proximo_pago, pagado_at
  ) VALUES (
    p_customer_id,
    CASE WHEN coalesce(v_cust.es_revendedor, false) THEN p_customer_id ELSE null END,
    p_profile_id,
    v_prof.product_id,
    p_metodo_id,
    v_precio,
    v_rate,
    round(v_precio * v_rate, 2),
    'entregado',
    coalesce(p_referencia, '[VENTA DIRECTA ADMIN] ' || coalesce(v_cust.nombre, 'Cliente') || ' - ' || v_srv_name || ' ($' || v_precio || ' USD)'),
    current_date,
    v_f_vence,
    v_f_vence,
    now()
  ) RETURNING id INTO v_order_id;

  INSERT INTO invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
  VALUES (v_order_id, p_customer_id, v_precio, round(v_precio * v_rate, 2), v_rate, 'emitida')
  ON CONFLICT (order_id) DO NOTHING;

  v_clv_plain := CASE WHEN v_mother.clave LIKE 'enc:%' THEN dec_text(v_mother.clave) ELSE v_mother.clave END;
  v_pin_plain := CASE WHEN v_prof.pin LIKE 'enc:%' THEN dec_text(v_prof.pin) ELSE v_prof.pin END;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'servicio', v_srv_name,
    'perfil', coalesce(v_prof.nombre_perfil, 'Perfil 1'),
    'correo', v_mother.correo,
    'clave', v_clv_plain,
    'pin', coalesce(v_pin_plain, 'Sin PIN'),
    'cliente_nombre', coalesce(v_cust.nombre, 'Cliente'),
    'cliente_telefono', coalesce(v_cust.telefono, ''),
    'monto_usd', v_precio,
    'monto_bs', round(v_precio * v_rate, 2),
    'vence_servicio', v_f_vence
  );
END;
$function$;

-- Función: admin_deliver_profile_credit
CREATE OR REPLACE FUNCTION public.admin_deliver_profile_credit(p_profile_id uuid, p_customer_id uuid, p_dias integer DEFAULT 7, p_monto_usd numeric DEFAULT NULL::numeric, p_notas text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_prof profiles_inventory%rowtype;
  v_cust customers%rowtype;
  v_prod products%rowtype;
  v_mother mother_accounts%rowtype;
  v_rate numeric := 1;
  v_precio numeric := 0;
  v_dias int := coalesce(p_dias, 7);
  v_f_vence date;
  v_f_credito date;
  v_order_id uuid;
  v_srv_name text;
  v_cred_usado numeric := 0;
  v_clv_plain text;
  v_pin_plain text;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Solo el Administrador puede realizar entregas directas a crédito.';
  END IF;

  PERFORM set_config('app.internal', '1', true);

  -- 1. Obtener perfil
  SELECT * INTO v_prof FROM profiles_inventory WHERE id = p_profile_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Perfil no encontrado en inventario.';
  END IF;

  -- 2. Obtener cliente
  SELECT * INTO v_cust FROM customers WHERE id = p_customer_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cliente no encontrado.';
  END IF;

  -- 3. Obtener producto y cuenta madre
  SELECT * INTO v_prod FROM products WHERE id = v_prof.product_id;
  SELECT * INTO v_mother FROM mother_accounts WHERE id = v_prof.mother_id;
  v_srv_name := coalesce(v_prod.nombre, v_mother.plataforma, 'Servicio Digital');

  -- 4. Determinar precio en USD
  IF p_monto_usd IS NOT NULL AND p_monto_usd > 0 THEN
    v_precio := p_monto_usd;
  ELSIF coalesce(v_cust.es_revendedor, false) AND v_prod.precio_revendedor_usd IS NOT NULL AND v_prod.precio_revendedor_usd > 0 THEN
    v_precio := v_prod.precio_revendedor_usd;
  ELSE
    v_precio := coalesce(v_prod.precio_usd, 5.00);
  END IF;

  -- 5. Tasa BCV
  SELECT bs_por_usd INTO v_rate FROM exchange_rates ORDER BY fecha DESC LIMIT 1;
  v_rate := coalesce(v_rate, 1);

  -- 6. Fechas: vencimiento de la cuenta y límite del crédito
  v_f_vence := (current_date + coalesce(v_prod.duracion_dias, 30))::date;
  v_f_credito := (current_date + make_interval(days => v_dias))::date;

  -- 7. Actualizar cupo si es necesario
  SELECT coalesce(sum(monto_usd), 0) INTO v_cred_usado
  FROM installments
  WHERE (customer_id = p_customer_id OR reseller_id = p_customer_id)
    AND estado IN ('pendiente', 'en_revision');

  IF (v_cred_usado + v_precio) > coalesce(v_cust.limite_credito, 0) THEN
    UPDATE customers SET limite_credito = (v_cred_usado + v_precio) WHERE id = p_customer_id;
  END IF;

  -- 8. Actualizar perfil en profiles_inventory
  UPDATE profiles_inventory SET
    estado = 'vendido',
    inicia = current_date,
    vence = v_f_vence,
    assigned_customer_id = p_customer_id,
    cliente_final = coalesce(nullif(trim(v_cust.nombre), ''), v_cust.email, 'Cliente'),
    vendedor_id = CASE WHEN coalesce(v_cust.es_revendedor, false) THEN p_customer_id ELSE null END,
    vendedor = CASE WHEN coalesce(v_cust.es_revendedor, false) THEN coalesce(v_cust.nombre, 'Revendedor') ELSE null END,
    no_renueva = false,
    no_renueva_reportado_at = null,
    no_renueva_motivo = null
  WHERE id = p_profile_id;

  -- 9. Cerrar órdenes activas anteriores de este perfil
  UPDATE orders SET estado = 'vencido', no_renueva = false
  WHERE profile_id = p_profile_id AND estado IN ('entregado', 'pagado');

  -- 10. Crear orden entregada a crédito
  INSERT INTO orders (
    customer_id, vendedor_id, profile_id, product_id,
    total_usd, tasa_bs, total_bs, estado,
    referencia, inicia, vence, proximo_pago, pagado_at
  ) VALUES (
    p_customer_id,
    CASE WHEN coalesce(v_cust.es_revendedor, false) THEN p_customer_id ELSE null END,
    p_profile_id,
    v_prof.product_id,
    v_precio,
    v_rate,
    round(v_precio * v_rate, 2),
    'entregado',
    '[CRÉDITO ADMIN] ' || coalesce(v_cust.nombre, 'Cliente') || ' - ' || v_srv_name || ' ($' || v_precio || ' USD a ' || v_dias || 'd)',
    current_date,
    v_f_credito,
    v_f_credito,
    now()
  ) RETURNING id INTO v_order_id;

  -- 11. Factura
  INSERT INTO invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
  VALUES (v_order_id, p_customer_id, v_precio, round(v_precio * v_rate, 2), v_rate, 'emitida')
  ON CONFLICT (order_id) DO NOTHING;

  -- 12. Insertar deuda en installments (Cobranza / Línea de Crédito)
  INSERT INTO installments (
    order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
    monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
  ) VALUES (
    v_order_id,
    p_customer_id,
    CASE WHEN coalesce(v_cust.es_revendedor, false) THEN p_customer_id ELSE null END,
    1, 1,
    v_precio,
    round(v_precio * v_rate, 2),
    v_rate,
    v_f_credito,
    'pendiente',
    '[CRÉDITO ADMIN] ' || v_srv_name || ' (' || coalesce(v_prof.nombre_perfil, 'P1') || ') - ' || coalesce(v_cust.nombre, 'Cliente')
  );

  -- Desencriptar credenciales para retorno inmediato
  v_clv_plain := CASE WHEN v_mother.clave LIKE 'enc:%' THEN dec_text(v_mother.clave) ELSE v_mother.clave END;
  v_pin_plain := CASE WHEN v_prof.pin LIKE 'enc:%' THEN dec_text(v_prof.pin) ELSE v_prof.pin END;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'servicio', v_srv_name,
    'perfil', coalesce(v_prof.nombre_perfil, 'Perfil 1'),
    'correo', v_mother.correo,
    'clave', v_clv_plain,
    'pin', coalesce(v_pin_plain, 'Sin PIN'),
    'cliente_nombre', coalesce(v_cust.nombre, 'Cliente'),
    'cliente_telefono', coalesce(v_cust.telefono, ''),
    'monto_usd', v_precio,
    'monto_bs', round(v_precio * v_rate, 2),
    'fecha_limite_pago', v_f_credito,
    'vence_servicio', v_f_vence,
    'dias_credito', v_dias
  );
END;
$function$;

-- Función: apply_ledger
CREATE OR REPLACE FUNCTION public.apply_ledger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin if new.estado = 'aprobado' and (tg_op = 'INSERT' or old.estado <> 'aprobado') then
  update customers set zeny_balance = zeny_balance + new.monto where id = new.customer_id; end if; return new; end $function$;

-- Función: approve_installment
CREATE OR REPLACE FUNCTION public.approve_installment(p_installment_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_inst public.installments;
  v_pending_count int := 0;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;

  select * into v_inst from public.installments where id = p_installment_id for update;
  if not found then raise exception 'Cuota no encontrada'; end if;

  update public.installments
  set estado = 'pagada',
      pagada_at = coalesce(pagada_at, now())
  where id = p_installment_id;

  -- Si todas las cuotas de la orden asociada fueron liquidadas, actualizar pagado_at
  if v_inst.order_id is not null then
    select count(*) into v_pending_count
    from public.installments
    where order_id = v_inst.order_id
      and estado in ('pendiente', 'en_revision', 'vencida');

    if v_pending_count = 0 then
      update public.orders
      set pagado_at = coalesce(pagado_at, now())
      where id = v_inst.order_id;
    end if;
  end if;
end $function$;

-- Función: asignar_cliente_a_vendedor
CREATE OR REPLACE FUNCTION public.asignar_cliente_a_vendedor(p_cliente_id uuid, p_vendedor_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_vendedor_nom text := null;
begin
  if not is_admin() then
    raise exception 'No autorizado: se requieren permisos de administrador';
  end if;

  if p_vendedor_id is not null then
    select nombre into v_vendedor_nom from customers where id = p_vendedor_id and es_revendedor;
    if v_vendedor_nom is null then
      raise exception 'El vendedor especificado no existe o no tiene rol de revendedor';
    end if;
  end if;

  update customers
  set vendedor_id = p_vendedor_id,
      vendedor_nombre = v_vendedor_nom
  where id = p_cliente_id;

  -- Actualizar pedidos del cliente
  update orders
  set vendedor_id = p_vendedor_id
  where customer_id = p_cliente_id;

  -- Actualizar inventario de perfiles asignados a este cliente
  update profiles_inventory
  set vendedor_id = p_vendedor_id,
      vendedor = v_vendedor_nom,
      assigned_customer_id = p_cliente_id
  where assigned_customer_id = p_cliente_id
     or id in (select profile_id from orders where customer_id = p_cliente_id and profile_id is not null);

  return jsonb_build_object(
    'success', true,
    'cliente_id', p_cliente_id,
    'vendedor_id', p_vendedor_id,
    'vendedor_nombre', v_vendedor_nom
  );
end;
$function$;

-- Función: bot_get_customer_credentials
CREATE OR REPLACE FUNCTION public.bot_get_customer_credentials(p_customer_id uuid)
 RETURNS TABLE(order_id uuid, servicio text, tipo text, datos_recarga jsonb, correo text, clave text, perfil text, pin text, inicia date, vence date, dias_restantes integer, estado text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

-- Función: bot_get_customer_debt_summary
CREATE OR REPLACE FUNCTION public.bot_get_customer_debt_summary(p_customer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

-- Función: cancel_my_order
CREATE OR REPLACE FUNCTION public.cancel_my_order(p_order uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists(select 1 from orders where id = p_order and customer_id = auth.uid()) then raise exception 'Pedido no encontrado'; end if;
  perform _close_order(p_order, 'cancelado'); end $function$;

-- Función: check_overdue_installments
CREATE OR REPLACE FUNCTION public.check_overdue_installments()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_count int := 0;
begin
  update installments
  set estado = 'vencida'
  where estado = 'pendiente'
    and fecha_vencimiento < current_date;
  get diagnostics v_count = row_count;
  return jsonb_build_object('success', true, 'cuotas_vencidas', v_count);
end;
$function$;

-- Función: create_order
CREATE OR REPLACE FUNCTION public.create_order(p_product uuid, p_metodo uuid DEFAULT NULL::uuid, p_ref text DEFAULT NULL::text, p_zeny numeric DEFAULT 0, p_datos_recarga jsonb DEFAULT '{}'::jsonb, p_es_cuotas boolean DEFAULT false, p_franchise_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  pr public.products;
  pf uuid;
  o uuid;
  rate numeric;
  bal numeric;
  holds numeric;
  z numeric := coalesce(p_zeny, 0);
  pm public.payment_methods;
  eff_price numeric;
  is_res boolean := false;
  is_demo_user boolean := false;
  v_card_desc numeric := 0;
  v_limite numeric := 30.00;
  v_credito_usado numeric := 0;
  v_cuota_1 numeric;
  v_cuota_2 numeric;
  v_order_total numeric;
  v_fran_estado text;
begin
  if auth.uid() is null then
    raise exception 'Inicia sesión primero';
  end if;

  -- 0. PROTECCIÓN MODO DEMOSTRACIÓN:
  select coalesce(es_demo, false) into is_demo_user from public.customers where id = auth.uid();
  if is_demo_user then
    raise exception '🔒 MODO DEMOSTRACIÓN: Has llegado al paso final de la compra. En una cuenta regular el servicio se entregaría de inmediato. Las órdenes reales están desactivadas para cuentas de prueba.';
  end if;

  perform release_expired();

  -- Validación de Franquicia y Kill-Switch
  if p_franchise_id is not null then
    select estado into v_fran_estado from public.franchises where id = p_franchise_id;
    if not found then
      raise exception 'Franquicia no encontrada';
    end if;
    if v_fran_estado in ('suspendido_fraude', 'suspendido_mora') then
      raise exception 'Portal de franquicia suspendido temporalmente por la administración Central';
    end if;
  end if;

  select * into pr from public.products where id = p_product and activo;
  if not found then
    raise exception 'Producto no disponible o inactivo';
  end if;

  if p_franchise_id is not null and (pr.es_exclusivo_central or pr.tipo in ('gaming', 'recarga_telefonica')) then
    raise exception 'Este producto es exclusivo de la tienda central';
  end if;

  select coalesce(es_revendedor, false), coalesce(limite_credito, 30.00)
    into is_res, v_limite
  from public.customers where id = auth.uid();

  if p_metodo is not null then
    select * into pm from public.payment_methods where id = p_metodo;
  end if;

  -- 1. Determinar precio base (Revendedor prevalece sobre Binance)
  if is_res and not coalesce(pr.es_exclusivo_central, false) and pr.precio_revendedor_usd is not null and pr.precio_revendedor_usd > 0 then
    eff_price := pr.precio_revendedor_usd;
  elsif (pm.tipo = 'binance' or lower(coalesce(pm.nombre,'')) like '%binance%') and pr.precio_binance_usd is not null and pr.precio_binance_usd > 0 then
    eff_price := pr.precio_binance_usd;
  else
    eff_price := pr.precio_usd;
  end if;

  -- 2. Descuento oficial de Tarjeta Zeny
  select descuento_porcentaje into v_card_desc
  from public.zeny_cards
  where customer_id = auth.uid() and estado = 'activa'
  limit 1;

  if v_card_desc is not null and v_card_desc > 0 then
    eff_price := round(eff_price * (1.0 - (v_card_desc / 100.0)), 2);
  end if;

  -- 3. Financiamiento en Cuotas (BNPL)
  if p_es_cuotas then
    if not pr.permite_cuotas then
      raise exception 'Este servicio no permite financiamiento en cuotas';
    end if;

    if exists (
      select 1 from public.installments
      where customer_id = auth.uid()
        and (estado = 'vencida' or (estado = 'pendiente' and fecha_vencimiento < current_date))
    ) then
      raise exception 'Tienes cuotas vencidas pendientes. Debes ponerte al día para solicitar un nuevo financiamiento.';
    end if;

    select coalesce(sum(monto_usd), 0) into v_credito_usado
    from public.installments
    where customer_id = auth.uid() and estado in ('pendiente', 'en_revision');

    v_cuota_1 := round(eff_price * 0.50, 2);
    v_cuota_2 := eff_price - v_cuota_1;

    if (v_credito_usado + v_cuota_2) > v_limite then
      raise exception 'El monto a financiar ($%) excede tu límite de crédito disponible ($%)',
        v_cuota_2, greatest(0, v_limite - v_credito_usado);
    end if;

    v_order_total := v_cuota_1;
  else
    v_order_total := eff_price;
  end if;

  -- 4. Validar saldo Zeny aplicado
  if z < 0 or z > v_order_total then
    raise exception 'Monto Zeny inválido';
  end if;

  if z < v_order_total and p_metodo is null then
    raise exception 'Elige un método de pago para el monto restante';
  end if;

  if z > 0 then
    select zeny_balance into bal from public.customers where id = auth.uid() for update;
    select coalesce(sum(-monto), 0) into holds
    from public.zeny_ledger
    where customer_id = auth.uid() and tipo = 'compra' and estado = 'pendiente';

    if z > coalesce(bal, 0) - holds then
      raise exception 'Saldo Zeny insuficiente';
    end if;
  end if;

  -- 5. Asignar perfil con cuenta madre activa y no vencida
  if pr.tipo not in ('servicio', 'gaming', 'recarga_telefonica') then
    if p_franchise_id is not null then
      select pi.id into pf
      from public.profiles_inventory pi
      join public.mother_accounts m on m.id = pi.mother_id
      where pi.product_id = p_product
        and pi.estado = 'disponible'
        and pi.franchise_id = p_franchise_id
        and coalesce(m.activa, true) is true
        and (m.vence is null or m.vence >= current_date)
      order by pi.id limit 1 for update skip locked;
    end if;

    if pf is null then
      select pi.id into pf
      from public.profiles_inventory pi
      join public.mother_accounts m on m.id = pi.mother_id
      where pi.product_id = p_product
        and pi.estado = 'disponible'
        and (pi.franchise_id is null or p_franchise_id is null)
        and coalesce(m.activa, true) is true
        and (m.vence is null or m.vence >= current_date)
      order by pi.id limit 1 for update skip locked;
    end if;

    if pf is null then
      raise exception 'Agotado (sin inventario disponible con cuenta madre activa)';
    end if;

    update public.profiles_inventory set estado = 'reservado' where id = pf;
  end if;

  select bs_por_usd into rate from public.exchange_rates order by fecha desc limit 1;
  perform set_config('app.internal', '1', true);

  -- 6. Insertar el Pedido
  insert into public.orders(
    customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs,
    metodo_id, referencia, estado, zeny_aplicado, datos_recarga, franchise_id
  )
  values (
    auth.uid(), p_product, pf, v_order_total, rate, round(v_order_total * coalesce(rate, 0), 2),
    p_metodo, left(coalesce(p_ref,''), 120), 'pendiente', z, coalesce(p_datos_recarga, '{}'::jsonb), p_franchise_id
  )
  returning id into o;

  -- 7. Retención Zeny si aplica
  if z > 0 then
    insert into public.zeny_ledger(customer_id, tipo, monto, referencia, estado, order_id)
    values (auth.uid(), 'compra', -z, 'Retención pedido ' || left(o::text, 8), 'pendiente', o);
  end if;

  -- 8. Si es compra financiada, generar las cuotas
  if p_es_cuotas then
    insert into public.installments(
      order_id, customer_id, numero_cuota, total_cuotas, monto_usd, tasa_bs, monto_bs,
      fecha_vencimiento, estado, metodo_id, referencia
    ) values (
      o, auth.uid(), 1, 2, v_cuota_1, rate, round(v_cuota_1 * coalesce(rate, 0), 2), current_date,
      case when z >= v_cuota_1 then 'pagada' else 'en_revision' end,
      p_metodo, left(coalesce(p_ref,''), 120)
    );

    insert into public.installments(
      order_id, customer_id, numero_cuota, total_cuotas, monto_usd, tasa_bs, monto_bs,
      fecha_vencimiento, estado
    ) values (
      o, auth.uid(), 2, 2, v_cuota_2, rate, round(v_cuota_2 * coalesce(rate, 0), 2),
      (current_date + interval '15 days')::date, 'pendiente'
    );
  end if;

  return o;
end $function$;

-- Función: customers_guard
CREATE OR REPLACE FUNCTION public.customers_guard()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if current_user in ('authenticated','anon') and not is_admin() then
    new.id := old.id; new.zeny_balance := old.zeny_balance; new.limite_credito := old.limite_credito; new.nivel_credito := old.nivel_credito;
    new.es_revendedor := old.es_revendedor; new.codigo_identificacion := old.codigo_identificacion; new.gcontact_id := old.gcontact_id;
    new.email := old.email; new.creado := old.creado;
  end if;
  return new;
end $function$;

-- Función: dec_text
CREATE OR REPLACE FUNCTION public.dec_text(t text)
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  select pgp_sym_decrypt(decode(substr(t,5),'base64'), (select value from secrets where name='enc_key')) $function$;

-- Función: delete_my_push_subscription
CREATE OR REPLACE FUNCTION public.delete_my_push_subscription(p_endpoint text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  delete from public.push_subscriptions
  where endpoint = p_endpoint
    and (user_id = auth.uid() or is_admin() or user_id is null);
  return jsonb_build_object('success', true);
end;
$function$;

-- Función: deliver_order
CREATE OR REPLACE FUNCTION public.deliver_order(p_order uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin if not is_admin() then raise exception 'No autorizado'; end if; perform _deliver(p_order); end $function$;

-- Función: deliver_order_credit
CREATE OR REPLACE FUNCTION public.deliver_order_credit(p_order uuid, p_dias integer DEFAULT 7, p_reseller_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  o public.orders;
  c public.customers;
  v_dias int := coalesce(p_dias, 7);
  f_vence date;
  v_rate numeric;
  v_credito_usado numeric := 0;
  v_limite numeric := 30.00;
  v_seller_id uuid;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;

  select * into o from public.orders where id = p_order for update;
  if not found then raise exception 'Pedido no encontrado'; end if;
  if o.estado not in ('pendiente', 'pagado', 'vencido') then
    raise exception 'El pedido no puede ser entregado a crédito (estado actual: %)', o.estado;
  end if;

  v_seller_id := coalesce(p_reseller_id, o.customer_id);

  select * into c from public.customers where id = v_seller_id;
  if not found then raise exception 'Cliente o Revendedor no encontrado'; end if;

  v_limite := coalesce(c.limite_credito, 30.00);

  select coalesce(sum(monto_usd), 0) into v_credito_usado
  from public.installments
  where (customer_id = v_seller_id or reseller_id = v_seller_id)
    and estado in ('pendiente', 'en_revision', 'vencida');

  -- Si el crédito excede el límite del usuario, el Admin lo aprueba ampliando el cupo automáticamente
  if (v_credito_usado + o.total_usd) > v_limite then
    update public.customers set limite_credito = (v_credito_usado + o.total_usd) where id = v_seller_id;
  end if;

  -- Entregar credenciales y fijar estado
  perform public._deliver(p_order);

  f_vence := (current_date + make_interval(days => v_dias))::date;
  select bs_por_usd into v_rate from public.exchange_rates order by fecha desc limit 1;

  -- Actualizar orden para indicar crédito y fecha límite de pago
  update public.orders
  set vence = f_vence,
      proximo_pago = f_vence,
      referencia = '[CRÉDITO] Vence ' || f_vence::text || ' ($' || o.total_usd::text || ' USD)'
  where id = p_order;

  -- Insertar la cuenta por cobrar en installments para restar cupo inmediatamente
  insert into public.installments(
    order_id,
    customer_id,
    reseller_id,
    numero_cuota,
    total_cuotas,
    monto_usd,
    tasa_bs,
    monto_bs,
    fecha_vencimiento,
    estado,
    referencia
  ) values (
    p_order,
    o.customer_id,
    v_seller_id,
    1,
    1,
    o.total_usd,
    coalesce(o.tasa_bs, v_rate, 1),
    round(o.total_usd * coalesce(o.tasa_bs, v_rate, 1), 2),
    f_vence,
    'pendiente',
    '[CRÉDITO REVENDEDOR] Plazo ' || v_dias::text || 'd - Pedido ' || left(p_order::text, 8)
  );
end $function$;

-- Función: enc_mother
CREATE OR REPLACE FUNCTION public.enc_mother()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin if new.clave is not null and new.clave <> '' and new.clave not like 'enc:%' then new.clave := enc_text(new.clave); end if; return new; end $function$;

-- Función: enc_profile
CREATE OR REPLACE FUNCTION public.enc_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin if new.pin is not null and new.pin <> '' and new.pin not like 'enc:%' then new.pin := enc_text(new.pin); end if; return new; end $function$;

-- Función: enc_text
CREATE OR REPLACE FUNCTION public.enc_text(t text)
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  select 'enc:' || encode(pgp_sym_encrypt(t, (select value from secrets where name='enc_key')), 'base64') $function$;

-- Función: ensure_customer_zeny_card
CREATE OR REPLACE FUNCTION public.ensure_customer_zeny_card()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  return new;
end;
$function$;

-- Función: finanzas
CREATE OR REPLACE FUNCTION public.finanzas(p_meses integer DEFAULT 12)
 RETURNS TABLE(mes date, ventas numeric, devoluciones numeric, gastos numeric, compras numeric, ganancia numeric, cuotas_cobradas numeric, cuotas_por_cobrar numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
begin
  if not is_admin() then raise exception 'No autorizado'; end if;

  return query
  with m as (
    select generate_series(
      date_trunc('month', current_date) - make_interval(months => p_meses - 1),
      date_trunc('month', current_date),
      interval '1 month'
    )::date as mes
  ),
  -- Ventas de contado (órdenes pagadas que NO están divididas en cuotas)
  v as (
    select date_trunc('month', coalesce(o.pagado_at, o.created_at))::date as mes,
           coalesce(sum(o.total_usd), 0) as t
    from public.orders o
    where o.estado in ('pagado', 'entregado')
      and o.pagado_at is not null
      and not exists (select 1 from public.installments i where i.order_id = o.id)
    group by 1
  ),
  -- Cuotas y créditos efectivamente cobrados y conciliados
  inst_pagadas as (
    select date_trunc('month', coalesce(i.pagada_at, i.created_at))::date as mes,
           coalesce(sum(i.monto_usd), 0) as t
    from public.installments i
    where i.estado = 'pagada'
    group by 1
  ),
  -- Cuotas y créditos pendientes de cobro (calle)
  inst_pend as (
    select date_trunc('month', coalesce(i.fecha_vencimiento, current_date))::date as mes,
           coalesce(sum(i.monto_usd), 0) as t
    from public.installments i
    where i.estado in ('pendiente', 'en_revision', 'vencida')
    group by 1
  ),
  d as (
    select date_trunc('month', created_at)::date as mes,
           coalesce(sum(monto_usd), 0) as t
    from public.refunds
    group by 1
  ),
  g as (
    select date_trunc('month', fecha)::date as mes,
           coalesce(sum(monto_usd), 0) as t
    from public.expenses
    group by 1
  ),
  -- Compras de cuentas madre pagadas o de contado
  c as (
    select date_trunc('month', fecha)::date as mes,
           coalesce(sum(monto_usd), 0) as t
    from public.purchases
    where coalesce(estado_pago, 'pagado') = 'pagado' or es_credito is false
    group by 1
  ),
  -- Operaciones completadas de la Mesa de Cambio USDT
  mc as (
    select date_trunc('month', created_at)::date as mes,
           coalesce(sum(round(monto_usdt * 0.02, 2)), 0) as t
    from public.mesa_cambio_operaciones
    where estado = 'completado_enviado'
    group by 1
  )
  select
    m.mes,
    round(coalesce(v.t, 0) + coalesce(ip.t, 0), 2) as ventas,
    round(coalesce(d.t, 0), 2) as devoluciones,
    round(coalesce(g.t, 0), 2) as gastos,
    round(coalesce(c.t, 0), 2) as compras,
    round((coalesce(v.t, 0) + coalesce(ip.t, 0) + coalesce(mc.t, 0)) - coalesce(d.t, 0) - coalesce(g.t, 0) - coalesce(c.t, 0), 2) as ganancia,
    round(coalesce(ip.t, 0), 2) as cuotas_cobradas,
    round(coalesce(inpend.t, 0), 2) as cuotas_por_cobrar
  from m
  left join v on v.mes = m.mes
  left join inst_pagadas ip on ip.mes = m.mes
  left join inst_pend inpend on inpend.mes = m.mes
  left join d on d.mes = m.mes
  left join g on g.mes = m.mes
  left join c on c.mes = m.mes
  left join mc on mc.mes = m.mes
  order by m.mes desc;
end $function$;

-- Función: generate_profiles
CREATE OR REPLACE FUNCTION public.generate_profiles(p_mother uuid, p_product uuid, p_cantidad integer, p_prefijo text DEFAULT 'Perfil'::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m mother_accounts; ya int; i int;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select * into m from mother_accounts where id = p_mother; if not found then raise exception 'Cuenta no existe'; end if;
  select count(*) into ya from profiles_inventory where mother_id = p_mother;
  if p_cantidad < 1 or ya + p_cantidad > coalesce(m.max_perfiles, 5) then raise exception 'Excede el maximo de perfiles de la cuenta (% de %)', ya, m.max_perfiles; end if;
  for i in 1..p_cantidad loop
    insert into profiles_inventory(mother_id, product_id, nombre_perfil, estado) values (p_mother, p_product, p_prefijo || ' ' || (ya + i), 'disponible');
  end loop;
  return p_cantidad;
end $function$;

-- Función: get_next_customer_code
CREATE OR REPLACE FUNCTION public.get_next_customer_code(p_es_revendedor boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  prefix text;
  start_num int;
  candidate int;
  code_candidate text;
  exists_code boolean;
begin
  if p_es_revendedor then
    prefix := 'RVD';
    start_num := 1001;
  else
    prefix := 'CLT';
    start_num := 1;
  end if;

  candidate := start_num;
  loop
    if p_es_revendedor then
      code_candidate := prefix || ':' || candidate::text;
    else
      code_candidate := prefix || ':' || lpad(candidate::text, 3, '0');
    end if;

    select exists(select 1 from customers where codigo_identificacion = code_candidate) into exists_code;
    if not exists_code then
      return code_candidate;
    end if;
    candidate := candidate + 1;
  end loop;
end;
$function$;

-- Función: handle_new_user
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  assigned_code text;
begin
  assigned_code := get_next_customer_code(false); -- Por defecto cliente CLT:001
  insert into customers(id, nombre, email, telefono, codigo_identificacion, es_revendedor)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'nombre'),
    new.email,
    coalesce(new.phone, new.raw_user_meta_data->>'telefono'),
    assigned_code,
    false
  ) on conflict (id) do update set
    codigo_identificacion = coalesce(customers.codigo_identificacion, assigned_code);
  return new;
end;
$function$;

-- Función: is_admin
CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1 from public.admins
    where lower(admins.email) = lower(auth.jwt()->>'email')
  ) or lower(coalesce(auth.jwt()->>'email', '')) in (
    'emprendimientogregoryizquierdo@gmail.com',
    'gregoryizquierdo1990@gmail.com'
  );
$function$;

-- Función: liberar_perfil_inventario
CREATE OR REPLACE FUNCTION public.liberar_perfil_inventario(p_profile_id uuid, p_nuevo_pin text DEFAULT NULL::text, p_nuevo_nombre text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orders_updated int := 0;
  v_profile_exists boolean := false;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'No autorizado. Solo administradores pueden liberar perfiles.';
  END IF;

  SELECT EXISTS(SELECT 1 FROM profiles_inventory WHERE id = p_profile_id) INTO v_profile_exists;
  IF NOT v_profile_exists THEN
    RAISE EXCEPTION 'Perfil no encontrado en inventario.';
  END IF;

  -- 1. Actualizar el perfil a disponible y limpiar asignaciones, vendedor y cliente_final
  UPDATE profiles_inventory
  SET 
    estado = 'disponible',
    inicia = null,
    vence = null,
    assigned_customer_id = null,
    vendedor = null,
    vendedor_id = null,
    cliente_final = null,
    pin = coalesce(nullif(trim(p_nuevo_pin), ''), pin),
    nombre_perfil = coalesce(nullif(trim(p_nuevo_nombre), ''), nombre_perfil),
    no_renueva = false,
    no_renueva_reportado_at = null,
    no_renueva_motivo = null,
    no_renueva_por = null
  WHERE id = p_profile_id;

  -- 2. Marcar las órdenes activas vinculadas como vencidas
  UPDATE orders
  SET estado = 'vencido',
      no_renueva = false
  WHERE profile_id = p_profile_id
    AND estado IN ('entregado', 'pagado');
  GET DIAGNOSTICS v_orders_updated = row_count;

  RETURN jsonb_build_object(
    'ok', true,
    'profile_id', p_profile_id,
    'orders_closed', v_orders_updated,
    'mensaje', 'Perfil liberado con éxito. Ya está en stock y disponible para la venta en la tienda.'
  );
END;
$function$;

-- Función: liquidar_comisiones_socio
CREATE OR REPLACE FUNCTION public.liquidar_comisiones_socio(p_vendedor_id uuid, p_referencia text, p_notas text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_count int;
  v_total_usd numeric;
  v_total_bs numeric;
begin
  if not is_admin() then
    raise exception 'No autorizado: se requieren permisos de administrador';
  end if;

  select count(*), coalesce(sum(ganancia_vendedor_usd), 0.00), coalesce(sum(ganancia_vendedor_bs), 0.00)
  into v_count, v_total_usd, v_total_bs
  from partner_commissions
  where vendedor_id = p_vendedor_id and estado = 'pendiente';

  if v_count = 0 then
    raise exception 'No hay comisiones pendientes de liquidación para este vendedor';
  end if;

  update partner_commissions
  set estado = 'liquidada',
      liquidada_at = now(),
      referencia_pago = p_referencia,
      notas = coalesce(p_notas, 'Liquidado por administrador')
  where vendedor_id = p_vendedor_id and estado = 'pendiente';

  return jsonb_build_object(
    'ok', true,
    'comisiones_liquidadas', v_count,
    'total_usd', v_total_usd,
    'total_bs', v_total_bs,
    'referencia', p_referencia
  );
end;
$function$;

-- Función: mark_overdue_installments
CREATE OR REPLACE FUNCTION public.mark_overdue_installments()
 RETURNS TABLE(vencen_hoy integer, vencidas integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update installments set estado = 'vencida' where estado = 'pendiente' and fecha_vencimiento < current_date;
  return query select (select count(*)::int from installments where estado in ('pendiente','en_revision') and fecha_vencimiento = current_date),
                      (select count(*)::int from installments where estado = 'vencida');
end $function$;

-- Función: my_credentials
CREATE OR REPLACE FUNCTION public.my_credentials()
 RETURNS TABLE(order_id uuid, servicio text, tipo text, correo text, clave text, perfil text, pin text, vence date)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  select o.id, p.nombre, p.tipo, m.correo, dec_text(m.clave), pi.nombre_perfil, dec_text(pi.pin), o.vence
  from orders o join products p on p.id = o.product_id join profiles_inventory pi on pi.id = o.profile_id join mother_accounts m on m.id = pi.mother_id
  where o.customer_id = auth.uid() and o.estado = 'entregado' $function$;

-- Función: my_reseller_clients
CREATE OR REPLACE FUNCTION public.my_reseller_clients()
 RETURNS TABLE(profile_id uuid, cliente_id uuid, cliente_nombre text, cliente_telefono text, cliente_email text, servicio text, plataforma text, nombre_perfil text, pin text, correo text, clave text, vence date, estado text, no_renueva boolean, tiene_pendiente boolean, orden_pendiente_id uuid, orden_pendiente_ref text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_is_adm boolean := false;
  v_seller_name text := null;
begin
  if v_user_id is null then return; end if;

  v_is_adm := is_admin();
  select nombre into v_seller_name from customers where id = v_user_id;

  if v_is_adm then
    -- Administrador: clientes y perfiles de venta directa en tienda
    return query
    select distinct
      pi.id as profile_id,
      coalesce(c.id, o.customer_id) as cliente_id,
      coalesce(nullif(trim(pi.cliente_final), ''), c.nombre, o_cust.nombre, 'Cliente Tienda') as cliente_nombre,
      coalesce(nullif(trim(pi.cliente_telefono), ''), c.telefono, o_cust.telefono, '') as cliente_telefono,
      coalesce(c.email, o_cust.email, '') as cliente_email,
      coalesce(p.nombre, m.plataforma) as servicio,
      m.plataforma as plataforma,
      pi.nombre_perfil as nombre_perfil,
      case when pi.pin like 'enc:%' then dec_text(pi.pin) else pi.pin end as pin,
      m.correo as correo,
      case when m.clave like 'enc:%' then dec_text(m.clave) else m.clave end as clave,
      coalesce(pi.vence, o.vence) as vence,
      pi.estado as estado,
      coalesce(pi.no_renueva, false) as no_renueva,
      (ord_pend.p_id is not null) as tiene_pendiente,
      ord_pend.p_id as orden_pendiente_id,
      ord_pend.p_ref as orden_pendiente_ref
    from profiles_inventory pi
    join mother_accounts m on m.id = pi.mother_id
    left join products p on p.id = pi.product_id
    left join customers c on c.id = pi.assigned_customer_id
    left join orders o on o.profile_id = pi.id and o.estado in ('entregado', 'pagado')
    left join customers o_cust on o_cust.id = o.customer_id
    left join lateral (
      select o2.id as p_id, o2.referencia as p_ref
      from public.orders o2
      where o2.profile_id = pi.id and o2.estado = 'pendiente'
      order by o2.created_at desc limit 1
    ) ord_pend on true
    where (
      (pi.vendedor_id is null and coalesce(c.vendedor_id, o.vendedor_id) is null)
      or lower(trim(coalesce(pi.vendedor, ''))) in ('directo tienda', 'tienda', 'directo')
      or lower(trim(coalesce(c.vendedor_nombre, o_cust.vendedor_nombre, ''))) in ('directo tienda', 'tienda', 'directo')
    )
    order by vence asc nulls last;

  else
    -- Revendedor (Pablo, Nelson, etc.): Sus clientes y perfiles asignados
    return query
    select distinct
      pi.id as profile_id,
      coalesce(c.id, o.customer_id) as cliente_id,
      coalesce(nullif(trim(pi.cliente_final), ''), c.nombre, o_cust.nombre, 'Cliente Asignado') as cliente_nombre,
      coalesce(nullif(trim(pi.cliente_telefono), ''), c.telefono, o_cust.telefono, '') as cliente_telefono,
      coalesce(c.email, o_cust.email, '') as cliente_email,
      coalesce(p.nombre, m.plataforma) as servicio,
      m.plataforma as plataforma,
      pi.nombre_perfil as nombre_perfil,
      case when pi.pin like 'enc:%' then dec_text(pi.pin) else pi.pin end as pin,
      m.correo as correo,
      case when m.clave like 'enc:%' then dec_text(m.clave) else m.clave end as clave,
      coalesce(pi.vence, o.vence) as vence,
      pi.estado as estado,
      coalesce(pi.no_renueva, false) as no_renueva,
      (ord_pend.p_id is not null) as tiene_pendiente,
      ord_pend.p_id as orden_pendiente_id,
      ord_pend.p_ref as orden_pendiente_ref
    from profiles_inventory pi
    join mother_accounts m on m.id = pi.mother_id
    left join products p on p.id = pi.product_id
    left join customers c on c.id = pi.assigned_customer_id
    left join orders o on o.profile_id = pi.id and o.estado in ('entregado', 'pagado')
    left join customers o_cust on o_cust.id = o.customer_id
    left join lateral (
      select o2.id as p_id, o2.referencia as p_ref
      from public.orders o2
      where o2.profile_id = pi.id and o2.estado = 'pendiente'
      order by o2.created_at desc limit 1
    ) ord_pend on true
    where (
      pi.vendedor_id = v_user_id
      or c.vendedor_id = v_user_id
      or o.vendedor_id = v_user_id
      or pi.assigned_customer_id = v_user_id
      or o.customer_id = v_user_id
      or (pi.vendedor is not null and v_seller_name is not null and lower(trim(pi.vendedor)) = lower(trim(v_seller_name)))
      or exists (
        select 1 from public.customers cust
        where cust.id = v_user_id
          and (
            lower(trim(coalesce(pi.vendedor, ''))) in (lower(trim(coalesce(cust.nombre, ''))), lower(trim(coalesce(cust.codigo_identificacion, ''))))
            or (coalesce(cust.codigo_identificacion, '') = 'RVD:1001' and lower(coalesce(pi.vendedor, '')) like '%pablo%')
          )
      )
    )
    order by vence asc nulls last;
  end if;
end;
$function$;

-- Función: my_reseller_debts
CREATE OR REPLACE FUNCTION public.my_reseller_debts()
 RETURNS TABLE(id uuid, order_id uuid, cliente_id uuid, cliente_nombre text, cliente_telefono text, servicio text, nombre_perfil text, monto_usd numeric, monto_bs numeric, tasa_bs numeric, fecha_vencimiento date, estado text, referencia text, pagada_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then return; end if;

  return query
  select distinct
    i.id,
    i.order_id,
    c.id as cliente_id,
    coalesce(c.nombre, 'Cliente Asignado') as cliente_nombre,
    coalesce(c.telefono, '') as cliente_telefono,
    coalesce(p.nombre, m.plataforma, 'Servicio Digital') as servicio,
    coalesce(pi.nombre_perfil, 'Perfil 1') as nombre_perfil,
    i.monto_usd,
    i.monto_bs,
    i.tasa_bs,
    i.fecha_vencimiento,
    i.estado,
    i.referencia,
    i.pagada_at,
    i.created_at
  from public.installments i
  left join public.orders o on o.id = i.order_id
  left join public.customers c on c.id = coalesce(i.customer_id, o.customer_id)
  left join public.products p on p.id = o.product_id
  left join public.profiles_inventory pi on pi.id = o.profile_id
  left join public.mother_accounts m on m.id = pi.mother_id
  where (
    i.reseller_id = v_user_id
    or o.vendedor_id = v_user_id
    or (i.customer_id = v_user_id and exists (select 1 from public.customers cust where cust.id = v_user_id and cust.es_revendedor = true))
  )
  order by (i.estado = 'pendiente') desc, (i.estado = 'en_revision') desc, i.fecha_vencimiento asc;
end;
$function$;

-- Función: notify_admin
CREATE OR REPLACE FUNCTION public.notify_admin(p_kind text, p_msg text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  u text;
  s text;
BEGIN
  SELECT value INTO u FROM secrets WHERE name = 'notify_url';
  SELECT value INTO s FROM secrets WHERE name = 'notify_secret';
  IF u IS NULL OR s IS NULL THEN RETURN; END IF;
  
  -- timeout de 2000ms para evitar congelar transacciones si la red externa está lenta
  PERFORM net.http_post(
    url := u,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', s),
    body := jsonb_build_object('kind', p_kind, 'msg', p_msg),
    timeout_milliseconds := 2000
  );
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
$function$;

-- Función: orders_guard
CREATE OR REPLACE FUNCTION public.orders_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  pr public.products;
  r numeric;
  pm public.payment_methods;
  eff_price numeric;
  is_res boolean := false;
  v_card_desc numeric := 0;
begin
  if is_admin() or current_setting('app.internal', true) = '1' then
    return new;
  end if;

  select * into pr from public.products where id = new.product_id and activo;
  if not found then
    raise exception 'Producto no disponible o inactivo';
  end if;

  select coalesce(es_revendedor, false) into is_res from public.customers where id = auth.uid();
  if new.metodo_id is not null then
    select * into pm from public.payment_methods where id = new.metodo_id;
  end if;

  -- 1. Jerarquía de precios: Revendedor oficial prevalece sobre tarifa minorista Binance
  if is_res and not coalesce(pr.es_exclusivo_central, false) and pr.precio_revendedor_usd is not null and pr.precio_revendedor_usd > 0 then
    eff_price := pr.precio_revendedor_usd;
  elsif (pm.tipo = 'binance' or lower(coalesce(pm.nombre,'')) like '%binance%') and pr.precio_binance_usd is not null and pr.precio_binance_usd > 0 then
    eff_price := pr.precio_binance_usd;
  else
    eff_price := pr.precio_usd;
  end if;

  -- 2. Descuento oficial de Tarjeta Zeny (5%)
  select descuento_porcentaje into v_card_desc
  from public.zeny_cards
  where customer_id = auth.uid() and estado = 'activa'
  limit 1;

  if v_card_desc is not null and v_card_desc > 0 then
    eff_price := round(eff_price * (1.0 - (v_card_desc / 100.0)), 2);
  end if;

  select bs_por_usd into r from public.exchange_rates order by fecha desc limit 1;
  new.customer_id := auth.uid();

  -- Si new.total_usd viene con monto válido (ej: cuota inicial o zeny descontado), no sobreescribir ciegamente
  if new.total_usd is null or new.total_usd <= 0 or new.total_usd > eff_price then
    new.total_usd := eff_price;
  end if;

  new.tasa_bs := r;
  new.total_bs := round(new.total_usd * coalesce(r, 0), 2);
  new.estado := 'pendiente';
  new.profile_id := null;
  new.inicia := null;
  new.vence := null;
  new.proximo_pago := null;
  new.gcal_event_id := null;
  return new;
end $function$;

-- Función: orders_sync_installments
CREATE OR REPLACE FUNCTION public.orders_sync_installments()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.estado is distinct from old.estado then
    if new.estado = 'entregado' then update installments set estado = 'pagada', pagada_at = coalesce(pagada_at, now()) where order_id = new.id and numero_cuota = 1 and estado <> 'pagada'; end if;
    if new.estado in ('rechazado','cancelado','vencido','reembolsado') then delete from installments where order_id = new.id and estado <> 'pagada'; end if;
  end if;
  return new;
end $function$;

-- Función: pagar_compra_proveedor
CREATE OR REPLACE FUNCTION public.pagar_compra_proveedor(p_purchase_id uuid, p_metodo text, p_tasa numeric DEFAULT NULL::numeric, p_comprobante text DEFAULT NULL::text, p_notas text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_pur record;
  v_monto_bs numeric(16,2) := 0.00;
  v_tasa numeric(14,2) := coalesce(p_tasa, 1.00);
begin
  if not is_admin() then
    raise exception 'No autorizado: se requieren permisos de administrador';
  end if;

  select * into v_pur from purchases where id = p_purchase_id for update;
  if not found then
    raise exception 'Registro de compra no encontrado';
  end if;

  if v_pur.estado_pago = 'pagado' then
    raise exception 'Esta compra ya se encuentra pagada';
  end if;

  if p_metodo = 'bolivares' then
    v_monto_bs := round(coalesce(v_pur.monto_usdt, v_pur.monto_usd, 0.00) * v_tasa, 2);
  end if;

  update purchases
  set estado_pago = 'pagado',
      pagado_at = now(),
      metodo_pago_proveedor = p_metodo,
      tasa_usdt_pago = case when p_metodo = 'bolivares' then v_tasa else null end,
      monto_pagado_bs = case when p_metodo = 'bolivares' then v_monto_bs else null end,
      comprobante_pago = p_comprobante,
      notas = case 
        when p_notas is not null and length(trim(p_notas)) > 0 then coalesce(notas, '') || ' | ' || p_notas
        else notas
      end
  where id = p_purchase_id;

  return jsonb_build_object(
    'ok', true,
    'purchase_id', p_purchase_id,
    'monto_usdt', coalesce(v_pur.monto_usdt, v_pur.monto_usd),
    'monto_bs', v_monto_bs,
    'metodo', p_metodo
  );
end;
$function$;

-- Función: pagar_deuda_revendedor
CREATE OR REPLACE FUNCTION public.pagar_deuda_revendedor(p_installment_id uuid, p_metodo text, p_metodo_id uuid DEFAULT NULL::uuid, p_referencia text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_inst public.installments%rowtype;
  v_zeny_bal numeric(12,2) := 0;
  v_seller_nom text := 'Revendedor';
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para pagar deudas.';
  end if;

  select * into v_inst from public.installments where id = p_installment_id;
  if not found then
    raise exception 'Registro de crédito no encontrado.';
  end if;

  -- Verificar pertenencia
  if not is_admin() and v_inst.reseller_id <> v_user_id and v_inst.customer_id <> v_user_id then
    raise exception 'No estás autorizado para pagar este crédito.';
  end if;

  if v_inst.estado = 'pagada' then
    raise exception 'Esta cuenta por pagar ya fue saldada previamente.';
  end if;

  select nombre into v_seller_nom from public.customers where id = v_user_id;

  if p_metodo = 'zeny' then
    -- Verificar saldo Zeny
    select coalesce(sum(monto), 0) into v_zeny_bal
    from public.zeny_ledger
    where customer_id = v_user_id and estado in ('aprobado', 'completado');

    if v_zeny_bal < v_inst.monto_usd then
      raise exception 'Saldo Zeny insuficiente. Tu saldo es $% USD y el monto a pagar es $% USD.', v_zeny_bal, v_inst.monto_usd;
    end if;

    -- Descontar del zeny_ledger
    insert into public.zeny_ledger (customer_id, tipo, monto, estado, referencia)
    values (v_user_id, 'compra', -v_inst.monto_usd, 'aprobado', 'Pago de Crédito Mayorista: ' || coalesce(v_inst.referencia, 'Cuota'));

    -- Actualizar balance en customers
    update public.customers set zeny_balance = coalesce(zeny_balance, 0) - v_inst.monto_usd where id = v_user_id;

    -- Marcar cuota como pagada
    update public.installments set
      estado = 'pagada',
      pagada_at = now(),
      referencia = coalesce(referencia, '') || ' [PAGADO CON ZENY]'
    where id = p_installment_id;

    -- Actualizar orden si aplica
    if v_inst.order_id is not null then
      update public.orders set
        referencia = coalesce(referencia, '') || ' [CRÉDITO SALDADO ZENY]'
      where id = v_inst.order_id;
    end if;

    return jsonb_build_object(
      'success', true,
      'estado', 'pagada',
      'mensaje', 'Deuda saldada exitosamente con saldo Zeny.'
    );

  elsif p_metodo = 'transferencia' then
    if p_referencia is null or trim(p_referencia) = '' then
      raise exception 'Debes ingresar el número de referencia bancaria.';
    end if;

    update public.installments set
      estado = 'en_revision',
      metodo_id = p_metodo_id,
      referencia = coalesce(referencia, '') || ' [REF PAGO: ' || trim(p_referencia) || ']'
    where id = p_installment_id;

    return jsonb_build_object(
      'success', true,
      'estado', 'en_revision',
      'mensaje', 'Comprobante de pago registrado. Gregory verificará la referencia.'
    );

  else
    raise exception 'Método no soportado (debe ser zeny o transferencia).';
  end if;
end;
$function$;

-- Función: pay_installment
CREATE OR REPLACE FUNCTION public.pay_installment(p_installment_id uuid, p_metodo_id uuid, p_referencia text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare inst installments; r numeric;
begin
  if auth.uid() is null then raise exception 'Inicia sesion'; end if;
  select * into inst from installments where id = p_installment_id for update;
  if not found then raise exception 'Cuota no encontrada'; end if;
  if inst.customer_id <> auth.uid() and not is_admin() then raise exception 'No autorizado'; end if;
  select bs_por_usd into r from exchange_rates order by fecha desc limit 1;
  update installments set estado = 'en_revision', metodo_id = p_metodo_id, referencia = left(coalesce(p_referencia,''), 120), tasa_bs = r, monto_bs = inst.monto_usd * coalesce(r, 0) where id = p_installment_id;
end $function$;

-- Función: procesar_comision_socio_orden
CREATE OR REPLACE FUNCTION public.procesar_comision_socio_orden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform registrar_comision_orden(new.id);
  return new;
end;
$function$;

-- Función: protect_customer_fields
CREATE OR REPLACE FUNCTION public.protect_customer_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if current_user in ('postgres', 'service_role') or is_admin() then
    return new;
  end if;

  new.id := old.id;
  new.email := old.email;
  new.zeny_balance := old.zeny_balance;
  new.limite_credito := old.limite_credito;
  new.nivel_credito := old.nivel_credito;
  new.es_revendedor := old.es_revendedor;
  new.codigo_identificacion := old.codigo_identificacion;
  new.creado := old.creado;
  return new;
end;
$function$;

-- Función: purchase_from_mother
CREATE OR REPLACE FUNCTION public.purchase_from_mother()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(new.costo_usd, 0) > 0 then
    if exists (select 1 from public.purchases where mother_id = new.id) then
      update public.purchases
      set monto_usd = new.costo_usd,
          proveedor = coalesce(new.proveedor, proveedor),
          plataforma = coalesce(new.plataforma, plataforma),
          fecha = coalesce(fecha, current_date)
      where mother_id = new.id;
    else
      insert into public.purchases(proveedor, plataforma, mother_id, monto_usd, notas, fecha)
      values (new.proveedor, new.plataforma, new.id, new.costo_usd, 'Automático: alta/sincronización cuenta madre', current_date);
    end if;
  end if;
  return new;
end $function$;

-- Función: refund_order
CREATE OR REPLACE FUNCTION public.refund_order(p_order uuid, p_monto numeric, p_destino text, p_motivo text, p_liberar boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  o public.orders;
  prev numeric;
  m numeric;
  rid uuid;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select * into o from public.orders where id = p_order for update;
  if not found then raise exception 'Pedido no existe'; end if;
  if o.estado not in ('pagado','entregado') then
    raise exception 'Solo se reembolsan pedidos pagados o entregados';
  end if;
  if p_destino not in ('zeny','usdt','bolivares','externo') then
    raise exception 'Destino de devolución inválido';
  end if;

  select coalesce(sum(monto_usd),0) into prev from public.refunds where order_id = p_order;
  m := coalesce(p_monto, o.total_usd - prev);
  if m <= 0 or m + prev > o.total_usd then
    raise exception 'Monto inválido (máximo reembolsable: %)', o.total_usd - prev;
  end if;

  insert into public.refunds(order_id, customer_id, monto_usd, destino, motivo, liberado)
  values (p_order, o.customer_id, m, p_destino, p_motivo, case when m + prev >= o.total_usd then p_liberar end)
  returning id into rid;

  -- Si el destino es Zeny, se acredita con estado 'aprobado' para sumar inmediatamente al saldo
  if p_destino = 'zeny' then
    insert into public.zeny_ledger(customer_id, tipo, monto, referencia, estado, order_id)
    values (o.customer_id, 'reembolso', m, 'Reembolso pedido ' || left(o.id::text, 8), 'aprobado', o.id);
  end if;

  if m + prev >= o.total_usd then
    update public.orders set estado = 'reembolsado' where id = p_order;
    update public.invoices set estado = 'anulada' where order_id = p_order;
    if o.profile_id is not null then
      update public.profiles_inventory
      set estado = case when p_liberar then 'disponible' else 'suspendido' end,
          inicia = null,
          vence = null
      where id = o.profile_id;
    end if;
  end if;

  return rid;
end $function$;

-- Función: registrar_comision_orden
CREATE OR REPLACE FUNCTION public.registrar_comision_orden(p_order_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ord record;
  v_seller_id uuid;
  v_prod record;
  v_pm record;
  v_rate numeric;
  v_is_binance boolean := false;
  v_metodo_tipo text := 'bolivares';
  v_pvp numeric;
  v_rvd numeric;
  v_cost numeric;
  v_gan_vendedor numeric;
  v_gan_negocio numeric;
  v_gan_gregory numeric;
begin
  select * into v_ord from orders where id = p_order_id;
  if not found or v_ord.estado not in ('entregado', 'pagado') then
    return;
  end if;

  v_seller_id := v_ord.vendedor_id;
  if v_seller_id is null and v_ord.customer_id is not null then
    select vendedor_id into v_seller_id from customers where id = v_ord.customer_id;
  end if;

  if v_seller_id is null then
    return;
  end if;

  select bs_por_usd into v_rate from exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_ord.tasa_bs, v_rate, 50.00);

  select * into v_prod from products where id = v_ord.product_id;

  -- 1. Detectar si el pago es Binance (USDT) o Bolívares
  if v_ord.metodo_id is not null then
    select * into v_pm from payment_methods where id = v_ord.metodo_id;
    if v_pm.tipo = 'binance' or lower(coalesce(v_pm.nombre, '')) like '%binance%' then
      v_is_binance := true;
    end if;
  end if;

  if not v_is_binance then
    if lower(coalesce(v_ord.referencia, '')) like '%binance%' or lower(coalesce(v_ord.referencia, '')) like '%usdt%' then
      v_is_binance := true;
    end if;
  end if;

  -- 2. Asignar comisiones según el modelo específico
  if v_is_binance then
    v_metodo_tipo := 'binance';
    v_pvp := coalesce(v_ord.total_usd, v_prod.precio_binance_usd, v_prod.precio_usd, 0.00);
    v_rvd := coalesce(v_prod.precio_revendedor_usd, v_pvp * 0.80);
    v_cost := coalesce(v_prod.costo_usdt, 0.00);

    if coalesce(v_prod.reparto_usdt_pablo, 0.00) > 0 then
      v_gan_vendedor := v_prod.reparto_usdt_pablo;
      v_gan_negocio  := v_prod.reparto_usdt_negocio;
      v_gan_gregory  := v_prod.reparto_usdt_gregory;
    else
      v_gan_vendedor := greatest(0.00, round(v_pvp - v_rvd, 2));
      v_gan_gregory  := round(greatest(0.00, v_rvd - v_cost) * 0.70, 2);
      v_gan_negocio  := round(greatest(0.00, v_rvd - v_cost) - v_gan_gregory, 2);
    end if;
  else
    v_metodo_tipo := 'bolivares';
    v_pvp := coalesce(v_ord.total_usd, v_prod.precio_usd, 0.00);
    v_rvd := coalesce(v_prod.precio_revendedor_usd, v_pvp * 0.80);
    v_cost := coalesce(v_prod.costo_bs, v_prod.costo_usdt, 0.00);

    if coalesce(v_prod.reparto_bs_pablo, 0.00) > 0 then
      v_gan_vendedor := v_prod.reparto_bs_pablo;
      v_gan_negocio  := v_prod.reparto_bs_negocio;
      v_gan_gregory  := v_prod.reparto_bs_gregory;
    else
      v_gan_vendedor := greatest(0.00, round(v_pvp - v_rvd, 2));
      v_gan_gregory  := round(greatest(0.00, v_rvd - v_cost) * 0.70, 2);
      v_gan_negocio  := round(greatest(0.00, v_rvd - v_cost) - v_gan_gregory, 2);
    end if;
  end if;

  insert into partner_commissions (
    order_id, customer_id, vendedor_id, product_id, servicio_nombre,
    metodo_origen, monto_cobrado_usd, precio_revendedor_usd, costo_proveedor_usd,
    ganancia_vendedor_usd, ganancia_gregory_usd, ganancia_negocio_usd,
    tasa_bs, ganancia_vendedor_bs, ganancia_gregory_bs, ganancia_negocio_bs, estado
  ) values (
    v_ord.id, v_ord.customer_id, v_seller_id, v_ord.product_id, coalesce(v_prod.nombre, 'Servicio Streaming'),
    v_metodo_tipo, v_pvp, v_rvd, v_cost,
    v_gan_vendedor, v_gan_gregory, v_gan_negocio,
    v_rate,
    round(v_gan_vendedor * v_rate, 2),
    round(v_gan_gregory * v_rate, 2),
    round(v_gan_negocio * v_rate, 2),
    'pendiente'
  ) on conflict (order_id) do update set
    vendedor_id = excluded.vendedor_id,
    metodo_origen = excluded.metodo_origen,
    monto_cobrado_usd = excluded.monto_cobrado_usd,
    precio_revendedor_usd = excluded.precio_revendedor_usd,
    costo_proveedor_usd = excluded.costo_proveedor_usd,
    ganancia_vendedor_usd = excluded.ganancia_vendedor_usd,
    ganancia_gregory_usd = excluded.ganancia_gregory_usd,
    ganancia_negocio_usd = excluded.ganancia_negocio_usd,
    tasa_bs = excluded.tasa_bs,
    ganancia_vendedor_bs = excluded.ganancia_vendedor_bs,
    ganancia_gregory_bs = excluded.ganancia_gregory_bs,
    ganancia_negocio_bs = excluded.ganancia_negocio_bs;
end;
$function$;

-- Función: registrar_devolucion_avanzada
CREATE OR REPLACE FUNCTION public.registrar_devolucion_avanzada(p_order_id uuid, p_monto_usd numeric, p_metodo text DEFAULT 'zeny'::text, p_motivo text DEFAULT NULL::text, p_referencia text DEFAULT NULL::text, p_destinatario text DEFAULT NULL::text, p_accion_perfil text DEFAULT 'liberar'::text, p_diferencia_usd numeric DEFAULT 0.00, p_tasa numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ord record;
  v_rid uuid;
  v_prev numeric := 0.00;
  v_monto numeric(10,2);
  v_monto_bs numeric(16,2) := 0.00;
  v_tasa numeric(14,2);
  v_destino_legacy text;
begin
  if not is_admin() then
    raise exception 'No autorizado: se requieren permisos de administrador';
  end if;

  select * into v_ord from orders where id = p_order_id for update;
  if not found then
    raise exception 'El pedido indicado no existe';
  end if;

  if v_ord.estado not in ('pagado', 'entregado', 'vencido') then
    raise exception 'Solo se pueden reembolsar pedidos pagados o entregados';
  end if;

  select coalesce(sum(monto_usd), 0.00) into v_prev from refunds where order_id = p_order_id;
  v_monto := coalesce(p_monto_usd, v_ord.total_usd - v_prev);

  if v_monto <= 0 or (v_monto + v_prev) > (v_ord.total_usd + 0.01) then
    raise exception 'Monto inválido (máximo reembolsable: $%)', round(v_ord.total_usd - v_prev, 2);
  end if;

  select bs_por_usd into v_tasa from exchange_rates order by fecha desc limit 1;
  v_tasa := coalesce(p_tasa, v_tasa, 50.00);
  v_monto_bs := round(v_monto * v_tasa, 2);

  v_destino_legacy := case when p_metodo = 'zeny' then 'zeny' else 'externo' end;

  -- 1. Insertar el registro de devolución
  insert into refunds (
    order_id, customer_id, monto_usd, destino, motivo, liberado,
    metodo_reembolso, referencia_soporte, destinatario_datos,
    accion_perfil, diferencia_precio_usd, tasa_cambio, monto_bs
  ) values (
    p_order_id, v_ord.customer_id, v_monto, v_destino_legacy, p_motivo, (p_accion_perfil = 'liberar'),
    p_metodo, p_referencia, p_destinatario,
    p_accion_perfil, coalesce(p_diferencia_usd, 0.00), v_tasa, v_monto_bs
  ) returning id into v_rid;

  -- 2. Si el reembolso es a la Billetera Zeny, abonar inmediatamente
  if p_metodo = 'zeny' then
    insert into zeny_ledger (customer_id, tipo, monto, referencia, estado)
    values (v_ord.customer_id, 'reembolso', v_monto, 'Reembolso / Devolución Pedido ' || left(v_ord.id::text, 8), 'aprobado');
  end if;

  -- 3. Acción sobre el perfil en inventario
  if v_ord.profile_id is not null then
    if p_accion_perfil = 'liberar' then
      update profiles_inventory
      set estado = 'disponible',
          assigned_customer_id = null,
          inicia = null,
          vence = null
      where id = v_ord.profile_id;
    elsif p_accion_perfil = 'suspender' then
      update profiles_inventory
      set estado = 'suspendido'
      where id = v_ord.profile_id;
    end if;
  end if;

  -- 4. Si el reembolso cubre la totalidad, marcar el pedido como reembolsado
  if (v_monto + v_prev) >= (v_ord.total_usd - 0.01) then
    update orders set estado = 'reembolsado' where id = p_order_id;
    update invoices set estado = 'anulada' where order_id = p_order_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'refund_id', v_rid,
    'order_id', p_order_id,
    'monto_usd', v_monto,
    'monto_bs', v_monto_bs,
    'metodo', p_metodo
  );
end;
$function$;

-- Función: reject_order
CREATE OR REPLACE FUNCTION public.reject_order(p_order uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin if not is_admin() then raise exception 'No autorizado'; end if; perform _close_order(p_order, 'rechazado'); end $function$;

-- Función: release_expired
CREATE OR REPLACE FUNCTION public.release_expired()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  m int;
  r record;
begin
  select coalesce((value->>'minutos')::int, 60) into m from public.settings where key = 'reserva';

  for r in
    select id, profile_id from public.orders
    where estado = 'pendiente'
      and created_at < now() - make_interval(mins => coalesce(m, 60))
    for update skip locked
  loop
    update public.orders set estado = 'vencido' where id = r.id;

    if r.profile_id is not null then
      update public.profiles_inventory
      set estado = 'disponible'
      where id = r.profile_id and estado = 'reservado';
    end if;

    update public.zeny_ledger
    set estado = 'rechazado'
    where order_id = r.id and tipo = 'compra' and estado = 'pendiente';

    update public.installments
    set estado = 'cancelada'
    where order_id = r.id and estado in ('pendiente', 'en_revision');
  end loop;
end $function$;

-- Función: renovar_suscripcion_perfil
CREATE OR REPLACE FUNCTION public.renovar_suscripcion_perfil(p_profile_id uuid, p_metodo text, p_metodo_id uuid DEFAULT NULL::uuid, p_referencia text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_is_adm boolean := false;
  v_prof profiles_inventory%rowtype;
  v_prod products%rowtype;
  v_mother mother_accounts%rowtype;
  v_is_reseller boolean := false;
  v_precio numeric(10,2) := 0;
  v_bcv numeric(12,4) := 1;
  v_cur_vence date;
  v_next_vence date;
  v_zeny_bal numeric(12,2) := 0;
  v_cred_limit numeric(10,2) := 0;
  v_used_cred numeric(10,2) := 0;
  v_order_id uuid;
  v_cli_nom text := 'Cliente';
  v_srv_nom text := 'Servicio Digital';
  v_assigned_cli uuid;
  v_seller_name text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión para realizar renovaciones.';
  END IF;

  -- Activar bypass app.internal para evitar bloqueos de orders_guard
  PERFORM set_config('app.internal', '1', true);

  v_is_adm := is_admin();

  -- 1. Obtener perfil
  SELECT * INTO v_prof FROM profiles_inventory WHERE id = p_profile_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Perfil no encontrado en inventario.';
  END IF;

  v_assigned_cli := v_prof.assigned_customer_id;

  -- 2. Verificar datos del usuario que ejecuta
  SELECT es_revendedor, limite_credito, nombre INTO v_is_reseller, v_cred_limit, v_seller_name
  FROM customers WHERE id = v_user_id;

  v_is_reseller := coalesce(v_is_reseller, false);
  v_cred_limit := coalesce(v_cred_limit, 0);

  -- 3. Autorización flexible y coherente con my_reseller_clients
  IF NOT v_is_adm AND NOT (
    v_prof.vendedor_id = v_user_id
    OR v_prof.assigned_customer_id = v_user_id
    OR EXISTS (SELECT 1 FROM orders o WHERE o.profile_id = p_profile_id AND (o.customer_id = v_user_id OR o.vendedor_id = v_user_id))
    OR EXISTS (SELECT 1 FROM customers c WHERE c.id = v_prof.assigned_customer_id AND c.vendedor_id = v_user_id)
    OR (v_prof.vendedor IS NOT NULL AND v_seller_name IS NOT NULL AND lower(trim(v_prof.vendedor)) = lower(trim(v_seller_name)))
    OR EXISTS (SELECT 1 FROM customers cust WHERE cust.id = v_user_id AND (
         lower(trim(coalesce(v_prof.vendedor, ''))) IN (lower(trim(coalesce(cust.nombre, ''))), lower(trim(coalesce(cust.codigo_identificacion, ''))))
         OR (coalesce(cust.codigo_identificacion, '') = 'RVD:1001' AND lower(coalesce(v_prof.vendedor, '')) LIKE '%pablo%')
         OR (cust.es_revendedor = true AND v_prof.vendedor_id IS NULL AND (v_prof.vendedor IS NULL OR lower(trim(v_prof.vendedor)) NOT IN ('directo tienda', 'tienda', 'directo')))
       ))
  ) THEN
    RAISE EXCEPTION 'No estás autorizado para renovar este perfil.';
  END IF;

  -- 4. Obtener producto y cuenta madre
  SELECT * INTO v_prod FROM products WHERE id = v_prof.product_id;
  SELECT * INTO v_mother FROM mother_accounts WHERE id = v_prof.mother_id;
  v_srv_nom := coalesce(v_prod.nombre, v_mother.plataforma, 'Servicio Digital');

  -- Nombre del cliente final asignado
  IF v_prof.cliente_final IS NOT NULL AND trim(v_prof.cliente_final) <> '' THEN
    v_cli_nom := trim(v_prof.cliente_final);
  ELSIF v_assigned_cli IS NOT NULL AND v_assigned_cli <> v_user_id THEN
    SELECT coalesce(nombre, email, 'Cliente') INTO v_cli_nom FROM customers WHERE id = v_assigned_cli;
  ELSIF v_prof.nombre_perfil IS NOT NULL THEN
    v_cli_nom := v_prof.nombre_perfil;
  ELSE
    v_cli_nom := 'Cliente';
  END IF;

  -- 5. Tarifa: mayorista si es revendedor, o precio público estándar
  IF v_is_reseller THEN
    IF v_prod.precio_revendedor_usd IS NOT NULL AND v_prod.precio_revendedor_usd > 0 THEN
      v_precio := v_prod.precio_revendedor_usd;
    ELSE
      SELECT precio_revendedor_usd INTO v_precio
      FROM products
      WHERE lower(nombre) LIKE '%' || lower(coalesce(v_mother.plataforma, '')) || '%'
        AND precio_revendedor_usd > 0
      ORDER BY orden ASC LIMIT 1;
      
      v_precio := coalesce(v_precio, 4.50);
    END IF;
  ELSE
    v_precio := coalesce(v_prod.precio_usd, 3.00);
  END IF;

  -- 6. Tasa BCV
  SELECT bs_por_usd INTO v_bcv FROM exchange_rates ORDER BY fecha DESC LIMIT 1;
  v_bcv := coalesce(v_bcv, 1);

  -- 7. Calcular nuevo vencimiento (+30 días desde la fecha agendada o desde hoy si ya expiró)
  v_cur_vence := coalesce(v_prof.vence, current_date);
  IF v_cur_vence < current_date THEN
    v_next_vence := current_date + interval '30 days';
  ELSE
    v_next_vence := v_cur_vence + interval '30 days';
  END IF;

  -- 8. Cerrar órdenes anteriores de este perfil marcándolas como vencidas para evitar conflicto de índice único
  UPDATE orders
  SET estado = 'vencido',
      no_renueva = false
  WHERE profile_id = p_profile_id
    AND estado IN ('entregado', 'pagado', 'pendiente');

  -- 9. Procesar según método de pago
  IF p_metodo = 'zeny' THEN
    SELECT coalesce(sum(monto), 0) INTO v_zeny_bal
    FROM zeny_ledger
    WHERE customer_id = v_user_id AND estado IN ('aprobado', 'completado');

    IF v_zeny_bal < v_precio THEN
      RAISE EXCEPTION 'Saldo Zeny insuficiente. Tu saldo es $% USD y el costo de renovación es $% USD.', v_zeny_bal, v_precio;
    END IF;

    INSERT INTO zeny_ledger (customer_id, tipo, monto, estado, referencia)
    VALUES (v_user_id, 'compra', -v_precio, 'aprobado', 'Renovación +30d ' || v_srv_nom || ' (' || coalesce(v_cli_nom, 'P1') || ')');

    UPDATE customers SET zeny_balance = coalesce(zeny_balance, 0) - v_precio WHERE id = v_user_id;

    UPDATE profiles_inventory SET
      vence = v_next_vence,
      estado = 'vendido',
      vendedor_id = coalesce(vendedor_id, v_user_id),
      vendedor = coalesce(vendedor, v_seller_name),
      no_renueva = false,
      no_renueva_reportado_at = null,
      no_renueva_motivo = null
    WHERE id = p_profile_id;

    INSERT INTO orders (
      customer_id, vendedor_id, profile_id, product_id,
      total_usd, tasa_bs, total_bs, estado,
      referencia, vence, proximo_pago, pagado_at
    ) VALUES (
      coalesce(v_assigned_cli, v_user_id),
      CASE WHEN v_is_reseller THEN v_user_id ELSE v_prof.vendedor_id END,
      p_profile_id,
      v_prof.product_id,
      v_precio,
      v_bcv,
      round(v_precio * v_bcv, 2),
      'entregado',
      '[RENOVACIÓN ZENY] ' || v_srv_nom || ' - ' || coalesce(v_cli_nom, 'Cliente') || ' (Mismas Credenciales)',
      v_next_vence,
      v_next_vence,
      now()
    ) RETURNING id INTO v_order_id;

    INSERT INTO public.invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
    VALUES (v_order_id, coalesce(v_assigned_cli, v_user_id), v_precio, round(v_precio * v_bcv, 2), v_bcv, 'emitida')
    ON CONFLICT (order_id) DO NOTHING;

    RETURN jsonb_build_object(
      'success', true,
      'estado', 'entregado',
      'order_id', v_order_id,
      'nuevo_vencimiento', v_next_vence,
      'total_usd', v_precio,
      'mensaje', 'Suscripción renovada exitosamente por 30 días con saldo Zeny.'
    );

  ELSIF p_metodo = 'credito' THEN
    IF NOT v_is_reseller AND NOT v_is_adm THEN
      RAISE EXCEPTION 'La opción a crédito solo está disponible para Revendedores Oficiales.';
    END IF;

    SELECT coalesce(sum(monto_usd), 0) INTO v_used_cred
    FROM public.installments
    WHERE (reseller_id = v_user_id OR (customer_id = v_user_id AND reseller_id IS NULL))
      AND estado IN ('pendiente', 'en_revision');

    IF v_cred_limit IS NOT NULL AND v_cred_limit > 0 AND (v_used_cred + v_precio) > v_cred_limit THEN
      RAISE EXCEPTION 'Límite de crédito superado. Tu límite es $% USD, ya utilizaste $% USD y esta renovación requiere $% USD.', v_cred_limit, v_used_cred, v_precio;
    END IF;

    UPDATE profiles_inventory SET
      vence = v_next_vence,
      estado = 'vendido',
      vendedor_id = coalesce(vendedor_id, v_user_id),
      vendedor = coalesce(vendedor, v_seller_name),
      no_renueva = false,
      no_renueva_reportado_at = null,
      no_renueva_motivo = null
    WHERE id = p_profile_id;

    INSERT INTO orders (
      customer_id, vendedor_id, profile_id, product_id,
      total_usd, tasa_bs, total_bs, estado,
      referencia, vence, proximo_pago, pagado_at
    ) VALUES (
      coalesce(v_assigned_cli, v_user_id),
      v_user_id,
      p_profile_id,
      v_prof.product_id,
      v_precio,
      v_bcv,
      round(v_precio * v_bcv, 2),
      'entregado',
      '[RENOVACIÓN CRÉDITO REVENDEDOR] ' || coalesce(v_cli_nom, 'Cliente') || ' - ' || v_srv_nom || ' ($' || v_precio || ' USD)',
      v_next_vence,
      v_next_vence,
      now()
    ) RETURNING id INTO v_order_id;

    INSERT INTO public.invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado)
    VALUES (v_order_id, coalesce(v_assigned_cli, v_user_id), v_precio, round(v_precio * v_bcv, 2), v_bcv, 'emitida')
    ON CONFLICT (order_id) DO NOTHING;

    INSERT INTO public.installments (
      order_id, customer_id, reseller_id, numero_cuota, total_cuotas,
      monto_usd, monto_bs, tasa_bs, fecha_vencimiento, estado, referencia
    ) VALUES (
      v_order_id,
      coalesce(v_assigned_cli, v_user_id),
      v_user_id,
      1, 1,
      v_precio,
      round(v_precio * v_bcv, 2),
      v_bcv,
      (current_date + interval '7 days')::date,
      'pendiente',
      '[CRÉDITO REVENDEDOR] Renovación ' || coalesce(v_cli_nom, 'Cliente') || ' - ' || v_srv_nom || ' ($' || v_precio || ' USD)'
    );

    RETURN jsonb_build_object(
      'success', true,
      'estado', 'entregado',
      'order_id', v_order_id,
      'nuevo_vencimiento', v_next_vence,
      'total_usd', v_precio,
      'mensaje', 'Suscripción renovada exitosamente a crédito (+30 días).'
    );

  ELSE -- Transferencia / Pago Móvil / Binance
    INSERT INTO orders (
      customer_id, vendedor_id, profile_id, product_id, metodo_id,
      total_usd, tasa_bs, total_bs, estado,
      referencia, vence, proximo_pago
    ) VALUES (
      coalesce(v_assigned_cli, v_user_id),
      CASE WHEN v_is_reseller THEN v_user_id ELSE v_prof.vendedor_id END,
      p_profile_id,
      v_prof.product_id,
      p_metodo_id,
      v_precio,
      v_bcv,
      round(v_precio * v_bcv, 2),
      'pendiente',
      '[RENOVACIÓN PENDIENTE] ' || coalesce(v_cli_nom, 'Cliente') || ' - ' || v_srv_nom || ' (Ref: ' || coalesce(p_referencia, 'N/A') || ')',
      v_next_vence,
      v_next_vence
    ) RETURNING id INTO v_order_id;

    RETURN jsonb_build_object(
      'success', true,
      'estado', 'pendiente',
      'order_id', v_order_id,
      'nuevo_vencimiento', v_next_vence,
      'total_usd', v_precio,
      'mensaje', 'Solicitud de renovación registrada. En proceso de verificación por Gregory.'
    );
  END IF;
END;
$function$;

-- Función: reportar_no_renovacion_perfil
CREATE OR REPLACE FUNCTION public.reportar_no_renovacion_perfil(p_profile_id uuid, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_caller_name text := 'Revendedor';
  v_prof profiles_inventory;
begin
  if v_user_id is null then raise exception 'No autenticado.'; end if;
  select coalesce(nombre, email, 'Revendedor') into v_caller_name from customers where id = v_user_id;
  select * into v_prof from profiles_inventory where id = p_profile_id for update;
  if not found then raise exception 'Perfil no encontrado.'; end if;

  update profiles_inventory set 
    no_renueva = true,
    no_renueva_reportado_at = now(),
    no_renueva_motivo = coalesce(p_motivo, 'El cliente no desea renovar'),
    no_renueva_por = coalesce(v_caller_name, 'Revendedor')
  where id = p_profile_id;

  update orders set no_renueva = true, no_renueva_reportado_at = now()
  where profile_id = p_profile_id and estado in ('entregado', 'pagado');

  return jsonb_build_object('ok', true, 'mensaje', 'Reportado con éxito.');
end;
$function$;

-- Función: reseller_set_cliente_final
CREATE OR REPLACE FUNCTION public.reseller_set_cliente_final(p_profile_id uuid, p_cliente_nombre text, p_cliente_telefono text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN public.reseller_update_client_info(p_profile_id, p_cliente_nombre, p_cliente_telefono);
END;
$function$;

-- Función: reseller_set_cliente_final
CREATE OR REPLACE FUNCTION public.reseller_set_cliente_final(p_profile_id uuid, p_cliente_nombre text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN public.reseller_update_client_info(p_profile_id, p_cliente_nombre, NULL);
END;
$function$;

-- Función: reseller_update_client_info
CREATE OR REPLACE FUNCTION public.reseller_update_client_info(p_profile_id uuid, p_cliente_nombre text, p_cliente_telefono text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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

  -- Verificar existencia del perfil y permisos del usuario
  IF v_is_adm THEN
    SELECT assigned_customer_id INTO v_assigned_cust
    FROM profiles_inventory
    WHERE id = p_profile_id;
    v_found := FOUND;
  ELSE
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
    v_found := FOUND;
  END IF;

  IF NOT v_found THEN
    RAISE EXCEPTION 'Perfil no encontrado o no tienes permisos sobre este perfil';
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
$function$;

-- Función: reveal_secret
CREATE OR REPLACE FUNCTION public.reveal_secret(p text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin if not is_admin() then raise exception 'No autorizado'; end if;
  return case when p like 'enc:%' then dec_text(p) else p end; end $function$;

-- Función: safe_dec_text
CREATE OR REPLACE FUNCTION public.safe_dec_text(t text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
$function$;

-- Función: save_my_push_subscription
CREATE OR REPLACE FUNCTION public.save_my_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_user_agent text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_user_id uuid := auth.uid();
begin
  if p_endpoint is null or p_p256dh is null or p_auth is null then
    return jsonb_build_object('success', false, 'error', 'Parámetros inválidos');
  end if;

  insert into public.push_subscriptions (endpoint, p256dh, auth, user_agent, user_id, created_at)
  values (p_endpoint, p_p256dh, p_auth, coalesce(p_user_agent, ''), v_user_id, now())
  on conflict (endpoint) do update
  set p256dh = excluded.p256dh,
      auth = excluded.auth,
      user_agent = excluded.user_agent,
      user_id = coalesce(excluded.user_id, push_subscriptions.user_id),
      created_at = now();

  return jsonb_build_object('success', true);
end;
$function$;

-- Función: stock
CREATE OR REPLACE FUNCTION public.stock()
 RETURNS TABLE(product_id uuid, disponibles bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform release_expired();
  return query
  select pi.product_id, count(*)
  from public.profiles_inventory pi
  join public.mother_accounts m on m.id = pi.mother_id
  where pi.estado = 'disponible'
    and pi.product_id is not null
    and coalesce(m.activa, true) is true
    and (m.vence is null or m.vence >= current_date)
  group by pi.product_id;
end $function$;

-- Función: switch_customer_role
CREATE OR REPLACE FUNCTION public.switch_customer_role(p_customer_id uuid, p_make_reseller boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  new_code text;
begin
  if not is_admin() then
    raise exception 'No autorizado';
  end if;
  new_code := get_next_customer_code(p_make_reseller);
  update customers set 
    es_revendedor = p_make_reseller,
    codigo_identificacion = new_code
  where id = p_customer_id;
  return new_code;
end;
$function$;

-- Función: transfer_order
CREATE OR REPLACE FUNCTION public.transfer_order(p_order uuid, p_new_profile uuid, p_motivo text, p_liberar_anterior boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_pid uuid;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select profile_id into v_pid from orders where id = p_order;
  if not found or v_pid is null then
    raise exception 'El pedido no tiene perfil asignado';
  end if;
  perform transfer_service(v_pid, p_new_profile, p_motivo, p_liberar_anterior, p_order, null, true);
end $function$;

-- Función: transfer_service
CREATE OR REPLACE FUNCTION public.transfer_service(p_from_profile uuid, p_to_profile uuid, p_motivo text DEFAULT ''::text, p_liberar_anterior boolean DEFAULT false, p_order uuid DEFAULT NULL::uuid, p_nueva_fecha_vence date DEFAULT NULL::date, p_permitir_otra_plataforma boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_from record;
  v_to record;
  v_from_mat record;
  v_to_mat record;
  v_order record;
  v_order_id uuid := p_order;
  v_customer_id uuid;
  v_vence date;
  v_inicia date;
  v_pass_revelada text := '';
begin
  if not is_admin() then
    raise exception 'No autorizado';
  end if;

  if p_from_profile = p_to_profile then
    raise exception 'El perfil destino no puede ser igual al de origen';
  end if;

  -- Perfil origen
  select * into v_from from profiles_inventory where id = p_from_profile for update;
  if not found then
    raise exception 'Perfil origen no encontrado';
  end if;
  select * into v_from_mat from mother_accounts where id = v_from.mother_id;

  -- Perfil destino
  select * into v_to from profiles_inventory where id = p_to_profile for update;
  if not found then
    raise exception 'Perfil destino no encontrado';
  end if;
  if v_to.estado <> 'disponible' then
    raise exception 'El perfil destino no esta disponible (estado: %)', v_to.estado;
  end if;
  select * into v_to_mat from mother_accounts where id = v_to.mother_id;

  -- Validar plataformas si no se permite cruce
  if not p_permitir_otra_plataforma and v_from_mat.plataforma is distinct from v_to_mat.plataforma then
    raise exception 'El traslado debe ser en la misma plataforma (% / %)', v_from_mat.plataforma, v_to_mat.plataforma;
  end if;

  -- Asociar pedido si existe
  if v_order_id is not null then
    select * into v_order from orders where id = v_order_id for update;
    if found then
      v_customer_id := v_order.customer_id;
    end if;
  else
    select * into v_order from orders
    where profile_id = p_from_profile and estado in ('entregado', 'pagado')
    order by created_at desc limit 1 for update;
    if found then
      v_order_id := v_order.id;
      v_customer_id := v_order.customer_id;
    end if;
  end if;

  -- Calcular fechas respetando la suscripción original
  v_inicia := coalesce(v_from.inicia, current_date);
  if p_nueva_fecha_vence is not null then
    v_vence := p_nueva_fecha_vence;
  elsif v_order.id is not null and v_order.vence is not null then
    v_vence := v_order.vence;
  else
    v_vence := coalesce(v_from.vence, (current_date + interval '30 days')::date);
  end if;

  -- 1. Perfil destino -> pasa a vendido
  update profiles_inventory set
    estado = 'vendido',
    inicia = v_inicia,
    vence = v_vence
  where id = p_to_profile;

  -- 2. Perfil origen -> suspendido o disponible según elección
  update profiles_inventory set
    estado = case when p_liberar_anterior then 'disponible' else 'suspendido' end,
    inicia = null,
    vence = null
  where id = p_from_profile;

  -- 3. Actualizar pedido enlazado si existe
  if v_order_id is not null then
    update orders set
      profile_id = p_to_profile,
      product_id = coalesce(v_to.product_id, orders.product_id),
      vence = v_vence
    where id = v_order_id;
  end if;

  -- 4. Registrar en historial de transfers
  insert into transfers (order_id, customer_id, from_profile, to_profile, motivo)
  values (v_order_id, v_customer_id, p_from_profile, p_to_profile, p_motivo);

  -- Revelar contraseña si está cifrada
  begin
    if v_to_mat.clave like 'enc:%' then
      v_pass_revelada := reveal_secret(v_to_mat.clave);
    else
      v_pass_revelada := v_to_mat.clave;
    end if;
  exception when others then
    v_pass_revelada := v_to_mat.clave;
  end;

  return jsonb_build_object(
    'success', true,
    'mensaje', 'Traslado completado con exito',
    'origen_plataforma', v_from_mat.plataforma,
    'origen_correo', v_from_mat.correo,
    'origen_perfil', v_from.nombre_perfil,
    'destino_plataforma', v_to_mat.plataforma,
    'destino_correo', v_to_mat.correo,
    'destino_clave', v_pass_revelada,
    'destino_perfil', v_to.nombre_perfil,
    'destino_pin', coalesce(v_to.pin, ''),
    'vence', v_vence,
    'order_id', v_order_id,
    'customer_id', v_customer_id
  );
end $function$;

-- Función: trg_auto_provision_zeny_card
CREATE OR REPLACE FUNCTION public.trg_auto_provision_zeny_card()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.es_revendedor is true then
    if not exists (select 1 from public.zeny_cards where customer_id = new.id) then
      insert into public.zeny_cards(
        customer_id,
        numero_tarjeta,
        nombre_titular,
        codigo_activacion,
        fecha_vencimiento,
        estado,
        descuento_porcentaje
      ) values (
        new.id,
        '4242 ' || lpad((floor(random() * 9000) + 1000)::int::text, 4, '0') || ' ' || lpad((floor(random() * 9000) + 1000)::int::text, 4, '0') || ' ' || lpad((floor(random() * 9000) + 1000)::int::text, 4, '0'),
        upper(coalesce(new.nombre, 'Revendedor Oficial')),
        lpad((floor(random() * 900) + 100)::int::text, 3, '0'),
        to_char(now() + interval '365 days', 'MM/YY'),
        'activa',
        5.00
      ) on conflict (customer_id) do update set estado = 'activa';
    else
      update public.zeny_cards set estado = 'activa' where customer_id = new.id and estado <> 'activa';
    end if;
  end if;
  return new;
end $function$;

-- Función: trg_notify_incident
CREATE OR REPLACE FUNCTION public.trg_notify_incident()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin perform notify_admin('incidencia', 'Nueva incidencia: ' || left(coalesce(new.asunto,'sin asunto'), 80)); return new; end $function$;

-- Función: trg_notify_order
CREATE OR REPLACE FUNCTION public.trg_notify_order()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare pn text;
begin
  if new.estado = 'pendiente' then
    select nombre into pn from products where id = new.product_id;
    perform notify_admin('order', 'Nuevo pedido pendiente: ' || coalesce(pn,'producto') || ' ($' || new.total_usd || ')');
  end if; return new;
end $function$;

-- Función: trg_notify_recarga
CREATE OR REPLACE FUNCTION public.trg_notify_recarga()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if new.tipo = 'recarga' and new.estado = 'pendiente' then perform notify_admin('recarga', 'Nueva recarga Zeny por aprobar: $' || new.monto); end if; return new;
end $function$;

-- Función: trg_sync_customer_role
CREATE OR REPLACE FUNCTION public.trg_sync_customer_role()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.es_revendedor is true then
    if new.codigo_identificacion is null or new.codigo_identificacion = '' or new.codigo_identificacion like 'CLT:%' then
      new.codigo_identificacion := public.get_next_customer_code(true);
    end if;
    if new.limite_credito is null or new.limite_credito = 0 then
      new.limite_credito := 30.00;
    end if;
    if new.nivel_credito is null or new.nivel_credito = '' then
      new.nivel_credito := 'Bronce';
    end if;
  elsif new.es_revendedor is false then
    if new.codigo_identificacion is null or new.codigo_identificacion = '' or new.codigo_identificacion like 'RVD:%' then
      new.codigo_identificacion := public.get_next_customer_code(false);
    end if;
  end if;
  return new;
end $function$;



-- [PASO 3]: Triggers Automáticos
-- ==============================================================================
-- 03_TRIGGERS.SQL
-- Emprendimiento Gregory Izquierdo - Suite de Instalación PostgreSQL Independiente
-- Triggers de Seguridad, Cifrado, Notificaciones y Automatizaciones
-- ==============================================================================

SET search_path = public, extensions;

DROP TRIGGER IF EXISTS t_auto_provision_zeny_card ON public.customers;
CREATE TRIGGER t_auto_provision_zeny_card
  AFTER INSERT ON public.customers
  FOR EACH ROW
  EXECUTE FUNCTION trg_auto_provision_zeny_card();

DROP TRIGGER IF EXISTS t_customers_guard ON public.customers;
CREATE TRIGGER t_customers_guard
  BEFORE UPDATE ON public.customers
  FOR EACH ROW
  EXECUTE FUNCTION customers_guard();

DROP TRIGGER IF EXISTS t_sync_customer_role ON public.customers;
CREATE TRIGGER t_sync_customer_role
  BEFORE UPDATE ON public.customers
  FOR EACH ROW
  EXECUTE FUNCTION trg_sync_customer_role();

DROP TRIGGER IF EXISTS trg_protect_customer_fields ON public.customers;
CREATE TRIGGER trg_protect_customer_fields
  BEFORE UPDATE ON public.customers
  FOR EACH ROW
  EXECUTE FUNCTION protect_customer_fields();

DROP TRIGGER IF EXISTS t_notify_incident ON public.incidents;
CREATE TRIGGER t_notify_incident
  AFTER INSERT ON public.incidents
  FOR EACH ROW
  EXECUTE FUNCTION trg_notify_incident();

DROP TRIGGER IF EXISTS t_enc_mother ON public.mother_accounts;
CREATE TRIGGER t_enc_mother
  BEFORE INSERT ON public.mother_accounts
  FOR EACH ROW
  EXECUTE FUNCTION enc_mother();

DROP TRIGGER IF EXISTS t_purchase_mother ON public.mother_accounts;
CREATE TRIGGER t_purchase_mother
  AFTER INSERT ON public.mother_accounts
  FOR EACH ROW
  EXECUTE FUNCTION purchase_from_mother();

DROP TRIGGER IF EXISTS t_notify_order ON public.orders;
CREATE TRIGGER t_notify_order
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION trg_notify_order();

DROP TRIGGER IF EXISTS t_orders_guard ON public.orders;
CREATE TRIGGER t_orders_guard
  BEFORE INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION orders_guard();

DROP TRIGGER IF EXISTS t_orders_sync_installments ON public.orders;
CREATE TRIGGER t_orders_sync_installments
  AFTER UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION orders_sync_installments();

DROP TRIGGER IF EXISTS trg_procesar_comision_socio_orden ON public.orders;
CREATE TRIGGER trg_procesar_comision_socio_orden
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION procesar_comision_socio_orden();

DROP TRIGGER IF EXISTS t_enc_profile ON public.profiles_inventory;
CREATE TRIGGER t_enc_profile
  BEFORE INSERT ON public.profiles_inventory
  FOR EACH ROW
  EXECUTE FUNCTION enc_profile();

DROP TRIGGER IF EXISTS t_ledger ON public.zeny_ledger;
CREATE TRIGGER t_ledger
  AFTER INSERT ON public.zeny_ledger
  FOR EACH ROW
  EXECUTE FUNCTION apply_ledger();

DROP TRIGGER IF EXISTS t_notify_recarga ON public.zeny_ledger;
CREATE TRIGGER t_notify_recarga
  AFTER INSERT ON public.zeny_ledger
  FOR EACH ROW
  EXECUTE FUNCTION trg_notify_recarga();



-- [PASO 4]: Seguridad RLS
-- ==============================================================================
-- 04_SEGURIDAD_RLS.SQL
-- Emprendimiento Gregory Izquierdo - Suite de Instalación PostgreSQL Independiente
-- Políticas de Row Level Security (RLS) y Control de Acceso
-- ==============================================================================

ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exchange_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.franchises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mother_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zeny_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zeny_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.faqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.google_integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recargas_puntos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recargas_abonos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mesa_cambio_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mesa_cambio_operaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.telegram_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.franchise_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.franchise_wallet_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_all" ON public.admins;
CREATE POLICY "admin_all" ON public.admins
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_manage" ON public.admins;
CREATE POLICY "admin_manage" ON public.admins
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_read" ON public.admins;
CREATE POLICY "admin_read" ON public.admins
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (true)
;

DROP POLICY IF EXISTS "admin_all" ON public.banners;
CREATE POLICY "admin_all" ON public.banners
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_ban" ON public.banners;
CREATE POLICY "pub_ban" ON public.banners
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING ((activo AND ((inicio IS NULL) OR (inicio <= CURRENT_DATE)) AND ((fin IS NULL) OR (fin >= CURRENT_DATE))))
;

DROP POLICY IF EXISTS "admin_all" ON public.bot_commands;
CREATE POLICY "admin_all" ON public.bot_commands
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.categories;
CREATE POLICY "admin_all" ON public.categories
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_cat" ON public.categories;
CREATE POLICY "pub_cat" ON public.categories
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (activo)
;

DROP POLICY IF EXISTS "admin_all" ON public.customers;
CREATE POLICY "admin_all" ON public.customers
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_cust" ON public.customers;
CREATE POLICY "me_cust" ON public.customers
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "me_cust_upd" ON public.customers;
CREATE POLICY "me_cust_upd" ON public.customers
  AS PERMISSIVE
  FOR UPDATE
  TO authenticated
  USING ((id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "admin_all" ON public.exchange_rates;
CREATE POLICY "admin_all" ON public.exchange_rates
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_rates" ON public.exchange_rates;
CREATE POLICY "pub_rates" ON public.exchange_rates
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (true)
;

DROP POLICY IF EXISTS "admin_all" ON public.expenses;
CREATE POLICY "admin_all" ON public.expenses
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.faqs;
CREATE POLICY "admin_all" ON public.faqs
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_faq" ON public.faqs;
CREATE POLICY "pub_faq" ON public.faqs
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (activo)
;

DROP POLICY IF EXISTS "fq_app_anon_insert" ON public.franchise_applications;
CREATE POLICY "fq_app_anon_insert" ON public.franchise_applications
  AS PERMISSIVE
  FOR INSERT
  TO anon
  WITH CHECK (true)
;

DROP POLICY IF EXISTS "fq_app_auth_all" ON public.franchise_applications;
CREATE POLICY "fq_app_auth_all" ON public.franchise_applications
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true)
;

DROP POLICY IF EXISTS "fq_wallet_anon_select" ON public.franchise_wallet_ledger;
CREATE POLICY "fq_wallet_anon_select" ON public.franchise_wallet_ledger
  AS PERMISSIVE
  FOR SELECT
  TO anon
  USING (true)
;

DROP POLICY IF EXISTS "fq_wallet_auth_all" ON public.franchise_wallet_ledger;
CREATE POLICY "fq_wallet_auth_all" ON public.franchise_wallet_ledger
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true)
;

DROP POLICY IF EXISTS "franchises_admin" ON public.franchises;
CREATE POLICY "franchises_admin" ON public.franchises
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "franchises_admin_full" ON public.franchises;
CREATE POLICY "franchises_admin_full" ON public.franchises
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true)
;

DROP POLICY IF EXISTS "franchises_public_select" ON public.franchises;
CREATE POLICY "franchises_public_select" ON public.franchises
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (true)
;

DROP POLICY IF EXISTS "admin_all" ON public.google_integrations;
CREATE POLICY "admin_all" ON public.google_integrations
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.incidents;
CREATE POLICY "admin_all" ON public.incidents
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_inc_ins" ON public.incidents;
CREATE POLICY "me_inc_ins" ON public.incidents
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (((customer_id = ( SELECT auth.uid() AS uid)) AND (estado = 'abierta'::text)))
;

DROP POLICY IF EXISTS "me_inc_sel" ON public.incidents;
CREATE POLICY "me_inc_sel" ON public.incidents
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "installments_admin_all" ON public.installments;
CREATE POLICY "installments_admin_all" ON public.installments
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "installments_user_select" ON public.installments;
CREATE POLICY "installments_user_select" ON public.installments
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (((customer_id = auth.uid()) OR (reseller_id = auth.uid()) OR is_admin()))
;

DROP POLICY IF EXISTS "admin_all" ON public.invoices;
CREATE POLICY "admin_all" ON public.invoices
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_inv" ON public.invoices;
CREATE POLICY "me_inv" ON public.invoices
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "admin_all" ON public.login_log;
CREATE POLICY "admin_all" ON public.login_log
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_log" ON public.login_log;
CREATE POLICY "me_log" ON public.login_log
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "mesa_caja_admin_all" ON public.mesa_cambio_caja;
CREATE POLICY "mesa_caja_admin_all" ON public.mesa_cambio_caja
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "mesa_cambio_admin_all" ON public.mesa_cambio_operaciones;
CREATE POLICY "mesa_cambio_admin_all" ON public.mesa_cambio_operaciones
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "mesa_cambio_customer_insert" ON public.mesa_cambio_operaciones;
CREATE POLICY "mesa_cambio_customer_insert" ON public.mesa_cambio_operaciones
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK ((((customer_id = ( SELECT auth.uid() AS uid)) AND (estado = 'pendiente'::text) AND (notas_admin IS NULL) AND (enviado_at IS NULL)) OR ( SELECT is_admin() AS is_admin)))
;

DROP POLICY IF EXISTS "mesa_cambio_customer_select" ON public.mesa_cambio_operaciones;
CREATE POLICY "mesa_cambio_customer_select" ON public.mesa_cambio_operaciones
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (((customer_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin)))
;

DROP POLICY IF EXISTS "admin_all" ON public.mother_accounts;
CREATE POLICY "admin_all" ON public.mother_accounts
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.orders;
CREATE POLICY "admin_all" ON public.orders
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_orders" ON public.orders;
CREATE POLICY "me_orders" ON public.orders
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "partner_commissions_admin_all" ON public.partner_commissions;
CREATE POLICY "partner_commissions_admin_all" ON public.partner_commissions
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "partner_commissions_reseller_select" ON public.partner_commissions;
CREATE POLICY "partner_commissions_reseller_select" ON public.partner_commissions
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((vendedor_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "admin_all" ON public.payment_methods;
CREATE POLICY "admin_all" ON public.payment_methods
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pm_autenticados" ON public.payment_methods;
CREATE POLICY "pm_autenticados" ON public.payment_methods
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (activo)
;

DROP POLICY IF EXISTS "admin_all" ON public.products;
CREATE POLICY "admin_all" ON public.products
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_prod" ON public.products;
CREATE POLICY "pub_prod" ON public.products
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (activo)
;

DROP POLICY IF EXISTS "admin_all" ON public.profiles_inventory;
CREATE POLICY "admin_all" ON public.profiles_inventory
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.purchases;
CREATE POLICY "admin_all" ON public.purchases
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_all" ON public.push_subscriptions;
CREATE POLICY "admin_all" ON public.push_subscriptions
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "recargas_abonos_admin" ON public.recargas_abonos;
CREATE POLICY "recargas_abonos_admin" ON public.recargas_abonos
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "recargas_puntos_admin" ON public.recargas_puntos;
CREATE POLICY "recargas_puntos_admin" ON public.recargas_puntos
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "ref_admin" ON public.refunds;
CREATE POLICY "ref_admin" ON public.refunds
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ref_me" ON public.refunds;
CREATE POLICY "ref_me" ON public.refunds
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "admin_all" ON public.settings;
CREATE POLICY "admin_all" ON public.settings
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "admin_settings" ON public.settings;
CREATE POLICY "admin_settings" ON public.settings
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "pub_settings" ON public.settings;
CREATE POLICY "pub_settings" ON public.settings
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING ((key = ANY (ARRAY['negocio'::text, 'zeny'::text, 'reserva'::text, 'app'::text, 'plantillas_mensajes'::text, 'niveles_beneficios'::text, 'mesa_cambio_config'::text])))
;

DROP POLICY IF EXISTS "telegram_sessions_service_role" ON public.telegram_sessions;
CREATE POLICY "telegram_sessions_service_role" ON public.telegram_sessions
  AS PERMISSIVE
  FOR ALL
  TO public
  USING ((auth.role() = 'service_role'::text))
;

DROP POLICY IF EXISTS "tr_admin_all" ON public.transfers;
CREATE POLICY "tr_admin_all" ON public.transfers
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "zeny_cards_admin_all" ON public.zeny_cards;
CREATE POLICY "zeny_cards_admin_all" ON public.zeny_cards
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "zeny_cards_user_select" ON public.zeny_cards;
CREATE POLICY "zeny_cards_user_select" ON public.zeny_cards
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (((customer_id = ( SELECT auth.uid() AS uid)) OR is_admin()))
;

DROP POLICY IF EXISTS "admin_all" ON public.zeny_ledger;
CREATE POLICY "admin_all" ON public.zeny_ledger
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "me_ledger" ON public.zeny_ledger;
CREATE POLICY "me_ledger" ON public.zeny_ledger
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((customer_id = ( SELECT auth.uid() AS uid)))
;

DROP POLICY IF EXISTS "me_recarga" ON public.zeny_ledger;
CREATE POLICY "me_recarga" ON public.zeny_ledger
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (((customer_id = ( SELECT auth.uid() AS uid)) AND (tipo = 'recarga'::text) AND (estado = 'pendiente'::text) AND (monto > (0)::numeric)))
;



-- [PASO 5]: Catálogo y Datos Semilla
-- ==============================================================================
-- 05_DATOS_SEMILLA_INICIALES.SQL
-- Emprendimiento Gregory Izquierdo - Suite de Instalación PostgreSQL Independiente
-- Catálogo de Categorías, Productos Oficiales, Configuración, Métodos de Pago y Admin
-- ==============================================================================

-- 1. Categorías Oficiales
INSERT INTO public.categories (id, nombre, orden)
VALUES ('e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Perfiles & Pantallas', 1)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, orden = EXCLUDED.orden;
INSERT INTO public.categories (id, nombre, orden)
VALUES ('e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'Cuentas Completas', 2)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, orden = EXCLUDED.orden;
INSERT INTO public.categories (id, nombre, orden)
VALUES ('e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'Combos Especiales', 3)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, orden = EXCLUDED.orden;
INSERT INTO public.categories (id, nombre, orden)
VALUES ('e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'Música & Productividad', 4)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, orden = EXCLUDED.orden;

-- 2. Métodos de Pago Oficiales
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('69e2be6c-0b95-4cb7-9e03-8f45c85b6e69', 'Pago Móvil (BNC)', 'pago_movil', '{"Banco":"BNC (Banco Nacional de Crédito)","Código":"0191","Documento":"V 18931731","Teléfono":"04242809333"}'::jsonb, 1, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('e2762451-fc48-4457-9318-42389791b4ae', 'Binance (USDT)', 'binance', '{"Correo":"gregoryrodriguez2021@gmail.com","ID Binance":"393089335"}'::jsonb, 2, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('e1919cec-6687-4e04-a719-b8f3a4666db4', 'Transferencia Internacional (Ecuador)', 'transferencia_internacional', '{"Banco":"Guayaquil","Email":"evertizquierdo91@gmail.com","Titular":"Evert Izquierdo","Documento":"2451655498","N° Cuenta":"0042286503","Tipo de Cuenta":"Ahorros"}'::jsonb, 3, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('445586ab-1bec-4692-9e8b-3f7f2106303f', 'ApoloPay', 'apolopay', '{"Correo":"gregoryrodriguez2021@gmail.com","ID Usuario":"7604"}'::jsonb, 4, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('bb6d9100-a066-4528-88d7-f0f5e3149515', 'Zinli', 'zinli', '{"Correo":"gregoryrodriguez2021@gmail.com","Teléfono":"04242809333"}'::jsonb, 5, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('2bc8ae59-e88f-4be0-b73d-8211ebc97ebf', 'Wally', 'wally', '{"Correo":"gregoryrodriguez2021@gmail.com","Teléfono":"04242809333"}'::jsonb, 6, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('1fde2ff7-8e4e-405d-b86d-e0e8de019288', 'Uglycash', 'uglycash', '{"Usuario":"gair1990"}'::jsonb, 7, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('69409bfc-511d-441e-8012-d30753a255eb', 'Transferencia EEUU (Lead Bank)', 'transferencia_eeuu', '{"Banco":"Lead Bank","Routing":"101019644","Titular":"Gregori Antonio Izquierdo Rodriguez","N° Cuenta":"210345561126","Tipo de Cuenta":"Corriente","Dirección Banco":"1801 Main St., Kansas City. MO 64108"}'::jsonb, 8, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('c6517bb7-8aa7-4c04-a156-4c6c8ee32c9d', 'Pago Móvil Jurídico', 'pago_movil_juridico', '{"Banco":"Venezolano de Crédito","Código":"0104","Documento":"J 506393794","Teléfono":"04242809333"}'::jsonb, 9, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;

-- 3. Parámetros de Configuración del Sistema (settings)
INSERT INTO public.settings (key, value)
VALUES ('zeny', '{"moneda":"ZenyPoints","nombre":"Zeny","valor_usd":1}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('reserva', '{"minutos":60}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('bot', '{"username":"Diego1asistente_bot"}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('mesa_cambio_config', '{"banco":"BNC (0191)","activo":false,"titular":"Gregory Izquierdo","max_usdt":10,"min_usdt":2,"telefono":"04242809333","documento":"18931731","metodo_pago":"Pago Móvil (BNC)","tasa_usdt_bs":1050.52,"mensaje_aviso":"⚠️ IMPORTANTE: Por favor verifica cuidadosamente tu ID de Binance Pay o Correo electrónico antes de enviar la solicitud. No nos hacemos responsables ni realizaremos reembolsos por mala identificación de sus datos.","fondo_caja_usdt":3,"tasa_adquisicion_bs":1004.43}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('negocio', '{"rif":"J-50639379-4","correo":"emprendimientogregoryizquierdo@gmail.com","nombre":"Emprendimiento Gregory Izquierdo","telefono":"+584241983648"}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('app', '{"apk_url":"https://github.com/gregoryizquierdo1990/tienda-gregory/releases/download/v1.0.0/Emprendimiento-Gregory-Izquierdo.apk"}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('notificaciones', '{"telegram_chat_id":"7154250409"}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('plantillas_mensajes', '{"abono_zeny":{"id":"abono_zeny","tags":["cliente","monto_usd","monto_bs","referencia","nuevo_balance","portal_url","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 💳✨\nTu abono de saldo Zeny ha sido verificado y acreditado exitosamente en tu cuenta de {negocio}.\n\n💵 Monto Acreditado: ${monto_usd} USD (Bs. {monto_bs})\n🔢 Referencia: {referencia}\n💰 Nuevo Balance Zeny: ${nuevo_balance} ZP\n\nTu saldo está disponible para compras y renovaciones instantáneas con 0 esperas bancarias en:\n🌐 {portal_url}\n\n¡Muchas gracias por recargar con nosotros! 🚀","titulo":"💳 Confirmación de Abono / Recarga Saldo Zeny","descripcion":"Notificación de saldo acreditado a la Tarjeta Digital Zeny o billetera del usuario."},"cobro_cuota":{"id":"cobro_cuota","tags":["cliente","negocio","producto","cuota","total_cuotas","monto_usd","monto_bs","tasa_bcv","fecha_vencimiento"],"canal":"whatsapp","cuerpo":"Hola {cliente}, \nun cordial saludo de\n {negocio} 👋\n\nTe recordamos que tienes una cuota pendiente de tu servicio financiado:\n\n📦 Servicio: {producto}\n💳 Cuota: #{cuota} de {total_cuotas}\n💵 Monto en USD: ${monto_usd} USD\n🇻🇪 Monto en Bs: Bs. {monto_bs} (Tasa BCV {tasa_bcv})\n📅 Fecha de vencimiento: {fecha_vencimiento}\n\nPor favor envíanos el comprobante una vez realizada la transferencia. ¡Muchas gracias por tu puntualidad!","titulo":"Cobro de Cuota Pendiente (BNPL)","descripcion":"Recordatorio enviado al cliente con los detalles de su cuota financiada por pagar."},"factura_lista":{"id":"factura_lista","tags":["cliente","numero_factura","fecha","total_usd","total_bs","tasa_bcv","portal_url","negocio","rif"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 📄 Tu factura digital en {negocio} ya está emitida y disponible.\n\n🧾 Documento: {numero_factura}\n📅 Fecha de Emisión: {fecha}\n💵 Total Facturado: ${total_usd} USD (Bs. {total_bs})\n🇻🇪 Tasa Oficial BCV: Bs. {tasa_bcv}\n🏢 RIF Emisor: {rif}\n\nPuedes consultar, descargar o imprimir tu factura oficial ingresando directamente a tu portal web:\n🌐 {portal_url}\n\n¡Gracias por tu pago puntual y por elegirnos! ⭐","titulo":"📄 Factura Digital Emitida y Lista","descripcion":"Aviso al cliente de que su factura oficial ya está generada y lista para descargar en el portal."},"recarga_gaming":{"id":"recarga_gaming","tags":["cliente","producto","player_id","nickname","monto_usd","codigo_id","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🎮✨\nTu recarga de {producto} ha sido PROCESADA CON ÉXITO.\n\n📌 Juego / Servicio: {producto}\n🆔 ID de Jugador: {player_id}\n👤 Nickname: {nickname}\n💵 Monto: ${monto_usd} USD\n🧾 Pedido ID: {codigo_id}\n\n⚠️ Por favor abre o reinicia el juego para verificar tus activos. ¡Gracias por confiar en {negocio}! 🔥","titulo":"Entrega de Recarga Gaming / Activos","descripcion":"Enviado al cliente cuando su recarga de juego (Free Fire, Roblox, etc.) ha sido procesada."},"recibo_factura":{"id":"recibo_factura","tags":["cliente","negocio","numero_factura","fecha","total_usd","total_bs","tasa_bcv"],"canal":"whatsapp","cuerpo":"Hola {cliente}! \nAdjuntamos tu comprobante digital de compra en {negocio} 📄:\n\n🧾 Documento: {numero_factura}\n📅 Fecha: {fecha}\n💵 Total: ${total_usd} USD (Bs. {total_bs})\nTasa: {tasa_bcv}\n\nPuedes descargar o imprimir tu factura oficial directamente desde tu portal. ¡Gracias por confiar en nosotros!","titulo":"Envío de Factura Digital / Recibo","descripcion":"Comprobante formal de pago con datos fiscales, tasa BCV y desglose de items."},"entrega_credito":{"id":"entrega_credito","tags":["cliente","negocio","producto","monto_usd","fecha_vence_credito","dias_credito"],"canal":"whatsapp","cuerpo":"Hola {cliente}! \nTe saludamos de {negocio} ✨\nTu servicio de {producto} ha sido activado/renovado a CRÉDITO por 30 días de disfrute.\n\n💵 Monto pendiente: ${monto_usd} USD\n📅 Fecha límite para el pago: {fecha_vence_credito} ({dias_credito} días)\n💳 Recuerda que puedes pagar con Pago Móvil o con tu Tarjeta Digital Zeny.\n\n¡Muchas gracias por tu preferencia y confianza continua! ⭐","titulo":"Activación de Servicio a Crédito","descripcion":"Notificación cuando se entrega o renueva un servicio a crédito con fecha límite de pago."},"entrega_servicio":{"id":"entrega_servicio","tags":["cliente","numero_factura","negocio","producto","correo","clave","perfil","pin","vence","garantia","codigo_id"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! \n🎉 Gracias por tu compra {numero_factura} en {negocio}.\nAquí tienes los datos de acceso para tu servicio:\n\n📌 Servicio: {producto}\n📧 Correo: {correo}\n🔑 Clave: {clave}\n👤 Perfil: {perfil}\n🔒 PIN: {pin}\n⏳ Vence el: {vence}\n🛡️ Garantía: {garantia} días\n\n⚠️ Instrucciones:\n• No modificar correo ni perfil asignado.\n• Ante dudas indícanos tu ID {codigo_id}.\n\n¡Que disfrutes tu servicio! ⭐","titulo":"Entrega de Credenciales del Pedido","descripcion":"Enviado al cliente cuando su pedido es conciliado y se entregan las credenciales de acceso."},"abono_recargas247":{"id":"abono_recargas247","tags":["titular","nombre_punto","usuario_247","monto_usd","monto_bs","referencia","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {titular}! ✅\nTu abono de saldo ha sido verificado y acreditado en tu usuario {usuario_247} de Recargas247.\n\n🏪 Punto de Venta: {nombre_punto}\n💵 Monto Acreditado: ${monto_usd} USD (Bs. {monto_bs})\n🔢 Referencia: {referencia}\n\nTu saldo ya se encuentra disponible para emitir recargas a tus clientes. ¡Éxito en las ventas de hoy! 🚀","titulo":"Confirmación de Abono Punto Recargas247","descripcion":"Enviado al revendedor cuando Gregory le concilia y acredita saldo en Recargas247."},"aviso_vencimiento":{"id":"aviso_vencimiento","tags":["cliente","producto","fecha_vence","monto_usd","portal_url"],"canal":"whatsapp","cuerpo":"Hola {cliente}! ⏰ \nTu servicio de {producto} está próximo a vencer el {fecha_vence}.\n\nPara mantener tu perfil activo y no perder tus pantallas guardadas, puedes renovar directamente desde tu portal con saldo Zeny o confirmarnos con tu pago a traves de la opcion en mi portal de tu usuario u por acá:\n💵 Monto de renovación: ${monto_usd} USD\n🌐 Tu Portal de Cliente: {portal_url}\n\n¿Deseas renovar para este próximo período? Quedamos a tu orden.","titulo":"Aviso Previo de Vencimiento de Suscripción","descripcion":"Mensaje preventivo antes del vencimiento para ofrecer la renovación inmediata."},"bienvenida_tarjeta":{"id":"bienvenida_tarjeta","tags":["cliente","codigo_id","numero_tarjeta","codigo_activacion","portal_url","negocio"],"canal":"whatsapp","cuerpo":"¡Bienvenido a {negocio}, {cliente}! 🌟\nTu cuenta ha sido creada exitosamente en nuestra plataforma.\n\n🆔 Tu Identificador oficial: {codigo_id}\n💳 Tarjeta Digital Zeny: {numero_tarjeta}\n🔐 Código de Activación: {codigo_activacion}\n🌐 Portal Web: {portal_url}\n\nTu Tarjeta Zeny te permite comprar al instante sin esperas bancarias. ¡Estamos listos para atenderte!","titulo":"Bienvenida y Tarjeta Zeny Emitida","descripcion":"Enviado tras el registro para entregar el ID único, tarjeta digital y código de activación."},"recarga_telefonica":{"id":"recarga_telefonica","tags":["cliente","producto","operadora","telefono_recarga","monto_usd","monto_bs","codigo_id","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 📱⚡\nTu recarga telefónica de {producto} ha sido ACREDITADA EXITOSAMENTE.\n\n📌 Operadora: {operadora}\n📞 Teléfono: {telefono_recarga}\n💵 Monto: ${monto_usd} USD (Bs. {monto_bs})\n🧾 Pedido ID: {codigo_id}\n\n¡Gracias por recargar con {negocio}! Quedamos a tu orden para tus próximas recargas. ✨","titulo":"Entrega de Recarga Telefónica","descripcion":"Enviado al cliente cuando su recarga de saldo móvil ha sido abonada."},"renovacion_exitosa":{"id":"renovacion_exitosa","tags":["cliente","producto","vence","monto_usd","monto_bs","tasa_bcv","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🔄✨\nTu renovación para {producto} ha sido PROCESADA CON ÉXITO en {negocio}.\n\n📌 Servicio: {producto}\n📅 Nuevo Vencimiento (+30 días): {vence}\n💵 Monto Pagado: ${monto_usd} USD (Bs. {monto_bs})\n🇻🇪 Tasa BCV: {tasa_bcv}\n\nTu perfil continúa activo sin interrupciones ni cambios de pantalla. ¡Muchas gracias por tu preferencia y confianza continua! ⭐🍿","titulo":"🔄 Renovación Exitosa de Suscripción (+30 días)","descripcion":"Confirmación enviada al cliente cuando renueva su servicio para el próximo período."},"activacion_servicio":{"id":"activacion_servicio","tags":["cliente","producto","correo","clave","perfil","pin","vence","garantia","codigo_id","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🎉 Tu servicio ha sido ACTIVADO EXITOSAMENTE en {negocio}.\nAquí tienes los datos de acceso para tu pantalla:\n\n📌 Servicio: {producto}\n📧 Correo: {correo}\n🔑 Clave: {clave}\n👤 Perfil Asignado: {perfil}\n🔒 PIN de Acceso: {pin}\n⏳ Vence el: {vence}\n🛡️ Garantía: {garantia} días continuos\n\n⚠️ Reglas de uso importantes:\n• Usar ÚNICAMENTE tu perfil asignado ({perfil}).\n• No modificar correo, clave ni los perfiles de otros usuarios.\n• Ante cualquier consulta, indícanos tu ID oficial {codigo_id}.\n\n¡Que disfrutes al máximo tu entretenimiento! ⭐🍿","titulo":"🚀 Activación y Entrega Oficial de Credenciales","descripcion":"Bienvenida al cliente con sus credenciales de acceso, perfil, PIN de 4 dígitos y normas de uso."},"devolucion_garantia":{"id":"devolucion_garantia","tags":["cliente","producto","monto_usd","motivo","destino","codigo_id","negocio"],"canal":"whatsapp","cuerpo":"Hola {cliente}, un cordial saludo de {negocio} 🛡️\nTe informamos que tu solicitud de garantía para el servicio de {producto} ha sido APROBADA y procesada con éxito.\n\n💵 Monto Reintegrado: ${monto_usd} USD\n💼 Destino del Reintegro: {destino}\n📝 Motivo / Detalle: {motivo}\n🧾 ID de Registro: {codigo_id}\n\nLamentamos cualquier inconveniente presentado con el proveedor. Nuestro compromiso es garantizar siempre tu inversión y satisfacción. Quedamos a tu total disposición. 🤝","titulo":"🛡️ Reembolso o Devolución por Garantía / Pantalla","descripcion":"Enviado al cliente cuando se procesa una devolución o reposición de saldo ante una incidencia."},"reposicion_pantalla":{"id":"reposicion_pantalla","tags":["cliente","producto","correo","clave","perfil","pin","vence","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🔀 Hemos activado tu REPOSICIÓN POR GARANTÍA para tu servicio de {producto}.\nAquí tienes tus nuevos datos de acceso funcionales:\n\n📌 Servicio: {producto}\n📧 Nuevo Correo: {correo}\n🔑 Nueva Clave: {clave}\n👤 Perfil: {perfil}\n🔒 PIN: {pin}\n⏳ Vigencia garantizada hasta: {vence}\n\nDisculpa la interrupción ocasionada por la plataforma original. Ya puedes disfrutar de tu servicio con total normalidad. ¡Cualquier duda estamos a la orden! 🍿","titulo":"🔀 Reposición Inmediata de Pantalla por Garantía","descripcion":"Entrega de nuevas credenciales de reemplazo por caída de cuenta o pantalla caída."},"aviso_vencimiento_hoy":{"id":"aviso_vencimiento_hoy","tags":["cliente","producto","vence","monto_usd","monto_bs","portal_url","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! ⏰ Te recordamos de {negocio} que tu servicio de {producto} tiene fecha de cobro y vencimiento el día de HOY ({vence}).\n\n💵 Monto de renovación: ${monto_usd} USD (Bs. {monto_bs})\n🌐 Tu Portal Web: {portal_url}\n\n¿Deseas renovar tu pantalla para mantenerla activa este próximo mes? Por favor confírmanos por esta vía para asegurar tu cupo sin interrupciones. ¡Quedamos atentos a tu respuesta! 👋","titulo":"⏰ Cobro y Vencimiento del Día (Hoy)","descripcion":"Recordatorio urgente enviado el día exacto de vencimiento para gestionar la renovación o liberación."},"abono_usdt_mesa_cambio":{"id":"abono_usdt_mesa_cambio","tags":["cliente","tipo_operacion","monto_usdt","tasa_cambio","monto_bs","referencia","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 💱⚡\nTu operación en la Mesa de Cambio USDT de {negocio} ha sido PROCESADA Y LIQUIDADA CON ÉXITO.\n\n📊 Operación: {tipo_operacion}\n🪙 Monto USDT: {monto_usdt} USDT\n📈 Tasa de Cambio: Bs. {tasa_cambio} por USDT\n🇻🇪 Total en Bolívares: Bs. {monto_bs}\n🔢 Referencia Bancaria / Binance: {referencia}\n\nFondos entregados y verificados. ¡Gracias por confiar en nuestra mesa de cambio segura y rápida! 🤝💎","titulo":"💱 Confirmación de Operación Mesa de Cambio USDT","descripcion":"Enviado al cliente cuando su operación de USDT (Binance Pay / TRC20 / BEP20) ha sido liquidada."},"datos_limpios_revendedor":{"id":"datos_limpios_revendedor","tags":["servicio","correo","clave","perfil","pin","vence","vendedor"],"canal":"whatsapp","cuerpo":"*{servicio}*\nCorreo: {correo}\nClave: {clave}\nPerfil: {perfil}\nPIN: {pin}\nVence: {vence}\nVendedor: {vendedor}\n\n⚠️ Cuida tus accesos y disfruta tu servicio. Garantía activa durante todo el período.","titulo":"Formato Reenvío de Revendedor a Cliente Final","descripcion":"Estructura limpia sin marcas que el revendedor copia para entregar a sus propios clientes."},"notificacion_telegram_bot":{"id":"notificacion_telegram_bot","tags":["cliente","servicio","monto_usd","estado","negocio"],"canal":"telegram","cuerpo":"🤖 *Notificación de {negocio}*\n\nHola {cliente}, tu solicitud para *{servicio}* se encuentra en estado: *{estado}*.\nMonto: ${monto_usd} USD.\n\nAccede a tu portal para ver tus accesos actualizados.","titulo":"Aviso del Bot de Telegram al Cliente","descripcion":"Mensaje formateado enviado por el bot de Telegram ante pedidos o recargas."},"invitacion_registro_portal":{"id":"invitacion_registro_portal","tags":["cliente","portal_url","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 👋 Como cliente de {negocio}, tienes a tu disposición nuestro portal web exclusivo:\n🌐 {portal_url}\n\nEn tu portal podrás:\n✅ Ver tus pantallas activas, PIN y fechas de vencimiento 24/7.\n✅ Descargar tus facturas digitales y comprobantes de compra.\n✅ Usar tu Tarjeta Digital Zeny para renovar en 1 clic.\n\nTu usuario es este mismo número de WhatsApp o tu correo. ¡Cualquier duda estamos a tu disposición! 🤝✨","titulo":"🌐 Invitación y Acceso al Portal de Clientes","descripcion":"Invita a un cliente que compró por WhatsApp a registrarse o entrar a su portal para ver sus servicios y tarjeta."},"entrega_directa_credenciales":{"id":"entrega_directa_credenciales","tags":["cliente","producto","correo","clave","perfil","pin","vence","garantia","portal_url","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🎉 Aquí tienes tus accesos oficiales para disfrutar de {producto} activados por {negocio}:\n\n📺 *Servicio:* {producto}\n✉️ *Correo:* {correo}\n🔑 *Clave:* {clave}\n👤 *Perfil:* {perfil}\n🔒 *PIN:* {pin}\n📅 *Vencimiento:* {vence} (+30 días)\n🛡️ *Garantía:* {garantia} días continuos\n\n⚠️ *Recomendaciones importantes:*\n• Ingresa únicamente a tu perfil asignado ({perfil}).\n• No modificar correo, clave ni otros perfiles.\n• Puedes consultar tu historial y facturas en tu portal: {portal_url}\n\n¡Que disfrutes tu programación favorita! Si tienes alguna duda, estamos a la orden por aquí. ⭐🎬","titulo":"🔑 Entrega de Accesos por Pago Directo","descripcion":"Entrega limpia de usuario, clave, perfil y PIN cuando un cliente paga fuera de la plataforma."},"datos_de_pago_cliente_directo":{"id":"datos_de_pago_cliente_directo","tags":["cliente","producto","monto_usd","monto_bs","tasa_bcv","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 👋 Con gusto te facilitamos los datos oficiales de pago para tu servicio {producto} en {negocio}:\n\n💵 *Total a transferir:* ${monto_usd} USD\n🇻🇪 *En Bolívares:* Bs. {monto_bs} (Tasa oficial BCV: {tasa_bcv})\n\n📌 *Opción 1: Pago Móvil (BNC)*\n• Banco: BNC (0191)\n• Teléfono: 04242809333\n• Cédula: V-18931731\n\n📌 *Opción 2: Binance Pay (USDT)*\n• Pay ID: 393089335\n• Correo: gregoryrodriguez2021@gmail.com\n\nAl realizar el pago, envíanos por favor la captura o el número de referencia para activar tu servicio al instante. ¡Muchas gracias! ✨","titulo":"💳 Envío de Cuentas de Pago a Cliente Directo","descripcion":"Plantilla rápida con todos los métodos de pago (Pago Móvil, Binance, etc.) para pasarle a un cliente por WhatsApp."},"pago_recibido_fuera_plataforma":{"id":"pago_recibido_fuera_plataforma","tags":["cliente","negocio","producto","monto_usd","monto_bs","tasa_bcv","referencia"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 👋\nConfirmamos la recepción de tu pago con total éxito en {negocio} ✅\n\n📌 Concepto / Servicio: {producto}\n💵 Monto: ${monto_usd} USD (Bs. {monto_bs})\n🇻🇪 Tasa BCV: Bs. {tasa_bcv}\n🔢 Referencia: {referencia}\n\nEstamos procesando tu solicitud de inmediato. En breves minutos te enviaremos tus datos de acceso oficiales. ¡Muchas gracias por tu compra y confianza! ⭐🍿","titulo":"💵 Confirmación de Pago Recibido (Venta Directa / WhatsApp)","descripcion":"Enviado al cliente cuando transfiere por Pago Móvil, Binance o Efectivo directamente a Gregory fuera de la web."},"solicitud_datos_membresia_personal":{"id":"solicitud_datos_membresia_personal","tags":["cliente","producto","monto_usd","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 👋 Tu pago de ${monto_usd} USD para {producto} ha sido confirmado con éxito en {negocio} ✅\n\nPara proceder con la activación personalizada de tu membresía:\n👉 *Por favor indícanos el correo electrónico* al que deseas vincular el servicio (o al que te enviaremos la invitación de activación).\n\nUna vez nos envíes tu correo, activaremos tu cuenta en un lapso estimado de 15 a 30 minutos. ¡Quedamos atentos a tu respuesta! 🚀","titulo":"✉️ Solicitud de Correo para Membresía a Pedido","descripcion":"Para membresías bajo demanda (Spotify Familiar, Canva Pro, YouTube Premium, etc.) que se activan al correo personal del cliente."},"confirmacion_renovacion_fuera_plataforma":{"id":"confirmacion_renovacion_fuera_plataforma","tags":["cliente","producto","perfil","vence","monto_usd","referencia","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🔄✨\nConfirmamos tu pago directo para la RENOVACIÓN de tu servicio en {negocio}.\n\n📺 *Servicio:* {producto}\n👤 *Perfil:* {perfil}\n📅 *Nuevo Vencimiento (+30 días):* {vence}\n💵 *Monto:* ${monto_usd} USD\n🔢 *Referencia:* {referencia}\n\n✅ Tu pantalla continúa activa exactamente con tus mismas credenciales, historial y series guardadas sin interrupción. ¡Gracias por renovar con nosotros! ⭐🍿","titulo":"🔄 Confirmación de Renovación por Pago Directo","descripcion":"Para clientes directos que pagaron su mensualidad por WhatsApp/Pago Móvil para extender su pantalla existente."}}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 4. Tasa BCV Inicial
INSERT INTO public.exchange_rates (bs_por_usd, fecha, fuente)
VALUES (883.3963, '2026-10-21', 'BCV')
ON CONFLICT DO NOTHING;

-- 5. Clave de Cifrado en Secrets (AES-256)
INSERT INTO public.secrets (name, value)
VALUES ('enc_key', 'gregory_secret_master_key_2026_x789b12')
ON CONFLICT (name) DO NOTHING;

-- 6. Catálogo de Productos Oficiales (69 Productos)
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c2b130bd-97dc-4b2c-8b1d-c87f04797844', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'CANVA 30 DIAS', 'servicio', 2.56, 2.06, 1.72, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('4323f2e9-4839-4202-9957-d5152cba3ba3', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'CANVA 90 DIAS', 'servicio', 7.12, 5.37, 4.48, 90, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('fe6554dc-6dda-45c8-9550-f8e95c24c634', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'DISNEY PERFIL 15 DIAS', 'pantalla', 2.5, 2.08, 1.73, 15, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('43487373-260f-487d-85f0-871d9d6fbf89', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'VIX PERFIL 15 DIAS', 'pantalla', 1.25, 0.85, 0.71, 15, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('911c01cd-ab71-48da-9cf1-5eb3ce0746be', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'FLUJOTV PERFIL 180+30 DIAS', 'pantalla', 25.42, 17.39, 14.51, 210, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('1f9cf6e7-8128-4a82-8b79-75791f887a1b', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'VIKI RAKUTEN PERFIL 30 DIAS', 'pantalla', 3.03, 2.23, 1.86, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('3b140a9e-93ff-43cc-a836-eb5b4d4038ed', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'FLUJOTV PERFIL 90 DIAS', 'pantalla', 12.51, 8.5, 7.09, 90, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('6f4fdf56-424c-435c-820a-6182748fb473', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', '4 PERFIL EXTRA NETFLIX 30 DIAS', 'pantalla', 24.04, 22.11, 18.44, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c4755fb9-0168-448b-9399-4c7fa5b53a30', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'TELELTINO PERFIL 90 DIAS', 'pantalla', 12.21, 8.95, 7.46, 90, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('97aea63d-c5ee-44c8-90bc-87f8a3929fcb', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'SPOTIFY 30 DIAS ALQUILER', 'pantalla', 5.66, 4.65, 3.88, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('2db418ee-d3de-4578-856b-42247d47bc1d', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'SPOTIFY 60 DIAS ALQUILER', 'pantalla', 10.8, 9.05, 7.54, 60, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('3f6e796b-acf3-4052-bb8d-1d98b10af5a9', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'YOUTUBE PREMIUM 30 DIAS', 'pantalla', 3.11, 2.71, 2.26, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('12573bb5-85ca-4be1-8cc4-f21e132b3aec', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'YOUTUBE PREMIUM 60 DIAS', 'pantalla', 5.13, 4.77, 3.98, 60, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('1978f094-ee20-4bbb-9e8d-2a8bb72dba24', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'TELELATINO PERFIL 180 DIAS', 'pantalla', 24.42, 17.89, 14.92, 180, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('95dbc467-6d30-4138-b1f4-414e1b8dbead', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'UNIVERSAL PERFIL 30 DIAS', 'pantalla', 3.03, 2.23, 1.86, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('719c7da0-714d-4e71-aec6-6dd4eb33ef4a', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'FLUJOTV PERFIL 365+60 DIAS', 'pantalla', 50.82, 35.78, 29.84, 425, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('56bbbd2e-ad38-413c-b0f7-0d97ab72e5a3', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'CANVA 180 DIAS', 'servicio', 12.23, 9.17, 7.64, 180, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('817719d3-2adf-4010-b2c8-35c879867ca6', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Netflix', 'pantalla', 6, 4.29, 3.58, 30, 1, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('44f72a12-1f9a-4827-91ba-2687a34694f8', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'DRAMA BOX CTA C  30 DIAS', 'pantalla', 3, 1.3, 1.5, 30, 1, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('5389333e-9252-4a1a-9423-1dd253e25afc', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Perfil Extra Netflix', 'pantalla', 8, 6.08, 4.5, 30, 2, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('9231b1d6-93c0-4e2e-b003-5e5c31b2c4b2', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Disney+ Premium', 'pantalla', 5, 3.32, 2.77, 30, 3, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('9caba6a0-3def-4ade-8f53-7d078c737a29', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Max Estándar', 'pantalla', 3, 1.9, 1.58, 30, 4, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c19efbe7-e2e0-406c-97a8-2557e7af4b96', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Amazon Prime Video', 'pantalla', 2.53, 1.81, 1.51, 30, 5, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('21d5e3b4-be67-4ef1-848c-a9a5c8f493d5', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'ViX Premium', 'pantalla', 2.5, 1.7, 1.42, 30, 6, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('6153d298-de80-446f-8683-d266e527fc34', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Crunchyroll Fan', 'pantalla', 3.02, 2.12, 1.77, 30, 7, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('1e7f6366-a111-437b-8b68-7659117275ac', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Paramount+', 'pantalla', 3.03, 2.23, 1.86, 30, 8, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('1facf06b-7777-43a8-bd1b-28b9abc685d1', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Telelatino', 'pantalla', 4.5, 3.3, 2.75, 30, 9, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('e7a9fcd1-9771-4bec-85ba-b139185de5ce', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Flujo TV', 'pantalla', 4.5, 3.3, 2.75, 30, 10, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('3b8585ca-9bfc-44e5-bdc3-f11ce16a457b', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'DEEZER  CTA C 30 DIAS', 'cuenta_completa', 3.09, 2.59, 2.16, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('82bac9c2-a266-4125-8d91-d47cb1ca61ad', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'NETFLIX CUENTA COMPLETA 30 DIAS', 'cuenta_completa', 19, 17.18, 14.33, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('467c53e0-9819-467d-a5f2-5558832a0a15', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'MAX CUENTA COMPLETA 30 DIAS', 'cuenta_completa', 8, 5.89, 4.91, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('fe87da46-d60d-4d71-a549-c8090ceffc46', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'CRUNCHYROLL CTA COMPLETA 30 DIAS', 'cuenta_completa', 7.1, 5.1, 4.25, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('0f202af8-c3b1-40ac-ad73-a57f37452797', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'PARAMOUNT CTA C 30 DIAS', 'cuenta_completa', 7.21, 5.9, 4.92, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('07aa1a1b-f9e6-449d-826c-957fabe892c5', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'PARAMOUNT CTA C  ALQUILER 30 DIAS', 'cuenta_completa', 7.13, 5.46, 4.55, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('79ee78ca-6c98-416c-ae4e-8653507fe836', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'UNIVERSAL CTA C 30 DIAS', 'cuenta_completa', 7.17, 5.58, 4.65, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('39377c66-e638-4882-9452-aa934bc8867f', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'VIKI RAKUTEN CTA C 30 DIAS', 'cuenta_completa', 7.17, 5.58, 4.65, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('a8a148a4-37d8-43f8-9e78-998c071d8fbf', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'TELELATINO CTA C 30 DIAS', 'cuenta_completa', 8.21, 6.7, 5.59, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('598f706a-bc20-4e54-ab53-3d3fdbd21191', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'TELELATINO CTA C 90 DIAS', 'cuenta_completa', 20.61, 17.08, 14.25, 90, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('991fdddf-95d5-4141-afb8-4d613ba367b3', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'TELELATINO CTA C  180 DIAS', 'cuenta_completa', 42.74, 35.67, 29.75, 180, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('6a484fd0-2172-4b55-b5d2-7f1c38b8e9e6', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'MAX CTA C ALQUILER  30 DIAS', 'cuenta_completa', 8, 5.53, 4.61, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c23c3f4f-72a6-486f-8ad8-dd1fb6d30e36', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'DISNEY PREMIUM CTA C 30 DIAS', 'cuenta_completa', 11.98, 10.67, 8.9, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('cbb4af03-e403-4e94-b53a-18044dd52951', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'PRIME VIDEO CTA C 30 DIAS', 'cuenta_completa', 6.71, 5.7, 4.75, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c8e3ed62-8c16-406f-9671-7bf4dfcbeb13', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'VIX CTA C 30 DIAS', 'cuenta_completa', 5.03, 3.53, 2.94, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('8cd76175-0c9c-4424-bd82-b8977566b9a0', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'FLUJOTV CTA C 30 DIAS', 'cuenta_completa', 9.21, 7.15, 5.96, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('f01ce00d-be52-4c5f-af42-b1ae6b3173eb', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'FLUJOTV CTA C 180+30  DIAS', 'cuenta_completa', 51.24, 41.17, 34.34, 210, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('01982296-a72f-48c4-84e9-aef92105e21c', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'FLUJOTV CTA C 365+60 DIAS', 'cuenta_completa', 102.47, 82.34, 68.67, 425, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('30dcb9a0-fd54-4e1f-aa27-503aa2d94009', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'PLEX CTA C 30 DIAS', 'cuenta_completa', 4.64, 3.88, 3.23, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('08846893-c11f-476e-824b-967aa8fbcb7c', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'EMBY CTA C 30 DIAS', 'cuenta_completa', 5.17, 4.36, 3.63, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c299d305-c260-4733-969b-340be20be57a', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'JELLYFIN CTA C 30 DIAS', 'cuenta_completa', 5.17, 4.36, 3.63, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('b4d53291-36a9-433e-8b04-296d59f8b734', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', '3 CUENTAS VIX 30 DIAS', 'cuenta_completa', 10.1, 7.1, 5.92, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('96f1dd05-606c-4d6f-9270-17685bb4133e', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', '3 CUENTAS MAX 30 DIAS', 'cuenta_completa', 18.41, 14.64, 12.21, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('a8fcd384-200d-424e-a85c-c3f7f26ca452', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', '3 CUENTAS PRIME 30 DIAS', 'cuenta_completa', 18.62, 16.14, 13.46, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('8e51db01-3f3c-4718-8f89-43db6e37d760', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', '3 CUENTAS PARAMOUNT 30 DIAS', 'cuenta_completa', 18.61, 16.08, 13.41, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('e1f2ef27-c6b3-448b-a62a-ce4803000a9c', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', '3 CUENTAS CRUNCHYROOL 30 DIAS', 'cuenta_completa', 14.31, 11.29, 9.42, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c745a754-e1ea-45e5-b6d9-7eec7cf23c61', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 6 (NETFLIX +CRUNCHYROLL)', 'servicio', 8.13, 6.2, 5.17, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('2c4f8eec-9fd4-4d18-8227-3a13d2dd6c18', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 1 (NETFLIX +VIX)', 'servicio', 7.65, 5.48, 4.57, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('190d1feb-0835-4902-b445-7e0c751ad32c', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 2 (NETFLIX+PRIME)', 'servicio', 7, 6.01, 5.01, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('bc9205ad-8b44-4a1d-a0b0-efd6b6985dd7', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 3 (NETFLIX + MAX)', 'servicio', 8, 5.81, 4.84, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('63638554-72c6-44ca-bbf4-ba28f7584f38', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 4 (NETFLIX + DISNEY)', 'servicio', 9.9, 7.24, 6.04, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('d0e5ecfc-1da8-44e6-b8c8-0bfe29a1f73b', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 5 (NETFLIX + PARAMOUNT)', 'servicio', 8, 6.2, 5.17, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('58eb0b47-f23a-4d24-a1e7-bf73ca402c78', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'PAQUETE OFFICE 365 30 DIAS', 'servicio', 2.8, 2.3, 1.5, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('6e021b16-879b-4d9a-ab76-8b835268d04f', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'GEMINIS PRO 6 meses', 'servicio', 4, 3.5, 3, 180, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('d60c9c3d-c225-45dd-99a4-adffcc61be4f', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'SPOTIFY PREMIUM APK', 'servicio', 3, 2, 1.2, 30, 20, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('cb1ab668-f8ef-4d30-8be2-57621abb3623', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'YOUTUBE PREMIUM APK', 'servicio', 2, 1.3, 1, 30, 21, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('389413bb-e26c-469d-b64a-58655ddc038b', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'CAPCUT APK', 'servicio', 3, 2, 1.2, 30, 22, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('b00e4a3f-c36c-4d9d-b82a-5cc80fcde615', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'PICSART APK', 'servicio', 3, 2, 1.2, 30, 23, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('ebb67bb4-f370-4aac-b716-2cd725e92c6f', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'DRAMA BOX APK', 'servicio', 3, 2, 1.2, 30, 24, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('0dfdb6c1-b375-40d2-a927-efd1c0b5841f', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'FREEREELS APK', 'servicio', 3, 2, 1.2, 30, 25, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('6f6b554f-f889-49bf-b75e-d00f9f61d481', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'REELSHORT APK', 'servicio', 3, 2, 1.2, 30, 26, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;

-- 7. Cuentas Administradoras Oficiales
INSERT INTO public.admins (email)
VALUES 
  ('emprendimientogregoryizquierdo@gmail.com'),
  ('gregoryrodriguez2021@gmail.com'),
  ('admin.demo@gregoryizquierdo.xyz')
ON CONFLICT (email) DO NOTHING;


\echo '>>> INSTALACIÓN CONCLUIDA EXITOSAMENTE <<<'
