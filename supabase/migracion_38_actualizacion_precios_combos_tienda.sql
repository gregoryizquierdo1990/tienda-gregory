-- ==============================================================================
-- MIGRACIÓN 38: ACTUALIZACIÓN DE PRECIOS COMBOS DE SERVICIOS (CLIENTE FINAL / TIENDA)
-- ==============================================================================
-- Precios oficiales de tienda (PVP Cliente Final):
-- COMBO 1 (NETFLIX + VIX)         -> $7.65
-- COMBO 2 (NETFLIX + PRIME)       -> $7.00
-- COMBO 3 (NETFLIX + MAX)         -> $8.00
-- COMBO 4 (NETFLIX + DISNEY)      -> $9.90
-- COMBO 5 (NETFLIX + PARAMOUNT)   -> $8.00
-- COMBO 6 (NETFLIX + CRUNCHYROLL) -> $8.13
-- ==============================================================================

begin;

-- 1. Asegurar categoría "Combos Especiales"
insert into categories (id, nombre, orden, activo)
values ('e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'Combos Especiales', 3, true)
on conflict (id) do update set nombre = 'Combos Especiales', activo = true;

-- 2. Actualizar o Insertar cada Combo con su nuevo PVP Tienda

-- COMBO 1: NETFLIX + VIX ($7.65)
do $$
declare
  v_id uuid;
begin
  select id into v_id from products
  where lower(trim(nombre)) in ('combo 1 (netflix +vix)', 'combo 1 (netflix + vix)', 'combo 1')
     or (nombre ilike '%combo 1%' and nombre ilike '%vix%')
  order by id limit 1;

  if v_id is not null then
    update products set
      precio_usd = 7.65,
      ganancia_tienda_usd = greatest(0.00, round(7.65 - coalesce(costo_bs, costo_usdt, 3.24) - coalesce(comision_revendedor_usd, 1.20), 2)),
      reparto_bs_negocio = greatest(0.00, round(7.65 - coalesce(costo_bs, 3.24) - coalesce(reparto_bs_pablo, 1.20) - coalesce(reparto_bs_gregory, 1.20), 2)),
      activo = true
    where id = v_id;
  else
    insert into products (
      category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd,
      costo_usdt, costo_bs, comision_revendedor_usd, ganancia_tienda_usd,
      reparto_bs_pablo, reparto_bs_negocio, reparto_bs_gregory,
      reparto_usdt_pablo, reparto_usdt_negocio, reparto_usdt_gregory,
      duracion_dias, garantia_dias, activo
    ) values (
      'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 1 (NETFLIX + VIX)', 'Combo oficial Netflix + Vix Premium por perfiles', 'servicio',
      7.65, 5.48, 4.57,
      2.70, 3.24, 1.20, 3.21,
      1.20, 2.01, 1.20,
      1.00, 0.87, 1.00,
      30, 30, true
    );
  end if;
end $$;

-- COMBO 2: NETFLIX + PRIME ($7.00)
do $$
declare
  v_id uuid;
begin
  select id into v_id from products
  where lower(trim(nombre)) in ('combo 2 (netflix+prime)', 'combo 2 (netflix + prime)', 'combo 2')
     or (nombre ilike '%combo 2%' and nombre ilike '%prime%')
  order by id limit 1;

  if v_id is not null then
    update products set
      precio_usd = 7.00,
      ganancia_tienda_usd = greatest(0.00, round(7.00 - coalesce(costo_bs, costo_usdt, 3.71) - coalesce(comision_revendedor_usd, 1.20), 2)),
      reparto_bs_negocio = greatest(0.00, round(7.00 - coalesce(costo_bs, 3.71) - coalesce(reparto_bs_pablo, 1.20) - coalesce(reparto_bs_gregory, 1.00), 2)),
      activo = true
    where id = v_id;
  else
    insert into products (
      category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd,
      costo_usdt, costo_bs, comision_revendedor_usd, ganancia_tienda_usd,
      reparto_bs_pablo, reparto_bs_negocio, reparto_bs_gregory,
      reparto_usdt_pablo, reparto_usdt_negocio, reparto_usdt_gregory,
      duracion_dias, garantia_dias, activo
    ) values (
      'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 2 (NETFLIX + PRIME)', 'Combo oficial Netflix + Amazon Prime Video por perfiles', 'servicio',
      7.00, 6.01, 5.01,
      3.09, 3.71, 1.20, 2.09,
      1.20, 1.09, 1.00,
      1.00, 0.92, 1.00,
      30, 30, true
    );
  end if;
end $$;

-- COMBO 3: NETFLIX + MAX ($8.00)
do $$
declare
  v_id uuid;
begin
  select id into v_id from products
  where lower(trim(nombre)) in ('combo 3 (netflix + max)', 'combo 3 (netflix+max)', 'combo 3')
     or (nombre ilike '%combo 3%' and nombre ilike '%max%')
  order by id limit 1;

  if v_id is not null then
    update products set
      precio_usd = 8.00,
      ganancia_tienda_usd = greatest(0.00, round(8.00 - coalesce(costo_bs, costo_usdt, 3.84) - coalesce(comision_revendedor_usd, 0.90), 2)),
      reparto_bs_negocio = greatest(0.00, round(8.00 - coalesce(costo_bs, 3.84) - coalesce(reparto_bs_pablo, 0.90) - coalesce(reparto_bs_gregory, 0.75), 2)),
      activo = true
    where id = v_id;
  else
    insert into products (
      category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd,
      costo_usdt, costo_bs, comision_revendedor_usd, ganancia_tienda_usd,
      reparto_bs_pablo, reparto_bs_negocio, reparto_bs_gregory,
      reparto_usdt_pablo, reparto_usdt_negocio, reparto_usdt_gregory,
      duracion_dias, garantia_dias, activo
    ) values (
      'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 3 (NETFLIX + MAX)', 'Combo oficial Netflix + Max Estándar por perfiles', 'servicio',
      8.00, 5.81, 4.84,
      3.20, 3.84, 0.90, 3.26,
      0.90, 2.51, 0.75,
      0.75, 0.89, 0.75,
      30, 30, true
    );
  end if;
end $$;

-- COMBO 4: NETFLIX + DISNEY ($9.90)
do $$
declare
  v_id uuid;
begin
  select id into v_id from products
  where lower(trim(nombre)) in ('combo 4 (netflix + disney)', 'combo 4 (netflix+disney)', 'combo 4')
     or (nombre ilike '%combo 4%' and nombre ilike '%disney%')
  order by id limit 1;

  if v_id is not null then
    update products set
      precio_usd = 9.90,
      ganancia_tienda_usd = greatest(0.00, round(9.90 - coalesce(costo_bs, costo_usdt, 4.32) - coalesce(comision_revendedor_usd, 1.50), 2)),
      reparto_bs_negocio = greatest(0.00, round(9.90 - coalesce(costo_bs, 4.32) - coalesce(reparto_bs_pablo, 1.50) - coalesce(reparto_bs_gregory, 1.25), 2)),
      activo = true
    where id = v_id;
  else
    insert into products (
      category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd,
      costo_usdt, costo_bs, comision_revendedor_usd, ganancia_tienda_usd,
      reparto_bs_pablo, reparto_bs_negocio, reparto_bs_gregory,
      reparto_usdt_pablo, reparto_usdt_negocio, reparto_usdt_gregory,
      duracion_dias, garantia_dias, activo
    ) values (
      'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 4 (NETFLIX + DISNEY)', 'Combo oficial Netflix + Disney+ Premium por perfiles', 'servicio',
      9.90, 7.24, 6.04,
      3.60, 4.32, 1.50, 4.08,
      1.50, 2.83, 1.25,
      1.25, 1.18, 1.25,
      30, 30, true
    );
  end if;
end $$;

-- COMBO 5: NETFLIX + PARAMOUNT ($8.00)
do $$
declare
  v_id uuid;
begin
  select id into v_id from products
  where lower(trim(nombre)) in ('combo 5 (netflix + paramount)', 'combo 5 (netflix+paramount)', 'combo 5')
     or (nombre ilike '%combo 5%' and nombre ilike '%paramount%')
  order by id limit 1;

  if v_id is not null then
    update products set
      precio_usd = 8.00,
      ganancia_tienda_usd = greatest(0.00, round(8.00 - coalesce(costo_bs, costo_usdt, 3.72) - coalesce(comision_revendedor_usd, 1.50), 2)),
      reparto_bs_negocio = greatest(0.00, round(8.00 - coalesce(costo_bs, 3.72) - coalesce(reparto_bs_pablo, 1.50) - coalesce(reparto_bs_gregory, 1.25), 2)),
      activo = true
    where id = v_id;
  else
    insert into products (
      category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd,
      costo_usdt, costo_bs, comision_revendedor_usd, ganancia_tienda_usd,
      reparto_bs_pablo, reparto_bs_negocio, reparto_bs_gregory,
      reparto_usdt_pablo, reparto_usdt_negocio, reparto_usdt_gregory,
      duracion_dias, garantia_dias, activo
    ) values (
      'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 5 (NETFLIX + PARAMOUNT)', 'Combo oficial Netflix + Paramount+ por perfiles', 'servicio',
      8.00, 6.20, 5.17,
      3.10, 3.72, 1.50, 2.78,
      1.50, 1.53, 1.25,
      1.25, 0.82, 1.25,
      30, 30, true
    );
  end if;
end $$;

-- COMBO 6: NETFLIX + CRUNCHYROLL ($8.13)
do $$
declare
  v_id uuid;
begin
  select id into v_id from products
  where lower(trim(nombre)) in ('combo 6 (netflix +crunchyroll)', 'combo 6 (netflix + crunchyroll)', 'combo 6')
     or (nombre ilike '%combo 6%' and nombre ilike '%crunchy%')
  order by id limit 1;

  if v_id is not null then
    update products set
      precio_usd = 8.13,
      ganancia_tienda_usd = greatest(0.00, round(8.13 - coalesce(costo_bs, costo_usdt, 3.72) - coalesce(comision_revendedor_usd, 1.50), 2)),
      reparto_bs_negocio = greatest(0.00, round(8.13 - coalesce(costo_bs, 3.72) - coalesce(reparto_bs_pablo, 1.50) - coalesce(reparto_bs_gregory, 1.25), 2)),
      activo = true
    where id = v_id;
  else
    insert into products (
      category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd,
      costo_usdt, costo_bs, comision_revendedor_usd, ganancia_tienda_usd,
      reparto_bs_pablo, reparto_bs_negocio, reparto_bs_gregory,
      reparto_usdt_pablo, reparto_usdt_negocio, reparto_usdt_gregory,
      duracion_dias, garantia_dias, activo
    ) values (
      'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 6 (NETFLIX + CRUNCHYROLL)', 'Combo oficial Netflix + Crunchyroll Fan por perfiles', 'servicio',
      8.13, 6.20, 5.17,
      3.10, 3.72, 1.50, 2.91,
      1.50, 1.66, 1.25,
      1.25, 0.82, 1.25,
      30, 30, true
    );
  end if;
end $$;

commit;
