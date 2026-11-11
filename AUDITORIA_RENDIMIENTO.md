# Auditoría de rendimiento — tienda-gregory

Fecha: 2026-11-10. Alcance: frontend (index.html + admin-extra.js), API serverless (tienda/api), base de datos (supabase/), infra (Vercel), PWA/Service Worker.

## Resumen ejecutivo

- **Carga inicial pesada**: `index.html` ≈ 685 KB (12.177 líneas) y `admin-extra.js` ≈ 635 KB (11.698 líneas). Todo en un solo archivo HTML/JS sin build ni minificación. Los clientes descargan ~685 KB antes de pintar.
- **Realtime consolidado**: antes 3 canales (`pub`, `alerts`, `live`) con ~34 suscripciones; ahora `alerts` y `live` se fusionaron en un solo canal `_liveCh`. `badge()` throttled a 30 s. Canales se desmontan en logout (`teardownRealtime`).
- **Consultas amplias**: 36 usos de `.select('*')` (21 en index, 15 en admin-extra) que traen columnas pesadas (claves/PIN cifrados, blobs) aunque no se usen.
- **Base de datos**: migración `06_rendimiento` ya añadió índices FK y RLS con `(select auth.uid())`. Faltaban índices en `orders.profile_id`, `orders.vendedor_id`, `profiles_inventory.vendedor_id/assigned_customer_id`, etc. (creados en `migracion_65`).
- **Infra**: `engines.node` estaba en `26.x` (experimental en Vercel) → bajado a `20.x` (LTS). Faltaban cabeceras de caché para assets estáticos → añadidas en `vercel.json`.
- **Imágenes**: `logo.png` (302 KB) y `logo-badge.png` (272 KB) sin optimizar; varias `<img>` sin `loading="lazy"` (corregido parcialmente).
- **Service Worker**: solo cachea la cáscara (network-first). Correcto para datos, pero no cachea assets CDN. Aceptable.

## Métricas observadas

| Archivo | Tamaño | Líneas |
|---|---|---|
| tienda/index.html | 685 KB | 12.177 |
| tienda/admin-extra.js | 635 KB | 11.698 |
| tienda/sw.js | 4 KB | 21 |
| CSS inline (index) | 79 KB | — |
| logo.png | 302 KB | — |
| logo-badge.png | 272 KB | — |

Patrones en código:
- `innerHTML`: 101 (index) / 118 (admin-extra) → re-render de listas completas.
- `querySelectorAll`: 72 / 104.
- `setInterval`: 2 (index) — `checkVenc` cada 1 h (aceptable).
- `setTimeout`: 25 / 16.
- `.select('*')`: 21 / 15.
- Realtime channels: `pub`, `alerts`, `live` (17 tablas en `live`).

## Hallazgos y recomendaciones

### 1. Frontend — carga inicial (alto impacto)
**Problema**: monolito HTML de 685 KB; CSS inline 79 KB; Supabase UMD + confetti desde CDN; fuente Sora.
**Acciones aplicadas**:
- `loading="lazy" decoding="async"` en imágenes no críticas (watermark, badge, KYC, banners).
- Cabeceras de caché en `vercel.json` para imágenes/JS/CSS (SWR).
- **Imágenes optimizadas**: `logo.png` (302 KB) y `logo-badge.png` (272 KB) convertidas a WebP con fallback PNG via `<picture>`: `logo.webp` (51 KB, −83%) y `logo-badge.webp` (31 KB, −89%). PNGs recomprimados. Service Worker cachea los WebP y bump de versión a `gi-v20`.
**Pendiente (alto esfuerzo)**:
- Separar CSS a archivo externo con cache largo.
- Minificar/bundlear (introducir build step con Vite) — hoy "sin compilación" por decisión de proyecto.
- Lazy-load `canvas-confetti` solo cuando se confirma pedido.

### 2. Runtime — re-renders y realtime (alto impacto)
**Problema**: canal `live` suscribe 17 tablas con `event:'*'` y llama `refresh()`; `refresh()` re-ejecuta `portal()`/`admin()` completos. El debounce de 1.2 s ayuda pero en admin activo sigue siendo costoso. `badge()` hace 3 `count` queries en cada refresh.
**Recomendaciones**:
- Filtrar eventos por tabla/vista: solo recargar la vista activa cuando la tabla afectada es relevante (ya parcialmente implementado en `refresh` con `isDirectMatch`).
- Throttle `badge()` a cada 30 s en lugar de cada evento.
- Desuscribir canales al cerrar sesión / cambiar de vista (hoy persisten).
- Evitar `innerHTML` masivo: usar templates + `insertAdjacentHTML` o actualización incremental. Alto esfuerzo.

### 3. Consultas a Supabase (medio impacto) — parcialmente aplicado
**Problema**: 36 `.select('*')` (21 en index, 15 en admin-extra) traen columnas sensibles/pesadas.
**Aplicado**:
- `profiles_inventory` con `products(*), mother_accounts(*)` → columnas explícitas (id, nombre_perfil, pin, vence, product_id, mother_id, products(nombre, precio_usd, precio_revendedor_usd), mother_accounts(plataforma, correo)).
- `public_franchises` → columnas explícitas.
- Fallback de listado de `orders` en admin → mismas columnas explícitas del query principal.
**Pendiente (bajo impacto, riesgo de romper)**: los `select('*')` restantes en tablas pequeñas/admin (payment_methods, settings, banners, products, customers, incidents, zeny_ledger, etc.). Mantener por ahora; su impacto en payload es bajo y requieren revisar cada uso.

### 4. Base de datos (medio impacto)
**Aplicado**:
- `migracion_65_indices_rendimiento.sql` con índices FK/filtrado faltantes.
- `schema.sql`: políticas RLS actualizadas a `(select auth.uid())` (evita re-evaluación por fila).
**Pendiente**:
- Revisar funciones SQL con `for update` y locks; `transfer_order`, `deliver_order` bloquean filas. Aceptable para concurrencia baja, pero monitorear contención.
- Realtime publica 17 tablas → tráfico elevado. Considerar publicar solo `orders`, `profiles_inventory`, `zeny_ledger` y usar polling para el resto.

### 5. Serverless / Vercel (bajo-medio impacto)
**Aplicado**: `engines.node` 20.x (LTS) en root y `tienda/`.
**Observaciones**:
- 10 endpoints agrupados por rewrites (límite Hobby 12 funciones). OK.
- `requireAdmin` hace 2 fetch por request (auth + admins). Aceptable; podría cachear admins en memoria (cold start).
- `ejecutar-reportes-diarios` cron diario 12:00 UTC; revisar que no supere timeout (10 s Hobby). El endpoint hace trabajo pesado (Google Calendar, Sheets). Verificar duración en logs.

### 6. Seguridad (no rendimiento, pero crítico)
- `root/.env` contiene `GEMINI_API_KEY` real y `CRON_SECRET`. Aunque `.gitignore` excluye `.env`, el archivo existe en disco del desarrollador y la clave ya pudo filtrarse por el historial de commits previos. **Rotar `GEMINI_API_KEY` y `CRON_SECRET`** y limpiar historial si fue commiteado.
- `SUPABASE_SERVICE_KEY` vacío en `.env` (correcto que no esté en repo).

### 7. PWA / Service Worker
- Versión cache `gi-v19`; bump al desplegar cambios de shell.
- `fetch` handler hace `fetch` siempre (network-first) → sin offline real, pero garantiza datos frescos. OK.

## Cambios aplicados en este commit de auditoría
1. `supabase/schema.sql`: RLS `(select auth.uid())`.
2. `package.json` / `tienda/package.json`: `engines.node` 20.x.
3. `tienda/vercel.json`: cabeceras de caché para assets.
4. `tienda/index.html`: `loading="lazy" decoding="async"` en imágenes no críticas + conversión a WebP con fallback PNG.
5. `tienda/admin-extra.js`: `loading="lazy" decoding="async"` en imágenes KYC.
6. `tienda/sw.js`: bump cache a `gi-v20` y precache de WebP.
5. `supabase/migracion_65_indices_rendimiento.sql`: índices adicionales.
6. `AUDITORIA_RENDIMIENTO.md`: este informe.
7. `tienda/index.html`: consolidación de canales Realtime (`_liveCh`), throttle de `badge()` (30 s), desuscripción en logout (`teardownRealtime`).
8. `tienda/index.html` / `tienda/admin-extra.js`: `.select('*')` → columnas explícitas en `profiles_inventory` anidado, `public_franchises` y fallback de `orders`.

## Próximos pasos sugeridos (orden de impacto)
1. Optimizar imágenes (WebP) y CSS externo.
2. Reducir suscripciones Realtime y throttlear `badge()`.
3. Reemplazar `.select('*')` por columnas explícitas.
4. Introducir minificación (Vite) si se acepta build step.
5. Rotar secretos expuestos.
