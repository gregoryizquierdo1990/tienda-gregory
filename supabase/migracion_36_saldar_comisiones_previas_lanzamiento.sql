-- ==============================================================================
-- MIGRACIÓN 36: SALDADO DE COMISIONES PREVIAS AL LANZAMIENTO OFICIAL
-- Marca como liquidadas todas las comisiones generadas hasta el 15/10/2026
-- Las liquidaciones oficiales en plataforma arrancan en limpio desde el 16/10/2026
-- ==============================================================================

begin;

-- 1. Asegurar columnas de registro de pagos si no existen
alter table partner_commissions add column if not exists metodo_pago text;
alter table partner_commissions add column if not exists pagado_usd numeric(10,2);
alter table partner_commissions add column if not exists pagado_bs numeric(12,2);
alter table partner_commissions add column if not exists pagado_gregory_usd numeric(10,2);
alter table partner_commissions add column if not exists pagado_gregory_bs numeric(12,2);

-- 2. Actualizar todas las comisiones pendientes previas como liquidadas
update partner_commissions
set estado = 'liquidada',
    liquidada_at = coalesce(liquidada_at, now()),
    referencia_pago = coalesce(referencia_pago, 'SALDADO-PREVIO-LANZAMIENTO-15-OCT'),
    notas = coalesce(notas, 'Liquidado previo a puesta en marcha oficial (acuerdo externo)'),
    metodo_pago = coalesce(metodo_pago, 'Acuerdo externo previo a plataforma'),
    pagado_usd = coalesce(pagado_usd, ganancia_vendedor_usd),
    pagado_bs = coalesce(pagado_bs, ganancia_vendedor_bs, round(ganancia_vendedor_usd * coalesce(tasa_bs, 50.00), 2)),
    pagado_gregory_usd = coalesce(pagado_gregory_usd, ganancia_gregory_usd),
    pagado_gregory_bs = coalesce(pagado_gregory_bs, ganancia_gregory_bs, round(ganancia_gregory_usd * coalesce(tasa_bs, 50.00), 2))
where estado = 'pendiente';

commit;
