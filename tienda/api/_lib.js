// Utilidades del servidor. Usan la clave service_role (solo en variables de Vercel, nunca en el navegador)
const U = process.env.SUPABASE_URL, K = process.env.SUPABASE_SERVICE_KEY;
export const sbRest = async (path, opts = {}) => {
  const r = await fetch(`${U}/rest/v1/${path}`, { ...opts, headers: { apikey: K, Authorization: `Bearer ${K}`, 'Content-Type': 'application/json', ...(opts.headers || {}) } });
  if (!r.ok) throw new Error(await r.text());
  const t = await r.text(); return t ? JSON.parse(t) : null;
};
export const getSecret = async n => (await sbRest(`secrets?name=eq.${n}&select=value`))?.[0]?.value;
export const setSecret = (name, value) => sbRest('secrets?on_conflict=name', { method: 'POST', headers: { Prefer: 'resolution=merge-duplicates' }, body: JSON.stringify({ name, value }) });
// Solo el administrador (correo autorizado + sesión iniciada con Google) puede usar estos endpoints
export async function requireAdmin(req, res) {
  if (req.method !== 'POST') { res.status(405).json({ error: 'Método no permitido' }); return null; }
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) { res.status(401).json({ error: 'No autenticado' }); return null; }
  const r = await fetch(`${U}/auth/v1/user`, { headers: { apikey: K, Authorization: `Bearer ${token}` } });
  if (!r.ok) { res.status(401).json({ error: 'Sesión inválida' }); return null; }
  const u = await r.json(); let amr = [];
  try { amr = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString()).amr || []; } catch {}
  const adm = await sbRest(`admins?email=eq.${encodeURIComponent((u.email || '').toLowerCase())}&select=email`);
  if (!amr.some(a => a.method === 'oauth') || !adm?.length) { res.status(403).json({ error: 'No autorizado' }); return null; }
  return u;
}
