// Webhook de Telegram interactivo y automatizado para @agentemilos_bot
// Vinculado a la tienda de Emprendimiento Gregory Izquierdo
import { sbRest, getSecret, U, K } from './_lib.js';

const GREETING_BASE = 'Hola Mi nombre es Milos Asistente y Orquestador de Emprendimiento Gregory Izquierdo, ¿en qué puedo ayudarte?';
const MILOS_DEFAULT_TOKEN = '9018604803:AAGrRViH6W6Ct2FTP65RqbUga6u0uFZ6gDg';

// Teclado interactivo para Clientes finales (Bot Público)
const CLIENT_KEYBOARD = [
  [{ text: '🛍️ Catálogo Tienda' }, { text: '💱 Tasa BCV Actual' }],
  [{ text: '💳 Métodos de Pago' }, { text: '📊 Cuotas & Financiamiento' }],
  [{ text: '📅 Calendario Vencimientos' }, { text: '📦 Historial de Compras' }],
  [{ text: '💰 Mi Saldo Zeny' }, { text: '📞 Soporte Técnico' }],
  [{ text: '🚪 Cerrar Sesión' }]
];

// Teclado interactivo para Revendedores Autorizados (B2B)
const RESELLER_KEYBOARD = [
  [{ text: '📦 Catálogo Mayorista' }, { text: '💱 Tasa BCV & Pagos' }],
  [{ text: '📈 Cuotas & Línea Crédito' }, { text: '📅 Vencimientos Clientes' }],
  [{ text: '👥 Mi Red de Clientes' }, { text: '📦 Historial de Pedidos' }],
  [{ text: '💰 Mi Saldo Zeny' }, { text: '📞 Soporte Prioritario' }],
  [{ text: '🚪 Cerrar Sesión' }]
];

function getCustomerKeyboard(cust) {
  return cust?.es_revendedor === true ? RESELLER_KEYBOARD : CLIENT_KEYBOARD;
}

function escHtml(str) {
  return String(str ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

async function sendTelegram(token, chatId, text, keyboard = null, removeKeyboard = false) {
  const payload = {
    chat_id: chatId,
    text: text,
    parse_mode: 'HTML',
    disable_web_page_preview: true
  };
  if (keyboard) {
    payload.reply_markup = {
      keyboard: keyboard,
      resize_keyboard: true,
      is_persistent: true
    };
  } else if (removeKeyboard) {
    payload.reply_markup = {
      remove_keyboard: true
    };
  }
  const r = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  if (!r.ok) {
    // Si Telegram rechaza el formato HTML, enviar como texto plano limpio
    const fallbackText = text.replace(/<[^>]+>/g, '');
    delete payload.parse_mode;
    payload.text = fallbackText;
    await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    }).catch(() => {});
  }
}

async function deleteTelegramMessage(token, chatId, messageId) {
  if (!messageId) return;
  await fetch(`https://api.telegram.org/bot${token}/deleteMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, message_id: messageId })
  }).catch(() => {});
}

async function getBcvRate() {
  const rate = await sbRest('exchange_rates?select=bs_por_usd,fecha&order=fecha.desc&limit=1');
  return {
    rate: Number(rate?.[0]?.bs_por_usd || 0),
    fecha: rate?.[0]?.fecha || 'Hoy'
  };
}

async function findCustomerByIdentifier(raw) {
  const clean = (raw || '').trim();
  if (!clean) return null;

  // 1. Búsqueda por Email exacto (insensible a mayúsculas)
  const byEmail = await sbRest(`customers?email=ilike.${encodeURIComponent(clean)}&limit=1`);
  if (byEmail?.[0]) return byEmail[0];

  // 2. Búsqueda por Código de Identificación (ej: CLT-008, RVD:1001, etc.)
  const byCode = await sbRest(`customers?codigo_identificacion=ilike.${encodeURIComponent(clean)}&limit=1`);
  if (byCode?.[0]) return byCode[0];

  const altCode = clean.includes('-') ? clean.replace(/-/g, ':') : (clean.includes(':') ? clean.replace(/:/g, '-') : null);
  if (altCode) {
    const byAltCode = await sbRest(`customers?codigo_identificacion=ilike.${encodeURIComponent(altCode)}&limit=1`);
    if (byAltCode?.[0]) return byAltCode[0];
  }

  // 3. Búsqueda por Teléfono o cuenta virtual telefónica
  const digits = clean.replace(/\D/g, '');
  if (digits.length >= 7) {
    const byPhone = await sbRest(`customers?telefono=ilike.%25${digits.slice(-7)}%25&limit=1`);
    if (byPhone?.[0]) return byPhone[0];

    const virtualEmail = `${digits}@cliente.gregoryizquierdo.xyz`;
    const byVE = await sbRest(`customers?email=eq.${encodeURIComponent(virtualEmail)}&limit=1`);
    if (byVE?.[0]) return byVE[0];
  }

  return null;
}

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(200).send('ok');

  const sec = await getSecret('telegram_webhook_secret');
  if (sec && req.headers['x-telegram-bot-api-secret-token'] !== sec) {
    return res.status(401).end();
  }

  const isCallback = !!req.body?.callback_query;
  const cb = req.body?.callback_query;
  const msg = cb ? cb.message : req.body?.message;
  if (!msg?.chat?.id) return res.status(200).end();

  const chatId = msg.chat.id;
  const fromId = (cb ? cb.from?.id : msg.from?.id) || chatId;
  const username = (cb ? cb.from?.username : msg.from?.username) ? `@${cb ? cb.from.username : msg.from.username}` : null;
  const rawText = (cb ? (cb.data || '') : (msg.text || '')).trim();
  const lowerText = rawText.toLowerCase();

  const token = (await getSecret('telegram_token')) || MILOS_DEFAULT_TOKEN;

  if (isCallback && cb?.id) {
    await fetch(`https://api.telegram.org/bot${token}/answerCallbackQuery`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ callback_query_id: cb.id })
    }).catch(() => {});
  }

  try {

  // 1. Obtener o resolver la sesión actual del chat
  let sessions = await sbRest(`telegram_sessions?chat_id=eq.${chatId}&limit=1`);
  let session = sessions?.[0] || null;

  // Si no hay sesión en tabla telegram_sessions, buscar si el cliente ya tenía su telegram_chat_id vinculado
  if (!session) {
    const custByChat = await sbRest(`customers?telegram_chat_id=eq.${chatId}&limit=1`);
    if (custByChat?.[0]) {
      const newSession = {
        chat_id: chatId,
        telegram_user_id: fromId,
        telegram_username: username,
        customer_id: custByChat[0].id,
        step: 'authenticated',
        updated_at: new Date().toISOString()
      };
      await sbRest('telegram_sessions', {
        method: 'POST',
        headers: { Prefer: 'resolution=merge-duplicates' },
        body: JSON.stringify(newSession)
      });
      session = newSession;
    }
  }

  // 2. Manejo de Deep Link de 1 Clic desde el Portal: /start auth_<token>
  if (lowerText.startsWith('/start auth_') || lowerText.startsWith('/start link_')) {
    const authToken = rawText.replace(/^\/start\s+/i, '').trim();
    const tokenSession = await sbRest(`telegram_sessions?auth_token=eq.${encodeURIComponent(authToken)}&limit=1`);
    if (tokenSession?.[0] && tokenSession[0].customer_id) {
      const cust = (await sbRest(`customers?id=eq.${tokenSession[0].customer_id}&limit=1`))?.[0];
      if (cust) {
        // Asociar este chat_id a la sesión y al cliente
        await sbRest(`telegram_sessions?auth_token=eq.${encodeURIComponent(authToken)}`, {
          method: 'PATCH',
          body: JSON.stringify({
            chat_id: chatId,
            telegram_user_id: fromId,
            telegram_username: username,
            step: 'authenticated',
            auth_token: null,
            updated_at: new Date().toISOString()
          })
        });
        await sbRest(`customers?id=eq.${cust.id}`, {
          method: 'PATCH',
          body: JSON.stringify({
            telegram_chat_id: chatId,
            telegram_username: username
          })
        });

        const isRev = cust.es_revendedor === true;
        const keyboard = getCustomerKeyboard(cust);
        const welcomeLinked = `${GREETING_BASE}\n\n` +
          `✅ <b>¡Tu cuenta ha sido vinculada exitosamente!</b>\n` +
          `Bienvenido/a <b>${escHtml(cust.nombre)}</b> (ID: <code>${escHtml(cust.codigo_identificacion || (isRev ? 'RVD:1001' : 'CLT'))}</code>).\n\n` +
          (isRev
            ? `🏢 <b>Panel Oficial de Revendedor Activo:</b> Tienes acceso a precios mayoristas, calendario de clientes y línea de crédito comercial.`
            : `Ahora tienes acceso instantáneo a tus membresías activas, PINs, saldos en Wallet Zeny y cuotas pendientes desde este chat.`
          );
        await sendTelegram(token, chatId, welcomeLinked, keyboard);
        return res.status(200).end();
      }
    }
  }

  // 3. Manejo del comando /start
  if (lowerText === '/start' || lowerText.startsWith('/start ')) {
    if (session?.customer_id && session?.step === 'authenticated') {
      const cust = (await sbRest(`customers?id=eq.${session.customer_id}&limit=1`))?.[0];
      if (cust) {
        const isRev = cust.es_revendedor === true;
        const keyboard = getCustomerKeyboard(cust);
        const welcomeBack = `${GREETING_BASE}\n\n` +
          `👋 ¡Hola de nuevo, <b>${escHtml(cust.nombre)}</b>!\n` +
          (isRev
            ? `🏢 <b>Panel Oficial de Revendedor</b> (ID: <code>${escHtml(cust.codigo_identificacion || 'RVD')}</code>).\n` +
              `Tienes activo tu catálogo de mayorista, control de cartera de clientes y línea de crédito.`
            : `Tu cuenta de cliente está conectada y sincronizada con la tienda.`
          ) +
          `\n\n¿Qué deseas consultar hoy? Elige una opción del menú 👇`;
        await sendTelegram(token, chatId, welcomeBack, keyboard);
        return res.status(200).end();
      }
    }

    // Cliente NO autenticado: Solicitar identificación
    await sbRest('telegram_sessions', {
      method: 'POST',
      headers: { Prefer: 'resolution=merge-duplicates' },
      body: JSON.stringify({
        chat_id: chatId,
        telegram_user_id: fromId,
        telegram_username: username,
        step: 'waiting_identifier',
        temp_identifier: null,
        updated_at: new Date().toISOString()
      })
    });

    const askIdentifier = `${GREETING_BASE}\n\n` +
      `🔐 <b>Para acceder a tus servicios, saldos y catálogo personalizado:</b>\n` +
      `Por favor escribe tu <b>Correo electrónico</b>, <b>Código ID</b> (ej: <code>CLT-008</code> o <code>RVD:1001</code>) o tu <b>Número de WhatsApp</b> registrado en la tienda:`;
    await sendTelegram(token, chatId, askIdentifier, null, true);
    return res.status(200).end();
  }

  // 4. Cancelar operación en curso
  if (lowerText === '/cancelar' || lowerText === '/cancel') {
    if (session && session.step !== 'authenticated') {
      await sbRest(`telegram_sessions?chat_id=eq.${chatId}`, {
        method: 'PATCH',
        body: JSON.stringify({ step: 'unauthenticated', temp_identifier: null, updated_at: new Date().toISOString() })
      });
      await sendTelegram(token, chatId, 'Operación cancelada. Puedes presionar /start cuando desees identificarte.', null, true);
      return res.status(200).end();
    }
  }

  // 5. Flujo de Login - Paso: Esperando Identificador (Email, Código ID o Teléfono)
  if (session?.step === 'waiting_identifier') {
    const cust = await findCustomerByIdentifier(rawText);
    if (!cust) {
      const notFound = `❌ No encontramos ninguna cuenta registrada con: <b>${escHtml(rawText)}</b>\n\n` +
        `Por favor verifica tu correo, código ID o WhatsApp e inténtalo nuevamente.\n` +
        `<i>(También puedes escribir /cancelar para salir)</i>`;
      await sendTelegram(token, chatId, notFound);
      return res.status(200).end();
    }

    await sbRest(`telegram_sessions?chat_id=eq.${chatId}`, {
      method: 'PATCH',
      body: JSON.stringify({
        customer_id: cust.id,
        temp_identifier: cust.email || rawText,
        step: 'waiting_password',
        updated_at: new Date().toISOString()
      })
    });

    const askPassword = `👤 Cuenta localizada: <b>${escHtml(cust.nombre)}</b> (ID: <code>${escHtml(cust.codigo_identificacion || 'CLT')}</code>)\n\n` +
      `🔑 <b>Por favor ingresa tu contraseña de acceso a la tienda:</b>\n\n` +
      `🛡️ <i>(Por tu seguridad, tu mensaje con la clave se borrará de inmediato de este chat de Telegram)</i>`;
    await sendTelegram(token, chatId, askPassword);
    return res.status(200).end();
  }

  // 6. Flujo de Login - Paso: Esperando Contraseña
  if (session?.step === 'waiting_password') {
    // Borrado inmediato del mensaje que contiene la clave
    await deleteTelegramMessage(token, chatId, msg.message_id);

    const cust = (await sbRest(`customers?id=eq.${session.customer_id}&limit=1`))?.[0];
    if (!cust) {
      await sbRest(`telegram_sessions?chat_id=eq.${chatId}`, {
        method: 'PATCH',
        body: JSON.stringify({ step: 'waiting_identifier', temp_identifier: null })
      });
      await sendTelegram(token, chatId, '⚠️ No se pudo cargar tu cuenta. Por favor escribe /start nuevamente.');
      return res.status(200).end();
    }

    const enteredPassword = rawText;
    let authSuccess = false;

    // Probar login con Supabase Auth usando el correo registrado
    if (cust.email) {
      try {
        const authRes = await fetch(`${U}/auth/v1/token?grant_type=password`, {
          method: 'POST',
          headers: { apikey: K, 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: cust.email.toLowerCase(), password: enteredPassword })
        });
        if (authRes.ok) authSuccess = true;
      } catch (err) {
        console.error('Error al autenticar en Supabase:', err);
      }
    }

    // Si falló y tiene teléfono, probar con las variantes de correo virtual
    if (!authSuccess && cust.telefono) {
      const cleanDigits = cust.telefono.replace(/\D/g, '');
      const candidates = [
        `${cleanDigits}@cliente.gregoryizquierdo.xyz`,
        cleanDigits.startsWith('58') ? `0${cleanDigits.slice(2)}@cliente.gregoryizquierdo.xyz` : `58${cleanDigits}@cliente.gregoryizquierdo.xyz`
      ];
      for (const altEmail of candidates) {
        try {
          const authRes = await fetch(`${U}/auth/v1/token?grant_type=password`, {
            method: 'POST',
            headers: { apikey: K, 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: altEmail, password: enteredPassword })
          });
          if (authRes.ok) {
            authSuccess = true;
            break;
          }
        } catch {}
      }
    }

    if (authSuccess) {
      // Guardar sesión activa y vincular chat_id en customers
      await sbRest(`telegram_sessions?chat_id=eq.${chatId}`, {
        method: 'PATCH',
        body: JSON.stringify({
          step: 'authenticated',
          temp_identifier: null,
          updated_at: new Date().toISOString()
        })
      });
      await sbRest(`customers?id=eq.${cust.id}`, {
        method: 'PATCH',
        body: JSON.stringify({
          telegram_chat_id: chatId,
          telegram_username: username
        })
      });

      const isRev = cust.es_revendedor === true;
      const isDemo = cust.es_demo === true;
      const keyboard = getCustomerKeyboard(cust);

      const successMsg = `✅ <b>¡Inicio de sesión exitoso!</b>\n` +
        `Bienvenido/a <b>${escHtml(cust.nombre)}</b> al Asistente Interactivo Bot Milos.` +
        (isRev ? `\n\n🏢 <b>Acceso de Revendedor Autorizado:</b> Dispones de catálogo mayorista, gestión de tus clientes y línea de crédito aprobada.` : '') +
        (isDemo ? `\n\n🔒 <b>Modo Demostración Activo:</b> Cuenta habilitada para pruebas y visualización.` : '') +
        `\n\n¿Qué deseas consultar? Elige una opción abajo 👇`;
      await sendTelegram(token, chatId, successMsg, keyboard);
      return res.status(200).end();
    } else {
      const failMsg = `❌ <b>Contraseña incorrecta para ${escHtml(cust.nombre)}.</b>\n\n` +
        `Por favor, escribe tu contraseña nuevamente o escribe /cancelar para reiniciar el proceso.\n` +
        `<i>(Tu mensaje anterior fue borrado por seguridad)</i>`;
      await sendTelegram(token, chatId, failMsg);
      return res.status(200).end();
    }
  }

  // 7. Acciones Públicas (disponibles incluso sin estar logueado)
  const isTasa = lowerText.includes('tasa') || lowerText.includes('bcv') || lowerText.includes('dolar') || lowerText === '/tasa';
  if (isTasa) {
    const { rate, fecha } = await getBcvRate();
    const rateText = `💵 <b>Tasa Oficial Banco Central de Venezuela (BCV):</b>\n\n` +
      `<b>1 USD = ${rate.toFixed(4)} Bs</b>\n` +
      `📅 <i>Fecha: ${escHtml(fecha)}</i>\n\n` +
      `<i>Esta es la tasa oficial aplicada a todas las compras, recargas y cuotas de la tienda.</i>`;
    const cust = session?.customer_id ? (await sbRest(`customers?id=eq.${session.customer_id}&limit=1`))?.[0] : null;
    await sendTelegram(token, chatId, rateText, session?.step === 'authenticated' ? getCustomerKeyboard(cust) : null);
    return res.status(200).end();
  }

  const isTienda = lowerText.includes('tienda') || lowerText.includes('catálogo tienda') || lowerText.includes('catalogo tienda') || lowerText.includes('comprar') || lowerText === '/tienda';
  if (isTienda) {
    const storeText = `🛒 <b>Catálogo Oficial de la Tienda Gregory Izquierdo:</b>\n\n` +
      `Explora nuestras membresías de streaming, combos en promoción, servicios bajo pedido y gaming:\n\n` +
      `🌐 <b>Tienda Online:</b> <a href="https://www.gregoryizquierdo.xyz">https://www.gregoryizquierdo.xyz</a>\n` +
      `⚡ Entregas automatizadas e inmediatas 24/7 con Pago Móvil BDV y BNC.`;
    const cust = session?.customer_id ? (await sbRest(`customers?id=eq.${session.customer_id}&limit=1`))?.[0] : null;
    await sendTelegram(token, chatId, storeText, session?.step === 'authenticated' ? getCustomerKeyboard(cust) : null);
    return res.status(200).end();
  }

  // Métodos de Pago Oficiales (BDV, BNC, Binance)
  const isMetodosPago = lowerText.includes('métodos de pago') || lowerText.includes('metodos de pago') ||
    lowerText.includes('formas de pago') || lowerText.includes('pago movil') || lowerText.includes('pago móvil') ||
    lowerText.includes('donde pagar') || lowerText.includes('datos de pago') || lowerText === '/pagos';
  if (isMetodosPago) {
    const pagosText = `💳 <b>MÉTODOS OFICIALES DE PAGO:</b>\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `⚡ <b>1. Pago Móvil BDV (0102) [Auto-Conciliación 24/7]</b>\n` +
      `• Banco: <b>Banco de Venezuela (0102)</b>\n` +
      `• Teléfono: <code>04242809333</code>\n` +
      `• Cédula: <code>V-18931731</code>\n` +
      `• Titular: Gregory Izquierdo\n\n` +
      `⚡ <b>2. Pago Móvil BNC (0191) [Auto-Conciliación 24/7]</b>\n` +
      `• Banco: <b>Banco Nacional de Crédito (0191)</b>\n` +
      `• Teléfono: <code>04242809333</code>\n` +
      `• Cédula: <code>V-18931731</code>\n` +
      `• Titular: Gregory Izquierdo\n\n` +
      `🟡 <b>3. Binance Pay (USDT)</b>\n` +
      `• Pay ID: <code>393089335</code>\n` +
      `• Correo: <code>gregoryrodriguez2021@gmail.com</code>\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `💡 <i>Toca sobre cualquier dato para copiarlo en tu portapapeles. Al pagar por BDV o BNC, el sistema concilia tu referencia y entrega tus credenciales de forma 100% automatizada.</i>`;
    const cust = session?.customer_id ? (await sbRest(`customers?id=eq.${session.customer_id}&limit=1`))?.[0] : null;
    await sendTelegram(token, chatId, pagosText, session?.step === 'authenticated' ? getCustomerKeyboard(cust) : null);
    return res.status(200).end();
  }

  const isSoporte = lowerText.includes('soporte') || lowerText.includes('ayuda') || lowerText.includes('contacto') ||
    lowerText.includes('asesor') || lowerText.includes('whatsapp') || lowerText === '/soporte';
  if (isSoporte) {
    const neg = (await sbRest('settings?key=eq.negocio&select=value'))?.[0]?.value || {};
    const tel = (neg.telefono || '+584242809333').replace(/\D/g, '');
    const sopText = `💬 <b>Atención Directa y Soporte con Gregory:</b>\n\n` +
      `¿Tienes consultas con una membresía, recarga o gestión comercial?\n\n` +
      `📲 <b>WhatsApp Directo:</b> <a href="https://wa.me/${tel}">Escribir por WhatsApp a Gregory</a>\n` +
      `📧 <b>Correo:</b> ${escHtml(neg.correo || 'emprendimientogregoryizquierdo@gmail.com')}\n\n` +
      `¡Estamos siempre a tu orden para ayudarte!`;
    const cust = session?.customer_id ? (await sbRest(`customers?id=eq.${session.customer_id}&limit=1`))?.[0] : null;
    await sendTelegram(token, chatId, sopText, session?.step === 'authenticated' ? getCustomerKeyboard(cust) : null);
    return res.status(200).end();
  }

  // 8. Si no está autenticado y pide información personal:
  if (session?.step !== 'authenticated' || !session?.customer_id) {
    const isPrivateQuery = lowerText.includes('servicio') || lowerText.includes('membresia') || lowerText.includes('pantalla') ||
      lowerText.includes('saldo') || lowerText.includes('zeny') || lowerText.includes('wallet') ||
      lowerText.includes('deuda') || lowerText.includes('credito') || lowerText.includes('cuota') ||
      lowerText.includes('cliente') || lowerText.includes('revendedor');

    if (isPrivateQuery) {
      const reqLoginMsg = `🔐 <b>Acceso a Información Personal</b>\n\n` +
        `Para consultar tus servicios activos, saldos o cartera, primero debes iniciar sesión.\n\n` +
        `Escribe <b>/start</b> para identificarte con tu correo, teléfono o ID de cliente/revendedor.`;
      await sendTelegram(token, chatId, reqLoginMsg);
      return res.status(200).end();
    }

    // Verificar si coincide con algún bot_command personalizado del admin
    const cmds = await sbRest('bot_commands?activo=eq.true&order=orden');
    const hit = cmds?.find(c => c.trigger.toLowerCase() === lowerText.split('@')[0]) ||
                cmds?.find(c => !c.trigger.startsWith('/') && c.trigger !== '*' && lowerText.includes(c.trigger.toLowerCase())) ||
                cmds?.find(c => c.trigger === '*');
    if (hit) {
      const { rate } = await getBcvRate();
      const neg = (await sbRest('settings?key=eq.negocio&select=value'))?.[0]?.value || {};
      const reply = hit.response
        .replaceAll('{tasa}', rate.toFixed(4))
        .replaceAll('{telefono}', neg.telefono || '')
        .replaceAll('{correo}', neg.correo || '');
      await sendTelegram(token, chatId, escHtml(reply));
      return res.status(200).end();
    }

    await sendTelegram(token, chatId, `${GREETING_BASE}\n\nEscribe <b>/start</b> para iniciar sesión con tu cuenta de la tienda o <b>/soporte</b> si requieres asistencia.`);
    return res.status(200).end();
  }

  // 9. CLIENTE / REVENDEDOR AUTENTICADO: Consultas personalizadas
  const customerId = session.customer_id;
  const cust = (await sbRest(`customers?id=eq.${customerId}&limit=1`))?.[0];
  if (!cust) {
    await sbRest(`telegram_sessions?chat_id=eq.${chatId}`, {
      method: 'PATCH',
      body: JSON.stringify({ step: 'unauthenticated', customer_id: null })
    });
    await sendTelegram(token, chatId, '⚠️ No se encontró la sesión del cliente. Por favor escribe /start para iniciar sesión.');
    return res.status(200).end();
  }

  const isReseller = cust.es_revendedor === true;
  const userKeyboard = getCustomerKeyboard(cust);

  // =========================================================================
  // SECCIÓN REVENDEDOR 1: 👥 Mis Clientes & Suscripciones
  // =========================================================================
  const isRevClientes = lowerText.includes('mis clientes') || lowerText.includes('cartera') ||
    lowerText.includes('suscripciones') || lowerText === '/clientes';

  if (isReseller && isRevClientes) {
    const myProfiles = await sbRest(
      `profiles_inventory?or=(vendedor_id.eq.${customerId},vendedor.ilike.%25${encodeURIComponent(cust.nombre)}%25)&estado=eq.vendido&order=vence.asc&limit=30`
    );

    if (!myProfiles || myProfiles.length === 0) {
      const emptyMsg = `👥 <b>Cartera de Clientes & Suscripciones:</b>\n\n` +
        `Actualmente no tienes clientes o pantallas asignadas en tu cartera de revendedor.\n\n` +
        `💡 <i>Puedes activar suscripciones al mayor para tus clientes directamente desde la tienda o reportando tu pedido a Gregory.</i>`;
      await sendTelegram(token, chatId, emptyMsg, userKeyboard);
      return res.status(200).end();
    }

    const hoyIso = new Date().toISOString().slice(0, 10);
    const lines = myProfiles.map((p, idx) => {
      const cliNom = p.cliente_final || 'Cliente Final';
      const tel = p.cliente_telefono ? String(p.cliente_telefono).replace(/\D/g, '') : '';
      const srvNom = p.nombre_perfil || 'Perfil Digital';
      const vence = p.vence || 'N/D';

      let diasRest = null;
      let badge = '';
      if (p.vence) {
        const msDiff = new Date(p.vence).getTime() - new Date(hoyIso).getTime();
        diasRest = Math.ceil(msDiff / 864e5);
        if (diasRest > 1) badge = `⏱ Vence en ${diasRest} días (${vence})`;
        else if (diasRest === 1) badge = `⚠️ Vence mañana (${vence})`;
        else if (diasRest === 0) badge = `🔴 ¡Vence hoy! (${vence})`;
        else badge = `⛔ Vencido (${vence})`;
      }

      let waLink = '';
      if (tel) {
        const full = tel.startsWith('58') ? tel : (tel.startsWith('0') ? '58' + tel.slice(1) : '58' + tel);
        waLink = ` · <a href="https://wa.me/${full}">WhatsApp</a>`;
      }

      return `<b>${idx + 1}. ${escHtml(cliNom)}</b> (${escHtml(srvNom)})\n` +
        `   📅 ${badge}\n` +
        (tel ? `   📱 Teléfono: <code>${tel}</code>${waLink}\n` : '');
    }).join('\n');

    const msgOut = `👥 <b>Tu Cartera de Clientes (${myProfiles.length} Activos):</b>\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `${lines}\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `💡 <i>Toca sobre los números para copiar o comunícate directamente con tus clientes para gestionar renovaciones.</i>`;
    await sendTelegram(token, chatId, msgOut, userKeyboard);
    return res.status(200).end();
  }

  // =========================================================================
  // SECCIÓN REVENDEDOR 2: 📦 Catálogo Revendedor (Precios Mayoristas)
  // =========================================================================
  const isRevCatalogo = lowerText.includes('catálogo revendedor') || lowerText.includes('catalogo revendedor') ||
    lowerText.includes('mayorista') || lowerText.includes('precios revendedor') || lowerText === '/mayorista';

  if (isReseller && isRevCatalogo) {
    const products = await sbRest('products?activo=eq.true&precio_revendedor_usd=gt.0&order=nombre.asc');
    if (!products || products.length === 0) {
      await sendTelegram(token, chatId, '📦 No hay productos con lista mayorista cargada en este momento.', userKeyboard);
      return res.status(200).end();
    }

    const { rate } = await getBcvRate();
    const items = products.map((pr, idx) => {
      const pMayor = Number(pr.precio_revendedor_usd || 0).toFixed(2);
      const pPub = Number(pr.precio_usd || 0).toFixed(2);
      const margen = (Number(pr.precio_usd || 0) - Number(pr.precio_revendedor_usd || 0)).toFixed(2);
      const bsMayor = (Number(pr.precio_revendedor_usd || 0) * rate).toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

      return `<b>${idx + 1}. ${escHtml(pr.nombre)}</b>\n` +
        `   💵 Mayorista: <b>$${pMayor} USD</b> (Bs. ${bsMayor})\n` +
        `   🏷️ PVP Sugerido: $${pPub} USD · Margen: <b>+$${margen} USD</b>`;
    }).join('\n\n');

    const msgOut = `📦 <b>Catálogo Oficial de Revendedores (Precios al Mayor):</b>\n` +
      `📊 <i>Tasa BCV aplicable: ${rate.toFixed(4)} Bs/USD</i>\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n` +
      `${items}\n\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `⚡ <i>Para activar cuentas o perfiles al instante a precio mayorista, inicia sesión en la tienda con tu ID de revendedor.</i>`;
    await sendTelegram(token, chatId, msgOut, userKeyboard);
    return res.status(200).end();
  }

  // =========================================================================
  // SECCIÓN CLIENTE 1: 📦 Mis Servicios Activos (Credenciales y PINs)
  // =========================================================================
  const isServicios = lowerText.includes('mis servicios') || lowerText.includes('servicio') ||
    lowerText.includes('membresia') || lowerText.includes('pantalla') || lowerText.includes('pin') ||
    lowerText.includes('clave') || lowerText.includes('cuenta') || lowerText === '/servicios';

  if (isServicios) {
    const items = await sbRest('rpc/bot_get_customer_credentials', {
      method: 'POST',
      body: JSON.stringify({ p_customer_id: customerId })
    });

    if (!items || items.length === 0) {
      const noSrvMsg = `📦 <b>Membresías & Servicios Activos:</b>\n\n` +
        `Actualmente no posees servicios o pantallas activas a tu nombre.\n\n` +
        `Puedes adquirir cuentas y perfiles en nuestra tienda:\n` +
        `🌐 <a href="https://www.gregoryizquierdo.xyz">https://www.gregoryizquierdo.xyz</a>`;
      await sendTelegram(token, chatId, noSrvMsg, userKeyboard);
      return res.status(200).end();
    }

    const srvLines = items.map((it, idx) => {
      let diasBadge = '';
      if (it.dias_restantes > 1) diasBadge = `⏱ Vence en ${it.dias_restantes} días (${it.vence})`;
      else if (it.dias_restantes === 1) diasBadge = `⚠️ Vence mañana (${it.vence})`;
      else if (it.dias_restantes === 0) diasBadge = `🔴 ¡Vence hoy! (${it.vence})`;
      else diasBadge = `⏳ Vence: ${it.vence || 'N/D'}`;

      let extraRecarga = '';
      if (it.datos_recarga && Object.keys(it.datos_recarga).length > 0) {
        extraRecarga = `\n   📝 <b>Activación:</b> <code>${escHtml(JSON.stringify(it.datos_recarga))}</code>`;
      }

      return `<b>${idx + 1}. ${escHtml(it.servicio)}</b> (${escHtml(it.tipo || 'Servicio')})\n` +
        `   📧 <b>Usuario:</b> <code>${escHtml(it.correo || 'Pendiente')}</code>\n` +
        `   🔑 <b>Clave:</b> <code>${escHtml(it.clave || 'Pendiente')}</code>\n` +
        (it.perfil ? `   👤 <b>Perfil:</b> ${escHtml(it.perfil)}\n` : '') +
        (it.pin ? `   🔒 <b>PIN:</b> <code>${escHtml(it.pin)}</code>\n` : '') +
        `   ${diasBadge}${extraRecarga}`;
    }).join('\n\n');

    const srvMsg = `📦 <b>Tus Servicios & Membresías Activas (${items.length}):</b>\n\n` +
      `${srvLines}\n\n` +
      `💡 <i>Toca sobre cualquier usuario o PIN para copiarlo directamente en tu teléfono.</i>`;
    await sendTelegram(token, chatId, srvMsg, userKeyboard);
    return res.status(200).end();
  }

  // =========================================================================
  // SECCIÓN CLIENTE 2: 📅 Mis Cuotas Pendientes (Desglose individual)
  // =========================================================================
  const isMisCuotas = lowerText.includes('mis cuotas') || lowerText.includes('cuotas pendientes') || lowerText === '/cuotas';
  if (isMisCuotas) {
    const { rate } = await getBcvRate();
    const cuotas = await sbRest(`installments?customer_id=eq.${customerId}&estado=in.(pendiente,en_revision,vencida)&order=fecha_vencimiento.asc&select=id,numero_cuota,total_cuotas,monto_usd,fecha_vencimiento,estado,orders(products(nombre))`);

    if (!cuotas || cuotas.length === 0) {
      const okMsg = `✨ <b>¡Estás 100% al día con tus pagos!</b>\n\n` +
        `No tienes ninguna cuota pendiente o vencida en este momento.\n` +
        `¡Gracias por tu excelente puntualidad! 🌟`;
      await sendTelegram(token, chatId, okMsg, userKeyboard);
      return res.status(200).end();
    }

    const lines = cuotas.map((c, i) => {
      const mUsd = Number(c.monto_usd || 0).toFixed(2);
      const mBs = (Number(c.monto_usd || 0) * rate).toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      const prod = c.orders?.products?.nombre || 'Servicio Digital';
      const isVencida = c.estado === 'vencida';
      const badge = isVencida ? '🔴 VENCIDA' : '🟡 POR PAGAR';

      return `${i + 1}. <b>${escHtml(prod)}</b> [${badge}]\n` +
        `   💳 Cuota: <b>#${c.numero_cuota} de ${c.total_cuotas}</b>\n` +
        `   💵 Monto: <b>$${mUsd} USD</b> (Bs. ${mBs})\n` +
        `   📅 Vencimiento: <code>${escHtml(c.fecha_vencimiento)}</code>`;
    }).join('\n\n');

    const msgOut = `📅 <b>Tus Cuotas Pendientes de Pago (${cuotas.length}):</b>\n` +
      `📊 <i>Tasa BCV del día: ${rate.toFixed(4)} Bs/USD</i>\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n` +
      `${lines}\n\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `💡 <i>Puedes saldar tus cuotas por Pago Móvil BDV / BNC o directamente desde el portal web.</i>`;
    await sendTelegram(token, chatId, msgOut, userKeyboard);
    return res.status(200).end();
  }

  // =========================================================================
  // SECCIÓN COMPARTIDA: 💰 Mi Saldo Zeny
  // =========================================================================
  const isSaldo = lowerText.includes('saldo') || lowerText.includes('zeny') ||
    lowerText.includes('wallet') || lowerText.includes('billetera') || lowerText.includes('puntos') || lowerText === '/saldo';

  if (isSaldo) {
    const { rate } = await getBcvRate();
    const zeny = Number(cust.zeny_balance || 0);
    const bsEquiv = zeny * rate;

    const saldoMsg = `💰 <b>Tu Saldo en Wallet (ZenyPoints):</b>\n\n` +
      `💵 <b>Balance:</b> <code>$${zeny.toFixed(2)} USD</code> (${zeny.toFixed(2)} ZP)\n` +
      `🇻🇪 <b>Equivalente en Bs:</b> <code>${bsEquiv.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs</code>\n` +
      `📊 <b>Tasa BCV del día:</b> ${rate.toFixed(4)} Bs/USD\n\n` +
      `✨ <i>Puedes usar tu saldo Zeny para comprar membresías sin comisiones o transferir saldo a otros usuarios desde el portal web.</i>`;
    await sendTelegram(token, chatId, saldoMsg, userKeyboard);
    return res.status(200).end();
  }

  // =========================================================================
  // SECCIÓN COMPARTIDA: 💳 Línea de Crédito & Deudas / Financiamiento
  // =========================================================================
  const isCredito = lowerText.includes('crédito') || lowerText.includes('credito') ||
    lowerText.includes('deuda') || lowerText.includes('financiamiento') ||
    lowerText.includes('límite') || lowerText.includes('limite') || lowerText === '/deudas' || lowerText === '/credito';

  if (isCredito) {
    const { rate } = await getBcvRate();
    const debt = await sbRest('rpc/bot_get_customer_debt_summary', {
      method: 'POST',
      body: JSON.stringify({ p_customer_id: customerId })
    });

    const limiteUsd = Number(debt?.limite_credito || cust.limite_credito || 0);
    const deudaUsd = Number(debt?.deuda_total || 0);
    const deudaBs = deudaUsd * rate;
    const dispUsd = Number(debt?.credito_disponible || (limiteUsd - deudaUsd));
    const cuotas = debt?.cuotas || [];

    let debtDetail = '';
    if (cuotas.length > 0) {
      debtDetail = `\n\n📅 <b>Desglose de Cuotas Pendientes (${cuotas.length}):</b>\n` +
        cuotas.map((c, i) => {
          const m = Number(c.monto_usd || 0).toFixed(2);
          const st = c.vencida ? '🔴 Vencida' : '🟡 Por Pagar';
          return `${i + 1}. <b>${escHtml(c.plataforma || 'Servicio')}</b> (${escHtml(c.perfil || 'Perfil')})\n` +
            `   Monto: <b>$${m} USD</b> · Vence: ${escHtml(c.fecha_vencimiento || 'N/D')} [${st}]`;
        }).join('\n');
    }

    const creditoMsg = (isReseller ? `📈 <b>Línea de Crédito Comercial de Revendedor:</b>\n\n` : `📊 <b>Estado de tu Financiamiento & Cuotas:</b>\n\n`) +
      `📈 <b>Límite Aprobado:</b> $${limiteUsd.toFixed(2)} USD\n` +
      `🔴 <b>Deuda Total Pendiente:</b> $${deudaUsd.toFixed(2)} USD (${deudaBs.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs)\n` +
      `🟢 <b>Crédito Disponible:</b> $${dispUsd.toFixed(2)} USD` +
      debtDetail +
      (deudaUsd === 0 ? `\n\n✨ <b>¡Estás 100% al día!</b> No tienes cuotas o deudas pendientes.` : `\n\n💡 <i>Puedes saldar tus cuotas pendientes desde el portal o notificando tu pago a Gregory por WhatsApp.</i>`);

    await sendTelegram(token, chatId, creditoMsg, userKeyboard);
    return res.status(200).end();
  }

  // =========================================================================
  // BOTÓN: 📦 Historial de Compras / Historial de Pedidos Recientes
  // =========================================================================
  const isHistorial = lowerText.includes('historial') || lowerText.includes('pedidos') ||
    lowerText.includes('compras recientes') || lowerText === '/pedidos' || lowerText === '/historial';

  if (isHistorial) {
    const { rate } = await getBcvRate();
    const orders = await sbRest(
      `orders?customer_id=eq.${customerId}&order=created_at.desc&limit=6&select=id,created_at,total_usd,total_bs,estado,referencia,conciliado_por,products(nombre)`
    );

    if (!orders || orders.length === 0) {
      const noOrdersMsg = `📦 <b>Historial de Compras & Pedidos:</b>\n\n` +
        `Aún no has registrado pedidos en la tienda.\n\n` +
        `🌐 <i>Explora nuestro catálogo online para adquirir tus membresías:</i>\n<a href="https://www.gregoryizquierdo.xyz">https://www.gregoryizquierdo.xyz</a>`;
      await sendTelegram(token, chatId, noOrdersMsg, userKeyboard);
      return res.status(200).end();
    }

    const orderLines = orders.map((o, idx) => {
      const shortId = o.id ? String(o.id).slice(0, 8) : 'OK';
      const prod = o.products?.nombre || 'Suscripción Digital';
      const usd = Number(o.total_usd || 0).toFixed(2);
      const bs = o.total_bs ? Number(o.total_bs).toLocaleString('es-VE', { minimumFractionDigits: 2 }) : (Number(o.total_usd || 0) * rate).toLocaleString('es-VE', { minimumFractionDigits: 2 });
      const fStr = o.created_at ? new Date(o.created_at).toLocaleDateString('es-VE') : 'Reciente';

      let statusBadge = '🟡 Pendiente';
      if (o.estado === 'entregado') statusBadge = '✅ Entregado / Activo';
      else if (o.estado === 'pagado') statusBadge = '💳 Pagado';
      else if (o.estado === 'cancelado') statusBadge = '❌ Cancelado';

      return `<b>${idx + 1}. Pedido #${shortId}</b> [${statusBadge}]\n` +
        `   📺 <b>${escHtml(prod)}</b>\n` +
        `   💵 Total: <b>$${usd} USD</b> (Bs. ${bs})\n` +
        `   📅 Fecha: <code>${fStr}</code>\n` +
        (o.referencia ? `   🔢 Ref: <code>${escHtml(o.referencia)}</code>\n` : '');
    }).join('\n');

    const histMsg = (isReseller ? `📦 <b>Tus Pedidos Mayoristas Recientes (${orders.length}):</b>\n` : `📦 <b>Tu Historial de Compras Recientes (${orders.length}):</b>\n`) +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `${orderLines}\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `💡 <i>Las credenciales de pedidos entregados están siempre accesibles en la opción "📦 Mis Servicios Activos" o en Mi Portal.</i>`;
    await sendTelegram(token, chatId, histMsg, userKeyboard);
    return res.status(200).end();
  }

  // =========================================================================
  // BOTÓN: 📅 Calendario de Vencimientos (Clientes y Revendedores)
  // =========================================================================
  const isCalendarioVenc = lowerText.includes('calendario') || lowerText.includes('vencimientos clientes') ||
    lowerText === '/calendario' || lowerText === '/vencimientos';

  if (isCalendarioVenc) {
    const hoyIso = new Date().toISOString().slice(0, 10);
    const { rate } = await getBcvRate();

    if (isReseller) {
      // Para revendedor: Calendario de vencimiento de las suscripciones de sus propios clientes
      const myProfiles = await sbRest(
        `profiles_inventory?or=(vendedor_id.eq.${customerId},vendedor.ilike.%25${encodeURIComponent(cust.nombre)}%25)&estado=eq.vendido&order=vence.asc&limit=30`
      );

      if (!myProfiles || myProfiles.length === 0) {
        await sendTelegram(token, chatId, '📅 No tienes clientes con perfiles activos por vencer en este momento.', userKeyboard);
        return res.status(200).end();
      }

      const lines = myProfiles.map((p, idx) => {
        const cliNom = p.cliente_final || 'Cliente';
        const srvNom = p.nombre_perfil || 'Servicio';
        const vence = p.vence || 'N/D';
        const tel = p.cliente_telefono ? String(p.cliente_telefono).replace(/\D/g, '') : '';

        let badge = '';
        if (p.vence) {
          const msDiff = new Date(p.vence).getTime() - new Date(hoyIso).getTime();
          const diasRest = Math.ceil(msDiff / 864e5);
          if (diasRest > 1) badge = `⏱ En ${diasRest} días (${vence})`;
          else if (diasRest === 1) badge = `⚠️ ¡Vence mañana! (${vence})`;
          else if (diasRest === 0) badge = `🔴 ¡Vence hoy! (${vence})`;
          else badge = `⛔ Vencido (${vence})`;
        }

        let waBtn = '';
        if (tel) {
          const full = tel.startsWith('58') ? tel : (tel.startsWith('0') ? '58' + tel.slice(1) : '58' + tel);
          waBtn = ` · <a href="https://wa.me/${full}?text=${encodeURIComponent(`Hola ${cliNom}! 👋 Te recordamos que tu servicio de ${srvNom} vence el ${vence}. ¿Deseas renovarlo hoy?`)}">Avisar WhatsApp</a>`;
        }

        return `<b>${idx + 1}. ${escHtml(cliNom)}</b> (${escHtml(srvNom)})\n` +
          `   📅 ${badge}${waBtn}`;
      }).join('\n\n');

      const calMsg = `📅 <b>Calendario de Vencimiento de tus Clientes (${myProfiles.length}):</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `${lines}\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `💡 <i>Toca sobre "Avisar WhatsApp" para notificar la renovación con un solo toque.</i>`;
      await sendTelegram(token, chatId, calMsg, userKeyboard);
      return res.status(200).end();
    } else {
      // Para cliente final: Calendario de sus servicios y sus cuotas
      const [items, cuotas] = await Promise.all([
        sbRest('rpc/bot_get_customer_credentials', { method: 'POST', body: JSON.stringify({ p_customer_id: customerId }) }).catch(() => []),
        sbRest(`installments?customer_id=eq.${customerId}&estado=in.(pendiente,vencida)&order=fecha_vencimiento.asc&select=numero_cuota,total_cuotas,monto_usd,fecha_vencimiento,estado,orders(products(nombre))`).catch(() => [])
      ]);

      let bodyParts = [];

      if (items && items.length > 0) {
        const srvLines = items.map((it, idx) => {
          let badge = '';
          if (it.dias_restantes > 1) badge = `⏱ En ${it.dias_restantes} días (${it.vence})`;
          else if (it.dias_restantes === 1) badge = `⚠️ ¡Vence mañana! (${it.vence})`;
          else if (it.dias_restantes === 0) badge = `🔴 ¡Vence hoy! (${it.vence})`;
          else badge = `⏳ Vence: ${it.vence || 'N/D'}`;

          return `${idx + 1}. <b>${escHtml(it.servicio)}</b> (${escHtml(it.perfil || 'Perfil')})\n   📅 ${badge}`;
        }).join('\n');
        bodyParts.push(`📺 <b>Membresías Activas:</b>\n${srvLines}`);
      }

      if (cuotas && cuotas.length > 0) {
        const cuotaLines = cuotas.map((c, idx) => {
          const mUsd = Number(c.monto_usd || 0).toFixed(2);
          const mBs = (Number(c.monto_usd || 0) * rate).toLocaleString('es-VE', { minimumFractionDigits: 2 });
          const isVencida = c.estado === 'vencida';
          const badge = isVencida ? '🔴 Vencida' : '🟡 Por Pagar';
          return `${idx + 1}. Cuota ${c.numero_cuota}/${c.total_cuotas} de <b>${escHtml(c.orders?.products?.nombre || 'Servicio')}</b>\n   💵 $${mUsd} USD (Bs. ${mBs}) · Vence: <code>${c.fecha_vencimiento}</code> [${badge}]`;
        }).join('\n');
        bodyParts.push(`💳 <b>Cuotas Programadas:</b>\n${cuotaLines}`);
      }

      if (bodyParts.length === 0) {
        await sendTelegram(token, chatId, '✨ No posees membresías ni cuotas con vencimiento próximo.', userKeyboard);
        return res.status(200).end();
      }

      const outMsg = `📅 <b>Tu Calendario de Vencimientos:</b>\n` +
        `📊 <i>Tasa BCV del día: ${rate.toFixed(4)} Bs/USD</i>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n` +
        bodyParts.join('\n\n') + '\n\n' +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `🌐 <i>Renueva o salda tus cuotas en:</i> <a href="https://www.gregoryizquierdo.xyz">https://www.gregoryizquierdo.xyz</a>`;
      await sendTelegram(token, chatId, outMsg, userKeyboard);
      return res.status(200).end();
    }
  }

  // =========================================================================
  // BOTÓN: 🚪 Cerrar Sesión
  // =========================================================================
  const isLogout = lowerText.includes('cerrar sesión') || lowerText.includes('cerrar sesion') ||
    lowerText.includes('salir') || lowerText === '/logout' || lowerText === '/salir';

  if (isLogout) {
    await sbRest(`telegram_sessions?chat_id=eq.${chatId}`, {
      method: 'PATCH',
      body: JSON.stringify({
        step: 'unauthenticated',
        customer_id: null,
        temp_identifier: null,
        updated_at: new Date().toISOString()
      })
    });
    await sbRest(`customers?id=eq.${customerId}`, {
      method: 'PATCH',
      body: JSON.stringify({
        telegram_chat_id: null
      })
    });

    const logoutMsg = `👋 <b>Has cerrado sesión exitosamente.</b>\n\n` +
      `Tu cuenta de la tienda se ha desvinculado de este chat de Telegram.\n` +
      `Para volver a acceder en cualquier momento, presiona /start.`;
    await sendTelegram(token, chatId, logoutMsg, null, true);
    return res.status(200).end();
  }

  // --- Respuesta a otros textos o comandos de BD ---
  const cmds = await sbRest('bot_commands?activo=eq.true&order=orden');
  const hit = cmds?.find(c => c.trigger.toLowerCase() === lowerText.split('@')[0]) ||
              cmds?.find(c => !c.trigger.startsWith('/') && c.trigger !== '*' && lowerText.includes(c.trigger.toLowerCase()));
  if (hit) {
    const { rate } = await getBcvRate();
    const neg = (await sbRest('settings?key=eq.negocio&select=value'))?.[0]?.value || {};
    const reply = hit.response
      .replaceAll('{tasa}', rate.toFixed(4))
      .replaceAll('{telefono}', neg.telefono || '')
      .replaceAll('{correo}', neg.correo || '');
    await sendTelegram(token, chatId, escHtml(reply), userKeyboard);
    return res.status(200).end();
  }

  // Fallback amigable adaptado según el rol
  const fallbackMsg = isReseller
    ? `🤖 <b>Milos:</b> Hola <b>${escHtml(cust.nombre)}</b> (Revendedor Autorizado).\n\n` +
      `Usa los botones del menú inferior para gestionar tu negocio:\n` +
      `• 👥 <b>Mis Clientes & Suscripciones</b>: Monitorea vencimientos y contactos.\n` +
      `• 📦 <b>Catálogo Revendedor</b>: Precios de mayorista y márgenes de ganancia.\n` +
      `• 💳 <b>Mis Cuotas & Línea Crédito</b>: Límite y saldo a crédito.\n` +
      `• 💰 <b>Mi Saldo Zeny</b>: Balance disponible.\n` +
      `• 💵 <b>Tasa BCV Oficial</b>: Tasa del día.\n` +
      `• 💳 <b>Métodos de Pago</b>: Cuentas BDV, BNC y Binance.`
    : `🤖 <b>Milos:</b> Hola <b>${escHtml(cust.nombre)}</b>, ¿en qué puedo ayudarte?\n\n` +
      `Usa los botones del menú inferior para consultar al instante:\n` +
      `• 📦 <b>Mis Servicios Activos</b>: Ver credenciales, perfiles y PINs.\n` +
      `• 💰 <b>Mi Saldo Zeny</b>: Consultar saldo en USD y Bolívares.\n` +
      `• 📅 <b>Mis Cuotas Pendientes</b>: Consulta fechas y montos.\n` +
      `• 💳 <b>Mi Límite Financiamiento</b>: Ver saldo a crédito.\n` +
      `• 💵 <b>Tasa BCV Oficial</b>: Tasa del día.\n` +
      `• 💳 <b>Métodos de Pago</b>: Cuentas bancarias para transferir.`;

  await sendTelegram(token, chatId, fallbackMsg, userKeyboard);
  return res.status(200).end();

} catch (err) {
  console.error('Error en webhook de Telegram:', err);
  try {
    if (token && chatId) {
      await sendTelegram(token, chatId, '⚠️ Ocurrió un error temporal al procesar tu solicitud. Por favor intenta de nuevo en un momento o escribe /start.');
    }
  } catch {}
  return res.status(200).json({ ok: false, error: err.message });
}
}
