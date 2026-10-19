// Webhook de Telegram interactivo y automatizado para @Diego1asistente_bot
// Vinculado a la tienda de Emprendimiento Gregory Izquierdo
import { sbRest, getSecret, U, K } from './_lib.js';

const GREETING_BASE = 'Hola Mi nombre es Diego_bot Asistente de Gestio de Emprendimiento Gregory Izquierdo en que puedo ayudarte';

const MAIN_KEYBOARD = [
  [{ text: '📦 Mis Servicios Activos' }, { text: '💰 Mi Saldo Zeny' }],
  [{ text: '💳 Línea de Crédito & Deudas' }, { text: '💵 Tasa BCV Oficial' }],
  [{ text: '🛒 Catálogo Tienda' }, { text: '💬 Contactar Soporte' }],
  [{ text: '🚪 Cerrar Sesión' }]
];

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

  // 2. Búsqueda por Código de Identificación (ej: CLT-008, RVD-1002, etc.)
  const byCode = await sbRest(`customers?codigo_identificacion=ilike.${encodeURIComponent(clean)}&limit=1`);
  if (byCode?.[0]) return byCode[0];

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

  const msg = req.body?.message;
  if (!msg?.chat?.id) return res.status(200).end();

  const chatId = msg.chat.id;
  const fromId = msg.from?.id || chatId;
  const username = msg.from?.username ? `@${msg.from.username}` : null;
  const rawText = (msg.text || '').trim();
  const lowerText = rawText.toLowerCase();

  const token = await getSecret('telegram_token');
  if (!token) return res.status(200).end();

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

        const welcomeLinked = `${GREETING_BASE}\n\n` +
          `✅ <b>¡Tu cuenta ha sido vinculada exitosamente!</b>\n` +
          `Bienvenido/a <b>${escHtml(cust.nombre)}</b> (ID: <code>${escHtml(cust.codigo_identificacion || 'CLT')}</code>).\n\n` +
          `Ahora tienes acceso instantáneo a tus membresías activas, PINs, saldos en Wallet Zeny y cuotas pendientes desde este chat.`;
        await sendTelegram(token, chatId, welcomeLinked, MAIN_KEYBOARD);
        return res.status(200).end();
      }
    }
  }

  // 3. Manejo del comando /start
  if (lowerText === '/start' || lowerText.startsWith('/start ')) {
    if (session?.customer_id && session?.step === 'authenticated') {
      const cust = (await sbRest(`customers?id=eq.${session.customer_id}&limit=1`))?.[0];
      if (cust) {
        const welcomeBack = `${GREETING_BASE}\n\n` +
          `👋 ¡Hola de nuevo, <b>${escHtml(cust.nombre)}</b>!\n` +
          `Tu cuenta está conectada y sincronizada con la tienda.\n\n` +
          `¿Qué deseas consultar hoy? Elige una opción del menú abajo 👇`;
        await sendTelegram(token, chatId, welcomeBack, MAIN_KEYBOARD);
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
      `🔐 <b>Para acceder a tus servicios, saldos y deudas personalizadas:</b>\n` +
      `Por favor escribe tu <b>Correo electrónico</b>, <b>Código ID de Cliente</b> (ej: <code>CLT-008</code> o <code>RVD-1002</code>) o tu <b>Número de WhatsApp</b> registrado en la tienda:`;
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
        `Por favor verifica tu correo o código ID de cliente e inténtalo nuevamente.\n` +
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
      `🔑 <b>Por favor ingresa tu contraseña de acceso al portal:</b>\n\n` +
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

      const isDemo = cust.es_demo === true;
      const successMsg = `✅ <b>¡Inicio de sesión exitoso!</b>\n` +
        `Bienvenido/a <b>${escHtml(cust.nombre)}</b> al Asistente Interactivo.` +
        (isDemo ? `\n\n🔒 <b>Modo Demostración Activo:</b> Esta cuenta es para visualización y pruebas. Puedes consultar saldos, cuotas y catálogo con total libertad.` : '') +
        `\n\nPuedes consultar tus servicios, deudas, saldo o tasa en cualquier momento usando los botones abajo 👇`;
      await sendTelegram(token, chatId, successMsg, MAIN_KEYBOARD);
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
      `<i>Esta es la tasa oficial aplicada a todos los consumos y recargas de la tienda.</i>`;
    await sendTelegram(token, chatId, rateText, session?.step === 'authenticated' ? MAIN_KEYBOARD : null);
    return res.status(200).end();
  }

  const isTienda = lowerText.includes('tienda') || lowerText.includes('catálogo') || lowerText.includes('catalogo') || lowerText.includes('comprar') || lowerText === '/tienda';
  if (isTienda) {
    const storeText = `🛒 <b>Catálogo Oficial de la Tienda Gregory Izquierdo:</b>\n\n` +
      `Explora nuestras membresías de streaming, combos en promoción, servicios bajo pedido y gaming:\n\n` +
      `🌐 <b>Tienda Online:</b> <a href="https://www.gregoryizquierdo.xyz">https://www.gregoryizquierdo.xyz</a>\n` +
      `⚡ Entregas automatizadas e inmediatas 24/7.`;
    await sendTelegram(token, chatId, storeText, session?.step === 'authenticated' ? MAIN_KEYBOARD : null);
    return res.status(200).end();
  }

  const isSoporte = lowerText.includes('soporte') || lowerText.includes('ayuda') || lowerText.includes('contacto') || lowerText.includes('asesor') || lowerText.includes('whatsapp') || lowerText === '/soporte';
  if (isSoporte) {
    const neg = (await sbRest('settings?key=eq.negocio&select=value'))?.[0]?.value || {};
    const tel = (neg.telefono || '+584122952044').replace(/\D/g, '');
    const sopText = `💬 <b>Atención al Cliente y Soporte Directo:</b>\n\n` +
      `¿Necesitas ayuda con una membresía, recarga o consulta comercial?\n\n` +
      `📲 <b>WhatsApp:</b> <a href="https://wa.me/${tel}">Escribir por WhatsApp a Gregory</a>\n` +
      `📧 <b>Correo:</b> ${escHtml(neg.correo || 'soporte@gregoryizquierdo.xyz')}\n\n` +
      `¡Estamos a tu orden para asistirte!`;
    await sendTelegram(token, chatId, sopText, session?.step === 'authenticated' ? MAIN_KEYBOARD : null);
    return res.status(200).end();
  }

  // 8. Si no está autenticado y pide información personal:
  if (session?.step !== 'authenticated' || !session?.customer_id) {
    const isPrivateQuery = lowerText.includes('servicio') || lowerText.includes('membresia') || lowerText.includes('pantalla') ||
      lowerText.includes('saldo') || lowerText.includes('zeny') || lowerText.includes('wallet') ||
      lowerText.includes('deuda') || lowerText.includes('credito') || lowerText.includes('cuota');

    if (isPrivateQuery) {
      const reqLoginMsg = `🔐 <b>Acceso a Información Personal</b>\n\n` +
        `Para consultar tus servicios activos, saldos o deudas, primero debes iniciar sesión.\n\n` +
        `Escribe <b>/start</b> para identificarte con tu correo o ID de cliente.`;
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

  // 9. CLIENTE AUTENTICADO: Consultas personalizadas
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

  // --- BOTÓN: 📦 Mis Servicios Activos ---
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
      await sendTelegram(token, chatId, noSrvMsg, MAIN_KEYBOARD);
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
    await sendTelegram(token, chatId, srvMsg, MAIN_KEYBOARD);
    return res.status(200).end();
  }

  // --- BOTÓN: 💰 Mi Saldo Zeny ---
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
    await sendTelegram(token, chatId, saldoMsg, MAIN_KEYBOARD);
    return res.status(200).end();
  }

  // --- BOTÓN: 💳 Línea de Crédito & Deudas ---
  const isCredito = lowerText.includes('crédito') || lowerText.includes('credito') ||
    lowerText.includes('deuda') || lowerText.includes('cuota') || lowerText.includes('financiamiento') ||
    lowerText.includes('limite') || lowerText === '/deudas' || lowerText === '/credito';

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

    const creditoMsg = `💳 <b>Estado de tu Línea de Crédito & Deudas:</b>\n\n` +
      `📈 <b>Límite Aprobado:</b> $${limiteUsd.toFixed(2)} USD\n` +
      `🔴 <b>Deuda Total Pendiente:</b> $${deudaUsd.toFixed(2)} USD (${deudaBs.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs)\n` +
      `🟢 <b>Crédito Disponible:</b> $${dispUsd.toFixed(2)} USD` +
      debtDetail +
      (deudaUsd === 0 ? `\n\n✨ <b>¡Estás 100% al día!</b> No tienes cuotas o deudas pendientes.` : `\n\n💡 <i>Puedes saldar tus cuotas pendientes desde el portal o notificando tu pago a Gregory por WhatsApp.</i>`);

    await sendTelegram(token, chatId, creditoMsg, MAIN_KEYBOARD);
    return res.status(200).end();
  }

  // --- BOTÓN: 🚪 Cerrar Sesión ---
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
    await sendTelegram(token, chatId, escHtml(reply), MAIN_KEYBOARD);
    return res.status(200).end();
  }

  // Fallback amigable para clientes autenticados
  const fallbackMsg = `🤖 <b>Diego_bot:</b> Hola <b>${escHtml(cust.nombre)}</b>, ¿en qué puedo ayudarte?\n\n` +
    `Usa los botones del menú inferior para consultar al instante:\n` +
    `• 📦 <b>Mis Servicios Activos</b>: Ver credenciales, perfiles y PINs.\n` +
    `• 💰 <b>Mi Saldo Zeny</b>: Consultar saldo en USD y Bolívares.\n` +
    `• 💳 <b>Línea de Crédito & Deudas</b>: Ver límite y cuotas pendientes.\n` +
    `• 💵 <b>Tasa BCV Oficial</b>: Tasa del día.\n` +
    `• 💬 <b>Contactar Soporte</b>: Enlace directo con Gregory.`;
  await sendTelegram(token, chatId, fallbackMsg, MAIN_KEYBOARD);
  return res.status(200).end();
}
