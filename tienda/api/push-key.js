// Clave pública VAPID (es pública por diseño) para que el navegador pueda suscribirse a las notificaciones push.
import { getSecret } from './_lib.js';
export default async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  res.json({ key: (await getSecret('vapid_public')) || null });
}
