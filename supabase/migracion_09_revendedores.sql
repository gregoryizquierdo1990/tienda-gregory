-- Migracion 09: Campos de Revendedores Mayoristas (Precios especiales y rol revendedor)

-- 1. Añadir precio para revendedores a productos (si no se define, el sistema calcula 15% de descuento por defecto)
alter table products add column if not exists precio_revendedor_usd numeric(10,2);

-- 2. Añadir bandera es_revendedor a clientes
alter table customers add column if not exists es_revendedor boolean not null default false;
