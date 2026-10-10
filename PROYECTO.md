# Resumen del proyecto
**Negocio:** Emprendimiento Gregory Izquierdo (J-50639379-4). Tel. oficial +584241983648 · correo oficial emprendimientogregoryizquierdo@gmail.com · sitio en tienda.gregoryizquierdo.xyz (subdominio); www.gregoryizquierdo.xyz es otro proyecto.
**Venta:** pantallas (perfiles), cuentas completas y otros servicios digitales. Precios en USD con conversión a Bs. por la tasa oficial BCV diaria.

## Decisiones y reglas
- Stack: HTML/JS sin compilación + funciones serverless en Vercel + Supabase (Postgres, Auth, Storage, Realtime) + GitHub. Diseño moderno, responsive, azul-verde y negro. App instalable (PWA) y vía APK con PWABuilder.
- Acceso: clientes con correo/teléfono + contraseña o Google. Administrador: solo `emprendimientogregoryizquierdo@gmail.com` con Google.
- Wallet **Zeny** (ZenyPoints, 1 ZenyPoint = 1 USD). Pago total o parcial con Zeny permitido, pero los puntos solo se **retienen** hasta la conciliación.
- **Nada se entrega sin revisión y conciliación manual** del administrador (también con Zeny).
- Reserva automática de perfil al enviar el pedido (60 min, configurable), sin vender dos veces el mismo perfil ni sin stock.
- Devoluciones: libera o suspende el perfil, anula factura, devuelve a Zeny o por fuera. Traslados entre perfiles de la misma plataforma.
- Contabilidad mensual: Ganancia = Ventas − Devoluciones − Gastos − Compras (USD).
- Inventario: cuentas madre y perfiles (basado en la hoja CONTROL_CUENTAS_2026), clave y PIN cifrados.
- Notificaciones al administrador: sonido en la app, push y Telegram (pedidos, recargas, incidencias, vencimientos del día).
- Bot de Telegram editable desde el panel; banners, FAQ, métodos de pago, productos y ajustes editables.
- Integraciones Google en el panel: Calendar, Sheets, Drive, Contactos y Gemini.
- Sincronización en tiempo real (Supabase Realtime) entre tienda, portal, app y panel.

## Tablas principales
settings, exchange_rates, customers, categories, products, banners, mother_accounts, profiles_inventory, payment_methods, orders, invoices, zeny_ledger, refunds, transfers, expenses, purchases, faqs, login_log, incidents, google_integrations, bot_commands, push_subscriptions, admins, secrets (solo servidor).

## Funciones de base de datos
is_admin, create_order, deliver_order (conciliar), reject_order, cancel_my_order, refund_order, transfer_order, generate_profiles, my_credentials, stock, finanzas, reveal_secret, release_expired y los avisos (notify_admin).
