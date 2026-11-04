// Endpoint para conciliación y liberación automática de pedidos por Pago Móvil BDV
// Soporta tanto Webhook directo (HTTP POST) como mensajes reenviados a través del bot @Julian4asistente_bot
import { U, K, sbRest, getSecret } from './_lib.js';

const BDV_BOT_TOKEN = '8571549759:AAHqPS64PQTyVjMEwecJN937dHzLQd-Et_A';
const GREGORY_CHAT_ID = '7154250409';

// Envía notificación al chat de Gregory en Telegram
async function notifyGregoryTelegram(text) {
  try {
    const token = await getSecret('telegram_bdv_bot_token') || BDV_BOT_TOKEN;
    await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: GREGORY_CHAT_ID,
        text,
        parse_mode: 'HTML'
      })
    });
  } catch (err) {
    console.error('Error enviando notificación a Telegram:', err);
  }
}

// Envía credenciales directamente al cliente en Telegram si está vinculado
async function notifyCustomerTelegram(chatId, text) {
  if (!chatId) return;
  try {
    const token = await getSecret('telegram_bdv_bot_token') || BDV_BOT_TOKEN;
    await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: String(chatId),
        text,
        parse_mode: 'HTML'
      })
    });
  } catch (err) {
    console.error('Error enviando credenciales a cliente por Telegram:', err);
  }
}

// Analizador inteligente de texto de notificación bancaria (SMS / Push BDV / MacroDroid)
function parseBankNotificationText(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const clean = raw.replace(/\r?\n/g, ' ').trim();

  // 1. Extraer Referencia
  // Ejemplos: "Ref: 12345678", "Referencia: 987654", "Operacion: 456789", "Ref. 123456"
  let ref = null;
  const refPatterns = [
    /(?:ref|referencia|operaci[oó]n|op|nro|transacci[oó]n|recibo)\.?\s*[:#-]?\s*(\d{4,14})\b/i,
    /\bref\s*(\d{4,14})\b/i,
    /\b(\d{6,12})\b/
  ];
  for (const regex of refPatterns) {
    const m = clean.match(regex);
    if (m && m[1]) {
      ref = m[1].trim();
      break;
    }
  }

  // 2. Extraer Monto en Bolívares
  // Ejemplos: "Bs. 215,50", "Bs 215.50", "Monto: 150,00 Bs", "Bs.S 350.00"
  let monto = null;
  const montoPatterns = [
    /(?:bs\.?s?|bol[ií]vares|monto)\.?\s*[:$]?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2}))/i,
    /([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2}))\s*(?:bs\.?s?|bol[ií]vares)/i,
    /\bmonto\s*[:=]?\s*([0-9.,]+)/i
  ];
  for (const regex of montoPatterns) {
    const m = clean.match(regex);
    if (m && m[1]) {
      let rawVal = m[1].replace(/\s/g, '');
      // Manejar formato venezolano: 1.250,50 o 250,50
      if (rawVal.includes(',') && rawVal.includes('.')) {
        if (rawVal.indexOf('.') < rawVal.indexOf(',')) {
          rawVal = rawVal.replace(/\./g, '').replace(',', '.');
        } else {
          rawVal = rawVal.replace(/,/g, '');
        }
      } else if (rawVal.includes(',')) {
        rawVal = rawVal.replace(',', '.');
      }
      const val = parseFloat(rawVal);
      if (!isNaN(val) && val > 0) {
        monto = Math.round(val * 100) / 100;
        break;
      }
    }
  }

  return { ref, monto, raw: clean };
}

export default async function handler(req, res) {
  // Configuración de CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();

  if (req.method === 'GET') {
    return res.status(200).json({
      status: 'active',
      service: 'Pago Móvil BDV Auto-Conciliación',
      timestamp: new Date().toISOString()
    });
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Método no permitido' });
  }

  try {
    const body = req.body || {};

    // 1. Validación de Token Secreto (si la petición no viene del bot de Telegram)
    const expectedSecret = await getSecret('bdv_webhook_secret');
    const incomingToken = body.secret_token || body.token || (req.headers.authorization || '').replace('Bearer ', '').trim() || req.query?.secret_token;
    const isTelegramWebhook = !!(body.update_id || body.message);

    if (expectedSecret && !isTelegramWebhook) {
      if (incomingToken !== expectedSecret) {
        return res.status(403).json({ error: 'Acceso no autorizado: secret_token inválido' });
      }
    }

    let ref = body.referenciaBanco || body.referencia || body.ref || null;
    let rawMonto = body.montoBanco != null ? body.montoBanco : body.monto;
    let monto = rawMonto ? (typeof rawMonto === 'string' ? parseFloat(rawMonto.replace(',', '.')) : parseFloat(rawMonto)) : null;
    let rawText = body.notificacion || body.raw || body.texto || body.message?.text || null;

    // Caso 1: Actualización recibida desde Telegram Webhook (@Julian4asistente_bot)
    if (body.message && body.message.text) {
      const parsed = parseBankNotificationText(body.message.text);
      if (parsed) {
        if (parsed.ref) ref = parsed.ref;
        if (parsed.monto) monto = parsed.monto;
        rawText = parsed.raw;
      }
    } else if (rawText && (!ref || !monto)) {
      // Caso 2: Se envió el texto de la notificación en "notificacion" o "raw" desde MacroDroid
      const parsed = parseBankNotificationText(rawText);
      if (parsed) {
        if (!ref && parsed.ref) ref = parsed.ref;
        if (!monto && parsed.monto) monto = parsed.monto;
      }
    }

    // MODO CAPTURA: Envía el texto crudo de la notificación al Telegram personal de Gregory para auditoría
    if (rawText && !body.message) {
      await notifyGregoryTelegram(`📲 <b>Notificación BDV recibida desde teléfono:</b>\n<code>${rawText}</code>`);
    }

    if (!ref || !monto || isNaN(monto) || monto <= 0) {
      return res.status(200).json({
        ok: true,
        aviso: 'Notificación guardada en log, pero no contiene referencia o monto de Pago Móvil válido.',
        parsed: { ref, monto, rawText }
      });
    }

    // Limpiar referencia (solo dígitos)
    const cleanRef = String(ref).replace(/[^0-9]/g, '');

    // Llamar a la función RPC de Supabase para hacer match o buffer
    const result = await sbRest('rpc/conciliar_pedido_bdv', {
      method: 'POST',
      body: JSON.stringify({
        p_ref: cleanRef,
        p_monto: monto,
        p_raw: rawText
      })
    });

    if (result?.matched) {
      // MATCH Y LIBERACIÓN INMEDIATA
      const msg = `⚡ <b>¡PAGO MÓVIL BDV CONCILIADO Y ENTREGADO!</b>\n\n` +
        `📦 <b>Pedido:</b> <code>#${result.order_id ? result.order_id.slice(0, 8) : 'OK'}</code>\n` +
        `👤 <b>Cliente:</b> ${result.cliente || 'Cliente'}\n` +
        `📺 <b>Producto:</b> ${result.producto || 'Suscripción Digital'}\n` +
        `💵 <b>Monto:</b> Bs. ${monto.toFixed(2)} ($${Number(result.total_usd || 0).toFixed(2)})\n` +
        `🔢 <b>Referencia:</b> <code>${cleanRef}</code>\n` +
        `✅ <b>Estado:</b> Credenciales liberadas y entregadas en segundos.`;

      // Si el cliente tiene vinculado su Telegram, entregarle sus credenciales de inmediato
      if (result.telegram_chat_id) {
        const clientMsg = `🎉 <b>¡PAGO VERIFICADO CON ÉXITO!</b>\n\n` +
          `Tu compra de <b>${result.producto}</b> ha sido procesada.\n\n` +
          `📱 <b>Datos de acceso:</b>\n` +
          (result.correo_cuenta ? `📧 <b>Correo:</b> <code>${result.correo_cuenta}</code>\n` : '') +
          (result.clave_cuenta ? `🔑 <b>Clave:</b> <code>${result.clave_cuenta}</code>\n` : '') +
          (result.nombre_perfil ? `👤 <b>Perfil:</b> ${result.nombre_perfil}\n` : '') +
          (result.pin_perfil ? `🔒 <b>PIN:</b> <code>${result.pin_perfil}</code>\n` : '') +
          `\n✅ Tus credenciales también están guardadas y disponibles en <b>Mi Portal</b> en nuestra tienda.\n\n¡Gracias por preferirnos!`;

        await notifyCustomerTelegram(result.telegram_chat_id, clientMsg);
      }

      await notifyGregoryTelegram(msg);

      return res.status(200).json({
        ok: true,
        action: 'delivered',
        message: 'Pedido conciliado y entregado automáticamente.',
        data: result
      });
    } else {
      // REGISTRADO EN BUFFER A LA ESPERA DEL CLIENTE
      const msg = `📥 <b>Pago Móvil BDV recibido en buffer:</b>\n\n` +
        `💵 <b>Monto:</b> Bs. ${monto.toFixed(2)}\n` +
        `🔢 <b>Referencia:</b> <code>${cleanRef}</code>\n` +
        `⏳ <i>Guardado en el sistema. En cuanto el cliente pulse Confirmar en la tienda con esta referencia, se liberará al instante.</i>`;

      await notifyGregoryTelegram(msg);

      return res.status(200).json({
        ok: true,
        action: 'buffered',
        message: 'Pago guardado en buffer. Se liberará en cuanto el cliente reporte la referencia.',
        referencia: cleanRef,
        monto_bs: monto
      });
    }

  } catch (err) {
    console.error('Error en conciliar-bdv:', err);
    return res.status(500).json({
      ok: false,
      error: err.message || 'Error interno del servidor'
    });
  }
}
