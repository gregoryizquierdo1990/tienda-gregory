// Envía un aviso al administrador por Telegram y por notificación push (a todos sus dispositivos registrados).
import webpush from 'web-push';
import { sbRest, getSecret } from './_lib.js';

export async function sendTelegram(msgHtml, plainMsg) {
  try {
    const cfg = (await sbRest('settings?key=eq.notificaciones&select=value'))?.[0]?.value || {};
    const token = (await getSecret('telegram_token')) || cfg.bot_token || process.env.TELEGRAM_BOT_TOKEN;
    const chatId = cfg.telegram_chat_id || process.env.TELEGRAM_CHAT_ID;

    if (!chatId || !token) {
      return { ok: false, error: 'Telegram sin configurar (guarda el token y tu ID en el módulo Notificaciones)' };
    }

    const payload = {
      chat_id: chatId,
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
      // Reintentar en texto plano si Telegram rechaza etiquetas HTML mal balanceadas
      r = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chat_id: chatId, text: plainMsg || msgHtml.replace(/<[^>]+>/g, '') })
      });
    }

    if (!r.ok) {
      const errText = await r.text();
      return { ok: false, error: 'Telegram: ' + errText.slice(0, 160) };
    }

    return { ok: true };
  } catch (err) {
    return { ok: false, error: 'Telegram: ' + err.message };
  }
}

export async function sendAll(kind, msg, htmlMsg, targetUserId = null) {
  const out = { telegram: false, push: 0, errores: [] };

  // 1. Envío a Telegram con formato HTML enriquecido (solo para admin o cuando no es privado)
  if (!targetUserId) {
    const tgRes = await sendTelegram(htmlMsg || msg, msg);
    out.telegram = tgRes.ok;
    if (!tgRes.ok && tgRes.error) {
      out.errores.push(tgRes.error);
    }
  }

  // 2. Envío a Web Push (al usuario específico o a todos según corresponda)
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
