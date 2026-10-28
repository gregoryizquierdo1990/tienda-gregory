-- ==============================================================================
-- MIGRACIÓN 59: AGREGAR COLUMNA VENDEDOR_NOMBRE A ORDERS
-- Soluciona error al procesar compras de revendedores en create_order y _deliver
-- ==============================================================================

-- 1. Agregar columna vendedor_nombre a la tabla orders si no existe
alter table public.orders add column if not exists vendedor_nombre text;

-- 2. Retro-poblar vendedor_nombre en órdenes existentes que ya tengan vendedor_id
update public.orders o
set vendedor_nombre = c.nombre
from public.customers c
where o.vendedor_id = c.id
  and o.vendedor_nombre is null;
