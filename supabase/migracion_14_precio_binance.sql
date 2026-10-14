-- ==============================================================================
-- MIGRACIÓN 14: CAMPO PRECIO BINANCE (USDT) Y AJUSTE DE PRECIO DIFERENCIAL
-- ==============================================================================

-- 1. Añadir columna precio_binance_usd a la tabla products
alter table products add column if not exists precio_binance_usd numeric(10,2) check (precio_binance_usd >= 0);

-- 2. Actualizar orders_guard para respetar precio_binance_usd cuando el método es Binance
create or replace function orders_guard() returns trigger language plpgsql security definer set search_path = public as $$
declare
  pr products;
  r numeric;
  pm payment_methods;
  eff_price numeric;
  is_res boolean := false;
begin
  if is_admin() or current_setting('app.internal', true) = '1' then return new; end if;
  select * into pr from products where id = new.product_id and activo;
  if not found then raise exception 'Producto no disponible'; end if;

  select es_revendedor into is_res from customers where id = auth.uid();
  if new.metodo_id is not null then
    select * into pm from payment_methods where id = new.metodo_id;
  end if;

  -- Si el método es Binance y el producto tiene precio_binance_usd, usarlo
  if pm.tipo = 'binance' or lower(coalesce(pm.nombre,'')) like '%binance%' then
    if pr.precio_binance_usd is not null and pr.precio_binance_usd > 0 then
      eff_price := pr.precio_binance_usd;
    else
      eff_price := pr.precio_usd;
    end if;
  elsif is_res and pr.precio_revendedor_usd is not null and pr.precio_revendedor_usd > 0 then
    eff_price := pr.precio_revendedor_usd;
  else
    eff_price := pr.precio_usd;
  end if;

  select bs_por_usd into r from exchange_rates order by fecha desc limit 1;
  new.customer_id := auth.uid();
  new.total_usd := eff_price;
  new.tasa_bs := r;
  new.total_bs := eff_price * coalesce(r, 0);
  new.estado := 'pendiente';
  new.profile_id := null;
  new.inicia := null;
  new.vence := null;
  new.proximo_pago := null;
  new.gcal_event_id := null;
  return new;
end $$;

-- 3. Actualizar create_order para aplicar precio_binance_usd
create or replace function create_order(
  p_product uuid,
  p_metodo uuid default null,
  p_ref text default null,
  p_zeny numeric default 0
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  pr products;
  pf uuid;
  o uuid;
  rate numeric;
  bal numeric;
  holds numeric;
  z numeric := coalesce(p_zeny, 0);
  pm payment_methods;
  eff_price numeric;
  is_res boolean := false;
begin
  if auth.uid() is null then raise exception 'Inicia sesion'; end if;
  perform release_expired();
  select * into pr from products where id = p_product and activo;
  if not found then raise exception 'Producto no disponible'; end if;

  select es_revendedor into is_res from customers where id = auth.uid();
  if p_metodo is not null then
    select * into pm from payment_methods where id = p_metodo;
  end if;

  if pm.tipo = 'binance' or lower(coalesce(pm.nombre,'')) like '%binance%' then
    if pr.precio_binance_usd is not null and pr.precio_binance_usd > 0 then
      eff_price := pr.precio_binance_usd;
    else
      eff_price := pr.precio_usd;
    end if;
  elsif is_res and pr.precio_revendedor_usd is not null and pr.precio_revendedor_usd > 0 then
    eff_price := pr.precio_revendedor_usd;
  else
    eff_price := pr.precio_usd;
  end if;

  if z < 0 or z > eff_price then raise exception 'Monto Zeny invalido'; end if;
  if z < eff_price and p_metodo is null then raise exception 'Elige un metodo de pago para el resto'; end if;

  if z > 0 then
    select zeny_balance into bal from customers where id = auth.uid() for update;
    select coalesce(sum(-monto), 0) into holds from zeny_ledger where customer_id = auth.uid() and tipo = 'compra' and estado = 'pendiente';
    if z > coalesce(bal,0) - holds then raise exception 'Saldo Zeny insuficiente'; end if;
  end if;

  if pr.tipo <> 'servicio' then
    select id into pf from profiles_inventory where product_id = p_product and estado = 'disponible' order by id limit 1 for update skip locked;
    if pf is null then raise exception 'Agotado'; end if;
    update profiles_inventory set estado = 'reservado' where id = pf;
  end if;

  select bs_por_usd into rate from exchange_rates order by fecha desc limit 1;
  perform set_config('app.internal','1',true);

  insert into orders(customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, metodo_id, referencia, estado, zeny_aplicado)
  values (auth.uid(), p_product, pf, eff_price, rate, eff_price * coalesce(rate, 0), p_metodo, left(coalesce(p_ref,''), 120), 'pendiente', z)
  returning id into o;

  if z > 0 then
    insert into zeny_ledger(customer_id, tipo, monto, referencia, estado, order_id)
    values (auth.uid(), 'compra', -z, 'Retencion pedido ' || left(o::text, 8), 'pendiente', o);
  end if;

  return o;
end $$;

revoke execute on function create_order(uuid,uuid,text,numeric) from public, anon;
grant execute on function create_order(uuid,uuid,text,numeric) to authenticated;
