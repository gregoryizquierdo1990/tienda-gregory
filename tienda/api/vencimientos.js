// Motor de Notificaciones Automáticas y Reportes Programados:
// 1. ESTEBAN BOT (@agenteesteban_bot): Reporte Matutino Diario (8:00 AM)
//    - Tasa de Cambio BCV y USDT
//    - Vencimientos de Cuentas Madre
//    - Vencimientos de Clientes Directos y de Revendedores (mensajes separados y listos para WhatsApp)
//    - Nuevos usuarios registrados (24h)
//    - Solicitudes de ascenso a revendedor
//    - Solicitudes de recarga de billetera Zeny
//
// 2. RAMSES BOT (@agenteramses_bot): Reporte de Cierre Diario (9:00 PM)
//    - Ventas del día
//    - Gastos operativos del día
//    - Compras a proveedores del día
//    - Devoluciones y reembolsos del día
//    - Saldo Zeny aprobado del día
//    - Compras de USDT aprobadas en Mesa de Cambio
//
// 3. MILOS BOT (@agentemilos_bot): Notificaciones directas a clientes vinculados

import { sbRest, getSecret } from './_lib.js';
import { sendEsteban, sendRamses, sendMilos, ADMIN_CHAT_ID } from './_notify.js';

export default async function handler(req, res) {
  const hoy = req.query?.fecha || new Date(Date.now() - 4 * 3600e3).toISOString().slice(0, 10);
  const hace24h = new Date(Date.now() - 24 * 3600e3).toISOString();
  const requestedTipo = req.query?.tipo || null; // 'matutino', 'cierre', o automático por hora

  const vzlaDate = new Date(Date.now() - 4 * 3600e3);
  const horaVzla = vzlaDate.getUTCHours();

  const escHtml = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const cleanTel = t => String(t || '').replace(/\D/g, '');
  const toWaLink = (tel, text) => {
    const d = cleanTel(tel);
    if (!d) return '';
    const full = d.startsWith('58') ? d : (d.startsWith('0') ? '58' + d.slice(1) : '58' + d);
    return `https://wa.me/${full}?text=${encodeURIComponent(text)}`;
  };

  try {
    // Marcaje automático de cuotas vencidas
    await sbRest('rpc/check_overdue_installments', { method: 'POST', body: '{}' }).catch(() => {});

    // Tasas oficiales: BCV y Mesa de Cambio USDT
    const [rateRes, mcCfgRes] = await Promise.all([
      sbRest('exchange_rates?select=bs_por_usd,fecha&order=fecha.desc&limit=1').catch(() => []),
      sbRest('settings?key=eq.mesa_cambio_config&select=value').catch(() => [])
    ]);

    const tasaBcv = Number(rateRes?.[0]?.bs_por_usd || 1);
    const mcVal = mcCfgRes?.[0]?.value || {};
    const tasaUsdt = Number(mcVal?.tasa_usdt_bs || 0);

    const ejecutarCierre = requestedTipo === 'cierre' || (requestedTipo == null && (horaVzla >= 19 || horaVzla < 4));
    const ejecutarMatutino = requestedTipo === 'matutino' || (requestedTipo == null && (horaVzla >= 4 && horaVzla < 19));

    const outResults = {
      fecha: hoy,
      hora_vzla: `${String(horaVzla).padStart(2, '0')}:${String(vzlaDate.getUTCMinutes()).padStart(2, '0')}`,
      tasa_bcv: tasaBcv,
      tasa_usdt: tasaUsdt,
      reportes: []
    };

    // =========================================================================
    // 1. REPORTE MATUTINO (8:00 AM) - ESTEBAN BOT (@agenteesteban_bot)
    // =========================================================================
    if (ejecutarMatutino) {
      const [
        newUsersRes,
        solicitudesRevRes,
        recargasZenyPendRes,
        mothersRes,
        directOrdersRes,
        profilesRes
      ] = await Promise.all([
        // 4. Registro de Nuevos Usuarios últimas 24h
        sbRest(`customers?creado=gte.${hace24h}&order=creado.desc&select=id,nombre,email,telefono,codigo_identificacion,creado,es_revendedor`).catch(() => []),
        // 5. Solicitudes de Ascenso a revendedores pendientes
        sbRest(`customers?solicita_revendedor=eq.true&es_revendedor=eq.false&order=solicita_revendedor_at.desc&select=id,nombre,email,telefono,codigo_identificacion,solicita_revendedor_at`).catch(() => []),
        // 6. Solicitudes de recarga billetera zeny pendientes
        sbRest(`zeny_ledger?tipo=eq.recarga&estado=eq.pendiente&order=created_at.desc&select=id,monto,referencia,created_at,customers(nombre,telefono,codigo_identificacion)`).catch(() => []),
        // 2. Vencimientos de cuentas madres que vencen hoy
        sbRest(`mother_accounts?activa=eq.true&vence=eq.${hoy}&select=id,plataforma,correo,vence,max_perfiles,proveedor`).catch(() => []),
        // 3. Suscripciones directas que vencen hoy
        sbRest(`orders?estado=in.(entregado,pagado)&vence=eq.${hoy}&select=id,inicia,vence,referencia,total_usd,customers!customer_id(id,nombre,email,telefono,telegram_chat_id,es_revendedor),products(nombre)`).catch(() => []),
        // 3. Perfiles vendidos asignados que vencen hoy (con datos de revendedor si aplica)
        sbRest(`profiles_inventory?estado=eq.vendido&vence=eq.${hoy}&select=id,nombre_perfil,pin,vence,cliente_final,cliente_telefono,vendedor,mother_accounts(plataforma,correo)`).catch(() => [])
      ]);

      const newUsers = newUsersRes || [];
      const solicitudesRev = solicitudesRevRes || [];
      const recargasZenyPend = recargasZenyPendRes || [];
      const mothers = mothersRes || [];
      const directOrders = directOrdersRes || [];
      const profiles = profilesRes || [];

      // Mensaje 1 de Esteban: Resumen Matutino y Tasas de Cambio
      const totalVencimientos = directOrders.length + profiles.length;
      let estebanSummary = `🌅 <b>REPORTE MATUTINO DE GESTIÓN (8:00 AM)</b>\n` +
        `🤖 <i>Agente Esteban · Emprendimiento Gregory</i>\n` +
        `📅 <b>Fecha:</b> ${hoy}\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `💱 <b>1. TASAS DE CAMBIO OFICIALES:</b>\n` +
        `• 💵 <b>Tasa BCV Oficial:</b> <b>${tasaBcv.toFixed(4)} Bs/USD</b>\n` +
        `• 💱 <b>Mesa de Cambio USDT:</b> <b>${tasaUsdt > 0 ? `${tasaUsdt.toFixed(2)} Bs/USDT` : 'No configurada'}</b>\n\n` +
        `📊 <b>RESUMEN OPERATIVO DEL DÍA:</b>\n` +
        `• 🔑 <b>Cuentas Madre por vencer:</b> ${mothers.length}\n` +
        `• 📅 <b>Clientes por vencer hoy:</b> ${totalVencimientos} (${directOrders.length} directos · ${profiles.length} perfiles)\n` +
        `• 👤 <b>Nuevos Registros (24h):</b> ${newUsers.length}\n` +
        `• 🎖️ <b>Solicitudes de Revendedor:</b> ${solicitudesRev.length}\n` +
        `• 💰 <b>Recargas Zeny Pendientes:</b> ${recargasZenyPend.length}\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `👉 <a href="https://www.gregoryizquierdo.xyz/#admin">Abrir Panel de Control Admin</a>`;

      await sendEsteban(estebanSummary);
      outResults.reportes.push('Esteban: Resumen Matutino');

      // Mensaje 2 de Esteban: Cuentas Madres que vencen hoy
      if (mothers.length > 0) {
        let msgMadres = `🔑 <b>2. CUENTAS MADRE POR VENCER HOY (${hoy})</b>\n` +
          `Total a renovar con proveedores: <b>${mothers.length}</b>\n` +
          `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

        mothers.forEach((m, idx) => {
          msgMadres += `${idx + 1}. <b>${escHtml(m.plataforma || 'Plataforma')}</b>\n` +
            `   📧 <code>${escHtml(m.correo)}</code>\n` +
            `   🤝 Proveedor: <b>${escHtml(m.proveedor || 'No especificado')}</b>\n` +
            `   👥 Perfiles asignados: ${m.max_perfiles || 5}\n\n`;
        });

        msgMadres += `⚠️ <i>Renovar antes de que finalice la jornada con el proveedor.</i>`;
        await sendEsteban(msgMadres);
        outResults.reportes.push(`Esteban: Cuentas Madre (${mothers.length})`);
      }

      // Mensaje 3 de Esteban: Vencimientos de Clientes Directos y de Revendedores (mensajes separados y listos para WhatsApp)
      if (directOrders.length > 0) {
        let msgCliDirectos = `📅 <b>3. VENCIMIENTOS DE CLIENTES DIRECTOS (${directOrders.length})</b>\n` +
          `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

        for (const o of directOrders) {
          const cliNom = o.customers?.nombre || o.customers?.email || 'Cliente';
          const srvNom = o.products?.nombre || 'Suscripción Digital';
          const tel = o.customers?.telefono || '';
          const cChatId = o.customers?.telegram_chat_id;

          const waText = `Hola ${cliNom}! 👋 Te saluda Gregory Izquierdo.\n` +
            `Te recordamos que hoy *${hoy}* vence tu servicio de *${srvNom}*.\n` +
            `Para mantener tus accesos activos y evitar cortes, puedes renovar directamente en la tienda:\n` +
            `🌐 https://www.gregoryizquierdo.xyz\n` +
            `O por Pago Móvil BDV / BNC (04242809333 - V 18931731).\n¡Gracias por tu preferencia!`;

          const waLink = toWaLink(tel, waText);

          msgCliDirectos += `👤 <b>${escHtml(cliNom)}</b> · ${escHtml(srvNom)}\n` +
            (tel ? `📱 Teléfono: <code>${cleanTel(tel)}</code> ${waLink ? `👉 <a href="${waLink}">Enviar WhatsApp</a>` : ''}\n` : '') +
            `📝 <b>Copy listo para WhatsApp:</b>\n<code>${escHtml(waText)}</code>\n\n`;

          // Aviso directo al cliente mediante Bot Milos si tiene Telegram
          if (cChatId) {
            const directTg = `👋 ¡Hola <b>${escHtml(cliNom)}</b>!\n\n` +
              `⏱ Te recordamos que hoy <b>${hoy}</b> vence tu servicio de <b>${escHtml(srvNom)}</b>.\n\n` +
              `Renueva tus accesos en línea:\n` +
              `🌐 <a href="https://www.gregoryizquierdo.xyz">https://www.gregoryizquierdo.xyz</a>\n` +
              `⚡ O por Pago Móvil al 04242809333 (V 18931731). ¡Gracias por preferirnos!`;
            await sendMilos(directTg, null, cChatId).catch(() => {});
          }
        }

        await sendEsteban(msgCliDirectos);
        outResults.reportes.push(`Esteban: Vencimientos Clientes Directos (${directOrders.length})`);
      }

      if (profiles.length > 0) {
        let msgPerfiles = `👥 <b>3B. VENCIMIENTOS DE PERFILES / CLIENTES DE REVENDEDOR (${profiles.length})</b>\n` +
          `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

        for (const p of profiles) {
          const cliNom = p.cliente_final || 'Cliente';
          const srvNom = `${p.mother_accounts?.plataforma || 'Servicio'} (${p.nombre_perfil || 'Perfil'})`;
          const tel = p.cliente_telefono || '';
          const revendedor = p.vendedor || 'Revendedor';

          const waText = `Hola ${cliNom}! 👋 Te saluda Gregory Izquierdo.\n` +
            `Te recordamos que hoy *${hoy}* vence tu perfil de *${srvNom}* gestionado a través de tu asesor comercial.\n` +
            `Para renovar tus accesos y seguir disfrutando del servicio sin interrupciones, comunícate con nosotros o renueva en:\n` +
            `🌐 https://www.gregoryizquierdo.xyz\n¡Gracias por tu preferencia!`;

          const waLink = toWaLink(tel, waText);

          msgPerfiles += `👤 <b>${escHtml(cliNom)}</b> [Asesor: <i>${escHtml(revendedor)}</i>]\n` +
            `📺 Servicio: ${escHtml(srvNom)}\n` +
            (tel ? `📱 Teléfono: <code>${cleanTel(tel)}</code> ${waLink ? `👉 <a href="${waLink}">Enviar WhatsApp</a>` : ''}\n` : '') +
            `📝 <b>Copy listo para WhatsApp:</b>\n<code>${escHtml(waText)}</code>\n\n`;
        }

        await sendEsteban(msgPerfiles);
        outResults.reportes.push(`Esteban: Vencimientos Clientes Revendedor (${profiles.length})`);
      }

      // Mensaje 4 de Esteban: Nuevos usuarios registrados (24h)
      if (newUsers.length > 0) {
        let msgNuevos = `👤 <b>4. NUEVOS USUARIOS REGISTRADOS EN LA TIENDA (ÚLTIMAS 24H: ${newUsers.length})</b>\n` +
          `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

        newUsers.forEach((u, idx) => {
          const nom = u.nombre || 'Usuario';
          const code = u.codigo_identificacion || (u.es_revendedor ? 'RVD' : 'CLT');
          const rol = u.es_revendedor ? 'Revendedor' : 'Cliente';
          const tel = u.telefono ? cleanTel(u.telefono) : '';
          const wa = tel ? toWaLink(tel, `¡Hola ${nom}! 👋 Bienvenido/a a Emprendimiento Gregory.`) : '';

          msgNuevos += `${idx + 1}. <b>${escHtml(nom)}</b> [${rol}] (ID: <code>${escHtml(code)}</code>)\n` +
            `   ✉️ <code>${escHtml(u.email || 'Sin correo')}</code>\n` +
            (tel ? `   📱 Teléfono: <code>${tel}</code> ${wa ? `· <a href="${wa}">Saludar WhatsApp</a>` : ''}\n` : '') +
            `   📅 Registro: <code>${new Date(u.creado).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' })}</code>\n\n`;
        });

        await sendEsteban(msgNuevos);
        outResults.reportes.push(`Esteban: Nuevos Registros (${newUsers.length})`);
      }

      // Mensaje 5 de Esteban: Solicitudes de ascenso a revendedor
      if (solicitudesRev.length > 0) {
        let msgSolRev = `🎖️ <b>5. SOLICITUDES DE ASCENSO A REVENDEDOR (${solicitudesRev.length})</b>\n` +
          `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

        solicitudesRev.forEach((s, idx) => {
          const nom = s.nombre || 'Cliente';
          const tel = s.telefono ? cleanTel(s.telefono) : '';
          const waLink = toWaLink(tel, `¡Hola ${nom}! 👋 Te escribe Gregory Izquierdo respecto a tu solicitud para ser Revendedor Oficial.`);

          msgSolRev += `${idx + 1}. 👤 <b>${escHtml(nom)}</b> (ID: <code>${escHtml(s.codigo_identificacion || 'CLT')}</code>)\n` +
            `   ✉️ <code>${escHtml(s.email || 'Sin correo')}</code>\n` +
            (tel ? `   📱 Teléfono: <code>${tel}</code> ${waLink ? `👉 <a href="${waLink}">Contactar WhatsApp</a>` : ''}\n` : '') +
            `   📅 Fecha: <code>${s.solicita_revendedor_at ? new Date(s.solicita_revendedor_at).toLocaleDateString('es-VE') : 'Reciente'}</code>\n\n`;
        });

        msgSolRev += `👉 <a href="https://www.gregoryizquierdo.xyz/#admin">Aprobar en Red de Revendedores</a>`;
        await sendEsteban(msgSolRev);
        outResults.reportes.push(`Esteban: Solicitudes Revendedor (${solicitudesRev.length})`);
      }

      // Mensaje 6 de Esteban: Solicitudes de recarga billetera Zeny
      if (recargasZenyPend.length > 0) {
        let msgZeny = `💰 <b>6. SOLICITUDES DE RECARGA BILLETERA ZENY PENDIENTES (${recargasZenyPend.length})</b>\n` +
          `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

        recargasZenyPend.forEach((z, idx) => {
          const nom = z.customers?.nombre || 'Cliente';
          const usd = Number(z.monto || 0).toFixed(2);
          const bs = (Number(z.monto || 0) * tasaBcv).toLocaleString('es-VE', { minimumFractionDigits: 2 });
          const ref = z.referencia || 'N/A';

          msgZeny += `${idx + 1}. 👤 <b>${escHtml(nom)}</b>\n` +
            `   💵 <b>$${usd} USD</b> (Bs. ${bs})\n` +
            `   🔢 Referencia: <code>${escHtml(ref)}</code>\n\n`;
        });

        msgZeny += `👉 <a href="https://www.gregoryizquierdo.xyz/#admin">Revisar y Conciliar en Billetera Zeny</a>`;
        await sendEsteban(msgZeny);
        outResults.reportes.push(`Esteban: Recargas Zeny Pendientes (${recargasZenyPend.length})`);
      }
    }

    // =========================================================================
    // 2. REPORTE DE CIERRE (9:00 PM) - RAMSES BOT (@agenteramses_bot)
    // =========================================================================
    if (ejecutarCierre) {
      const inicioDia = `${hoy}T00:00:00-04:00`;
      const [
        ventasRes,
        gastosRes,
        comprasRes,
        refundsRes,
        zenyAprobadosRes,
        usdtAprobadosRes
      ] = await Promise.all([
        // 1. Ventas del día (orders creadas hoy)
        sbRest(`orders?created_at=gte.${inicioDia}&select=id,total_usd,total_bs,estado,referencia,products(nombre),customers(nombre)`).catch(() => []),
        // 2. Gastos operativos del día
        sbRest(`expenses?fecha=eq.${hoy}&select=id,concepto,categoria,monto_usd,monto_bs,notas`).catch(() => []),
        // 3. Compras a proveedores del día
        sbRest(`purchases?fecha=eq.${hoy}&select=id,proveedor,plataforma,monto_usd,monto_usdt,monto_bs,es_credito,estado_pago`).catch(() => []),
        // 4. Devoluciones y reembolsos del día
        sbRest(`refunds?created_at=gte.${inicioDia}&select=id,monto_usd,motivo,customers(nombre)`).catch(() => []),
        // 5. Saldo Zeny aprobados del día
        sbRest(`zeny_ledger?tipo=eq.recarga&estado=eq.aprobado&created_at=gte.${inicioDia}&select=id,monto,referencia,customers(nombre)`).catch(() => []),
        // 6. Compras de USDT aprobadas en Mesa de Cambio
        sbRest(`mesa_cambio_operaciones?estado=in.(completado,aprobado)&created_at=gte.${inicioDia}&select=id,monto_usdt,total_bs,tasa_bs,cliente_nombre,referencia_bancaria`).catch(() => [])
      ]);

      const ventas = ventasRes || [];
      const gastos = gastosRes || [];
      const compras = comprasRes || [];
      const devoluciones = refundsRes || [];
      const zenyAprobados = zenyAprobadosRes || [];
      const usdtAprobados = usdtAprobadosRes || [];

      // Cálculos consolidados
      const totalVentasUsd = ventas.filter(v => ['entregado', 'pagado'].includes(v.estado)).reduce((a, v) => a + Number(v.total_usd || 0), 0);
      const totalGastosUsd = gastos.reduce((a, g) => a + Number(g.monto_usd || 0), 0);
      const totalComprasUsd = compras.reduce((a, c) => a + Number(c.monto_usd || c.monto_usdt || 0), 0);
      const totalDevolucionesUsd = devoluciones.reduce((a, d) => a + Number(d.monto_usd || 0), 0);
      const totalZenyAprobadoUsd = zenyAprobados.reduce((a, z) => a + Number(z.monto || 0), 0);
      const totalUsdtAprobado = usdtAprobados.reduce((a, u) => a + Number(u.monto_usdt || 0), 0);
      const totalUsdtBs = usdtAprobados.reduce((a, u) => a + Number(u.total_bs || 0), 0);

      const balanceNetoUsd = totalVentasUsd - totalGastosUsd - totalComprasUsd - totalDevolucionesUsd;

      let ramsesMsg = `🌙 <b>REPORTE DE CIERRE DIARIO (9:00 PM)</b>\n` +
        `🤖 <i>Agente Ramses · Auditor Financiero de Emprendimiento Gregory</i>\n` +
        `📅 <b>Fecha:</b> ${hoy} · 📊 <b>Tasa BCV:</b> <b>${tasaBcv.toFixed(4)} Bs/USD</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `📊 <b>BALANCE FINANCIERO Y CIERRE DE CAJA:</b>\n\n` +
        `1. 🛒 <b>VENTAS DEL DÍA:</b>\n` +
        `   • Pedidos cobrados: <b>${ventas.filter(v => ['entregado', 'pagado'].includes(v.estado)).length}</b>\n` +
        `   • Total Ventas: <b>$${totalVentasUsd.toFixed(2)} USD</b> (Bs. ${(totalVentasUsd * tasaBcv).toLocaleString('es-VE', { minimumFractionDigits: 2 })})\n\n` +
        `2. 📉 <b>GASTOS OPERATIVOS DEL DÍA:</b>\n` +
        `   • Registros de gasto: <b>${gastos.length}</b>\n` +
        `   • Total Gastos: <b>$${totalGastosUsd.toFixed(2)} USD</b>\n\n` +
        `3. 🛍️ <b>COMPRAS A PROVEEDORES DEL DÍA:</b>\n` +
        `   • Cuentas / Compras: <b>${compras.length}</b>\n` +
        `   • Total Inversión: <b>$${totalComprasUsd.toFixed(2)} USD</b>\n\n` +
        `4. 🔄 <b>DEVOLUCIONES & REEMBOLSOS:</b>\n` +
        `   • Casos atendidos: <b>${devoluciones.length}</b>\n` +
        `   • Total Devoluciones: <b>$${totalDevolucionesUsd.toFixed(2)} USD</b>\n\n` +
        `5. 💰 <b>SALDO ZENY APROBADO:</b>\n` +
        `   • Recargas acreditadas: <b>${zenyAprobados.length}</b>\n` +
        `   • Monto Aprobado: <b>+$${totalZenyAprobadoUsd.toFixed(2)} USD</b>\n\n` +
        `6. 💱 <b>COMPRAS DE USDT APROBADAS (MESA DE CAMBIO):</b>\n` +
        `   • Operaciones completadas: <b>${usdtAprobados.length}</b>\n` +
        `   • Total USDT Despachado: <b>$${totalUsdtAprobado.toFixed(2)} USDT</b>\n` +
        `   • Bolívares Recibidos: <b>Bs. ${totalUsdtBs.toLocaleString('es-VE', { minimumFractionDigits: 2 })}</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `📈 <b>RESULTADO OPERATIVO NETO:</b> <b>$${balanceNetoUsd.toFixed(2)} USD</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `👉 <a href="https://www.gregoryizquierdo.xyz/#admin">Ver Libro Contable Completo en Panel Admin</a>`;

      await sendRamses(ramsesMsg);
      outResults.reportes.push('Ramses: Reporte Cierre 9:00 PM');
    }

    return res.json({
      ok: true,
      ...outResults
    });

  } catch (err) {
    console.error('Error procesando cron de vencimientos y reportes:', err);
    return res.status(500).json({ error: err.message });
  }
}
