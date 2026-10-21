-- ==============================================================================
-- MIGRACIÓN 55: NOTIFICACIONES PUSH Y ALERTAS EN VIVO PARA REVENDEDORES Y CLIENTES
-- 1. Agregar columna user_id a push_subscriptions
-- 2. Políticas RLS para que usuarios autenticados gestionen sus suscripciones push
-- 3. Funciones RPC save_my_push_subscription y delete_my_push_subscription
-- ==============================================================================

alter table public.push_subscriptions add column if not exists user_id uuid references auth.users(id) on delete cascade;

create index if not exists idx_push_subscriptions_user on public.push_subscriptions(user_id);

-- Política RLS para usuarios autenticados
drop policy if exists push_subscriptions_user on public.push_subscriptions;
create policy push_subscriptions_user on public.push_subscriptions
for all to authenticated
using (user_id = auth.uid() or is_admin() or user_id is null)
with check (user_id = auth.uid() or is_admin());

-- RPC para guardar la suscripción push del usuario
create or replace function public.save_my_push_subscription(
  p_endpoint text,
  p_p256dh text,
  p_auth text,
  p_user_agent text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if p_endpoint is null or p_p256dh is null or p_auth is null then
    return jsonb_build_object('success', false, 'error', 'Parámetros inválidos');
  end if;

  insert into public.push_subscriptions (endpoint, p256dh, auth, user_agent, user_id, created_at)
  values (p_endpoint, p_p256dh, p_auth, coalesce(p_user_agent, ''), v_user_id, now())
  on conflict (endpoint) do update
  set p256dh = excluded.p256dh,
      auth = excluded.auth,
      user_agent = excluded.user_agent,
      user_id = coalesce(excluded.user_id, push_subscriptions.user_id),
      created_at = now();

  return jsonb_build_object('success', true);
end;
$$;

revoke execute on function public.save_my_push_subscription(text, text, text, text) from public;
grant execute on function public.save_my_push_subscription(text, text, text, text) to authenticated, anon;

-- RPC para eliminar suscripción push
create or replace function public.delete_my_push_subscription(
  p_endpoint text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  delete from public.push_subscriptions
  where endpoint = p_endpoint
    and (user_id = auth.uid() or is_admin() or user_id is null);
  return jsonb_build_object('success', true);
end;
$$;

revoke execute on function public.delete_my_push_subscription(text) from public;
grant execute on function public.delete_my_push_subscription(text) to authenticated, anon;
