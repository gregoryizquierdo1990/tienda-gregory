-- ==============================================================================
-- MIGRACIÓN 15: PRODUCTOS EN CUOTAS, LÍMITE DE CRÉDITO BASE $0 Y DESTINOS DE REEMBOLSO
-- ==============================================================================

-- 1. Bandera en productos para habilitar selectivamente el plan de cuotas (BNPL)
alter table products add column if not exists permite_cuotas boolean default false;

-- 2. Asegurar que los clientes al registrarse tengan límite de crédito 0 por defecto
-- El administrador asignará manualmente el crédito a cada cliente individualmente
alter table customers alter column limite_credito set default 0.00;

-- 3. Actualizar la tabla refunds y su función para admitir destinos explícitos:
-- zeny, usdt, bolivares, externo
alter table refunds drop constraint if exists refunds_destino_check;
alter table refunds add constraint refunds_destino_check check (destino in ('zeny', 'usdt', 'bolivares', 'externo'));

create or replace function refund_order(
  p_order uuid,
  p_monto numeric,
  p_destino text,
  p_motivo text,
  p_liberar boolean default true
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  o orders;
  prev numeric;
  m numeric;
  rid uuid;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select * into o from orders where id = p_order for update;
  if not found then raise exception 'Pedido no existe'; end if;
  if o.estado not in ('pagado','entregado') then raise exception 'Solo se reembolsan pedidos pagados o entregados'; end if;
  if p_destino not in ('zeny','usdt','bolivares','externo') then raise exception 'Destino de devolución inválido'; end if;

  select coalesce(sum(monto_usd),0) into prev from refunds where order_id = p_order;
  m := coalesce(p_monto, o.total_usd - prev);
  if m <= 0 or m + prev > o.total_usd then raise exception 'Monto inválido (máximo reembolsable: %)', o.total_usd - prev; end if;

  insert into refunds(order_id, customer_id, monto_usd, destino, motivo, liberado)
  values (p_order, o.customer_id, m, p_destino, p_motivo, case when m + prev >= o.total_usd then p_liberar end)
  returning id into rid;

  -- Si el destino es Zeny, se acredita automáticamente a la wallet del cliente
  if p_destino = 'zeny' then
    insert into zeny_ledger(customer_id, tipo, monto, referencia)
    values (o.customer_id, 'reembolso', m, 'Reembolso pedido ' || left(o.id::text, 8));
  end if;

  -- Si se reembolsó la totalidad del pedido, actualizar estado y liberar perfil
  if m + prev >= o.total_usd then
    update orders set estado = 'reembolsado' where id = p_order;
    update invoices set estado = 'anulada' where order_id = p_order;
    if o.profile_id is not null then
      update profiles_inventory
      set estado = case when p_liberar then 'disponible' else 'suspendido' end,
          inicia = null,
          vence = null
      where id = o.profile_id;
    end if;
  end if;

  return rid;
end $$;
