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
