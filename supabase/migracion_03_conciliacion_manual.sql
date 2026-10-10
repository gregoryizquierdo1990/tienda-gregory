-- Conciliacion MANUAL obligatoria (tambien con ZenyPoints, pago total o parcial) + ajustes de app instalable
-- (Ya incluido al final de schema.sql. Ejecuta este archivo SOLO si ya habias corrido el esquema anterior.)
alter table orders add column if not exists zeny_aplicado numeric(10,2) not null default 0 check (zeny_aplicado >= 0);
alter table orders add column if not exists conciliado_por text;
alter table orders add column if not exists conciliado_at timestamptz;
alter table zeny_ledger add column if not exists order_id uuid references orders;

-- Se elimina la compra automatica con Zeny: nada se entrega sin revision del administrador
drop function if exists buy_with_zeny(uuid);
drop function if exists create_order(uuid, uuid, text);

-- Libera reservas vencidas y sus retenciones Zeny
create or replace function release_expired() returns void language plpgsql security definer set search_path = public as $$
declare m int; r record;
begin
  select coalesce((value->>'minutos')::int, 60) into m from settings where key = 'reserva';
  for r in select id, profile_id from orders where estado = 'pendiente' and created_at < now() - make_interval(mins => coalesce(m,60)) for update skip locked loop
    update orders set estado = 'vencido' where id = r.id;
    update zeny_ledger set estado = 'rechazado' where order_id = r.id and tipo = 'compra' and estado = 'pendiente';
    if r.profile_id is not null then update profiles_inventory set estado = 'disponible' where id = r.profile_id and estado = 'reservado'; end if;
  end loop;
end $$;

create or replace function _close_order(p_order uuid, p_estado text) returns void language plpgsql security definer set search_path = public as $$
declare o orders;
begin
  select * into o from orders where id = p_order for update;
  if o.estado <> 'pendiente' then raise exception 'Solo se puede cerrar un pedido pendiente'; end if;
  update orders set estado = p_estado where id = p_order;
  update zeny_ledger set estado = 'rechazado' where order_id = p_order and tipo = 'compra' and estado = 'pendiente';
  if o.profile_id is not null then update profiles_inventory set estado = 'disponible' where id = o.profile_id and estado = 'reservado'; end if;
end $$;

-- Pedido del cliente: reserva el perfil y RETIENE (no cobra) los ZenyPoints indicados. Pago total o parcial con Zeny.
create or replace function create_order(p_product uuid, p_metodo uuid, p_ref text, p_zeny numeric default 0) returns uuid
language plpgsql security definer set search_path = public as $$
declare pr products; pf uuid; o uuid; rate numeric; bal numeric; holds numeric; z numeric := coalesce(p_zeny, 0);
begin
  if auth.uid() is null then raise exception 'Inicia sesion'; end if;
  perform release_expired();
  select * into pr from products where id = p_product and activo; if not found then raise exception 'Producto no disponible'; end if;
  if z < 0 or z > pr.precio_usd then raise exception 'Monto Zeny invalido'; end if;
  if z < pr.precio_usd and p_metodo is null then raise exception 'Elige un metodo de pago para el resto'; end if;
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
  insert into orders(customer_id,product_id,profile_id,total_usd,tasa_bs,total_bs,metodo_id,referencia,estado,zeny_aplicado)
  values (auth.uid(),p_product,pf,pr.precio_usd,rate,pr.precio_usd*coalesce(rate,0),p_metodo,left(coalesce(p_ref,''),120),'pendiente',z) returning id into o;
  if z > 0 then insert into zeny_ledger(customer_id,tipo,monto,referencia,estado,order_id) values (auth.uid(),'compra',-z,'Retencion pedido '||left(o::text,8),'pendiente',o); end if;
  return o;
end $$;
revoke execute on function create_order(uuid,uuid,text,numeric) from public, anon;
grant execute on function create_order(uuid,uuid,text,numeric) to authenticated;

-- Conciliacion: SOLO el administrador. Entrega, cobra los Zeny retenidos, factura y deja constancia de quien concilio
create or replace function _deliver(p_order uuid) returns void language plpgsql security definer set search_path = public as $$
declare o orders; pr products; pf uuid; st text;
begin
  select * into o from orders where id = p_order for update;
  if o.estado not in ('pendiente','pagado','vencido') then raise exception 'Estado de pedido invalido'; end if;
  select * into pr from products where id = o.product_id;
  if o.zeny_aplicado > 0 and coalesce((select zeny_balance from customers where id = o.customer_id),0) < o.zeny_aplicado then raise exception 'Saldo Zeny insuficiente del cliente'; end if;
  if pr.tipo <> 'servicio' then
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
  if o.zeny_aplicado > 0 then
    update zeny_ledger set estado = 'aprobado' where order_id = p_order and tipo = 'compra' and estado = 'pendiente';
    if not found then insert into zeny_ledger(customer_id,tipo,monto,referencia,estado,order_id) values (o.customer_id,'compra',-o.zeny_aplicado,'Pedido '||left(p_order::text,8),'aprobado',p_order); end if;
  end if;
  update orders set estado = 'entregado', profile_id = pf, inicia = current_date, vence = current_date + pr.duracion_dias, proximo_pago = current_date + pr.duracion_dias,
    pagado_at = coalesce(pagado_at, now()), conciliado_por = coalesce(auth.jwt()->>'email','sistema'), conciliado_at = now() where id = p_order;
  insert into invoices(order_id,customer_id,total_usd,total_bs,tasa_bs) select id,customer_id,total_usd,total_bs,tasa_bs from orders where id = p_order on conflict do nothing;
end $$;

-- Configuracion publica de la app (enlace del APK editable desde Admin > settings > app)
insert into settings values ('app','{"apk_url":""}') on conflict do nothing;
drop policy if exists pub_settings on settings;
create policy pub_settings on settings for select using (key in ('negocio','zeny','reserva','app'));
