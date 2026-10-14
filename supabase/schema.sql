-- Emprendimiento Gregory Izquierdo - esquema Supabase (ejecutar UNA vez completo en SQL Editor)
create extension if not exists pgcrypto with schema extensions;

-- ===== ADMIN: correo oficial + inicio de sesion por Google (OAuth) =====
create table if not exists admins (email text primary key);
insert into admins values ('emprendimientogregoryizquierdo@gmail.com') on conflict do nothing;
create or replace function is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from admins where lower(email) = lower(auth.jwt()->>'email'))
     and (
       coalesce(auth.jwt()->'app_metadata'->>'provider', '') = 'google'
       or exists(select 1 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) a where a->>'method' in ('oauth', 'refresh_token', 'google'))
     ) $$;

-- ===== SECRETOS (llave de cifrado, token Telegram). Nadie del navegador puede leerla =====
create table if not exists secrets (name text primary key, value text not null);
alter table secrets enable row level security;
revoke all on secrets from anon, authenticated;
insert into secrets values ('enc_key', encode(extensions.gen_random_bytes(32),'hex')) on conflict do nothing;

create or replace function enc_text(t text) returns text language sql security definer set search_path = public, extensions as $$
  select 'enc:' || encode(pgp_sym_encrypt(t, (select value from secrets where name='enc_key')), 'base64') $$;
create or replace function dec_text(t text) returns text language sql security definer set search_path = public, extensions as $$
  select pgp_sym_decrypt(decode(substr(t,5),'base64'), (select value from secrets where name='enc_key')) $$;
revoke execute on function enc_text(text), dec_text(text) from public, anon, authenticated;

create or replace function reveal_secret(p text) returns text language plpgsql security definer set search_path = public, extensions as $$
begin if not is_admin() then raise exception 'No autorizado'; end if;
  return case when p like 'enc:%' then dec_text(p) else p end; end $$;

-- ===== AJUSTES =====
create table if not exists settings (key text primary key, value jsonb not null, updated_at timestamptz default now());
insert into settings values
 ('negocio','{"nombre":"Emprendimiento Gregory Izquierdo","rif":"J-50639379-4","telefono":"+584241983648","correo":"emprendimientogregoryizquierdo@gmail.com"}'),
 ('zeny','{"nombre":"Zeny","moneda":"ZenyPoints","valor_usd":1}'),
 ('reserva','{"minutos":60}') on conflict do nothing;
create table if not exists exchange_rates (fecha date primary key default current_date, bs_por_usd numeric(14,4) not null check (bs_por_usd > 0), fuente text default 'BCV', created_at timestamptz default now());

-- ===== CLIENTES =====
create table if not exists customers (
  id uuid primary key references auth.users on delete cascade, nombre text, email text, telefono text,
  zeny_balance numeric(14,2) not null default 0 check (zeny_balance >= 0), gcontact_id text, creado timestamptz default now());
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin insert into customers(id,nombre,email,telefono)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'nombre'), new.email, coalesce(new.phone, new.raw_user_meta_data->>'telefono')) on conflict do nothing;
  return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

-- ===== CATALOGO / BANNERS =====
create table if not exists categories (id uuid primary key default gen_random_uuid(), nombre text not null, orden int default 0, activo boolean default true);
create table if not exists products (
  id uuid primary key default gen_random_uuid(), category_id uuid references categories on delete set null, nombre text not null, descripcion text,
  tipo text not null default 'pantalla' check (tipo in ('pantalla','cuenta_completa','servicio')),
  precio_usd numeric(10,2) not null check (precio_usd >= 0), duracion_dias int not null default 30, garantia_dias int default 30,
  imagen_url text, activo boolean default true, orden int default 0, created_at timestamptz default now());
create table if not exists banners (
  id uuid primary key default gen_random_uuid(), titulo text, texto text, imagen_url text, enlace text, orden int default 0,
  activo boolean default true, inicio date, fin date);

-- ===== INVENTARIO: cuentas madre y perfiles (clave y PIN cifrados) =====
create table if not exists mother_accounts (
  id uuid primary key default gen_random_uuid(), plataforma text not null, correo text not null, clave text, proveedor text,
  costo_usd numeric(10,2) default 0, vence date, max_perfiles int default 5, notas text, activa boolean default true, unique (plataforma, correo));
create table if not exists profiles_inventory (
  id uuid primary key default gen_random_uuid(), mother_id uuid references mother_accounts on delete cascade, product_id uuid references products on delete set null,
  nombre_perfil text, pin text, vendedor text, inicia date, vence date, estado text not null default 'disponible' check (estado in ('disponible','reservado','vendido','suspendido')));
create or replace function enc_mother() returns trigger language plpgsql security definer set search_path = public, extensions as $$
begin if new.clave is not null and new.clave <> '' and new.clave not like 'enc:%' then new.clave := enc_text(new.clave); end if; return new; end $$;
create or replace function enc_profile() returns trigger language plpgsql security definer set search_path = public, extensions as $$
begin if new.pin is not null and new.pin <> '' and new.pin not like 'enc:%' then new.pin := enc_text(new.pin); end if; return new; end $$;
drop trigger if exists t_enc_mother on mother_accounts; create trigger t_enc_mother before insert or update on mother_accounts for each row execute function enc_mother();
drop trigger if exists t_enc_profile on profiles_inventory; create trigger t_enc_profile before insert or update on profiles_inventory for each row execute function enc_profile();

-- ===== PEDIDOS / FACTURAS / WALLET =====
create table if not exists payment_methods (id uuid primary key default gen_random_uuid(), nombre text not null, tipo text, datos jsonb default '{}', activo boolean default true, orden int default 0);
create table if not exists orders (
  id uuid primary key default gen_random_uuid(), customer_id uuid references customers, product_id uuid references products, profile_id uuid references profiles_inventory,
  total_usd numeric(10,2) not null, tasa_bs numeric(14,4), total_bs numeric(16,2), metodo_id uuid references payment_methods, referencia text, comprobante_url text,
  estado text not null default 'pendiente' check (estado in ('pendiente','pagado','entregado','rechazado','vencido','cancelado','reembolsado')),
  inicia date, vence date, proximo_pago date, gcal_event_id text, pagado_at timestamptz, created_at timestamptz default now());
-- Garantia absoluta: un perfil no puede estar en dos pedidos activos a la vez
create unique index if not exists orders_profile_activo on orders(profile_id) where profile_id is not null and estado in ('pendiente','pagado','entregado');
create table if not exists invoices (
  id uuid primary key default gen_random_uuid(), numero bigint generated always as identity, order_id uuid references orders unique, customer_id uuid references customers,
  total_usd numeric(10,2), total_bs numeric(16,2), tasa_bs numeric(14,4), estado text not null default 'emitida' check (estado in ('emitida','anulada')), emitida timestamptz default now());
create table if not exists zeny_ledger (
  id uuid primary key default gen_random_uuid(), customer_id uuid not null references customers, tipo text not null check (tipo in ('recarga','compra','ajuste','reembolso')),
  monto numeric(14,2) not null, referencia text, estado text default 'aprobado' check (estado in ('pendiente','aprobado','rechazado')), created_at timestamptz default now());

-- ===== CONTABILIDAD: devoluciones, gastos y compras =====
create table if not exists refunds (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references orders, customer_id uuid references customers,
  monto_usd numeric(10,2) not null check (monto_usd > 0), destino text not null check (destino in ('zeny','externo')), motivo text, liberado boolean, created_at timestamptz default now());
create table if not exists expenses (id uuid primary key default gen_random_uuid(), fecha date not null default current_date, concepto text not null, categoria text, monto_usd numeric(10,2) not null check (monto_usd >= 0), notas text);
create table if not exists purchases (id uuid primary key default gen_random_uuid(), fecha date not null default current_date, proveedor text, plataforma text, mother_id uuid references mother_accounts on delete set null, monto_usd numeric(10,2) not null check (monto_usd >= 0), notas text);
-- Al registrar una cuenta madre con costo, se anota la compra automaticamente
create or replace function purchase_from_mother() returns trigger language plpgsql security definer set search_path = public as $$
begin if coalesce(new.costo_usd,0) > 0 then insert into purchases(proveedor,plataforma,mother_id,monto_usd,notas) values (new.proveedor,new.plataforma,new.id,new.costo_usd,'Automatico: alta de cuenta madre'); end if; return new; end $$;
drop trigger if exists t_purchase_mother on mother_accounts; create trigger t_purchase_mother after insert on mother_accounts for each row execute function purchase_from_mother();

create or replace function apply_ledger() returns trigger language plpgsql security definer set search_path = public as $$
begin if new.estado = 'aprobado' and (tg_op = 'INSERT' or old.estado <> 'aprobado') then
  update customers set zeny_balance = zeny_balance + new.monto where id = new.customer_id; end if; return new; end $$;
drop trigger if exists t_ledger on zeny_ledger; create trigger t_ledger after insert or update on zeny_ledger for each row execute function apply_ledger();

-- El cliente nunca fija precio, estado ni perfil: se fuerza en servidor
create or replace function orders_guard() returns trigger language plpgsql security definer set search_path = public as $$
declare pr products; r numeric;
begin
  if is_admin() or current_setting('app.internal', true) = '1' then return new; end if;
  select * into pr from products where id = new.product_id and activo;
  if not found then raise exception 'Producto no disponible'; end if;
  select bs_por_usd into r from exchange_rates order by fecha desc limit 1;
  new.customer_id := auth.uid(); new.total_usd := pr.precio_usd; new.tasa_bs := r; new.total_bs := pr.precio_usd * coalesce(r,0);
  new.estado := 'pendiente'; new.profile_id := null; new.inicia := null; new.vence := null; new.proximo_pago := null; new.gcal_event_id := null;
  return new; end $$;
drop trigger if exists t_orders_guard on orders; create trigger t_orders_guard before insert on orders for each row execute function orders_guard();

-- Libera reservas vencidas (por defecto 60 min, editable en settings > reserva)
create or replace function release_expired() returns void language plpgsql security definer set search_path = public as $$
declare m int; r record;
begin
  select coalesce((value->>'minutos')::int, 60) into m from settings where key = 'reserva';
  for r in select id, profile_id from orders where estado = 'pendiente' and created_at < now() - make_interval(mins => coalesce(m,60)) for update skip locked loop
    update orders set estado = 'vencido' where id = r.id;
    if r.profile_id is not null then update profiles_inventory set estado = 'disponible' where id = r.profile_id and estado = 'reservado'; end if;
  end loop;
end $$;

-- Cierra un pedido sin pago (libera el perfil reservado)
create or replace function _close_order(p_order uuid, p_estado text) returns void language plpgsql security definer set search_path = public as $$
declare o orders;
begin
  select * into o from orders where id = p_order for update;
  if o.estado <> 'pendiente' then raise exception 'Solo se puede cerrar un pedido pendiente'; end if;
  update orders set estado = p_estado where id = p_order;
  if o.profile_id is not null then update profiles_inventory set estado = 'disponible' where id = o.profile_id and estado = 'reservado'; end if;
end $$;
create or replace function reject_order(p_order uuid) returns void language plpgsql security definer set search_path = public as $$
begin if not is_admin() then raise exception 'No autorizado'; end if; perform _close_order(p_order, 'rechazado'); end $$;
create or replace function cancel_my_order(p_order uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from orders where id = p_order and customer_id = auth.uid()) then raise exception 'Pedido no encontrado'; end if;
  perform _close_order(p_order, 'cancelado'); end $$;

-- Compra con pago manual: RESERVA el perfil al instante (nadie mas lo puede tomar)
create or replace function create_order(p_product uuid, p_metodo uuid, p_ref text) returns uuid language plpgsql security definer set search_path = public as $$
declare pr products; pf uuid; o uuid; rate numeric;
begin
  if auth.uid() is null then raise exception 'Inicia sesion'; end if;
  perform release_expired();
  select * into pr from products where id = p_product and activo; if not found then raise exception 'Producto no disponible'; end if;
  if pr.tipo <> 'servicio' then
    select id into pf from profiles_inventory where product_id = p_product and estado = 'disponible' order by id limit 1 for update skip locked;
    if pf is null then raise exception 'Agotado'; end if;
    update profiles_inventory set estado = 'reservado' where id = pf;
  end if;
  select bs_por_usd into rate from exchange_rates order by fecha desc limit 1;
  perform set_config('app.internal','1',true);
  insert into orders(customer_id,product_id,profile_id,total_usd,tasa_bs,total_bs,metodo_id,referencia,estado)
  values (auth.uid(),p_product,pf,pr.precio_usd,rate,pr.precio_usd*coalesce(rate,0),p_metodo,left(coalesce(p_ref,''),120),'pendiente') returning id into o;
  return o;
end $$;
grant execute on function create_order(uuid,uuid,text), cancel_my_order(uuid) to authenticated;

-- Entrega: confirma el pago, usa el perfil reservado (o busca otro libre), fija vencimiento y factura
create or replace function _deliver(p_order uuid) returns void language plpgsql security definer set search_path = public as $$
declare o orders; pr products; pf uuid; st text;
begin
  select * into o from orders where id = p_order for update;
  if o.estado not in ('pendiente','pagado','vencido') then raise exception 'Estado de pedido invalido'; end if;
  select * into pr from products where id = o.product_id;
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
  update orders set estado = 'entregado', profile_id = pf, inicia = current_date, vence = current_date + pr.duracion_dias,
    proximo_pago = current_date + pr.duracion_dias, pagado_at = coalesce(pagado_at, now()) where id = p_order;
  insert into invoices(order_id,customer_id,total_usd,total_bs,tasa_bs) select id,customer_id,total_usd,total_bs,tasa_bs from orders where id = p_order on conflict do nothing;
end $$;
create or replace function deliver_order(p_order uuid) returns void language plpgsql security definer set search_path = public as $$
begin if not is_admin() then raise exception 'No autorizado'; end if; perform _deliver(p_order); end $$;
revoke execute on function _deliver(uuid), _close_order(uuid,text), release_expired() from public, anon, authenticated;

create or replace function buy_with_zeny(p_product uuid) returns uuid language plpgsql security definer set search_path = public as $$
declare pr products; o uuid; rate numeric;
begin
  if auth.uid() is null then raise exception 'Inicia sesion'; end if;
  perform release_expired();
  select * into pr from products where id = p_product and activo; if not found then raise exception 'Producto no disponible'; end if;
  if pr.tipo <> 'servicio' and not exists(select 1 from profiles_inventory where product_id = p_product and estado = 'disponible') then raise exception 'Agotado'; end if;
  perform set_config('app.internal','1',true);
  select bs_por_usd into rate from exchange_rates order by fecha desc limit 1;
  insert into zeny_ledger(customer_id,tipo,monto,referencia) values (auth.uid(),'compra',-pr.precio_usd,pr.nombre);
  insert into orders(customer_id,product_id,total_usd,tasa_bs,total_bs,estado) values (auth.uid(),p_product,pr.precio_usd,rate,pr.precio_usd*coalesce(rate,0),'pagado') returning id into o;
  perform _deliver(o); return o;
end $$;

-- Accesos del cliente (solo los suyos, descifrados en el servidor)
create or replace function my_credentials() returns table(order_id uuid, servicio text, tipo text, correo text, clave text, perfil text, pin text, vence date)
language sql security definer set search_path = public, extensions as $$
  select o.id, p.nombre, p.tipo, m.correo, dec_text(m.clave), pi.nombre_perfil, dec_text(pi.pin), o.vence
  from orders o join products p on p.id = o.product_id join profiles_inventory pi on pi.id = o.profile_id join mother_accounts m on m.id = pi.mother_id
  where o.customer_id = auth.uid() and o.estado = 'entregado' $$;
create or replace function stock() returns table(product_id uuid, disponibles bigint) language plpgsql security definer set search_path = public as $$
begin perform release_expired();
  return query select pi.product_id, count(*) from profiles_inventory pi where pi.estado = 'disponible' and pi.product_id is not null group by pi.product_id; end $$;
grant execute on function stock() to anon, authenticated;

-- ===== REEMBOLSO INTELIGENTE =====
-- Total: anula factura, libera (o suspende) el perfil y devuelve a Zeny automaticamente. Parcial: solo registra la devolucion.
create or replace function refund_order(p_order uuid, p_monto numeric, p_destino text, p_motivo text, p_liberar boolean default true) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders; prev numeric; m numeric; rid uuid;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select * into o from orders where id = p_order for update;
  if not found then raise exception 'Pedido no existe'; end if;
  if o.estado not in ('pagado','entregado') then raise exception 'Solo se reembolsan pedidos pagados o entregados'; end if;
  if p_destino not in ('zeny','externo') then raise exception 'Destino invalido'; end if;
  select coalesce(sum(monto_usd),0) into prev from refunds where order_id = p_order;
  m := coalesce(p_monto, o.total_usd - prev);
  if m <= 0 or m + prev > o.total_usd then raise exception 'Monto invalido (maximo reembolsable: %)', o.total_usd - prev; end if;
  insert into refunds(order_id,customer_id,monto_usd,destino,motivo,liberado) values (p_order,o.customer_id,m,p_destino,p_motivo,case when m + prev >= o.total_usd then p_liberar end) returning id into rid;
  if p_destino = 'zeny' then insert into zeny_ledger(customer_id,tipo,monto,referencia) values (o.customer_id,'reembolso',m,'Reembolso pedido '||left(o.id::text,8)); end if;
  if m + prev >= o.total_usd then
    update orders set estado = 'reembolsado' where id = p_order;
    update invoices set estado = 'anulada' where order_id = p_order;
    if o.profile_id is not null then update profiles_inventory set estado = case when p_liberar then 'disponible' else 'suspendido' end, inicia = null, vence = null where id = o.profile_id; end if;
  end if;
  return rid;
end $$;

-- ===== GANANCIAS = ventas - devoluciones - gastos - compras (por mes, en USD) =====
create or replace function finanzas(p_meses int default 12) returns table(mes date, ventas numeric, devoluciones numeric, gastos numeric, compras numeric, ganancia numeric)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  return query
  with m as (select generate_series(date_trunc('month', current_date) - make_interval(months => p_meses - 1), date_trunc('month', current_date), interval '1 month')::date as mes),
  v as (select date_trunc('month', pagado_at)::date as mes, sum(total_usd) t from orders where pagado_at is not null group by 1),
  d as (select date_trunc('month', created_at)::date as mes, sum(monto_usd) t from refunds group by 1),
  g as (select date_trunc('month', fecha)::date as mes, sum(monto_usd) t from expenses group by 1),
  c as (select date_trunc('month', fecha)::date as mes, sum(monto_usd) t from purchases group by 1)
  select m.mes, coalesce(v.t,0), coalesce(d.t,0), coalesce(g.t,0), coalesce(c.t,0), coalesce(v.t,0) - coalesce(d.t,0) - coalesce(g.t,0) - coalesce(c.t,0)
  from m left join v on v.mes = m.mes left join d on d.mes = m.mes left join g on g.mes = m.mes left join c on c.mes = m.mes order by m.mes desc;
end $$;

-- ===== CONTENIDO Y OPERACION =====
create table if not exists faqs (id uuid primary key default gen_random_uuid(), pregunta text, respuesta text, orden int default 0, activo boolean default true);
create table if not exists login_log (id uuid primary key default gen_random_uuid(), customer_id uuid, email text, user_agent text, created_at timestamptz default now());
create table if not exists incidents (id uuid primary key default gen_random_uuid(), customer_id uuid references customers, order_id uuid references orders, asunto text, detalle text, captura_url text,
  estado text default 'abierta' check (estado in ('abierta','en_proceso','resuelta')), created_at timestamptz default now());
create table if not exists google_integrations (service text primary key, enabled boolean default false, config jsonb default '{}', updated_at timestamptz default now());
insert into google_integrations(service) values ('calendar'),('sheets'),('drive'),('contacts'),('gemini') on conflict do nothing;
create table if not exists bot_commands (id uuid primary key default gen_random_uuid(), trigger text not null, response text not null, orden int default 0, activo boolean default true);
insert into bot_commands(trigger,response,orden) values
 ('/start','Hola 👋 Soy el asistente de Emprendimiento Gregory Izquierdo. Escribe /tasa para ver la tasa BCV o /soporte para hablar con nosotros.',1),
 ('/tasa','Tasa oficial BCV de hoy: {tasa} Bs/USD',2),
 ('/soporte','Escríbenos por WhatsApp: {telefono} o al correo {correo}',3),
 ('*','No entendí tu mensaje. Usa /tasa o /soporte.',99) on conflict do nothing;

-- ===== STORAGE (capturas privadas, catalogo publico) =====
insert into storage.buckets(id,name,public) values ('capturas','capturas',false), ('catalogo','catalogo',true) on conflict do nothing;
create policy cap_ins on storage.objects for insert to authenticated with check (bucket_id='capturas' and (storage.foldername(name))[1] = auth.uid()::text);
create policy cap_sel on storage.objects for select to authenticated using (bucket_id='capturas' and ((storage.foldername(name))[1] = auth.uid()::text or is_admin()));
create policy cat_admin on storage.objects for all to authenticated using (bucket_id='catalogo' and is_admin()) with check (bucket_id='catalogo' and is_admin());
create policy cat_pub on storage.objects for select using (bucket_id='catalogo');

-- ===== RLS: todo cerrado salvo lo explicitamente permitido =====
do $$ declare t text; begin
 foreach t in array array['admins','settings','exchange_rates','customers','categories','products','banners','mother_accounts','profiles_inventory','payment_methods','orders','invoices','zeny_ledger','faqs','login_log','incidents','google_integrations','bot_commands','expenses','purchases'] loop
  execute format('alter table %I enable row level security', t);
  execute format('drop policy if exists admin_all on %I', t);
  execute format('create policy admin_all on %I for all to authenticated using (is_admin()) with check (is_admin())', t);
 end loop; end $$;
alter table refunds enable row level security;
create policy ref_admin on refunds for select to authenticated using (is_admin());
create policy ref_me on refunds for select to authenticated using (customer_id = auth.uid());
create policy pub_settings on settings for select using (key in ('negocio','zeny','reserva'));
create policy pub_rates on exchange_rates for select using (true);
create policy pub_cat on categories for select using (activo);
create policy pub_prod on products for select using (activo);
create policy pub_ban on banners for select using (activo and (inicio is null or inicio <= current_date) and (fin is null or fin >= current_date));
create policy pub_pm on payment_methods for select using (activo);
create policy pub_faq on faqs for select using (activo);
create policy me_cust on customers for select to authenticated using (id = auth.uid());
create policy me_cust_upd on customers for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy me_orders on orders for select to authenticated using (customer_id = auth.uid());
create policy me_inv on invoices for select to authenticated using (customer_id = auth.uid());
create policy me_ledger on zeny_ledger for select to authenticated using (customer_id = auth.uid());
create policy me_recarga on zeny_ledger for insert to authenticated with check (customer_id = auth.uid() and tipo = 'recarga' and estado = 'pendiente' and monto > 0);
create policy me_inc_sel on incidents for select to authenticated using (customer_id = auth.uid());
create policy me_inc_ins on incidents for insert to authenticated with check (customer_id = auth.uid() and estado = 'abierta');
create policy me_log on login_log for insert to authenticated with check (customer_id = auth.uid());

-- ===== REALTIME =====
do $$ declare t text; begin
 foreach t in array array['settings','exchange_rates','customers','products','banners','orders','zeny_ledger','faqs','incidents','payment_methods','login_log','profiles_inventory','mother_accounts','bot_commands','refunds','expenses','purchases'] loop
  begin execute format('alter publication supabase_realtime add table %I', t); exception when duplicate_object then null; end;
 end loop; end $$;

create table if not exists transfers (
  id uuid primary key default gen_random_uuid(), order_id uuid references orders, customer_id uuid references customers,
  from_profile uuid references profiles_inventory on delete set null, to_profile uuid references profiles_inventory on delete set null,
  motivo text, created_at timestamptz default now());
alter table transfers enable row level security;
create policy tr_admin on transfers for select to authenticated using (is_admin());

-- Traslada al cliente a otro perfil libre de la MISMA plataforma, conservando sus dias contratados
create or replace function transfer_order(p_order uuid, p_new_profile uuid, p_motivo text, p_liberar_anterior boolean default true) returns void
language plpgsql security definer set search_path = public as $$
declare o orders; st text; pa text; pb text;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select * into o from orders where id = p_order for update;
  if not found or o.estado <> 'entregado' or o.profile_id is null then raise exception 'Solo se trasladan pedidos entregados con perfil asignado'; end if;
  if p_new_profile = o.profile_id then raise exception 'Es el mismo perfil'; end if;
  select m.plataforma into pa from profiles_inventory pi join mother_accounts m on m.id = pi.mother_id where pi.id = o.profile_id;
  select pi.estado, m.plataforma into st, pb from profiles_inventory pi join mother_accounts m on m.id = pi.mother_id where pi.id = p_new_profile for update of pi;
  if st is distinct from 'disponible' then raise exception 'El perfil destino no esta disponible'; end if;
  if pa is distinct from pb then raise exception 'El traslado debe ser dentro de la misma plataforma (% / %)', pa, pb; end if;
  update profiles_inventory set estado = 'vendido', inicia = o.inicia, vence = o.vence where id = p_new_profile;
  update profiles_inventory set estado = case when p_liberar_anterior then 'disponible' else 'suspendido' end, inicia = null, vence = null where id = o.profile_id;
  update orders set profile_id = p_new_profile where id = p_order;
  insert into transfers(order_id, customer_id, from_profile, to_profile, motivo) values (p_order, o.customer_id, o.profile_id, p_new_profile, p_motivo);
end $$;

-- Crea N perfiles disponibles para una cuenta madre (respeta max_perfiles)
create or replace function generate_profiles(p_mother uuid, p_product uuid, p_cantidad int, p_prefijo text default 'Perfil') returns int
language plpgsql security definer set search_path = public as $$
declare m mother_accounts; ya int; i int;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  select * into m from mother_accounts where id = p_mother; if not found then raise exception 'Cuenta no existe'; end if;
  select count(*) into ya from profiles_inventory where mother_id = p_mother;
  if p_cantidad < 1 or ya + p_cantidad > coalesce(m.max_perfiles, 5) then raise exception 'Excede el maximo de perfiles de la cuenta (% de %)', ya, m.max_perfiles; end if;
  for i in 1..p_cantidad loop
    insert into profiles_inventory(mother_id, product_id, nombre_perfil, estado) values (p_mother, p_product, p_prefijo || ' ' || (ya + i), 'disponible');
  end loop;
  return p_cantidad;
end $$;

do $$ begin alter publication supabase_realtime add table transfers; exception when duplicate_object then null; end $$;

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

create extension if not exists pg_net with schema extensions;

create table if not exists push_subscriptions (
  id uuid primary key default gen_random_uuid(), endpoint text unique not null, p256dh text not null, auth text not null,
  user_agent text, created_at timestamptz default now());
alter table push_subscriptions enable row level security;
drop policy if exists admin_all on push_subscriptions;
create policy admin_all on push_subscriptions for all to authenticated using (is_admin()) with check (is_admin());

-- Aviso al servidor de la tienda (/api/notify). Si falla, NUNCA bloquea la operacion original.
create or replace function notify_admin(p_kind text, p_msg text) returns void language plpgsql security definer set search_path = public, extensions as $$
declare u text; s text;
begin
  select value into u from secrets where name = 'notify_url'; select value into s from secrets where name = 'notify_secret';
  if u is null or s is null then return; end if;
  perform net.http_post(url := u, headers := jsonb_build_object('Content-Type','application/json','x-notify-secret', s), body := jsonb_build_object('kind', p_kind, 'msg', p_msg));
exception when others then null;
end $$;
revoke execute on function notify_admin(text, text) from public, anon, authenticated;

create or replace function trg_notify_order() returns trigger language plpgsql security definer set search_path = public, extensions as $$
declare pn text;
begin
  if new.estado = 'pendiente' then
    select nombre into pn from products where id = new.product_id;
    perform notify_admin('order', 'Nuevo pedido pendiente: ' || coalesce(pn,'producto') || ' ($' || new.total_usd || ')');
  end if; return new;
end $$;
create or replace function trg_notify_recarga() returns trigger language plpgsql security definer set search_path = public, extensions as $$
begin
  if new.tipo = 'recarga' and new.estado = 'pendiente' then perform notify_admin('recarga', 'Nueva recarga Zeny por aprobar: $' || new.monto); end if; return new;
end $$;
create or replace function trg_notify_incident() returns trigger language plpgsql security definer set search_path = public, extensions as $$
begin perform notify_admin('incidencia', 'Nueva incidencia: ' || left(coalesce(new.asunto,'sin asunto'), 80)); return new; end $$;
revoke execute on function trg_notify_order(), trg_notify_recarga(), trg_notify_incident() from public, anon, authenticated;

drop trigger if exists t_notify_order on orders; create trigger t_notify_order after insert on orders for each row execute function trg_notify_order();
drop trigger if exists t_notify_recarga on zeny_ledger; create trigger t_notify_recarga after insert on zeny_ledger for each row execute function trg_notify_recarga();
drop trigger if exists t_notify_incident on incidents; create trigger t_notify_incident after insert on incidents for each row execute function trg_notify_incident();

-- Destino de los avisos (solo visible para el administrador). Editable en Admin > notificaciones.
insert into settings values ('notificaciones','{"telegram_chat_id":"7154250409"}') on conflict do nothing;

revoke execute on function apply_ledger(), enc_mother(), enc_profile(), orders_guard(), purchase_from_mother(), handle_new_user() from public, anon, authenticated;
revoke execute on function is_admin(), deliver_order(uuid), reject_order(uuid), transfer_order(uuid,uuid,text,boolean), generate_profiles(uuid,uuid,int,text),
  finanzas(int), reveal_secret(text), refund_order(uuid,numeric,text,text,boolean), my_credentials(), cancel_my_order(uuid) from public, anon;
grant execute on function is_admin(), deliver_order(uuid), reject_order(uuid), transfer_order(uuid,uuid,text,boolean), generate_profiles(uuid,uuid,int,text),
  finanzas(int), reveal_secret(text), refund_order(uuid,numeric,text,text,boolean), my_credentials(), cancel_my_order(uuid) to authenticated;
revoke execute on function stock() from public;
grant execute on function stock() to anon, authenticated;

create index if not exists idx_incidents_customer on incidents(customer_id);
create index if not exists idx_incidents_order on incidents(order_id);
create index if not exists idx_invoices_customer on invoices(customer_id);
create index if not exists idx_orders_customer on orders(customer_id);
create index if not exists idx_orders_metodo on orders(metodo_id);
create index if not exists idx_orders_product on orders(product_id);
create index if not exists idx_orders_pendientes on orders(created_at) where estado = 'pendiente';
create index if not exists idx_orders_vence on orders(vence) where estado = 'entregado';
create index if not exists idx_products_category on products(category_id);
create index if not exists idx_profiles_mother on profiles_inventory(mother_id);
create index if not exists idx_profiles_product_estado on profiles_inventory(product_id, estado);
create index if not exists idx_purchases_mother on purchases(mother_id);
create index if not exists idx_refunds_customer on refunds(customer_id);
create index if not exists idx_refunds_order on refunds(order_id);
create index if not exists idx_transfers_customer on transfers(customer_id);
create index if not exists idx_transfers_order on transfers(order_id);
create index if not exists idx_transfers_from on transfers(from_profile);
create index if not exists idx_transfers_to on transfers(to_profile);
create index if not exists idx_ledger_customer on zeny_ledger(customer_id);
create index if not exists idx_ledger_order on zeny_ledger(order_id);

drop policy if exists ref_me on refunds;
create policy ref_me on refunds for select to authenticated using (customer_id = (select auth.uid()));
drop policy if exists me_cust on customers;
create policy me_cust on customers for select to authenticated using (id = (select auth.uid()));
drop policy if exists me_cust_upd on customers;
create policy me_cust_upd on customers for update to authenticated using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
drop policy if exists me_orders on orders;
create policy me_orders on orders for select to authenticated using (customer_id = (select auth.uid()));
drop policy if exists me_inv on invoices;
create policy me_inv on invoices for select to authenticated using (customer_id = (select auth.uid()));
drop policy if exists me_ledger on zeny_ledger;
create policy me_ledger on zeny_ledger for select to authenticated using (customer_id = (select auth.uid()));
drop policy if exists me_recarga on zeny_ledger;
create policy me_recarga on zeny_ledger for insert to authenticated with check (customer_id = (select auth.uid()) and tipo = 'recarga' and estado = 'pendiente' and monto > 0);
drop policy if exists me_inc_sel on incidents;
create policy me_inc_sel on incidents for select to authenticated using (customer_id = (select auth.uid()));
drop policy if exists me_inc_ins on incidents;
create policy me_inc_ins on incidents for insert to authenticated with check (customer_id = (select auth.uid()) and estado = 'abierta');
drop policy if exists me_log on login_log;
create policy me_log on login_log for insert to authenticated with check (customer_id = (select auth.uid()));
