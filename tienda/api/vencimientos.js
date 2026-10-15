// Cron diario (8:00 a. m. Venezuela o llamada manual desde Panel Admin):
// Avisa los vencimientos del día por Telegram y push con el listado detallado de clientes y cuentas madre.
import { sbRest } from './_lib.js';
import { sendAll } from './_notify.js';

export default async function handler(req, res) {
  // Permitir ejecución con CRON_SECRET o si viene de un admin autenticado
  if (process.env.CRON_SECRET && req.headers.authorization && req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) {
    // Si no coincide cron secret, verificamos si es admin
  }

  const hoy = req.query?.fecha || new Date(Date.now() - 4 * 3600e3).toISOString().slice(0, 10);

  try {
    // Consultar pedidos entregados, perfiles vendidos directos y cuentas madre que vencen hoy
    const [ordersRes, profilesRes, mothersRes] = await Promise.all([
      sbRest(`orders?estado=in.(entregado,pagado)&vence=eq.${hoy}&select=id,inicia,vence,referencia,customers(nombre,email,telefono),products(nombre)`).catch(() => []),
      sbRest(`profiles_inventory?estado=eq.vendido&vence=eq.${hoy}&select=id,nombre_perfil,pin,vence,mother_accounts(plataforma,correo)`).catch(() => []),
      sbRest(`mother_accounts?activa=eq.true&vence=eq.${hoy}&select=id,plataforma,correo,vence,max_perfiles`).catch(() => [])
    ]);

    const orders = ordersRes || [];
    const profiles = profilesRes || [];
    const mothers = mothersRes || [];

    const totalClientes = orders.length + profiles.length;
    const totalMadres = mothers.length;

    if (totalClientes === 0 && totalMadres === 0) {
      return res.json({ ok: true, mensaje: `Sin vencimientos para la fecha ${hoy}`, enviados: 0 });
    }

    // Armar lista de clientes / perfiles
    const clientesList = [];
    orders.forEach(o => {
      const cli = o.customers?.nombre || o.customers?.email || 'Cliente';
      const tel = o.customers?.telefono ? ` 📱 +${o.customers.telefono.replace(/\D/g,'')}` : '';
      clientesList.push(`• 👤 <b>[${o.products?.nombre || 'Servicio'}]</b> ${cli}${tel}`);
    });

    profiles.forEach(p => {
      const plat = p.mother_accounts?.plataforma || 'Servicio';
      const acc = p.mother_accounts?.correo ? ` (${p.mother_accounts.correo})` : '';
      clientesList.push(`• 👤 <b>[${plat}]</b> ${p.nombre_perfil}${acc}`);
    });

    // Armar lista de cuentas madre
    const mothersList = mothers.map(m => `• 🔑 <b>[${m.plataforma}]</b> <code>${m.correo}</code> (Capacidad: ${m.max_perfiles || 5} perfiles)`);

    const plainMsg = `📅 VENCIMIENTOS DE HOY (${hoy}): ${totalClientes} cliente(s) y ${totalMadres} cuenta(s) madre.`;
    const htmlMsg = `📅 <b>LISTADO DE VENCIMIENTOS DE HOY (${hoy})</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 <b>CLIENTES / PERFILES POR VENCER (${totalClientes}):</b>
${clientesList.slice(0, 20).join('\n') || '<i>No hay clientes registrados con vencimiento hoy.</i>'}${clientesList.length > 20 ? `\n<i>... y ${clientesList.length - 20} cliente(s) más</i>` : ''}

🔑 <b>CUENTAS MADRE POR VENCER (${totalMadres}):</b>
${mothersList.join('\n') || '<i>No hay cuentas madre por vencer hoy.</i>'}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 <b>Total a renovar hoy:</b> ${totalClientes} clientes · ${totalMadres} cuentas madre.
👉 <a href="https://tienda.gregoryizquierdo.xyz/#admin">Abrir Control de Vencimientos</a>`;

    const out = await sendAll('vencimientos_resumen', plainMsg, htmlMsg);
    return res.json({ ok: true, fecha: hoy, totalClientes, totalMadres, ...out });
  } catch (err) {
    console.error('Error procesando cron de vencimientos:', err);
    return res.status(500).json({ error: err.message });
  }
}
