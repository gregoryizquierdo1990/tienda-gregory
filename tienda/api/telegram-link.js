// Genera enlaces de vinculación de 1 clic para Diego_bot en Telegram
import { sbRest, U, K } from './_lib.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });

  const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '').trim();
  if (!token) return res.status(401).json({ error: 'No autenticado' });

  // 1. Validar el token del cliente contra Supabase Auth
  const userRes = await fetch(`${U}/auth/v1/user`, {
    headers: { apikey: K, Authorization: `Bearer ${token}` }
  });
  if (!userRes.ok) return res.status(401).json({ error: 'Sesión inválida o expirada' });

  const authUser = await userRes.json();
  const email = (authUser.email || '').toLowerCase();
  if (!email) return res.status(400).json({ error: 'Usuario sin correo' });

  // 2. Buscar cliente en la base de datos
  let cust = (await sbRest(`customers?email=ilike.${encodeURIComponent(email)}&limit=1`))?.[0];

  // Si no se encontró por email directo, intentar si es correo virtual telefónico
  if (!cust && email.includes('@cliente.gregoryizquierdo.xyz')) {
    const digits = email.split('@')[0].replace(/\D/g, '');
    cust = (await sbRest(`customers?telefono=ilike.%25${digits.slice(-7)}%25&limit=1`))?.[0];
  }

  if (!cust) return res.status(404).json({ error: 'No se encontró la ficha de cliente' });

  // 3. Generar token aleatorio seguro
  const linkToken = 'auth_' + crypto.randomUUID().replaceAll('-', '').slice(0, 20);
  const tempChatId = -1 * Math.floor(Math.random() * 899999999 + 100000000);

  // 4. Limpiar tokens pendientes antiguos de este cliente
  await sbRest(`telegram_sessions?customer_id=eq.${cust.id}&step=eq.pending_link`, {
    method: 'DELETE'
  }).catch(() => {});

  // 5. Registrar la sesión pendiente
  await sbRest('telegram_sessions', {
    method: 'POST',
    body: JSON.stringify({
      chat_id: tempChatId,
      customer_id: cust.id,
      step: 'pending_link',
      auth_token: linkToken,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    })
  });

  const botUsername = 'Diego1asistente_bot';
  const url = `https://t.me/${botUsername}?start=${linkToken}`;

  res.status(200).json({
    ok: true,
    token: linkToken,
    bot: botUsername,
    url
  });
}
