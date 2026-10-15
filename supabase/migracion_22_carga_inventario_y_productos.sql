-- ==============================================================================
-- MIGRACIÓN 22: CARGA INICIAL DE CATÁLOGO E INVENTARIO (DATOS REALES)
-- Emprendimiento Gregory Izquierdo
-- Total: 10 Productos, 32 Cuentas Madre, 71 Perfiles (46 Vendidos + 25 Libres)
-- Cifrado automático: Las contraseñas y PINs se cifran mediante pgcrypto.
-- Idempotente: Es 100% seguro ejecutarlo varias veces sin duplicar registros.
-- ==============================================================================

begin;

-- 1. CATEGORÍA PRINCIPAL: Perfiles
insert into categories (id, nombre, descripcion, activo, orden) values
  ('e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Perfiles', 'Perfiles de Streaming individuales y compartidos', true, 1)
on conflict (id) do update set nombre = 'Perfiles', activo = true;

-- 2. ACTUALIZAR O REGISTRAR LOS 10 PRODUCTOS
-- Producto: Netflix (Para servicio: NETFLIX)
update products set nombre = 'Netflix', descripcion = 'Perfil con PIN Netflix 4K UHD', precio_usd = 5.0, precio_revendedor_usd = 4.5, activo = true, orden = 1 where id = '817719d3-2adf-4010-b2c8-35c879867ca6';
insert into products (id, category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, duracion_dias, pantallas, activo, orden)
select '817719d3-2adf-4010-b2c8-35c879867ca6', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Netflix', 'Perfil con PIN Netflix 4K UHD', 'pantalla', 5.0, 4.5, 30, 1, true, 1
where not exists (select 1 from products where id = '817719d3-2adf-4010-b2c8-35c879867ca6');
-- Producto: Perfil Extra Netflix (Para servicio: PERFIL EXTRA NETFLIX)
insert into products (category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, duracion_dias, pantallas, activo, orden)
select 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Perfil Extra Netflix', 'Perfil Extra Oficial Netflix (Directo a tu correo personal)', 'pantalla', 4.5, 4.0, 30, 1, true, 2
where not exists (select 1 from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')));
-- Producto: Disney+ Premium (Para servicio: DISNEY PREMIUM)
insert into products (category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, duracion_dias, pantallas, activo, orden)
select 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Disney+ Premium', 'Pantalla Disney+ Premium 4K UHD con PIN', 'pantalla', 3.5, 3.0, 30, 1, true, 3
where not exists (select 1 from products where lower(trim(nombre)) = lower(trim('Disney+ Premium')));
-- Producto: Max Estándar (Para servicio: MAX ESTANDAR)
insert into products (category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, duracion_dias, pantallas, activo, orden)
select 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Max Estándar', 'Pantalla Max (HBO) Estándar Full HD con PIN', 'pantalla', 3.5, 3.0, 30, 1, true, 4
where not exists (select 1 from products where lower(trim(nombre)) = lower(trim('Max Estándar')));
-- Producto: Amazon Prime Video (Para servicio: PRIME VIDEO)
insert into products (category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, duracion_dias, pantallas, activo, orden)
select 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Amazon Prime Video', 'Pantalla Amazon Prime Video con PIN', 'pantalla', 3.0, 2.5, 30, 1, true, 5
where not exists (select 1 from products where lower(trim(nombre)) = lower(trim('Amazon Prime Video')));
-- Producto: ViX Premium (Para servicio: VIX PREMIUM)
insert into products (category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, duracion_dias, pantallas, activo, orden)
select 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'ViX Premium', 'Pantalla ViX Premium Liga y Novelas', 'pantalla', 3.0, 2.5, 30, 1, true, 6
where not exists (select 1 from products where lower(trim(nombre)) = lower(trim('ViX Premium')));
-- Producto: Crunchyroll Fan (Para servicio: CRUNCHYROLL)
insert into products (category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, duracion_dias, pantallas, activo, orden)
select 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Crunchyroll Fan', 'Pantalla Crunchyroll Mega Fan Anime HD', 'pantalla', 3.0, 2.5, 30, 1, true, 7
where not exists (select 1 from products where lower(trim(nombre)) = lower(trim('Crunchyroll Fan')));
-- Producto: Paramount+ (Para servicio: PARAMOUNT)
insert into products (category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, duracion_dias, pantallas, activo, orden)
select 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Paramount+', 'Pantalla Paramount+ Oficial con PIN', 'pantalla', 3.0, 2.5, 30, 1, true, 8
where not exists (select 1 from products where lower(trim(nombre)) = lower(trim('Paramount+')));
-- Producto: Telelatino (Para servicio: TELELATINO)
insert into products (category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, duracion_dias, pantallas, activo, orden)
select 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Telelatino', 'Acceso Telelatino Canales en Vivo y Series', 'pantalla', 3.5, 3.0, 30, 1, true, 9
where not exists (select 1 from products where lower(trim(nombre)) = lower(trim('Telelatino')));
-- Producto: Flujo TV (Para servicio: FLUJOTV)
insert into products (category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, duracion_dias, pantallas, activo, orden)
select 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Flujo TV', 'Cuenta / Pantalla Flujo TV Canales en Vivo', 'pantalla', 3.5, 3.0, 30, 1, true, 10
where not exists (select 1 from products where lower(trim(nombre)) = lower(trim('Flujo TV')));

-- 3. CARGAR LAS 32 CUENTAS MADRE
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'fredyvegagoat+36mue4982@gmail.com', '600600a', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'carom8780+aronmsch@gmail.com', 'US920040', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'villanetservi+m008@gmail.com', 'extre2026z2', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'samudxw+ynphb65e@gmail.com', '652345us', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'wvarne7+v666mz7@gmail.com', '4879621', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'hzxrp.ar@mmextra.xyz', '535662GBB', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'solucionservinet+ext603@gmail.com', 'maxter1010', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'eslelozada+gyt6h@gmail.com', '1002003pt', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'wvarne7+eam3mca@gmail.com', '632590', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'villanetservi+ext-ah4@gmail.com', '105510', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'Catos43572+tt8h7h65bh@zohomail.com', '15151510', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'cahrypya+6r8@gmail.com', '854623br', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'etankpra+x0nhrqqy@gmail.com', '94863r1', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'possub42+atilla_gs@gmail.com', 'FR6325c1', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'carat1045.us@atlantispose.com', 'maxterz1', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'fus5katu+e1sjbux@gmail.com', 'BR632590', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'possub20+marciano71@gmail.com', 'MX632590', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PERFIL EXTRA NETFLIX', 'cuentavillanet+3093@gmail.com', 'maxter2c1', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('NETFLIX', 'possub41+4uph8e@gmail.com', 'BR9293', 5, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('NETFLIX', 'dyny-94.skate.AR@xposemail.com', 'XZ8585', 5, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('MAX ESTANDAR', 'leokairosmarket24@gmail.com', 'max12platino', 5, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('DISNEY PREMIUM', 'gotimotthy675@sclubint.com', 'Cuenta1234*', 7, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PRIME VIDEO', 'bssgg927@cruxitoprime.lat', 'amazon00', 5, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('VIX PREMIUM', 'tataarizt@gmail.com', 'vixvix1234', 5, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('CRUNCHYROLL', 'sabyer77@sayulive.com', '3255665', 5, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('PARAMOUNT', 'sjnj55sal@mirai.re', 'parampe33@', 6, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('TELELATINO', 'yynqkh', 'maxter1112', 5, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('FLUJOTV', 'Canva001', 'maxter1234', 5, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('FLUJOTV', 'Canva002', 'maxter1235', 5, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('FLUJOTV', 'Canva003', 'maxter1236', 5, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('FLUJOTV', 'R2023Gabriel', 'digital', 5, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;
insert into mother_accounts (plataforma, correo, clave, max_perfiles, activa)
values ('FLUJOTV', 'Conec744', 'matrix', 1, true)
on conflict (plataforma, correo) do update set clave = excluded.clave, max_perfiles = excluded.max_perfiles, activa = true;

-- 4. CARGAR LOS 71 PERFILES DE INVENTARIO
-- (46 ocupados con vencimiento real y 25 libres listos para venta en la tienda)
-- Fila 2: PERFIL EXTRA NETFLIX | fredyvegagoat+36mue4982@gmail.com | NANI2 (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'NANI2', null, 'PABLO', '2026-10-30'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'fredyvegagoat+36mue4982@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('NANI2'))
);
-- Fila 3: PERFIL EXTRA NETFLIX | carom8780+aronmsch@gmail.com | melyta1 (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'melyta1', null, 'PABLO', '2026-11-13'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'carom8780+aronmsch@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('melyta1'))
);
-- Fila 4: PERFIL EXTRA NETFLIX | villanetservi+m008@gmail.com | nani 1 (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'nani 1', null, 'PABLO', '2026-10-30'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'villanetservi+m008@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('nani 1'))
);
-- Fila 5: PERFIL EXTRA NETFLIX | samudxw+ynphb65e@gmail.com | ENDRYS (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'ENDRYS', null, 'PABLO', '2026-11-05'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'samudxw+ynphb65e@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('ENDRYS'))
);
-- Fila 6: PERFIL EXTRA NETFLIX | wvarne7+v666mz7@gmail.com | landys (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'landys', null, 'PABLO', '2026-11-13'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'wvarne7+v666mz7@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('landys'))
);
-- Fila 7: PERFIL EXTRA NETFLIX | hzxrp.ar@mmextra.xyz | melyta2 (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'melyta2', null, 'PABLO', '2026-11-13'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'hzxrp.ar@mmextra.xyz' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('melyta2'))
);
-- Fila 8: PERFIL EXTRA NETFLIX | solucionservinet+ext603@gmail.com | marianne (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'marianne', null, 'PABLO', '2026-10-17'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'solucionservinet+ext603@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('marianne'))
);
-- Fila 9: PERFIL EXTRA NETFLIX | eslelozada+gyt6h@gmail.com | evert (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'evert', null, 'PABLO', '2026-11-11'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'eslelozada+gyt6h@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('evert'))
);
-- Fila 10: PERFIL EXTRA NETFLIX | wvarne7+eam3mca@gmail.com | marianela espinoza (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'marianela espinoza', null, 'PABLO', '2026-11-08'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'wvarne7+eam3mca@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('marianela espinoza'))
);
-- Fila 11: PERFIL EXTRA NETFLIX | villanetservi+ext-ah4@gmail.com | silvia (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'silvia', null, 'JOSUANNY', '2026-10-17'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'villanetservi+ext-ah4@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('silvia'))
);
-- Fila 12: PERFIL EXTRA NETFLIX | Catos43572+tt8h7h65bh@zohomail.com | yosestyle (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'yosestyle', null, 'JOSUANNY', '2026-10-17'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'Catos43572+tt8h7h65bh@zohomail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('yosestyle'))
);
-- Fila 13: PERFIL EXTRA NETFLIX | cahrypya+6r8@gmail.com | yosemit (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'yosemit', null, 'PABLO', '2026-10-15'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'cahrypya+6r8@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('yosemit'))
);
-- Fila 14: PERFIL EXTRA NETFLIX | etankpra+x0nhrqqy@gmail.com | elis (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'elis', null, 'PABLO', '2026-10-29'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'etankpra+x0nhrqqy@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('elis'))
);
-- Fila 15: PERFIL EXTRA NETFLIX | possub42+atilla_gs@gmail.com | carmen nacero (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'carmen nacero', null, 'NELSON', '2026-11-06'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'possub42+atilla_gs@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('carmen nacero'))
);
-- Fila 16: PERFIL EXTRA NETFLIX | carat1045.us@atlantispose.com | keiber nacero (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'keiber nacero', null, 'NELSON', '2026-11-06'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'carat1045.us@atlantispose.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('keiber nacero'))
);
-- Fila 17: PERFIL EXTRA NETFLIX | fus5katu+e1sjbux@gmail.com | diogenes 1 (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'diogenes 1', null, 'PABLO', '2026-11-11'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'fus5katu+e1sjbux@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('diogenes 1'))
);
-- Fila 18: PERFIL EXTRA NETFLIX | possub20+marciano71@gmail.com | diogenes 2 (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'diogenes 2', null, 'PABLO', '2026-11-11'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'possub20+marciano71@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('diogenes 2'))
);
-- Fila 19: PERFIL EXTRA NETFLIX | cuentavillanet+3093@gmail.com | Perfil Extra 1 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil Extra 1', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'PERFIL EXTRA NETFLIX' and correo = 'cuentavillanet+3093@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Perfil Extra Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil Extra 1'))
);
-- Fila 20: NETFLIX | possub41+4uph8e@gmail.com | Perfil 1 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 1', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'NETFLIX' and correo = 'possub41+4uph8e@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 1'))
);
-- Fila 21: NETFLIX | possub41+4uph8e@gmail.com | Perfil 2 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 2', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'NETFLIX' and correo = 'possub41+4uph8e@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 2'))
);
-- Fila 22: NETFLIX | possub41+4uph8e@gmail.com | Perfil 3 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 3', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'NETFLIX' and correo = 'possub41+4uph8e@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 3'))
);
-- Fila 23: NETFLIX | possub41+4uph8e@gmail.com | Perfil 4 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 4', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'NETFLIX' and correo = 'possub41+4uph8e@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 4'))
);
-- Fila 24: NETFLIX | possub41+4uph8e@gmail.com | Perfil 5 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 5', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'NETFLIX' and correo = 'possub41+4uph8e@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 5'))
);
-- Fila 25: NETFLIX | dyny-94.skate.AR@xposemail.com | ariana herrera (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'ariana herrera', '1937', 'PABLO', '2026-10-24'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'NETFLIX' and correo = 'dyny-94.skate.AR@xposemail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('ariana herrera'))
);
-- Fila 26: NETFLIX | dyny-94.skate.AR@xposemail.com | Perfil 2 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 2', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'NETFLIX' and correo = 'dyny-94.skate.AR@xposemail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 2'))
);
-- Fila 27: NETFLIX | dyny-94.skate.AR@xposemail.com | Perfil 3 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 3', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'NETFLIX' and correo = 'dyny-94.skate.AR@xposemail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 3'))
);
-- Fila 28: NETFLIX | dyny-94.skate.AR@xposemail.com | Perfil 4 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 4', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'NETFLIX' and correo = 'dyny-94.skate.AR@xposemail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 4'))
);
-- Fila 29: NETFLIX | dyny-94.skate.AR@xposemail.com | Perfil 5 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 5', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'NETFLIX' and correo = 'dyny-94.skate.AR@xposemail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Netflix')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 5'))
);
-- Fila 30: MAX ESTANDAR | leokairosmarket24@gmail.com | endris (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'endris', '5057', 'PABLO', '2026-11-11'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'MAX ESTANDAR' and correo = 'leokairosmarket24@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Max Estándar')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('endris'))
);
-- Fila 31: MAX ESTANDAR | leokairosmarket24@gmail.com | isaac (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'isaac', '2957', 'PABLO', '2026-10-16'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'MAX ESTANDAR' and correo = 'leokairosmarket24@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Max Estándar')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('isaac'))
);
-- Fila 32: MAX ESTANDAR | leokairosmarket24@gmail.com | angelo (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'angelo', '7550', 'PABLO', '2026-10-22'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'MAX ESTANDAR' and correo = 'leokairosmarket24@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Max Estándar')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('angelo'))
);
-- Fila 33: MAX ESTANDAR | leokairosmarket24@gmail.com | vanessa (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'vanessa', '0705', 'PABLO', '2026-11-01'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'MAX ESTANDAR' and correo = 'leokairosmarket24@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Max Estándar')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('vanessa'))
);
-- Fila 34: MAX ESTANDAR | leokairosmarket24@gmail.com | Perfil 5 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 5', '0468', null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'MAX ESTANDAR' and correo = 'leokairosmarket24@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Max Estándar')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 5'))
);
-- Fila 35: DISNEY PREMIUM | gotimotthy675@sclubint.com | angelo (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'angelo', '1611', 'PABLO', '2026-10-17'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'DISNEY PREMIUM' and correo = 'gotimotthy675@sclubint.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Disney+ Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('angelo'))
);
-- Fila 36: DISNEY PREMIUM | gotimotthy675@sclubint.com | isaac (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'isaac', '2957', 'PABLO', '2026-10-16'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'DISNEY PREMIUM' and correo = 'gotimotthy675@sclubint.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Disney+ Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('isaac'))
);
-- Fila 37: DISNEY PREMIUM | gotimotthy675@sclubint.com | armando (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'armando', '5106', 'NELSON', '2026-10-24'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'DISNEY PREMIUM' and correo = 'gotimotthy675@sclubint.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Disney+ Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('armando'))
);
-- Fila 38: DISNEY PREMIUM | gotimotthy675@sclubint.com | roymel (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'roymel', '6018', 'PABLO', '2026-10-16'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'DISNEY PREMIUM' and correo = 'gotimotthy675@sclubint.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Disney+ Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('roymel'))
);
-- Fila 39: DISNEY PREMIUM | gotimotthy675@sclubint.com | yuglis perez (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'yuglis perez', '2751', 'PABLO', '2026-10-24'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'DISNEY PREMIUM' and correo = 'gotimotthy675@sclubint.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Disney+ Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('yuglis perez'))
);
-- Fila 40: DISNEY PREMIUM | gotimotthy675@sclubint.com | douglas parra (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'douglas parra', '2323', 'PABLO', '2026-10-21'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'DISNEY PREMIUM' and correo = 'gotimotthy675@sclubint.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Disney+ Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('douglas parra'))
);
-- Fila 41: DISNEY PREMIUM | gotimotthy675@sclubint.com | fernisbel (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'fernisbel', '6838', 'PABLO', '2026-11-07'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'DISNEY PREMIUM' and correo = 'gotimotthy675@sclubint.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Disney+ Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('fernisbel'))
);
-- Fila 42: PRIME VIDEO | bssgg927@cruxitoprime.lat | maria victoria (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'maria victoria', null, 'PABLO', '2026-10-17'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PRIME VIDEO' and correo = 'bssgg927@cruxitoprime.lat' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Amazon Prime Video')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('maria victoria'))
);
-- Fila 43: PRIME VIDEO | bssgg927@cruxitoprime.lat | Perfil 2 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 2', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'PRIME VIDEO' and correo = 'bssgg927@cruxitoprime.lat' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Amazon Prime Video')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 2'))
);
-- Fila 44: PRIME VIDEO | bssgg927@cruxitoprime.lat | Perfil 3 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 3', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'PRIME VIDEO' and correo = 'bssgg927@cruxitoprime.lat' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Amazon Prime Video')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 3'))
);
-- Fila 45: PRIME VIDEO | bssgg927@cruxitoprime.lat | Perfil 4 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 4', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'PRIME VIDEO' and correo = 'bssgg927@cruxitoprime.lat' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Amazon Prime Video')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 4'))
);
-- Fila 46: PRIME VIDEO | bssgg927@cruxitoprime.lat | Perfil 5 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 5', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'PRIME VIDEO' and correo = 'bssgg927@cruxitoprime.lat' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Amazon Prime Video')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 5'))
);
-- Fila 47: VIX PREMIUM | tataarizt@gmail.com | Perfil 1 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 1', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'VIX PREMIUM' and correo = 'tataarizt@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('ViX Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 1'))
);
-- Fila 48: VIX PREMIUM | tataarizt@gmail.com | Perfil 2 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 2', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'VIX PREMIUM' and correo = 'tataarizt@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('ViX Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 2'))
);
-- Fila 49: VIX PREMIUM | tataarizt@gmail.com | Perfil 3 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 3', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'VIX PREMIUM' and correo = 'tataarizt@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('ViX Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 3'))
);
-- Fila 50: VIX PREMIUM | tataarizt@gmail.com | Perfil 4 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 4', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'VIX PREMIUM' and correo = 'tataarizt@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('ViX Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 4'))
);
-- Fila 51: VIX PREMIUM | tataarizt@gmail.com | Perfil 5 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 5', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'VIX PREMIUM' and correo = 'tataarizt@gmail.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('ViX Premium')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 5'))
);
-- Fila 52: CRUNCHYROLL | sabyer77@sayulive.com | dirwing Caraballo (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'dirwing Caraballo', null, 'PABLO', '2026-10-22'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'CRUNCHYROLL' and correo = 'sabyer77@sayulive.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Crunchyroll Fan')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('dirwing Caraballo'))
);
-- Fila 53: CRUNCHYROLL | sabyer77@sayulive.com | frederick longa (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'frederick longa', null, 'PABLO', '2026-11-10'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'CRUNCHYROLL' and correo = 'sabyer77@sayulive.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Crunchyroll Fan')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('frederick longa'))
);
-- Fila 54: CRUNCHYROLL | sabyer77@sayulive.com | JOSLEX (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'JOSLEX', null, 'LEANDRO', '2026-11-10'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'CRUNCHYROLL' and correo = 'sabyer77@sayulive.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Crunchyroll Fan')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('JOSLEX'))
);
-- Fila 55: CRUNCHYROLL | sabyer77@sayulive.com | Perfil 4 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 4', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'CRUNCHYROLL' and correo = 'sabyer77@sayulive.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Crunchyroll Fan')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 4'))
);
-- Fila 56: CRUNCHYROLL | sabyer77@sayulive.com | Perfil 5 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 5', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'CRUNCHYROLL' and correo = 'sabyer77@sayulive.com' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Crunchyroll Fan')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 5'))
);
-- Fila 57: PARAMOUNT | sjnj55sal@mirai.re | carlos (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'carlos', null, 'PABLO', '2026-10-19'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PARAMOUNT' and correo = 'sjnj55sal@mirai.re' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Paramount+')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('carlos'))
);
-- Fila 58: PARAMOUNT | sjnj55sal@mirai.re | gepe (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'gepe', null, 'PABLO', '2026-10-19'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PARAMOUNT' and correo = 'sjnj55sal@mirai.re' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Paramount+')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('gepe'))
);
-- Fila 59: PARAMOUNT | sjnj55sal@mirai.re | vanessa (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'vanessa', null, 'PABLO', '2026-10-25'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'PARAMOUNT' and correo = 'sjnj55sal@mirai.re' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Paramount+')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('vanessa'))
);
-- Fila 60: PARAMOUNT | sjnj55sal@mirai.re | Perfil 4 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 4', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'PARAMOUNT' and correo = 'sjnj55sal@mirai.re' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Paramount+')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 4'))
);
-- Fila 61: PARAMOUNT | sjnj55sal@mirai.re | Perfil 5 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 5', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'PARAMOUNT' and correo = 'sjnj55sal@mirai.re' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Paramount+')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 5'))
);
-- Fila 62: PARAMOUNT | sjnj55sal@mirai.re | Perfil 6 (disponible)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 6', null, null, null, 'disponible'
from (select id from mother_accounts where plataforma = 'PARAMOUNT' and correo = 'sjnj55sal@mirai.re' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Paramount+')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 6'))
);
-- Fila 63: TELELATINO | yynqkh | MANUEL (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'MANUEL', null, 'PABLO', '2026-10-25'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'TELELATINO' and correo = 'yynqkh' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Telelatino')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('MANUEL'))
);
-- Fila 64: TELELATINO | yynqkh | tony (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'tony', null, 'PABLO', '2026-11-11'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'TELELATINO' and correo = 'yynqkh' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Telelatino')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('tony'))
);
-- Fila 65: TELELATINO | yynqkh | Maria Rodríguez (Tony) (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Maria Rodríguez (Tony)', null, 'PABLO', '2027-04-14'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'TELELATINO' and correo = 'yynqkh' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Telelatino')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Maria Rodríguez (Tony)'))
);
-- Fila 66: FLUJOTV | Canva001 | enyerber (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'enyerber', null, 'PABLO', '2026-11-12'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'FLUJOTV' and correo = 'Canva001' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Flujo TV')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('enyerber'))
);
-- Fila 67: FLUJOTV | Canva002 | melvin 1 (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'melvin 1', null, 'PABLO', '2026-10-15'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'FLUJOTV' and correo = 'Canva002' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Flujo TV')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('melvin 1'))
);
-- Fila 68: FLUJOTV | Canva003 | gabriel (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'gabriel', null, 'PABLO', '2026-10-17'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'FLUJOTV' and correo = 'Canva003' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Flujo TV')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('gabriel'))
);
-- Fila 69: FLUJOTV | R2023Gabriel | pablo (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'pablo', null, 'PABLO', '2026-10-17'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'FLUJOTV' and correo = 'R2023Gabriel' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Flujo TV')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('pablo'))
);
-- Fila 70: FLUJOTV | R2023Gabriel | melvin 2 (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'melvin 2', null, 'PABLO', '2026-11-01'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'FLUJOTV' and correo = 'R2023Gabriel' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Flujo TV')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('melvin 2'))
);
-- Fila 71: FLUJOTV | R2023Gabriel | MARIA (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'MARIA', null, 'PABLO', '2026-10-17'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'FLUJOTV' and correo = 'R2023Gabriel' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Flujo TV')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('MARIA'))
);
-- Fila 72: FLUJOTV | Conec744 | Perfil 1 (vendido)
insert into profiles_inventory (mother_id, product_id, nombre_perfil, pin, vendedor, vence, estado)
select m.id, p.id, 'Perfil 1', null, 'PABLO', '2026-10-29'::date, 'vendido'
from (select id from mother_accounts where plataforma = 'FLUJOTV' and correo = 'Conec744' limit 1) m,
     (select id from products where lower(trim(nombre)) = lower(trim('Flujo TV')) limit 1) p
where not exists (
  select 1 from profiles_inventory pi
  where pi.mother_id = m.id and lower(trim(pi.nombre_perfil)) = lower(trim('Perfil 1'))
);

commit;

-- Resumen de verificación final
select p.nombre as producto, count(pi.id) as total_perfiles,
       count(pi.id) filter (where pi.estado = 'disponible') as disponibles,
       count(pi.id) filter (where pi.estado = 'vendido') as vendidos
from products p
left join profiles_inventory pi on pi.product_id = p.id
group by p.nombre, p.orden
order by coalesce(p.orden, 99);