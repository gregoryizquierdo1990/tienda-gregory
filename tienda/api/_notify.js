// Envía un aviso al administrador por Telegram y por notificación push (a todos sus dispositivos registrados).
import webpush from 'web-push';
import { sbRest, getSecret } from './_lib.js';

export async function sendAll(kind, msg) {
  const out = { telegram: false, push: 0, errores: [] };
  const cfg = (await sbRest('settings?key=eq.notificaciones&select=value'))?.[0]?.value || {};
  const token = await getSecret('telegram_token');
  if (cfg.telegram_chat_id && token) {
    try {
      const r = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ chat_id: cfg.telegram_chat_id, text: '🔔 ' + msg }) });
      out.telegram = r.ok; if (!r.ok) out.errores.push('Telegram: ' + (await r.text()).slice(0, 120));
    } catch (e) { out.errores.push('Telegram: ' + e.message); }
  } else out.errores.push('Telegram sin configurar (conecta el bot y guarda tu ID)');
  const pub = await getSecret('vapid_public'), priv = await getSecret('vapid_private');
  if (pub && priv) {
    const neg = (await sbRest('settings?key=eq.negocio&select=value'))?.[0]?.value || {};
    webpush.setVapidDetails('mailto:' + (neg.correo || 'emprendimientogregoryizquierdo@gmail.com'), pub, priv);
    const subs = (await sbRest('push_subscriptions?select=id,endpoint,p256dh,auth')) || [];
    await Promise.all(subs.map(async s => {
      try { await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify({ title: 'Gregory Izquierdo', body: msg, tag: kind }), { TTL: 3600, urgency: 'high' }); out.push++; }
      catch (e) { if (e.statusCode === 404 || e.statusCode === 410) await sbRest(`push_subscriptions?id=eq.${s.id}`, { method: 'DELETE' }); else out.errores.push('Push: ' + (e.statusCode || e.message)); }
    }));
  }
  return out;
}
