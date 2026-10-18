-- ==============================================================================
-- SCRIPT DE SANEAMIENTO, COHERENCIA Y VERIFICACIÓN EN PRODUCCIÓN
-- Archivo: supabase/verificar_y_sanear_produccion.sql
-- Ejecutar en el SQL Editor de Supabase después de migracion_16_sincronizacion_total.sql
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- PASO 1: SANEAMIENTO DE CÓDIGOS DE CLIENTE (CLT) Y REVENDEDOR (RVD)
-- ------------------------------------------------------------------------------
do $$
declare
  r record;
  v_next_code text;
begin
  -- 1.1 Corregir clientes con es_revendedor = true que no tengan prefijo RVD:
  for r in
    select id, creado
    from public.customers
    where coalesce(es_revendedor, false) is true
      and (codigo_identificacion is null or not codigo_identificacion like 'RVD:%')
    order by creado asc
  loop
    v_next_code := public.get_next_customer_code(true);
    update public.customers
    set codigo_identificacion = v_next_code,
        limite_credito = greatest(coalesce(limite_credito, 30.00), 30.00)
    where id = r.id;
  end loop;

  -- 1.2 Corregir clientes normales que no tengan código CLT:
  for r in
    select id, creado
    from public.customers
    where coalesce(es_revendedor, false) is false
      and (codigo_identificacion is null or not codigo_identificacion like 'CLT:%')
    order by creado asc
  loop
    v_next_code := public.get_next_customer_code(false);
    update public.customers
    set codigo_identificacion = v_next_code,
        limite_credito = coalesce(limite_credito, 10.00)
    where id = r.id;
  end loop;
end $$;

-- ------------------------------------------------------------------------------
-- PASO 2: APROVISIONAMIENTO Y COHERENCIA DE TARJETAS DIGITALES ZENY
-- ------------------------------------------------------------------------------
do $$
declare
  c record;
  v_num text;
  v_cvv text;
begin
  for c in
    select id, nombre, email, es_revendedor
    from public.customers
    where id not in (select customer_id from public.zeny_cards)
  loop
    v_num := '9540 ' || lpad(floor(random() * 9000 + 1000)::text, 4, '0') || ' ' ||
             lpad(floor(random() * 9000 + 1000)::text, 4, '0') || ' ' ||
             lpad(floor(random() * 9000 + 1000)::text, 4, '0');
    v_cvv := lpad(floor(random() * 900 + 100)::text, 3, '0');

    insert into public.zeny_cards(
      customer_id,
      numero_tarjeta,
      nombre_titular,
      codigo_activacion,
      fecha_vencimiento,
      estado,
      descuento_porcentaje,
      activada_at
    ) values (
      c.id,
      v_num,
      upper(trim(coalesce(c.nombre, split_part(c.email, '@', 1), 'CLIENTE ZENY'))),
      v_cvv,
      '12/31',
      'activa',
      5.00,
      now()
    ) on conflict (customer_id) do nothing;
  end loop;
end $$;

-- ------------------------------------------------------------------------------
-- PASO 3: RECALCULAR Y SINCRONIZAR zeny_balance CON zeny_ledger APROBADO
-- ------------------------------------------------------------------------------
update public.customers c
set zeny_balance = coalesce((
  select round(sum(zl.monto), 2)
  from public.zeny_ledger zl
  where zl.customer_id = c.id
    and zl.estado = 'aprobado'
), 0.00);

-- Cancelar retenciones de Zeny huérfanas de pedidos no activos
update public.zeny_ledger
set estado = 'rechazado'
where tipo = 'compra'
  and estado = 'pendiente'
  and order_id in (
    select id from public.orders
    where estado in ('rechazado', 'cancelado', 'vencido', 'reembolsado')
  );

-- ------------------------------------------------------------------------------
-- PASO 4: LIBERAR RESERVAS DE profiles_inventory Y PEDIDOS EXPIRADOS
-- ------------------------------------------------------------------------------
-- 4.1 Ejecutar liberación de reservas expiradas
do $$
begin
  perform public.release_expired();
end $$;

-- 4.2 Liberar perfiles marcados como 'reservado' sin pedido activo pendiente
update public.profiles_inventory pi
set estado = 'disponible'
where pi.estado = 'reservado'
  and not exists (
    select 1
    from public.orders o
    where o.profile_id = pi.id
      and o.estado = 'pendiente'
  );

-- ------------------------------------------------------------------------------
-- PASO 5: ASEGURAR FACTURA (invoices) EN TODOS LOS PEDIDOS ENTREGADOS
-- ------------------------------------------------------------------------------
insert into public.invoices (order_id, customer_id, total_usd, total_bs, tasa_bs, estado, franchise_id)
select o.id, o.customer_id, o.total_usd, o.total_bs, o.tasa_bs, 'emitida', o.franchise_id
from public.orders o
where o.estado = 'entregado'
on conflict (order_id) do update
set estado = 'emitida',
    total_usd = excluded.total_usd,
    total_bs = excluded.total_bs,
    tasa_bs = excluded.tasa_bs;

-- ------------------------------------------------------------------------------
-- PASO 6: ANULAR CUOTAS DE PEDIDOS CANCELADOS, RECHAZADOS O EXPIRADOS
-- ------------------------------------------------------------------------------
update public.installments
set estado = 'cancelada'
where estado in ('pendiente', 'en_revision')
  and order_id in (
    select id from public.orders
    where estado in ('rechazado', 'cancelado', 'vencido', 'reembolsado')
  );

-- ------------------------------------------------------------------------------
-- PASO 7: TABLA DE DIAGNÓSTICO Y SALUD OPERATIVA EN PRODUCCIÓN
-- ------------------------------------------------------------------------------
select
  '1. Clientes Finales (CLT)' as metrica,
  count(*)::text as valor,
  'Usuarios registrados con prefijo CLT:001+' as detalle
from public.customers where coalesce(es_revendedor, false) is false
union all
select
  '2. Revendedores Mayoristas (RVD)',
  count(*)::text,
  'Revendedores activos con código RVD:1001+'
from public.customers where coalesce(es_revendedor, false) is true
union all
select
  '3. Tarjetas Digitales Zeny (TDC)',
  count(*)::text,
  'Tarjetas activas vinculadas con 5% de descuento'
from public.zeny_cards where estado = 'activa'
union all
select
  '4. Inventario: Perfiles Disponibles',
  count(*)::text,
  'Perfiles listos para entrega inmediata'
from public.profiles_inventory where estado = 'disponible'
union all
select
  '5. Inventario: Perfiles Vendidos',
  count(*)::text,
  'Perfiles activos entregados a clientes'
from public.profiles_inventory where estado = 'vendido'
union all
select
  '6. Inventario: Perfiles Reservados',
  count(*)::text,
  'Perfiles en proceso de pago (bloqueo preventivo)'
from public.profiles_inventory where estado = 'reservado'
union all
select
  '7. Cuentas Madre Activas',
  count(*)::text,
  'Cuentas proveedor activas y vigentes'
from public.mother_accounts where coalesce(activa, true) is true and (vence is null or vence >= current_date)
union all
select
  '8. Pedidos: Pendientes por Conciliar',
  count(*)::text,
  'Pedidos esperando validación en Panel Admin'
from public.orders where estado = 'pendiente'
union all
select
  '9. Pedidos: Entregados con Factura',
  count(*)::text,
  'Pedidos conciliados con comprobante en invoices'
from public.orders where estado = 'entregado'
union all
select
  '10. Cobranza Cuotas: Pendientes / Por Cobrar',
  count(*)::text,
  'Cuotas activas en installments'
from public.installments where estado in ('pendiente', 'en_revision', 'vencida')
union all
select
  '11. Cartera por Cobrar Total ($ USD)',
  coalesce(round(sum(monto_usd), 2), 0.00)::text,
  'Total monto adeudado en cuotas por cobrar'
from public.installments where estado in ('pendiente', 'en_revision', 'vencida')
union all
select
  '12. Saldo Total en Billeteras Zeny ($)',
  coalesce(round(sum(zeny_balance), 2), 0.00)::text,
  'Suma exacta de saldos a favor de usuarios'
from public.customers
union all
select
  '13. Red de Franquicias Activas',
  count(*)::text,
  'Franquicias operativas conectadas al catálogo híbrido'
from public.franchises where estado = 'activo'
order by metrica asc;
