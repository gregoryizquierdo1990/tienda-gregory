// Cron Diario Unificado para Vercel (Plan Hobby - Máximo 1 Cron Diario):
// Programado en vercel.json a las "0 12 * * *" (12:00 UTC = 8:00 AM Venezuela UTC-4).
//
// Flujo de ejecución en cadena:
// 1. Actualización Automática de Tasa Oficial BCV desde DolarAPI y resguardo en Supabase.
// 2. Verificación y marcaje de cuotas BNPL en mora (check_overdue_installments).
// 3. AGENTE ESTEBAN (@agenteesteban_bot) - Reporte Matutino Oficial (8:00 AM):
//    - Tasas oficiales (BCV actualizada + USDT Mesa de Cambio)
//    - Cuentas Madre por vencer hoy
//    - Clientes Directos y de Revendedores por vencer hoy (con links y copys WhatsApp listos)
//    - Nuevos Usuarios registrados en las últimas 24h
//    - Solicitudes de ascenso a Revendedor
//    - Solicitudes pendientes de recarga en Billetera Zeny
// 4. AGENTE RAMSES (@agenteramses_bot) - Soporta ejecución de cierre de caja (ayer u hoy en demanda).

import { sbRest, formatearFecha } from './_lib.js';
import { sendEsteban, sendRamses, sendMilos } from './_notify.js';

export default async function handler(req, res) {
  // Verificación de seguridad CRON_SECRET de Vercel (si está configurado)
  if (process.env.CRON_SECRET && req.headers.authorization && req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'No autorizado' });
  }

  const vzlaNow = new Date(Date.now() - 4 * 3600e3);
  const hoy = req.query?.fecha || vzlaNow.toISOString().slice(0, 10);
  const ayer = new Date(Date.now() - 28 * 3600e3).toISOString().slice(0, 10);
  const hace24h = new Date(Date.now() - 24 * 3600e3).toISOString();
  const tipo = req.query?.tipo || 'matutino'; // 'matutino', 'cierre', 'ambos'

  const escHtml = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const cleanTel = t => String(t || '').replace(/\D/g, '');
  const toWaLink = (tel, text) => {
    const d = cleanTel(tel);
    if (!d) return '';
    const full = d.startsWith('58') ? d : (d.startsWith('0') ? '58' + d.slice(1) : '58' + d);
    return `https://wa.me/${full}?text=${encodeURIComponent(text)}`;
  };

  const resultados = {
    fecha: hoy,
    hora_vzla: vzlaNow.toISOString().slice(11, 16),
    tasa_bcv_actualizada: false,
    tasa_bcv: 0,
    tasa_usdt: 0,
    reportes_enviados: []
  };

  try {
    // =========================================================================
    // PASO 1: ACTUALIZACIÓN AUTOMÁTICA DE TASA OFICIAL BCV
    // =========================================================================
    try {
      const r = await fetch('https://ve.dolarapi.com/v1/dolares/oficial', { headers: { Accept: 'application/json' } });
      if (r.ok) {
        const j = await r.json();
        const tasa = Number(j.promedio ?? j.venta ?? j.compra ?? j.price);
        if (tasa > 0 && Number.isFinite(tasa)) {
          await sbRest('exchange_rates?on_conflict=fecha', {
            method: 'POST',
            headers: { Prefer: 'resolution=merge-duplicates' },
            body: JSON.stringify({ fecha: hoy, bs_por_usd: tasa, fuente: 'BCV' })
          });
          resultados.tasa_bcv_actualizada = true;
          resultados.tasa_bcv = tasa;
        }
      }
    } catch (eTasa) {
      console.warn('Advertencia actualizando tasa BCV en cron diario:', eTasa.message);
    }

    // =========================================================================
    // PASO 2: OBTENER TASAS VIGENTES Y MARCAJE DE CUOTAS BNPL
    // =========================================================================
    await sbRest('rpc/check_overdue_installments', { method: 'POST', body: '{}' }).catch(() => {});

    const [rateRes, mcCfgRes] = await Promise.all([
      sbRest('exchange_rates?select=bs_por_usd,fecha&order=fecha.desc&limit=1').catch(() => []),
      sbRest('settings?key=eq.mesa_cambio_config&select=value').catch(() => [])
    ]);

    const tasaBcv = Number(rateRes?.[0]?.bs_por_usd || resultados.tasa_bcv || 1);
    resultados.tasa_bcv = tasaBcv;
    const mcVal = mcCfgRes?.[0]?.value || {};
    const tasaUsdt = Number(mcVal?.tasa_usdt_bs || 0);
    resultados.tasa_usdt = tasaUsdt;

    // =========================================================================
    // PASO 3: REPORTE MATUTINO (8:00 AM) - AGENTE ESTEBAN (@agenteesteban_bot)
    // =========================================================================
    if (tipo === 'matutino' || tipo === 'ambos') {
      const [
        newUsersRes,
        solicitudesRevRes,
        recargasZenyPendRes,
        mothersRes,
        directOrdersRes,
        profilesRes
      ] = await Promise.all([
        sbRest(`customers?creado=gte.${hace24h}&order=creado.desc&select=id,nombre,email,telefono,codigo_identificacion,creado,es_revendedor`).catch(() => []),
        sbRest(`customers?solicita_revendedor=eq.true&es_revendedor=eq.false&order=solicita_revendedor_at.desc&select=id,nombre,email,telefono,codigo_identificacion,solicita_revendedor_at`).catch(() => []),
        sbRest(`zeny_ledger?tipo=eq.recarga&estado=eq.pendiente&order=created_at.desc&select=id,monto,referencia,created_at,customers(nombre,telefono,codigo_identificacion)`).catch(() => []),
        sbRest(`mother_accounts?activa=eq.true&vence=eq.${hoy}&select=id,plataforma,correo,vence,max_perfiles,proveedor`).catch(() => []),
        sbRest(`orders?estado=in.(entregado,pagado)&vence=eq.${hoy}&select=id,inicia,vence,referencia,total_usd,customers!customer_id(id,nombre,email,telefono,telegram_chat_id,es_revendedor),products(nombre)`).catch(() => []),
        sbRest(`profiles_inventory?estado=eq.vendido&vence=eq.${hoy}&select=id,nombre_perfil,pin,vence,cliente_final,cliente_telefono,vendedor,mother_accounts(plataforma,correo)`).catch(() => [])
      ]);

      const newUsers = newUsersRes || [];
      const solicitudesRev = solicitudesRevRes || [];
      const recargasZenyPend = recargasZenyPendRes || [];
      const mothers = mothersRes || [];
      const directOrders = directOrdersRes || [];
      const profiles = profilesRes || [];

      // 1. Resumen General y Tasas
      const totalVencimientos = directOrders.length + profiles.length;
      let estebanSummary = `🌅 <b>REPORTE MATUTINO DE GESTIÓN (8:00 AM)</b>\n` +
        `🤖 <i>Agente Esteban · Emprendimiento Gregory</i>\n` +
        `📅 <b>Fecha:</b> ${formatearFecha(hoy)}\n` +
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
      resultados.reportes_enviados.push('Esteban: Resumen Matutino');

      // 2. Cuentas Madres por vencer
      if (mothers.length > 0) {
        let msgMadres = `🔑 <b>2. CUENTAS MADRE POR VENCER HOY (${formatearFecha(hoy)})</b>\n` +
          `Total a renovar con proveedores: <b>${mothers.length}</b>\n` +
          `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

        mothers.forEach((m, idx) => {
          msgMadres += `${idx + 1}. <b>${escHtml(m.plataforma || 'Plataforma')}</b>\n` +
            `   📧 <code>${escHtml(m.correo)}</code>\n` +
            `   🤝 Proveedor: <b>${escHtml(m.proveedor || 'No especificado')}</b>\n` +
            `   👥 Perfiles: ${m.max_perfiles || 5}\n\n`;
        });
        msgMadres += `⚠️ <i>Gestionar la renovación con el proveedor para no interrumpir pantallas.</i>`;
        await sendEsteban(msgMadres);
        resultados.reportes_enviados.push(`Esteban: Cuentas Madre (${mothers.length})`);
      }

      // 3. Vencimientos de Clientes Directos
      if (directOrders.length > 0) {
        let msgCliDirectos = `📅 <b>3. VENCIMIENTOS DE CLIENTES DIRECTOS (${directOrders.length})</b>\n` +
          `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

        for (const o of directOrders) {
          const cliNom = o.customers?.nombre || o.customers?.email || 'Cliente';
          const srvNom = o.products?.nombre || 'Suscripción Digital';
          const tel = o.customers?.telefono || '';
          const cChatId = o.customers?.telegram_chat_id;

          const waText = `¡Hola ${cliNom}! 👋 Te saluda Gregory Izquierdo.\n` +
            `Te recordamos que hoy *${formatearFecha(hoy)}* se cumple el vencimiento de tu servicio *${srvNom}*.\n` +
            `Para mantener tu perfil activo sin cortes, renueva directamente en nuestra tienda:\n` +
            `🌐 https://www.gregoryizquierdo.xyz\n` +
            `O contáctanos por WhatsApp al 04242809333. ¡Muchas gracias por tu preferencia! ⭐`;

          const waLink = toWaLink(tel, waText);

          msgCliDirectos += `👤 <b>${escHtml(cliNom)}</b> · ${escHtml(srvNom)}\n` +
            (tel ? `📱 Teléfono: <code>${cleanTel(tel)}</code> ${waLink ? `👉 <a href="${waLink}">Enviar WhatsApp</a>` : ''}\n` : '') +
            `📝 <b>Copy listo para WhatsApp:</b>\n<code>${escHtml(waText)}</code>\n\n`;

          if (cChatId) {
            const directTg = `👋 ¡Hola <b>${escHtml(cliNom)}</b>!\n\n` +
              `⏱ Te recordamos que hoy <b>${formatearFecha(hoy)}</b> vence tu servicio de <b>${escHtml(srvNom)}</b>.\n\n` +
              `Renueva tus accesos en línea:\n` +
              `🌐 <a href="https://www.gregoryizquierdo.xyz">https://www.gregoryizquierdo.xyz</a>\n` +
              `⚡ O por Pago Móvil al 04242809333. ¡Gracias por preferirnos!`;
            await sendMilos(directTg, null, cChatId).catch(() => {});
          }
        }

        await sendEsteban(msgCliDirectos);
        resultados.reportes_enviados.push(`Esteban: Clientes Directos (${directOrders.length})`);
      }

      // 3B. Vencimientos de Perfiles de Revendedores
      if (profiles.length > 0) {
        let msgPerfiles = `👥 <b>3B. VENCIMIENTOS DE PERFILES / CLIENTES DE REVENDEDOR (${profiles.length})</b>\n` +
          `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

        for (const p of profiles) {
          const cliNom = p.cliente_final || 'Cliente';
          const srvNom = `${p.mother_accounts?.plataforma || 'Servicio'} (${p.nombre_perfil || 'Perfil'})`;
          const tel = p.cliente_telefono || '';
          const revendedor = p.vendedor || 'Revendedor';

          const waText = `¡Hola ${cliNom}! 👋 Te saludamos de parte de tu asesor ${revendedor}.\n` +
            `Te recordamos que hoy *${formatearFecha(hoy)}* vence tu perfil de *${srvNom}*.\n` +
            `Comunícate con nosotros para renovar tu pantalla y no perder tus contenidos. ¡Gracias! ⭐`;

          const waLink = toWaLink(tel, waText);

          msgPerfiles += `👤 <b>${escHtml(cliNom)}</b> [Asesor: <i>${escHtml(revendedor)}</i>]\n` +
            `📺 Servicio: ${escHtml(srvNom)}\n` +
            (tel ? `📱 Teléfono: <code>${cleanTel(tel)}</code> ${waLink ? `👉 <a href="${waLink}">Enviar WhatsApp</a>` : ''}\n` : '') +
            `📝 <b>Copy listo para WhatsApp:</b>\n<code>${escHtml(waText)}</code>\n\n`;
        }

        await sendEsteban(msgPerfiles);
        resultados.reportes_enviados.push(`Esteban: Clientes Revendedor (${profiles.length})`);
      }

      // 4. Nuevos Usuarios Registrados
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
        resultados.reportes_enviados.push(`Esteban: Nuevos Registros (${newUsers.length})`);
      }

      // 5. Solicitudes de Revendedor
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
            `   📅 Fecha: <code>${s.solicita_revendedor_at ? formatearFecha(s.solicita_revendedor_at) : 'Reciente'}</code>\n\n`;
        });

        msgSolRev += `👉 <a href="https://www.gregoryizquierdo.xyz/#admin">Aprobar en Red de Revendedores</a>`;
        await sendEsteban(msgSolRev);
        resultados.reportes_enviados.push(`Esteban: Solicitudes Revendedor (${solicitudesRev.length})`);
      }

      // 6. Solicitudes de Recarga Zeny
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
        resultados.reportes_enviados.push(`Esteban: Recargas Zeny Pendientes (${recargasZenyPend.length})`);
      }
    }

    // =========================================================================
    // PASO 4: REPORTE DE CIERRE - AGENTE RAMSES (@agenteramses_bot)
    // =========================================================================
    // Si se invoca en demanda o con ?tipo=cierre o ?tipo=ambos
    if (tipo === 'cierre' || tipo === 'ambos') {
      const fechaCierre = req.query?.fecha_cierre || (tipo === 'ambos' ? ayer : hoy);
      const inicioDia = `${fechaCierre}T00:00:00-04:00`;
      const finDia = `${fechaCierre}T23:59:59-04:00`;

      const [
        ventasRes,
        gastosRes,
        comprasRes,
        refundsRes,
        zenyAprobadosRes,
        usdtAprobadosRes
      ] = await Promise.all([
        sbRest(`orders?created_at=gte.${inicioDia}&created_at=lte.${finDia}&select=id,total_usd,total_bs,estado,referencia,products(nombre),customers(nombre)`).catch(() => []),
        sbRest(`expenses?fecha=eq.${fechaCierre}&select=id,concepto,categoria,monto_usd,monto_bs,notas`).catch(() => []),
        sbRest(`purchases?fecha=eq.${fechaCierre}&select=id,proveedor,plataforma,monto_usd,monto_usdt,monto_bs,es_credito,estado_pago`).catch(() => []),
        sbRest(`refunds?created_at=gte.${inicioDia}&created_at=lte.${finDia}&select=id,monto_usd,motivo,customers(nombre)`).catch(() => []),
        sbRest(`zeny_ledger?tipo=eq.recarga&estado=eq.aprobado&created_at=gte.${inicioDia}&created_at=lte.${finDia}&select=id,monto,referencia,customers(nombre)`).catch(() => []),
        sbRest(`mesa_cambio_operaciones?estado=in.(completado,aprobado)&created_at=gte.${inicioDia}&created_at=lte.${finDia}&select=id,monto_usdt,total_bs,tasa_bs,cliente_nombre,referencia_bancaria`).catch(() => [])
      ]);

      const ventas = ventasRes || [];
      const gastos = gastosRes || [];
      const compras = comprasRes || [];
      const devoluciones = refundsRes || [];
      const zenyAprobados = zenyAprobadosRes || [];
      const usdtAprobados = usdtAprobadosRes || [];

      const totalVentasUsd = ventas.filter(v => ['entregado', 'pagado'].includes(v.estado)).reduce((a, v) => a + Number(v.total_usd || 0), 0);
      const totalGastosUsd = gastos.reduce((a, g) => a + Number(g.monto_usd || 0), 0);
      const totalComprasUsd = compras.reduce((a, c) => a + Number(c.monto_usd || c.monto_usdt || 0), 0);
      const totalDevolucionesUsd = devoluciones.reduce((a, d) => a + Number(d.monto_usd || 0), 0);
      const totalZenyAprobadoUsd = zenyAprobados.reduce((a, z) => a + Number(z.monto || 0), 0);
      const totalUsdtAprobado = usdtAprobados.reduce((a, u) => a + Number(u.monto_usdt || 0), 0);
      const totalUsdtBs = usdtAprobados.reduce((a, u) => a + Number(u.total_bs || 0), 0);

      const balanceNetoUsd = totalVentasUsd - totalGastosUsd - totalComprasUsd - totalDevolucionesUsd;

      let ramsesMsg = `🌙 <b>REPORTE FINANCIERO Y AUDITORÍA DE CAJA</b>\n` +
        `🤖 <i>Agente Ramses · Auditor Financiero</i>\n` +
        `📅 <b>Período Evaluado:</b> ${formatearFecha(fechaCierre)} · 📊 <b>Tasa BCV:</b> <b>${tasaBcv.toFixed(4)} Bs/USD</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `📊 <b>BALANCE FINANCIERO CONSOLIDADO:</b>\n\n` +
        `1. 🛒 <b>VENTAS:</b>\n` +
        `   • Pedidos cobrados: <b>${ventas.filter(v => ['entregado', 'pagado'].includes(v.estado)).length}</b>\n` +
        `   • Total Ventas: <b>$${totalVentasUsd.toFixed(2)} USD</b> (Bs. ${(totalVentasUsd * tasaBcv).toLocaleString('es-VE', { minimumFractionDigits: 2 })})\n\n` +
        `2. 📉 <b>GASTOS OPERATIVOS:</b>\n` +
        `   • Registros de gasto: <b>${gastos.length}</b>\n` +
        `   • Total Gastos: <b>$${totalGastosUsd.toFixed(2)} USD</b>\n\n` +
        `3. 🛍️ <b>COMPRAS A PROVEEDORES:</b>\n` +
        `   • Compras: <b>${compras.length}</b>\n` +
        `   • Total Invertido: <b>$${totalComprasUsd.toFixed(2)} USD</b>\n\n` +
        `4. 🔄 <b>DEVOLUCIONES & REEMBOLSOS:</b>\n` +
        `   • Casos atendidos: <b>${devoluciones.length}</b>\n` +
        `   • Total Devoluciones: <b>$${totalDevolucionesUsd.toFixed(2)} USD</b>\n\n` +
        `5. 💰 <b>SALDO ZENY APROBADO:</b>\n` +
        `   • Recargas acreditadas: <b>${zenyAprobados.length}</b>\n` +
        `   • Monto Aprobado: <b>+$${totalZenyAprobadoUsd.toFixed(2)} USD</b>\n\n` +
        `6. 💱 <b>COMPRAS DE USDT APROBADAS (MESA DE CAMBIO):</b>\n` +
        `   • Operaciones: <b>${usdtAprobados.length}</b>\n` +
        `   • Total USDT Entregado: <b>$${totalUsdtAprobado.toFixed(2)} USDT</b>\n` +
        `   • Bolívares Recibidos: <b>Bs. ${totalUsdtBs.toLocaleString('es-VE', { minimumFractionDigits: 2 })}</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `📈 <b>RESULTADO OPERATIVO NETO:</b> <b>$${balanceNetoUsd.toFixed(2)} USD</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `👉 <a href="https://www.gregoryizquierdo.xyz/#admin">Ver Libro Contable Completo</a>`;

      await sendRamses(ramsesMsg);
      resultados.reportes_enviados.push(`Ramses: Reporte Cierre (${fechaCierre})`);
    }

    return res.status(200).json({ ok: true, ...resultados });
  } catch (err) {
    console.error('Error en cron ejecutar-reportes-diarios:', err);
    return res.status(500).json({ error: err.message, stack: err.stack });
  }
}
