-- =========================================================================
-- MIGRACIÓN 32: COMPRAS A CRÉDITO A PROVEEDORES Y DEVOLUCIONES AVANZADAS
-- =========================================================================

-- 1. Ampliar tabla `purchases` para Compras a Crédito con Proveedores
alter table purchases add column if not exists monto_bs numeric(14,2) default 0.00;
alter table purchases add column if not exists monto_usdt numeric(10,2) default 0.00;
alter table purchases add column if not exists es_credito boolean not null default false;
alter table purchases add column if not exists dias_credito integer default 0;
alter table purchases add column if not exists fecha_limite_pago date;
alter table purchases add column if not exists estado_pago text not null default 'pagado';
alter table purchases add column if not exists metodo_pago_proveedor text;
alter table purchases add column if not exists tasa_usdt_pago numeric(14,2);
alter table purchases add column if not exists monto_pagado_bs numeric(16,2);
alter table purchases add column if not exists pagado_at timestamptz;
alter table purchases add column if not exists comprobante_pago text;

create index if not exists idx_purchases_estado_pago on purchases(estado_pago);
create index if not exists idx_purchases_fecha_limite on purchases(fecha_limite_pago);

-- 2. Ampliar tabla `refunds` para Devoluciones y Reversos Detallados
alter table refunds drop constraint if exists refunds_destino_check;
alter table refunds alter column destino drop not null;

alter table refunds add column if not exists metodo_reembolso text default 'zeny';
alter table refunds add column if not exists referencia_soporte text;
alter table refunds add column if not exists destinatario_datos text;
alter table refunds add column if not exists accion_perfil text default 'liberar';
alter table refunds add column if not exists diferencia_precio_usd numeric(10,2) default 0.00;
alter table refunds add column if not exists tasa_cambio numeric(14,2);
alter table refunds add column if not exists monto_bs numeric(16,2);

-- 3. Función RPC para registrar y pagar deuda de compra a proveedor
create or replace function pagar_compra_proveedor(
  p_purchase_id uuid,
  p_metodo text,
  p_tasa numeric default null,
  p_comprobante text default null,
  p_notas text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_pur record;
  v_monto_bs numeric(16,2) := 0.00;
  v_tasa numeric(14,2) := coalesce(p_tasa, 1.00);
begin
  if not is_admin() then
    raise exception 'No autorizado: se requieren permisos de administrador';
  end if;

  select * into v_pur from purchases where id = p_purchase_id for update;
  if not found then
    raise exception 'Registro de compra no encontrado';
  end if;

  if v_pur.estado_pago = 'pagado' then
    raise exception 'Esta compra ya se encuentra pagada';
  end if;

  if p_metodo = 'bolivares' then
    v_monto_bs := round(coalesce(v_pur.monto_usdt, v_pur.monto_usd, 0.00) * v_tasa, 2);
  end if;

  update purchases
  set estado_pago = 'pagado',
      pagado_at = now(),
      metodo_pago_proveedor = p_metodo,
      tasa_usdt_pago = case when p_metodo = 'bolivares' then v_tasa else null end,
      monto_pagado_bs = case when p_metodo = 'bolivares' then v_monto_bs else null end,
      comprobante_pago = p_comprobante,
      notas = case 
        when p_notas is not null and length(trim(p_notas)) > 0 then coalesce(notas, '') || ' | ' || p_notas
        else notas
      end
  where id = p_purchase_id;

  return jsonb_build_object(
    'ok', true,
    'purchase_id', p_purchase_id,
    'monto_usdt', coalesce(v_pur.monto_usdt, v_pur.monto_usd),
    'monto_bs', v_monto_bs,
    'metodo', p_metodo
  );
end;
$$;

grant execute on function pagar_compra_proveedor(uuid, text, numeric, text, text) to authenticated;

-- 4. Función RPC Avanzada para Devoluciones y Reversos
create or replace function registrar_devolucion_avanzada(
  p_order_id uuid,
  p_monto_usd numeric,
  p_metodo text default 'zeny',
  p_motivo text default null,
  p_referencia text default null,
  p_destinatario text default null,
  p_accion_perfil text default 'liberar',
  p_diferencia_usd numeric default 0.00,
  p_tasa numeric default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_ord record;
  v_rid uuid;
  v_prev numeric := 0.00;
  v_monto numeric(10,2);
  v_monto_bs numeric(16,2) := 0.00;
  v_tasa numeric(14,2);
  v_destino_legacy text;
begin
  if not is_admin() then
    raise exception 'No autorizado: se requieren permisos de administrador';
  end if;

  select * into v_ord from orders where id = p_order_id for update;
  if not found then
    raise exception 'El pedido indicado no existe';
  end if;

  if v_ord.estado not in ('pagado', 'entregado', 'vencido') then
    raise exception 'Solo se pueden reembolsar pedidos pagados o entregados';
  end if;

  select coalesce(sum(monto_usd), 0.00) into v_prev from refunds where order_id = p_order_id;
  v_monto := coalesce(p_monto_usd, v_ord.total_usd - v_prev);

  if v_monto <= 0 or (v_monto + v_prev) > (v_ord.total_usd + 0.01) then
    raise exception 'Monto inválido (máximo reembolsable: $%)', round(v_ord.total_usd - v_prev, 2);
  end if;

  select bs_por_usd into v_tasa from exchange_rates order by fecha desc limit 1;
  v_tasa := coalesce(p_tasa, v_tasa, 50.00);
  v_monto_bs := round(v_monto * v_tasa, 2);

  v_destino_legacy := case when p_metodo = 'zeny' then 'zeny' else 'externo' end;

  -- 1. Insertar el registro de devolución
  insert into refunds (
    order_id, customer_id, monto_usd, destino, motivo, liberado,
    metodo_reembolso, referencia_soporte, destinatario_datos,
    accion_perfil, diferencia_precio_usd, tasa_cambio, monto_bs
  ) values (
    p_order_id, v_ord.customer_id, v_monto, v_destino_legacy, p_motivo, (p_accion_perfil = 'liberar'),
    p_metodo, p_referencia, p_destinatario,
    p_accion_perfil, coalesce(p_diferencia_usd, 0.00), v_tasa, v_monto_bs
  ) returning id into v_rid;

  -- 2. Si el reembolso es a la Billetera Zeny, abonar inmediatamente
  if p_metodo = 'zeny' then
    insert into zeny_ledger (customer_id, tipo, monto, referencia, estado)
    values (v_ord.customer_id, 'reembolso', v_monto, 'Reembolso / Devolución Pedido ' || left(v_ord.id::text, 8), 'aprobado');
  end if;

  -- 3. Acción sobre el perfil en inventario
  if v_ord.profile_id is not null then
    if p_accion_perfil = 'liberar' then
      update profiles_inventory
      set estado = 'disponible',
          assigned_customer_id = null,
          inicia = null,
          vence = null
      where id = v_ord.profile_id;
    elsif p_accion_perfil = 'suspender' then
      update profiles_inventory
      set estado = 'suspendido'
      where id = v_ord.profile_id;
    end if;
  end if;

  -- 4. Si el reembolso cubre la totalidad, marcar el pedido como reembolsado
  if (v_monto + v_prev) >= (v_ord.total_usd - 0.01) then
    update orders set estado = 'reembolsado' where id = p_order_id;
    update invoices set estado = 'anulada' where order_id = p_order_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'refund_id', v_rid,
    'order_id', p_order_id,
    'monto_usd', v_monto,
    'monto_bs', v_monto_bs,
    'metodo', p_metodo
  );
end;
$$;

grant execute on function registrar_devolucion_avanzada(uuid, numeric, text, text, text, text, text, numeric, numeric) to authenticated;
