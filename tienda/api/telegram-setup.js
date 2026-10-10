import { requireAdmin, setSecret, sbRest } from './_lib.js';
export default async function handler(req, res) {
  if (!(await requireAdmin(req, res))) return;
  const token = String(req.body?.token || '');
  if (!/^\d+:[\w-]{30,}$/.test(token)) return res.status(400).json({ error: 'Token inválido' });
  const me = await (await fetch(`https://api.telegram.org/bot${token}/getMe`)).json();
  if (!me.ok) return res.status(400).json({ error: 'Telegram rechazó el token' });
  const secret = crypto.randomUUID().replaceAll('-', '');
  const host = `https://${req.headers['x-forwarded-host'] || req.headers.host}`;
  const w = await (await fetch(`https://api.telegram.org/bot${token}/setWebhook`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url: `${host}/api/telegram`, secret_token: secret, allowed_updates: ['message'] }) })).json();
  if (!w.ok) return res.status(400).json({ error: 'No se pudo registrar el webhook' });
  await setSecret('telegram_token', token); await setSecret('telegram_webhook_secret', secret);
  await sbRest('settings?on_conflict=key', { method: 'POST', headers: { Prefer: 'resolution=merge-duplicates' }, body: JSON.stringify({ key: 'bot', value: { username: me.result.username } }) });
  res.json({ ok: true, bot: me.result.username });
}
