// Cron diario (8:00 a. m. Venezuela): avisa los vencimientos del día por Telegram y push, aunque la app esté cerrada.
import { sbRest } from './_lib.js';
import { sendAll } from './_notify.js';
export default async function handler(req, res) {
  if (process.env.CRON_SECRET && req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) return res.status(401).json({ error: 'No autorizado' });
  const hoy = new Date(Date.now() - 4 * 3600e3).toISOString().slice(0, 10);
  const [a, b] = await Promise.all([sbRest(`orders?estado=eq.entregado&vence=eq.${hoy}&select=id`), sbRest(`mother_accounts?activa=eq.true&vence=eq.${hoy}&select=id`)]);
  const n1 = a?.length || 0, n2 = b?.length || 0;
  if (n1 + n2 === 0) return res.json({ ok: true, enviados: 0 });
  res.json({ ok: true, ...(await sendAll('venc', `Vencen hoy: ${n1} servicio(s) de clientes y ${n2} cuenta(s) madre`)) });
}
