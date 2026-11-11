# Entendimiento profundo del proyecto — tienda-gregory

## 1. Negocio
Emprendimiento Gregory Izquierdo (J-50639379-4). Vende **pantallas (perfiles), cuentas completas y servicios digitales**. Precios en USD, conversión a Bs. por tasa BCV diaria. Sitio: www.gregoryizquierdo.xyz. App instalable (PWA/APK).

Stack: HTML/JS sin compilación + funciones serverless Vercel + Supabase (Postgres, Auth, Storage, Realtime) + GitHub. Multi-tenant SaaS "franquicia": subdominios con branding propio, canon mensual, kill-switch.

## 2. Roles
- **Cliente**: registro email/teléfono+password o Google. Ve pedidos, credenciales, facturas, Zeny, incidencias. RLS aislado.
- **Revendedor (VIP)**: cliente con `es_revendedor`; precio revendedor (o -15% auto). Gestiona clientes finales, perfiles asignados, créditos.
- **Admin (franquiciado/owner)**: solo `emprendimientogregoryizquierdo@gmail.com` con Google. Panel completo.
- **Franquicia**: tenant con subdominio, canon, autonomía comercial, infra central.
- **Central**: Gregory Izquierdo super-admin sobre todos los tenants.

## 3. Wallet Zeny
- 1 ZenyPoint = 1 USD. Ledger `zeny_ledger` (recarga/compra/ajuste/reembolso), estados pendiente/aprobado/rechazado.
- Pago total/parcial con Zeny permitido, pero los puntos se **retienen** (hold) hasta conciliación.
- Admin aprueba recargas → trigger acredita `zeny_balance`.
- Al entregar: Zeny retenido pasa a aprobado; si falta balance, bloquea entrega.
- Devolución a Zeny: crédito en ledger → balance sube.
- Reservas vencidas: rechaza holds.

## 4. Inventario
- `mother_accounts`: plataforma, correo, clave cifrada (pgcrypto AES), proveedor, costo_usd (auto-inserta `purchases`), vence, max_perfiles.
- `profiles_inventory`: perfil bajo cuenta madre, product_id, nombre_perfil, PIN cifrado, estado (disponible/reservado/vendido/suspendido), inicia/vence.
- `generate_profiles`: crea N disponibles (respeta max_perfiles).
- Claves/PINs cifrados en reposo; solo admin revela (`reveal_secret`); cliente ve los suyos tras entrega (`my_credentials`).
- Servicios (no perfiles) no consumen inventario.

## 5. Flujo de pedido
1. Cliente crea pedido (`create_order`): libera reservas vencidas, reserva perfil disponible (FOR UPDATE SKIP LOCKED), inserta order estado pendiente + Zeny retenido + hold ledger.
2. **Nada se entrega sin revisión manual** del admin (incluso con Zeny).
3. Admin `deliver_order` (conciliar): valida Zeny, asigna perfil, marca vendido con vencimiento, aprueba Zeny retenido, set entregado+pagado_at, conciliado_por/at, inserta factura.
4. `reject_order` / `cancel_my_order`: cierra → rechazado/cancelado, libera perfil, rechaza holds.
5. `release_expired`: pedidos pendientes > minutos configurables (default 60) → vencido, rechaza holds, libera perfil.
6. `stock()`: disponibles por producto.
7. Índice único evita que un perfil esté en dos pedidos activos.

## 6. Devoluciones / Traslados
- `refund_order(order, monto, destino, motivo, liberar)`: admin. Total → reembolsado, factura anulada, perfil liberado (disponible) o suspendido; Zeny refund si destino=zeny. Parcial → solo registra.
- `transfer_order(order, new_profile, motivo, liberar_anterior)`: admin. Solo entregados. Misma plataforma. Conserva días (inicia/vence). Perfil anterior liberado/suspendido. Log en `transfers`.

## 7. Contabilidad
- `finanzas(meses)`: serie mensual. Ganancia = Ventas − Devoluciones − Gastos − Compras (USD). Ventas = sum orders total_usd donde pagado_at not null (al conciliar). Devoluciones = refunds. Gastos = expenses. Compras = purchases (cuentas madre auto-registradas al insertar).

## 8. Notificaciones
- `notify_admin(kind, msg)` vía pg_net POST a `/api/notify` con secret; nunca bloquea.
- Triggers: nuevo pedido (order), recarga Zeny pendiente (recarga), nueva incidencia (incidencia).
- Cron vencimientos diario 12:00 UTC (8am Vzla) vía `/api/vencimientos`.
- Canales: sonido in-app, push (web push), Telegram. Settings key `notificaciones` (telegram_chat_id). Admin puede enviar test. Vencimientos del día para clientes y cuentas madre.

## 9. Integraciones
- Google: Calendar (vencimientos, elimina reembolsados), Sheets, Drive (backups), People/Contacts, Gemini (AI con contexto de tienda).
- Telegram bot: comandos editables en `bot_commands` (trigger/response, variables {tasa},{telefono},{correo}); default `*`; token cifrado server-side.
- BCV daily rate cron `/api/tasa-bcv` a las 11:00 UTC.
- Push (VAPID) en `push_subscriptions`.
- Storage: privado `capturas` (carpeta por cliente), público `catalogo`.
- Realtime: publicación incluye settings, exchange_rates, customers, products, banners, orders, zeny_ledger, faqs, incidents, payment_methods, login_log, profiles_inventory, mother_accounts, bot_commands, refunds, expenses, purchases, transfers.

## 10. Bots Telegram
- **Milos** (`@agentemilos_bot`): Orquestador Inteligente. Bot interactivo con comandos editables. Envía recordatorios de vencimiento a clientes con telegram_chat_id. Bot por defecto para notificaciones.
- **Esteban** (`@agenteesteban_bot`): Reporte Matutino 8:00 AM (vencimientos, nuevos registros, solicitudes, recargas).
- **Ramses** (`@agenteramses_bot`): Reporte Cierre (balance financiero).
- **Sahara** (`@agentesahara_bot`): Finanzas & Despachos Zeny (recargas).

## 11. Frontend (index.html)
- SPA monolítica. Vistas: home, portal, admin, checkout, dialogs.
- Estado global `S`. Helpers `$`, `esc`, `money`, `toast`.
- Auth: Supabase persisted session + auto-refresh; OAuth hash sanitization; login email/teléfono+password (teléfono → email sintético); Google OAuth.
- `loadPublic`: detección de franquicia, kill-switch, branding, carga catálogo (cache sessionStorage 3 min + revalidación).
- `home`: hero, rate, banners, tabs, grid, carousel, popups, flyer, demo admin.
- `portal`: pedidos, credenciales, facturas, Zeny, incidencias, Mesa de Cambio, installments/crédito, Telegram.
- `checkout`: 2 pasos (método → detalles), contado/cuotas, Zeny aplicado, pago mixto, BDV/BNC auto-verify.
- Realtime: `_pubCh` (productos/rate/banners), `_liveCh` (alertas + refresh).
- Service Worker: network-first, cache shell.

## 12. Panel Admin (admin-extra.js)
19 módulos EXTRA: notificaciones, orders, vencimientos, finanzas, google, telegram, cuotas, bnpl_ops, franquicias, tarjetas, mesa_cambio, liquidaciones, gemini, importar, plantillas, niveles, transfers, resellers, dev_studio.
TABLES (CRUD genérico): orders, installments, zeny_ledger, products, banners, categories, payment_methods, mother_accounts, profiles_inventory, customers, incidents, login_log, exchange_rates, expenses, purchases, refunds, transfers, settings, google_integrations.
PK mapping: settings→key, google_integrations→service, exchange_rates→fecha, resto→id.

## 13. API Serverless
- `_lib.js`: sbRest, getSecret, setSecret, requireAdmin, formatearFecha.
- `telegram.js`: bot interactivo (webhook), comandos editables.
- `telegram-link.js`: vinculación de Telegram al cliente.
- `notify.js`, `notify-event.js`, `_notify.js`, `notify-setup.js`: push + Telegram.
- `ejecutar-reportes-diarios.js`: cron unificado (tasa BCV, cuotas vencidas, Esteban matutino, Ramses cierre).
- `gemini.js`: asistente IA con contexto de tienda.
- `solicitud-franquicia.js`: solicitudes de franquicia.
- `conciliar-bdv.js`: verificación automática BDV/BNC.
- `push-key.js`: VAPID public key.

## 14. Limitaciones conocidas
- Monolito HTML (685 KB) + admin-extra (635 KB), sin build/minificación.
- Realtime suscrito a ~34 tablas (consolidado a 2 canales).
- 36 `.select('*')` (parcialmente optimizado).
- Imágenes logo 300 KB (optimizadas a WebP).
- Vercel Hobby: 12 funciones, 10 s timeout.
- Node 26.x requerido por Vercel (experimental).
- RLS con (select auth.uid()) aplicado en migración 06.
- Secretos: CRON_SECRET no configurado en Vercel (endpoint desprotegido), GEMINI_API_KEY expuesto en .env local.

## 20 sugerencias

1. **Configurar CRON_SECRET en Vercel** para proteger `/api/ejecutar-reportes-diarios` (actualmente desprotegido).
2. **Rotar GEMINI_API_KEY y CRON_SECRET** (expuestos en .env local).
3. **Aplicar migración 65** (índices) en Supabase para mejorar consultas.
4. **Reemplazar `.select('*')` restantes** por columnas explícitas (33 pendientes) para reducir payload y exposición de datos sensibles.
5. **Throttlear `badge()` a 30s** (ya aplicado) y desuscribir canales al cerrar sesión (revertido por bug de re-login; implementar recreación lazy).
6. **Optimizar imágenes restantes** (banners de productos, capturas KYC) con WebP/avif y redimensionado.
7. **Externalizar CSS** a archivo cacheable (79 KB inline) para mejorar FCP.
8. **Introducir build step (Vite)** para minificar y tree-shake (decisión de proyecto: hoy "sin compilación").
9. **Lazy-load canvas-confetti** solo al confirmar pedido.
10. **Reducir publicación Realtime** a tablas críticas (orders, profiles_inventory, zeny_ledger) y usar polling para el resto.
11. **Agregar paginación/infinite scroll** en listados grandes (orders, customers, profiles) en vez de limit 60 + load more manual.
12. **Cachear admins en memoria** en `requireAdmin` (evitar 2 fetch por request serverless).
13. **Validar duración del cron** en logs (Google Calendar/Sheets pueden superar 10s Hobby).
14. **Implementar offline real** en Service Worker (cache de catálogo) o al menos fallback offline.
15. **Agregar tests automatizados** (al menos smoke tests de carga y de funciones críticas).
16. **Separar `admin-extra.js`** en módulos por feature para carga bajo demanda granular (hoy se descarga completo).
17. **Auditar RLS** para columnas sensibles (clave, pin) — asegurar que clientes nunca las reciben.
18. **Implementar rate limiting** en endpoints públicos (notify, telegram, gemini) contra abuso.
19. **Monitoreo de errores** (Sentry o similar) para capturar fallos en producción.
20. **Documentar variables de entorno** y migraciones pendientes en un checklist de deploy.
EOF
echo done