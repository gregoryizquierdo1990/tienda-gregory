// Lo llama la base de datos (pg_net) al llegar un pedido, recarga o incidencia. Protegido con un secreto compartido.
import { timingSafeEqual } from 'node:crypto';
import { getSecret } from './_lib.js';
import { sendAll } from './_notify.js';
export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  const s = await getSecret('notify_secret'), got = String(req.headers['x-notify-secret'] || '');
  if (!s || got.length !== s.length || !timingSafeEqual(Buffer.from(got), Buffer.from(s))) return res.status(401).end();
  const { kind, msg } = req.body || {};
  if (!msg) return res.status(400).json({ error: 'Falta msg' });
  res.json(await sendAll(String(kind || 'info'), String(msg).slice(0, 300)));
}
