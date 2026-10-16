-- ==============================================================================
-- MIGRACIÓN 37: AJUSTE DE IDENTIFICACIÓN ADMINISTRADOR MASTER Y SOCIO REVENDEDOR
-- ==============================================================================
-- Asegura que:
-- 1. Gregory Izquierdo tenga código ADM:001 (Administrador Master Central) y NUNCA CLT:001.
-- 2. Pablo González tenga código oficial PABLO (Socio Revendedor) con es_revendedor = true.
-- ==============================================================================

begin;

-- 1. Actualizar cuenta de Gregory Izquierdo (Master Admin)
update customers
set codigo_identificacion = 'ADM:001',
    es_revendedor = false,
    nombre = coalesce(nullif(nombre, ''), 'Gregory Izquierdo (Master Admin)')
where lower(trim(email)) in (
  'emprendimientogregoryizquierdo@gmail.com',
  'gregoryizquierdo1990@gmail.com'
);

-- 2. Asegurar que Pablo Gonzalez sea formalmente socio revendedor con código PABLO
update customers
set codigo_identificacion = 'PABLO',
    es_revendedor = true,
    nombre = coalesce(nullif(nombre, ''), 'Pablo Gonzalez')
where lower(trim(email)) in ('pacun1989@gmail.com', 'pacun1989@gmai.com')
   or telefono like '%4129130080%';

-- 3. Asegurar columnas de registro de liquidaciones en partner_commissions
alter table partner_commissions add column if not exists metodo_pago text;
alter table partner_commissions add column if not exists pagado_usd numeric(10,2);
alter table partner_commissions add column if not exists pagado_bs numeric(12,2);
alter table partner_commissions add column if not exists pagado_gregory_usd numeric(10,2);
alter table partner_commissions add column if not exists pagado_gregory_bs numeric(12,2);

commit;
