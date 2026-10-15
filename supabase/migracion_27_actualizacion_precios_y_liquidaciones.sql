-- ==============================================================================
-- Migración 27: Actualización Maestra de Precios de la Tienda (PVP, Revendedor, USDT)
-- y Sistema Automatizado de Liquidación de Ganancias para Socios
-- Emprendimiento Gregory Izquierdo
-- ==============================================================================

-- 1. Ampliar columnas en products para costos y márgenes de liquidación
alter table products add column if not exists costo_usdt numeric(10,2) default 0.00;
alter table products add column if not exists costo_bs numeric(10,2) default 0.00;
alter table products add column if not exists comision_revendedor_usd numeric(10,2) default 0.00;
alter table products add column if not exists ganancia_tienda_usd numeric(10,2) default 0.00;

-- 2. Asegurar categorías del catálogo
insert into categories (id, nombre, orden, activo) values
  ('e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Perfiles & Pantallas', 1, true),
  ('e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'Cuentas Completas', 2, true),
  ('e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'Combos Especiales', 3, true),
  ('e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'Música & Productividad', 4, true)
on conflict (id) do update set nombre = excluded.nombre, orden = excluded.orden, activo = true;

-- 3. Cargar y Actualizar los 62 Servicios Oficiales con sus Precios y Costos
do 74778
declare
  r record;
  v_cat_id uuid;
  v_prod_id uuid;
begin
  for r in
    select * from (values
      ('NETFLIX NORMAL 30 DIAS', 'pantalla', 6.0, 4.29, 3.58, 2.6, 3.12, 1.71, 1.69, 30),
      ('NETFLIX PERFIL EXTRA NETFLIX 30 DIAS', 'pantalla', 8.0, 6.08, 4.5, 3.8, 4.56, 1.92, 2.28, 30),
      ('NETFLIX CUENTA COMPLETA 30 DIAS', 'cuenta_completa', 19.0, 17.18, 14.33, 13.0, 15.59, 1.82, 4.18, 30),
      ('4 PERFIL EXTRA NETFLIX 30 DIAS', 'pantalla', 24.04, 22.11, 18.44, 15.2, 18.23, 1.93, 6.91, 30),
      ('MAX PERFIL ESTANDAR 30 DIAS', 'pantalla', 3.0, 1.9, 1.58, 0.6, 0.72, 1.1, 1.3, 30),
      ('MAX CUENTA COMPLETA 30 DIAS', 'cuenta_completa', 8.0, 5.89, 4.91, 3.0, 3.6, 2.11, 2.89, 30),
      ('MAX CTA C ALQUILER  30 DIAS', 'cuenta_completa', 8.0, 5.53, 4.61, 1.99, 2.39, 2.47, 3.54, 30),
      ('DISNEY PERFIL 15 DIAS', 'pantalla', 2.5, 2.08, 1.73, 0.5, 0.6, 0.42, 1.58, 15),
      ('DISNEY PERFIL 30 DIAS', 'pantalla', 5.0, 3.32, 2.77, 1.0, 1.2, 1.68, 2.32, 30),
      ('DISNEY PREMIUM CTA C 30 DIAS', 'cuenta_completa', 11.98, 10.67, 8.9, 7.0, 8.39, 1.31, 3.67, 30),
      ('PRIME VIDEO PERFIL 30 DIAS', 'pantalla', 2.53, 1.81, 1.51, 0.49, 0.59, 0.72, 1.32, 30),
      ('PRIME VIDEO CTA C 30 DIAS', 'cuenta_completa', 6.71, 5.7, 4.75, 2.99, 3.59, 1.01, 2.71, 30),
      ('VIX PERFIL 15 DIAS', 'pantalla', 1.25, 0.85, 0.71, 0.05, 0.06, 0.4, 0.8, 15),
      ('VIX PERFIL 30 DIAS', 'pantalla', 2.5, 1.7, 1.42, 0.1, 0.12, 0.8, 1.6, 30),
      ('VIX CTA C 30 DIAS', 'cuenta_completa', 5.03, 3.53, 2.94, 0.5, 0.6, 1.5, 3.03, 30),
      ('CRUNCHYROLL PERFIL 30 DIA', 'pantalla', 3.02, 2.12, 1.77, 0.3, 0.36, 0.9, 1.82, 30),
      ('CRUNCHYROLL CTA COMPLETA 30 DIAS', 'cuenta_completa', 7.1, 5.1, 4.25, 1.49, 1.79, 2.0, 3.61, 30),
      ('PARAMOUNT PERFIL 30 DIAS', 'pantalla', 3.03, 2.23, 1.86, 0.5, 0.6, 0.8, 1.73, 30),
      ('PARAMOUNT CTA C 30 DIAS', 'cuenta_completa', 7.21, 5.9, 4.92, 3.0, 3.6, 1.31, 2.9, 30),
      ('PARAMOUNT CTA C  ALQUILER 30 DIAS', 'cuenta_completa', 7.13, 5.46, 4.55, 1.99, 2.39, 1.67, 3.47, 30),
      ('UNIVERSAL PERFIL 30 DIAS', 'pantalla', 3.03, 2.23, 1.86, 0.5, 0.6, 0.8, 1.73, 30),
      ('UNIVERSAL CTA C 30 DIAS', 'cuenta_completa', 7.17, 5.58, 4.65, 2.5, 3.0, 1.59, 3.08, 30),
      ('VIKI RAKUTEN PERFIL 30 DIAS', 'pantalla', 3.03, 2.23, 1.86, 0.5, 0.6, 0.8, 1.73, 30),
      ('VIKI RAKUTEN CTA C 30 DIAS', 'cuenta_completa', 7.17, 5.58, 4.65, 2.5, 3.0, 1.59, 3.08, 30),
      ('TELELATINO PERFIL 30 DIAS', 'pantalla', 4.5, 3.3, 2.75, 1.0, 1.2, 1.2, 2.3, 30),
      ('TELELTINO PERFIL 90 DIAS', 'pantalla', 12.21, 8.95, 7.46, 3.0, 3.6, 3.26, 5.95, 90),
      ('TELELATINO PERFIL 180 DIAS', 'pantalla', 24.42, 17.89, 14.92, 6.0, 7.19, 6.53, 11.89, 180),
      ('TELELATINO CTA C 30 DIAS', 'cuenta_completa', 8.21, 6.7, 5.59, 3.0, 3.6, 1.51, 3.7, 30),
      ('TELELATINO CTA C 90 DIAS', 'cuenta_completa', 20.61, 17.08, 14.25, 9.0, 10.79, 3.53, 8.08, 90),
      ('TELELATINO CTA C  180 DIAS', 'cuenta_completa', 42.74, 35.67, 29.75, 18.0, 21.58, 7.07, 17.67, 180),
      ('FLUJOTV PERFIL 30 DIAS', 'pantalla', 4.5, 3.3, 2.75, 1.0, 1.2, 1.2, 2.3, 30),
      ('FLUJOTV PERFIL 90 DIAS', 'pantalla', 12.51, 8.5, 7.09, 3.0, 3.6, 4.01, 5.5, 90),
      ('FLUJOTV PERFIL 180+30 DIAS', 'pantalla', 25.42, 17.39, 14.51, 6.0, 7.19, 8.03, 11.39, 210),
      ('FLUJOTV PERFIL 365+60 DIAS', 'pantalla', 50.82, 35.78, 29.84, 12.0, 14.39, 15.04, 23.78, 60),
      ('FLUJOTV CTA C 30 DIAS', 'cuenta_completa', 9.21, 7.15, 5.96, 3.0, 3.6, 2.06, 4.15, 30),
      ('FLUJOTV CTA C 180+30  DIAS', 'cuenta_completa', 51.24, 41.17, 34.34, 18.0, 21.58, 10.07, 23.17, 210),
      ('FLUJOTV CTA C 365+60 DIAS', 'cuenta_completa', 102.47, 82.34, 68.67, 36.0, 43.17, 20.13, 46.34, 60),
      ('CANVA 30 DIAS', 'pantalla', 2.56, 2.06, 1.72, 0.9, 1.08, 0.5, 1.16, 30),
      ('CANVA 90 DIAS', 'pantalla', 7.12, 5.37, 4.48, 1.8, 2.16, 1.75, 3.57, 90),
      ('CANVA 180 DIAS', 'pantalla', 12.23, 9.17, 7.64, 3.4, 4.08, 3.06, 5.77, 180),
      ('SPOTIFY 30 DIAS ALQUILER', 'pantalla', 5.66, 4.65, 3.88, 2.2, 2.64, 1.01, 2.45, 30),
      ('SPOTIFY 60 DIAS ALQUILER', 'pantalla', 10.8, 9.05, 7.54, 4.4, 5.28, 1.75, 4.65, 60),
      ('YOUTUBE PREMIUM 30 DIAS', 'pantalla', 3.11, 2.71, 2.26, 1.7, 2.04, 0.4, 1.01, 30),
      ('YOUTUBE PREMIUM 60 DIAS', 'pantalla', 5.13, 4.77, 3.98, 3.4, 4.08, 0.36, 1.37, 60),
      ('GEMINIS PRO 30 DIAS', 'pantalla', 3.87, 3.56, 2.97, 2.5, 3.0, 0.31, 1.06, 30),
      ('PLEX CTA C 30 DIAS', 'cuenta_completa', 4.64, 3.88, 3.23, 2.0, 2.4, 0.76, 1.88, 30),
      ('DRAMA BOX CTA C  30 DIAS', 'cuenta_completa', 4.1, 3.35, 2.79, 1.5, 1.8, 0.75, 1.85, 30),
      ('DEEZER  CTA C 30 DIAS', 'cuenta_completa', 3.09, 2.59, 2.16, 1.4, 1.68, 0.5, 1.19, 30),
      ('PAQUETE OFFICE 365 30 DIAS', 'pantalla', 3.57, 2.82, 2.35, 1.0, 1.2, 0.75, 1.82, 30),
      ('EMBY CTA C 30 DIAS', 'cuenta_completa', 5.17, 4.36, 3.63, 2.5, 3.0, 0.81, 1.86, 30),
      ('JELLYFIN CTA C 30 DIAS', 'cuenta_completa', 5.17, 4.36, 3.63, 2.5, 3.0, 0.81, 1.86, 30),
      ('COMBO 1 (NETFLIX +VIX)', 'servicio', 6.69, 5.48, 4.57, 2.7, 3.24, 1.21, 2.78, 30),
      ('COMBO 2 (NETFLIX+PRIME)', 'servicio', 7.22, 6.01, 5.01, 3.09, 3.71, 1.21, 2.92, 30),
      ('COMBO 3 (NETFLIX + MAX)', 'servicio', 6.72, 5.81, 4.84, 3.2, 3.84, 0.91, 2.61, 30),
      ('COMBO 4 (NETFLIX + DISNEY)', 'servicio', 8.75, 7.24, 6.04, 3.6, 4.32, 1.51, 3.64, 30),
      ('COMBO 5 (NETFLIX + PARAMOUNT)', 'servicio', 7.71, 6.2, 5.17, 3.1, 3.72, 1.51, 3.1, 30),
      ('COMBO 6 (NETFLIX +CRUNCHYROLL)', 'servicio', 7.71, 6.2, 5.17, 3.1, 3.72, 1.51, 3.1, 30),
      ('3 CUENTAS VIX 30 DIAS', 'cuenta_completa', 10.1, 7.1, 5.92, 1.5, 1.8, 3.0, 5.6, 30),
      ('3 CUENTAS MAX 30 DIAS', 'cuenta_completa', 18.41, 14.64, 12.21, 5.97, 7.16, 3.77, 8.67, 30),
      ('3 CUENTAS PRIME 30 DIAS', 'cuenta_completa', 18.62, 16.14, 13.46, 8.97, 10.76, 2.48, 7.17, 30),
      ('3 CUENTAS PARAMOUNT 30 DIAS', 'cuenta_completa', 18.61, 16.08, 13.41, 9.0, 10.79, 2.53, 7.08, 30),
      ('3 CUENTAS CRUNCHYROOL 30 DIAS', 'cuenta_completa', 14.31, 11.29, 9.42, 4.47, 5.36, 3.02, 6.82, 30)
    ) as t(nombre, tipo, pvp, rvd, usdt, costo_usdt, costo_bs, com_rvd, gan_tienda, duracion)
  loop
    v_cat_id := case 
      when r.tipo = 'cuenta_completa' then 'e23806c0-6237-4dfc-bf16-99a7e8e66b21'::uuid
      when r.tipo = 'servicio' then 'e23806c0-6237-4dfc-bf16-99a7e8e66b22'::uuid
      else 'e23806c0-6237-4dfc-bf16-99a7e8e66b20'::uuid
    end;

    -- Buscar si ya existe por nombre exacto o nombre base
    v_prod_id := null;
    select id into v_prod_id from products
    where lower(trim(nombre)) = lower(trim(r.nombre))
       or (r.nombre = 'NETFLIX NORMAL 30 DIAS' and lower(trim(nombre)) in ('netflix', 'netflix normal'))
       or (r.nombre = 'NETFLIX PERFIL EXTRA NETFLIX 30 DIAS' and lower(trim(nombre)) in ('perfil extra netflix', 'netflix perfil extra'))
       or (r.nombre = 'DISNEY PERFIL 30 DIAS' and lower(trim(nombre)) in ('disney+ premium', 'disney premium'))
       or (r.nombre = 'MAX PERFIL ESTANDAR 30 DIAS' and lower(trim(nombre)) in ('max estándar', 'max estandar'))
       or (r.nombre = 'PRIME VIDEO PERFIL 30 DIAS' and lower(trim(nombre)) in ('amazon prime video', 'prime video'))
       or (r.nombre = 'VIX PERFIL 30 DIAS' and lower(trim(nombre)) in ('vix premium', 'vix'))
       or (r.nombre = 'CRUNCHYROLL PERFIL 30 DIA' and lower(trim(nombre)) in ('crunchyroll fan', 'crunchyroll'))
       or (r.nombre = 'PARAMOUNT PERFIL 30 DIAS' and lower(trim(nombre)) in ('paramount+', 'paramount'))
       or (r.nombre = 'TELELATINO PERFIL 30 DIAS' and lower(trim(nombre)) = 'telelatino')
       or (r.nombre = 'FLUJOTV PERFIL 30 DIAS' and lower(trim(nombre)) in ('flujo tv', 'flujotv'))
    order by id limit 1;

    if v_prod_id is not null then
      update products set
        precio_usd = r.pvp,
        precio_revendedor_usd = r.rvd,
        precio_binance_usd = r.usdt,
        costo_usdt = r.costo_usdt,
        costo_bs = r.costo_bs,
        comision_revendedor_usd = r.com_rvd,
        ganancia_tienda_usd = r.gan_tienda,
        duracion_dias = r.duracion,
        garantia_dias = r.duracion,
        activo = true
      where id = v_prod_id;
    else
      insert into products (
        category_id, nombre, descripcion, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd,
        costo_usdt, costo_bs, comision_revendedor_usd, ganancia_tienda_usd, duracion_dias, garantia_dias, activo
      ) values (
        v_cat_id, r.nombre, 'Servicio Oficial', r.tipo, r.pvp, r.rvd, r.usdt,
        r.costo_usdt, r.costo_bs, r.com_rvd, r.gan_tienda, r.duracion, r.duracion, true
      );
    end if;
  end loop;
end 74778;

-- 4. Tabla de Liquidaciones y Comisiones para Socios / Revendedores (Pablo, etc.)
create table if not exists partner_commissions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade unique,
  customer_id uuid references customers(id) on delete set null,
  vendedor_id uuid not null references customers(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  servicio_nombre text not null,
  monto_cobrado_usd numeric(10,2) not null,
  precio_revendedor_usd numeric(10,2) not null,
  costo_proveedor_usd numeric(10,2) not null default 0.00,
  ganancia_vendedor_usd numeric(10,2) not null default 0.00,
  ganancia_gregory_usd numeric(10,2) not null default 0.00,
  ganancia_negocio_usd numeric(10,2) not null default 0.00,
  tasa_bs numeric(12,4) not null default 50.00,
  ganancia_vendedor_bs numeric(14,2) not null default 0.00,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'liquidada', 'cancelada')),
  liquidada_at timestamptz,
  referencia_pago text,
  notas text,
  created_at timestamptz not null default now()
);

create index if not exists idx_partner_commissions_vendedor on partner_commissions(vendedor_id);
create index if not exists idx_partner_commissions_estado on partner_commissions(estado);

-- RLS para partner_commissions
alter table partner_commissions enable row level security;
drop policy if exists partner_commissions_admin_all on partner_commissions;
create policy partner_commissions_admin_all on partner_commissions for all to authenticated
using (is_admin()) with check (is_admin());

drop policy if exists partner_commissions_reseller_select on partner_commissions;
create policy partner_commissions_reseller_select on partner_commissions for select to authenticated
using (vendedor_id = (select auth.uid()));

-- 5. Función de cálculo automático de comisión al entregar un pedido
create or replace function procesar_comision_socio_orden()
returns trigger
language plpgsql security definer set search_path = public as 74778
declare
  v_seller_id uuid;
  v_prod record;
  v_rate numeric;
  v_pvp numeric;
  v_rvd numeric;
  v_cost numeric;
  v_gan_vendedor numeric;
  v_gan_tienda numeric;
  v_gan_gregory numeric;
  v_gan_negocio numeric;
begin
  if new.estado not in ('entregado', 'pagado') then
    return new;
  end if;

  v_seller_id := new.vendedor_id;
  if v_seller_id is null and new.customer_id is not null then
    select vendedor_id into v_seller_id from customers where id = new.customer_id;
  end if;

  if v_seller_id is null then
    return new;
  end if;

  select bs_por_usd into v_rate from exchange_rates order by fecha desc limit 1;
  v_rate := coalesce(new.tasa_bs, v_rate, 50.00);

  select * into v_prod from products where id = new.product_id;

  v_pvp := coalesce(new.total_usd, v_prod.precio_usd, 0.00);
  v_rvd := coalesce(v_prod.precio_revendedor_usd, v_pvp * 0.80);
  v_cost := coalesce(v_prod.costo_usdt, 0.00);

  -- Comisión de Pablo = PVP cobrado - Precio Revendedor Mayorista
  v_gan_vendedor := greatest(0.00, round(v_pvp - v_rvd, 2));

  -- Ganancia Plataforma = Precio Revendedor Mayorista - Costo Proveedor
  v_gan_tienda := greatest(0.00, round(v_rvd - v_cost, 2));

  -- Reparto: 70% Gregory, 30% Fondo del Negocio
  v_gan_gregory := round(v_gan_tienda * 0.70, 2);
  v_gan_negocio := round(v_gan_tienda - v_gan_gregory, 2);

  insert into partner_commissions (
    order_id, customer_id, vendedor_id, product_id, servicio_nombre,
    monto_cobrado_usd, precio_revendedor_usd, costo_proveedor_usd,
    ganancia_vendedor_usd, ganancia_gregory_usd, ganancia_negocio_usd,
    tasa_bs, ganancia_vendedor_bs, estado
  ) values (
    new.id, new.customer_id, v_seller_id, new.product_id, coalesce(v_prod.nombre, 'Servicio Streaming'),
    v_pvp, v_rvd, v_cost,
    v_gan_vendedor, v_gan_gregory, v_gan_negocio,
    v_rate, round(v_gan_vendedor * v_rate, 2), 'pendiente'
  ) on conflict (order_id) do update set
    vendedor_id = excluded.vendedor_id,
    monto_cobrado_usd = excluded.monto_cobrado_usd,
    precio_revendedor_usd = excluded.precio_revendedor_usd,
    costo_proveedor_usd = excluded.costo_proveedor_usd,
    ganancia_vendedor_usd = excluded.ganancia_vendedor_usd,
    ganancia_gregory_usd = excluded.ganancia_gregory_usd,
    ganancia_negocio_usd = excluded.ganancia_negocio_usd,
    ganancia_vendedor_bs = excluded.ganancia_vendedor_bs;

  return new;
end;
74778;

drop trigger if exists trg_procesar_comision_socio_orden on orders;
create trigger trg_procesar_comision_socio_orden
after insert or update of estado on orders
for each row execute function procesar_comision_socio_orden();

-- 6. Retroalimentar comisiones de las órdenes existentes que tienen vendedor_id
do 74778
declare
  ord record;
begin
  for ord in select * from orders where vendedor_id is not null and estado in ('entregado', 'pagado')
  loop
    perform procesar_comision_socio_orden() from (select ord.*) as new;
  end loop;
end 74778;

-- 7. RPC: liquidar_comisiones_socio(p_vendedor_id, p_referencia, p_notas)
create or replace function liquidar_comisiones_socio(
  p_vendedor_id uuid,
  p_referencia text,
  p_notas text default null
) returns jsonb
language plpgsql security definer set search_path = public as 74778
declare
  v_count int;
  v_total_usd numeric;
  v_total_bs numeric;
begin
  if not is_admin() then
    raise exception 'No autorizado: se requieren permisos de administrador';
  end if;

  select count(*), coalesce(sum(ganancia_vendedor_usd), 0.00), coalesce(sum(ganancia_vendedor_bs), 0.00)
  into v_count, v_total_usd, v_total_bs
  from partner_commissions
  where vendedor_id = p_vendedor_id and estado = 'pendiente';

  if v_count = 0 then
    raise exception 'No hay comisiones pendientes de liquidación para este vendedor';
  end if;

  update partner_commissions
  set estado = 'liquidada',
      liquidada_at = now(),
      referencia_pago = p_referencia,
      notas = coalesce(p_notas, 'Liquidado por administrador')
  where vendedor_id = p_vendedor_id and estado = 'pendiente';

  return jsonb_build_object(
    'ok', true,
    'comisiones_liquidadas', v_count,
    'total_usd', v_total_usd,
    'total_bs', v_total_bs,
    'referencia', p_referencia
  );
end;
74778;

grant execute on function liquidar_comisiones_socio(uuid, text, text) to authenticated;
