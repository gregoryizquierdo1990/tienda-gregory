-- ==============================================================================
-- SCRIPT DE AUDITORÍA Y DIAGNÓSTICO DE COHERENCIA EN PRODUCCIÓN (MODO SEGURO)
-- ==============================================================================
-- Propósito: Diagnóstico 100% no destructivo (solo lecturas / SELECT).
-- Ejecutar en: Supabase SQL Editor.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. DESINCRONIZACIÓN PEDIDOS (orders) ↔ INVENTARIO (profiles_inventory)
-- ------------------------------------------------------------------------------
-- 1.A. Pedidos 'entregados' cuyo perfil asignado NO está como 'vendido'
select 
  '1.A. Pedido entregado con perfil no vendido' as tipo_inconsistencia,
  o.id as order_id,
  o.created_at::date as fecha_pedido,
  o.estado as estado_pedido,
  o.profile_id,
  pi.nombre_perfil,
  pi.estado as estado_perfil_actual,
  'El pedido fue entregado pero el perfil figura como ' || coalesce(pi.estado, 'NULL') || ' (debería ser vendido)' as explicacion
from public.orders o
left join public.profiles_inventory pi on pi.id = o.profile_id
where o.estado = 'entregado'
  and (o.profile_id is null or pi.estado is distinct from 'vendido');

-- 1.B. Perfiles 'vendido' o 'reservado' en profiles_inventory sin pedido activo correspondiente
select 
  '1.B. Perfil marcado vendido/reservado sin pedido activo' as tipo_inconsistencia,
  pi.id as profile_id,
  pi.nombre_perfil,
  pi.estado as estado_perfil,
  pi.mother_id,
  pi.vence as fecha_vence_perfil,
  'El perfil está bloqueado en inventario pero no tiene ninguna orden activa vinculada' as explicacion
from public.profiles_inventory pi
where pi.estado in ('vendido', 'reservado')
  and not exists (
    select 1 from public.orders o 
    where o.profile_id = pi.id 
      and o.estado in ('pendiente', 'entregado', 'pagado')
  );

-- ------------------------------------------------------------------------------
-- 2. FACTURACIÓN Y CONCILIACIÓN: orders ↔ invoices ↔ finanzas()
-- ------------------------------------------------------------------------------
-- 2.A. Pedidos conciliados ('pagado' o 'entregado') sin factura en invoices
select 
  '2.A. Pedido conciliado sin factura' as tipo_inconsistencia,
  o.id as order_id,
  o.customer_id,
  o.total_usd,
  o.estado,
  o.pagado_at,
  'Pedido conciliado sin registro en la tabla invoices' as explicacion
from public.orders o
where o.estado in ('pagado', 'entregado')
  and not exists (
    select 1 from public.invoices inv where inv.order_id = o.id
  );

-- 2.B. Pedidos 'entregado' que carecen de fecha pagado_at (afecta el agrupamiento en finanzas)
select 
  '2.B. Pedido entregado sin pagado_at' as tipo_inconsistencia,
  o.id as order_id,
  o.total_usd,
  o.estado,
  o.created_at,
  o.conciliado_at,
  'La orden se entregó pero pagado_at es nulo; quedaba fuera del reporte mensual de finanzas' as explicacion
from public.orders o
where o.estado in ('pagado', 'entregado')
  and o.pagado_at is null;

-- ------------------------------------------------------------------------------
-- 3. BILLETERA ZENY: zeny_ledger ↔ orders ↔ customers.zeny_balance
-- ------------------------------------------------------------------------------
-- 3.A. Retenciones de Zeny pendientes asociadas a pedidos ya cerrados (entregados, cancelados, vencidos, rechazados)
select 
  '3.A. Retención Zeny huérfana' as tipo_inconsistencia,
  zl.id as ledger_id,
  zl.customer_id,
  zl.monto,
  zl.order_id,
  zl.estado as estado_ledger,
  o.estado as estado_pedido,
  case 
    when o.estado = 'entregado' then 'El pedido se entregó pero el Zeny sigue en estado pendiente en vez de aprobado'
    else 'El pedido se canceló/venció/rechazó pero la retención sigue pendiente en vez de rechazada'
  end as explicacion
from public.zeny_ledger zl
join public.orders o on o.id = zl.order_id
where zl.tipo = 'compra'
  and zl.estado = 'pendiente'
  and o.estado in ('entregado', 'rechazado', 'vencido', 'cancelado', 'reembolsado');

-- 3.B. Discrepancias entre la suma de movimientos en zeny_ledger y customers.zeny_balance
with ledger_sum as (
  select 
    customer_id,
    coalesce(sum(monto), 0) as saldo_calculado
  from public.zeny_ledger
  where estado = 'aprobado'
  group by customer_id
)
select 
  '3.B. Descuadre en zeny_balance' as tipo_inconsistencia,
  c.id as customer_id,
  c.nombre,
  c.email,
  c.zeny_balance as saldo_en_tabla_customer,
  coalesce(ls.saldo_calculado, 0) as saldo_segun_ledger,
  round((c.zeny_balance - coalesce(ls.saldo_calculado, 0)), 2) as diferencia,
  'El saldo almacenado en customers no coincide con el historial auditado en zeny_ledger' as explicacion
from public.customers c
left join ledger_sum ls on ls.customer_id = c.id
where abs(c.zeny_balance - coalesce(ls.saldo_calculado, 0)) > 0.01;

-- ------------------------------------------------------------------------------
-- 4. IDENTIFICACIÓN Y TARJETAS: customers (Revendedores) ↔ zeny_cards
-- ------------------------------------------------------------------------------
-- 4.A. Clientes con es_revendedor = true que aún conservan código 'CLT:' o carecen de código 'RVD:'
select 
  '4.A. Revendedor con código inválido' as tipo_inconsistencia,
  c.id as customer_id,
  c.nombre,
  c.email,
  c.telefono,
  c.codigo_identificacion,
  c.es_revendedor,
  'El usuario está habilitado como revendedor pero conserva prefijo de cliente estándar' as explicacion
from public.customers c
where c.es_revendedor = true
  and (c.codigo_identificacion is null or c.codigo_identificacion not like 'RVD:%');

-- 4.B. Revendedores activos sin registro de tarjeta digital en zeny_cards
select 
  '4.B. Revendedor sin tarjeta digital Zeny' as tipo_inconsistencia,
  c.id as customer_id,
  c.nombre,
  c.email,
  c.codigo_identificacion,
  c.limite_credito,
  'Revendedor oficial sin tarjeta emitida en zeny_cards' as explicacion
from public.customers c
where c.es_revendedor = true
  and not exists (
    select 1 from public.zeny_cards zc where zc.customer_id = c.id
  );

-- ------------------------------------------------------------------------------
-- 5. CRÉDITOS Y CUOTAS: installments ↔ orders
-- ------------------------------------------------------------------------------
-- 5.A. Cuotas de crédito huérfanas o desincronizadas con el estado de su orden
select 
  '5.A. Cuota desincronizada con pedido' as tipo_inconsistencia,
  i.id as installment_id,
  i.order_id,
  i.monto_usd,
  i.estado as estado_cuota,
  o.estado as estado_orden,
  o.customer_id,
  case 
    when o.id is null then 'La cuota apunta a una orden que no existe'
    when o.estado in ('cancelado', 'rechazado') and i.estado not in ('cancelada', 'pagada') then 'El pedido fue cancelado pero la cuota sigue activa/pendiente'
    when o.estado = 'entregado' and o.pagado_at is null and i.estado = 'pagada' then 'La cuota fue pagada pero la orden no tiene pagado_at'
    else 'Desincronización de estado'
  end as explicacion
from public.installments i
left join public.orders o on o.id = i.order_id
where o.id is null 
   or (o.estado in ('cancelado', 'rechazado') and i.estado not in ('cancelada', 'pagada'));

-- ------------------------------------------------------------------------------
-- 6. FRANQUICIAS SAAS: franchises ↔ products / orders / profiles_inventory
-- ------------------------------------------------------------------------------
-- 6.A. Diagnóstico de subdominios, estado y Kill-Switch
select 
  '6.A. Auditoría de Franquicias' as modulo,
  f.id as franchise_id,
  f.subdominio,
  f.nombre_comercial,
  f.titular_nombre,
  f.titular_correo,
  f.estado as estado_franquicia,
  f.canon_mensual_usd,
  f.fecha_vencimiento_canon,
  case 
    when f.estado in ('suspendido_fraude', 'suspendido_mora') then '🔴 Kill-Switch activo: portal web bloqueado para clientes'
    when f.fecha_vencimiento_canon < current_date then '⚠️ Canon vencido en mora'
    else '🟢 Operativa'
  end as diagnostico_operativo
from public.franchises f;

-- 6.B. Comprobación estructural: ¿Existe columna franchise_id en tablas operativas?
select 
  table_name,
  column_name,
  data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('orders', 'profiles_inventory', 'mother_accounts', 'products')
  and column_name = 'franchise_id';
-- (Si esta consulta no devuelve filas, significa que el multi-tenant opera sobre inventario y pedidos centrales unificados sin particionamiento por franchise_id).
