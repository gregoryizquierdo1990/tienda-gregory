import { requireAdmin } from './_lib.js';
export default async function handler(req, res) {
  if (!(await requireAdmin(req, res))) return;
  const prompt = String(req.body?.prompt || '').slice(0, 4000);
  if (!prompt || !process.env.GEMINI_API_KEY) return res.status(400).json({ error: 'Falta el texto o GEMINI_API_KEY' });
  const r = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent', { method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': process.env.GEMINI_API_KEY }, body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }) });
  const j = await r.json();
  if (!r.ok) return res.status(502).json({ error: j.error?.message || 'Error de Gemini' });
  res.json({ text: j.candidates?.[0]?.content?.parts?.map(p => p.text).join('') || '' });
}
