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
    let ref = body.referencia || body.ref || null;
    let monto = body.monto ? parseFloat(body.monto) : null;
    let rawText = body.raw || body.texto || body.message?.text || null;

    // Caso 1: Actualización recibida desde Telegram Webhook (@Julian4asistente_bot)
    if (body.message && body.message.text) {
      const parsed = parseBankNotificationText(body.message.text);
      if (parsed) {
        if (parsed.ref) ref = parsed.ref;
        if (parsed.monto) monto = parsed.monto;
        rawText = parsed.raw;
      }
    } else if (rawText && (!ref || !monto)) {
      // Caso 2: Se envió un texto sin procesar desde MacroDroid / Tasker
      const parsed = parseBankNotificationText(rawText);
      if (parsed) {
        if (!ref && parsed.ref) ref = parsed.ref;
        if (!monto && parsed.monto) monto = parsed.monto;
      }
    }

    if (!ref || !monto || isNaN(monto) || monto <= 0) {
      return res.status(400).json({
        ok: false,
        error: 'No se pudo extraer la referencia o el monto válido.',
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
