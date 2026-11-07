import { sbRest, getSecret } from './_lib.js';

let webpush = null;
try {
  const mod = await import('web-push');
  webpush = mod.default || mod;
} catch {}

export const ADMIN_CHAT_ID = '1252102820';

export const BOTS = {
  milos: {
    name: 'Milos',
    username: 'agentemilos_bot',
    token: '9018604803:AAGrRViH6W6Ct2FTP65RqbUga6u0uFZ6gDg',
    role: 'Orquestador Inteligente & Supervisor'
  },
  esteban: {
    name: 'Esteban',
    username: 'agenteesteban_bot',
    token: '9281654307:AAFOfFL0PlLFHAyaoGRyBlhz-faKrFqV8E4',
    role: 'Reporte Matutino 8:00 AM'
  },
  ramses: {
    name: 'Ramses',
    username: 'agenteramses_bot',
    token: '9010437688:AAGJ6VaBNo_vls_zdgw4QA-Ol6Tce6D3mQY',
    role: 'Reporte Cierre 9:00 PM'
  },
  sahara: {
    name: 'Sahara',
    username: 'agentesahara_bot',
    token: '9130459367:AAGpInOIOdln8MrxmcUZqhP6y0q-Zc-CDl8',
    role: 'Finanzas & Despachos Zeny'
  }
};

export async function sendTelegramBot(botKey = 'milos', msgHtml, plainMsg, targetChatId = null) {
  try {
    const botCfg = BOTS[botKey] || BOTS.milos;
    const token = botCfg.token;
    const chatId = targetChatId || ADMIN_CHAT_ID;

    if (!chatId || !token) {
      return { ok: false, error: `Bot ${botKey} sin token o chat_id no especificado` };
    }

    const payload = {
      chat_id: String(chatId),
      text: msgHtml,
      parse_mode: 'HTML',
      disable_web_page_preview: true
    };

    let r = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    if (!r.ok) {
      // Reintentar en texto plano si Telegram rechaza formato HTML
      r = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: String(chatId),
          text: plainMsg || msgHtml.replace(/<[^>]+>/g, '')
        })
      });
    }

    if (!r.ok) {
      const errText = await r.text();
      return { ok: false, error: `Telegram (${botCfg.name}): ${errText.slice(0, 160)}` };
    }

    return { ok: true, bot: botCfg.name };
  } catch (err) {
    return { ok: false, error: `Telegram (${botKey}): ${err.message}` };
  }
}

export async function sendMilos(msgHtml, plainMsg, targetChatId = null) {
  return sendTelegramBot('milos', msgHtml, plainMsg, targetChatId);
}

export async function sendEsteban(msgHtml, plainMsg, targetChatId = null) {
  return sendTelegramBot('esteban', msgHtml, plainMsg, targetChatId);
}

export async function sendRamses(msgHtml, plainMsg, targetChatId = null) {
  return sendTelegramBot('ramses', msgHtml, plainMsg, targetChatId);
}

export async function sendSahara(msgHtml, plainMsg, targetChatId = null) {
  return sendTelegramBot('sahara', msgHtml, plainMsg, targetChatId);
}

// Mantener compatibilidad directa con código existente
export async function sendTelegram(msgHtml, plainMsg, botKey = 'milos', targetChatId = null) {
  return sendTelegramBot(botKey, msgHtml, plainMsg, targetChatId);
}

export async function sendAll(kind, msg, htmlMsg, targetUserId = null, botKey = 'milos') {
  const out = { telegram: false, push: 0, errores: [] };

  // 1. Envío a Telegram por el bot indicado (por defecto Milos o Sahara para zeny)
  if (!targetUserId) {
    const tgRes = await sendTelegramBot(botKey, htmlMsg || msg, msg);
    out.telegram = tgRes.ok;
    if (!tgRes.ok && tgRes.error) {
      out.errores.push(tgRes.error);
    }
  }

  // 2. Envío a Web Push (al usuario específico o a todos los administradores)
  try {
    const pub = (await getSecret('vapid_public')) || process.env.VAPID_PUBLIC_KEY;
    const priv = (await getSecret('vapid_private')) || process.env.VAPID_PRIVATE_KEY;
    if (pub && priv) {
      const neg = (await sbRest('settings?key=eq.negocio&select=value'))?.[0]?.value || {};
      webpush.setVapidDetails('mailto:' + (neg.correo || 'emprendimientogregoryizquierdo@gmail.com'), pub, priv);
      const urlQuery = targetUserId
        ? `push_subscriptions?user_id=eq.${targetUserId}&select=id,endpoint,p256dh,auth,user_id`
        : 'push_subscriptions?select=id,endpoint,p256dh,auth,user_id';
      const subs = (await sbRest(urlQuery)) || [];
      await Promise.all(subs.map(async s => {
        try {
          await webpush.sendNotification(
            { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
            JSON.stringify({ title: 'Emprendimiento Gregory', body: String(msg).slice(0, 160), tag: kind }),
            { TTL: 3600, urgency: 'high' }
          );
          out.push++;
        } catch (e) {
          if (e.statusCode === 404 || e.statusCode === 410) {
            await sbRest(`push_subscriptions?id=eq.${s.id}`, { method: 'DELETE' });
          } else {
            out.errores.push('Push: ' + (e.statusCode || e.message));
          }
        }
      }));
    }
  } catch (e) {
    out.errores.push('Push: ' + e.message);
  }

  return out;
}
