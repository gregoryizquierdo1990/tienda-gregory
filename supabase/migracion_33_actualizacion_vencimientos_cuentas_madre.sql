-- ==============================================================================
-- MIGRACIÓN 33: ACTUALIZACIÓN DE VENCIMIENTOS Y PROVEEDORES DE CUENTAS MADRE
-- Emprendimiento Gregory Izquierdo - Control de Inventario y Calendario
-- ==============================================================================

begin;

-- 1. PERFIL EXTRA NETFLIX (Proveedor Alexander Ojeda)
update mother_accounts
set vence = '2026-10-18'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('fredyvegagoat+36mue4982@gmail.com');

update mother_accounts
set vence = '2026-11-13'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('carom8780+aronmsch@gmail.com');

update mother_accounts
set vence = '2026-11-02'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('villanetservi+m008@gmail.com');

update mother_accounts
set vence = '2026-10-18'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('samudxw+ynphb65e@gmail.com');

update mother_accounts
set vence = '2026-11-14'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('wvarne7+v666mz7@gmail.com');

update mother_accounts
set vence = '2026-11-10'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('hzxrp.ar@mmextra.xyz');

update mother_accounts
set vence = '2026-11-13'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('solucionservinet+ext603@gmail.com');

update mother_accounts
set vence = '2026-11-02'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('eslelozada+gyt6h@gmail.com');

update mother_accounts
set vence = '2026-10-19'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('wvarne7+eam3mca@gmail.com');

update mother_accounts
set vence = '2026-11-07'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('villanetservi+ext-ah4@gmail.com');

update mother_accounts
set vence = '2026-11-07'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('Catos43572+tt8h7h65bh@zohomail.com');

update mother_accounts
set vence = '2026-11-07'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('cahrypya+6r8@gmail.com');

update mother_accounts
set vence = '2026-10-29'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('etankpra+x0nhrqqy@gmail.com');

update mother_accounts
set vence = '2026-11-06'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('possub42+atilla_gs@gmail.com');

update mother_accounts
set vence = '2026-11-06'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('carat1045.us@atlantispose.com');

update mother_accounts
set vence = '2026-11-11'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('fus5katu+e1sjbux@gmail.com');

update mother_accounts
set vence = '2026-11-11'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('possub20+marciano71@gmail.com');

update mother_accounts
set vence = '2026-11-06'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('cuentavillanet+3093@gmail.com');

-- 2. NETFLIX CUENTAS COMPLETAS (Proveedor Alexander Ojeda)
update mother_accounts
set vence = '2026-10-30'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('possub41+4uph8e@gmail.com');

update mother_accounts
set vence = '2026-11-12'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('dyny-94.skate.AR@xposemail.com');

-- 3. DISNEY PREMIUM (Proveedor ALEGG)
update mother_accounts
set vence = '2026-11-09'::date, proveedor = 'ALEGG'
where lower(trim(correo)) = lower('gotimotthy675@sclubint.com');

-- 4. PRIME VIDEO (Proveedor MOVIAX)
update mother_accounts
set vence = '2026-11-12'::date, proveedor = 'MOVIAX'
where lower(trim(correo)) = lower('bssgg927@cruxitoprime.lat');

-- 5. VIX PREMIUM (Fecha asignada, sin proveedor como solicitó el usuario)
update mother_accounts
set vence = '2026-11-09'::date
where lower(trim(correo)) = lower('tataarizt@gmail.com');

-- 6. CRUNCHYROLL (Proveedor MOVIAX)
update mother_accounts
set vence = '2026-10-18'::date, proveedor = 'MOVIAX'
where lower(trim(correo)) = lower('sabyer77@sayulive.com');

-- 7. PARAMOUNT (Proveedor Alexander Ojeda)
update mother_accounts
set vence = '2026-10-20'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('sjnj55sal@mirai.re');

-- 8. TELELATINO (Proveedor Alexander Ojeda)
update mother_accounts
set vence = '2026-11-30'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('yynqkh');

-- 9. FLUJOTV (Proveedor Alexander Ojeda)
update mother_accounts
set vence = '2026-11-18'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('Canva001');

update mother_accounts
set vence = '2026-11-18'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('R2023Gabriel');

update mother_accounts
set vence = '2026-11-07'::date, proveedor = 'ALEXANDER OJEDA'
where lower(trim(correo)) = lower('Conec744');

-- NOTA: Cuentas sin proveedor ni fecha especificados (MAX ESTANDAR: leokairosmarket24@gmail.com,
-- FLUJOTV: Canva002 y Canva003) se mantienen sin modificaciones para ser asignadas al renovar.

commit;
