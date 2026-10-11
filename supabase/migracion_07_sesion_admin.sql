-- Migración 07: Mantener permisos de administrador al refrescar sesión (refresh_token)
-- En Supabase, cuando un token expira (1 hora) y se renueva automáticamente con el refresh_token,
-- el campo 'amr' pasa de 'oauth' a 'refresh_token'. Esta función asegura que el administrador no pierda
-- el acceso al dejar el panel inactivo o volver más tarde.

create or replace function is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from admins where lower(email) = lower(auth.jwt()->>'email'))
     and (
       coalesce(auth.jwt()->'app_metadata'->>'provider', '') = 'google'
       or exists(select 1 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) a where a->>'method' in ('oauth', 'refresh_token', 'google'))
     ) $$;

revoke execute on function is_admin() from public, anon;
grant execute on function is_admin() to authenticated;
