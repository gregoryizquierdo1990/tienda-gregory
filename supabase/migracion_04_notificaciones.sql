-- Notificaciones al administrador (Telegram + push) disparadas por la base de datos
-- (Ya incluido al final de schema.sql. Ejecuta este archivo SOLO si ya habias corrido un esquema anterior.)
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
