// Cron diario de Vercel: guarda la tasa oficial BCV. Protegido con CRON_SECRET.
// Valida el dato (número > 0 y sin saltos absurdos) y avisa al administrador por Telegram/push si falla.
import { sbRest } from './_lib.js';
import { sendAll } from './_notify.js';

export default async function handler(req, res) {
  if (process.env.CRON_SECRET && req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) return res.status(401).json({ error: 'No autorizado' });
  try {
    const r = await fetch('https://ve.dolarapi.com/v1/dolares/oficial', { headers: { Accept: 'application/json' } });
    if (!r.ok) throw new Error('Fuente de la tasa respondió ' + r.status);
    const j = await r.json();
    const tasa = Number(j.promedio ?? j.venta ?? j.compra ?? j.price);
    if (!(tasa > 0) || !Number.isFinite(tasa)) throw new Error('Tasa inválida recibida');
    const prev = Number((await sbRest('exchange_rates?select=bs_por_usd&order=fecha.desc&limit=1'))?.[0]?.bs_por_usd || 0);
    if (prev && Math.abs(tasa / prev - 1) > 0.25) throw new Error(`Tasa fuera de rango (${tasa} vs ${prev}); no se guardó`);
    const fecha = new Date(Date.now() - 4 * 3600e3).toISOString().slice(0, 10); // fecha de Venezuela (UTC-4)
    await sbRest('exchange_rates?on_conflict=fecha', { method: 'POST', headers: { Prefer: 'resolution=merge-duplicates' }, body: JSON.stringify({ fecha, bs_por_usd: tasa, fuente: 'BCV' }) });
    res.json({ ok: true, fecha, tasa });
  } catch (e) {
    try { await sendAll('tasa', 'No se pudo actualizar la tasa BCV hoy: ' + e.message); } catch {}
    res.status(500).json({ error: e.message });
  }
}
