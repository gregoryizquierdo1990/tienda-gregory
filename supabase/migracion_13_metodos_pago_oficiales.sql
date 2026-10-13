-- ==============================================================================
-- MIGRACIÓN 13: CONFIGURACIÓN OFICIAL DE MÉTODOS DE PAGO EN BLOQUES (CAJONES)
-- ==============================================================================

-- 1. Asegurar la estructura de la tabla payment_methods
create table if not exists payment_methods (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  tipo text,
  datos jsonb default '{}'::jsonb,
  activo boolean default true,
  orden int default 0
);

-- Asegurar RLS
alter table payment_methods enable row level security;

-- Política de lectura pública
drop policy if exists pub_pm on payment_methods;
create policy pub_pm on payment_methods for select using (activo);

-- 2. Limpieza o actualización idempotente de los 9 métodos oficiales
-- Desactivar métodos antiguos genéricos para priorizar los 9 oficiales
update payment_methods set activo = false where activo = true;

-- Insertar los 9 métodos oficiales estructurados para el renderizado por cajones
insert into payment_methods (nombre, tipo, datos, activo, orden) values
(
  'Pago Móvil (BNC)',
  'pago_movil',
  '{
    "Banco": "BNC (Banco Nacional de Crédito)",
    "Código": "0191",
    "Teléfono": "04242809333",
    "Documento": "V 18931731"
  }'::jsonb,
  true,
  1
),
(
  'Binance (USDT)',
  'binance',
  '{
    "ID Binance": "393089335",
    "Correo": "gregoryrodriguez2021@gmail.com"
  }'::jsonb,
  true,
  2
),
(
  'Transferencia Internacional (Ecuador)',
  'transferencia_internacional',
  '{
    "Banco": "Guayaquil",
    "Tipo de Cuenta": "Ahorros",
    "Titular": "Evert Izquierdo",
    "Documento": "2451655498",
    "N° Cuenta": "0042286503",
    "Email": "evertizquierdo91@gmail.com"
  }'::jsonb,
  true,
  3
),
(
  'ApoloPay',
  'apolopay',
  '{
    "ID Usuario": "7604",
    "Correo": "gregoryrodriguez2021@gmail.com"
  }'::jsonb,
  true,
  4
),
(
  'Zinli',
  'zinli',
  '{
    "Teléfono": "04242809333",
    "Correo": "gregoryrodriguez2021@gmail.com"
  }'::jsonb,
  true,
  5
),
(
  'Wally',
  'wally',
  '{
    "Teléfono": "04242809333",
    "Correo": "gregoryrodriguez2021@gmail.com"
  }'::jsonb,
  true,
  6
),
(
  'Uglycash',
  'uglycash',
  '{
    "Usuario": "gair1990"
  }'::jsonb,
  true,
  7
),
(
  'Transferencia EEUU (Lead Bank)',
  'transferencia_eeuu',
  '{
    "Banco": "Lead Bank",
    "Tipo de Cuenta": "Corriente",
    "Titular": "Gregori Antonio Izquierdo Rodriguez",
    "N° Cuenta": "210345561126",
    "Routing": "101019644",
    "Dirección Banco": "1801 Main St., Kansas City. MO 64108"
  }'::jsonb,
  true,
  8
),
(
  'Pago Móvil Jurídico',
  'pago_movil_juridico',
  '{
    "Banco": "Venezolano de Crédito",
    "Código": "0104",
    "Teléfono": "04242809333",
    "Documento": "J 506393794"
  }'::jsonb,
  true,
  9
);
