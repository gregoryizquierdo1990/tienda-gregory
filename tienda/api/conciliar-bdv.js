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

const MILOS_BOT_TOKEN = '9018604803:AAGrRViH6W6Ct2FTP65RqbUga6u0uFZ6gDg';
const GREGORY_CHAT_ID = '1252102820';

// Bot Milos: Notifica a Gregory en su chat personal
async function notifyGregoryTelegram(text) {
  try {
    const token = await getSecret('telegram_bdv_bot_token') || MILOS_BOT_TOKEN;
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

// Bot Milos: Entrega credenciales y avisos a clientes y revendedores
async function notifyCustomerTelegram(chatId, text) {
  if (!chatId) return;
  try {
    const token = await getSecret('telegram_token') || MILOS_BOT_TOKEN;
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
    console.error('Error enviando credenciales a cliente por Bot Milos:', err);
  }
}

// Analizador inteligente de texto de notificación bancaria DUAL (BDV + BNC)
function parseBankNotificationText(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const clean = raw.replace(/\r?\n/g, ' ').trim();

  // ==========================================
  // CASO 1: BANCO DE VENEZUELA (BDV)
  // Ejemplo: "Recibiste un PagomovilBDV por Bs. 10,00 del 0424-2809333 Ref: 063082497655 en fecha 04-11-26 hora: 10:17."
  // ==========================================
  if (/Recibiste un PagomovilBDV|PagomovilBDV recibido/i.test(clean)) {
    const matchMonto = clean.match(/por\s+Bs\.?\s*([\d.]+,\d{2})/i) ||
                       clean.match(/(?:bs\.?s?|bol[ií]vares|monto)\.?\s*[:$]?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2}))/i);
    const matchRef = clean.match(/Ref:\s*(\d+)/i) || clean.match(/\b(\d{6,14})\b/);
    const matchTel = clean.match(/del\s+(04\d{2}-?\d{7})/i) || clean.match(/\b(04\d{9})\b/);
    const matchFecha = clean.match(/fecha\s+(\d{2}[-/]\d{2}[-/]\d{2,4})/i);
    const matchHora = clean.match(/hora:\s*(\d{2}:\d{2})/i);

    if (matchMonto && matchRef) {
      let rawVal = matchMonto[1].replace(/\s/g, '');
      if (rawVal.includes('.') && rawVal.includes(',')) rawVal = rawVal.replace(/\./g, '').replace(',', '.');
      else if (rawVal.includes(',')) rawVal = rawVal.replace(',', '.');

      const val = parseFloat(rawVal);
      const ref = matchRef[1].trim();
      const telefono = matchTel ? matchTel[1].replace(/[^0-9]/g, '') : null;

      return {
        banco: 'BDV',
        ref,
        monto: !isNaN(val) && val > 0 ? Math.round(val * 100) / 100 : null,
        telefono,
        fechaBanco: matchFecha ? matchFecha[1] : null,
        horaBanco: matchHora ? matchHora[1] : null,
        esPagoMovil: true,
        raw: clean
      };
    }
  }

  // ==========================================
  // CASO 2: BANCO NACIONAL DE CRÉDITO (BNC)
  // Ejemplo: "BNC Pago Movil Recibido Bs.1000,00 Telf.0424***9333 Dia:04/11/26-10:26 Ref:906956804 Llamar al..."
  // ==========================================
  if (/BNC Pago Movil Recibido|PAGO MOVIL RECIBIDO/i.test(clean)) {
    const matchMonto = clean.match(/Recibido\s+Bs\.?\s*([\d.]+,\d{2})/i) ||
                       clean.match(/Bs\.?\s*([\d.]+,\d{2})/i);
    const matchRef = clean.match(/Ref:\s*(\d+)/i) || clean.match(/\b(\d{6,14})\b/);
    const matchTel = clean.match(/Telf\.?\s*(04\d{2}\*{3}\d{4})/i) || clean.match(/\b(04\d{2}\*{3}\d{4})\b/);
    const matchFechaHora = clean.match(/Dia:\s*(\d{2}\/\d{2}\/\d{2})-(\d{2}:\d{2})/i);

    if (matchMonto && matchRef) {
      let rawVal = matchMonto[1].replace(/\s/g, '');
      if (rawVal.includes('.') && rawVal.includes(',')) rawVal = rawVal.replace(/\./g, '').replace(',', '.');
      else if (rawVal.includes(',')) rawVal = rawVal.replace(',', '.');

      const val = parseFloat(rawVal);
      const ref = matchRef[1].trim();
      const telefono = matchTel ? matchTel[1] : null;

      return {
        banco: 'BNC',
        ref,
        monto: !isNaN(val) && val > 0 ? Math.round(val * 100) / 100 : null,
        telefono,
        fechaBanco: matchFechaHora ? matchFechaHora[1].replace(/\//g, '-') : null,
        horaBanco: matchFechaHora ? matchFechaHora[2] : null,
        esPagoMovil: true,
        raw: clean
      };
    }
  }

  // ==========================================
  // CASO 3: GENÉRICO / FALLBACK
  // ==========================================
  let monto = null;
  const matchMontoGen = clean.match(/(?:bs\.?s?|bol[ií]vares|monto)\.?\s*[:$]?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2}))/i) ||
                        clean.match(/([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2}))\s*(?:bs\.?s?|bol[ií]vares)/i);
  if (matchMontoGen) {
    let rawVal = matchMontoGen[1].replace(/\s/g, '');
    if (rawVal.includes('.') && rawVal.includes(',')) rawVal = rawVal.replace(/\./g, '').replace(',', '.');
    else if (rawVal.includes(',')) rawVal = rawVal.replace(',', '.');
    const val = parseFloat(rawVal);
    if (!isNaN(val) && val > 0) monto = Math.round(val * 100) / 100;
  }

  let ref = null;
  const matchRefGen = clean.match(/Ref:\s*(\d+)/i) ||
                      clean.match(/(?:ref|referencia|operaci[oó]n|op|nro)\.?\s*[:#-]?\s*(\d{4,14})\b/i) ||
                      clean.match(/\b(\d{6,14})\b/);
  if (matchRefGen) ref = matchRefGen[1].trim();

  return {
    banco: 'PAGO_MOVIL',
    ref,
    monto,
    telefono: null,
    fechaBanco: null,
    horaBanco: null,
    esPagoMovil: false,
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
      service: 'Pago Móvil Auto-Conciliación (BDV + BNC)',
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
    let banco = body.banco || null;
    let rawText = body.notificacion || body.raw || body.texto || body.message?.text || null;
    let parsedInfo = null;

    // Caso 1: Actualización recibida desde Telegram Webhook (@Julian4asistente_bot)
    if (body.message && body.message.text) {
      parsedInfo = parseBankNotificationText(body.message.text);
      if (parsedInfo) {
        if (parsedInfo.ref) ref = parsedInfo.ref;
        if (parsedInfo.monto) monto = parsedInfo.monto;
        if (parsedInfo.telefono) telefono = parsedInfo.telefono;
        if (parsedInfo.banco) banco = parsedInfo.banco;
        rawText = parsedInfo.raw;
      }
    } else if (rawText && (!ref || !monto)) {
      // Caso 2: Se envió el texto de la notificación en "notificacion" o "raw" desde MacroDroid
      parsedInfo = parseBankNotificationText(rawText);
      if (parsedInfo) {
        if (!ref && parsedInfo.ref) ref = parsedInfo.ref;
        if (!monto && parsedInfo.monto) monto = parsedInfo.monto;
        if (!telefono && parsedInfo.telefono) telefono = parsedInfo.telefono;
        if (parsedInfo.banco) banco = parsedInfo.banco;
      }
    }

    if (!banco) banco = 'BDV';

    // MODO CAPTURA: Envía el texto crudo de la notificación al Telegram personal de Gregory para auditoría
    if (rawText && !body.message) {
      await notifyGregoryTelegram(`📲 <b>Notificación ${banco} recibida desde teléfono:</b>\n<code>${rawText}</code>`);
    }

    if (!ref || !monto || isNaN(monto) || monto <= 0) {
      return res.status(200).json({
        ok: true,
        aviso: 'Notificación guardada en log, pero no contiene referencia o monto de Pago Móvil válido.',
        parsed: { banco, ref, monto, telefono, rawText }
      });
    }

    // Limpiar referencia (solo dígitos)
    const cleanRef = String(ref).replace(/[^0-9]/g, '');
    const cleanTel = telefono ? String(telefono).replace(/[^0-9*]/g, '') : null;

    // Llamar a la función RPC de Supabase para hacer match o buffer
    const result = await sbRest('rpc/conciliar_pedido_bdv', {
      method: 'POST',
      body: JSON.stringify({
        p_ref: cleanRef,
        p_monto: monto,
        p_raw: rawText,
        p_telefono: cleanTel,
        p_banco: banco
      })
    });

    if (result?.matched) {
      // MATCH Y LIBERACIÓN INMEDIATA
      const nowStr = new Date().toLocaleString('es-VE', { timeZone: 'America/Caracas' });
      const orderShort = result.order_id ? String(result.order_id).slice(0, 8) : 'OK';
      const cliNom = result.cliente || 'Cliente';
      const cliTel = result.telefono || cleanTel || '';
      const cliRol = result.cliente_rol || (result.es_revendedor ? 'Revendedor Oficial' : 'Cliente Directo');
      const prodNom = result.producto || 'Suscripción Digital';
      const usdVal = Number(result.total_usd || 0).toFixed(2);
      const bsVal = Number(monto).toFixed(2);
      const cEmail = result.correo_cuenta || '';
      const cPass = result.clave_cuenta || '';
      const cProf = result.nombre_perfil || '';
      const cPin = result.pin_perfil || '';
      const bancoNombre = banco === 'BNC' ? 'Banco Nacional de Crédito (0191)' : 'Banco de Venezuela (0102)';
      const fechaHoraBanco = (parsedInfo?.fechaBanco || parsedInfo?.horaBanco)
        ? `${parsedInfo?.fechaBanco || 'Hoy'} ${parsedInfo?.horaBanco || ''}`.trim()
        : nowStr;

      const confirmText = `¡Hola ${cliNom}! 🎉 Confirmamos tu pago de ${prodNom} (${banco} Ref: ${cleanRef}).\n` +
        `Tus credenciales ya están activas:\n` +
        `📧 Correo: ${cEmail}\n🔑 Clave: ${cPass}\n` +
        (cProf ? `👤 Perfil: ${cProf}\n` : '') +
        (cPin ? `🔒 PIN: ${cPin}\n` : '') +
        `¡Que disfrutes tu servicio! ⭐`;

      const msg = `🧾 <b>COMPROBANTE DE CONCILIACIÓN AUTOMÁTICA</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `🆔 <b>Nro. de Orden:</b> <code>#${orderShort}</code>\n` +
        `🏦 <b>Banco Involucrado:</b> <b>${bancoNombre}</b>\n` +
        `🔢 <b>Nro. de Referencia:</b> <code>${cleanRef}</code>\n` +
        `💵 <b>Monto Recibido:</b> <b>Bs. ${bsVal}</b> (<b>$${usdVal} USD</b>)\n` +
        `⏰ <b>Fecha y Hora (Banco):</b> ${fechaHoraBanco}\n` +
        `🛒 <b>Producto / Servicio:</b> <b>${prodNom}</b>\n` +
        `👤 <b>Usuario Involucrado:</b> <b>${cliNom}</b> [<b>${cliRol}</b>]\n` +
        `📱 <b>Teléfono de Origen:</b> <code>${cleanTel || (cliTel ? String(cliTel).replace(/\D/g, '') : 'No detectado')}</code>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `🔑 <b>Credenciales Entregadas:</b>\n` +
        (cEmail ? `📧 <b>Correo:</b> <code>${cEmail}</code>\n` : '') +
        (cPass ? `🔑 <b>Clave:</b> <code>${cPass}</code>\n` : '') +
        (cProf ? `👤 <b>Perfil:</b> <code>${cProf}</code>\n` : '') +
        (cPin ? `🔒 <b>PIN:</b> <code>${cPin}</code>\n` : '') +
        `\n📝 <b>Mensaje listo para copiar:</b>\n` +
        `<code>${confirmText}</code>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `✅ <i>Pago validado por coincidencia (4/6 dígitos en 24h) y liberado de forma segura en la tienda.</i>`;

      // Si el cliente tiene vinculado su Telegram, entregarle sus credenciales de inmediato por Bot Diego
      if (result.telegram_chat_id) {
        const clientMsg = `🎉 <b>¡PAGO VERIFICADO CON ÉXITO (${banco})!</b>\n\n` +
          `Tu compra de <b>${prodNom}</b> ha sido validada y entregada al instante.\n\n` +
          `📱 <b>Datos de acceso activados:</b>\n` +
          (cEmail ? `📧 <b>Correo:</b> <code>${cEmail}</code>\n` : '') +
          (cPass ? `🔑 <b>Clave:</b> <code>${cPass}</code>\n` : '') +
          (cProf ? `👤 <b>Perfil:</b> ${cProf}\n` : '') +
          (cPin ? `🔒 <b>PIN:</b> <code>${cPin}</code>\n` : '') +
          `\n✅ Tus credenciales también quedan respaldadas en <b>Mi Portal</b> en nuestra tienda web.\n\n¡Gracias por preferirnos!`;

        await notifyCustomerTelegram(result.telegram_chat_id, clientMsg);
      }

      await notifyGregoryTelegram(msg);

      return res.status(200).json({
        ok: true,
        action: 'delivered',
        banco,
        message: 'Pedido conciliado y entregado automáticamente.',
        data: result
      });
    } else {
      // REGISTRADO EN BUFFER A LA ESPERA DEL CLIENTE
      const bancoNombre = banco === 'BNC' ? 'Banco Nacional de Crédito (0191)' : 'Banco de Venezuela (0102)';
      const fechaHoraBanco = (parsedInfo?.fechaBanco || parsedInfo?.horaBanco)
        ? `${parsedInfo?.fechaBanco || 'Hoy'} ${parsedInfo?.horaBanco || ''}`.trim()
        : 'Recibido ahora';

      const msg = `📥 <b>PAGO MÓVIL RECIBIDO EN BUFFER (${banco})</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `🏦 <b>Banco Receptor:</b> <b>${bancoNombre}</b>\n` +
        `💵 <b>Monto Recibido:</b> <b>Bs. ${monto.toFixed(2)}</b>\n` +
        `🔢 <b>Referencia:</b> <code>${cleanRef}</code>\n` +
        (cleanTel ? `📱 <b>Teléfono Origen:</b> <code>${cleanTel}</code>\n` : '') +
        `⏰ <b>Fecha/Hora Banco:</b> ${fechaHoraBanco}\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `⏳ <i>Guardado en el sistema (vigencia 24h). En cuanto el cliente confirme su compra con esta referencia, se liberará al instante.</i>`;

      await notifyGregoryTelegram(msg);

      return res.status(200).json({
        ok: true,
        action: 'buffered',
        banco,
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
