-- ==============================================================================
-- MIGRACIÓN 47: Integración de Cuotas/Créditos al Consolidado de Finanzas y Métricas de Revendedores
-- ==============================================================================

-- 1. Actualizar la función finanzas() para que sume:
--    - Ventas directas de contado en orders
--    - MÁS todas las cuotas y créditos efectivamente cobrados y conciliados en installments
--    - Y devuelva cuotas_cobradas y cuotas_por_cobrar
create or replace function public.finanzas(p_meses int default 12)
returns table(
  mes date,
  ventas numeric,
  devoluciones numeric,
  gastos numeric,
  compras numeric,
  ganancia numeric,
  cuotas_cobradas numeric,
  cuotas_por_cobrar numeric
)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not is_admin() then raise exception 'No autorizado'; end if;

  return query
  with m as (
    select generate_series(
      date_trunc('month', current_date) - make_interval(months => p_meses - 1),
      date_trunc('month', current_date),
      interval '1 month'
    )::date as mes
  ),
  -- Ventas de contado (órdenes pagadas que NO están divididas en installments)
  v as (
    select date_trunc('month', coalesce(o.pagado_at, o.created_at))::date as mes,
           coalesce(sum(o.total_usd), 0) as t
    from public.orders o
    where o.estado in ('pagado', 'entregado')
      and o.pagado_at is not null
      and not exists (select 1 from public.installments i where i.order_id = o.id)
    group by 1
  ),
  -- Cuotas y cuentas por cobrar efectivamente PAGADAS y conciliadas
  inst_pagadas as (
    select date_trunc('month', coalesce(i.pagada_at, i.created_at))::date as mes,
           coalesce(sum(i.monto_usd), 0) as t
    from public.installments i
    where i.estado = 'pagada'
    group by 1
  ),
  -- Cuotas y créditos pendientes de cobro (en la calle)
  inst_pend as (
    select date_trunc('month', coalesce(i.fecha_vencimiento, current_date))::date as mes,
           coalesce(sum(i.monto_usd), 0) as t
    from public.installments i
    where i.estado in ('pendiente', 'en_revision', 'vencida')
    group by 1
  ),
  d as (
    select date_trunc('month', created_at)::date as mes,
           coalesce(sum(monto_usd), 0) as t
    from public.refunds
    group by 1
  ),
  g as (
    select date_trunc('month', fecha)::date as mes,
           coalesce(sum(monto_usd), 0) as t
    from public.expenses
    group by 1
  ),
  c as (
    select date_trunc('month', fecha)::date as mes,
           coalesce(sum(monto_usd), 0) as t
    from public.purchases
    group by 1
  )
  select
    m.mes,
    round(coalesce(v.t, 0) + coalesce(ip.t, 0), 2) as ventas,
    round(coalesce(d.t, 0), 2) as devoluciones,
    round(coalesce(g.t, 0), 2) as gastos,
    round(coalesce(c.t, 0), 2) as compras,
    round((coalesce(v.t, 0) + coalesce(ip.t, 0)) - coalesce(d.t, 0) - coalesce(g.t, 0) - coalesce(c.t, 0), 2) as ganancia,
    round(coalesce(ip.t, 0), 2) as cuotas_cobradas,
    round(coalesce(inpend.t, 0), 2) as cuotas_por_cobrar
  from m
  left join v on v.mes = m.mes
  left join inst_pagadas ip on ip.mes = m.mes
  left join inst_pend inpend on inpend.mes = m.mes
  left join d on d.mes = m.mes
  left join g on g.mes = m.mes
  left join c on c.mes = m.mes
  order by m.mes desc;
end $$;

grant execute on function public.finanzas(int) to authenticated;
