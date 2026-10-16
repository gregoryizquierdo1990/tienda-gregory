-- ==============================================================================
-- MIGRACIÓN 36: SALDADO DE COMISIONES PREVIAS AL LANZAMIENTO OFICIAL
-- Marca como liquidadas todas las comisiones generadas hasta el 15/10/2026
-- Las liquidaciones oficiales en plataforma arrancan en limpio desde el 16/10/2026
-- ==============================================================================

begin;

-- 1. Actualizar todas las comisiones previas al 16 de Octubre de 2026 como liquidadas
update partner_commissions
set estado = 'liquidada',
    liquidada_at = coalesce(liquidada_at, now()),
    metodo_pago = coalesce(metodo_pago, 'Acuerdo externo previo a plataforma'),
    referencia_pago = coalesce(referencia_pago, 'SALDADO-PREVIO-LANZAMIENTO-15-OCT'),
    pagado_usd = coalesce(pagado_usd, ganancia_vendedor_usd),
    pagado_bs = coalesce(pagado_bs, ganancia_vendedor_bs, round(ganancia_vendedor_usd * coalesce(tasa_bs, 50.00), 2))
where (estado = 'pendiente' or estado is null)
  and created_at < '2026-10-16T00:00:00-04:00';

-- 2. Asegurar que cualquier registro sin fecha límite anterior también quede cerrado
update partner_commissions
set estado = 'liquidada',
    liquidada_at = coalesce(liquidada_at, now()),
    metodo_pago = coalesce(metodo_pago, 'Acuerdo externo previo a plataforma'),
    referencia_pago = coalesce(referencia_pago, 'SALDADO-PREVIO-LANZAMIENTO-15-OCT'),
    pagado_usd = coalesce(pagado_usd, ganancia_vendedor_usd),
    pagado_bs = coalesce(pagado_bs, ganancia_vendedor_bs, round(ganancia_vendedor_usd * coalesce(tasa_bs, 50.00), 2))
where estado = 'pendiente'
  and created_at::date <= '2026-10-15'::date;

commit;
