-- ==============================================================================
-- MIGRACIÓN 40: Guardar URL del APK en settings y habilitar guardado sin congelamiento
-- ==============================================================================
-- 1. Guarda el enlace oficial del APK de GitHub Releases en la tabla settings.
-- 2. Asegura que is_admin() reconozca a Gregory tanto con Google como con Correo/Clave.
-- 3. Habilita permisos para que el administrador pueda editar settings desde la web.

begin;

-- 1. Actualizar directamente el enlace del APK en la tabla settings
insert into public.settings (key, value, updated_at)
values (
  'app',
  '{"apk_url": "https://github.com/gregoryizquierdo1990/tienda-gregory/releases/download/v1.0.0/Emprendimiento-Gregory-Izquierdo.apk"}'::jsonb,
  now()
)
on conflict (key) do update set 
  value = excluded.value,
  updated_at = now();

-- 2. Asegurar que los correos de Gregory estén en la tabla admins
insert into public.admins (email)
values 
  ('emprendimientogregoryizquierdo@gmail.com'),
  ('gregoryizquierdo1990@gmail.com')
on conflict (email) do nothing;

-- 3. Blindar la función is_admin() para que funcione con cualquier método de inicio de sesión (Google o Correo/Contraseña)
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from public.admins
    where lower(admins.email) = lower(auth.jwt()->>'email')
  ) or lower(coalesce(auth.jwt()->>'email', '')) in (
    'emprendimientogregoryizquierdo@gmail.com',
    'gregoryizquierdo1990@gmail.com'
  );
$$;

grant execute on function public.is_admin() to authenticated;

-- 4. Asegurar política de lectura y actualización en settings
drop policy if exists pub_settings on public.settings;
create policy pub_settings on public.settings for select using (
  key in ('negocio', 'zeny', 'reserva', 'app', 'plantillas_mensajes', 'niveles_beneficios', 'mesa_cambio_config')
);

drop policy if exists admin_settings on public.settings;
create policy admin_settings on public.settings for all to authenticated
using (public.is_admin())
with check (public.is_admin());

commit;
