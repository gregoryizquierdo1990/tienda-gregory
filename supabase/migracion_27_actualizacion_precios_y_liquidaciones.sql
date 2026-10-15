-- ==============================================================================
-- Migración 27: Actualización Maestra de Precios de la Tienda (PVP, Revendedor, USDT)
-- y Modelo Dual de Liquidación de Ganancias para Socios (Bolívares vs Binance)
-- Emprendimiento Gregory Izquierdo
-- ==============================================================================

-- 0. Desambiguar relación orders -> customers eliminando la FK explícita de vendedor_id
-- (se mantiene vendedor_id como columna UUID en orders para guardar el socio, pero sin FK para que PostgREST no confunda la relación principal con customers)
alter table orders drop constraint if exists orders_vendedor_id_fkey;

-- 0.1 UNIFICACIÓN DEFINITIVA DEL REVENDEDOR PABLO GONZALEZ Y LIMPIEZA DE DUPLICADOS
do 78188
declare
  v_pablo_id uuid;
  v_nelson_id uuid;
  v_josuanny_id uuid;
  v_leandro_id uuid;
  v_dup_id uuid;
begin
  -- 1. Identificar o consolidar el registro OFICIAL de Pablo Gonzalez (pacun1989@gmail.com)
  select id into v_pablo_id from customers
  where lower(trim(email)) = 'pacun1989@gmail.com'
  order by creado asc limit 1;

  if v_pablo_id is null then
    select id into v_pablo_id from customers
    where lower(trim(nombre)) like '%pablo gonzalez%' or lower(trim(nombre)) = 'pablo'
    order by (email is not null and email like '%@%') desc, creado asc limit 1;
  end if;

  if v_pablo_id is not null then
    update customers set
      nombre = 'Pablo Gonzalez',
      email = 'pacun1989@gmail.com',
      telefono = '584129130080',
      es_revendedor = true,
      codigo_identificacion = 'RVD:1001'
    where id = v_pablo_id;

    -- Reasignar cualquier cliente, orden, perfil o comisión que apunte al registro duplicado 'PABLO'
    for v_dup_id in
      select id from customers
      where id <> v_pablo_id
        and (lower(trim(nombre)) in ('pablo', 'pablo revendedor') or lower(trim(email)) in ('584129130080@cliente.gregoryizquierdo.xyz', 'pacun1989@gmail.com'))
    loop
      update customers set vendedor_id = v_pablo_id, vendedor_nombre = 'Pablo Gonzalez' where vendedor_id = v_dup_id;
      update orders set vendedor_id = v_pablo_id where vendedor_id = v_dup_id;
      update orders set customer_id = v_pablo_id where customer_id = v_dup_id;
      update profiles_inventory set vendedor_id = v_pablo_id, vendedor = 'Pablo Gonzalez' where vendedor_id = v_dup_id;
      update profiles_inventory set assigned_customer_id = v_pablo_id where assigned_customer_id = v_dup_id;
      update partner_commissions set vendedor_id = v_pablo_id where vendedor_id = v_dup_id;
      update zeny_ledger set customer_id = v_pablo_id where customer_id = v_dup_id;
      delete from zeny_cards where customer_id = v_dup_id;
      delete from customers where id = v_dup_id;
      begin
        delete from auth.users where id = v_dup_id;
      exception when others then null;
      end;
    end loop;
  end if;

  -- 2. Asegurar a los demás revendedores oficiales con sus códigos RVD
  select id into v_leandro_id from customers where lower(email) in ('perdomoleandro39@gmail.com', '584122952044@cliente.gregoryizquierdo.xyz') or lower(nombre) like '%leandro%' limit 1;
  if v_leandro_id is not null then
    update customers set
      nombre = 'Leandro Perdomo',
      email = coalesce(email, 'perdomoleandro39@gmail.com'),
      telefono = coalesce(telefono, '584122952044'),
      es_revendedor = true,
      codigo_identificacion = 'RVD:1002'
    where id = v_leandro_id;
  end if;

  select id into v_nelson_id from customers where lower(email) in ('584120266710@cliente.gregoryizquierdo.xyz') or lower(nombre) like '%nelson%' limit 1;
  if v_nelson_id is not null then
    update customers set
      nombre = 'Nelson Bustamante',
      telefono = coalesce(telefono, '584120266710'),
      es_revendedor = true,
      codigo_identificacion = 'RVD:1003'
    where id = v_nelson_id;
  end if;

  select id into v_josuanny_id from customers where lower(email) in ('584129939848@cliente.gregoryizquierdo.xyz') or lower(nombre) like '%josuanny%' limit 1;
  if v_josuanny_id is not null then
    update customers set
      nombre = 'Josuanny',
      telefono = coalesce(telefono, '584129939848'),
      es_revendedor = true,
      codigo_identificacion = 'RVD:1004'
    where id = v_josuanny_id;
  end if;

  -- 3. Asignación estricta de Vendedores a Clientes según desglose oficial:
  -- Pablo Gonzalez (27 clientes):
  update customers set vendedor_id = v_pablo_id, vendedor_nombre = 'Pablo Gonzalez'
  where lower(trim(nombre)) in (
    'angelo', 'ariana herrera', 'carlos leon', 'carolina herrera', 'diogenes',
    'dirwin caraballo', 'elis', 'enyerber estevez', 'evert izquierdo', 'fernisbel',
    'gabriel rodriguez', 'gepeto', 'isaac tovar', 'landys', 'manuel gonzalez',
    'maria', 'marianela espinoza', 'marianne agudo', 'melvin amundarain', 'melyta',
    'pablo gonzalez', 'roymel', 'tony massimo', 'vanessa', 'victoria guevara',
    'yosemit', 'yuglislelo perez'
  ) or lower(trim(email)) in (
    '584242782146@cliente.gregoryizquierdo.xyz', '584128592774@cliente.gregoryizquierdo.xyz',
    '584143725323@cliente.gregoryizquierdo.xyz', '584142725342@cliente.gregoryizquierdo.xyz',
    '584143848858@cliente.gregoryizquierdo.xyz', '584120904544@cliente.gregoryizquierdo.xyz',
    '584124494241@cliente.gregoryizquierdo.xyz', '584128047511@cliente.gregoryizquierdo.xyz',
    '593978678921@cliente.gregoryizquierdo.xyz', '584141181778@cliente.gregoryizquierdo.xyz',
    '584143893589@cliente.gregoryizquierdo.xyz', '584129251463@cliente.gregoryizquierdo.xyz',
    '18133779985@cliente.gregoryizquierdo.xyz', '584142478459@cliente.gregoryizquierdo.xyz',
    '584264078565@cliente.gregoryizquierdo.xyz', '584241415188@cliente.gregoryizquierdo.xyz',
    '584142773768@cliente.gregoryizquierdo.xyz', '584245620861@cliente.gregoryizquierdo.xyz',
    '584142302384@cliente.gregoryizquierdo.xyz', '584129809304@cliente.gregoryizquierdo.xyz',
    'pacun1989@gmail.com', '584120229689@cliente.gregoryizquierdo.xyz',
    '584142487511@cliente.gregoryizquierdo.xyz', '584242843713@cliente.gregoryizquierdo.xyz',
    '584242407603@cliente.gregoryizquierdo.xyz', '573215601336@cliente.gregoryizquierdo.xyz',
    '584242322095@cliente.gregoryizquierdo.xyz'
  );

  -- Nelson Bustamante (3 clientes):
  update customers set vendedor_id = v_nelson_id, vendedor_nombre = 'Nelson Bustamante'
  where lower(trim(nombre)) in ('armando', 'carmen nacero', 'keiber nacero')
     or lower(trim(email)) in ('armando.584120266710@cliente.gregoryizquierdo.xyz', 'carmennacero.584120266710@cliente.gregoryizquierdo.xyz', 'keibernacero.584120266710@cliente.gregoryizquierdo.xyz');

  -- Josuanny (2 clientes):
  update customers set vendedor_id = v_josuanny_id, vendedor_nombre = 'Josuanny'
  where lower(trim(nombre)) in ('silva', 'yosestyle')
     or lower(trim(email)) in ('silva.584129939848@cliente.gregoryizquierdo.xyz', 'yosestyle.584129939848@cliente.gregoryizquierdo.xyz');

  -- Leandro Perdomo (1 cliente):
  update customers set vendedor_id = v_leandro_id, vendedor_nombre = 'Leandro Perdomo'
  where lower(trim(nombre)) in ('joslex')
     or lower(trim(email)) in ('584122952044@cliente.gregoryizquierdo.xyz');

  -- DIRECTO TIENDA (2 clientes):
  update customers set vendedor_id = null, vendedor_nombre = 'Directo Tienda'
  where lower(trim(nombre)) in ('frederick ramos', 'douglas parra')
     or lower(trim(email)) in ('frederickramos1604@gmail.com', '584125872676@cliente.gregoryizquierdo.xyz');

  -- 4. Asignar en profiles_inventory según el cliente asignado:
  update profiles_inventory pi
  set vendedor_id = c.vendedor_id,
      vendedor = coalesce(c.vendedor_nombre, 'Directo Tienda')
  from customers c
  where pi.assigned_customer_id = c.id;

end 78188;

-- 1. Ampliar columnas en products para costos y modelo exacto de reparto
alter table products add column if not exists costo_usdt numeric(10,2) default 0.00;
alter table products add column if not exists costo_bs numeric(10,2) default 0.00;
alter table products add column if not exists comision_revendedor_usd numeric(10,2) default 0.00;
alter table products add column if not exists ganancia_tienda_usd numeric(10,2) default 0.00;

-- Modelo de Reparto en Bolívares (USD equiv)
alter table products add column if not exists reparto_bs_pablo numeric(10,2) default 0.00;
alter table products add column if not exists reparto_bs_negocio numeric(10,2) default 0.00;
alter table products add column if not exists reparto_bs_gregory numeric(10,2) default 0.00;

-- Modelo de Reparto en Binance (USDT)
alter table products add column if not exists reparto_usdt_pablo numeric(10,2) default 0.00;
alter table products add column if not exists reparto_usdt_negocio numeric(10,2) default 0.00;
alter table products add column if not exists reparto_usdt_gregory numeric(10,2) default 0.00;

-- 2. Asegurar categorías del catálogo
insert into categories (id, nombre, orden, activo) values
  ('e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Perfiles & Pantallas', 1, true),
  ('e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'Cuentas Completas', 2, true),
  ('e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'Combos Especiales', 3, true),
  ('e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'Música & Productividad', 4, true)
on conflict (id) do update set nombre = excluded.nombre, orden = excluded.orden, activo = true;

-- 3. Cargar y Actualizar los 62 Servicios Oficiales con Precios, Costos y Repartos Exactos
do 76648
declare
  r record;
  v_cat_id uuid;
  v_prod_id uuid;
begin
  for r in
    select * from (values
      ('NETFLIX NORMAL 30 DIAS', 'pantalla', 6.00, 4.29, 3.58, 2.60, 3.12, 0.70, 0.47, 0.70, 0.58, 0.39, 0.58, 30),
      ('NETFLIX PERFIL EXTRA NETFLIX 30 DIAS', 'pantalla', 8.00, 6.08, 4.50, 3.80, 4.56, 0.90, 0.52, 1.00, 0.75, 0.43, 0.83, 30),
      ('NETFLIX CUENTA COMPLETA 30 DIAS', 'cuenta_completa', 19.00, 17.18, 14.33, 13.00, 15.59, 1.17, 0.42, 1.17, 0.98, 0.35, 0.98, 30),
      ('4 PERFIL EXTRA NETFLIX 30 DIAS', 'pantalla', 24.04, 22.11, 18.44, 15.20, 18.23, 1.88, 2.00, 1.88, 1.57, 1.67, 1.57, 30),
      ('MAX PERFIL ESTANDAR 30 DIAS', 'pantalla', 3.00, 1.90, 1.58, 0.60, 0.72, 0.60, 0.58, 0.60, 0.50, 0.48, 0.50, 30),
      ('MAX CUENTA COMPLETA 30 DIAS', 'cuenta_completa', 8.00, 5.89, 4.91, 3.00, 3.60, 1.30, 0.99, 1.30, 1.08, 0.83, 1.08, 30),
      ('MAX CTA C ALQUILER  30 DIAS', 'cuenta_completa', 8.00, 5.53, 4.61, 1.99, 2.39, 1.60, 1.54, 1.60, 1.33, 1.28, 1.33, 30),
      ('DISNEY PERFIL 15 DIAS', 'pantalla', 2.50, 2.08, 1.73, 0.50, 0.60, 0.75, 0.73, 0.75, 0.63, 0.61, 0.63, 15),
      ('DISNEY PERFIL 30 DIAS', 'pantalla', 5.00, 3.32, 2.77, 1.00, 1.20, 1.25, 0.87, 1.25, 1.04, 0.73, 1.04, 30),
      ('DISNEY PREMIUM CTA C 30 DIAS', 'cuenta_completa', 11.98, 10.67, 8.90, 7.00, 8.39, 1.28, 1.00, 1.28, 1.07, 0.83, 1.07, 30),
      ('PRIME VIDEO PERFIL 30 DIAS', 'pantalla', 2.53, 1.81, 1.51, 0.49, 0.59, 0.72, 0.50, 0.72, 0.60, 0.42, 0.60, 30),
      ('PRIME VIDEO CTA C 30 DIAS', 'cuenta_completa', 6.71, 5.70, 4.75, 2.99, 3.59, 1.00, 1.11, 1.00, 0.83, 0.93, 0.83, 30),
      ('VIX PERFIL 15 DIAS', 'pantalla', 1.25, 0.85, 0.71, 0.05, 0.06, 0.40, 0.39, 0.40, 0.33, 0.33, 0.33, 15),
      ('VIX PERFIL 30 DIAS', 'pantalla', 2.50, 1.70, 1.42, 0.10, 0.12, 0.80, 0.78, 0.80, 0.67, 0.65, 0.67, 30),
      ('VIX CTA C 30 DIAS', 'cuenta_completa', 5.03, 3.53, 2.94, 0.50, 0.60, 1.50, 1.43, 1.50, 1.25, 1.19, 1.25, 30),
      ('CRUNCHYROLL PERFIL 30 DIA', 'pantalla', 3.02, 2.12, 1.77, 0.30, 0.36, 0.90, 0.86, 0.90, 0.75, 0.72, 0.75, 30),
      ('CRUNCHYROLL CTA COMPLETA 30 DIAS', 'cuenta_completa', 7.10, 5.10, 4.25, 1.49, 1.79, 2.00, 1.31, 2.00, 1.67, 1.09, 1.67, 30),
      ('PARAMOUNT PERFIL 30 DIAS', 'pantalla', 3.03, 2.23, 1.86, 0.50, 0.60, 0.80, 0.83, 0.80, 0.67, 0.69, 0.67, 30),
      ('PARAMOUNT CTA C 30 DIAS', 'cuenta_completa', 7.21, 5.90, 4.92, 3.00, 3.60, 1.30, 1.00, 1.30, 1.08, 0.83, 1.08, 30),
      ('PARAMOUNT CTA C  ALQUILER 30 DIAS', 'cuenta_completa', 7.13, 5.46, 4.55, 1.99, 2.39, 1.67, 1.40, 1.67, 1.39, 1.17, 1.39, 30),
      ('UNIVERSAL PERFIL 30 DIAS', 'pantalla', 3.03, 2.23, 1.86, 0.50, 0.60, 0.80, 0.83, 0.80, 0.67, 0.69, 0.67, 30),
      ('UNIVERSAL CTA C 30 DIAS', 'cuenta_completa', 7.17, 5.58, 4.65, 2.50, 3.00, 1.58, 1.00, 1.58, 1.32, 0.83, 1.32, 30),
      ('VIKI RAKUTEN PERFIL 30 DIAS', 'pantalla', 3.03, 2.23, 1.86, 0.50, 0.60, 0.80, 0.83, 0.80, 0.67, 0.69, 0.67, 30),
      ('VIKI RAKUTEN CTA C 30 DIAS', 'cuenta_completa', 7.17, 5.58, 4.65, 2.50, 3.00, 1.58, 1.00, 1.58, 1.32, 0.83, 1.32, 30),
      ('TELELATINO PERFIL 30 DIAS', 'pantalla', 4.50, 3.30, 2.75, 1.00, 1.20, 1.20, 0.90, 1.20, 1.00, 0.75, 1.00, 30),
      ('TELELTINO PERFIL 90 DIAS', 'pantalla', 12.21, 8.95, 7.46, 3.00, 3.60, 3.25, 2.10, 3.25, 2.71, 1.75, 2.71, 90),
      ('TELELATINO PERFIL 180 DIAS', 'pantalla', 24.42, 17.89, 14.92, 6.00, 7.19, 6.50, 4.20, 6.50, 5.42, 3.50, 5.42, 180),
      ('TELELATINO CTA C 30 DIAS', 'cuenta_completa', 8.21, 6.70, 5.59, 3.00, 3.60, 1.50, 1.60, 1.50, 1.25, 1.33, 1.25, 30),
      ('TELELATINO CTA C 90 DIAS', 'cuenta_completa', 20.61, 17.08, 14.25, 9.00, 10.79, 3.50, 2.79, 3.50, 2.92, 2.33, 2.92, 90),
      ('TELELATINO CTA C  180 DIAS', 'cuenta_completa', 42.74, 35.67, 29.75, 18.00, 21.58, 7.00, 7.09, 7.00, 5.84, 5.91, 5.84, 180),
      ('FLUJOTV PERFIL 30 DIAS', 'pantalla', 4.50, 3.30, 2.75, 1.00, 1.20, 1.20, 0.90, 1.20, 1.00, 0.75, 1.00, 30),
      ('FLUJOTV PERFIL 90 DIAS', 'pantalla', 12.51, 8.50, 7.09, 3.00, 3.60, 4.00, 0.90, 4.00, 3.34, 0.75, 3.34, 90),
      ('FLUJOTV PERFIL 180+30 DIAS', 'pantalla', 25.42, 17.39, 14.51, 6.00, 7.19, 8.00, 2.20, 8.00, 6.67, 1.83, 6.67, 210),
      ('FLUJOTV PERFIL 365+60 DIAS', 'pantalla', 50.82, 35.78, 29.84, 12.00, 14.39, 15.00, 6.39, 15.00, 12.51, 5.33, 12.51, 60),
      ('FLUJOTV CTA C 30 DIAS', 'cuenta_completa', 9.21, 7.15, 5.96, 3.00, 3.60, 2.05, 1.50, 2.05, 1.71, 1.25, 1.71, 30),
      ('FLUJOTV CTA C 180+30  DIAS', 'cuenta_completa', 51.24, 41.17, 34.34, 18.00, 21.58, 10.00, 9.59, 10.00, 8.34, 8.00, 8.34, 210),
      ('FLUJOTV CTA C 365+60 DIAS', 'cuenta_completa', 102.47, 82.34, 68.67, 36.00, 43.17, 20.00, 19.17, 20.00, 16.68, 15.99, 16.68, 60),
      ('CANVA 30 DIAS', 'pantalla', 2.56, 2.06, 1.72, 0.90, 1.08, 0.50, 0.48, 0.50, 0.42, 0.40, 0.42, 30),
      ('CANVA 90 DIAS', 'pantalla', 7.12, 5.37, 4.48, 1.80, 2.16, 1.75, 1.46, 1.75, 1.46, 1.22, 1.46, 90),
      ('CANVA 180 DIAS', 'pantalla', 12.23, 9.17, 7.64, 3.40, 4.08, 3.05, 2.04, 3.05, 2.54, 1.70, 2.54, 180),
      ('SPOTIFY 30 DIAS ALQUILER', 'pantalla', 5.66, 4.65, 3.88, 2.20, 2.64, 1.00, 1.01, 1.00, 0.83, 0.84, 0.83, 30),
      ('SPOTIFY 60 DIAS ALQUILER', 'pantalla', 10.80, 9.05, 7.54, 4.40, 5.28, 1.74, 2.03, 1.74, 1.45, 1.69, 1.45, 60),
      ('YOUTUBE PREMIUM 30 DIAS', 'pantalla', 3.11, 2.71, 2.26, 1.70, 2.04, 0.40, 0.27, 0.40, 0.33, 0.23, 0.33, 30),
      ('YOUTUBE PREMIUM 60 DIAS', 'pantalla', 5.13, 4.77, 3.98, 3.40, 4.08, 0.35, 0.34, 0.35, 0.29, 0.28, 0.29, 60),
      ('GEMINIS PRO 30 DIAS', 'pantalla', 3.87, 3.56, 2.97, 2.50, 3.00, 0.30, 0.26, 0.30, 0.25, 0.22, 0.25, 30),
      ('PLEX CTA C 30 DIAS', 'cuenta_completa', 4.64, 3.88, 3.23, 2.00, 2.40, 0.75, 0.73, 0.75, 0.63, 0.61, 0.63, 30),
      ('DRAMA BOX CTA C  30 DIAS', 'cuenta_completa', 4.10, 3.35, 2.79, 1.50, 1.80, 0.75, 0.80, 0.75, 0.63, 0.67, 0.63, 30),
      ('DEEZER  CTA C 30 DIAS', 'cuenta_completa', 3.09, 2.59, 2.16, 1.40, 1.68, 0.50, 0.41, 0.50, 0.42, 0.34, 0.42, 30),
      ('PAQUETE OFFICE 365 30 DIAS', 'pantalla', 3.57, 2.82, 2.35, 1.00, 1.20, 0.75, 0.87, 0.75, 0.63, 0.73, 0.63, 365),
      ('EMBY CTA C 30 DIAS', 'cuenta_completa', 5.17, 4.36, 3.63, 2.50, 3.00, 0.80, 0.56, 0.80, 0.67, 0.47, 0.67, 30),
      ('JELLYFIN CTA C 30 DIAS', 'cuenta_completa', 5.17, 4.36, 3.63, 2.50, 3.00, 0.80, 0.56, 0.80, 0.67, 0.47, 0.67, 30),
      ('COMBO 1 (NETFLIX +VIX)', 'servicio', 6.69, 5.48, 4.57, 2.70, 3.24, 1.20, 1.04, 1.20, 1.00, 0.87, 1.00, 30),
      ('COMBO 2 (NETFLIX+PRIME)', 'servicio', 7.22, 6.01, 5.01, 3.09, 3.71, 1.20, 1.10, 1.20, 1.00, 0.92, 1.00, 30),
      ('COMBO 3 (NETFLIX + MAX)', 'servicio', 6.72, 5.81, 4.84, 3.20, 3.84, 0.90, 1.07, 0.90, 0.75, 0.89, 0.75, 30),
      ('COMBO 4 (NETFLIX + DISNEY)', 'servicio', 8.75, 7.24, 6.04, 3.60, 4.32, 1.50, 1.42, 1.50, 1.25, 1.18, 1.25, 30),
      ('COMBO 5 (NETFLIX + PARAMOUNT)', 'servicio', 7.71, 6.20, 5.17, 3.10, 3.72, 1.50, 0.98, 1.50, 1.25, 0.82, 1.25, 30),
      ('COMBO 6 (NETFLIX +CRUNCHYROLL)', 'servicio', 7.71, 6.20, 5.17, 3.10, 3.72, 1.50, 0.98, 1.50, 1.25, 0.82, 1.25, 30),
      ('3 CUENTAS VIX 30 DIAS', 'cuenta_completa', 10.10, 7.10, 5.92, 1.50, 1.80, 3.00, 2.30, 3.00, 2.50, 1.92, 2.50, 30),
      ('3 CUENTAS MAX 30 DIAS', 'cuenta_completa', 18.41, 14.64, 12.21, 5.97, 7.16, 3.75, 3.73, 3.75, 3.13, 3.11, 3.13, 30),
      ('3 CUENTAS PRIME 30 DIAS', 'cuenta_completa', 18.62, 16.14, 13.46, 8.97, 10.76, 2.45, 2.93, 2.45, 2.04, 2.44, 2.04, 30),
      ('3 CUENTAS PARAMOUNT 30 DIAS', 'cuenta_completa', 18.61, 16.08, 13.41, 9.00, 10.79, 2.50, 2.79, 2.50, 2.08, 2.33, 2.08, 30),
      ('3 CUENTAS CRUNCHYROOL 30 DIAS', 'cuenta_completa', 14.31, 11.29, 9.42, 4.47, 5.36, 3.00, 2.93, 3.00, 2.50, 2.44, 2.50, 30)
    ) as t(
      nombre, tipo, pvp, rvd, usdt, costo_usdt, costo_bs,
      bs_pablo, bs_negocio, bs_gregory,
      usdt_pablo, usdt_negocio, usdt_gregory, duracion
    )
  loop
    v_cat_id := case 
      when r.tipo = 'cuenta_completa' then 'e23806c0-6237-4dfc-bf16-99a7e8e66b21'::uuid
      when r.tipo = 'servicio' then 'e23806c0-6237-4dfc-bf16-99a7e8e66b22'::uuid
      else 'e23806c0-6237-4dfc-bf16-99a7e8e66b20'::uuid
    end;

    -- Buscar si ya existe por nombre exacto o equivalencia
    v_prod_id := null;
    select id into v_prod_id from products
    where lower(trim(nombre)) = lower(trim(r.nombre))
       or (r.nombre = 'NETFLIX NORMAL 30 DIAS' and lower(trim(nombre)) in ('netflix', 'netflix normal'))
       or (r.nombre = 'NETFLIX PERFIL EXTRA NETFLIX 30 DIAS' and lower(trim(nombre)) in ('perfil extra netflix', 'netflix perfil extra', 'netflix perfil extra 30 dias'))
       or (r.nombre = 'DISNEY PERFIL 30 DIAS' and lower(trim(nombre)) in ('disney+ premium', 'disney premium'))
       or (r.nombre = 'MAX PERFIL ESTANDAR 30 DIAS' and lower(trim(nombre)) in ('max estándar', 'max estandar'))
       or (r.nombre = 'PRIME VIDEO PERFIL 30 DIAS' and lower(trim(nombre)) in ('amazon prime video', 'prime video'))
       or (r.nombre = 'VIX PERFIL 30 DIAS' and lower(trim(nombre)) in ('vix premium', 'vix'))
       or (r.nombre = 'CRUNCHYROLL PERFIL 30 DIA' and lower(trim(nombre)) in ('crunchyroll fan', 'crunchyroll'))
       or (r.nombre = 'PARAMOUNT PERFIL 30 DIAS' and lower(trim(nombre)) in ('paramount+', 'paramount'))
       or (r.nombre = 'TELELATINO PERFIL 30 DIAS' and lower(trim(nombre)) = 'telelatino')
       or (r.nombre = 'FLUJOTV PERFIL 30 DIAS' and lower(trim(nombre)) in ('flujo tv', 'flujotv'))
    order by id limit 1;

    if v_prod_id is not null then
      update products set
        precio_usd = r.pvp,
        precio_revendedor_usd = r.rvd,
        precio_binance_usd = r.usdt,
        costo_usdt = r.costo_usdt,
        costo_bs = r.costo_bs,
        comision_revendedor_usd = r.bs_pablo,
        ganancia_tienda_usd = round(r.bs_negocio + r.bs_gregory, 2),
        reparto_bs_pablo = r.bs_pablo,
        reparto_bs_negocio = r.bs_negocio,
        reparto_bs_gregory = r.bs_gregory,
        reparto_usdt_pablo = r.usdt_pablo,
        reparto_usdt_negocio = r.usdt_negocio,
        reparto_usdt_gregory = r.usdt_gregory,
        duracion_dias = r.duracion,
        garantia_dias = r.duracion,
        activo = true
      where id = v_prod_id;
    else
      insert into products (
        category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd,
        costo_usdt, costo_bs, comision_revendedor_usd, ganancia_tienda_usd,
        reparto_bs_pablo, reparto_bs_negocio, reparto_bs_gregory,
        reparto_usdt_pablo, reparto_usdt_negocio, reparto_usdt_gregory,
        duracion_dias, garantia_dias, activo
      ) values (
        v_cat_id, r.nombre, 'Servicio Oficial', r.tipo, r.pvp, r.rvd, r.usdt,
        r.costo_usdt, r.costo_bs, r.bs_pablo, round(r.bs_negocio + r.bs_gregory, 2),
        r.bs_pablo, r.bs_negocio, r.bs_gregory,
        r.usdt_pablo, r.usdt_negocio, r.usdt_gregory,
        r.duracion, r.duracion, true
      );
    end if;
  end loop;
end 76648;

-- 4. Tabla de Liquidaciones y Comisiones para Socios / Revendedores (Pablo, etc.)
create table if not exists partner_commissions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade unique,
  customer_id uuid references customers(id) on delete set null,
  vendedor_id uuid not null references customers(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  servicio_nombre text not null,
  tipo_venta text not null default 'autogestion_bs',
  metodo_origen text not null check (metodo_origen in ('bolivares', 'binance')) default 'bolivares',
  monto_cobrado_usd numeric(10,2) not null default 0.00,
  costo_proveedor_usd numeric(10,2) not null default 0.00,
  ganancia_vendedor_usd numeric(10,2) not null default 0.00,
  ganancia_gregory_usd numeric(10,2) not null default 0.00,
  ganancia_negocio_usd numeric(10,2) not null default 0.00,
  reserva_estrategica_usd numeric(10,2) not null default 0.00,
  caja_negocio_usd numeric(10,2) not null default 0.00,
  tasa_bs numeric(10,4) not null default 1.0000,
  ganancia_vendedor_bs numeric(12,2) not null default 0.00,
  ganancia_gregory_bs numeric(12,2) not null default 0.00,
  ganancia_negocio_bs numeric(12,2) not null default 0.00,
  reserva_estrategica_bs numeric(12,2) not null default 0.00,
  caja_negocio_bs numeric(12,2) not null default 0.00,
  estado text not null check (estado in ('pendiente', 'liquidada', 'cancelada')) default 'pendiente',
  liquidada_at timestamptz,
  referencia_pago text,
  notas text,
  created_at timestamptz default now()
);

-- Asegurar columnas si la tabla ya existía
alter table partner_commissions add column if not exists tipo_venta text not null default 'autogestion_bs';
alter table partner_commissions add column if not exists metodo_origen text not null default 'bolivares';
alter table partner_commissions add column if not exists ganancia_gregory_bs numeric(12,2) default 0.00;
alter table partner_commissions add column if not exists ganancia_negocio_bs numeric(12,2) default 0.00;
alter table partner_commissions add column if not exists reserva_estrategica_usd numeric(10,2) default 0.00;
alter table partner_commissions add column if not exists caja_negocio_usd numeric(10,2) default 0.00;
alter table partner_commissions add column if not exists reserva_estrategica_bs numeric(12,2) default 0.00;
alter table partner_commissions add column if not exists caja_negocio_bs numeric(12,2) default 0.00;

create index if not exists idx_partner_commissions_vendedor on partner_commissions(vendedor_id);
create index if not exists idx_partner_commissions_order on partner_commissions(order_id);
create index if not exists idx_partner_commissions_estado on partner_commissions(estado);

-- RLS para partner_commissions
alter table partner_commissions enable row level security;
drop policy if exists partner_commissions_admin_all on partner_commissions;
create policy partner_commissions_admin_all on partner_commissions for all to authenticated
using (is_admin()) with check (is_admin());

drop policy if exists partner_commissions_reseller_select on partner_commissions;
create policy partner_commissions_reseller_select on partner_commissions for select to authenticated
using (vendedor_id = (select auth.uid()));

-- 5. Función de cálculo y registro de comisión por orden aplicando las 4 Reglas Oficiales:
-- 1) Autogestión en Bs: Gregory y Pablo toman montos fijos; el resultante cubre Costo + Negocio.
-- 2) Pablo Revendedor: compra con descuento; solo gana Gregory y el resto va al Negocio.
-- 3) Binance USDT: Margen neto dividido en 3 partes iguales (Pablo, Gregory, Negocio).
-- 4) Reserva Estratégica: 10% de la ganancia neta del negocio se aparta para caídas y reposiciones.
create or replace function registrar_comision_orden(p_order_id uuid)
returns void
language plpgsql security definer set search_path = public as 77766
declare
  v_ord record;
  v_pablo_id uuid;
  v_seller_id uuid;
  v_prod record;
  v_pm record;
  v_rate numeric;
  v_is_binance boolean := false;
  v_tipo_venta text := 'autogestion_bs';
  v_metodo_tipo text := 'bolivares';
  v_cobrado numeric;
  v_costo numeric;
  v_gan_vendedor numeric := 0.00;
  v_gan_gregory numeric := 0.00;
  v_gan_negocio_total numeric := 0.00;
  v_reserva_estrategica numeric := 0.00;
  v_caja_negocio numeric := 0.00;
  v_is_pablo boolean := false;
  v_is_other_reseller boolean := false;
  v_margen_usdt numeric;
  v_un_tercio numeric;
begin
  select * into v_ord from orders where id = p_order_id;
  if not found or v_ord.estado not in ('entregado', 'pagado') then
    return;
  end if;

  -- 1. Identificar a Pablo Gonzalez (Socio Estratégico)
  select id into v_pablo_id from customers
  where lower(trim(email)) in ('pacun1989@gmail.com', 'pablo@gregoryizquierdo.xyz')
     or (lower(trim(nombre)) like '%pablo%' and es_revendedor = true)
  order by creado asc limit 1;

  -- 2. Identificar el vendedor asociado
  v_seller_id := v_ord.vendedor_id;
  if v_seller_id is null and v_ord.customer_id is not null then
    select vendedor_id into v_seller_id from customers where id = v_ord.customer_id;
  end if;

  -- ¿El comprador es Pablo comprando directamente desde su portal?
  if v_ord.customer_id = v_pablo_id or (v_seller_id = v_pablo_id and v_ord.customer_id = v_pablo_id) then
    v_is_pablo := true;
  end if;

  -- ¿El comprador es otro revendedor (Nelson, Josuanny, etc.)?
  if not v_is_pablo and v_ord.customer_id is not null then
    select coalesce(es_revendedor, false) into v_is_other_reseller from customers where id = v_ord.customer_id;
  end if;

  select bs_por_usd into v_rate from exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(v_ord.tasa_bs, v_rate, 50.00);

  select * into v_prod from products where id = v_ord.product_id;

  -- 3. Detectar si el pago es Binance (USDT)
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

  -- =========================================================================
  -- APLICACIÓN DE LAS 4 REGLAS FINANCIERAS
  -- =========================================================================

  if v_is_binance then
    -- REGLA 3: Compras vía Binance (USDT)
    -- (Precio de Venta USDT - Costo USDT) dividido en 3 partes iguales (Pablo, Gregory, Negocio)
    v_tipo_venta := 'binance_usdt';
    v_metodo_tipo := 'binance';
    v_cobrado := coalesce(v_ord.total_usd, v_prod.precio_binance_usd, v_prod.precio_usd, 0.00);
    v_costo   := coalesce(v_prod.costo_usdt, 0.00);

    v_margen_usdt := greatest(0.00, round(v_cobrado - v_costo, 2));
    v_un_tercio   := round(v_margen_usdt / 3.0, 2);

    v_gan_vendedor      := v_un_tercio;
    v_gan_gregory       := v_un_tercio;
    v_gan_negocio_total := round(v_margen_usdt - (v_un_tercio * 2), 2);

  elsif v_is_pablo then
    -- REGLA 2: Pablo compra directamente a precio de Revendedor
    -- Pablo ya se beneficia del precio mayorista (ganancia directa bash en comisiones).
    -- Se separa primero a Gregory y el resultante va al Negocio.
    v_tipo_venta := 'pablo_revendedor';
    v_metodo_tipo := 'bolivares';
    v_cobrado := coalesce(v_ord.total_usd, v_prod.precio_revendedor_usd, 0.00);
    v_costo   := coalesce(v_prod.costo_bs, v_prod.costo_usdt, 0.00);

    v_gan_vendedor      := 0.00;
    v_gan_gregory       := coalesce(v_prod.reparto_bs_gregory, 0.70);
    v_gan_negocio_total := greatest(0.00, round(v_cobrado - v_gan_gregory - v_costo, 2));

  elsif coalesce(v_is_other_reseller, false) then
    -- OTROS REVENDEDORES: Compran a precio preferencial y cobran su ganancia por fuera.
    v_tipo_venta := 'otro_revendedor';
    v_metodo_tipo := 'bolivares';
    v_cobrado := coalesce(v_ord.total_usd, v_prod.precio_revendedor_usd, 0.00);
    v_costo   := coalesce(v_prod.costo_bs, v_prod.costo_usdt, 0.00);

    v_gan_vendedor      := 0.00;
    v_gan_gregory       := coalesce(v_prod.reparto_bs_gregory, 0.70);
    v_gan_negocio_total := greatest(0.00, round(v_cobrado - v_gan_gregory - v_costo, 2));

  else
    -- REGLA 1: Cliente Independiente (Directo Tienda / Autogestión en Bolívares)
    -- El cliente paga PVP. Se toman primero los montos fijos de Gregory y Pablo.
    -- El resultante queda para el Negocio (Costo de la cuenta + Ganancia Negocio).
    v_tipo_venta := 'autogestion_bs';
    v_metodo_tipo := 'bolivares';
    v_cobrado := coalesce(v_ord.total_usd, v_prod.precio_usd, 0.00);
    v_costo   := coalesce(v_prod.costo_bs, v_prod.costo_usdt, 0.00);

    v_gan_vendedor := coalesce(v_prod.reparto_bs_pablo, 0.70);
    v_gan_gregory  := coalesce(v_prod.reparto_bs_gregory, 0.70);

    -- Resultante para el Negocio:
    v_gan_negocio_total := greatest(0.00, round(v_cobrado - v_gan_gregory - v_gan_vendedor - v_costo, 2));
  end if;

  -- REGLA 4: Apartar el 10% de la Ganancia Neta del Negocio como Reserva Estratégica
  v_reserva_estrategica := round(v_gan_negocio_total * 0.10, 2);
  v_caja_negocio        := round(v_gan_negocio_total - v_reserva_estrategica, 2);

  -- Registrar o vincular como socio beneficiario a Pablo (o el vendedor respectivo)
  if v_seller_id is null or v_seller_id = v_pablo_id then
    v_seller_id := coalesce(v_pablo_id, v_ord.customer_id);
  end if;

  insert into partner_commissions (
    order_id, customer_id, vendedor_id, product_id, servicio_nombre,
    tipo_venta, metodo_origen, monto_cobrado_usd, costo_proveedor_usd,
    ganancia_vendedor_usd, ganancia_gregory_usd, ganancia_negocio_usd,
    reserva_estrategica_usd, caja_negocio_usd,
    tasa_bs,
    ganancia_vendedor_bs, ganancia_gregory_bs, ganancia_negocio_bs,
    reserva_estrategica_bs, caja_negocio_bs,
    estado
  ) values (
    v_ord.id, v_ord.customer_id, v_seller_id, v_ord.product_id, coalesce(v_prod.nombre, 'Servicio Streaming'),
    v_tipo_venta, v_metodo_tipo, v_cobrado, v_costo,
    v_gan_vendedor, v_gan_gregory, v_gan_negocio_total,
    v_reserva_estrategica, v_caja_negocio,
    v_rate,
    round(v_gan_vendedor * v_rate, 2),
    round(v_gan_gregory * v_rate, 2),
    round(v_gan_negocio_total * v_rate, 2),
    round(v_reserva_estrategica * v_rate, 2),
    round(v_caja_negocio * v_rate, 2),
    'pendiente'
  ) on conflict (order_id) do update set
    vendedor_id = excluded.vendedor_id,
    tipo_venta = excluded.tipo_venta,
    metodo_origen = excluded.metodo_origen,
    monto_cobrado_usd = excluded.monto_cobrado_usd,
    costo_proveedor_usd = excluded.costo_proveedor_usd,
    ganancia_vendedor_usd = excluded.ganancia_vendedor_usd,
    ganancia_gregory_usd = excluded.ganancia_gregory_usd,
    ganancia_negocio_usd = excluded.ganancia_negocio_usd,
    reserva_estrategica_usd = excluded.reserva_estrategica_usd,
    caja_negocio_usd = excluded.caja_negocio_usd,
    tasa_bs = excluded.tasa_bs,
    ganancia_vendedor_bs = excluded.ganancia_vendedor_bs,
    ganancia_gregory_bs = excluded.ganancia_gregory_bs,
    ganancia_negocio_bs = excluded.ganancia_negocio_bs,
    reserva_estrategica_bs = excluded.reserva_estrategica_bs,
    caja_negocio_bs = excluded.caja_negocio_bs;
end;
77766;

create or replace function procesar_comision_socio_orden()
returns trigger
language plpgsql security definer set search_path = public as 77766
begin
  perform registrar_comision_orden(new.id);
  return new;
end;
77766;

drop trigger if exists trg_procesar_comision_socio_orden on orders;
create trigger trg_procesar_comision_socio_orden
after insert or update of estado on orders
for each row execute function procesar_comision_socio_orden();

-- 6. Retroalimentar comisiones de las órdenes existentes
do 77766
declare
  ord record;
begin
  for ord in select id from orders where estado in ('entregado', 'pagado')
  loop
    perform registrar_comision_orden(ord.id);
  end loop;
end 77766;

-- 7. RPC: liquidar_comisiones_socio(p_vendedor_id, p_referencia, p_notas)
create or replace function liquidar_comisiones_socio(
  p_vendedor_id uuid,
  p_referencia text,
  p_notas text default null
) returns jsonb
language plpgsql security definer set search_path = public as 77766
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
77766;

grant execute on function liquidar_comisiones_socio(uuid, text, text) to authenticated;


-- 8. RPC: my_reseller_clients() con filtrado estricto por revendedor
-- Para el Administrador (Gregory): ÚNICAMENTE devuelve los 2 clientes de DIRECTO TIENDA (Frederick Ramos y Douglas Parra)
-- Para cada Revendedor (Pablo, Nelson, Josuanny, Leandro): ÚNICAMENTE devuelve sus propios clientes asignados
create or replace function my_reseller_clients()
returns table (
  profile_id uuid,
  cliente_id uuid,
  cliente_nombre text,
  cliente_telefono text,
  cliente_email text,
  servicio text,
  plataforma text,
  nombre_perfil text,
  pin text,
  correo text,
  clave text,
  vence date,
  estado text
)
language plpgsql security definer set search_path = public, extensions as 78188
declare
  v_user_id uuid := auth.uid();
  v_is_adm boolean := false;
  v_seller_name text := null;
begin
  if v_user_id is null then return; end if;

  v_is_adm := is_admin();
  select nombre into v_seller_name from customers where id = v_user_id;

  if v_is_adm then
    -- Administrador: SOLO clientes y perfiles de DIRECTO TIENDA
    return query
    select distinct
      pi.id as profile_id,
      coalesce(c.id, o.customer_id) as cliente_id,
      coalesce(c.nombre, o_cust.nombre, 'Cliente Tienda') as cliente_nombre,
      coalesce(c.telefono, o_cust.telefono, '') as cliente_telefono,
      coalesce(c.email, o_cust.email, '') as cliente_email,
      coalesce(p.nombre, m.plataforma) as servicio,
      m.plataforma as plataforma,
      pi.nombre_perfil as nombre_perfil,
      case when pi.pin like 'enc:%' then dec_text(pi.pin) else pi.pin end as pin,
      m.correo as correo,
      case when m.clave like 'enc:%' then dec_text(m.clave) else m.clave end as clave,
      coalesce(pi.vence, o.vence) as vence,
      pi.estado as estado
    from profiles_inventory pi
    join mother_accounts m on m.id = pi.mother_id
    left join products p on p.id = pi.product_id
    left join customers c on c.id = pi.assigned_customer_id
    left join orders o on o.profile_id = pi.id and o.estado in ('entregado', 'pagado')
    left join customers o_cust on o_cust.id = o.customer_id
    where (
      (pi.vendedor_id is null and coalesce(c.vendedor_id, o.vendedor_id) is null)
      or lower(trim(coalesce(pi.vendedor, ''))) in ('directo tienda', 'tienda', 'directo')
      or lower(trim(coalesce(c.vendedor_nombre, o_cust.vendedor_nombre, ''))) in ('directo tienda', 'tienda', 'directo')
    )
    order by vence asc nulls last;

  else
    -- Revendedor (Pablo, Nelson, etc.): SOLO sus clientes asignados
    return query
    select distinct
      pi.id as profile_id,
      coalesce(c.id, o.customer_id) as cliente_id,
      coalesce(c.nombre, o_cust.nombre, 'Cliente Asignado') as cliente_nombre,
      coalesce(c.telefono, o_cust.telefono, '') as cliente_telefono,
      coalesce(c.email, o_cust.email, '') as cliente_email,
      coalesce(p.nombre, m.plataforma) as servicio,
      m.plataforma as plataforma,
      pi.nombre_perfil as nombre_perfil,
      case when pi.pin like 'enc:%' then dec_text(pi.pin) else pi.pin end as pin,
      m.correo as correo,
      case when m.clave like 'enc:%' then dec_text(m.clave) else m.clave end as clave,
      coalesce(pi.vence, o.vence) as vence,
      pi.estado as estado
    from profiles_inventory pi
    join mother_accounts m on m.id = pi.mother_id
    left join products p on p.id = pi.product_id
    left join customers c on c.id = pi.assigned_customer_id
    left join orders o on o.profile_id = pi.id and o.estado in ('entregado', 'pagado')
    left join customers o_cust on o_cust.id = o.customer_id
    where (
      pi.vendedor_id = v_user_id
      or c.vendedor_id = v_user_id
      or o.vendedor_id = v_user_id
      or (pi.vendedor is not null and v_seller_name is not null and lower(trim(pi.vendedor)) = lower(trim(v_seller_name)))
    )
    order by vence asc nulls last;
  end if;
end;
78188;

revoke execute on function my_reseller_clients() from public, anon;
grant execute on function my_reseller_clients() to authenticated;
