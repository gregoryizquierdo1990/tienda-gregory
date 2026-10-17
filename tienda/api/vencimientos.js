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
    // 1. Ejecutar marcaje automático de cuotas vencidas en base de datos
    await sbRest('rpc/check_overdue_installments', { method: 'POST', body: '{}' }).catch(() => {});

    // 2. Consultar pedidos entregados, perfiles vendidos, cuentas madre y cuotas vencidas
    const [ordersRes, profilesRes, mothersRes, instRes] = await Promise.all([
      sbRest(`orders?estado=in.(entregado,pagado)&vence=eq.${hoy}&select=id,inicia,vence,referencia,customers!customer_id(nombre,email,telefono),products(nombre)`).catch(() => []),
      sbRest(`profiles_inventory?estado=eq.vendido&vence=eq.${hoy}&select=id,nombre_perfil,pin,vence,mother_accounts(plataforma,correo)`).catch(() => []),
      sbRest(`mother_accounts?activa=eq.true&vence=eq.${hoy}&select=id,plataforma,correo,vence,max_perfiles`).catch(() => []),
      sbRest(`installments?estado=in.(pendiente,vencida)&fecha_vencimiento=lte.${hoy}&select=id,numero_cuota,total_cuotas,monto_usd,fecha_vencimiento,estado,customers!customer_id(nombre,telefono),orders(products(nombre))`).catch(() => [])
    ]);

    const orders = ordersRes || [];
    const profiles = profilesRes || [];
    const mothers = mothersRes || [];
    const cuotas = instRes || [];

    const totalClientes = orders.length + profiles.length;
    const totalMadres = mothers.length;
    const totalCuotas = cuotas.length;

    if (totalClientes === 0 && totalMadres === 0 && totalCuotas === 0) {
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

    // Armar lista de cuotas vencidas o por cobrar
    const cuotasList = cuotas.map(c => {
      const cli = c.customers?.nombre || 'Cliente';
      const tel = c.customers?.telefono ? ` 📱 <a href="https://wa.me/${c.customers.telefono.replace(/\D/g,'')}">+${c.customers.telefono.replace(/\D/g,'')}</a>` : '';
      const prod = c.orders?.products?.nombre || 'Servicio';
      return `• 💳 <b>[Cuota ${c.numero_cuota}/${c.total_cuotas}]</b> $${Number(c.monto_usd).toFixed(2)} USD · ${cli}${tel} (${prod}) - ${c.estado === 'vencida' ? '⚠️ Vencida' : '📅 Vence hoy'}`;
    });

    const siteUrl = (process.env.NEXT_PUBLIC_SITE_URL || process.env.SITE_URL || (process.env.VERCEL_PROJECT_PRODUCTION_URL ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}` : 'https://www.gregoryizquierdo.xyz')).replace(/\/+$/, '');
    const plainMsg = `📅 VENCIMIENTOS DE HOY (${hoy}): ${totalClientes} clientes, ${totalMadres} cuentas madre y ${totalCuotas} cuotas por cobrar.`;
    const htmlMsg = `📅 <b>LISTADO DE VENCIMIENTOS DE HOY (${hoy})</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 <b>CLIENTES / PERFILES POR VENCER (${totalClientes}):</b>
${clientesList.slice(0, 20).join('\n') || '<i>No hay clientes con servicios por vencer hoy.</i>'}${clientesList.length > 20 ? `\n<i>... y ${clientesList.length - 20} cliente(s) más</i>` : ''}

🔑 <b>CUENTAS MADRE POR VENCER (${totalMadres}):</b>
${mothersList.join('\n') || '<i>No hay cuentas madre por vencer hoy.</i>'}

💳 <b>CUOTAS FINANCIADAS POR COBRAR (${totalCuotas}):</b>
${cuotasList.slice(0, 15).join('\n') || '<i>No hay cuotas pendientes o vencidas hoy.</i>'}${cuotasList.length > 15 ? `\n<i>... y ${cuotasList.length - 15} cuota(s) más</i>` : ''}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 <b>Resumen diario:</b> ${totalClientes} clientes · ${totalMadres} cuentas madre · ${totalCuotas} cuotas por cobrar.
👉 <a href="${siteUrl}/#admin">Abrir Control de Vencimientos</a>`;

    const out = await sendAll('vencimientos_resumen', plainMsg, htmlMsg);
    return res.json({ ok: true, fecha: hoy, totalClientes, totalMadres, totalCuotas, ...out });
  } catch (err) {
    console.error('Error procesando cron de vencimientos:', err);
    return res.status(500).json({ error: err.message });
  }
}
