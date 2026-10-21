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
