# Checklist de deploy — tienda-gregory

## Variables de entorno (Vercel → Settings → Environment Variables)
- [ ] `SUPABASE_URL` = https://tevjiqnnnjnakftrjgud.supabase.co
- [ ] `SUPABASE_SERVICE_KEY` = clave service_role de Supabase (NUNCA en el repo)
- [ ] `CRON_SECRET` = cadena larga aleatoria (protege /api/ejecutar-reportes-diarios y /api/tasa-bcv)
- [ ] `GEMINI_API_KEY` = clave de Google AI Studio
- [ ] `TELEGRAM_BOT_TOKEN` = token del bot oficial
- [ ] `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` = claves Web Push
- [ ] `VAPID_SUBJECT` = mailto:emprendimientogregoryizquierdo@gmail.com

## Configuración Vercel
- [ ] Root Directory = `tienda`
- [ ] Framework Preset = Other (static)
- [ ] Node.js Version = 26.x (engines.node en package.json)
- [ ] Rama conectada = `main` (auto-deploy on push)

## Migraciones Supabase (ejecutar en SQL Editor, en orden)
- [ ] `supabase/schema.sql` (proyecto nuevo) o migraciones incrementales
- [ ] `migracion_06_rendimiento.sql` (índices + RLS)
- [ ] `migracion_08_cuotas_bnpl.sql` (installments)
- [ ] `migracion_11_tdc_zeny.sql` (zeny_cards)
- [ ] `migracion_42_revendedores_vencimientos_y_no_renovacion.sql`
- [ ] `migracion_44_linea_credito_revendedores.sql`
- [ ] `migracion_47_consolidado_finanzas_cuotas_y_deudas_revendedores.sql`
- [ ] `migracion_48_renovaciones_credito_y_compras.sql`
- [ ] `migracion_65_indices_rendimiento.sql` (índices adicionales)
- [ ] Verificar tablas: orders, profiles_inventory, mother_accounts, installments, zeny_cards, zeny_ledger, refunds, transfers, expenses, purchases, customers, products, settings, banners, payment_methods, incidents, faqs, bot_commands, google_integrations, push_subscriptions, admins

## Post-deploy
- [ ] Hard refresh (Ctrl+Shift+R) en navegador
- [ ] Verificar consola sin errores (F12)
- [ ] Probar login admin + carga de módulos (Vencimientos, Tarjetas, Cuotas, BNPL)
- [ ] Probar flujo de pedido end-to-end (crear → conciliar → entregar)
- [ ] Verificar cron: `curl -X POST .../api/ejecutar-reportes-diarios?tipo=matutino -H "Authorization: Bearer $CRON_SECRET"`
- [ ] Verificar tasa BCV actualizada en la tienda
- [ ] Revisar Telegram (Esteban/Ramses/Milos/Sahara) reciben mensajes
- [ ] Verificar push notifications (suscribir dispositivo)
- [ ] Rotar secretos si se expusieron (GEMINI_API_KEY, CRON_SECRET)

## Verificación de rendimiento
- [ ] Lighthouse: FCP < 2s, LCP < 2.5s
- [ ] Tamaño de index.html < 700 KB (objetivo: reducir con build step)
- [ ] Imágenes en WebP con fallback
- [ ] Cache headers aplicados (vercel.json)
- [ ] Service Worker actualizado (gi-vXX)
EOF
echo done