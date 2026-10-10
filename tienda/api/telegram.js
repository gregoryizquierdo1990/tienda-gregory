// Webhook del bot. Solo responde con textos que el administrador edita (tabla bot_commands). No expone datos de clientes.
import { sbRest, getSecret } from './_lib.js';
export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(200).send('ok');
  const sec = await getSecret('telegram_webhook_secret');
  if (!sec || req.headers['x-telegram-bot-api-secret-token'] !== sec) return res.status(401).end();
  const msg = req.body?.message, text = (msg?.text || '').trim().toLowerCase();
  if (!msg?.chat?.id || !text) return res.status(200).end();
  const [cmds, rate, neg] = await Promise.all([sbRest('bot_commands?activo=eq.true&order=orden'),
    sbRest('exchange_rates?select=bs_por_usd&order=fecha.desc&limit=1'), sbRest('settings?key=eq.negocio&select=value')]);
  const hit = cmds.find(c => c.trigger.toLowerCase() === text.split('@')[0]) || cmds.find(c => !c.trigger.startsWith('/') && c.trigger !== '*' && text.includes(c.trigger.toLowerCase())) || cmds.find(c => c.trigger === '*');
  if (!hit) return res.status(200).end();
  const n = neg?.[0]?.value || {};
  const reply = hit.response.replaceAll('{tasa}', rate?.[0]?.bs_por_usd ?? 'N/D').replaceAll('{telefono}', n.telefono || '').replaceAll('{correo}', n.correo || '');
  const token = await getSecret('telegram_token');
  await fetch(`https://api.telegram.org/bot${token}/sendMessage`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ chat_id: msg.chat.id, text: reply }) });
  res.status(200).end();
}
