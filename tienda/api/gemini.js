import { requireAdmin } from './_lib.js';
export default async function handler(req, res) {
  if (!(await requireAdmin(req, res))) return;
  if (!process.env.GEMINI_API_KEY) return res.status(500).json({ error: 'Falta GEMINI_API_KEY en las variables de entorno de Vercel' });

  const body = req.body || {};
  let contents = body.contents;
  if (!contents || !Array.isArray(contents) || contents.length === 0) {
    const prompt = String(body.prompt || '').slice(0, 8000);
    if (!prompt) return res.status(400).json({ error: 'Falta el mensaje o prompt' });
    contents = [{ role: 'user', parts: [{ text: prompt }] }];
  }

  const systemInstruction = {
    parts: [{
      text: `Eres el Asistente Ejecutivo de Inteligencia Artificial de "Emprendimiento Gregory Izquierdo", una empresa líder de pantallas, cuentas completas y servicios digitales de streaming (Netflix, Disney+, Max, Prime Video, Spotify, YouTube Premium, etc.).
Tu misión es asistir al administrador (Gregory) en:
1. Redacción de mensajes persuasivos y profesionales para clientes por WhatsApp y Telegram.
2. Mensajes de cobro y recordatorio de pagos/cuotas respetuosos pero claros.
3. Campañas y promociones de ventas atractivas con emojis y llamadas a la acción.
4. Atención a reclamos, caídas de pantallas o reposición de PIN con amabilidad y rapidez.
5. Análisis comercial y recomendaciones para maximizar ingresos.
Responde de forma concisa, moderna, bien formateada en markdown con viñetas y emojis donde sea apropiado.`
    }]
  };

  try {
    const r = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': process.env.GEMINI_API_KEY
      },
      body: JSON.stringify({ contents, systemInstruction })
    });
    const j = await r.json();
    if (!r.ok) return res.status(502).json({ error: j.error?.message || 'Error de Gemini' });
    const replyText = j.candidates?.[0]?.content?.parts?.map(p => p.text).join('') || '';
    res.json({ text: replyText });
  } catch (err) {
    res.status(500).json({ error: err.message || 'Error interno al consultar Gemini' });
  }
}

