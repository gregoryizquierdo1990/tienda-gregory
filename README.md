# Tienda Emprendimiento Gregory Izquierdo
Sitio estático + funciones serverless de Vercel + base de datos Supabase. No requiere compilar.

- `GUIA_PASO_A_PASO.md` — instrucciones completas de despliegue y operación (empieza aquí)
- `supabase/schema.sql` — base de datos completa (ejecutar una vez en un proyecto nuevo)
- `supabase/migracion_02_traslados.sql` y `migracion_03_conciliacion_manual.sql` — solo si ya habías ejecutado un esquema anterior (en ese orden)
- `tienda/config.js` — URL y clave pública de Supabase (lo único que editas en el código)
- `tienda/index.html`, `tienda/admin-extra.js` — tienda, portal del cliente y panel administrativo
- `api/` — tasa BCV diaria, bot de Telegram, Gemini (usan variables de entorno de Vercel, ver `.env.example`)
- `vercel.json` — cabeceras de seguridad y tarea diaria de la tasa BCV
- `tienda/manifest.webmanifest`, `tienda/sw.js`, iconos, `.well-known/assetlinks.json` — app instalable (Android/iOS/navegador) y base para el APK
- `PROYECTO.md` — resumen de requisitos y decisiones
- Empieza por `GUIA_PASO_A_PASO.md`

## Estructura (importante)
- `tienda/` = lo que Vercel publica (Root Directory = `tienda`): sitio, `api/`, `vercel.json`, `package.json`, iconos.
- `supabase/` y los `.md` = documentación y base de datos; no se publican.
- Sitio: https://www.gregoryizquierdo.xyz/ (o https://gregoryizquierdo.xyz/)
