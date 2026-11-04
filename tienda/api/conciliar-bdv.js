// Endpoint para conciliación y liberación automática de pedidos por Pago Móvil BDV
// ==============================================================================
// SEPARACIÓN ESTRICTA DE BOTS DE TELEGRAM:
// 1. Bot Diego (Canal Oficial para Clientes y Revendedores):
//    - Único bot que habla con clientes y revendedores, y les entrega credenciales.
// 2. Bot Julián (@Julian4asistente_bot - Privado de Gregory):
//    - Meramente administrativo, exclusivo para Gregory.
//    - Recibe las notificaciones BDV desde MacroDroid y le reporta solo a Gregory.
// ==============================================================================
import { U, K, sbRest, getSecret } from './_lib.js';

const JULIAN_BOT_TOKEN = '8571549759:AAHqPS64PQTyVjMEwecJN937dHzLQd-Et_A'; // Bot Administrativo Privado
const DIEGO_DEFAULT_TOKEN = '8535286680:AAGCbVKMNk_aeDHwyICqsAqbtMUjDXlMOMg'; // Bot Oficial para Clientes
const GREGORY_CHAT_ID = '7154250409';

// Bot Julián: Notifica exclusivamente a Gregory en su chat personal
async function notifyGregoryTelegram(text) {
  try {
    const token = await getSecret('telegram_bdv_bot_token') || JULIAN_BOT_TOKEN;
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
    console.error('Error enviando notificación a Gregory por Bot Julián:', err);
  }
}

// Bot Diego: Entrega credenciales y avisos exclusivamente a clientes y revendedores
async function notifyCustomerTelegram(chatId, text) {
  if (!chatId) return;
  try {
    const token = await getSecret('telegram_token') || DIEGO_DEFAULT_TOKEN;
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
    console.error('Error enviando credenciales a cliente por Bot Diego:', err);
  }
}

// Analizador inteligente de texto de notificación bancaria BDV (Push BDV / SMS / MacroDroid)
function parseBankNotificationText(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const clean = raw.replace(/\r?\n/g, ' ').trim();

  // 1. Verificar si es Pago Móvil recibido (evita alertas informativas, retiros o cargos)
  const esPagoMovil = /Recibiste un PagomovilBDV|PagomovilBDV recibido/i.test(clean);

  // 2. Extraer Monto: soporte exacto BDV "por Bs. 10,00" o "Bs. 1.250,50"
  let monto = null;
  const matchMonto = clean.match(/por\s+Bs\.?\s*([\d.]+,\d{2})/i) ||
                     clean.match(/(?:bs\.?s?|bol[ií]vares|monto)\.?\s*[:$]?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2}))/i) ||
                     clean.match(/([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2}))\s*(?:bs\.?s?|bol[ií]vares)/i);

  if (matchMonto && matchMonto[1]) {
    let rawVal = matchMonto[1].replace(/\s/g, '');
    if (rawVal.includes('.') && rawVal.includes(',')) {
      rawVal = rawVal.replace(/\./g, '').replace(',', '.');
    } else if (rawVal.includes(',')) {
      rawVal = rawVal.replace(',', '.');
    }
    const val = parseFloat(rawVal);
    if (!isNaN(val) && val > 0) {
      monto = Math.round(val * 100) / 100;
    }
  }

  // 3. Extraer Referencia: formato exacto BDV "Ref: 063082497655"
  let ref = null;
  const matchRef = clean.match(/Ref:\s*(\d+)/i) ||
                   clean.match(/(?:ref|referencia|operaci[oó]n|op|nro|transacci[oó]n|recibo)\.?\s*[:#-]?\s*(\d{4,14})\b/i) ||
                   clean.match(/\b(\d{6,14})\b/);

  if (matchRef && matchRef[1]) {
    ref = matchRef[1].trim();
  }

  // 4. Extraer Teléfono del pagador: formato "del 0424-2809333"
  let telefono = null;
  const matchTel = clean.match(/del\s+(04\d{2}-?\d{7})/i) || clean.match(/\b(04\d{9})\b/);
  if (matchTel && matchTel[1]) {
    telefono = matchTel[1].replace(/[^0-9]/g, '');
  }

  // 5. Extraer Fecha y Hora del banco
  const matchFecha = clean.match(/fecha\s+(\d{2}[-/]\d{2}[-/]\d{2,4})/i);
  const matchHora = clean.match(/hora:\s*(\d{2}:\d{2})/i);
  const fechaBanco = matchFecha ? matchFecha[1] : null;
  const horaBanco = matchHora ? matchHora[1] : null;

  return {
    ref,
    monto,
    telefono,
    fechaBanco,
    horaBanco,
    esPagoMovil,
    raw: clean
  };
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
    let telefono = body.telefono || body.telefonoOrigen || null;
    let rawText = body.notificacion || body.raw || body.texto || body.message?.text || null;
    let parsedInfo = null;

    // Caso 1: Actualización recibida desde Telegram Webhook (@Julian4asistente_bot)
    if (body.message && body.message.text) {
      parsedInfo = parseBankNotificationText(body.message.text);
      if (parsedInfo) {
        if (parsedInfo.ref) ref = parsedInfo.ref;
        if (parsedInfo.monto) monto = parsedInfo.monto;
        if (parsedInfo.telefono) telefono = parsedInfo.telefono;
        rawText = parsedInfo.raw;
      }
    } else if (rawText && (!ref || !monto)) {
      // Caso 2: Se envió el texto de la notificación en "notificacion" o "raw" desde MacroDroid
      parsedInfo = parseBankNotificationText(rawText);
      if (parsedInfo) {
        if (!ref && parsedInfo.ref) ref = parsedInfo.ref;
        if (!monto && parsedInfo.monto) monto = parsedInfo.monto;
        if (!telefono && parsedInfo.telefono) telefono = parsedInfo.telefono;
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
        parsed: { ref, monto, telefono, rawText }
      });
    }

    // Limpiar referencia (solo dígitos)
    const cleanRef = String(ref).replace(/[^0-9]/g, '');
    const cleanTel = telefono ? String(telefono).replace(/[^0-9]/g, '') : null;

    // Llamar a la función RPC de Supabase para hacer match o buffer
    const result = await sbRest('rpc/conciliar_pedido_bdv', {
      method: 'POST',
      body: JSON.stringify({
        p_ref: cleanRef,
        p_monto: monto,
        p_raw: rawText,
        p_telefono: cleanTel
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
        (cleanTel ? `📱 <b>Origen:</b> <code>${cleanTel}</code>\n` : '') +
        (parsedInfo?.horaBanco ? `⏰ <b>Hora Banco:</b> ${parsedInfo.horaBanco}\n` : '') +
        `✅ <b>Estado:</b> Credenciales liberadas y entregadas en segundos.`;

      // Si el cliente tiene vinculado su Telegram, entregarle sus credenciales de inmediato por Bot Diego
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
        (cleanTel ? `📱 <b>Origen:</b> <code>${cleanTel}</code>\n` : '') +
        (parsedInfo?.horaBanco ? `⏰ <b>Hora Banco:</b> ${parsedInfo.horaBanco}\n` : '') +
        `⏳ <i>Guardado en el sistema. En cuanto el cliente pulse Confirmar en la tienda con esta referencia, se liberará al instante.</i>`;

      await notifyGregoryTelegram(msg);

      return res.status(200).json({
        ok: true,
        action: 'buffered',
        message: 'Pago guardado en buffer. Se liberará en cuanto el cliente reporte la referencia.',
        referencia: cleanRef,
        telefono_origen: cleanTel,
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
