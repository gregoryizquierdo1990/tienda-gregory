-- ==============================================================================
-- MIGRACIÓN 39: Configurar URL oficial de descarga del APK Android de la Tienda
-- ==============================================================================
-- Esta migración configura en la tabla 'settings' (clave 'app') el enlace
-- directo de descarga del archivo APK alojado en GitHub Releases (v1.0.0).
-- Al activarse, los usuarios en Android verán automáticamente la opción
-- "Descargar APK (Android)" al hacer clic en "Instalar App".

insert into public.settings (key, value, updated_at)
values (
  'app',
  jsonb_build_object(
    'apk_url', 'https://github.com/gregoryizquierdo1990/tienda-gregory/releases/download/v1.0.0/Emprendimiento-Gregory-Izquierdo.apk'
  ),
  now()
)
on conflict (key) do update set 
  value = excluded.value,
  updated_at = now();

-- Asegurar que la política de lectura pública permita consultar 'app'
drop policy if exists pub_settings on public.settings;
create policy pub_settings on public.settings for select using (
  key in ('negocio', 'zeny', 'reserva', 'app', 'plantillas_mensajes', 'niveles_beneficios', 'mesa_cambio_config')
);
