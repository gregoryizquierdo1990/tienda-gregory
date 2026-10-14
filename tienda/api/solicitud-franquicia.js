// Procesa solicitudes públicas de franquicias, las registra en Supabase y notifica de inmediato al bot de Telegram y push
import { sbRest } from './_lib.js';
import { sendAll } from './_notify.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });

  const { businessName, ownerName, email, phone, telegramUser, notes } = req.body || {};

  if (!businessName || !ownerName || !email || !phone) {
    return res.status(400).json({ error: 'Faltan campos obligatorios (nombre de negocio, titular, email y teléfono).' });
  }

  const cleanPhone = String(phone).replace(/[^\d+]/g, '');
  const cleanTg = String(telegramUser || '').replace(/^@/, '').trim();

  // Guardar en Supabase
  let savedId = null;
  try {
    const insertRes = await sbRest('franchise_applications', {
      method: 'POST',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify({
        business_name: String(businessName).trim(),
        owner_name: String(ownerName).trim(),
        email: String(email).trim().toLowerCase(),
        phone: cleanPhone,
        telegram_user: cleanTg || null,
        notes: String(notes || '').trim() || null,
        status: 'pending',
        ip_address: req.headers['x-forwarded-for'] || req.socket?.remoteAddress || null,
        user_agent: req.headers['user-agent'] || null
      })
    });
    savedId = Array.isArray(insertRes) ? insertRes[0]?.id : null;
  } catch (err) {
    console.error('Error guardando en Supabase:', err);
    // Continuamos para no perder la notificación en caso de falla de base de datos
  }

  // Notificación instantánea a Telegram y Push al Administrador
  const tgDisplay = cleanTg ? `@${cleanTg}` : 'No proporcionado';
  const leadWhatsappUrl = `https://wa.me/${cleanPhone.replace('+', '')}?text=${encodeURIComponent(`Hola ${ownerName}, un gusto saludarte. Te escribe Gregory Izquierdo en respuesta a tu solicitud de franquicia para ${businessName}.`)}`;

  const alertText = `🚨 ¡NUEVA SOLICITUD DE FRANQUICIA!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏢 Negocio: ${businessName}
👤 Titular: ${ownerName}
📱 WhatsApp: ${cleanPhone}
✉️ Correo: ${email}
✈️ Telegram: ${tgDisplay}
📝 Experiencia / Notas: ${notes || 'Ninguna'}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 Contactar al interesado por WhatsApp:
${leadWhatsappUrl}`;

  let notifyResult = { telegram: false, push: 0 };
  try {
    notifyResult = await sendAll('solicitud_franquicia', alertText);
  } catch (err) {
    console.error('Error enviando notificación push/tg:', err);
  }

  // URL de WhatsApp para que el cliente contacte inmediatamente a Gregory (+584241983648)
  const gregoryWhatsappUrl = `https://wa.me/584241983648?text=${encodeURIComponent(
`¡Hola Gregory! 👋 Acabo de enviar mi postulación para operar una Franquicia de Streaming Oficial:

🏢 Negocio: ${businessName}
👤 Titular: ${ownerName}
📱 WhatsApp: ${cleanPhone}
✉️ Correo: ${email}
${cleanTg ? `✈️ Telegram: @${cleanTg}\n` : ''}
🚀 Deseo agilizar mi activación, conocer los costos de entrada y cómo recibir mi tienda lista para vender.`
  )}`;

  return res.status(200).json({
    ok: true,
    applicationId: savedId,
    notified: notifyResult,
    whatsappUrl: gregoryWhatsappUrl
  });
}
