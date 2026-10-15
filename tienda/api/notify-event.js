// API centralizada para recepción de eventos y despacho de notificaciones a Telegram & Push
import { sendAll } from './_notify.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Método no permitido' });
  }

  const { type, data } = req.body || {};
  if (!type || !data) {
    return res.status(400).json({ error: 'Faltan parámetros type o data' });
  }

  const escHtml = str => String(str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const cleanPhone = String(data.telefono || data.phone || data.whatsapp || '').replace(/\D/g, '');
  const waLink = cleanPhone ? `https://wa.me/${cleanPhone.startsWith('58') ? cleanPhone : (cleanPhone.startsWith('0') ? '58' + cleanPhone.slice(1) : '58' + cleanPhone)}` : '';

  let plainMsg = '';
  let htmlMsg = '';
  let kind = type;

  switch (type) {
    // 1. COMPRA DE ALGUN SERVICIO
    case 'compra_servicio': {
      const prod = escHtml(data.producto || data.servicio || 'Servicio Digital');
      const nom = escHtml(data.cliente || data.nombre || 'Cliente');
      const correo = escHtml(data.correo || data.email || 'No especificado');
      const usd = Number(data.total_usd || data.monto_usd || 0).toFixed(2);
      const bs = data.total_bs ? Number(data.total_bs).toLocaleString('es-VE', { minimumFractionDigits: 2 }) : '';
      const metodo = escHtml(data.metodo || 'Pago Móvil');
      const ref = escHtml(data.referencia || 'N/A');

      plainMsg = `🛒 ¡NUEVA COMPRA! ${prod} - $${usd} USD. Cliente: ${nom} (${cleanPhone}). Ref: ${ref}`;
      htmlMsg = `🛒 <b>¡NUEVA COMPRA DE SERVICIO!</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 <b>Cliente:</b> ${nom}
📱 <b>WhatsApp:</b> ${waLink ? `<a href="${waLink}">+${cleanPhone}</a>` : 'No registrado'}
✉️ <b>Correo:</b> <code>${correo}</code>
📦 <b>Servicio:</b> <b>${prod}</b>
💵 <b>Total:</b> <b>$${usd} USD</b>${bs ? ` (Bs. ${bs})` : ''}
💳 <b>Método:</b> ${metodo}
🔢 <b>Referencia:</b> <code>${ref}</code>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 <a href="https://tienda.gregoryizquierdo.xyz/#admin">Ver pedido en Panel Admin</a>`;
      break;
    }

    // 2. SOLICITUD DE RECARGA DE BILLETERA ZENY
    case 'recarga_zeny': {
      const nom = escHtml(data.cliente || data.nombre || 'Cliente');
      const usd = Number(data.monto_usd || 0).toFixed(2);
      const bs = data.monto_bs ? Number(data.monto_bs).toLocaleString('es-VE', { minimumFractionDigits: 2 }) : '';
      const metodo = escHtml(data.metodo || 'Pago Móvil');
      const ref = escHtml(data.referencia || 'N/A');

      plainMsg = `💰 ¡SOLICITUD RECARGA ZENY! $${usd} USD. Cliente: ${nom} (${cleanPhone}). Ref: ${ref}`;
      htmlMsg = `💰 <b>¡SOLICITUD DE RECARGA BILLETERA ZENY!</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 <b>Cliente:</b> ${nom}
📱 <b>WhatsApp:</b> ${waLink ? `<a href="${waLink}">+${cleanPhone}</a>` : 'No registrado'}
💵 <b>Monto a Acreditar:</b> <b>$${usd} USD</b>${bs ? ` (Bs. ${bs})` : ''}
💳 <b>Forma de Pago:</b> ${metodo}
🔢 <b>Comprobante / Ref:</b> <code>${ref}</code>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 <a href="https://tienda.gregoryizquierdo.xyz/#admin">Revisar y Aprobar en Billetera Zeny</a>`;
      break;
    }

    // 3. SOLICITUD DE COMPRA DE USDT (MESA DE CAMBIO)
    case 'compra_usdt': {
      const nom = escHtml(data.cliente || data.nombre || 'Cliente');
      const usdt = Number(data.monto_usdt || data.usdt || 0).toFixed(2);
      const bs = data.total_bs ? Number(data.total_bs).toLocaleString('es-VE', { minimumFractionDigits: 2 }) : '';
      const tasa = data.tasa ? Number(data.tasa).toFixed(2) : '';
      const destTipo = data.destino_tipo === 'binance_email' ? 'Correo Binance' : 'ID Binance Pay';
      const destVal = escHtml(data.destino_valor || 'No especificado');
      const ref = escHtml(data.referencia || 'N/A');

      plainMsg = `💱 ¡SOLICITUD MESA DE CAMBIO! $${usdt} USDT. Destino: ${destVal}. Cliente: ${nom} (${cleanPhone}).`;
      htmlMsg = `💱 <b>¡NUEVA SOLICITUD DE USDT (MESA DE CAMBIO)!</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 <b>Cliente:</b> ${nom}
📱 <b>WhatsApp:</b> ${waLink ? `<a href="${waLink}">+${cleanPhone}</a>` : 'No registrado'}
💵 <b>Monto USDT:</b> <b>$${usdt} USDT</b>
🇻🇪 <b>Total a Recibir:</b> <b>Bs. ${bs}</b> ${tasa ? `(Tasa: ${tasa})` : ''}
🆔 <b>Destino (${destTipo}):</b> <code>${destVal}</code>
🔢 <b>Referencia Pago Móvil:</b> <code>${ref}</code>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 <a href="https://tienda.gregoryizquierdo.xyz/#admin">Conciliar Abono en Mesa de Cambio</a>`;
      break;
    }

    // 4. REPORTE DE FALLAS (INCIDENCIAS)
    case 'reporte_falla': {
      const nom = escHtml(data.cliente || data.nombre || 'Cliente');
      const srv = escHtml(data.servicio || data.producto || 'Servicio Digital');
      const desc = escHtml(data.descripcion || data.detalle || 'Falla reportada por el cliente');
      const motivo = escHtml(data.motivo || 'Incidencia Técnica');

      plainMsg = `⚠️ ¡REPORTE DE FALLA! Servicio: ${srv}. Cliente: ${nom} (${cleanPhone}). Detalle: ${desc}`;
      htmlMsg = `⚠️ <b>¡REPORTE DE FALLA / INCIDENCIA!</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 <b>Cliente:</b> ${nom}
📱 <b>WhatsApp:</b> ${waLink ? `<a href="${waLink}">+${cleanPhone}</a>` : 'No registrado'}
📦 <b>Servicio Afectado:</b> <b>${srv}</b>
🏷️ <b>Tipo de Falla:</b> ${motivo}
📝 <b>Descripción del Problema:</b>
<i>"${desc}"</i>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 ${waLink ? `<a href="${waLink}?text=${encodeURIComponent(`Hola ${nom}! 👋 Recibimos tu reporte de soporte sobre ${srv}. Ya lo estamos revisando.`)}">Contactar al cliente por WhatsApp</a>` : '<a href="https://tienda.gregoryizquierdo.xyz/#admin">Ver en Incidencias</a>'}`;
      break;
    }

    // 5. LISTADO DE VENCIMIENTOS DEL DÍA (CLIENTES Y CUENTAS MADRE)
    case 'vencimientos_resumen': {
      const fecha = escHtml(data.fecha || new Date().toISOString().slice(0, 10));
      const totCli = data.total_clientes || 0;
      const totMad = data.total_madres || 0;
      const listCli = (data.clientes || []).map(c => `• 👤 <b>[${escHtml(c.plataforma || 'Servicio')}]</b> ${escHtml(c.perfil || '')} (${escHtml(c.correo || '')}) - ${escHtml(c.cliente || 'Cliente')}${c.telefono ? ` 📱 <a href="https://wa.me/${c.telefono.replace(/\D/g,'')}">${c.telefono}</a>` : ''}`).join('\n') || '<i>No hay perfiles de clientes por vencer hoy.</i>';
      const listMad = (data.madres || []).map(m => `• 🔑 <b>[${escHtml(m.plataforma || 'Cuenta')}]</b> <code>${escHtml(m.correo || '')}</code> (Perfiles: ${m.perfiles_activos || 0})`).join('\n') || '<i>No hay cuentas madre por vencer hoy.</i>';

      plainMsg = `📅 VENCIMIENTOS DE HOY (${fecha}): ${totCli} clientes y ${totMad} cuentas madre.`;
      htmlMsg = `📅 <b>CONTROL DE VENCIMIENTOS - HOY (${fecha})</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 <b>CLIENTES / PERFILES POR VENCER (${totCli}):</b>
${listCli}

🔑 <b>CUENTAS MADRE POR VENCER (${totMad}):</b>
${listMad}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 <b>Total a gestionar hoy:</b> ${totCli} clientes · ${totMad} cuentas madre.
👉 <a href="https://tienda.gregoryizquierdo.xyz/#admin">Abrir Calendario de Vencimientos</a>`;
      break;
    }

    // 6. CUANDO SE REGISTRA UN NUEVO CLIENTE AL PORTAL
    case 'nuevo_cliente': {
      const nom = escHtml(data.nombre || 'Nuevo Usuario');
      const correo = escHtml(data.email || data.correo || 'No indicado');
      const tel = escHtml(data.telefono || 'No indicado');

      plainMsg = `👤 ¡NUEVO CLIENTE REGISTRADO! ${nom} (${tel}) - ${correo}`;
      htmlMsg = `👤 <b>¡NUEVO CLIENTE REGISTRADO AL PORTAL!</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 <b>Nombre y Apellido:</b> ${nom}
✉️ <b>Correo Electrónico:</b> <code>${correo}</code>
📱 <b>WhatsApp:</b> ${waLink ? `<a href="${waLink}">+${cleanPhone}</a>` : tel}
💳 <b>Tarjeta Digital Zeny:</b> Asignada y lista para compras
📅 <b>Fecha de Alta:</b> ${new Date().toLocaleDateString('es-VE')}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 <a href="https://tienda.gregoryizquierdo.xyz/#admin">Ver en Directorio de Clientes</a>`;
      break;
    }

    // 7. SOLICITUD DE CAMBIO DE CLIENTE A REVENDEDOR
    case 'solicitud_revendedor': {
      const nom = escHtml(data.nombre || data.cliente || 'Cliente');
      const correo = escHtml(data.email || 'No indicado');
      const ped = data.pedidos_previos || 0;
      const notas = escHtml(data.notas || data.mensaje || 'Desea acceder a catálogo de mayorista / revendedor');

      plainMsg = `🎖️ ¡SOLICITUD DE REVENDEDOR! ${nom} (${cleanPhone}). Pedidos: ${ped}. Notas: ${notas}`;
      htmlMsg = `🎖️ <b>¡SOLICITUD DE CAMBIO A REVENDEDOR!</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 <b>Cliente:</b> ${nom}
📱 <b>WhatsApp:</b> ${waLink ? `<a href="${waLink}">+${cleanPhone}</a>` : 'No registrado'}
✉️ <b>Correo:</b> <code>${correo}</code>
🛍️ <b>Historial de Compras:</b> ${ped} pedidos previos
📝 <b>Propuesta / Volumen Estimado:</b>
<i>"${notas}"</i>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 ${waLink ? `<a href="${waLink}?text=${encodeURIComponent(`Hola ${nom}! 👋 Recibimos tu solicitud para ser Revendedor Oficial de Emprendimiento Gregory. Cuéntanos sobre tus requerimientos.`)}">Contactar por WhatsApp</a>` : '<a href="https://tienda.gregoryizquierdo.xyz/#admin">Ver en Clientes</a>'}`;
      break;
    }

    // 8. SOLICITUD DE ACTIVACION DE FRANQUICIA
    case 'solicitud_franquicia': {
      const biz = escHtml(data.negocio || data.businessName || 'Nueva Franquicia');
      const owner = escHtml(data.titular || data.ownerName || 'Titular');
      const correo = escHtml(data.email || 'No indicado');
      const tg = escHtml(data.telegramUser || 'No indicado');
      const notas = escHtml(data.notes || 'Ninguna');

      plainMsg = `🏢 ¡NUEVA SOLICITUD DE FRANQUICIA! ${biz} - ${owner} (${cleanPhone})`;
      htmlMsg = `🏢 <b>¡NUEVA SOLICITUD DE FRANQUICIA SAAS!</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏢 <b>Nombre del Negocio:</b> <b>${biz}</b>
👤 <b>Titular:</b> ${owner}
📱 <b>WhatsApp:</b> ${waLink ? `<a href="${waLink}">+${cleanPhone}</a>` : 'No registrado'}
✉️ <b>Correo:</b> <code>${correo}</code>
✈️ <b>Telegram:</b> @${tg.replace(/^@/, '')}
📝 <b>Experiencia / Planes:</b>
<i>"${notas}"</i>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 ${waLink ? `<a href="${waLink}?text=${encodeURIComponent(`Hola ${owner}! 👋 Te escribe Gregory Izquierdo respecto a tu solicitud para la franquicia ${biz}.`)}">Contactar por WhatsApp</a>` : '<a href="https://tienda.gregoryizquierdo.xyz/#admin">Ver en Franquicias</a>'}`;
      break;
    }

    // 9. SOLICITUD DE TAQUILLA PARA RECARGAS TELEFONICAS
    case 'solicitud_taquilla': {
      const punto = escHtml(data.nombre_punto || data.punto || 'Punto de Venta');
      const titular = escHtml(data.titular || 'Titular');
      const ubicacion = escHtml(data.ubicacion || data.ciudad || 'No especificada');
      const user247 = escHtml(data.usuario_247 || 'Por asignar');
      const canon = Number(data.canon_usd || 10).toFixed(2);

      plainMsg = `📱 ¡NUEVA TAQUILLA RECARGAS247! ${punto} - ${titular} (${cleanPhone}). Canon: $${canon}`;
      htmlMsg = `📱 <b>¡NUEVA SOLICITUD / ALTA DE DISTRIBUIDOR DE RECARGAS!</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏪 <b>Punto de Venta:</b> <b>${punto}</b>
👤 <b>Titular:</b> ${titular}
📱 <b>WhatsApp:</b> ${waLink ? `<a href="${waLink}">+${cleanPhone}</a>` : 'No registrado'}
📍 <b>Ubicación:</b> ${ubicacion}
💼 <b>Usuario Recargas247:</b> <code>${user247}</code>
💵 <b>Canon Mensual Acordado:</b> <b>$${canon} USD</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 <a href="https://tienda.gregoryizquierdo.xyz/#admin">Gestionar en Red de Distribuidores</a>`;
      break;
    }

    default: {
      plainMsg = `🔔 Aviso: ${JSON.stringify(data).slice(0, 200)}`;
      htmlMsg = `🔔 <b>AVISO DEL SISTEMA</b><br><code>${escHtml(JSON.stringify(data, null, 2))}</code>`;
      break;
    }
  }

  try {
    const resNotify = await sendAll(kind, plainMsg, htmlMsg);
    return res.json({ ok: true, ...resNotify });
  } catch (err) {
    console.error('Error enviando notificación Telegram/Push:', err);
    return res.status(500).json({ error: err.message });
  }
}
