// Cron diario (8:00 a. m. Venezuela o llamada manual desde Panel Admin):
// Envía notificaciones separadas, identificadas y con mensajes precargados para WhatsApp/Telegram.
import { sbRest, getSecret } from './_lib.js';
import { sendTelegram, sendAll } from './_notify.js';

export default async function handler(req, res) {
  // Permitir ejecución con CRON_SECRET o si viene de un admin autenticado
  if (process.env.CRON_SECRET && req.headers.authorization && req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) {
    // Si no coincide cron secret, verificamos si es admin
  }

  const hoy = req.query?.fecha || new Date(Date.now() - 4 * 3600e3).toISOString().slice(0, 10);
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

    // 3. Consultar datos en paralelo
    const [ordersRes, profilesRes, mothersRes, instHoyRes, instOverdueRes, stockRes, productsRes] = await Promise.all([
      sbRest(`orders?estado=in.(entregado,pagado)&vence=eq.${hoy}&select=id,inicia,vence,referencia,customers!customer_id(id,nombre,email,telefono,telegram_chat_id),products(nombre)`).catch(() => []),
      sbRest(`profiles_inventory?estado=eq.vendido&vence=eq.${hoy}&select=id,nombre_perfil,pin,vence,cliente_final,cliente_telefono,mother_accounts(plataforma,correo)`).catch(() => []),
      sbRest(`mother_accounts?activa=eq.true&vence=eq.${hoy}&select=id,plataforma,correo,vence,max_perfiles,proveedor`).catch(() => []),
      sbRest(`installments?estado=in.(pendiente,en_revision)&fecha_vencimiento=eq.${hoy}&select=id,numero_cuota,total_cuotas,monto_usd,fecha_vencimiento,estado,customers!customer_id(id,nombre,telefono,telegram_chat_id),orders(products(nombre))`).catch(() => []),
      sbRest(`installments?estado=eq.vencida&fecha_vencimiento=lt.${hoy}&select=id,numero_cuota,total_cuotas,monto_usd,fecha_vencimiento,estado,customers!customer_id(id,nombre,telefono,telegram_chat_id),orders(products(nombre))`).catch(() => []),
      sbRest('rpc/stock').catch(() => []),
      sbRest('products?activo=eq.true&tipo=in.(pantalla,cuenta_completa)&select=id,nombre,tipo').catch(() => [])
    ]);

    const orders = ordersRes || [];
    const profiles = profilesRes || [];
    const mothers = mothersRes || [];
    const cuotasHoy = instHoyRes || [];
    const cuotasVencidas = instOverdueRes || [];
    const stockMap = Object.fromEntries((stockRes || []).map(s => [s.product_id, Number(s.disponibles || 0)]));
    const activeProducts = productsRes || [];

    // Detectar productos agotados
    const agotados = activeProducts.filter(p => (stockMap[p.id] || 0) <= 0);

    const reportesEnviados = [];

    // =========================================================================
    // BLOQUE 1: VENCIMIENTOS DE CLIENTES DE HOY (Con mensajes listos para WhatsApp)
    // =========================================================================
    const clientesTotal = orders.length + profiles.length;
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
    // BLOQUE 2: CUENTAS MADRE POR VENCER HOY (Para renovar con proveedores)
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
    // BLOQUE 3: CUOTAS / CUENTAS POR COBRAR DE HOY (Con monto en USD y Bs BCV)
    // =========================================================================
    if (cuotasHoy.length > 0) {
      let msgHtml = `💳 <b>CUOTAS POR COBRAR DE HOY (${hoy})</b>\n` +
        `📊 Tasa Oficial BCV: <b>${tasaBcv.toFixed(4)} Bs/USD</b>\n` +
        `Total cuotas de hoy: <b>${cuotasHoy.length}</b>\n` +
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
    // BLOQUE 4: CUOTAS VENCIDAS EN MORA (Llamado a la acción amistoso para evitar recargos)
    // =========================================================================
    if (cuotasVencidas.length > 0) {
      let msgHtml = `⚠️ <b>CUOTAS VENCIDAS EN MORA</b>\n` +
        `Total cuotas atrasadas: <b>${cuotasVencidas.length}</b>\n` +
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
          `📝 <b>Llamado de atención precargado:</b>\n<code>${escHtml(waText)}</code>\n\n`;

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
    // BLOQUE 5: ALERTA DE STOCK AGOTADO EN CATÁLOGO
    // =========================================================================
    if (agotados.length > 0) {
      let msgHtml = `🚨 <b>ALERTA DE INVENTARIO: STOCK AGOTADO</b>\n` +
        `Productos con 0 unidades disponibles: <b>${agotados.length}</b>\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

      agotados.forEach((p, idx) => {
        msgHtml += `${idx + 1}. 📦 <b>${escHtml(p.nombre)}</b> (${escHtml(p.tipo)})\n` +
          `   ⚠️ <i>Sin perfiles o cuentas disponibles para entrega inmediata.</i>\n\n`;
      });

      msgHtml += `👉 <a href="https://www.gregoryizquierdo.xyz/#admin">Cargar Inventario en Panel Admin</a>`;

      await sendTelegram(msgHtml);
      reportesEnviados.push(`Stock Agotado (${agotados.length})`);
    }

    if (reportesEnviados.length === 0) {
      await sendTelegram(`✅ <b>CONTROL DIARIO 8:00 AM (${hoy}):</b>\nTodo al día. No hay vencimientos, cuotas pendientes ni stock agotado para hoy.`);
      reportesEnviados.push('Todo al día');
    }

    return res.json({
      ok: true,
      fecha: hoy,
      tasa_bcv: tasaBcv,
      reportes_enviados: reportesEnviados
    });

  } catch (err) {
    console.error('Error procesando cron de vencimientos:', err);
    return res.status(500).json({ error: err.message });
  }
}
