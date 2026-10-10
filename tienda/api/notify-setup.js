// Activa las notificaciones: genera llaves VAPID (push) y el secreto de la base de datos, y guarda tu ID de Telegram.
import { generateKeyPairSync, randomBytes } from 'node:crypto';
import { requireAdmin, getSecret, setSecret, sbRest } from './_lib.js';
export default async function handler(req, res) {
  if (!(await requireAdmin(req, res))) return;
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
