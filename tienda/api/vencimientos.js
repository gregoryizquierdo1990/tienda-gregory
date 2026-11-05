// Cron diario (8:00 a. m. a 9:00 a. m. Venezuela o llamada manual desde Panel Admin):
// DIEGO BOT: Cerebro Administrativo, Reportes y Atención.
// Analiza métricas, nuevos registros, nuevos pedidos, solicitudes de revendedor,
// vencimientos de servicios/cuentas madre, cuentas por cobrar, cuotas en mora y stock crítico.
import { sbRest, getSecret } from './_lib.js';
import { sendTelegram } from './_notify.js';

export default async function handler(req, res) {
  const hoy = req.query?.fecha || new Date(Date.now() - 4 * 3600e3).toISOString().slice(0, 10);
  const hace24h = new Date(Date.now() - 24 * 3600e3).toISOString();
  const tokenBotDiego = await getSecret('telegram_token') || '8535286680:AAGCbVKMNk_aeDHwyICqsAqbtMUjDXlMOMg';

  const escHtml = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const cleanTel = t => String(t || '').replace(/\D/g, '');
  const toWaLink = (tel, text) => {
    const d = cleanTel(tel);
    if (!d) return '';
    const full = d.startsWith('58') ? d : (d.startsWith('0') ? '58' + d.slice(1) : '58' + d);
    return `https://wa.me/${full}?text=${encodeURIComponent(text)}`;
  };

  async function sendDirectTelegramToUser(chatId, text) {
    if (!chatId || !tokenBotDiego) return false;
    try {
      const r = await fetch(`https://api.telegram.org/bot${tokenBotDiego}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: String(chatId),
          text,
          parse_mode: 'HTML',
          disable_web_page_preview: true
        })
      });
      return r.ok;
    } catch {
      return false;
    }
  }

  try {
    // 1. Ejecutar marcaje automático de cuotas vencidas en base de datos
    await sbRest('rpc/check_overdue_installments', { method: 'POST', body: '{}' }).catch(() => {});

    // 2. Obtener tasa BCV oficial
    const rateRes = await sbRest('exchange_rates?select=bs_por_usd,fecha&order=fecha.desc&limit=1').catch(() => []);
    const tasaBcv = Number(rateRes?.[0]?.bs_por_usd || 1);
    const tasaFecha = rateRes?.[0]?.fecha || hoy;

    // 3. Consultar datos en paralelo para reporte integral 24h
    const [
      newUsersRes,
      newOrdersRes,
      solicitudesRevRes,
      ordersRes,
      profilesRes,
      mothersRes,
      instHoyRes,
      instOverdueRes,
      stockRes,
      productsRes
    ] = await Promise.all([
      // Nuevos registros últimas 24h
      sbRest(`customers?creado=gte.${hace24h}&order=creado.desc&select=id,nombre,email,telefono,codigo_identificacion,creado,es_revendedor`).catch(() => []),
      // Nuevos pedidos generados últimas 24h
      sbRest(`orders?created_at=gte.${hace24h}&order=created_at.desc&select=id,created_at,total_usd,total_bs,estado,referencia,customers(nombre,telefono,codigo_identificacion),products(nombre)`).catch(() => []),
      // Solicitudes pendientes de ascenso a revendedor
      sbRest(`customers?solicita_revendedor=eq.true&es_revendedor=eq.false&order=solicita_revendedor_at.desc&select=id,nombre,email,telefono,codigo_identificacion,solicita_revendedor_at`).catch(() => []),
      // Suscripciones directas que vencen hoy
      sbRest(`orders?estado=in.(entregado,pagado)&vence=eq.${hoy}&select=id,inicia,vence,referencia,customers!customer_id(id,nombre,email,telefono,telegram_chat_id),products(nombre)`).catch(() => []),
      // Perfiles vendidos que vencen hoy
      sbRest(`profiles_inventory?estado=eq.vendido&vence=eq.${hoy}&select=id,nombre_perfil,pin,vence,cliente_final,cliente_telefono,mother_accounts(plataforma,correo)`).catch(() => []),
      // Cuentas madre que vencen hoy
      sbRest(`mother_accounts?activa=eq.true&vence=eq.${hoy}&select=id,plataforma,correo,vence,max_perfiles,proveedor`).catch(() => []),
      // Cuotas del día de hoy
      sbRest(`installments?estado=in.(pendiente,en_revision)&fecha_vencimiento=eq.${hoy}&select=id,numero_cuota,total_cuotas,monto_usd,fecha_vencimiento,estado,customers!customer_id(id,nombre,telefono,telegram_chat_id),orders(products(nombre))`).catch(() => []),
      // Cuotas vencidas en mora
      sbRest(`installments?estado=eq.vencida&fecha_vencimiento=lt.${hoy}&select=id,numero_cuota,total_cuotas,monto_usd,fecha_vencimiento,estado,customers!customer_id(id,nombre,telefono,telegram_chat_id),orders(products(nombre))`).catch(() => []),
      // Inventario actual disponible
      sbRest('rpc/stock').catch(() => []),
      // Catálogo de productos activos
      sbRest('products?activo=eq.true&tipo=in.(pantalla,cuenta_completa)&select=id,nombre,tipo').catch(() => [])
    ]);

    const newUsers = newUsersRes || [];
    const newOrders = newOrdersRes || [];
    const solicitudesRev = solicitudesRevRes || [];
    const orders = ordersRes || [];
    const profiles = profilesRes || [];
    const mothers = mothersRes || [];
    const cuotasHoy = instHoyRes || [];
    const cuotasVencidas = instOverdueRes || [];
    const stockMap = Object.fromEntries((stockRes || []).map(s => [s.product_id, Number(s.disponibles || 0)]));
    const activeProducts = productsRes || [];

    // Detectar stock crítico y agotado
    const agotados = activeProducts.filter(p => (stockMap[p.id] || 0) <= 0);
    const criticos = activeProducts.filter(p => (stockMap[p.id] || 0) > 0 && (stockMap[p.id] || 0) <= 1);

    const clientesTotal = orders.length + profiles.length;
    const totalOrdersUsd = newOrders.reduce((acc, o) => acc + Number(o.total_usd || 0), 0);
    const totalOrdersBs = totalOrdersUsd * tasaBcv;
    const totalCuotasHoyUsd = cuotasHoy.reduce((acc, c) => acc + Number(c.monto_usd || 0), 0);
    const totalCuotasHoyBs = totalCuotasHoyUsd * tasaBcv;
    const totalCuotasMoraUsd = cuotasVencidas.reduce((acc, c) => acc + Number(c.monto_usd || 0), 0);
    const totalCuotasMoraBs = totalCuotasMoraUsd * tasaBcv;

    const reportesEnviados = [];

    // =========================================================================
    // BLOQUE 0: RESUMEN EJECUTIVO MATUTINO (8:00 AM)
    // =========================================================================
    const resumenMatutinoHtml = `🌅 <b>REPORTE MATUTINO DE GESTIÓN (8:00 AM)</b>\n` +
      `📅 <b>Fecha:</b> ${hoy} · 📊 <b>Tasa BCV:</b> <b>${tasaBcv.toFixed(4)} Bs/USD</b>\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `📈 <b>MÉTRICAS 24H & GESTIÓN DEL DÍA:</b>\n` +
      `• 👤 <b>Nuevos Registros (24h):</b> ${newUsers.length}\n` +
      `• 🛒 <b>Nuevos Pedidos (24h):</b> ${newOrders.length} ($${totalOrdersUsd.toFixed(2)} USD · Bs. ${totalOrdersBs.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })})\n` +
      `• 🎖️ <b>Solicitudes de Revendedor:</b> ${solicitudesRev.length} pendientes\n` +
      `• 📅 <b>Suscripciones por Vencer Hoy:</b> ${clientesTotal}\n` +
      `• 🔑 <b>Cuentas Madre por Vencer Hoy:</b> ${mothers.length}\n` +
      `• 💳 <b>Cuentas por Cobrar Hoy:</b> ${cuotasHoy.length} ($${totalCuotasHoyUsd.toFixed(2)} USD · Bs. ${totalCuotasHoyBs.toLocaleString('es-VE', { minimumFractionDigits: 2 })})\n` +
      `• ⚠️ <b>Cuotas Vencidas en Mora:</b> ${cuotasVencidas.length} ($${totalCuotasMoraUsd.toFixed(2)} USD)\n` +
      `• 🚨 <b>Stock Crítico / Agotado:</b> ${agotados.length} agotados, ${criticos.length} con stock bajo\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `👉 <a href="https://www.gregoryizquierdo.xyz/#admin">Abrir Panel de Control Admin</a>`;

    await sendTelegram(resumenMatutinoHtml);
    reportesEnviados.push('Resumen Ejecutivo 8:00 AM');

    // =========================================================================
    // BLOQUE 1: NUEVOS REGISTROS DE USUARIOS (ÚLTIMAS 24H)
    // =========================================================================
    if (newUsers.length > 0) {
      let msgHtml = `👤 <b>NUEVOS REGISTROS DE USUARIOS (ÚLTIMAS 24H: ${newUsers.length})</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

      newUsers.forEach((u, idx) => {
        const nom = u.nombre || 'Usuario';
        const code = u.codigo_identificacion || (u.es_revendedor ? 'RVD:1001' : 'CLT');
        const rol = u.es_revendedor ? 'Revendedor' : 'Cliente';
        const tel = u.telefono ? cleanTel(u.telefono) : '';
        const wa = tel ? toWaLink(tel, `¡Hola ${nom}! 👋 Bienvenido/a a Emprendimiento Gregory.`) : '';

        msgHtml += `${idx + 1}. <b>${escHtml(nom)}</b> [${rol}] (ID: <code>${escHtml(code)}</code>)\n` +
          `   ✉️ <code>${escHtml(u.email || 'Sin correo')}</code>\n` +
          (tel ? `   📱 Teléfono: <code>${tel}</code> ${wa ? `· <a href="${wa}">Saludar</a>` : ''}\n` : '') +
          `   📅 Registrado: <code>${new Date(u.creado).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' })}</code>\n\n`;
      });

      await sendTelegram(msgHtml);
      reportesEnviados.push(`Nuevos Registros (${newUsers.length})`);
    }

    // =========================================================================
    // BLOQUE 2: NUEVOS PEDIDOS GENERADOS (ÚLTIMAS 24H)
    // =========================================================================
    if (newOrders.length > 0) {
      let msgHtml = `🛒 <b>NUEVOS PEDIDOS GENERADOS (ÚLTIMAS 24H: ${newOrders.length})</b>\n` +
        `💵 Total: <b>$${totalOrdersUsd.toFixed(2)} USD</b> (Bs. ${totalOrdersBs.toLocaleString('es-VE', { minimumFractionDigits: 2 })})\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

      newOrders.slice(0, 15).forEach((o, idx) => {
        const shortId = o.id ? String(o.id).slice(0, 8) : 'OK';
        const cliNom = o.customers?.nombre || 'Cliente';
        const prodNom = o.products?.nombre || 'Servicio';
        const usd = Number(o.total_usd || 0).toFixed(2);
        const bs = (Number(o.total_usd || 0) * tasaBcv).toLocaleString('es-VE', { minimumFractionDigits: 2 });
        let badge = '🟡 Pendiente';
        if (o.estado === 'entregado') badge = '✅ Entregado';
        else if (o.estado === 'pagado') badge = '💳 Pagado';
        else if (o.estado === 'cancelado') badge = '❌ Cancelado';

        msgHtml += `${idx + 1}. <b>Pedido #${shortId}</b> [${badge}]\n` +
          `   👤 ${escHtml(cliNom)} · 📺 <b>${escHtml(prodNom)}</b>\n` +
          `   💵 $${usd} USD (Bs. ${bs})` +
          (o.referencia ? ` · Ref: <code>${escHtml(o.referencia)}</code>` : '') + `\n\n`;
      });

      if (newOrders.length > 15) {
        msgHtml += `<i>... y ${newOrders.length - 15} pedidos adicionales en el panel.</i>\n\n`;
      }

      await sendTelegram(msgHtml);
      reportesEnviados.push(`Nuevos Pedidos (${newOrders.length})`);
    }

    // =========================================================================
    // BLOQUE 3: SOLICITUDES PENDIENTES DE REVENDEDOR OFICIAL
    // =========================================================================
    if (solicitudesRev.length > 0) {
      let msgHtml = `🎖️ <b>SOLICITUDES PENDIENTES DE REVENDEDOR (${solicitudesRev.length})</b>\n` +
        `Usuarios esperando ascenso a catálogo mayorista:\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

      solicitudesRev.forEach((s, idx) => {
        const nom = s.nombre || 'Cliente';
        const tel = s.telefono ? cleanTel(s.telefono) : '';
        const waText = `¡Hola ${nom}! 👋 Te escribe Gregory Izquierdo respecto a tu solicitud para ser Revendedor Oficial de la tienda.`;
        const waLink = toWaLink(tel, waText);

        msgHtml += `${idx + 1}. 👤 <b>${escHtml(nom)}</b> (ID: <code>${escHtml(s.codigo_identificacion || 'CLT')}</code>)\n` +
          `   ✉️ <code>${escHtml(s.email || 'Sin correo')}</code>\n` +
          (tel ? `   📱 Teléfono: <code>${tel}</code> ${waLink ? `👉 <a href="${waLink}">Contactar WhatsApp</a>` : ''}\n` : '') +
          `   📅 Fecha Solicitud: <code>${s.solicita_revendedor_at ? new Date(s.solicita_revendedor_at).toLocaleDateString('es-VE') : 'Reciente'}</code>\n\n`;
      });

      msgHtml += `👉 <a href="https://www.gregoryizquierdo.xyz/#admin">Gestionar en Panel Clientes & Revendedores</a>`;
      await sendTelegram(msgHtml);
      reportesEnviados.push(`Solicitudes Revendedor (${solicitudesRev.length})`);
    }

    // =========================================================================
    // BLOQUE 4: VENCIMIENTOS DE CLIENTES DE HOY (Con mensajes listos para WhatsApp)
    // =========================================================================
    if (clientesTotal > 0) {
      let msgHtml = `📅 <b>VENCIMIENTOS DE SERVICIOS - HOY (${hoy})</b>\n` +
        `Total clientes por vencer: <b>${clientesTotal}</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

      for (const o of orders) {
        const cliNom = o.customers?.nombre || o.customers?.email || 'Cliente';
        const srvNom = o.products?.nombre || 'Suscripción Digital';
        const tel = o.customers?.telefono || '';
        const cChatId = o.customers?.telegram_chat_id;

        const waText = `Hola ${cliNom}! 👋 Te saluda Gregory Izquierdo.\n` +
          `Te recordamos que hoy *${hoy}* vence tu servicio de *${srvNom}*.\n` +
          `Para mantener tus accesos activos y evitar cortes, puedes renovar directamente en la tienda:\n` +
          `🌐 https://www.gregoryizquierdo.xyz\n` +
          `O reportando tu pago móvil BDV / BNC (04242809333 - V 18931731).\n¡Gracias por tu preferencia!`;

        const waLink = toWaLink(tel, waText);

        msgHtml += `👤 <b>${escHtml(cliNom)}</b> · ${escHtml(srvNom)}\n` +
          (tel ? `📱 Teléfono: <code>${cleanTel(tel)}</code> ${waLink ? `👉 <a href="${waLink}">Enviar WhatsApp</a>` : ''}\n` : '') +
          `📝 <b>Mensaje listo para copiar:</b>\n<code>${escHtml(waText)}</code>\n\n`;

        // Notificar directo al cliente por Bot Diego si tiene Telegram vinculado
        if (cChatId) {
          const directTgMsg = `👋 ¡Hola <b>${escHtml(cliNom)}</b>!\n\n` +
            `⏱ Te recordamos que hoy <b>${hoy}</b> vence tu servicio de <b>${escHtml(srvNom)}</b>.\n\n` +
            `Para renovar tus accesos y mantener tus pantallas activas:\n` +
            `🌐 Renueva en línea: <a href="https://www.gregoryizquierdo.xyz">https://www.gregoryizquierdo.xyz</a>\n` +
            `⚡ O por Pago Móvil BDV / BNC (04242809333 - V 18931731).\n\n¡Gracias por preferirnos!`;
          await sendDirectTelegramToUser(cChatId, directTgMsg);
        }
      }

      for (const p of profiles) {
        const cliNom = p.cliente_final || 'Cliente';
        const srvNom = `${p.mother_accounts?.plataforma || 'Servicio'} (${p.nombre_perfil || 'Perfil'})`;
        const tel = p.cliente_telefono || '';

        const waText = `Hola ${cliNom}! 👋 Te saluda Gregory Izquierdo.\n` +
          `Te recordamos que hoy *${hoy}* vence tu perfil de *${srvNom}*.\n` +
          `Para mantener tus accesos activos y evitar cortes, puedes renovar directamente en la tienda:\n` +
          `🌐 https://www.gregoryizquierdo.xyz\n` +
          `O reportando tu pago móvil BDV / BNC (04242809333 - V 18931731).\n¡Gracias por tu preferencia!`;

        const waLink = toWaLink(tel, waText);

        msgHtml += `👤 <b>${escHtml(cliNom)}</b> · ${escHtml(srvNom)}\n` +
          (tel ? `📱 Teléfono: <code>${cleanTel(tel)}</code> ${waLink ? `👉 <a href="${waLink}">Enviar WhatsApp</a>` : ''}\n` : '') +
          `📝 <b>Mensaje listo para copiar:</b>\n<code>${escHtml(waText)}</code>\n\n`;
      }

      await sendTelegram(msgHtml);
      reportesEnviados.push(`Vencimientos Clientes (${clientesTotal})`);
    }

    // =========================================================================
    // BLOQUE 5: CUENTAS MADRE POR VENCER HOY (Para renovar con proveedores)
    // =========================================================================
    if (mothers.length > 0) {
      let msgHtml = `🔑 <b>CUENTAS MADRE POR VENCER HOY (${hoy})</b>\n` +
        `Total cuentas por renovar: <b>${mothers.length}</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

      mothers.forEach((m, idx) => {
        msgHtml += `${idx + 1}. <b>${escHtml(m.plataforma || 'Plataforma')}</b>\n` +
          `   📧 Correo: <code>${escHtml(m.correo)}</code>\n` +
          `   👥 Perfiles asignados: ${m.max_perfiles || 5}\n` +
          `   🤝 Proveedor: <b>${escHtml(m.proveedor || 'No especificado')}</b>\n` +
          `   ⚠️ <i>Renovar antes de que caigan los perfiles activos.</i>\n\n`;
      });

      await sendTelegram(msgHtml);
      reportesEnviados.push(`Cuentas Madre (${mothers.length})`);
    }

    // =========================================================================
    // BLOQUE 6: CUOTAS / CUENTAS POR COBRAR DE HOY (Con monto en USD y Bs BCV)
    // =========================================================================
    if (cuotasHoy.length > 0) {
      let msgHtml = `💳 <b>CUENTAS POR COBRAR DE HOY (${hoy})</b>\n` +
        `📊 Tasa Oficial BCV: <b>${tasaBcv.toFixed(4)} Bs/USD</b>\n` +
        `Total cuotas de hoy: <b>${cuotasHoy.length}</b> ($${totalCuotasHoyUsd.toFixed(2)} USD · Bs. ${totalCuotasHoyBs.toLocaleString('es-VE', { minimumFractionDigits: 2 })})\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

      for (const c of cuotasHoy) {
        const cliNom = c.customers?.nombre || 'Cliente';
        const srvNom = c.orders?.products?.nombre || 'Servicio Digital';
        const tel = c.customers?.telefono || '';
        const cChatId = c.customers?.telegram_chat_id;
        const montoUsd = Number(c.monto_usd || 0).toFixed(2);
        const montoBs = (Number(c.monto_usd || 0) * tasaBcv).toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

        const waText = `Hola ${cliNom}! 👋 Te saluda Gregory Izquierdo.\n` +
          `Te recordamos que hoy corresponde tu cuota ${c.numero_cuota}/${c.total_cuotas} de *${srvNom}* por un monto de *$${montoUsd} USD* (Bs. ${montoBs} a tasa oficial BCV de ${tasaBcv.toFixed(2)}).\n` +
          `Puedes cancelar fácilmente por Pago Móvil BDV o BNC al 04242809333 - V 18931731 o reportar tu pago en la tienda:\n` +
          `🌐 https://www.gregoryizquierdo.xyz\n¡Gracias por tu puntualidad!`;

        const waLink = toWaLink(tel, waText);

        msgHtml += `👤 <b>${escHtml(cliNom)}</b> (Cuota ${c.numero_cuota}/${c.total_cuotas})\n` +
          `💵 Monto: <b>$${montoUsd} USD</b> · <b>Bs. ${montoBs}</b>\n` +
          `📦 Servicio: ${escHtml(srvNom)}\n` +
          (tel ? `📱 Teléfono: <code>${cleanTel(tel)}</code> ${waLink ? `👉 <a href="${waLink}">Cobrar WhatsApp</a>` : ''}\n` : '') +
          `📝 <b>Mensaje precargado:</b>\n<code>${escHtml(waText)}</code>\n\n`;

        // Notificar directo al cliente por Bot Diego
        if (cChatId) {
          const directTgMsg = `💳 ¡Hola <b>${escHtml(cliNom)}</b>!\n\n` +
            `Te recordamos que hoy corresponde tu cuota <b>${c.numero_cuota}/${c.total_cuotas}</b> de <b>${escHtml(srvNom)}</b>.\n\n` +
            `💵 <b>Monto a pagar:</b> $${montoUsd} USD (Bs. ${montoBs})\n` +
            `📊 <b>Tasa BCV del día:</b> ${tasaBcv.toFixed(4)} Bs/USD\n\n` +
            `Puedes saldar tu cuota en línea desde el portal o mediante Pago Móvil BDV / BNC (04242809333 - V 18931731).\n¡Gracias por tu puntualidad!`;
          await sendDirectTelegramToUser(cChatId, directTgMsg);
        }
      }

      await sendTelegram(msgHtml);
      reportesEnviados.push(`Cuotas de Hoy (${cuotasHoy.length})`);
    }

    // =========================================================================
    // BLOQUE 7: CUOTAS VENCIDAS EN MORA (Llamado a la acción amistoso CTA)
    // =========================================================================
    if (cuotasVencidas.length > 0) {
      let msgHtml = `⚠️ <b>CUOTAS VENCIDAS EN MORA</b>\n` +
        `Total cuotas atrasadas: <b>${cuotasVencidas.length}</b> ($${totalCuotasMoraUsd.toFixed(2)} USD · Bs. ${totalCuotasMoraBs.toLocaleString('es-VE', { minimumFractionDigits: 2 })})\n` +
        `📊 Tasa Oficial BCV: <b>${tasaBcv.toFixed(4)} Bs/USD</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

      for (const c of cuotasVencidas) {
        const cliNom = c.customers?.nombre || 'Cliente';
        const srvNom = c.orders?.products?.nombre || 'Servicio Digital';
        const tel = c.customers?.telefono || '';
        const cChatId = c.customers?.telegram_chat_id;
        const montoUsd = Number(c.monto_usd || 0).toFixed(2);
        const montoBs = (Number(c.monto_usd || 0) * tasaBcv).toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

        const waText = `Hola ${cliNom}! 👋 Te saluda Gregory Izquierdo.\n` +
          `Esperamos te encuentres bien. Notamos que tu cuota ${c.numero_cuota}/${c.total_cuotas} de *${srvNom}* por *$${montoUsd} USD* (Bs. ${montoBs}) tiene fecha de vencimiento pendiente del ${c.fecha_vencimiento}.\n` +
          `Por favor ponte al día a la brevedad para mantener tus accesos activos y evitar cargos adicionales por mora.\n` +
          `Reporta tu pago directamente en: https://www.gregoryizquierdo.xyz o avísanos por acá. ¡Estamos a tu orden!`;

        const waLink = toWaLink(tel, waText);

        msgHtml += `🔴 <b>${escHtml(cliNom)}</b> (Vencida desde: ${escHtml(c.fecha_vencimiento)})\n` +
          `💵 Monto: <b>$${montoUsd} USD</b> · <b>Bs. ${montoBs}</b>\n` +
          `📦 Servicio: ${escHtml(srvNom)} (Cuota ${c.numero_cuota}/${c.total_cuotas})\n` +
          (tel ? `📱 Teléfono: <code>${cleanTel(tel)}</code> ${waLink ? `👉 <a href="${waLink}">Enviar Alerta WhatsApp</a>` : ''}\n` : '') +
          `📝 <b>Llamado de atención precargado (CTA):</b>\n<code>${escHtml(waText)}</code>\n\n`;

        // Notificar directo al cliente por Bot Diego
        if (cChatId) {
          const directTgMsg = `⚠️ ¡Hola <b>${escHtml(cliNom)}</b>!\n\n` +
            `Notamos que tienes la cuota <b>${c.numero_cuota}/${c.total_cuotas}</b> de <b>${escHtml(srvNom)}</b> pendiente por pagar (Venció el ${escHtml(c.fecha_vencimiento)}).\n\n` +
            `💵 <b>Monto pendiente:</b> $${montoUsd} USD (Bs. ${montoBs})\n\n` +
            `Por favor ponte al día para mantener tus servicios activos y evitar recargos por mora.\n` +
            `🌐 Pagar en el portal: <a href="https://www.gregoryizquierdo.xyz">https://www.gregoryizquierdo.xyz</a>`;
          await sendDirectTelegramToUser(cChatId, directTgMsg);
        }
      }

      await sendTelegram(msgHtml);
      reportesEnviados.push(`Cuotas Vencidas (${cuotasVencidas.length})`);
    }

    // =========================================================================
    // BLOQUE 8: ALERTA DE STOCK CRÍTICO Y AGOTADO
    // =========================================================================
    if (agotados.length > 0 || criticos.length > 0) {
      let msgHtml = `🚨 <b>ALERTA DE INVENTARIO: STOCK CRÍTICO / AGOTADO</b>\n` +
        `Agotados (0 unidades): <b>${agotados.length}</b> · Stock Crítico (1 unidad): <b>${criticos.length}</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

      if (agotados.length > 0) {
        msgHtml += `🔴 <b>PRODUCTOS AGOTADOS (0 DISPONIBLES):</b>\n`;
        agotados.forEach((p, idx) => {
          msgHtml += `${idx + 1}. 📦 <b>${escHtml(p.nombre)}</b> (${escHtml(p.tipo)})\n`;
        });
        msgHtml += '\n';
      }

      if (criticos.length > 0) {
        msgHtml += `🟡 <b>PRODUCTOS CON STOCK CRÍTICO (1 DISPONIBLE):</b>\n`;
        criticos.forEach((p, idx) => {
          msgHtml += `${idx + 1}. ⚠️ <b>${escHtml(p.nombre)}</b> (${escHtml(p.tipo)}) - <i>Solo 1 restante</i>\n`;
        });
        msgHtml += '\n';
      }

      msgHtml += `👉 <a href="https://www.gregoryizquierdo.xyz/#admin">Cargar Cuentas e Inventario en Panel Admin</a>`;

      await sendTelegram(msgHtml);
      reportesEnviados.push(`Stock Crítico (${agotados.length + criticos.length})`);
    }

    return res.json({
      ok: true,
      fecha: hoy,
      tasa_bcv: tasaBcv,
      reportes_enviados: reportesEnviados,
      metricas: {
        nuevos_usuarios: newUsers.length,
        nuevos_pedidos: newOrders.length,
        solicitudes_revendedor: solicitudesRev.length,
        vencimientos_hoy: clientesTotal,
        cuentas_madre_hoy: mothers.length,
        cuotas_hoy: cuotasHoy.length,
        cuotas_mora: cuotasVencidas.length,
        agotados: agotados.length,
        stock_critico: criticos.length
      }
    });

  } catch (err) {
    console.error('Error procesando cron de vencimientos:', err);
    return res.status(500).json({ error: err.message });
  }
}
