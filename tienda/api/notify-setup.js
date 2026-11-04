// Activa las notificaciones: genera llaves VAPID (push) y el secreto de la base de datos, y guarda tu ID de Telegram.
// También maneja el envío de prueba (/api/notify-test) y la vinculación del bot (@Diego1asistente_bot / /api/telegram-setup).
import { generateKeyPairSync, randomBytes } from 'node:crypto';
import { requireAdmin, getSecret, setSecret, sbRest } from './_lib.js';
import { sendAll } from './_notify.js';

export default async function handler(req, res) {
  if (!(await requireAdmin(req, res))) return;

  const action = req.query?.action || req.body?.action;

  // 1. Envío de prueba (/api/notify-test)
  if (action === 'test' || req.query?.test === '1') {
    return res.json(await sendAll('test', 'Prueba de notificaciones: todo funciona ✅'));
  }

  // 2. Configuración del Bot de Telegram (/api/telegram-setup)
  if (action === 'telegram' || (req.body?.token && !req.body?.telegram_chat_id)) {
    const token = String(req.body?.token || '');
    if (!/^\d+:[\w-]{30,}$/.test(token)) return res.status(400).json({ error: 'Token inválido' });
    const me = await (await fetch(`https://api.telegram.org/bot${token}/getMe`)).json();
    if (!me.ok) return res.status(400).json({ error: 'Telegram rechazó el token' });
    const secret = crypto.randomUUID().replaceAll('-', '');
    const host = `https://${req.headers['x-forwarded-host'] || req.headers.host}`;
    const w = await (await fetch(`https://api.telegram.org/bot${token}/setWebhook`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url: `${host}/api/telegram`, secret_token: secret, allowed_updates: ['message'] })
    })).json();
    if (!w.ok) return res.status(400).json({ error: 'No se pudo registrar el webhook' });
    await setSecret('telegram_token', token);
    await setSecret('telegram_webhook_secret', secret);
    await sbRest('settings?on_conflict=key', {
      method: 'POST',
      headers: { Prefer: 'resolution=merge-duplicates' },
      body: JSON.stringify({ key: 'bot', value: { username: me.result.username } })
    });
    return res.json({ ok: true, bot: me.result.username });
  }

  // 3. Configuración de notificaciones Push y Secreto de DB (/api/notify-setup)
  if (!(await getSecret('vapid_public'))) {
    const { publicKey, privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
    const pub = publicKey.export({ format: 'jwk' });
    await setSecret('vapid_public', Buffer.concat([Buffer.from([4]), Buffer.from(pub.x, 'base64url'), Buffer.from(pub.y, 'base64url')]).toString('base64url'));
    await setSecret('vapid_private', privateKey.export({ format: 'jwk' }).d);
  }
  if (!(await getSecret('notify_secret'))) await setSecret('notify_secret', randomBytes(24).toString('hex'));
  await setSecret('notify_url', `https://${req.headers['x-forwarded-host'] || req.headers.host}/api/notify`);
  const chat = String(req.body?.telegram_chat_id || '').trim();
  if (chat) {
    if (!/^-?\d{5,15}$/.test(chat)) return res.status(400).json({ error: 'ID de Telegram inválido (solo números)' });
    await sbRest('settings?on_conflict=key', { method: 'POST', headers: { Prefer: 'resolution=merge-duplicates' }, body: JSON.stringify({ key: 'notificaciones', value: { telegram_chat_id: chat } }) });
  }
  res.json({ ok: true });
}

