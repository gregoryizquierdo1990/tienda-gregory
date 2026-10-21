-- ==============================================================================
-- 05_DATOS_SEMILLA_INICIALES.SQL
-- Emprendimiento Gregory Izquierdo - Suite de Instalación PostgreSQL Independiente
-- Catálogo de Categorías, Productos Oficiales, Configuración, Métodos de Pago y Admin
-- ==============================================================================

-- 1. Categorías Oficiales
INSERT INTO public.categories (id, nombre, orden)
VALUES ('e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Perfiles & Pantallas', 1)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, orden = EXCLUDED.orden;
INSERT INTO public.categories (id, nombre, orden)
VALUES ('e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'Cuentas Completas', 2)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, orden = EXCLUDED.orden;
INSERT INTO public.categories (id, nombre, orden)
VALUES ('e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'Combos Especiales', 3)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, orden = EXCLUDED.orden;
INSERT INTO public.categories (id, nombre, orden)
VALUES ('e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'Música & Productividad', 4)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, orden = EXCLUDED.orden;

-- 2. Métodos de Pago Oficiales
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('69e2be6c-0b95-4cb7-9e03-8f45c85b6e69', 'Pago Móvil (BNC)', 'pago_movil', '{"Banco":"BNC (Banco Nacional de Crédito)","Código":"0191","Documento":"V 18931731","Teléfono":"04242809333"}'::jsonb, 1, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('e2762451-fc48-4457-9318-42389791b4ae', 'Binance (USDT)', 'binance', '{"Correo":"gregoryrodriguez2021@gmail.com","ID Binance":"393089335"}'::jsonb, 2, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('e1919cec-6687-4e04-a719-b8f3a4666db4', 'Transferencia Internacional (Ecuador)', 'transferencia_internacional', '{"Banco":"Guayaquil","Email":"evertizquierdo91@gmail.com","Titular":"Evert Izquierdo","Documento":"2451655498","N° Cuenta":"0042286503","Tipo de Cuenta":"Ahorros"}'::jsonb, 3, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('445586ab-1bec-4692-9e8b-3f7f2106303f', 'ApoloPay', 'apolopay', '{"Correo":"gregoryrodriguez2021@gmail.com","ID Usuario":"7604"}'::jsonb, 4, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('bb6d9100-a066-4528-88d7-f0f5e3149515', 'Zinli', 'zinli', '{"Correo":"gregoryrodriguez2021@gmail.com","Teléfono":"04242809333"}'::jsonb, 5, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('2bc8ae59-e88f-4be0-b73d-8211ebc97ebf', 'Wally', 'wally', '{"Correo":"gregoryrodriguez2021@gmail.com","Teléfono":"04242809333"}'::jsonb, 6, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('1fde2ff7-8e4e-405d-b86d-e0e8de019288', 'Uglycash', 'uglycash', '{"Usuario":"gair1990"}'::jsonb, 7, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('69409bfc-511d-441e-8012-d30753a255eb', 'Transferencia EEUU (Lead Bank)', 'transferencia_eeuu', '{"Banco":"Lead Bank","Routing":"101019644","Titular":"Gregori Antonio Izquierdo Rodriguez","N° Cuenta":"210345561126","Tipo de Cuenta":"Corriente","Dirección Banco":"1801 Main St., Kansas City. MO 64108"}'::jsonb, 8, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;
INSERT INTO public.payment_methods (id, nombre, tipo, datos, orden, activo)
VALUES ('c6517bb7-8aa7-4c04-a156-4c6c8ee32c9d', 'Pago Móvil Jurídico', 'pago_movil_juridico', '{"Banco":"Venezolano de Crédito","Código":"0104","Documento":"J 506393794","Teléfono":"04242809333"}'::jsonb, 9, true)
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, datos = EXCLUDED.datos, activo = EXCLUDED.activo;

-- 3. Parámetros de Configuración del Sistema (settings)
INSERT INTO public.settings (key, value)
VALUES ('zeny', '{"moneda":"ZenyPoints","nombre":"Zeny","valor_usd":1}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('reserva', '{"minutos":60}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('bot', '{"username":"Diego1asistente_bot"}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('mesa_cambio_config', '{"banco":"BNC (0191)","activo":false,"titular":"Gregory Izquierdo","max_usdt":10,"min_usdt":2,"telefono":"04242809333","documento":"18931731","metodo_pago":"Pago Móvil (BNC)","tasa_usdt_bs":1050.52,"mensaje_aviso":"⚠️ IMPORTANTE: Por favor verifica cuidadosamente tu ID de Binance Pay o Correo electrónico antes de enviar la solicitud. No nos hacemos responsables ni realizaremos reembolsos por mala identificación de sus datos.","fondo_caja_usdt":3,"tasa_adquisicion_bs":1004.43}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('negocio', '{"rif":"J-50639379-4","correo":"emprendimientogregoryizquierdo@gmail.com","nombre":"Emprendimiento Gregory Izquierdo","telefono":"+584241983648"}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('app', '{"apk_url":"https://github.com/gregoryizquierdo1990/tienda-gregory/releases/download/v1.0.0/Emprendimiento-Gregory-Izquierdo.apk"}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('notificaciones', '{"telegram_chat_id":"7154250409"}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO public.settings (key, value)
VALUES ('plantillas_mensajes', '{"abono_zeny":{"id":"abono_zeny","tags":["cliente","monto_usd","monto_bs","referencia","nuevo_balance","portal_url","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 💳✨\nTu abono de saldo Zeny ha sido verificado y acreditado exitosamente en tu cuenta de {negocio}.\n\n💵 Monto Acreditado: ${monto_usd} USD (Bs. {monto_bs})\n🔢 Referencia: {referencia}\n💰 Nuevo Balance Zeny: ${nuevo_balance} ZP\n\nTu saldo está disponible para compras y renovaciones instantáneas con 0 esperas bancarias en:\n🌐 {portal_url}\n\n¡Muchas gracias por recargar con nosotros! 🚀","titulo":"💳 Confirmación de Abono / Recarga Saldo Zeny","descripcion":"Notificación de saldo acreditado a la Tarjeta Digital Zeny o billetera del usuario."},"cobro_cuota":{"id":"cobro_cuota","tags":["cliente","negocio","producto","cuota","total_cuotas","monto_usd","monto_bs","tasa_bcv","fecha_vencimiento"],"canal":"whatsapp","cuerpo":"Hola {cliente}, \nun cordial saludo de\n {negocio} 👋\n\nTe recordamos que tienes una cuota pendiente de tu servicio financiado:\n\n📦 Servicio: {producto}\n💳 Cuota: #{cuota} de {total_cuotas}\n💵 Monto en USD: ${monto_usd} USD\n🇻🇪 Monto en Bs: Bs. {monto_bs} (Tasa BCV {tasa_bcv})\n📅 Fecha de vencimiento: {fecha_vencimiento}\n\nPor favor envíanos el comprobante una vez realizada la transferencia. ¡Muchas gracias por tu puntualidad!","titulo":"Cobro de Cuota Pendiente (BNPL)","descripcion":"Recordatorio enviado al cliente con los detalles de su cuota financiada por pagar."},"factura_lista":{"id":"factura_lista","tags":["cliente","numero_factura","fecha","total_usd","total_bs","tasa_bcv","portal_url","negocio","rif"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 📄 Tu factura digital en {negocio} ya está emitida y disponible.\n\n🧾 Documento: {numero_factura}\n📅 Fecha de Emisión: {fecha}\n💵 Total Facturado: ${total_usd} USD (Bs. {total_bs})\n🇻🇪 Tasa Oficial BCV: Bs. {tasa_bcv}\n🏢 RIF Emisor: {rif}\n\nPuedes consultar, descargar o imprimir tu factura oficial ingresando directamente a tu portal web:\n🌐 {portal_url}\n\n¡Gracias por tu pago puntual y por elegirnos! ⭐","titulo":"📄 Factura Digital Emitida y Lista","descripcion":"Aviso al cliente de que su factura oficial ya está generada y lista para descargar en el portal."},"recarga_gaming":{"id":"recarga_gaming","tags":["cliente","producto","player_id","nickname","monto_usd","codigo_id","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🎮✨\nTu recarga de {producto} ha sido PROCESADA CON ÉXITO.\n\n📌 Juego / Servicio: {producto}\n🆔 ID de Jugador: {player_id}\n👤 Nickname: {nickname}\n💵 Monto: ${monto_usd} USD\n🧾 Pedido ID: {codigo_id}\n\n⚠️ Por favor abre o reinicia el juego para verificar tus activos. ¡Gracias por confiar en {negocio}! 🔥","titulo":"Entrega de Recarga Gaming / Activos","descripcion":"Enviado al cliente cuando su recarga de juego (Free Fire, Roblox, etc.) ha sido procesada."},"recibo_factura":{"id":"recibo_factura","tags":["cliente","negocio","numero_factura","fecha","total_usd","total_bs","tasa_bcv"],"canal":"whatsapp","cuerpo":"Hola {cliente}! \nAdjuntamos tu comprobante digital de compra en {negocio} 📄:\n\n🧾 Documento: {numero_factura}\n📅 Fecha: {fecha}\n💵 Total: ${total_usd} USD (Bs. {total_bs})\nTasa: {tasa_bcv}\n\nPuedes descargar o imprimir tu factura oficial directamente desde tu portal. ¡Gracias por confiar en nosotros!","titulo":"Envío de Factura Digital / Recibo","descripcion":"Comprobante formal de pago con datos fiscales, tasa BCV y desglose de items."},"entrega_credito":{"id":"entrega_credito","tags":["cliente","negocio","producto","monto_usd","fecha_vence_credito","dias_credito"],"canal":"whatsapp","cuerpo":"Hola {cliente}! \nTe saludamos de {negocio} ✨\nTu servicio de {producto} ha sido activado/renovado a CRÉDITO por 30 días de disfrute.\n\n💵 Monto pendiente: ${monto_usd} USD\n📅 Fecha límite para el pago: {fecha_vence_credito} ({dias_credito} días)\n💳 Recuerda que puedes pagar con Pago Móvil o con tu Tarjeta Digital Zeny.\n\n¡Muchas gracias por tu preferencia y confianza continua! ⭐","titulo":"Activación de Servicio a Crédito","descripcion":"Notificación cuando se entrega o renueva un servicio a crédito con fecha límite de pago."},"entrega_servicio":{"id":"entrega_servicio","tags":["cliente","numero_factura","negocio","producto","correo","clave","perfil","pin","vence","garantia","codigo_id"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! \n🎉 Gracias por tu compra {numero_factura} en {negocio}.\nAquí tienes los datos de acceso para tu servicio:\n\n📌 Servicio: {producto}\n📧 Correo: {correo}\n🔑 Clave: {clave}\n👤 Perfil: {perfil}\n🔒 PIN: {pin}\n⏳ Vence el: {vence}\n🛡️ Garantía: {garantia} días\n\n⚠️ Instrucciones:\n• No modificar correo ni perfil asignado.\n• Ante dudas indícanos tu ID {codigo_id}.\n\n¡Que disfrutes tu servicio! ⭐","titulo":"Entrega de Credenciales del Pedido","descripcion":"Enviado al cliente cuando su pedido es conciliado y se entregan las credenciales de acceso."},"abono_recargas247":{"id":"abono_recargas247","tags":["titular","nombre_punto","usuario_247","monto_usd","monto_bs","referencia","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {titular}! ✅\nTu abono de saldo ha sido verificado y acreditado en tu usuario {usuario_247} de Recargas247.\n\n🏪 Punto de Venta: {nombre_punto}\n💵 Monto Acreditado: ${monto_usd} USD (Bs. {monto_bs})\n🔢 Referencia: {referencia}\n\nTu saldo ya se encuentra disponible para emitir recargas a tus clientes. ¡Éxito en las ventas de hoy! 🚀","titulo":"Confirmación de Abono Punto Recargas247","descripcion":"Enviado al revendedor cuando Gregory le concilia y acredita saldo en Recargas247."},"aviso_vencimiento":{"id":"aviso_vencimiento","tags":["cliente","producto","fecha_vence","monto_usd","portal_url"],"canal":"whatsapp","cuerpo":"Hola {cliente}! ⏰ \nTu servicio de {producto} está próximo a vencer el {fecha_vence}.\n\nPara mantener tu perfil activo y no perder tus pantallas guardadas, puedes renovar directamente desde tu portal con saldo Zeny o confirmarnos con tu pago a traves de la opcion en mi portal de tu usuario u por acá:\n💵 Monto de renovación: ${monto_usd} USD\n🌐 Tu Portal de Cliente: {portal_url}\n\n¿Deseas renovar para este próximo período? Quedamos a tu orden.","titulo":"Aviso Previo de Vencimiento de Suscripción","descripcion":"Mensaje preventivo antes del vencimiento para ofrecer la renovación inmediata."},"bienvenida_tarjeta":{"id":"bienvenida_tarjeta","tags":["cliente","codigo_id","numero_tarjeta","codigo_activacion","portal_url","negocio"],"canal":"whatsapp","cuerpo":"¡Bienvenido a {negocio}, {cliente}! 🌟\nTu cuenta ha sido creada exitosamente en nuestra plataforma.\n\n🆔 Tu Identificador oficial: {codigo_id}\n💳 Tarjeta Digital Zeny: {numero_tarjeta}\n🔐 Código de Activación: {codigo_activacion}\n🌐 Portal Web: {portal_url}\n\nTu Tarjeta Zeny te permite comprar al instante sin esperas bancarias. ¡Estamos listos para atenderte!","titulo":"Bienvenida y Tarjeta Zeny Emitida","descripcion":"Enviado tras el registro para entregar el ID único, tarjeta digital y código de activación."},"recarga_telefonica":{"id":"recarga_telefonica","tags":["cliente","producto","operadora","telefono_recarga","monto_usd","monto_bs","codigo_id","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 📱⚡\nTu recarga telefónica de {producto} ha sido ACREDITADA EXITOSAMENTE.\n\n📌 Operadora: {operadora}\n📞 Teléfono: {telefono_recarga}\n💵 Monto: ${monto_usd} USD (Bs. {monto_bs})\n🧾 Pedido ID: {codigo_id}\n\n¡Gracias por recargar con {negocio}! Quedamos a tu orden para tus próximas recargas. ✨","titulo":"Entrega de Recarga Telefónica","descripcion":"Enviado al cliente cuando su recarga de saldo móvil ha sido abonada."},"renovacion_exitosa":{"id":"renovacion_exitosa","tags":["cliente","producto","vence","monto_usd","monto_bs","tasa_bcv","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🔄✨\nTu renovación para {producto} ha sido PROCESADA CON ÉXITO en {negocio}.\n\n📌 Servicio: {producto}\n📅 Nuevo Vencimiento (+30 días): {vence}\n💵 Monto Pagado: ${monto_usd} USD (Bs. {monto_bs})\n🇻🇪 Tasa BCV: {tasa_bcv}\n\nTu perfil continúa activo sin interrupciones ni cambios de pantalla. ¡Muchas gracias por tu preferencia y confianza continua! ⭐🍿","titulo":"🔄 Renovación Exitosa de Suscripción (+30 días)","descripcion":"Confirmación enviada al cliente cuando renueva su servicio para el próximo período."},"activacion_servicio":{"id":"activacion_servicio","tags":["cliente","producto","correo","clave","perfil","pin","vence","garantia","codigo_id","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🎉 Tu servicio ha sido ACTIVADO EXITOSAMENTE en {negocio}.\nAquí tienes los datos de acceso para tu pantalla:\n\n📌 Servicio: {producto}\n📧 Correo: {correo}\n🔑 Clave: {clave}\n👤 Perfil Asignado: {perfil}\n🔒 PIN de Acceso: {pin}\n⏳ Vence el: {vence}\n🛡️ Garantía: {garantia} días continuos\n\n⚠️ Reglas de uso importantes:\n• Usar ÚNICAMENTE tu perfil asignado ({perfil}).\n• No modificar correo, clave ni los perfiles de otros usuarios.\n• Ante cualquier consulta, indícanos tu ID oficial {codigo_id}.\n\n¡Que disfrutes al máximo tu entretenimiento! ⭐🍿","titulo":"🚀 Activación y Entrega Oficial de Credenciales","descripcion":"Bienvenida al cliente con sus credenciales de acceso, perfil, PIN de 4 dígitos y normas de uso."},"devolucion_garantia":{"id":"devolucion_garantia","tags":["cliente","producto","monto_usd","motivo","destino","codigo_id","negocio"],"canal":"whatsapp","cuerpo":"Hola {cliente}, un cordial saludo de {negocio} 🛡️\nTe informamos que tu solicitud de garantía para el servicio de {producto} ha sido APROBADA y procesada con éxito.\n\n💵 Monto Reintegrado: ${monto_usd} USD\n💼 Destino del Reintegro: {destino}\n📝 Motivo / Detalle: {motivo}\n🧾 ID de Registro: {codigo_id}\n\nLamentamos cualquier inconveniente presentado con el proveedor. Nuestro compromiso es garantizar siempre tu inversión y satisfacción. Quedamos a tu total disposición. 🤝","titulo":"🛡️ Reembolso o Devolución por Garantía / Pantalla","descripcion":"Enviado al cliente cuando se procesa una devolución o reposición de saldo ante una incidencia."},"reposicion_pantalla":{"id":"reposicion_pantalla","tags":["cliente","producto","correo","clave","perfil","pin","vence","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🔀 Hemos activado tu REPOSICIÓN POR GARANTÍA para tu servicio de {producto}.\nAquí tienes tus nuevos datos de acceso funcionales:\n\n📌 Servicio: {producto}\n📧 Nuevo Correo: {correo}\n🔑 Nueva Clave: {clave}\n👤 Perfil: {perfil}\n🔒 PIN: {pin}\n⏳ Vigencia garantizada hasta: {vence}\n\nDisculpa la interrupción ocasionada por la plataforma original. Ya puedes disfrutar de tu servicio con total normalidad. ¡Cualquier duda estamos a la orden! 🍿","titulo":"🔀 Reposición Inmediata de Pantalla por Garantía","descripcion":"Entrega de nuevas credenciales de reemplazo por caída de cuenta o pantalla caída."},"aviso_vencimiento_hoy":{"id":"aviso_vencimiento_hoy","tags":["cliente","producto","vence","monto_usd","monto_bs","portal_url","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! ⏰ Te recordamos de {negocio} que tu servicio de {producto} tiene fecha de cobro y vencimiento el día de HOY ({vence}).\n\n💵 Monto de renovación: ${monto_usd} USD (Bs. {monto_bs})\n🌐 Tu Portal Web: {portal_url}\n\n¿Deseas renovar tu pantalla para mantenerla activa este próximo mes? Por favor confírmanos por esta vía para asegurar tu cupo sin interrupciones. ¡Quedamos atentos a tu respuesta! 👋","titulo":"⏰ Cobro y Vencimiento del Día (Hoy)","descripcion":"Recordatorio urgente enviado el día exacto de vencimiento para gestionar la renovación o liberación."},"abono_usdt_mesa_cambio":{"id":"abono_usdt_mesa_cambio","tags":["cliente","tipo_operacion","monto_usdt","tasa_cambio","monto_bs","referencia","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 💱⚡\nTu operación en la Mesa de Cambio USDT de {negocio} ha sido PROCESADA Y LIQUIDADA CON ÉXITO.\n\n📊 Operación: {tipo_operacion}\n🪙 Monto USDT: {monto_usdt} USDT\n📈 Tasa de Cambio: Bs. {tasa_cambio} por USDT\n🇻🇪 Total en Bolívares: Bs. {monto_bs}\n🔢 Referencia Bancaria / Binance: {referencia}\n\nFondos entregados y verificados. ¡Gracias por confiar en nuestra mesa de cambio segura y rápida! 🤝💎","titulo":"💱 Confirmación de Operación Mesa de Cambio USDT","descripcion":"Enviado al cliente cuando su operación de USDT (Binance Pay / TRC20 / BEP20) ha sido liquidada."},"datos_limpios_revendedor":{"id":"datos_limpios_revendedor","tags":["servicio","correo","clave","perfil","pin","vence","vendedor"],"canal":"whatsapp","cuerpo":"*{servicio}*\nCorreo: {correo}\nClave: {clave}\nPerfil: {perfil}\nPIN: {pin}\nVence: {vence}\nVendedor: {vendedor}\n\n⚠️ Cuida tus accesos y disfruta tu servicio. Garantía activa durante todo el período.","titulo":"Formato Reenvío de Revendedor a Cliente Final","descripcion":"Estructura limpia sin marcas que el revendedor copia para entregar a sus propios clientes."},"notificacion_telegram_bot":{"id":"notificacion_telegram_bot","tags":["cliente","servicio","monto_usd","estado","negocio"],"canal":"telegram","cuerpo":"🤖 *Notificación de {negocio}*\n\nHola {cliente}, tu solicitud para *{servicio}* se encuentra en estado: *{estado}*.\nMonto: ${monto_usd} USD.\n\nAccede a tu portal para ver tus accesos actualizados.","titulo":"Aviso del Bot de Telegram al Cliente","descripcion":"Mensaje formateado enviado por el bot de Telegram ante pedidos o recargas."},"invitacion_registro_portal":{"id":"invitacion_registro_portal","tags":["cliente","portal_url","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 👋 Como cliente de {negocio}, tienes a tu disposición nuestro portal web exclusivo:\n🌐 {portal_url}\n\nEn tu portal podrás:\n✅ Ver tus pantallas activas, PIN y fechas de vencimiento 24/7.\n✅ Descargar tus facturas digitales y comprobantes de compra.\n✅ Usar tu Tarjeta Digital Zeny para renovar en 1 clic.\n\nTu usuario es este mismo número de WhatsApp o tu correo. ¡Cualquier duda estamos a tu disposición! 🤝✨","titulo":"🌐 Invitación y Acceso al Portal de Clientes","descripcion":"Invita a un cliente que compró por WhatsApp a registrarse o entrar a su portal para ver sus servicios y tarjeta."},"entrega_directa_credenciales":{"id":"entrega_directa_credenciales","tags":["cliente","producto","correo","clave","perfil","pin","vence","garantia","portal_url","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🎉 Aquí tienes tus accesos oficiales para disfrutar de {producto} activados por {negocio}:\n\n📺 *Servicio:* {producto}\n✉️ *Correo:* {correo}\n🔑 *Clave:* {clave}\n👤 *Perfil:* {perfil}\n🔒 *PIN:* {pin}\n📅 *Vencimiento:* {vence} (+30 días)\n🛡️ *Garantía:* {garantia} días continuos\n\n⚠️ *Recomendaciones importantes:*\n• Ingresa únicamente a tu perfil asignado ({perfil}).\n• No modificar correo, clave ni otros perfiles.\n• Puedes consultar tu historial y facturas en tu portal: {portal_url}\n\n¡Que disfrutes tu programación favorita! Si tienes alguna duda, estamos a la orden por aquí. ⭐🎬","titulo":"🔑 Entrega de Accesos por Pago Directo","descripcion":"Entrega limpia de usuario, clave, perfil y PIN cuando un cliente paga fuera de la plataforma."},"datos_de_pago_cliente_directo":{"id":"datos_de_pago_cliente_directo","tags":["cliente","producto","monto_usd","monto_bs","tasa_bcv","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 👋 Con gusto te facilitamos los datos oficiales de pago para tu servicio {producto} en {negocio}:\n\n💵 *Total a transferir:* ${monto_usd} USD\n🇻🇪 *En Bolívares:* Bs. {monto_bs} (Tasa oficial BCV: {tasa_bcv})\n\n📌 *Opción 1: Pago Móvil (BNC)*\n• Banco: BNC (0191)\n• Teléfono: 04242809333\n• Cédula: V-18931731\n\n📌 *Opción 2: Binance Pay (USDT)*\n• Pay ID: 393089335\n• Correo: gregoryrodriguez2021@gmail.com\n\nAl realizar el pago, envíanos por favor la captura o el número de referencia para activar tu servicio al instante. ¡Muchas gracias! ✨","titulo":"💳 Envío de Cuentas de Pago a Cliente Directo","descripcion":"Plantilla rápida con todos los métodos de pago (Pago Móvil, Binance, etc.) para pasarle a un cliente por WhatsApp."},"pago_recibido_fuera_plataforma":{"id":"pago_recibido_fuera_plataforma","tags":["cliente","negocio","producto","monto_usd","monto_bs","tasa_bcv","referencia"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 👋\nConfirmamos la recepción de tu pago con total éxito en {negocio} ✅\n\n📌 Concepto / Servicio: {producto}\n💵 Monto: ${monto_usd} USD (Bs. {monto_bs})\n🇻🇪 Tasa BCV: Bs. {tasa_bcv}\n🔢 Referencia: {referencia}\n\nEstamos procesando tu solicitud de inmediato. En breves minutos te enviaremos tus datos de acceso oficiales. ¡Muchas gracias por tu compra y confianza! ⭐🍿","titulo":"💵 Confirmación de Pago Recibido (Venta Directa / WhatsApp)","descripcion":"Enviado al cliente cuando transfiere por Pago Móvil, Binance o Efectivo directamente a Gregory fuera de la web."},"solicitud_datos_membresia_personal":{"id":"solicitud_datos_membresia_personal","tags":["cliente","producto","monto_usd","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 👋 Tu pago de ${monto_usd} USD para {producto} ha sido confirmado con éxito en {negocio} ✅\n\nPara proceder con la activación personalizada de tu membresía:\n👉 *Por favor indícanos el correo electrónico* al que deseas vincular el servicio (o al que te enviaremos la invitación de activación).\n\nUna vez nos envíes tu correo, activaremos tu cuenta en un lapso estimado de 15 a 30 minutos. ¡Quedamos atentos a tu respuesta! 🚀","titulo":"✉️ Solicitud de Correo para Membresía a Pedido","descripcion":"Para membresías bajo demanda (Spotify Familiar, Canva Pro, YouTube Premium, etc.) que se activan al correo personal del cliente."},"confirmacion_renovacion_fuera_plataforma":{"id":"confirmacion_renovacion_fuera_plataforma","tags":["cliente","producto","perfil","vence","monto_usd","referencia","negocio"],"canal":"whatsapp","cuerpo":"¡Hola {cliente}! 🔄✨\nConfirmamos tu pago directo para la RENOVACIÓN de tu servicio en {negocio}.\n\n📺 *Servicio:* {producto}\n👤 *Perfil:* {perfil}\n📅 *Nuevo Vencimiento (+30 días):* {vence}\n💵 *Monto:* ${monto_usd} USD\n🔢 *Referencia:* {referencia}\n\n✅ Tu pantalla continúa activa exactamente con tus mismas credenciales, historial y series guardadas sin interrupción. ¡Gracias por renovar con nosotros! ⭐🍿","titulo":"🔄 Confirmación de Renovación por Pago Directo","descripcion":"Para clientes directos que pagaron su mensualidad por WhatsApp/Pago Móvil para extender su pantalla existente."}}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 4. Tasa BCV Inicial
INSERT INTO public.exchange_rates (bs_por_usd, fecha, fuente)
VALUES (883.3963, '2026-10-21', 'BCV')
ON CONFLICT DO NOTHING;

-- 5. Clave de Cifrado en Secrets (AES-256)
INSERT INTO public.secrets (name, value)
VALUES ('enc_key', 'gregory_secret_master_key_2026_x789b12')
ON CONFLICT (name) DO NOTHING;

-- 6. Catálogo de Productos Oficiales (69 Productos)
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c2b130bd-97dc-4b2c-8b1d-c87f04797844', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'CANVA 30 DIAS', 'servicio', 2.56, 2.06, 1.72, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('4323f2e9-4839-4202-9957-d5152cba3ba3', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'CANVA 90 DIAS', 'servicio', 7.12, 5.37, 4.48, 90, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('fe6554dc-6dda-45c8-9550-f8e95c24c634', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'DISNEY PERFIL 15 DIAS', 'pantalla', 2.5, 2.08, 1.73, 15, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('43487373-260f-487d-85f0-871d9d6fbf89', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'VIX PERFIL 15 DIAS', 'pantalla', 1.25, 0.85, 0.71, 15, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('911c01cd-ab71-48da-9cf1-5eb3ce0746be', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'FLUJOTV PERFIL 180+30 DIAS', 'pantalla', 25.42, 17.39, 14.51, 210, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('1f9cf6e7-8128-4a82-8b79-75791f887a1b', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'VIKI RAKUTEN PERFIL 30 DIAS', 'pantalla', 3.03, 2.23, 1.86, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('3b140a9e-93ff-43cc-a836-eb5b4d4038ed', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'FLUJOTV PERFIL 90 DIAS', 'pantalla', 12.51, 8.5, 7.09, 90, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('6f4fdf56-424c-435c-820a-6182748fb473', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', '4 PERFIL EXTRA NETFLIX 30 DIAS', 'pantalla', 24.04, 22.11, 18.44, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c4755fb9-0168-448b-9399-4c7fa5b53a30', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'TELELTINO PERFIL 90 DIAS', 'pantalla', 12.21, 8.95, 7.46, 90, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('97aea63d-c5ee-44c8-90bc-87f8a3929fcb', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'SPOTIFY 30 DIAS ALQUILER', 'pantalla', 5.66, 4.65, 3.88, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('2db418ee-d3de-4578-856b-42247d47bc1d', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'SPOTIFY 60 DIAS ALQUILER', 'pantalla', 10.8, 9.05, 7.54, 60, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('3f6e796b-acf3-4052-bb8d-1d98b10af5a9', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'YOUTUBE PREMIUM 30 DIAS', 'pantalla', 3.11, 2.71, 2.26, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('12573bb5-85ca-4be1-8cc4-f21e132b3aec', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'YOUTUBE PREMIUM 60 DIAS', 'pantalla', 5.13, 4.77, 3.98, 60, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('1978f094-ee20-4bbb-9e8d-2a8bb72dba24', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'TELELATINO PERFIL 180 DIAS', 'pantalla', 24.42, 17.89, 14.92, 180, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('95dbc467-6d30-4138-b1f4-414e1b8dbead', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'UNIVERSAL PERFIL 30 DIAS', 'pantalla', 3.03, 2.23, 1.86, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('719c7da0-714d-4e71-aec6-6dd4eb33ef4a', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'FLUJOTV PERFIL 365+60 DIAS', 'pantalla', 50.82, 35.78, 29.84, 425, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('56bbbd2e-ad38-413c-b0f7-0d97ab72e5a3', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'CANVA 180 DIAS', 'servicio', 12.23, 9.17, 7.64, 180, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('817719d3-2adf-4010-b2c8-35c879867ca6', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Netflix', 'pantalla', 6, 4.29, 3.58, 30, 1, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('44f72a12-1f9a-4827-91ba-2687a34694f8', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'DRAMA BOX CTA C  30 DIAS', 'pantalla', 3, 1.3, 1.5, 30, 1, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('5389333e-9252-4a1a-9423-1dd253e25afc', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Perfil Extra Netflix', 'pantalla', 8, 6.08, 4.5, 30, 2, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('9231b1d6-93c0-4e2e-b003-5e5c31b2c4b2', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Disney+ Premium', 'pantalla', 5, 3.32, 2.77, 30, 3, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('9caba6a0-3def-4ade-8f53-7d078c737a29', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Max Estándar', 'pantalla', 3, 1.9, 1.58, 30, 4, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c19efbe7-e2e0-406c-97a8-2557e7af4b96', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Amazon Prime Video', 'pantalla', 2.53, 1.81, 1.51, 30, 5, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('21d5e3b4-be67-4ef1-848c-a9a5c8f493d5', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'ViX Premium', 'pantalla', 2.5, 1.7, 1.42, 30, 6, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('6153d298-de80-446f-8683-d266e527fc34', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Crunchyroll Fan', 'pantalla', 3.02, 2.12, 1.77, 30, 7, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('1e7f6366-a111-437b-8b68-7659117275ac', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Paramount+', 'pantalla', 3.03, 2.23, 1.86, 30, 8, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('1facf06b-7777-43a8-bd1b-28b9abc685d1', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Telelatino', 'pantalla', 4.5, 3.3, 2.75, 30, 9, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('e7a9fcd1-9771-4bec-85ba-b139185de5ce', 'e23806c0-6237-4dfc-bf16-99a7e8e66b20', 'Flujo TV', 'pantalla', 4.5, 3.3, 2.75, 30, 10, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('3b8585ca-9bfc-44e5-bdc3-f11ce16a457b', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'DEEZER  CTA C 30 DIAS', 'cuenta_completa', 3.09, 2.59, 2.16, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('82bac9c2-a266-4125-8d91-d47cb1ca61ad', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'NETFLIX CUENTA COMPLETA 30 DIAS', 'cuenta_completa', 19, 17.18, 14.33, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('467c53e0-9819-467d-a5f2-5558832a0a15', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'MAX CUENTA COMPLETA 30 DIAS', 'cuenta_completa', 8, 5.89, 4.91, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('fe87da46-d60d-4d71-a549-c8090ceffc46', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'CRUNCHYROLL CTA COMPLETA 30 DIAS', 'cuenta_completa', 7.1, 5.1, 4.25, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('0f202af8-c3b1-40ac-ad73-a57f37452797', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'PARAMOUNT CTA C 30 DIAS', 'cuenta_completa', 7.21, 5.9, 4.92, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('07aa1a1b-f9e6-449d-826c-957fabe892c5', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'PARAMOUNT CTA C  ALQUILER 30 DIAS', 'cuenta_completa', 7.13, 5.46, 4.55, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('79ee78ca-6c98-416c-ae4e-8653507fe836', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'UNIVERSAL CTA C 30 DIAS', 'cuenta_completa', 7.17, 5.58, 4.65, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('39377c66-e638-4882-9452-aa934bc8867f', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'VIKI RAKUTEN CTA C 30 DIAS', 'cuenta_completa', 7.17, 5.58, 4.65, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('a8a148a4-37d8-43f8-9e78-998c071d8fbf', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'TELELATINO CTA C 30 DIAS', 'cuenta_completa', 8.21, 6.7, 5.59, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('598f706a-bc20-4e54-ab53-3d3fdbd21191', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'TELELATINO CTA C 90 DIAS', 'cuenta_completa', 20.61, 17.08, 14.25, 90, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('991fdddf-95d5-4141-afb8-4d613ba367b3', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'TELELATINO CTA C  180 DIAS', 'cuenta_completa', 42.74, 35.67, 29.75, 180, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('6a484fd0-2172-4b55-b5d2-7f1c38b8e9e6', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'MAX CTA C ALQUILER  30 DIAS', 'cuenta_completa', 8, 5.53, 4.61, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c23c3f4f-72a6-486f-8ad8-dd1fb6d30e36', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'DISNEY PREMIUM CTA C 30 DIAS', 'cuenta_completa', 11.98, 10.67, 8.9, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('cbb4af03-e403-4e94-b53a-18044dd52951', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'PRIME VIDEO CTA C 30 DIAS', 'cuenta_completa', 6.71, 5.7, 4.75, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c8e3ed62-8c16-406f-9671-7bf4dfcbeb13', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'VIX CTA C 30 DIAS', 'cuenta_completa', 5.03, 3.53, 2.94, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('8cd76175-0c9c-4424-bd82-b8977566b9a0', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'FLUJOTV CTA C 30 DIAS', 'cuenta_completa', 9.21, 7.15, 5.96, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('f01ce00d-be52-4c5f-af42-b1ae6b3173eb', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'FLUJOTV CTA C 180+30  DIAS', 'cuenta_completa', 51.24, 41.17, 34.34, 210, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('01982296-a72f-48c4-84e9-aef92105e21c', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'FLUJOTV CTA C 365+60 DIAS', 'cuenta_completa', 102.47, 82.34, 68.67, 425, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('30dcb9a0-fd54-4e1f-aa27-503aa2d94009', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'PLEX CTA C 30 DIAS', 'cuenta_completa', 4.64, 3.88, 3.23, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('08846893-c11f-476e-824b-967aa8fbcb7c', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'EMBY CTA C 30 DIAS', 'cuenta_completa', 5.17, 4.36, 3.63, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c299d305-c260-4733-969b-340be20be57a', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', 'JELLYFIN CTA C 30 DIAS', 'cuenta_completa', 5.17, 4.36, 3.63, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('b4d53291-36a9-433e-8b04-296d59f8b734', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', '3 CUENTAS VIX 30 DIAS', 'cuenta_completa', 10.1, 7.1, 5.92, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('96f1dd05-606c-4d6f-9270-17685bb4133e', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', '3 CUENTAS MAX 30 DIAS', 'cuenta_completa', 18.41, 14.64, 12.21, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('a8fcd384-200d-424e-a85c-c3f7f26ca452', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', '3 CUENTAS PRIME 30 DIAS', 'cuenta_completa', 18.62, 16.14, 13.46, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('8e51db01-3f3c-4718-8f89-43db6e37d760', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', '3 CUENTAS PARAMOUNT 30 DIAS', 'cuenta_completa', 18.61, 16.08, 13.41, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('e1f2ef27-c6b3-448b-a62a-ce4803000a9c', 'e23806c0-6237-4dfc-bf16-99a7e8e66b21', '3 CUENTAS CRUNCHYROOL 30 DIAS', 'cuenta_completa', 14.31, 11.29, 9.42, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('c745a754-e1ea-45e5-b6d9-7eec7cf23c61', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 6 (NETFLIX +CRUNCHYROLL)', 'servicio', 8.13, 6.2, 5.17, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('2c4f8eec-9fd4-4d18-8227-3a13d2dd6c18', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 1 (NETFLIX +VIX)', 'servicio', 7.65, 5.48, 4.57, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('190d1feb-0835-4902-b445-7e0c751ad32c', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 2 (NETFLIX+PRIME)', 'servicio', 7, 6.01, 5.01, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('bc9205ad-8b44-4a1d-a0b0-efd6b6985dd7', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 3 (NETFLIX + MAX)', 'servicio', 8, 5.81, 4.84, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('63638554-72c6-44ca-bbf4-ba28f7584f38', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 4 (NETFLIX + DISNEY)', 'servicio', 9.9, 7.24, 6.04, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('d0e5ecfc-1da8-44e6-b8c8-0bfe29a1f73b', 'e23806c0-6237-4dfc-bf16-99a7e8e66b22', 'COMBO 5 (NETFLIX + PARAMOUNT)', 'servicio', 8, 6.2, 5.17, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('58eb0b47-f23a-4d24-a1e7-bf73ca402c78', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'PAQUETE OFFICE 365 30 DIAS', 'servicio', 2.8, 2.3, 1.5, 30, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('6e021b16-879b-4d9a-ab76-8b835268d04f', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'GEMINIS PRO 6 meses', 'servicio', 4, 3.5, 3, 180, 0, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('d60c9c3d-c225-45dd-99a4-adffcc61be4f', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'SPOTIFY PREMIUM APK', 'servicio', 3, 2, 1.2, 30, 20, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('cb1ab668-f8ef-4d30-8be2-57621abb3623', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'YOUTUBE PREMIUM APK', 'servicio', 2, 1.3, 1, 30, 21, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('389413bb-e26c-469d-b64a-58655ddc038b', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'CAPCUT APK', 'servicio', 3, 2, 1.2, 30, 22, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('b00e4a3f-c36c-4d9d-b82a-5cc80fcde615', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'PICSART APK', 'servicio', 3, 2, 1.2, 30, 23, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('ebb67bb4-f370-4aac-b716-2cd725e92c6f', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'DRAMA BOX APK', 'servicio', 3, 2, 1.2, 30, 24, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('0dfdb6c1-b375-40d2-a927-efd1c0b5841f', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'FREEREELS APK', 'servicio', 3, 2, 1.2, 30, 25, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;
INSERT INTO public.products (id, category_id, nombre, tipo, precio_usd, precio_revendedor_usd, precio_binance_usd, duracion_dias, orden, activo, badge, perfiles_por_cuenta, permite_cuotas, es_exclusivo_central)
VALUES ('6f6b554f-f889-49bf-b75e-d00f9f61d481', 'e23806c0-6237-4dfc-bf16-99a7e8e66b23', 'REELSHORT APK', 'servicio', 3, 2, 1.2, 30, 26, true, NULL, 1, false, false)
ON CONFLICT (id) DO UPDATE SET 
  nombre = EXCLUDED.nombre,
  precio_usd = EXCLUDED.precio_usd,
  precio_revendedor_usd = EXCLUDED.precio_revendedor_usd,
  precio_binance_usd = EXCLUDED.precio_binance_usd,
  activo = EXCLUDED.activo;

-- 7. Cuentas Administradoras Oficiales
INSERT INTO public.admins (email)
VALUES 
  ('emprendimientogregoryizquierdo@gmail.com'),
  ('gregoryrodriguez2021@gmail.com'),
  ('admin.demo@gregoryizquierdo.xyz')
ON CONFLICT (email) DO NOTHING;
