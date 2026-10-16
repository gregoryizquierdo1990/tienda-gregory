# Guía paso a paso — de cero a tienda en producción
Emprendimiento Gregory Izquierdo · Tiempo estimado: 1 a 2 horas. Sigue el orden. No saltes pasos.

**Cuentas que necesitas (todas tienen plan gratis para empezar):** GitHub, Supabase, Vercel, Google (la del correo oficial), tu proveedor de dominio y Telegram.
**Nota honesta:** yo no puedo crear tu repositorio de GitHub ni subir el código por ti (no tengo acceso a tus cuentas). El paso 2 lo hace en 5 minutos con los comandos listos.

> **ESTADO REAL (revisado el 15-oct-2026)** — Tienda Oficial: **https://www.gregoryizquierdo.xyz/** y **https://gregoryizquierdo.xyz/**.
> - **Supabase** `tienda-gregory`: esquema + permisos + rendimiento aplicados, sin datos de prueba, Auth con Email y Google activos. Ya hecho: no repitas el paso 3.2.
> - **Vercel** proyecto `tienda-gregory2026`, conectado a GitHub `gregoryizquierdo1990/tienda-gregory`, con las variables SUPABASE_URL, SUPABASE_SERVICE_KEY y CRON_SECRET. **Settings → General → Root Directory debe ser `tienda`.** Todo lo que se publica vive dentro de la carpeta `tienda/` (sitio, `api/`, `vercel.json`, `package.json`); `supabase/` y los documentos quedan fuera y no se publican.
> - **Pendiente tuyo:** poner en Supabase → Authentication → URL Configuration: Site URL y Redirect URL con `https://www.gregoryizquierdo.xyz` y `https://gregoryizquierdo.xyz`, entrar con Google, y activar notificaciones/Telegram.

---
## 1. Prepara los archivos
1. Descomprime `tienda-gregory.zip`. Verás la carpeta `tienda-gregory` con `index.html`, `api/`, `supabase/`, etc.
2. No subas a ningún sitio tu hoja de Excel de cuentas: contiene datos de clientes. Se importa solo desde el panel (paso 11).

## 2. GitHub (control de versiones)
1. En https://github.com/new crea un repositorio **privado** llamado `tienda-gregory` (sin README, sin .gitignore).
2. Instala Git (https://git-scm.com) y, desde una terminal **dentro de la carpeta `tienda-gregory`**, ejecuta (cambia `TU-USUARIO`):
```
git init -b main
git add .
git commit -m "Tienda Gregory Izquierdo - versión inicial"
git remote add origin https://github.com/TU-USUARIO/tienda-gregory.git   # tu usuario en Vercel/GitHub parece ser gregoryizquierdo1990
git push -u origin main
```
GitHub te pedirá iniciar sesión (usa un *Personal Access Token* como contraseña si te lo pide, o instala GitHub Desktop y arrastra la carpeta).
3. Verifica en GitHub que aparecen las carpetas `api`, `supabase` y `.well-known`. No arrastres archivos por el navegador: suele omitir carpetas ocultas como `.well-known`.
4. Cada cambio futuro: `git add . && git commit -m "descripción" && git push`. Vercel desplegará solo.

## 3. Supabase (base de datos y autenticación)
1. https://supabase.com → *New project*. Contraseña de base de datos larga (guárdala en un gestor de claves). Región cercana.
2. **SQL Editor → New query** → pega TODO el contenido de `supabase/schema.sql` → **Run**. Ejecútalo **una sola vez** en un proyecto nuevo. (Si ya habías corrido una versión anterior, ejecuta solo las migraciones `02`, `03` y `04` de la carpeta `supabase`, en ese orden.)
3. **Authentication → Providers:** activa *Email* (deja **Confirm email** encendido), *Phone* (requiere un proveedor SMS como Twilio; sin él no llegan códigos) y *Google* (se completa en el paso 4).
4. **Authentication → URL Configuration:** Site URL = `https://www.gregoryizquierdo.xyz`; en *Redirect URLs* agrega `https://www.gregoryizquierdo.xyz/**`, `https://www.gregoryizquierdo.xyz`, `https://gregoryizquierdo.xyz/**`, y `https://gregoryizquierdo.xyz`.
5. **Authentication → Attack Protection:** activa CAPTCHA (hCaptcha o Turnstile).
6. **Project Settings → API:** copia el *Project URL*, la clave *anon public* y la clave *service_role* (secreta, solo va en Vercel).

## 4. Google Cloud (acceso del administrador y servicios)
1. https://console.cloud.google.com → proyecto nuevo → **APIs y servicios → Biblioteca:** habilita Google Calendar API, Google Sheets API, Google Drive API y People API.
2. **Pantalla de consentimiento OAuth:** tipo *Externo*, modo *Testing*; agrega `emprendimientogregoryizquierdo@gmail.com` como usuario de prueba y los permisos de Calendar, Sheets, Drive (`drive.file`) y Contactos.
3. **Credenciales → ID de cliente OAuth → Aplicación web.** En *URI de redireccionamiento autorizado* pega la que te muestra Supabase en Authentication → Providers → Google (`https://TU-PROYECTO.supabase.co/auth/v1/callback`).
4. Copia *Client ID* y *Client Secret* a Supabase (Providers → Google).
5. Gemini: crea una clave en https://aistudio.google.com/apikey (va en Vercel como `GEMINI_API_KEY`).

## 5. Configura la conexión
Edita `tienda/config.js` y pon tu `SUPABASE_URL` y tu `SUPABASE_ANON`. Es lo único que se toca del código. Haz commit y push (paso 2.4). Nunca pongas aquí la clave `service_role`.

## 6. Vercel (publicación)
1. https://vercel.com → *Add New → Project* → importa el repositorio `tienda-gregory` (Framework: *Other*, sin comando de build, **Root Directory: `tienda`**).
2. **Settings → Environment Variables:** `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` (la service_role), `CRON_SECRET` (cualquier texto largo aleatorio) y `GEMINI_API_KEY`. Luego **Redeploy**.
3. **Settings → Domains:** agrega `www.gregoryizquierdo.xyz` y `gregoryizquierdo.xyz`. En Cloudflare crea los registros indicados por Vercel (`CNAME` para `www` hacia `cname.vercel-dns.com` y registro `A` para `@` hacia `76.76.21.21`). Configura la redirección automática según tu preferencia (ej. de raíz a www). La tienda queda en `https://www.gregoryizquierdo.xyz/` y `https://gregoryizquierdo.xyz/`.
4. Carga la primera tasa BCV: Vercel → **Settings → Cron Jobs → Run** en `/api/tasa-bcv`. Luego se actualiza sola cada día (11:00 UTC). `/api/vencimientos` corre a las 12:00 UTC (8:00 a. m. Venezuela).

## 7. Primer ingreso como administrador
1. Abre tu sitio → **Ingresar → Continuar con Google** con `emprendimientogregoryizquierdo@gmail.com`. Aparece el botón **Admin**.
2. Solo ese correo, y solo entrando con Google, es administrador: la base de datos rechaza a cualquier otra cuenta, aunque use ese mismo correo con contraseña.
3. Activa la verificación en dos pasos en esa cuenta de Google.

## 8. Configura tu negocio (todo desde Admin)
1. **settings:** datos del negocio (editable). Clave `reserva` → `{"minutos":60}`: tiempo que se reserva un perfil mientras revisas el pago (súbelo si tardas más).
2. **payment_methods:** tus métodos de pago; los datos van como JSON, ej. `{"banco":"…","telefono":"…"}`.
3. **categories** y **products:** tipo `pantalla`, `cuenta_completa` o `servicio`, precio en USD, duración, imagen. Los `servicio` no consumen perfiles.
4. **banners** (título, imagen, enlace, fechas), **faqs** y **bot_commands**: todo editable.
5. **Cuentas y perfiles:** ver paso 11 y la sección "Compras de cuentas, perfiles y traslados".

## 9. Bot de Telegram
1. En Telegram habla con **@BotFather** → `/newbot` → copia el token.
2. Admin → **telegram** → pega el token → *Conectar bot*. El token se guarda cifrado en el servidor y nunca vuelve al navegador.
3. Abre tu bot en Telegram y escríbele **/start** (necesario para que pueda enviarte avisos).
4. Edita sus respuestas en Admin → **bot_commands**. Variables: `{tasa}`, `{telefono}`, `{correo}`. El comando `*` es la respuesta por defecto. El bot solo responde textos que tú escribes; no expone datos de clientes.

## 10. Notificaciones: sonido, push y Telegram
Avisan de: **pedido nuevo**, **recarga Zeny**, **incidencia** y **vencimientos del día** (clientes y cuentas madre).
1. Admin → **notificaciones** → comprueba tu ID de Telegram (viene cargado: `7154250409`) → **1. Activar / guardar**. Esto genera las llaves y deja la base de datos lista para avisar.
2. **2. Activar push en este dispositivo:** acepta el permiso. Repite en cada dispositivo (teléfono, computador). En **iPhone** primero instala la app en la pantalla de inicio (iOS 16.4 o superior).
3. **Enviar prueba:** debe llegarte un mensaje a Telegram y una notificación push.
4. Los avisos llegan **aunque la app esté cerrada** (Telegram y push). Además, con la app abierta suena un tono distinto por tipo de evento (botón **🔔 Sonido**; el navegador exige un toque en pantalla para permitir audio).
5. Limitaciones: el sonido de una notificación push lo decide el sistema del teléfono (no se puede personalizar); en iPhone y con ahorro de batería agresivo pueden retrasarse. Telegram es el canal más fiable: mantenlo activo.

## 11. Cuentas, perfiles e importación de tu hoja
- **Importar tu hoja de control:** Admin → **importar** → sube `CONTROL_CUENTAS_2026_CORREGIDO.xlsx` (se lee en tu navegador, no se sube a ningún servidor) → asigna cada hoja a su producto → *Importar*. Claves y PIN se guardan cifrados. Hazlo **una sola vez**: repetirlo duplica los perfiles.
- **Cuenta comprada para vender por perfiles:** Admin → **mother_accounts** → *+ Agregar* (plataforma, correo, clave, proveedor, `costo_usd` [se anota solo como compra], vencimiento y `max_perfiles`) → botón **Generar perfiles** (producto, cantidad, nombre base) → en **profiles_inventory** agrega el PIN de cada uno.
- **Cuenta para vender completa:** igual, pero genera **1** perfil con un producto tipo `cuenta_completa`. Una cuenta se vende completa o por perfiles, no ambas.
- **Renovación mensual de una cuenta madre:** anótala en **purchases** y actualiza su vencimiento en mother_accounts.
- **Trasladar a un cliente a otro perfil:** Admin → **orders** → pedido *entregado* → **Trasladar**. Debe ser la misma plataforma; conserva los días contratados; el perfil anterior se libera o se suspende; queda registrado en **transfers**. Si lo liberas, el cliente aún conoce su PIN: cámbialo antes de revenderlo.

## 12. App instalable y APK
- La tienda es una **app instalable (PWA)**: es la misma tienda, siempre en tiempo real. No guarda credenciales ni datos de clientes en el teléfono.
- **Android (navegador):** botón **Instalar app**. **iPhone (Safari):** *Compartir → Añadir a pantalla de inicio*.
- **APK:** (no puedo compilarlo aquí; lo generas tú con tu llave de firma)
  1. https://www.pwabuilder.com → escribe `https://www.gregoryizquierdo.xyz/` → *Package for stores → Android*.
  2. Descarga el paquete: trae `.apk`, `.aab` (Google Play) y tu **llave de firma** (guárdala: sin ella no podrás actualizar la app).
  3. Pega el contenido de `assetlinks.json` que te da PWABuilder en `.well-known/assetlinks.json`, haz commit y push.
  4. Sube el `.apk` a una *Release* de GitHub o a un bucket público de Supabase, y pega su enlace en Admin → **settings** → clave `app` → `{"apk_url":"https://..."}`. Aparecerá *Descargar APK*.
- **iPhone:** Apple no permite APK. La vía gratuita es Safari; publicar en App Store requiere cuenta de desarrollador (99 USD al año).
- Las actualizaciones de la tienda llegan solas a la app instalada.

## 13. Operación diaria
**Venta (sin vender dos veces ni entregar sin revisión)**
- Cuando el cliente elige un servicio y envía su pedido, el sistema **reserva un perfil libre** al instante (la base de datos impide que dos clientes tomen el mismo). Si no hay, aparece "Agotado".
- **Nada se entrega automáticamente**, tampoco con ZenyPoints. El cliente puede pagar total o parcialmente con Zeny (el resto con otro método): esos puntos solo quedan **retenidos**.
- Tú recibes el aviso, verificas el pago y en Admin → **orders** pulsas **Conciliar y entregar**: se cobran los Zeny retenidos, se entrega el perfil, se fija el vencimiento, se factura y queda constancia de quién concilió. También puedes **Rechazar** (libera perfil y puntos). Si no concilias a tiempo, la reserva vence y todo se libera solo.
- **Recargas Zeny:** Admin → **zeny_ledger** → verifica y **Aprobar**.

**Devoluciones**
- Admin → orders → **Devolver** (pedido pagado o entregado): monto (vacío = total), destino (ZenyPoints o por fuera), motivo y qué hacer con el perfil. Devolución total: pedido *reembolsado*, factura *anulada*, perfil liberado (o **suspendido** si quieres cambiar el PIN antes de revenderlo) y el cliente pierde ese acceso. Parcial: solo se registra.

**Ganancias:** Admin → **finanzas**: Ganancia = Ventas − Devoluciones − Gastos − Compras, por mes, en USD. Ventas = al conciliar el pago; devoluciones = día de registro; gastos en **expenses**; compras en **purchases** (las cuentas madre con costo se anotan solas). Anota gastos y compras ya convertidos a USD.

**Respaldos y Google:** Admin → **google** → Sheets / Drive (respaldo), Calendar (vencimientos; borra los de pedidos reembolsados), Contactos.

## 14. Seguridad (qué quedó protegido)
- Contraseñas de clientes: las maneja Supabase Auth (hash); la tienda nunca las ve.
- Claves de cuentas y PIN: cifrados en la base de datos; solo el administrador los revela y cada cliente ve únicamente los suyos tras la entrega.
- Cada cliente solo accede a sus propios datos (RLS). Precio, estado y perfil de un pedido los fija el servidor. El saldo Zeny solo cambia con movimientos aprobados por ti.
- Tokens y llaves (Telegram, push, secretos): en el servidor, nunca en el navegador. Los webhooks validan un secreto.
- Capturas: almacenamiento privado por cliente. Cabeceras de seguridad (HSTS, CSP, anti-iframe) en `vercel.json`. La app no guarda datos sensibles en el teléfono.
- No hay datos de prueba: solo tu correo de administrador, datos del negocio, el destino de avisos y 4 respuestas básicas del bot.

## 15. Prueba antes de vender (y limpia después)
1. Crea un producto de prueba, un cliente de prueba (otro correo) y haz un pedido: verifica aviso, **Conciliar y entregar**, accesos en el portal, **Devolver** y traslado.
2. Al terminar, **borra** los registros de prueba (Admin → orders, invoices, customers, products de prueba; en Supabase → Authentication → Users borra el usuario de prueba) y deja los perfiles reales en *disponible*.
3. Cambia a un PIN nuevo cualquier perfil que hayas usado en la prueba.

## 16. Límites que debes conocer
- No hay validación automática de pagos: confirmas tú cada uno.
- No hay renovación automática: el cliente compra de nuevo y recibe un perfil nuevo.
- Los permisos de Google están en modo *Testing*: hay que pulsar "Conectar Google" al usar esos servicios; publicar la app exige verificación de Google.
- No pude ejecutar ni probar el SQL, el sitio ni las notificaciones en un entorno real: haz el paso 15 completo antes de vender, y avísame cualquier error para corregirlo.
- Rota las claves que hayas compartido en capturas o chats y no vuelvas a enviar capturas con saldos o datos bancarios.

## 17. Problemas frecuentes
- *"Acceso solo para el administrador"*: entraste sin Google o con otro correo; cierra sesión y entra con Google.
- *No llega Telegram*: ¿conectaste el bot y le escribiste /start? ¿ID correcto? Usa **Enviar prueba** y lee el mensaje de error.
- *No llega el push*: repite "Activar push en este dispositivo"; en iPhone la app debe estar instalada; revisa que el permiso no esté bloqueado.
- *Los avisos automáticos no salen (pedidos/recargas)*: ejecuta de nuevo "1. Activar / guardar" y comprueba que la extensión `pg_net` esté activa en Supabase (Database → Extensions).
- *Pantalla en blanco*: revisa `config.js` y que Vercel haya terminado el despliegue.

## 18. Archivos del proyecto
`tienda/` (tienda, portal, panel y app instalable: `index.html`, `admin-extra.js`, `config.js`, `sw.js`, `manifest.webmanifest`, iconos) · `.well-known/assetlinks.json` (en la raíz del dominio) · `api/` (tasa BCV, bot, Gemini, notificaciones, vencimientos) · `supabase/schema.sql` (todo en uno) y migraciones 02, 03 y 04 · `vercel.json`, `package.json`, `.env.example`, `.gitignore` · `PROYECTO.md` (resumen y decisiones).
