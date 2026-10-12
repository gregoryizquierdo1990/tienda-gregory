-- Migracion 12: Submódulos de Plantillas de Mensajes Multicanal y Niveles de Usuarios con Beneficios
-- Almacena las plantillas de comunicación y las configuraciones de niveles (Clientes, Revendedores, Franquiciados) en settings.

-- 1. Insertar configuración por defecto de plantillas de mensajes (si no existe)
insert into settings (key, value)
values ('plantillas_mensajes', '{
  "entrega_servicio": {
    "id": "entrega_servicio",
    "canal": "whatsapp",
    "titulo": "Entrega de Credenciales del Pedido",
    "descripcion": "Enviado al cliente cuando su pedido es conciliado y se entregan las credenciales de acceso.",
    "cuerpo": "¡Hola {cliente}! 🎉 Gracias por tu compra en {negocio}.\nAquí tienes los datos de acceso para tu servicio:\n\n📌 Servicio: {producto}\n📧 Correo: {correo}\n🔑 Clave: {clave}\n👤 Perfil: {perfil}\n🔒 PIN: {pin}\n⏳ Vence el: {vence}\n🛡️ Garantía: {garantia} días\n\n⚠️ Instrucciones:\n• No modificar correo ni perfil asignado.\n• Ante dudas indícanos tu ID {codigo_id}.\n¡Que disfrutes tu servicio! ⭐"
  },
  "cobro_cuota": {
    "id": "cobro_cuota",
    "canal": "whatsapp",
    "titulo": "Cobro de Cuota Pendiente (BNPL)",
    "descripcion": "Recordatorio enviado al cliente con los detalles de su cuota financiada por pagar.",
    "cuerpo": "Hola {cliente}, un cordial saludo de {negocio} 👋\nTe recordamos que tienes una cuota pendiente de tu servicio financiado:\n\n📦 Servicio: {producto}\n💳 Cuota: #{cuota} de {total_cuotas}\n💵 Monto en USD: ${monto_usd} USD\n🇻🇪 Monto en Bs: Bs. {monto_bs} (Tasa BCV {tasa_bcv})\n📅 Fecha de vencimiento: {fecha_vencimiento}\n\nPor favor envíanos el comprobante una vez realizada la transferencia. ¡Muchas gracias por tu puntualidad!"
  },
  "entrega_credito": {
    "id": "entrega_credito",
    "canal": "whatsapp",
    "titulo": "Activación de Servicio a Crédito",
    "descripcion": "Notificación cuando se entrega o renueva un servicio a crédito con fecha límite de pago.",
    "cuerpo": "Hola {cliente}! Te saludamos de {negocio} ✨\nTu servicio de {producto} ha sido activado/renovado a CRÉDITO por 30 días de disfrute.\n\n💵 Monto pendiente: ${monto_usd} USD\n📅 Fecha límite para el pago: {fecha_vence_credito} ({dias_credito} días)\n💳 Recuerda que puedes pagar con Pago Móvil o con tu Tarjeta Digital Zeny.\n\n¡Muchas gracias por tu preferencia y confianza continua! ⭐"
  },
  "aviso_vencimiento": {
    "id": "aviso_vencimiento",
    "canal": "whatsapp",
    "titulo": "Aviso Previo de Vencimiento de Suscripción",
    "descripcion": "Mensaje preventivo antes del vencimiento para ofrecer la renovación inmediata.",
    "cuerpo": "Hola {cliente}! ⏰ Tu servicio de {producto} está próximo a vencer el {fecha_vence}.\n\nPara mantener tu perfil activo y no perder tus pantallas guardadas, puedes renovar directamente desde tu portal con saldo Zeny o confirmarnos por acá:\n💵 Monto de renovación: ${monto_usd} USD\n🌐 Tu Portal de Cliente: {portal_url}\n\n¿Deseas renovar para este próximo período? Quedamos a tu orden."
  },
  "bienvenida_tarjeta": {
    "id": "bienvenida_tarjeta",
    "canal": "whatsapp",
    "titulo": "Bienvenida y Tarjeta Zeny Emitida",
    "descripcion": "Enviado tras el registro para entregar el ID único, tarjeta digital y código de activación.",
    "cuerpo": "¡Bienvenido a {negocio}, {cliente}! 🌟\nTu cuenta ha sido creada exitosamente en nuestra plataforma.\n\n🆔 Tu Identificador oficial: {codigo_id}\n💳 Tarjeta Digital Zeny: {numero_tarjeta}\n🔐 Código de Activación: {codigo_activacion}\n🌐 Portal Web: {portal_url}\n\nTu Tarjeta Zeny te permite comprar al instante sin esperas bancarias. ¡Estamos listos para atenderte!"
  },
  "recibo_factura": {
    "id": "recibo_factura",
    "canal": "whatsapp",
    "titulo": "Envío de Factura Digital / Recibo",
    "descripcion": "Comprobante formal de pago con datos fiscales, tasa BCV y desglose de items.",
    "cuerpo": "Hola {cliente}! Adjuntamos tu comprobante digital de compra en {negocio} 📄:\n\n🧾 Documento: {numero_factura}\n📅 Fecha: {fecha}\n💵 Total: ${total_usd} USD (Bs. {total_bs})\n🏢 RIF Emisor: {rif}\n\nPuedes descargar o imprimir tu factura oficial directamente desde tu portal. ¡Gracias por confiar en nosotros!"
  },
  "datos_limpios_revendedor": {
    "id": "datos_limpios_revendedor",
    "canal": "whatsapp",
    "titulo": "Formato Reenvío de Revendedor a Cliente Final",
    "descripcion": "Estructura limpia sin marcas que el revendedor copia para entregar a sus propios clientes.",
    "cuerpo": "*{servicio}*\nCorreo: {correo}\nClave: {clave}\nPerfil: {perfil}\nPIN: {pin}\nVence: {vence}\n\n⚠️ Cuida tus accesos y disfruta tu servicio. Garantía activa durante todo el período."
  },
  "notificacion_telegram_bot": {
    "id": "notificacion_telegram_bot",
    "canal": "telegram",
    "titulo": "Aviso del Bot de Telegram al Cliente",
    "descripcion": "Mensaje formateado enviado por el bot de Telegram ante pedidos o recargas.",
    "cuerpo": "🤖 *Notificación de {negocio}*\n\nHola {cliente}, tu solicitud para *{servicio}* se encuentra en estado: *{estado}*.\nMonto: ${monto_usd} USD.\n\nAccede a tu portal para ver tus accesos actualizados."
  }
}'::jsonb)
on conflict (key) do nothing;

-- 2. Insertar configuración por defecto de niveles de usuario y beneficios adjuntos
insert into settings (key, value)
values ('niveles_beneficios', '{
  "cliente": {
    "id": "cliente",
    "nombre": "Cliente Final Oficial",
    "subtitulo": "Usuarios y familias que adquieren servicios de entretenimiento y streaming para consumo personal.",
    "prefijo_codigo": "CLT",
    "color": "#00d4ff",
    "badge_icon": "👤",
    "descuento_porcentaje": "Precios Detal Oficiales",
    "requisito_acceso": "Registro gratuito inmediato en la tienda",
    "beneficios": [
      {
        "icono": "💳",
        "titulo": "Tarjeta Digital Zeny Oficial",
        "descripcion": "Tarjeta personalizada con tu nombre y número único vinculada a tu saldo para compras instantáneas.",
        "destacado": true
      },
      {
        "icono": "🛡️",
        "titulo": "Garantía Total por 30 Días",
        "descripcion": "Soporte y reactivación inmediata ante cualquier reporte o cambio en tus perfiles contratados.",
        "destacado": true
      },
      {
        "icono": "📅",
        "titulo": "Financiamiento en 2 Cuotas (BNPL)",
        "descripcion": "Posibilidad de pagar tus servicios en dos partes (50% inicial hoy y 50% a los 15 días).",
        "destacado": true
      },
      {
        "icono": "🧾",
        "titulo": "Facturación Digital Oficial",
        "descripcion": "Recibos con validez digital expresados en USD y Bolívares a la tasa oficial del BCV.",
        "destacado": false
      },
      {
        "icono": "🔔",
        "titulo": "Recordatorios Automatizados",
        "descripcion": "Avisos oportunos a tu WhatsApp antes del vencimiento para que no te quedes sin servicio.",
        "destacado": false
      }
    ]
  },
  "revendedor": {
    "id": "revendedor",
    "nombre": "Revendedor Mayorista VIP",
    "subtitulo": "Emprendedores y distribuidores comerciales que compran al por mayor para revender a sus propios clientes.",
    "prefijo_codigo": "RVD",
    "color": "#ffb703",
    "badge_icon": "⭐",
    "descuento_porcentaje": "15% a 25% Descuento Mayorista",
    "requisito_acceso": "Volumen mínimo de 5 compras mensuales o recarga de saldo comercial",
    "beneficios": [
      {
        "icono": "🏷️",
        "titulo": "Tarifas Mayoristas Automáticas",
        "descripcion": "Precios especiales con descuento directo visible en todo el catálogo de pantallas y cuentas completas.",
        "destacado": true
      },
      {
        "icono": "📋",
        "titulo": "Reenvío Limpio de Accesos",
        "descripcion": "Botón de un solo clic para copiar los datos sin marcas comerciales para enviárselos a tus clientes finales.",
        "destacado": true
      },
      {
        "icono": "🆔",
        "titulo": "Identificador VIP RVD:1001+",
        "descripcion": "Código prioritario en el sistema para aprobación express de compras y conciliaciones.",
        "destacado": true
      },
      {
        "icono": "💳",
        "titulo": "Línea de Crédito Comercial",
        "descripcion": "Entrega de pantallas a crédito para que no detengas tus ventas mientras recibes los pagos de tus clientes.",
        "destacado": true
      },
      {
        "icono": "⚡",
        "titulo": "Canal de Soporte Directo",
        "descripcion": "Atención preferencial por WhatsApp para solución de incidencias y traslados de pantallas.",
        "destacado": false
      }
    ]
  },
  "franquiciado": {
    "id": "franquiciado",
    "nombre": "Franquicia Digital Asociada (SaaS)",
    "subtitulo": "Socios comerciales que operan su propia tienda web con marca propia sobre nuestra infraestructura.",
    "prefijo_codigo": "FRQ",
    "color": "#a855f7",
    "badge_icon": "🏢",
    "descuento_porcentaje": "40% a 60% Margen de Ganancia Neto",
    "requisito_acceso": "Contrato de franquicia y canon mensual de mantenimiento tecnológico",
    "beneficios": [
      {
        "icono": "🌐",
        "titulo": "Tienda Web con Subdominio Propio",
        "descripcion": "Tu propio sitio web operativo 24/7 en tufranquicia.gregoryizquierdo.xyz listo para vender.",
        "destacado": true
      },
      {
        "icono": "🎨",
        "titulo": "Identidad de Marca 100% Personalizada",
        "descripcion": "Tu propio logo, colores de marca, datos bancarios de cobro y teléfonos de contacto independientes.",
        "destacado": true
      },
      {
        "icono": "💼",
        "titulo": "Panel de Administración Privado",
        "descripcion": "Control total de tus propios clientes, historial de pedidos, facturas e incidencias sin intermediarios.",
        "destacado": true
      },
      {
        "icono": "🔑",
        "titulo": "Inventario Centralizado Automatizado",
        "descripcion": "Vende directamente del stock global sin necesidad de comprar ni arriesgar capital en cuentas por adelantado.",
        "destacado": true
      },
      {
        "icono": "🛠️",
        "titulo": "Soporte y Mantenimiento Tecnológico",
        "descripcion": "Servidores, certificados SSL, actualizaciones de software y seguridad garantizados por la central.",
        "destacado": false
      }
    ]
  }
}'::jsonb)
on conflict (key) do nothing;

-- 3. Actualizar la política pub_settings para permitir lectura anónima y de clientes
drop policy if exists pub_settings on settings;
create policy pub_settings on settings for select using (
  key in ('negocio', 'zeny', 'reserva', 'app', 'plantillas_mensajes', 'niveles_beneficios')
);
