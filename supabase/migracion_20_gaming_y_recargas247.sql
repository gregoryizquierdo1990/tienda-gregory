-- Migración 20: Gaming & Activos Digitales + Red de Taquillas y Distribución Recargas247

-- 1. Ampliar el tipo de producto para soportar gaming y recargas telefónicas
alter table products drop constraint if exists products_tipo_check;
alter table products add constraint products_tipo_check 
  check (tipo in ('pantalla', 'cuenta_completa', 'servicio', 'gaming', 'recarga_telefonica'));

-- Campos para exclusividad de la central y metadatos de recarga
alter table products add column if not exists es_exclusivo_central boolean not null default false;
alter table products add column if not exists campos_requeridos jsonb not null default '[]';
alter table products add column if not exists operadora_o_juego text;

-- 2. Añadir datos de recarga en los pedidos (orders)
alter table orders add column if not exists datos_recarga jsonb not null default '{}';
alter table orders add column if not exists estado_recarga text default 'pendiente' check (estado_recarga in ('pendiente', 'recargado', 'fallido'));

-- 3. Actualizar función create_order para aceptar datos_recarga y respetar exclusividad
create or replace function create_order(
  p_product uuid,
  p_metodo uuid default null,
  p_ref text default null,
  p_zeny numeric default 0,
  p_datos_recarga jsonb default '{}'
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

  -- Precios: si es exclusivo de la central (Gaming / Telefonía propia), NO aplica precio de revendedor
  if (pm.tipo = 'binance' or lower(coalesce(pm.nombre,'')) like '%binance%') and pr.precio_binance_usd is not null and pr.precio_binance_usd > 0 then
    eff_price := pr.precio_binance_usd;
  elsif not pr.es_exclusivo_central and is_res and pr.precio_revendedor_usd is not null and pr.precio_revendedor_usd > 0 then
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

  -- Solo streaming (pantallas y cuentas completas) reservan en profiles_inventory
  -- Gaming, recargas telefonicas y servicios NO usan inventario de streaming
  if pr.tipo not in ('servicio', 'gaming', 'recarga_telefonica') then
    select id into pf from profiles_inventory where product_id = p_product and estado = 'disponible' order by id limit 1 for update skip locked;
    if pf is null then raise exception 'Agotado'; end if;
    update profiles_inventory set estado = 'reservado' where id = pf;
  end if;

  select bs_por_usd into rate from exchange_rates order by fecha desc limit 1;
  perform set_config('app.internal','1',true);

  insert into orders(
    customer_id, product_id, profile_id, total_usd, tasa_bs, total_bs, metodo_id, referencia, estado, zeny_aplicado, datos_recarga
  )
  values (
    auth.uid(), p_product, pf, eff_price, rate, eff_price * coalesce(rate, 0), p_metodo, left(coalesce(p_ref,''), 120), 'pendiente', z, coalesce(p_datos_recarga, '{}'::jsonb)
  )
  returning id into o;

  if z > 0 then
    insert into zeny_ledger(customer_id, tipo, monto, referencia, estado, order_id)
    values (auth.uid(), 'compra', -z, 'Retencion pedido ' || left(o::text, 8), 'pendiente', o);
  end if;

  return o;
end $$;

revoke execute on function create_order(uuid,uuid,text,numeric,jsonb) from public, anon;
grant execute on function create_order(uuid,uuid,text,numeric,jsonb) to authenticated;

-- Compatibilidad con llamada de 4 argumentos
create or replace function create_order(
  p_product uuid,
  p_metodo uuid,
  p_ref text,
  p_zeny numeric
) returns uuid language sql security definer set search_path = public as $$
  select create_order(p_product, p_metodo, p_ref, p_zeny, '{}'::jsonb);
$$;
revoke execute on function create_order(uuid,uuid,text,numeric) from public, anon;
grant execute on function create_order(uuid,uuid,text,numeric) to authenticated;

-- 4. Actualizar función de entrega _deliver para no exigir perfiles en gaming o recargas
create or replace function _deliver(p_order uuid) returns void language plpgsql security definer set search_path = public as $$
declare
  o orders;
  pr products;
  pf uuid;
  st text;
begin
  select * into o from orders where id = p_order for update;
  if o.estado not in ('pendiente','pagado','vencido') then raise exception 'Estado de pedido invalido'; end if;
  select * into pr from products where id = o.product_id;

  if pr.tipo not in ('servicio', 'gaming', 'recarga_telefonica') then
    pf := o.profile_id;
    if pf is not null then
      select estado into st from profiles_inventory where id = pf for update;
      if not ((o.estado <> 'vencido' and st = 'reservado') or st = 'disponible') then pf := null; end if;
    end if;
    if pf is null then
      select id into pf from profiles_inventory where product_id = o.product_id and estado = 'disponible' order by id limit 1 for update skip locked;
      if pf is null then raise exception 'Sin stock disponible para %', pr.nombre; end if;
    end if;
    update profiles_inventory set estado = 'vendido', inicia = current_date, vence = current_date + pr.duracion_dias where id = pf;
  end if;

  update orders set
    estado = 'entregado',
    estado_recarga = 'recargado',
    profile_id = pf,
    inicia = current_date,
    vence = current_date + pr.duracion_dias,
    proximo_pago = current_date + pr.duracion_dias,
    pagado_at = coalesce(pagado_at, now())
  where id = p_order;

  insert into invoices(order_id, customer_id, total_usd, total_bs, tasa_bs)
  select id, customer_id, total_usd, total_bs, tasa_bs from orders where id = p_order on conflict do nothing;
end $$;

-- 5. Tabla de TAQUILLAS / PUNTOS DE RECARGA (Red Recargas247 bajo el control de Gregory)
create table if not exists recargas_puntos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null, -- Nombre del titular
  apellido text not null, -- Apellido del titular
  email text not null unique,
  clave_acceso text, -- Clave generada para la taquilla en recargas247
  pais text not null default 'Venezuela',
  estado_region text not null default 'Distrito Capital',
  telefono text not null, -- WhatsApp en formato ej: 584126665544
  nombre_taquilla text not null, -- Nombre comercial del punto (ej: Bodega San Juan)
  usuario_recargas247 text, -- Usuario asignado en recargas247.net
  canon_mensual_usd numeric(10,2) not null default 5.00,
  fecha_vencimiento_canon date not null default (current_date + interval '30 days'),
  comision_deposito_pct numeric(5,2) not null default 3.00, -- Porcentaje de ganancia de Gregory sobre cada depósito
  saldo_actual_247 numeric(14,2) not null default 0,
  estado text not null default 'activo' check (estado in ('activo', 'suspendido_mora', 'inactivo')),
  notas text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_recargas_puntos_estado on recargas_puntos(estado);
create index if not exists idx_recargas_puntos_email on recargas_puntos(email);
create index if not exists idx_recargas_puntos_tel on recargas_puntos(telefono);

-- 6. Tabla de ABONOS / DEPÓSITOS DE SALDO (Compras de saldo de las taquillas)
create table if not exists recargas_abonos (
  id uuid primary key default gen_random_uuid(),
  punto_id uuid not null references recargas_puntos(id) on delete cascade,
  monto_depositado_usd numeric(10,2) not null check (monto_depositado_usd > 0),
  comision_distribuidor_pct numeric(5,2) not null default 3.00,
  ganancia_gregory_usd numeric(10,2) not null default 0, -- Ganancia neta de Gregory por el depósito
  saldo_acreditado_usd numeric(10,2) not null default 0, -- Saldo que se le acredita en el panel 247
  monto_bs numeric(16,2),
  tasa_bcv numeric(14,4),
  metodo_pago text not null, -- Pago Móvil, Binance, Transferencia Bancaria
  referencia text not null,
  comprobante_url text,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'conciliado_abonado', 'rechazado')),
  notas_admin text,
  abonado_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_recargas_abonos_punto on recargas_abonos(punto_id);
create index if not exists idx_recargas_abonos_estado on recargas_abonos(estado);

-- RLS
alter table recargas_puntos enable row level security;
alter table recargas_abonos enable row level security;

drop policy if exists recargas_puntos_admin on recargas_puntos;
create policy recargas_puntos_admin on recargas_puntos for all to authenticated using (is_admin()) with check (is_admin());

drop policy if exists recargas_abonos_admin on recargas_abonos;
create policy recargas_abonos_admin on recargas_abonos for all to authenticated using (is_admin()) with check (is_admin());
