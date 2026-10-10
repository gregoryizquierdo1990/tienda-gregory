import { requireAdmin } from './_lib.js';
import { sendAll } from './_notify.js';
export default async function handler(req, res) {
  if (!(await requireAdmin(req, res))) return;
  res.json(await sendAll('test', 'Prueba de notificaciones: todo funciona ✅'));
}
