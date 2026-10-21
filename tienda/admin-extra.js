// Herramientas avanzadas del panel: Google, Telegram, Gemini e importador de la hoja de control
const today = () => new Date().toISOString().slice(0, 10);
const addDay = d => { const x = new Date(d + 'T12:00:00Z'); x.setUTCDate(x.getUTCDate() + 1); return x.toISOString().slice(0, 10); };
const jwt = async () => (await sb.auth.getSession()).data.session?.access_token;
const api = async (path, body) => { const r = await fetch(path, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + await jwt() }, body: JSON.stringify(body) }); const j = await r.json().catch(() => ({})); if (!r.ok) throw new Error(j.error || r.status); return j; };
const G = async (url, opt = {}) => {
  const t = sessionStorage.getItem('gtk'); if (!t) throw new Error('Conecta Google primero (botón "Conectar Google").');
  const headers = { Authorization: 'Bearer ' + t, ...(opt.headers || {}) };
  if (opt.body) headers['Content-Type'] = 'application/json';
  const r = await fetch(url, { ...opt, headers });
  if (r.status === 401) { sessionStorage.removeItem('gtk'); throw new Error('Sesión de Google vencida: vuelve a conectar.'); }
  if (r.status === 204) return true;
  if (!r.ok) {
    const errTxt = await r.text().catch(() => '');
    throw new Error(errTxt.slice(0, 200) || ('Error HTTP ' + r.status));
  }
  const txt = await r.text().catch(() => '');
  if (!txt || !txt.trim()) return true;
  try { return JSON.parse(txt); } catch(e) { return true; }
};
const dump = async () => { const o = {}; for (const t of ['settings', 'customers', 'products', 'categories', 'banners', 'orders', 'invoices', 'zeny_ledger', 'payment_methods', 'faqs', 'incidents', 'bot_commands', 'exchange_rates']) o[t] = (await sb.from(t).select('*')).data || []; return o; };
const loadXLSX = () => window.XLSX ? Promise.resolve() : new Promise((ok, ko) => { const s = document.createElement('script'); s.src = 'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js'; s.onload = ok; s.onerror = () => ko(new Error('No se pudo cargar el lector de Excel')); document.head.appendChild(s); });
const run = async (btn, fn) => { btn.disabled = true; try { toast(await fn()); } catch (e) { toast('Error: ' + e.message); } btn.disabled = false; };

const GCal = {
  CAL_ID: 'emprendimientogregoryizquierdo@gmail.com',
  TZ: 'America/Caracas',
  EMBED_URL: 'https://calendar.google.com/calendar/embed?src=emprendimientogregoryizquierdo%40gmail.com&ctz=America%2FCaracas',

  isConnected() {
    return !!sessionStorage.getItem('gtk');
  },

  connect() {
    sessionStorage.setItem('oauth_dest', 'admin');
    return sb.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: location.origin + '/',
        scopes: 'https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/contacts https://www.googleapis.com/auth/spreadsheets',
        queryParams: {
          access_type: 'offline',
          prompt: 'select_account consent'
        }
      }
    });
  },

  async listEvents({ timeMin, timeMax, maxResults = 250 } = {}) {
    const min = timeMin || new Date(Date.now() - 30 * 86400000).toISOString();
    let q = `timeMin=${encodeURIComponent(min)}&timeZone=${encodeURIComponent(this.TZ)}&maxResults=${maxResults}&singleEvents=true&orderBy=startTime`;
    if (timeMax) q += `&timeMax=${encodeURIComponent(timeMax)}`;

    const eventsMap = new Map();
    // 1. Consultar primary (calendario por defecto del usuario OAuth autenticado)
    try {
      const res = await G(`https://www.googleapis.com/calendar/v3/calendars/primary/events?${q}`);
      (res.items || []).forEach(ev => {
        if (ev && ev.status !== 'cancelled') eventsMap.set(ev.id, ev);
      });
    } catch(e) {}

    // 2. Si CAL_ID está configurado y es diferente a primary, consultar también por si los eventos se crearon allí
    if (this.CAL_ID && this.CAL_ID !== 'primary') {
      try {
        const res2 = await G(`https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(this.CAL_ID)}/events?${q}`);
        (res2.items || []).forEach(ev => {
          if (ev && ev.status !== 'cancelled') eventsMap.set(ev.id, ev);
        });
      } catch(e) {}
    }

    return Array.from(eventsMap.values());
  },

  getEventDate(ev) {
    if (!ev) return null;
    if (ev.start?.date) return ev.start.date;
    if (ev.start?.dateTime) {
      try {
        const d = new Date(ev.start.dateTime);
        return new Intl.DateTimeFormat('en-CA', { timeZone: this.TZ || 'America/Caracas', year: 'numeric', month: '2-digit', day: '2-digit' }).format(d);
      } catch (e) {
        return ev.start.dateTime.slice(0, 10);
      }
    }
    return null;
  },

  async listMonthEvents(year, month) {
    const pad = n => String(n).padStart(2, '0');
    const startStr = `${year}-${pad(month)}-01T00:00:00-04:00`;
    const lastDay = new Date(year, month, 0).getDate();
    const endStr = `${year}-${pad(month)}-${pad(lastDay)}T23:59:59-04:00`;
    return this.listEvents({ timeMin: startStr, timeMax: endStr, maxResults: 250 });
  },

  async getEvent(eventId) {
    try {
      return await G(`https://www.googleapis.com/calendar/v3/calendars/primary/events/${encodeURIComponent(eventId)}`);
    } catch(e) {
      return await G(`https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(this.CAL_ID)}/events/${encodeURIComponent(eventId)}`);
    }
  },

  async createEvent({ summary, description, date, startDateTime, durationMinutes = 30 }) {
    const payload = { summary, description: description || '' };
    if (date) {
      payload.start = { date };
      payload.end = { date: addDay(date) };
    } else if (startDateTime) {
      const start = new Date(startDateTime);
      const end = new Date(start.getTime() + durationMinutes * 60000);
      payload.start = { dateTime: start.toISOString(), timeZone: this.TZ };
      payload.end = { dateTime: end.toISOString(), timeZone: this.TZ };
    }
    const body = JSON.stringify(payload);
    try {
      return await G('https://www.googleapis.com/calendar/v3/calendars/primary/events', { method: 'POST', body });
    } catch(e) {
      return await G(`https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(this.CAL_ID)}/events`, { method: 'POST', body });
    }
  },

  async updateEvent(eventId, { summary, description, date, startDateTime, durationMinutes = 30 }) {
    const patch = {};
    if (summary !== undefined) patch.summary = summary;
    if (description !== undefined) patch.description = description;
    if (date) {
      patch.start = { date };
      patch.end = { date: addDay(date) };
    } else if (startDateTime) {
      const start = new Date(startDateTime);
      const end = new Date(start.getTime() + durationMinutes * 60000);
      patch.start = { dateTime: start.toISOString(), timeZone: this.TZ };
      patch.end = { dateTime: end.toISOString(), timeZone: this.TZ };
    }
    const body = JSON.stringify(patch);
    try {
      return await G(`https://www.googleapis.com/calendar/v3/calendars/primary/events/${encodeURIComponent(eventId)}`, { method: 'PATCH', body });
    } catch(e) {
      return await G(`https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(this.CAL_ID)}/events/${encodeURIComponent(eventId)}`, { method: 'PATCH', body });
    }
  },

  async deleteEvent(eventId) {
    try {
      return await G(`https://www.googleapis.com/calendar/v3/calendars/primary/events/${encodeURIComponent(eventId)}`, { method: 'DELETE' });
    } catch(e) {
      return await G(`https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(this.CAL_ID)}/events/${encodeURIComponent(eventId)}`, { method: 'DELETE' });
    }
  },

  openEmbedView() {
    $('#dlgBody').innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
        <h3 style="margin:0">📅 Google Calendar Principal</h3>
        <span class="pill" style="font-size:.7rem;color:var(--c)">${this.TZ}</span>
      </div>
      <p class="mut" style="font-size:.78rem;margin:0 0 10px">
        Calendario oficial: <b>${this.CAL_ID}</b>
      </p>
      <div style="position:relative;width:100%;height:450px;border-radius:12px;overflow:hidden;border:1px solid rgba(0,212,255,.25);background:#fff">
        <iframe src="${this.EMBED_URL}" style="width:100%;height:100%;border:none" frameborder="0" scrolling="yes"></iframe>
      </div>
      <div style="display:flex;justify-content:space-between;align-items:center;margin-top:12px">
        <a href="${this.EMBED_URL}" target="_blank" rel="noopener noreferrer" style="color:var(--c);font-size:.8rem;font-weight:700;text-decoration:none">
          ↗ Abrir en Google Calendar Web
        </a>
        <button class="g" onclick="dlg.close()">Cerrar</button>
      </div>
    `;
    dlg.showModal();
  }
};
window.GCal = GCal;

async function refundDlg(id, total, done) {
  let targetOrderId = id;
  let targetTotal = total;
  let orderObj = null;

  $('#dlgBody').innerHTML = `
    <div style="padding:20px;text-align:center">
      <div class="sk" style="height:60px"></div>
      <p class="mut" style="margin-top:8px">Cargando datos del pedido...</p>
    </div>
  `;
  dlg.showModal();

  // Si no se pasó un ID de pedido (ej: desde el botón "+ Registrar Devolución" de la pestaña Devoluciones),
  // cargar los pedidos recientes pagados/entregados para que el usuario pueda seleccionar
  let recentOrders = [];
  if (!targetOrderId) {
    const { data: ords } = await sb.from('orders')
      .select('id,total_usd,total_bs,referencia,estado,created_at,customers!customer_id(nombre,email,telefono),products(nombre)')
      .in('estado', ['pagado', 'entregado', 'vencido'])
      .order('created_at', { ascending: false })
      .limit(60);
    recentOrders = ords || [];
    if (!recentOrders.length) {
      $('#dlgBody').innerHTML = `
        <h3>⚠️ No hay pedidos reembolsables</h3>
        <p class="mut">No se encontraron pedidos con estado Pagado o Entregado para procesar una devolución.</p>
        <button class="g" onclick="dlg.close()">Cerrar</button>
      `;
      return;
    }
    targetOrderId = recentOrders[0].id;
    targetTotal = recentOrders[0].total_usd;
    orderObj = recentOrders[0];
  } else {
    const { data: singleOrd } = await sb.from('orders')
      .select('id,total_usd,total_bs,referencia,estado,customers!customer_id(nombre,email,telefono),products(nombre)')
      .eq('id', targetOrderId)
      .maybeSingle();
    orderObj = singleOrd;
    if (orderObj) targetTotal = orderObj.total_usd;
  }

  const renderForm = () => {
    const curCust = orderObj?.customers;
    const custDesc = curCust ? `${curCust.nombre || curCust.email || 'Cliente'} (${curCust.telefono || 'Sin teléfono'})` : 'Cliente';
    const prodDesc = orderObj?.products?.nombre || 'Servicio';

    $('#dlgBody').innerHTML = `
      <h3>🔄 Registrar Devolución / Reembolso</h3>
      <p class="mut" style="font-size:.82rem;margin:0 0 14px">
        Registra la devolución detallada con soporte de pago, destinatario y acción sobre el perfil en inventario.
      </p>

      ${!id && recentOrders.length ? `
        <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Seleccionar Pedido a Reembolsar:</label>
        <select id="rOrderSelect" style="width:100%;font-size:.85rem;margin-bottom:12px;padding:8px;background:rgba(3,8,18,.8);border-radius:8px">
          ${recentOrders.map(o => `
            <option value="${o.id}" ${o.id === targetOrderId ? 'selected' : ''}>
              ${esc((o.created_at || '').slice(0, 10))} · ${esc(o.customers?.nombre || o.customers?.email || 'Cliente')} · ${esc(o.products?.nombre || 'Servicio')} ($${Number(o.total_usd).toFixed(2)})
            </option>
          `).join('')}
        </select>
      ` : `
        <div style="background:rgba(255,255,255,.03);padding:10px 14px;border-radius:10px;border:1px solid rgba(255,255,255,.08);margin-bottom:12px">
          <div style="display:flex;justify-content:space-between;font-size:.84rem;margin-bottom:4px">
            <span class="mut">Cliente:</span> <b>${esc(custDesc)}</b>
          </div>
          <div style="display:flex;justify-content:space-between;font-size:.84rem;margin-bottom:4px">
            <span class="mut">Servicio:</span> <b>${esc(prodDesc)}</b>
          </div>
          <div style="display:flex;justify-content:space-between;font-size:.84rem">
            <span class="mut">Total Pagado:</span> <b style="color:#00f5a0">$${Number(targetTotal).toFixed(2)} USD</b>
          </div>
        </div>
      `}

      <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:10px">
        <div>
          <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Monto a Devolver (USD):</label>
          <input id="rm" type="number" step="0.01" min="0.01" max="${esc(targetTotal)}" value="${esc(targetTotal)}" style="width:100%;font-size:.95rem;font-weight:700" required>
        </div>
        <div>
          <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Medio de Pago del Reembolso:</label>
          <select id="rd" style="width:100%;font-size:.85rem;padding:7px">
            <option value="zeny">💎 Saldo Zeny (Wallet interna cliente)</option>
            <option value="binance">🟡 Binance Pay (USDT)</option>
            <option value="pago_movil">🇻🇪 Bolívares (Pago Móvil / Bancario)</option>
            <option value="efectivo">💵 Efectivo / Otra Vía</option>
          </select>
        </div>
      </div>

      <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:10px">
        <div>
          <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Destinatario del Reverso:</label>
          <input id="rDestinatario" placeholder="Nombre, Cédula, Teléfono Pago Móvil o Pay ID" value="${esc(orderObj?.customers?.telefono ? (orderObj.customers.nombre + ' · ' + orderObj.customers.telefono) : '')}" style="width:100%;font-size:.84rem">
        </div>
        <div>
          <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Referencia / Comprobante de Pago:</label>
          <input id="rRef" placeholder="Ej: Pago Móvil #928374 / Binance TxID" style="width:100%;font-size:.84rem">
        </div>
      </div>

      <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:10px">
        <div>
          <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Acción sobre el Perfil en Inventario:</label>
          <select id="rAccionPerfil" style="width:100%;font-size:.84rem;padding:7px">
            <option value="liberar">🟢 Liberar Perfil (vuelve a Disponible)</option>
            <option value="suspender">🔴 Suspender Perfil (bloqueado/revisión)</option>
            <option value="trasladar">🔀 Trasladar Cliente a Otro Perfil</option>
            <option value="mantener">⚪ Mantener Perfil como está</option>
          </select>
        </div>
        <div>
          <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Diferencia de Precio ($ si hubo cambio):</label>
          <input id="rDiferencia" type="number" step="0.01" value="0.00" placeholder="0.00 (opcional)" style="width:100%;font-size:.84rem">
        </div>
      </div>

      <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Motivo / Razón de la Devolución:</label>
      <input id="rr" placeholder="Ej: Cuenta con caída del proveedor, cliente solicitó anulación..." style="width:100%;font-size:.85rem;margin-bottom:14px">

      <div style="display:flex;gap:10px;justify-content:flex-end">
        <button class="g" onclick="dlg.close()">Cancelar</button>
        <button id="rok" class="d" style="font-weight:800;padding:8px 16px">💾 Confirmar Devolución</button>
      </div>
    `;

    // Cambio dinámico de orden si no venía preseleccionada
    const selOrd = $('#rOrderSelect');
    if (selOrd) {
      selOrd.onchange = (e) => {
        targetOrderId = e.target.value;
        orderObj = recentOrders.find(x => x.id === targetOrderId) || recentOrders[0];
        targetTotal = orderObj?.total_usd || 0;
        renderForm();
      };
    }

    $('#rok').onclick = e => run(e.target, async () => {
      const montoVal = parseFloat($('#rm').value) || 0;
      if (montoVal <= 0) throw new Error('El monto a devolver debe ser mayor a 0');

      const rawDest = $('#rd').value;
      const destinatarioTxt = ($('#rDestinatario').value || '').trim();
      const refTxt = ($('#rRef')?.value || '').trim();
      const accionPerfil = $('#rAccionPerfil').value;
      const difUsd = parseFloat($('#rDiferencia')?.value) || 0;
      const motivoBase = ($('#rr').value || '').trim() || 'Devolución autorizada';

      const destLabel = rawDest === 'zeny' ? 'Saldo Zeny' : (rawDest === 'binance' ? 'Binance USDT' : (rawDest === 'pago_movil' ? 'Pago Móvil Bolívares' : 'Efectivo/Otro'));

      let finalMotivo = `[Vía ${destLabel}${refTxt ? ' · Ref: ' + refTxt : ''}${destinatarioTxt ? ' · Para: ' + destinatarioTxt : ''}] ${motivoBase}`;
      if (difUsd !== 0) {
        finalMotivo += ` (Diferencia de precio: $${difUsd.toFixed(2)})`;
      }

      // 1. Intentar llamar a registrar_devolucion_avanzada si la migración 32 está activa
      let success = false;
      try {
        const { data: advRes, error: advErr } = await sb.rpc('registrar_devolucion_avanzada', {
          p_order_id: targetOrderId,
          p_monto_usd: montoVal,
          p_metodo: rawDest,
          p_motivo: finalMotivo,
          p_referencia: refTxt,
          p_destinatario: destinatarioTxt,
          p_accion_perfil: accionPerfil,
          p_diferencia_usd: difUsd
        });
        if (advErr) throw advErr;
        success = true;
      } catch (errAdv) {
        console.warn('Fallback a refund_order:', errAdv.message);
        // Fallback a refund_order estándar
        const legacyDest = rawDest === 'zeny' ? 'zeny' : 'externo';
        const { error: legErr } = await sb.rpc('refund_order', {
          p_order: targetOrderId,
          p_monto: montoVal,
          p_destino: legacyDest,
          p_motivo: finalMotivo,
          p_liberar: accionPerfil === 'liberar'
        });
        if (legErr) throw legErr;
        success = true;
      }

      // Si se seleccionó trasladar el perfil, abrir modal de traslado
      if (accionPerfil === 'trasladar' && orderObj?.profile_id) {
        setTimeout(() => openTransferModal({ profileId: orderObj.profile_id, done }), 400);
      }

      dlg.close();
      done && done();
      return `✅ Devolución de $${montoVal.toFixed(2)} USD registrada con éxito (${destLabel}).`;
    });
  };

  renderForm();
}

window.openPayPurchaseModal = function(purchaseId, proveedor, montoUsdt, fechaVence, done) {
  const curUsdt = parseFloat(montoUsdt) || 0;
  const defRate = Number(S?.settings?.tasas?.usdt_ves || S?.rate || 50.00);

  $('#dlgBody').innerHTML = `
    <h3>💳 Registrar Pago de Compra a Proveedor</h3>
    <p class="mut" style="font-size:.82rem;margin:0 0 14px">
      Cancela la deuda contraída con el proveedor en USDT o en Bolívares calculados al cambio del momento.
    </p>

    <div style="background:rgba(255,255,255,.04);padding:12px 16px;border-radius:12px;border:1px solid rgba(255,255,255,.1);margin-bottom:14px">
      <div style="display:flex;justify-content:space-between;margin-bottom:6px">
        <span class="mut" style="font-size:.82rem">Proveedor:</span>
        <b>${esc(proveedor)}</b>
      </div>
      <div style="display:flex;justify-content:space-between;margin-bottom:6px">
        <span class="mut" style="font-size:.82rem">Deuda Acordada (USDT):</span>
        <b style="color:#fde047;font-size:1.1rem">$${curUsdt.toFixed(2)} USDT</b>
      </div>
      ${fechaVence ? `
        <div style="display:flex;justify-content:space-between">
          <span class="mut" style="font-size:.82rem">Fecha Límite:</span>
          <b>${esc(fechaVence)}</b>
        </div>
      ` : ''}
    </div>

    <label class="mut" style="font-size:.78rem;display:block;margin-bottom:4px">Forma de Pago al Proveedor:</label>
    <select id="selPayProvMethod" style="width:100%;font-size:.88rem;padding:8px;margin-bottom:12px">
      <option value="usdt">🟡 Cancelar en USDT (Binance Pay / Crypto)</option>
      <option value="bolivares">🇻🇪 Cancelar en Bolívares (Pago Móvil / Transferencia Bancaria)</option>
      <option value="efectivo">💵 Efectivo / Otra Vía</option>
    </select>

    <div id="wrapBsProvCalc" style="display:none;background:rgba(0,245,160,.06);border:1px solid rgba(0,245,160,.25);border-radius:10px;padding:12px;margin-bottom:12px">
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:8px">
        <div>
          <label class="mut" style="font-size:.74rem;display:block;margin-bottom:4px">Tasa USDT / Cambio Actual:</label>
          <input id="inpProvRate" type="number" step="0.01" value="${defRate.toFixed(2)}" style="width:100%;font-size:.88rem;font-weight:700">
        </div>
        <div>
          <label class="mut" style="font-size:.74rem;display:block;margin-bottom:4px">Monto Total a Transferir (Bs):</label>
          <div id="txtProvMontoBs" style="color:#00f5a0;font-size:1.15rem;font-weight:800;padding-top:4px">
            Bs. ${(curUsdt * defRate).toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}
          </div>
        </div>
      </div>
      <p class="mut" style="font-size:.72rem;margin:0">
        Calculado automáticamente: <b>$${curUsdt.toFixed(2)} USDT</b> × Tasa USDT de Al Cambio / P2P.
      </p>
    </div>

    <label class="mut" style="font-size:.78rem;display:block;margin-bottom:4px">Referencia / Comprobante de Pago:</label>
    <input id="inpProvRef" placeholder="Ej: Pago Móvil #847291 / Binance Pay Order ID" style="width:100%;font-size:.86rem;margin-bottom:12px" required>

    <label class="mut" style="font-size:.78rem;display:block;margin-bottom:4px">Notas u Observaciones (opcional):</label>
    <input id="inpProvNotas" placeholder="Ej: Cancelado crédito de 15 días" style="width:100%;font-size:.86rem;margin-bottom:14px">

    <div style="display:flex;gap:10px;justify-content:flex-end">
      <button class="g" onclick="dlg.close()">Cancelar</button>
      <button id="btnConfirmPayProv" style="background:linear-gradient(135deg,#00f5a0,#00d98b);color:#000;font-weight:800;border:none;padding:8px 16px">
        💾 Confirmar Pago a Proveedor
      </button>
    </div>
  `;
  dlg.showModal();

  const mSel = $('#selPayProvMethod');
  const wBs = $('#wrapBsProvCalc');
  const inpRate = $('#inpProvRate');
  const txtBs = $('#txtProvMontoBs');

  const updateBsCalc = () => {
    const rateVal = parseFloat(inpRate?.value) || defRate;
    const bsTotal = curUsdt * rateVal;
    if (txtBs) txtBs.textContent = 'Bs. ' + bsTotal.toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2});
  };

  if (mSel) {
    mSel.onchange = () => {
      if (wBs) wBs.style.display = mSel.value === 'bolivares' ? 'block' : 'none';
      updateBsCalc();
    };
  }
  if (inpRate) inpRate.oninput = updateBsCalc;

  $('#btnConfirmPayProv').onclick = async () => {
    const ref = ($('#inpProvRef').value || '').trim();
    if (!ref) return toast('Ingresa el número de comprobante o referencia de pago.');

    const m = mSel.value;
    const rVal = parseFloat(inpRate?.value) || defRate;
    const notas = ($('#inpProvNotas').value || '').trim();
    const btn = $('#btnConfirmPayProv');
    btn.disabled = true;
    btn.textContent = '⏳ Procesando...';

    try {
      const { data: rpcRes, error: rpcErr } = await sb.rpc('pagar_compra_proveedor', {
        p_purchase_id: purchaseId,
        p_metodo: m,
        p_tasa: m === 'bolivares' ? rVal : null,
        p_comprobante: ref,
        p_notas: notas
      });
      if (rpcErr) throw rpcErr;
    } catch(err) {
      console.warn('Fallback a update directo en purchases:', err.message);
      const bsTot = m === 'bolivares' ? (curUsdt * rVal) : null;
      await sb.from('purchases').update({
        estado_pago: 'pagado',
        pagado_at: new Date().toISOString(),
        metodo_pago_proveedor: m,
        tasa_usdt_pago: m === 'bolivares' ? rVal : null,
        monto_pagado_bs: bsTot,
        comprobante_pago: ref,
        notas: notas ? notas : undefined
      }).eq('id', purchaseId);
    }

    toast(`Pago a ${proveedor} registrado con éxito.`);
    dlg.close();
    done && done();
  };
};

async function transferDlg(orderId, done) {
  return openTransferModal({ orderId, done });
}

async function openTransferModal({ profileId, orderId, done } = {}) {
  $('#dlgBody').innerHTML = `
    <div style="text-align:center;padding:24px">
      <div style="font-size:2rem;margin-bottom:8px">⏳</div>
      <p class="mut">Cargando inventario de perfiles y clientes...</p>
    </div>
  `;
  dlg.showModal();

  try {
    const [profSoldRes, profFreeRes, ordersRes] = await Promise.all([
      sb.from('profiles_inventory')
        .select('id,nombre_perfil,pin,inicia,vence,estado,product_id,mother_id,mother_accounts(id,plataforma,correo,clave),products(nombre)')
        .eq('estado', 'vendido')
        .order('nombre_perfil'),
      sb.from('profiles_inventory')
        .select('id,nombre_perfil,pin,estado,product_id,mother_id,mother_accounts(id,plataforma,correo,clave),products(nombre)')
        .eq('estado', 'disponible')
        .order('nombre_perfil'),
      sb.from('orders')
        .select('id,referencia,profile_id,inicia,vence,estado,customers!customer_id(id,nombre,email,telefono),products(nombre)')
        .in('estado', ['entregado', 'pagado'])
    ]);

    const soldProfiles = profSoldRes.data || [];
    const freeProfiles = profFreeRes.data || [];
    const activeOrders = ordersRes.data || [];

    if (!soldProfiles.length && !activeOrders.length) {
      $('#dlgBody').innerHTML = `
        <h3>🔀 Traslado / Reposición</h3>
        <p class="mut">No se encontraron perfiles vendidos ni pedidos activos para trasladar.</p>
        <div style="text-align:right;margin-top:14px"><button class="g" onclick="dlg.close()">Cerrar</button></div>
      `;
      return;
    }

    if (!freeProfiles.length) {
      $('#dlgBody').innerHTML = `
        <h3>🔀 Traslado / Reposición</h3>
        <p class="mut" style="color:#f87171">⚠️ No hay ningún perfil con estado 'disponible' en el inventario para realizar la reposición.</p>
        <p class="mut" style="font-size:.84rem">Agrega o genera nuevos perfiles libres en una cuenta madre antes de continuar.</p>
        <div style="text-align:right;margin-top:14px"><button class="g" onclick="dlg.close()">Cerrar</button></div>
      `;
      return;
    }

    // Mapa de órdenes por profile_id
    const orderByProfId = {};
    activeOrders.forEach(o => {
      if (o.profile_id) orderByProfId[o.profile_id] = o;
    });

    // Perfil origen inicial
    let selectedProfId = profileId || '';
    if (!selectedProfId && orderId) {
      const ord = activeOrders.find(x => x.id === orderId);
      if (ord?.profile_id) selectedProfId = ord.profile_id;
    }
    if (!selectedProfId && soldProfiles.length) {
      selectedProfId = soldProfiles[0].id;
    }

    let modeDifferentPlat = false;
    let daysCompensation = 0;

    const renderModal = () => {
      const curSource = soldProfiles.find(p => p.id === selectedProfId) || soldProfiles[0];
      const curOrder = curSource ? orderByProfId[curSource.id] : null;
      const curPlat = curSource?.mother_accounts?.plataforma || '';
      const clientName = curOrder?.customers?.nombre || curOrder?.customers?.email || 'Cliente sin registrar';
      const clientPhone = curOrder?.customers?.telefono || '';

      // Filtrar perfiles destino
      let targetOptions = freeProfiles;
      if (!modeDifferentPlat && curPlat) {
        targetOptions = freeProfiles.filter(p => (p.mother_accounts?.plataforma || '').toLowerCase() === curPlat.toLowerCase());
      }

      // Calcular fecha de vencimiento proyectada
      let originalVence = curSource?.vence || curOrder?.vence || new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10);
      let calculatedVence = originalVence;
      if (daysCompensation > 0) {
        const d = new Date(originalVence + 'T12:00:00Z');
        d.setUTCDate(d.getUTCDate() + daysCompensation);
        calculatedVence = d.toISOString().slice(0, 10);
      }

      $('#dlgBody').innerHTML = `
        <div style="max-height:80vh;overflow-y:auto;padding-right:4px">
          <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:12px">
            <div>
              <h3 style="margin:0 0 4px;display:flex;align-items:center;gap:8px">
                <span>🔀 Traslado / Reposición de Servicio</span>
              </h3>
              <p class="mut" style="font-size:.82rem;margin:0">
                Reubica la pantalla por falla/caída en la misma plataforma o migra al cliente a otra cuenta.
              </p>
            </div>
            <button class="g" type="button" onclick="dlg.close()" style="padding:4px 8px;font-size:.8rem">✕</button>
          </div>

          <!-- SECCIÓN 1: ORIGEN -->
          <div style="background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);border-radius:12px;padding:12px;margin-bottom:14px">
            <label class="mut" style="font-size:.76rem;font-weight:700;display:block;margin-bottom:6px;text-transform:uppercase;color:var(--c)">
              1. Selecciona el perfil / cliente a reponer:
            </label>
            <select id="selSourceProf" style="width:100%;font-size:.88rem;padding:8px 10px;border-radius:10px;background:rgba(0,0,0,.4);border:1px solid rgba(255,255,255,.2);color:#fff">
              ${soldProfiles.map(p => {
                const ord = orderByProfId[p.id];
                const cli = ord?.customers?.nombre || ord?.customers?.email || 'Sin vincular';
                const isSel = p.id === curSource?.id ? 'selected' : '';
                return `<option value="${p.id}" ${isSel}>[${esc(p.mother_accounts?.plataforma || 'Servicio')}] ${esc(p.mother_accounts?.correo || '')} · ${esc(p.nombre_perfil)} (Vence: ${p.vence || '—'}) · ${esc(cli)}</option>`;
              }).join('')}
            </select>

            <!-- FICHA DETALLE DEL ORIGEN -->
            <div style="margin-top:10px;display:grid;grid-template-columns:1fr 1fr;gap:8px;font-size:.78rem;background:rgba(0,0,0,.25);padding:10px;border-radius:8px;border-left:3px solid #38bdf8">
              <div><b>Plataforma:</b> ${esc(curPlat || '—')}</div>
              <div><b>Perfil Actual:</b> ${esc(curSource?.nombre_perfil || '—')}</div>
              <div><b>Cuenta Madre:</b> <code>${esc(curSource?.mother_accounts?.correo || '—')}</code></div>
              <div><b>Vence:</b> <b style="color:#00f5a0">${curSource?.vence || '—'}</b></div>
              <div style="grid-column:1 / -1"><b>Cliente Vinculado:</b> ${esc(clientName)} ${clientPhone ? `(📱 ${esc(clientPhone)})` : ''}</div>
            </div>
          </div>

          <!-- SECCIÓN 2: TIPO DE TRASLADO -->
          <div style="background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);border-radius:12px;padding:12px;margin-bottom:14px">
            <label class="mut" style="font-size:.76rem;font-weight:700;display:block;margin-bottom:8px;text-transform:uppercase;color:var(--c)">
              2. Modalidad de Traslado / Reposición:
            </label>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px">
              <button type="button" id="btnModeSame" class="g" style="padding:10px;border-radius:10px;font-size:.8rem;text-align:left;${!modeDifferentPlat ? 'background:rgba(56,189,248,.15);border-color:#38bdf8;color:#38bdf8;font-weight:800' : ''}">
                <div style="font-weight:800">🔵 Misma Plataforma</div>
                <div class="mut" style="font-size:.72rem;margin-top:2px">Reposición por cuenta caída (ej: ${esc(curPlat || 'Netflix')} ➔ ${esc(curPlat || 'Netflix')})</div>
              </button>
              <button type="button" id="btnModeDiff" class="g" style="padding:10px;border-radius:10px;font-size:.8rem;text-align:left;${modeDifferentPlat ? 'background:rgba(168,85,247,.15);border-color:#a855f7;color:#c084fc;font-weight:800' : ''}">
                <div style="font-weight:800">🟣 Otra Plataforma</div>
                <div class="mut" style="font-size:.72rem;margin-top:2px">Migración a otro servicio (ej: Netflix ➔ Max / Disney+)</div>
              </button>
            </div>
          </div>

          <!-- SECCIÓN 3: PERFIL DESTINO -->
          <div style="background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);border-radius:12px;padding:12px;margin-bottom:14px">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">
              <label class="mut" style="font-size:.76rem;font-weight:700;text-transform:uppercase;color:var(--c)">
                3. Selecciona el nuevo perfil disponible (Destino):
              </label>
              <span class="pill" style="font-size:.7rem;background:rgba(0,245,160,.12);color:#00f5a0">
                ${targetOptions.length} disponible(s)
              </span>
            </div>
            ${targetOptions.length ? `
              <select id="selTargetProf" style="width:100%;font-size:.88rem;padding:8px 10px;border-radius:10px;background:rgba(0,0,0,.4);border:1px solid rgba(0,245,160,.3);color:#fff">
                ${targetOptions.map(p => `
                  <option value="${p.id}">
                    [${esc(p.mother_accounts?.plataforma || 'Servicio')}] ${esc(p.mother_accounts?.correo || '')} · ${esc(p.nombre_perfil)}${p.pin ? ` (PIN: ${esc(p.pin)})` : ''}
                  </option>
                `).join('')}
              </select>
            ` : `
              <div style="background:rgba(239,68,68,.12);border:1px solid rgba(239,68,68,.3);padding:10px;border-radius:8px;font-size:.82rem;color:#fca5a5">
                ⚠️ No hay perfiles libres en <b>${esc(curPlat)}</b>. Cambia a "🟣 Otra Plataforma" o agrega una cuenta nueva.
              </div>
            `}
          </div>

          <!-- SECCIÓN 4: ACCIÓN CON EL PERFIL ANTERIOR -->
          <div style="background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);border-radius:12px;padding:12px;margin-bottom:14px">
            <label class="mut" style="font-size:.76rem;font-weight:700;display:block;margin-bottom:6px;text-transform:uppercase;color:var(--c)">
              4. ¿Qué hacer con el perfil anterior?
            </label>
            <select id="selOldAction" style="width:100%;font-size:.84rem;padding:8px 10px;border-radius:10px">
              <option value="false" selected>🚫 Suspender perfil anterior (Recomendado: La cuenta tuvo falla / caída)</option>
              <option value="true">🟢 Liberar perfil anterior (Devolverlo a disponible para la venta)</option>
            </select>
          </div>

          <!-- SECCIÓN 5: MOTIVO DEL TRASLADO -->
          <div style="background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);border-radius:12px;padding:12px;margin-bottom:14px">
            <label class="mut" style="font-size:.76rem;font-weight:700;display:block;margin-bottom:6px;text-transform:uppercase;color:var(--c)">
              5. Motivo del traslado / reposición:
            </label>
            <div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:8px">
              <button type="button" class="g tr-preset-btn" data-preset="⚠️ Pantalla caída / Falla de cuenta (Reposición)" style="padding:3px 8px;font-size:.72rem;border-radius:6px">⚠️ Pantalla caída</button>
              <button type="button" class="g tr-preset-btn" data-preset="🏠 Hogar Netflix / Restricción de red" style="padding:3px 8px;font-size:.72rem;border-radius:6px">🏠 Hogar Netflix</button>
              <button type="button" class="g tr-preset-btn" data-preset="🔄 Reposición preventiva por mantenimiento" style="padding:3px 8px;font-size:.72rem;border-radius:6px">🔄 Mantenimiento</button>
              <button type="button" class="g tr-preset-btn" data-preset="🔀 Cambio de plataforma solicitado por cliente" style="padding:3px 8px;font-size:.72rem;border-radius:6px">🔀 Cambio de plataforma</button>
            </div>
            <input id="inputMotivo" value="⚠️ Pantalla caída / Falla de cuenta (Reposición)" placeholder="Escribe el motivo..." style="width:100%;font-size:.84rem;padding:7px 10px;border-radius:8px">
          </div>

          <!-- SECCIÓN 6: FECHA Y COMPENSACIÓN -->
          <div style="background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);border-radius:12px;padding:12px;margin-bottom:16px">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">
              <label class="mut" style="font-size:.76rem;font-weight:700;text-transform:uppercase;color:var(--c)">
                6. Vencimiento del cliente & Compensación:
              </label>
            </div>
            <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-bottom:8px">
              <input type="date" id="inputVenceDate" value="${calculatedVence}" style="font-size:.9rem;padding:7px 10px;border-radius:8px;font-weight:700">
              <div style="display:flex;gap:6px;flex-wrap:wrap">
                <button type="button" class="g tr-comp-btn" data-add="0" style="padding:4px 8px;font-size:.72rem;border-radius:6px;${daysCompensation===0?'border-color:#38bdf8;color:#38bdf8;font-weight:700':''}">Exacto</button>
                <button type="button" class="g tr-comp-btn" data-add="1" style="padding:4px 8px;font-size:.72rem;border-radius:6px;${daysCompensation===1?'border-color:#00f5a0;color:#00f5a0;font-weight:700':''}">+1 día cortesía</button>
                <button type="button" class="g tr-comp-btn" data-add="3" style="padding:4px 8px;font-size:.72rem;border-radius:6px;${daysCompensation===3?'border-color:#00f5a0;color:#00f5a0;font-weight:700':''}">+3 días cortesía</button>
                <button type="button" class="g tr-comp-btn" data-add="5" style="padding:4px 8px;font-size:.72rem;border-radius:6px;${daysCompensation===5?'border-color:#00f5a0;color:#00f5a0;font-weight:700':''}">+5 días cortesía</button>
              </div>
            </div>
            <p class="mut" style="font-size:.76rem;margin:0">
              El cliente conserva sus días intactos hasta el <b>${calculatedVence}</b>. Si la cuenta estuvo caída, puedes sumarle días de cortesía.
            </p>
          </div>

          <!-- BOTÓN CONFIRMAR -->
          <div style="display:flex;gap:10px;justify-content:flex-end">
            <button type="button" class="g" onclick="dlg.close()">Cancelar</button>
            <button type="button" id="btnSubmitTransfer" style="background:var(--grad);color:#03121c;font-weight:800;border:none;border-radius:10px;padding:10px 20px;cursor:pointer;font-size:.92rem" ${!targetOptions.length ? 'disabled' : ''}>
              🚀 Confirmar y Ejecutar Traslado
            </button>
          </div>
        </div>
      `;

      // Eventos del modal
      $('#selSourceProf').onchange = e => {
        selectedProfId = e.target.value;
        renderModal();
      };

      $('#btnModeSame').onclick = () => {
        modeDifferentPlat = false;
        renderModal();
      };
      $('#btnModeDiff').onclick = () => {
        modeDifferentPlat = true;
        renderModal();
      };

      $('#dlgBody').querySelectorAll('.tr-preset-btn').forEach(btn => {
        btn.onclick = () => {
          $('#inputMotivo').value = btn.dataset.preset;
        };
      });

      $('#dlgBody').querySelectorAll('.tr-comp-btn').forEach(btn => {
        btn.onclick = () => {
          daysCompensation = Number(btn.dataset.add);
          renderModal();
        };
      });

      $('#btnSubmitTransfer').onclick = async () => {
        const btn = $('#btnSubmitTransfer');
        const targetId = $('#selTargetProf')?.value;
        if (!targetId) return toast('Selecciona un perfil destino disponible');

        const motivoVal = $('#inputMotivo')?.value?.trim() || 'Reposición de servicio';
        const liberarAnterior = $('#selOldAction')?.value === 'true';
        const finalVence = $('#inputVenceDate')?.value || calculatedVence;

        btn.disabled = true;
        btn.textContent = '⏳ Ejecutando traslado...';

        const chosenTarget = freeProfiles.find(p => p.id === targetId);

        try {
          // Intentar ejecutar mediante función SQL RPC
          let rpcSuccess = false;
          try {
            const { data, error } = await sb.rpc('transfer_service', {
              p_from_profile: curSource.id,
              p_to_profile: targetId,
              p_motivo: motivoVal,
              p_liberar_anterior: liberarAnterior,
              p_order: curOrder?.id || null,
              p_nueva_fecha_vence: finalVence,
              p_permitir_otra_plataforma: true
            });
            if (!error && data?.success) {
              rpcSuccess = true;
            }
          } catch (rpcErr) {
            console.warn('RPC transfer_service no disponible aún, usando ejecución directa:', rpcErr);
          }

          // Fallback directo en caso de que la migración SQL no se haya ejecutado aún
          if (!rpcSuccess) {
            await sb.from('profiles_inventory').update({
              estado: 'vendido',
              inicia: curSource.inicia || new Date().toISOString().slice(0, 10),
              vence: finalVence
            }).eq('id', targetId);

            await sb.from('profiles_inventory').update({
              estado: liberarAnterior ? 'disponible' : 'suspendido',
              inicia: null,
              vence: null
            }).eq('id', curSource.id);

            if (curOrder?.id) {
              await sb.from('orders').update({
                profile_id: targetId,
                product_id: chosenTarget?.product_id || curOrder.product_id,
                vence: finalVence
              }).eq('id', curOrder.id);
            }

            try {
              await sb.from('transfers').insert({
                order_id: curOrder?.id || null,
                customer_id: curOrder?.customers?.id || null,
                from_profile: curSource.id,
                to_profile: targetId,
                motivo: motivoVal
              });
            } catch(e) {}
          }

          // Obtener credenciales reveladas
          let revealedPass = chosenTarget?.mother_accounts?.clave || '';
          if (revealedPass.startsWith('enc:')) {
            try {
              const { data: rev } = await sb.rpc('reveal_secret', { p: revealedPass });
              if (rev) revealedPass = rev;
            } catch(e) {}
          }

          // Pantalla de éxito con botón para enviar por WhatsApp
          const newPlat = chosenTarget?.mother_accounts?.plataforma || curPlat;
          const newMail = chosenTarget?.mother_accounts?.correo || '';
          const newProf = chosenTarget?.nombre_perfil || '';
          const newPin = chosenTarget?.pin || '';

          const waMsg = encodeURIComponent(
            `¡Hola ${clientName}! 👋 Te enviamos la reposición de tu servicio *${newPlat}*:\n\n` +
            `📧 *Correo:* ${newMail}\n` +
            `🔑 *Contraseña:* ${revealedPass}\n` +
            `👤 *Perfil:* ${newProf}\n` +
            (newPin ? `🔢 *PIN:* ${newPin}\n` : '') +
            `📅 *Tu servicio continúa activo hasta el:* ${finalVence}\n\n` +
            `¡Cualquier detalle o duda estamos a tu orden por aquí!`
          );

          const waUrl = clientPhone ? `https://wa.me/${clientPhone.replace(/\D/g, '')}?text=${waMsg}` : '';

          $('#dlgBody').innerHTML = `
            <div style="text-align:center;padding:14px 6px">
              <div style="font-size:3rem;margin-bottom:8px">🎉</div>
              <h3 style="margin:0 0 6px;color:#00f5a0">¡Traslado Realizado con Éxito!</h3>
              <p class="mut" style="font-size:.85rem;margin:0 0 16px">
                El perfil anterior ha sido ${liberarAnterior ? 'liberado' : 'suspendido por falla'} y el cliente ya cuenta con sus nuevos accesos activos.
              </p>

              <div style="background:rgba(0,0,0,.35);border:1px solid rgba(0,245,160,.3);border-radius:12px;padding:14px;text-align:left;font-size:.84rem;margin-bottom:18px">
                <div style="font-size:.78rem;font-weight:800;color:#38bdf8;text-transform:uppercase;margin-bottom:6px">Nuevos Accesos Asignados:</div>
                <div><b>Plataforma:</b> ${esc(newPlat)}</div>
                <div><b>Correo:</b> <code>${esc(newMail)}</code></div>
                <div><b>Contraseña:</b> <code>${esc(revealedPass)}</code></div>
                <div><b>Perfil:</b> ${esc(newProf)}</div>
                ${newPin ? `<div><b>PIN de Pantalla:</b> <code>${esc(newPin)}</code></div>` : ''}
                <div><b>Vence:</b> <b style="color:#00f5a0">${finalVence}</b></div>
              </div>

              <div style="display:flex;gap:10px;justify-content:center;flex-wrap:wrap">
                ${waUrl ? `
                  <a href="${waUrl}" target="_blank" rel="noopener noreferrer" style="background:#25D366;color:#fff;padding:10px 18px;border-radius:10px;text-decoration:none;font-weight:800;display:inline-flex;align-items:center;gap:6px">
                    <span>💬 Enviar Nuevos Accesos por WhatsApp</span>
                  </a>
                ` : `
                  <button type="button" class="g" onclick="navigator.clipboard.writeText(decodeURIComponent('${waMsg}')).then(()=>toast('Mensaje copiado'))">
                    📋 Copiar Mensaje de Accesos
                  </button>
                `}
                <button type="button" class="g" onclick="dlg.close()">Cerrar</button>
              </div>
            </div>
          `;

          done && done();
        } catch (err) {
          btn.disabled = false;
          btn.textContent = '🚀 Confirmar y Ejecutar Traslado';
          toast('Error en traslado: ' + err.message);
        }
      };
    };

    renderModal();
  } catch (err) {
    $('#dlgBody').innerHTML = `<p class="mut" style="color:#f87171">Error cargando inventario: ${esc(err.message)}</p><button class="g" onclick="dlg.close()">Cerrar</button>`;
  }
}
async function genDlg(motherId, done) {
  const { data: prods } = await sb.from('products').select('id,nombre,tipo').order('nombre');
  $('#dlgBody').innerHTML = `<h3>Generar perfiles</h3><p class="mut">Crea perfiles disponibles para esta cuenta. Para vender la cuenta completa, genera 1 con un producto tipo cuenta_completa. Luego agrega el PIN de cada uno en profiles_inventory.</p>
  <select id="gp">${(prods || []).map(p => `<option value="${p.id}">${esc(p.nombre)} (${esc(p.tipo)})</option>`).join('')}</select>
  <input id="gq" type="number" min="1" max="20" value="5" style="margin-top:8px"><input id="gx" value="Perfil" style="margin-top:8px">
  <button id="gok" style="margin-top:10px;width:100%">Crear</button>`; dlg.showModal();
  $('#gok').onclick = e => run(e.target, async () => { const { error } = await sb.rpc('generate_profiles', { p_mother: motherId, p_product: $('#gp').value, p_cantidad: +$('#gq').value, p_prefijo: $('#gx').value || 'Perfil' }); if (error) throw error; done && done(); return 'Perfiles creados.'; });
}

// 📢 Avisar Actualización de Credenciales a Clientes y Revendedores de una Cuenta Madre
async function notifyMotherClients(motherId) {
  dlg.style.maxWidth = '640px';
  $('#dlgBody').innerHTML = `
    <div style="text-align:center;padding:26px 12px">
      <div style="font-size:2.4rem;margin-bottom:8px">📢</div>
      <h3 style="margin:0 0 6px;color:#00f5a0">Avisar Actualización a Clientes</h3>
      <p class="mut" style="font-size:.85rem;margin:0 0 16px">Consultando perfiles, órdenes y clientes vinculados a esta cuenta madre...</p>
      <div class="sk" style="max-width:320px;min-height:90px;margin:auto"></div>
    </div>
  `;
  dlg.showModal();

  try {
    const cleanWaFn = window.cleanWaPhone || function(phone) {
      if (!phone) return '';
      let clean = String(phone).replace(/\D/g, '');
      if (!clean) return '';
      clean = clean.replace(/^0+/, '');
      if (clean.length === 10) return '58' + clean;
      if (!clean.startsWith('58') && clean.length <= 11) return '58' + clean;
      return clean;
    };

    // 1. Obtener datos de la cuenta madre
    const { data: mother, error: mErr } = await sb.from('mother_accounts').select('*').eq('id', motherId).single();
    if (mErr || !mother) throw new Error(mErr?.message || 'Cuenta madre no encontrada');

    let plainPass = mother.clave || '';
    if (plainPass.startsWith('enc:')) {
      try {
        const { data: rev } = await sb.rpc('reveal_secret', { p: plainPass });
        if (rev) plainPass = rev;
      } catch(e) {}
    }

    // 2. Obtener perfiles de esta cuenta madre
    const { data: profiles, error: pErr } = await sb.from('profiles_inventory')
      .select('id, nombre_perfil, pin, estado, inicia, vence, assigned_customer_id, vendedor, vendedor_id, products(nombre)')
      .eq('mother_id', motherId)
      .order('nombre_perfil');
    if (pErr) throw pErr;

    const profList = profiles || [];
    const profIds = profList.map(p => p.id);

    // 3. Traer órdenes activas asociadas a estos perfiles
    let ordersByProf = {};
    if (profIds.length > 0) {
      const { data: ords } = await sb.from('orders')
        .select('id, profile_id, customer_id, vence, referencia, reseller_id, customers!customer_id(id, nombre, email, telefono, es_revendedor)')
        .in('profile_id', profIds)
        .in('estado', ['entregado', 'pagado']);
      (ords || []).forEach(o => { ordersByProf[o.profile_id] = o; });
    }

    // 4. Mapear clientes por assigned_customer_id
    const assignedIds = profList.map(p => p.assigned_customer_id).filter(Boolean);
    let custMap = {};
    if (assignedIds.length > 0) {
      const { data: custs } = await sb.from('customers').select('id, nombre, email, telefono, es_revendedor').in('id', assignedIds);
      (custs || []).forEach(c => { custMap[c.id] = c; });
    }

    // 5. Mapear todos los clientes con teléfono para auto-emparejar por nombre si es de revendedor
    let allCustsWithPhone = [];
    try {
      const { data: ac } = await sb.from('customers').select('id, nombre, telefono').not('telefono', 'is', null);
      allCustsWithPhone = ac || [];
    } catch(e) {}

    // 6. Mapear revendedores si aplica
    const resellerIds = new Set();
    profList.forEach(p => { if (p.vendedor_id) resellerIds.add(p.vendedor_id); });
    Object.values(ordersByProf).forEach(o => { if (o.reseller_id) resellerIds.add(o.reseller_id); });
    let resellerMap = {};
    if (resellerIds.size > 0) {
      const { data: resList } = await sb.from('customers').select('id, nombre, email, telefono').in('id', Array.from(resellerIds));
      (resList || []).forEach(r => { resellerMap[r.id] = r; });
    }

    // Identificar perfiles ocupados/vendidos o disponibles
    const occupiedProfiles = profList.filter(p => p.estado === 'vendido' || ordersByProf[p.id] || p.assigned_customer_id);

    const plat = mother.plataforma || 'Servicio Digital';
    const mail = mother.correo || '—';

    // Generar resumen general para portapapeles
    let generalSummary = `📢 *ACTUALIZACIÓN DE CREDENCIALES (${plat.toUpperCase()})*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `📧 *Nuevo Correo:* ${mail}\n` +
      `🔑 *Nueva Contraseña:* ${plainPass}\n\n` +
      `👥 *PERFILES ACTIVOS:*\n`;

    occupiedProfiles.forEach((p, idx) => {
      const ord = ordersByProf[p.id];
      let cli = ord?.customers?.nombre || custMap[p.assigned_customer_id]?.nombre || ord?.customers?.email || '';
      if (!cli || cli.toLowerCase().includes('pablo')) {
        const ref = ord?.referencia || '';
        const m1 = ref.match(/\[[^\]]+\]\s*(?:Renovación\s+)?([^-]+)\s*-\s*([^($]+)/i);
        if (m1) cli = m1[1].trim();
        else {
          const m2 = ref.match(/·\s*([^($]+)/);
          if (m2 && !m2[1].toLowerCase().includes('pablo')) cli = m2[1].trim();
        }
      }
      if (!cli) cli = `Cliente ${idx + 1}`;
      const pinTxt = p.pin ? ` · PIN: ${p.pin}` : '';
      const venTxt = p.vence || ord?.vence || mother.vence || '';
      generalSummary += `${idx + 1}. *${p.nombre_perfil}* (${cli})${pinTxt}${venTxt ? ` - Vence: ${venTxt}` : ''}\n`;
    });
    generalSummary += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nYa pueden ingresar con estos datos en la app de streaming. ¡A la orden!`;

    // Detectar si hay revendedores involucrados
    const resellersFound = {};
    occupiedProfiles.forEach(p => {
      const ord = ordersByProf[p.id];
      const resId = p.vendedor_id || ord?.reseller_id;
      let resNom = p.vendedor || (resId ? resellerMap[resId]?.nombre : null);
      if (!resNom && ord?.referencia && /pablo/i.test(ord.referencia)) {
        resNom = 'Pablo Gonzalez';
      }
      if (resNom) {
        if (!resellersFound[resNom]) {
          resellersFound[resNom] = {
            nombre: resNom,
            telefono: (resId ? resellerMap[resId]?.telefono : null) || (resNom.toLowerCase().includes('pablo') ? '584129130080' : ''),
            profiles: []
          };
        }
        resellersFound[resNom].profiles.push({ profile: p, order: ord });
      }
    });

    // Renderizar modal
    $('#dlgBody').innerHTML = `
      <div style="max-height:82vh;overflow-y:auto;padding-right:4px">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;border-bottom:1px solid rgba(255,255,255,.1);padding-bottom:10px">
          <div>
            <h3 style="margin:0;color:#00f5a0;font-size:1.15rem;display:flex;align-items:center;gap:8px">
              <span>📢</span> Avisar Actualización a Clientes
            </h3>
            <span class="mut" style="font-size:.76rem">Envía las nuevas credenciales por WhatsApp sin cambiar de orden ni comprar nada</span>
          </div>
          <button class="g" id="btnCloseNotifyMotherDlg" style="padding:4px 8px;font-size:.8rem">✕</button>
        </div>

        <div style="background:rgba(0,245,160,.06);border:1.5px solid rgba(0,245,160,.3);border-radius:12px;padding:12px;margin-bottom:16px;font-size:.84rem">
          <div style="font-size:.72rem;font-weight:800;color:#00f5a0;text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px">
            📺 Datos Actualizados de la Cuenta Madre (${esc(plat)}):
          </div>
          <div style="display:grid;grid-template-columns:1fr;gap:4px">
            <div>📧 <b>Correo:</b> <code style="font-size:.88rem;color:#38bdf8">${esc(mail)}</code></div>
            <div>🔑 <b>Contraseña:</b> <code style="font-size:.88rem;color:#fde047">${esc(plainPass)}</code></div>
            ${mother.vence ? `<div>📅 <b>Vence Cuenta Madre:</b> ${esc(mother.vence)}</div>` : ''}
          </div>
          <div style="margin-top:10px;display:flex;gap:8px">
            <button id="btnCopyMotherFullSummary" class="g" style="font-size:.76rem;padding:6px 12px;background:rgba(255,255,255,.08);color:#fff;font-weight:700">
              📋 Copiar Resumen Completo de la Cuenta
            </button>
          </div>
        </div>

        ${Object.keys(resellersFound).length > 0 ? `
          <div style="background:rgba(56,189,248,.08);border:1.5px solid rgba(56,189,248,.3);border-radius:12px;padding:12px;margin-bottom:16px">
            <div style="font-size:.74rem;font-weight:800;color:#38bdf8;text-transform:uppercase;margin-bottom:6px">
              🤝 Aviso a Revendedores con clientes en esta cuenta:
            </div>
            ${Object.values(resellersFound).map(rf => {
              const rCleanPhone = cleanWaFn(rf.telefono);
              let rMsg = `¡Hola ${rf.nombre}! 👋 Te comparto las credenciales actualizadas de la cuenta madre de *${plat}* para tus clientes:\n\n` +
                `📧 *Nuevo Correo:* ${mail}\n` +
                `🔑 *Nueva Contraseña:* ${plainPass}\n\n` +
                `👥 *Tus perfiles en esta cuenta:*\n`;
              rf.profiles.forEach(rp => {
                let cNom = rp.order?.customers?.nombre || custMap[rp.profile.assigned_customer_id]?.nombre || '';
                if (!cNom || cNom.toLowerCase().includes('pablo')) {
                  const ref = rp.order?.referencia || '';
                  const m1 = ref.match(/\[[^\]]+\]\s*(?:Renovación\s+)?([^-]+)\s*-\s*([^($]+)/i);
                  if (m1) cNom = m1[1].trim();
                  else {
                    const m2 = ref.match(/·\s*([^($]+)/);
                    if (m2 && !m2[1].toLowerCase().includes('pablo')) cNom = m2[1].trim();
                  }
                }
                if (!cNom) cNom = 'Cliente';
                const pPin = rp.profile.pin ? ` · PIN: ${rp.profile.pin}` : '';
                const pVen = rp.profile.vence || rp.order?.vence || '';
                rMsg += `• *${rp.profile.nombre_perfil}* (${cNom})${pPin}${pVen ? ` - Vence: ${pVen}` : ''}\n`;
              });
              rMsg += `\nYa pueden ingresar con estos datos. ¡Cualquier duda a la orden!`;
              const rWaUrl = rCleanPhone ? `https://wa.me/${rCleanPhone}?text=${encodeURIComponent(rMsg)}` : '';

              return `
                <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;padding:6px 0;border-bottom:1px dashed rgba(255,255,255,.1)">
                  <div>
                    <b style="color:#fff;font-size:.85rem">${esc(rf.nombre)}</b>
                    <span class="pill" style="font-size:.65rem;margin-left:6px">${rf.profiles.length} perfil(es)</span>
                    ${rf.telefono ? `<span class="mut" style="font-size:.72rem;display:block">📲 +${esc(rCleanPhone)}</span>` : ''}
                  </div>
                  <div>
                    ${rWaUrl ? `
                      <a href="${rWaUrl}" target="_blank" rel="noopener noreferrer" class="g" style="font-size:.74rem;padding:6px 10px;background:rgba(37,211,102,.15);color:#25d366;border-color:rgba(37,211,102,.4);text-decoration:none;font-weight:700;display:inline-flex;align-items:center;gap:4px">
                        💬 Avisar a ${esc(rf.nombre.split(' ')[0])} por WA
                      </a>
                    ` : `
                      <button class="g" onclick="navigator.clipboard.writeText(decodeURIComponent('${encodeURIComponent(rMsg)}')).then(()=>toast('Mensaje para revendedor copiado'))" style="font-size:.74rem;padding:6px 10px">
                        📋 Copiar Mensaje
                      </button>
                    `}
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        ` : ''}

        <h4 style="margin:16px 0 8px;font-size:.9rem;color:#fff;display:flex;align-items:center;justify-content:space-between">
          <span>👥 Clientes Activos en esta Cuenta (${occupiedProfiles.length}):</span>
          <span class="mut" style="font-size:.72rem">Haz clic para enviar WhatsApp directo a cada cliente</span>
        </h4>

        ${occupiedProfiles.length === 0 ? `
          <p class="mut" style="font-size:.82rem;padding:12px;background:rgba(255,255,255,.02);border-radius:10px">
            Esta cuenta no tiene perfiles vendidos ni clientes asignados en este momento.
          </p>
        ` : `
          <div style="display:flex;flex-direction:column;gap:8px">
            ${occupiedProfiles.map((p, idx) => {
              const ord = ordersByProf[p.id];
              let cliNom = ord?.customers?.nombre || custMap[p.assigned_customer_id]?.nombre || ord?.customers?.email || '';
              let cliTel = ord?.customers?.telefono || custMap[p.assigned_customer_id]?.telefono || '';
              const venceFinal = p.vence || ord?.vence || mother.vence || '';
              const pinFinal = p.pin || '';

              if (!cliNom || cliNom.toLowerCase().includes('pablo')) {
                const ref = ord?.referencia || '';
                const m1 = ref.match(/\[[^\]]+\]\s*(?:Renovación\s+)?([^-]+)\s*-\s*([^($]+)/i);
                if (m1) {
                  cliNom = m1[1].trim();
                } else {
                  const m2 = ref.match(/·\s*([^($]+)/);
                  if (m2 && !m2[1].toLowerCase().includes('pablo')) cliNom = m2[1].trim();
                }
              }
              if (!cliNom) cliNom = p.nombre_perfil || `Perfil ${idx + 1}`;

              // Auto-búsqueda de teléfono si no vino en la orden
              if (!cliTel && allCustsWithPhone.length > 0 && cliNom) {
                const fCust = allCustsWithPhone.find(c => c.nombre && c.nombre.toLowerCase().includes(cliNom.toLowerCase()));
                if (fCust?.telefono) cliTel = fCust.telefono;
              }

              const resId = p.vendedor_id || ord?.reseller_id;
              const resNom = p.vendedor || (resId ? resellerMap[resId]?.nombre : null) || (ord?.referencia && /pablo/i.test(ord.referencia) ? 'Pablo Gonzalez' : null);

              const waMsgClient = `¡Hola ${cliNom}! 👋 Te informamos que realizamos una *actualización de credenciales* en tu servicio de *${plat}*:\n\n` +
                `📧 *Nuevo Correo:* ${mail}\n` +
                `🔑 *Nueva Contraseña:* ${plainPass}\n` +
                `👤 *Tu Perfil:* ${p.nombre_perfil}\n` +
                (pinFinal ? `🔢 *PIN:* ${pinFinal}\n` : '') +
                (venceFinal ? `📅 *Tu servicio continúa activo hasta el:* ${venceFinal}\n\n` : '\n') +
                `Ya puedes ingresar con estos datos en la app de streaming. ¡Cualquier duda estamos a tu orden!`;

              const cleanPhone = cleanWaFn(cliTel);
              const waClientUrl = cleanPhone ? `https://wa.me/${cleanPhone}?text=${encodeURIComponent(waMsgClient)}` : '';

              return `
                <div style="background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.08);border-radius:10px;padding:10px 12px;display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap">
                  <div style="min-width:180px">
                    <div style="display:flex;align-items:center;gap:6px">
                      <b style="color:#00f5a0;font-size:.88rem">${esc(p.nombre_perfil)}</b>
                      ${pinFinal ? `<code style="font-size:.72rem;background:rgba(0,245,160,.12);color:#00f5a0;padding:1px 5px;border-radius:4px">PIN: ${esc(pinFinal)}</code>` : ''}
                    </div>
                    <div style="font-size:.82rem;font-weight:700;color:#fff;margin-top:2px">
                      👤 ${esc(cliNom)}
                    </div>
                    ${resNom ? `
                      <div style="font-size:.7rem;color:#fde047;margin-top:1px">
                        🤝 Revendedor: <b>${esc(resNom)}</b>
                      </div>
                    ` : ''}
                    <div class="mut" style="font-size:.72rem;margin-top:2px">
                      📅 Vence: <b>${esc(venceFinal || '—')}</b>
                      ${cleanPhone ? ` · 📲 +${esc(cleanPhone)}` : ' · <span style="color:#f87171">Sin tel registrado</span>'}
                    </div>
                  </div>

                  <div style="display:flex;gap:6px;align-items:center">
                    ${waClientUrl ? `
                      <a href="${waClientUrl}" target="_blank" rel="noopener noreferrer" class="g" style="padding:6px 10px;font-size:.75rem;background:rgba(37,211,102,.12);color:#25d366;border-color:rgba(37,211,102,.35);font-weight:700;text-decoration:none;display:inline-flex;align-items:center;gap:4px">
                        💬 Enviar WA
                      </a>
                    ` : ''}
                    <button class="g" onclick="navigator.clipboard.writeText(decodeURIComponent('${encodeURIComponent(waMsgClient)}')).then(()=>toast('Mensaje copiado al portapapeles'))" style="padding:6px 8px;font-size:.75rem" title="Copiar mensaje">
                      📋 Copiar
                    </button>
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        `}

        <div style="margin-top:18px;display:flex;justify-content:flex-end">
          <button class="g" id="btnCloseNotifyMotherBottom">Cerrar</button>
        </div>
      </div>
    `;

    const closeHandler = () => {
      dlg.style.maxWidth = '';
      dlg.close();
    };
    $('#btnCloseNotifyMotherDlg').onclick = closeHandler;
    $('#btnCloseNotifyMotherBottom').onclick = closeHandler;

    $('#btnCopyMotherFullSummary').onclick = () => {
      navigator.clipboard.writeText(generalSummary).then(() => {
        toast('✅ Resumen completo de la cuenta copiado al portapapeles.');
      });
    };

  } catch(err) {
    console.error('Error al consultar clientes de cuenta madre:', err);
    $('#dlgBody').innerHTML = `
      <h3>⚠️ Error</h3>
      <p class="mut">${esc(err.message || err)}</p>
      <div style="display:flex;justify-content:flex-end;margin-top:14px">
        <button class="g" onclick="dlg.style.maxWidth='';dlg.close()">Cerrar</button>
      </div>
    `;
  }
}
window.notifyMotherClients = notifyMotherClients;

async function pushSub() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) throw new Error('Este navegador no permite push. En iPhone instala la app en la pantalla de inicio (iOS 16.4 o superior).');
  if (await Notification.requestPermission() !== 'granted') throw new Error('Permiso de notificaciones denegado en este dispositivo.');
  const reg = await navigator.serviceWorker.ready, { key } = await (await fetch('/api/push-key')).json();
  if (!key) throw new Error('Primero pulsa "1. Activar / guardar".');
  const b = key.replace(/-/g, '+').replace(/_/g, '/'), k = Uint8Array.from(atob(b + '='.repeat((4 - b.length % 4) % 4)), c => c.charCodeAt(0));
  const sub = (await reg.pushManager.getSubscription()) || await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: k }), j = sub.toJSON();
  const { error } = await sb.from('push_subscriptions').upsert({ endpoint: j.endpoint, p256dh: j.keys.p256dh, auth: j.keys.auth, user_agent: navigator.userAgent.slice(0, 120) }, { onConflict: 'endpoint' });
  if (error) throw error;
}

const EXTRA = {
  async notificaciones(box) {
    if (!box) return;
    const { data: cfg } = await sb.from('settings').select('value').eq('key', 'notificaciones').maybeSingle();
    const { data: subs } = await sb.from('push_subscriptions').select('id,user_agent,created_at').order('created_at', { ascending: false });
    if (!box.isConnected) {
      const activeBox = document.querySelector('#ex');
      if (activeBox) box = activeBox;
      else return;
    }
    box.innerHTML = `<p class="mut">Avisos de pedidos, recargas, incidencias y vencimientos del día por <b>Telegram</b> y <b>push</b>: llegan aunque la app esté cerrada. Para Telegram, el bot debe estar conectado (pestaña telegram) y debes haberle escrito /start.</p>
    <label class="mut">Tu ID de Telegram</label><input id="tg" value="${esc(cfg?.value?.telegram_chat_id || '')}" inputmode="numeric" style="max-width:260px">
    <div class="row" style="margin:10px 0"><button id="n1">1. Activar / guardar</button><button id="n2">2. Activar push en este dispositivo</button><button class="g" id="n3">Enviar prueba</button></div>
    <h3>Dispositivos con push (${(subs || []).length})</h3>${(subs || []).map(s => `<div class="row card" style="margin-bottom:6px;justify-content:space-between"><span class="mut">${esc((s.user_agent || '').slice(0, 70))} · ${esc(String(s.created_at).slice(0, 10))}</span><button class="d" data-del="${s.id}">Quitar</button></div>`).join('') || '<p class="mut">Ninguno todavía.</p>'}`;
    const bN1 = box.querySelector('#n1') || document.querySelector('#n1');
    if (bN1) bN1.onclick = e => run(e.target, async () => { await api('/api/notify-setup', { telegram_chat_id: ($('#tg')?.value || '').trim() }); return 'Notificaciones activadas y datos guardados.'; });
    const bN2 = box.querySelector('#n2') || document.querySelector('#n2');
    if (bN2) bN2.onclick = e => run(e.target, async () => { await pushSub(); EXTRA.notificaciones(box); return 'Este dispositivo recibirá notificaciones push.'; });
    const bN3 = box.querySelector('#n3') || document.querySelector('#n3');
    if (bN3) bN3.onclick = e => run(e.target, async () => { const r = await api('/api/notify-test', {}); return `Prueba enviada. Telegram: ${r.telegram ? 'sí' : 'no'} · Push: ${r.push} dispositivo(s).` + (r.errores?.length ? '\n' + r.errores.join(' | ') : ''); });
    box.querySelectorAll('[data-del]').forEach(b => b.onclick = async () => { await sb.from('push_subscriptions').delete().eq('id', b.dataset.del); EXTRA.notificaciones(box); });
  },
  async orders(box) {
    box.innerHTML = `<div style="text-align:center;padding:40px"><span style="font-size:2rem">⏳</span><p class="mut">Cargando pedidos de clientes...</p></div>`;

    let ordList = [];
    let resellers = [];
    try {
      const [resOrd, resResellers] = await Promise.all([
        sb.from('orders')
          .select('*, customers!customer_id(id,nombre,email,telefono,codigo_identificacion), products(id,nombre,tipo), profiles_inventory(id,nombre_perfil,pin,mother_id,mother_accounts(plataforma,correo))')
          .order('created_at', { ascending: false })
          .limit(300),
        sb.from('customers')
          .select('id,nombre,email,codigo_identificacion')
          .eq('es_revendedor', true)
      ]);
      ordList = resOrd?.data;
      if (!ordList) {
        const { data: rawOrds } = await sb.from('orders').select('*').order('created_at', { ascending: false }).limit(300);
        ordList = rawOrds || [];
      }
      resellers = resResellers?.data || [];
    } catch(errFetch) {
      console.warn('Error fetching orders:', errFetch);
      try {
        const { data: rawOrds } = await sb.from('orders').select('*').order('created_at', { ascending: false }).limit(300);
        ordList = rawOrds || [];
      } catch(e2) {
        return box.innerHTML = `<p class="mut">Error al cargar pedidos: ${esc(errFetch.message)}</p>`;
      }
    }

    const sellersMap = {};
    resellers.forEach(r => {
      sellersMap[r.id] = r.nombre || r.codigo_identificacion || r.email;
    });

    box._orderFilter = box._orderFilter || 'todos';
    box._searchQuery = box._searchQuery || '';

    const filterVal = box._orderFilter;
    const searchVal = box._searchQuery.toLowerCase().trim();

    const totalOrders = ordList.length;
    const pendCount = ordList.filter(o => o.estado === 'pendiente').length;
    const credCount = ordList.filter(o => o.estado === 'entregado' && (o.referencia && o.referencia.toLowerCase().includes('crédito'))).length;
    const deliveredCount = ordList.filter(o => o.estado === 'entregado').length;
    const totalUsdVol = ordList.filter(o => ['entregado', 'pagado'].includes(o.estado)).reduce((a, o) => a + Number(o.total_usd || 0), 0);

    let filtered = ordList.filter(o => {
      if (filterVal === 'pendientes') return o.estado === 'pendiente';
      if (filterVal === 'credito') return (o.referencia && o.referencia.toLowerCase().includes('crédito'));
      if (filterVal === 'entregados') return o.estado === 'entregado';
      if (filterVal === 'rechazados') return ['rechazado', 'cancelado', 'vencido'].includes(o.estado);
      return true;
    });

    if (searchVal) {
      filtered = filtered.filter(o => {
        const cNom = o.customers?.nombre || '';
        const cEmail = o.customers?.email || '';
        const cTel = o.customers?.telefono || '';
        const prod = o.products?.nombre || '';
        const ref = o.referencia || '';
        const id = String(o.id || '');
        const seller = sellersMap[o.vendedor_id] || '';
        const text = `${cNom} ${cEmail} ${cTel} ${prod} ${ref} ${id} ${seller}`.toLowerCase();
        return text.includes(searchVal);
      });
    }

    const render = () => {
      EXTRA.orders(box);
    };

    box.innerHTML = `
      <!-- Métricas Superiores -->
      <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px;margin-bottom:16px">
        <div class="card" style="background:rgba(234,179,8,.08);border:1.5px solid rgba(234,179,8,.35)">
          <div style="display:flex;justify-content:space-between;align-items:center">
            <span class="mut" style="font-size:.76rem">🟡 Pendientes de Conciliación</span>
            <span style="font-size:1.4rem">🛒</span>
          </div>
          <div style="font-size:1.7rem;font-weight:900;color:#fde047;margin:4px 0">${pendCount}</div>
          <span class="mut" style="font-size:.72rem">${pendCount ? 'Requieren entrega / revisión' : 'Todo conciliado al día'}</span>
        </div>

        <div class="card" style="background:rgba(255,183,3,.08);border:1.5px solid rgba(255,183,3,.35)">
          <div style="display:flex;justify-content:space-between;align-items:center">
            <span class="mut" style="font-size:.76rem">💳 A Crédito / Revendedores</span>
            <span style="font-size:1.4rem">🤝</span>
          </div>
          <div style="font-size:1.7rem;font-weight:900;color:#ffb703;margin:4px 0">${credCount}</div>
          <span class="mut" style="font-size:.72rem">Líneas de crédito y plazos activos</span>
        </div>

        <div class="card" style="background:rgba(0,245,160,.08);border:1.5px solid rgba(0,245,160,.35)">
          <div style="display:flex;justify-content:space-between;align-items:center">
            <span class="mut" style="font-size:.76rem">🟢 Pedidos Entregados</span>
            <span style="font-size:1.4rem">✅</span>
          </div>
          <div style="font-size:1.7rem;font-weight:900;color:#00f5a0;margin:4px 0">${deliveredCount}</div>
          <span class="mut" style="font-size:.72rem">Activos en plataforma</span>
        </div>

        <div class="card" style="background:rgba(56,189,248,.08);border:1.5px solid rgba(56,189,248,.35)">
          <div style="display:flex;justify-content:space-between;align-items:center">
            <span class="mut" style="font-size:.76rem">💰 Total Facturado (Ventas)</span>
            <span style="font-size:1.4rem">💵</span>
          </div>
          <div style="font-size:1.7rem;font-weight:900;color:#38bdf8;margin:4px 0">$${totalUsdVol.toFixed(2)} USD</div>
          <span class="mut" style="font-size:.72rem">${totalOrders} transacciones totales</span>
        </div>
      </div>

      <!-- Barra de Filtros y Búsqueda -->
      <div style="background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.08);border-radius:14px;padding:12px 16px;margin-bottom:16px;display:flex;flex-wrap:wrap;gap:12px;justify-content:space-between;align-items:center">
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          <button class="g btn-order-filter ${filterVal==='todos'?'active':''}" data-f="todos" style="padding:6px 12px;font-size:.78rem;font-weight:700;${filterVal==='todos'?'background:rgba(255,255,255,.15);border-color:#fff;color:#fff':''}">
            📋 Todos (${totalOrders})
          </button>
          <button class="g btn-order-filter ${filterVal==='pendientes'?'active':''}" data-f="pendientes" style="padding:6px 12px;font-size:.78rem;font-weight:700;${filterVal==='pendientes'?'background:rgba(234,179,8,.2);border-color:#fde047;color:#fde047':'color:#fde047'}">
            🟡 Pendientes (${pendCount})
          </button>
          <button class="g btn-order-filter ${filterVal==='credito'?'active':''}" data-f="credito" style="padding:6px 12px;font-size:.78rem;font-weight:700;${filterVal==='credito'?'background:rgba(255,183,3,.2);border-color:#ffb703;color:#ffb703':'color:#ffb703'}">
            💳 A Crédito (${credCount})
          </button>
          <button class="g btn-order-filter ${filterVal==='entregados'?'active':''}" data-f="entregados" style="padding:6px 12px;font-size:.78rem;font-weight:700;${filterVal==='entregados'?'background:rgba(0,245,160,.2);border-color:#00f5a0;color:#00f5a0':'color:#00f5a0'}">
            🟢 Entregados (${deliveredCount})
          </button>
          <button class="g btn-order-filter ${filterVal==='rechazados'?'active':''}" data-f="rechazados" style="padding:6px 12px;font-size:.78rem;font-weight:700;${filterVal==='rechazados'?'background:rgba(239,68,68,.2);border-color:#f87171;color:#f87171':'color:#f87171'}">
            🔴 Rechazados / Vencidos
          </button>
        </div>

        <div style="flex:1;min-width:240px;max-width:380px">
          <input id="inSearchOrders" value="${esc(box._searchQuery)}" placeholder="🔍 Buscar cliente, ref, servicio o ID..." style="width:100%;font-size:.82rem;padding:7px 12px;border-radius:10px">
        </div>
      </div>

      <!-- Tabla de Pedidos -->
      ${filtered.length === 0 ? `
        <div class="card" style="text-align:center;padding:36px;border:1.5px dashed rgba(255,255,255,.15);border-radius:14px">
          <div style="font-size:2.5rem;margin-bottom:8px">📦</div>
          <h4 style="margin:0 0 6px">No se encontraron pedidos con este filtro</h4>
          <p class="mut" style="font-size:.82rem;margin:0">Prueba cambiando la pestaña de filtro o limpiando el buscador.</p>
        </div>
      ` : `
        <div class="wrap">
          <table style="width:100%;font-size:.82rem">
            <thead>
              <tr>
                <th style="min-width:90px">Pedido</th>
                <th style="min-width:160px">Cliente</th>
                <th style="min-width:130px">Servicio / Producto</th>
                <th style="min-width:110px">Total</th>
                <th style="min-width:160px">Pago / Ref</th>
                <th style="min-width:100px">Estado</th>
                <th style="min-width:140px">Acciones</th>
              </tr>
            </thead>
            <tbody>
              ${filtered.map(o => {
                const cNom = o.customers?.nombre || o.customers?.email || 'Cliente';
                const cEmail = o.customers?.email || '';
                const cTel = o.customers?.telefono || '';
                const cleanPhone = cTel.replace(/\D/g, '');
                const waTarget = cleanPhone.startsWith('58') ? cleanPhone : (cleanPhone ? '58' + cleanPhone.replace(/^0+/, '') : '');
                const prodName = o.products?.nombre || 'Servicio Digital';
                const profName = o.profiles_inventory?.nombre_perfil || '';
                const profPin = o.profiles_inventory?.pin || '';
                const isPinEnc = profPin && profPin.startsWith('enc:');
                const sellerNom = sellersMap[o.vendedor_id];
                const isCredit = o.referencia && o.referencia.toLowerCase().includes('crédito');
                const createdStr = o.created_at ? new Date(o.created_at).toLocaleString('es-VE', { dateStyle: 'short', timeStyle: 'short' }) : '—';
                const hasVoucher = !!o.comprobante_url;

                let statusBadge = '';
                if (o.estado === 'pendiente') {
                  statusBadge = '<span class="pill" style="background:rgba(234,179,8,.18);color:#fde047;border-color:rgba(234,179,8,.4);font-weight:800">🟡 Pendiente</span>';
                } else if (isCredit) {
                  statusBadge = '<span class="pill" style="background:rgba(255,183,3,.18);color:#ffb703;border-color:rgba(255,183,3,.4);font-weight:800">💳 A Crédito</span>';
                } else if (o.estado === 'entregado') {
                  statusBadge = '<span class="pill" style="background:rgba(0,245,160,.18);color:#00f5a0;border-color:rgba(0,245,160,.4);font-weight:800">🟢 Entregado</span>';
                } else if (o.estado === 'vencido') {
                  statusBadge = '<span class="pill" style="background:rgba(148,163,184,.15);color:#94a3b8;border-color:rgba(148,163,184,.3)">⚪ Vencido</span>';
                } else {
                  statusBadge = `<span class="pill" style="background:rgba(239,68,68,.18);color:#f87171;border-color:rgba(239,68,68,.4)">🔴 ${esc(o.estado)}</span>`;
                }

                let gamingHtml = '';
                if (o.datos_recarga) {
                  const d = o.datos_recarga;
                  const servVal = d.texto_activacion || d.datos_activacion || d.correo_activacion;
                  if (d.player_id || d.telefono) {
                    const gText = d.player_id ? `🎮 ID: ${d.player_id}${d.servidor ? ' ('+d.servidor+')' : ''}` : `📱 ${d.operadora||''}: ${d.telefono||''}`;
                    const copyVal = d.player_id || d.telefono;
                    gamingHtml = `<div style="margin-top:3px;font-size:.72rem;color:#fde047;display:flex;align-items:center;gap:4px"><b>${esc(gText)}</b><button type="button" class="g" style="padding:1px 5px;font-size:.65rem" data-clean-copy="${esc(copyVal)}" title="Copiar dato">📋</button></div>`;
                  } else if (servVal) {
                    gamingHtml = `<div style="margin-top:3px;font-size:.72rem;color:#c084fc;display:flex;align-items:center;gap:4px"><b>📝 Dato: ${esc(servVal)}</b><button type="button" class="g" style="padding:1px 5px;font-size:.65rem" data-clean-copy="${esc(servVal)}" title="Copiar dato de activación">📋</button></div>`;
                  }
                }

                return `
                  <tr style="${o.estado === 'pendiente' ? 'background:rgba(234,179,8,.04)' : ''}">
                    <td>
                      <b>#${esc(String(o.id || '').slice(0, 8))}</b>
                      <div class="mut" style="font-size:.7rem;margin-top:2px">${createdStr}</div>
                      ${sellerNom ? `<div style="margin-top:3px"><span class="pill" style="font-size:.65rem;background:rgba(255,183,3,.15);color:#ffb703;border-color:rgba(255,183,3,.3)">🤝 Rev: ${esc(sellerNom)}</span></div>` : ''}
                    </td>

                    <td>
                      <b>${esc(cNom)}</b>
                      ${cTel ? `
                        <div style="margin-top:2px;display:flex;align-items:center;gap:4px">
                          <a href="https://wa.me/${waTarget}" target="_blank" rel="noopener noreferrer" style="font-size:.74rem;color:#25d366;text-decoration:none;font-weight:700">
                            📲 ${esc(cTel)}
                          </a>
                        </div>
                      ` : ''}
                      ${cEmail ? `<div class="mut" style="font-size:.7rem">${esc(cEmail)}</div>` : ''}
                    </td>

                    <td>
                      <b style="color:var(--c)">${esc(prodName)}</b>
                      ${profName ? `<div style="font-size:.72rem;color:#38bdf8;margin-top:2px">👤 ${esc(profName)} ${profPin ? (isPinEnc ? '🔒 PIN Cifrado' : `· PIN: ${esc(profPin)}`) : ''}</div>` : ''}
                      ${gamingHtml}
                    </td>

                    <td>
                      <b style="color:#00f5a0;font-size:.95rem">$${Number(o.total_usd || 0).toFixed(2)} USD</b>
                      ${o.total_bs ? `<div class="mut" style="font-size:.72rem">Bs. ${Number(o.total_bs).toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</div>` : ''}
                      ${o.zeny_aplicado > 0 ? `<div style="font-size:.68rem;color:#38bdf8">ZP -$${Number(o.zeny_aplicado).toFixed(2)}</div>` : ''}
                    </td>

                    <td>
                      <div style="font-size:.75rem;line-height:1.3;max-width:200px;word-break:break-word">
                        ${esc(o.referencia || '—')}
                      </div>
                      ${hasVoucher ? `
                        <button class="g btn-view-voucher" data-img="${esc(o.comprobante_url)}" style="margin-top:4px;padding:3px 7px;font-size:.68rem;color:#38bdf8;border-color:rgba(56,189,248,.3)">
                          🖼️ Ver Comprobante
                        </button>
                      ` : ''}
                    </td>

                    <td>
                      ${statusBadge}
                      ${o.vence ? `<div class="mut" style="font-size:.68rem;margin-top:3px">Vence: ${esc(o.vence)}</div>` : ''}
                    </td>

                    <td>
                      <div class="row" style="gap:4px;flex-wrap:wrap">
                        ${['pendiente', 'vencido'].includes(o.estado) ? `
                          <button class="g btn-order-deliver" data-ord="${o.id}" data-tot="${o.total_usd}" data-nom="${esc(cNom)}" style="padding:4px 8px;font-size:.73rem;background:rgba(0,245,160,.15);color:#00f5a0;border-color:rgba(0,245,160,.4);font-weight:800" title="Conciliar y entregar credenciales">
                            ✅ Entregar
                          </button>
                          <button class="g btn-order-credit" data-ord="${o.id}" data-tot="${o.total_usd}" data-nom="${esc(cNom)}" data-tel="${esc(cTel)}" data-prod="${esc(prodName)}" style="padding:4px 8px;font-size:.73rem;background:rgba(255,183,3,.15);color:#ffb703;border-color:rgba(255,183,3,.35);font-weight:700" title="Entregar a Crédito a cliente o revendedor">
                            💳 Crédito
                          </button>
                          <button class="g btn-order-reject" data-ord="${o.id}" style="padding:4px 7px;font-size:.73rem;color:#f87171;border-color:rgba(239,68,68,.3)" title="Rechazar y liberar perfil">
                            ❌
                          </button>
                        ` : ''}

                        ${o.estado === 'entregado' && o.profile_id ? `
                          <button class="g btn-order-tr" data-prof="${o.profile_id}" style="padding:4px 7px;font-size:.73rem;color:#38bdf8;border-color:rgba(56,189,248,.3)" title="Trasladar o reponer pantalla">
                            🔀
                          </button>
                        ` : ''}

                        ${['pagado', 'entregado'].includes(o.estado) ? `
                          <button class="g btn-order-refund" data-ord="${o.id}" data-tot="${o.total_usd}" style="padding:4px 7px;font-size:.73rem" title="Registrar devolución / reembolso">
                            🔄
                          </button>
                        ` : ''}

                        ${waTarget ? `
                          <a href="https://wa.me/${waTarget}?text=${encodeURIComponent('Hola ' + cNom + '! 👋 Te escribimos de Emprendimiento Gregory Izquierdo respecto a tu pedido #' + String(o.id).slice(0, 8) + ' (' + prodName + ').')}" target="_blank" rel="noopener noreferrer" class="g" style="padding:4px 7px;font-size:.73rem;color:#25d366;border-color:rgba(37,211,102,.3);text-decoration:none" title="Chatear por WhatsApp">
                            💬
                          </a>
                        ` : ''}

                        <button class="d btn-order-del" data-ord="${o.id}" style="padding:4px 7px;font-size:.73rem" title="Eliminar orden permanentemente">
                          🗑️
                        </button>
                      </div>
                    </td>
                  </tr>
                `;
              }).join('')}
            </tbody>
          </table>
        </div>
      `}
    `;

    box.querySelectorAll('.btn-order-filter').forEach(btn => {
      btn.onclick = () => {
        box._orderFilter = btn.dataset.f;
        render();
      };
    });

    const searchInp = box.querySelector('#inSearchOrders');
    if (searchInp) {
      searchInp.oninput = () => {
        box._searchQuery = searchInp.value;
        clearTimeout(box._searchTimer);
        box._searchTimer = setTimeout(render, 250);
      };
    }

    box.querySelectorAll('.btn-view-voucher').forEach(btn => {
      btn.onclick = () => {
        const imgUrl = btn.dataset.img;
        $('#dlgBody').innerHTML = `
          <h3>🖼️ Comprobante de Pago</h3>
          <div style="text-align:center;margin:14px 0">
            <a href="${esc(imgUrl)}" target="_blank" rel="noopener noreferrer">
              <img src="${esc(imgUrl)}" alt="Comprobante" style="max-width:100%;max-height:70vh;border-radius:12px;border:1px solid rgba(255,255,255,.15);box-shadow:0 10px 30px rgba(0,0,0,.5)">
            </a>
          </div>
          <div style="display:flex;justify-content:space-between;align-items:center">
            <a href="${esc(imgUrl)}" target="_blank" rel="noopener noreferrer" class="g" style="text-decoration:none;font-size:.8rem">
              ↗ Abrir imagen en pestaña nueva
            </a>
            <button class="g" onclick="dlg.close()">Cerrar</button>
          </div>
        `;
        dlg.showModal();
      };
    });

    box.querySelectorAll('.btn-order-deliver').forEach(btn => {
      btn.onclick = async () => {
        const ordId = btn.dataset.ord;
        const nom = btn.dataset.nom;
        const tot = btn.dataset.tot;
        if (!confirm(`¿Confirmas que verificaste el pago de $${tot} USD de ${nom} y deseas entregar las credenciales del servicio?`)) return;

        btn.disabled = true;
        btn.textContent = '⏳...';

        try {
          const { error: rpcErr } = await sb.rpc('deliver_order', { p_order: ordId });
          if (rpcErr) {
            const { error: updErr } = await sb.from('orders').update({
              estado: 'entregado',
              pagado_at: new Date().toISOString(),
              conciliado_at: new Date().toISOString(),
              conciliado_por: S.me?.email || S.user?.email || 'admin'
            }).eq('id', ordId);
            if (updErr) throw updErr;
          }
          toast(`✅ Pedido de ${nom} entregado con éxito.`);
          render();
        } catch(err) {
          btn.disabled = false;
          btn.textContent = '✅ Entregar';
          alert('Error al entregar pedido: ' + err.message);
        }
      };
    });

    box.querySelectorAll('.btn-order-credit').forEach(btn => {
      btn.onclick = async () => {
        const ordId = btn.dataset.ord;
        const nom = btn.dataset.nom;
        const tot = Number(btn.dataset.tot || 0);
        const tel = (btn.dataset.tel || '').replace(/\D/g, '');
        const prod = btn.dataset.prod;

        const dias = prompt(`¿A cuántos días de crédito entregas el servicio a ${nom}?`, '7');
        if (!dias || isNaN(dias)) return;

        btn.disabled = true;
        btn.textContent = '⏳...';

        const fVence = new Date(Date.now() + Number(dias) * 86400000).toISOString().slice(0, 10);

        try {
          const { error: rpcErr } = await sb.rpc('deliver_order', { p_order: ordId });
          if (rpcErr) {
            await sb.from('orders').update({
              estado: 'entregado',
              pagado_at: new Date().toISOString()
            }).eq('id', ordId);
          }

          await sb.from('orders').update({
            referencia: `[CRÉDITO] Vence ${fVence} ($${tot.toFixed(2)} USD)`
          }).eq('id', ordId);

          const bcv = Number(S.rate || 1);
          try {
            await sb.from('installments').insert({
              order_id: ordId,
              customer_id: ordList.find(o => o.id === ordId)?.customer_id,
              numero_cuota: 1,
              total_cuotas: 1,
              monto_usd: tot,
              monto_bs: Number((tot * bcv).toFixed(2)),
              tasa_bs: bcv,
              fecha_vencimiento: fVence,
              estado: 'pendiente',
              referencia: `[CRÉDITO] ${nom} - ${prod} ($${tot.toFixed(2)} USD)`
            });
          } catch(eInst) {
            console.warn('Installment insert warning:', eInst);
          }

          toast(`✅ Pedido entregado a CRÉDITO a ${nom} por ${dias} días.`);
          render();
        } catch(err) {
          btn.disabled = false;
          btn.textContent = '💳 Crédito';
          alert('Error al procesar crédito: ' + err.message);
        }
      };
    });

    box.querySelectorAll('.btn-order-reject').forEach(btn => {
      btn.onclick = async () => {
        const ordId = btn.dataset.ord;
        if (!confirm('¿Seguro que deseas rechazar este pedido? El perfil reservado será liberado inmediatamente.')) return;

        btn.disabled = true;
        try {
          const { error } = await sb.rpc('reject_order', { p_order: ordId });
          if (error) {
            await sb.from('orders').update({ estado: 'rechazado' }).eq('id', ordId);
          }
          toast('Pedido rechazado y stock restaurado.');
          render();
        } catch(err) {
          btn.disabled = false;
          alert('Error al rechazar pedido: ' + err.message);
        }
      };
    });

    box.querySelectorAll('.btn-order-tr').forEach(btn => {
      btn.onclick = () => {
        openTransferModal({ profileId: btn.dataset.prof, done: render });
      };
    });

    box.querySelectorAll('.btn-order-refund').forEach(btn => {
      btn.onclick = () => {
        refundDlg(btn.dataset.ord, btn.dataset.tot, render);
      };
    });

    box.querySelectorAll('.btn-order-del').forEach(btn => {
      btn.onclick = () => run(btn, async () => {
        const ordId = btn.dataset.ord;
        if (!confirm('¿Seguro que deseas eliminar permanentemente esta orden del sistema?')) return;
        try {
          const { error: rpcErr } = await sb.rpc('admin_delete_order', { p_order_id: ordId });
          if (!rpcErr) {
            toast('Orden eliminada correctamente.');
            return render();
          }
        } catch(e) {
          console.warn('RPC admin_delete_order no disponible, usando fallback manual:', e);
        }
        // Fallback manual limpiando dependencias hijas primero
        try { await sb.from('invoices').delete().eq('order_id', ordId); } catch(e){}
        try { await sb.from('installments').delete().eq('order_id', ordId); } catch(e){}
        try { await sb.from('refunds').delete().eq('order_id', ordId); } catch(e){}
        try { await sb.from('transfers').delete().eq('order_id', ordId); } catch(e){}
        try { await sb.from('incidents').update({ order_id: null }).eq('order_id', ordId); } catch(e){}
        try { await sb.from('zeny_ledger').update({ order_id: null }).eq('order_id', ordId); } catch(e){}
        const { error } = await sb.from('orders').delete().eq('id', ordId);
        if (error) throw error;
        toast('Orden eliminada correctamente.');
        render();
      });
    });
  },
  async vencimientos(box) {
    if (!box._calState) {
      const now = new Date();
      box._calState = { year: now.getFullYear(), month: now.getMonth(), selectedDate: now.toISOString().slice(0, 10) };
    }
    const state = box._calState;
    const pad = n => String(n).padStart(2, '0');
    const startMonth = `${state.year}-${pad(state.month + 1)}-01`;
    const lastDayOfMonth = new Date(state.year, state.month + 1, 0).getDate();
    const endMonth = `${state.year}-${pad(state.month + 1)}-${pad(lastDayOfMonth)}`;
    const calConnected = GCal.isConnected();

    box.innerHTML = '<p class="mut">Cargando calendario de vencimientos y Google Calendar…</p>';

    // Consultamos pedidos entregados/activos, cuentas madre, inventario de perfiles y eventos de Google Calendar en paralelo
    const pms = [
      sb.from('orders')
        .select('id,customer_id,product_id,profile_id,total_usd,referencia,inicia,vence,gcal_event_id,estado,customers!customer_id(nombre,email,telefono),products(nombre)')
        .not('vence', 'is', null)
        .gte('vence', startMonth)
        .lte('vence', endMonth),
      sb.from('mother_accounts')
        .select('id,plataforma,correo,vence,activa,proveedor,costo_usd')
        .not('vence', 'is', null)
        .gte('vence', startMonth)
        .lte('vence', endMonth),
      sb.from('profiles_inventory')
        .select('id,nombre_perfil,vence,vendedor,pin,estado,product_id,mother_id,no_renueva,no_renueva_motivo,products(nombre),mother_accounts(plataforma,correo)')
        .eq('estado', 'vendido')
        .not('vence', 'is', null)
        .gte('vence', startMonth)
        .lte('vence', endMonth)
    ];

    if (calConnected) {
      pms.push(GCal.listMonthEvents(state.year, state.month + 1).catch(e => {
        console.warn('GCal fetch warning:', e);
        return [];
      }));
    }

    const [resOrd, resMoth, resProf, resGcal] = await Promise.all(pms);
    const orders = resOrd?.data || [];
    const mothers = resMoth?.data || [];
    const profiles = resProf?.data || [];
    const gcalEvents = Array.isArray(resGcal) ? resGcal : [];

    if (resOrd?.error || resMoth?.error || resProf?.error) {
      return box.innerHTML = `<p class="mut">Error al cargar datos: ${esc((resOrd?.error || resMoth?.error || resProf?.error).message)}</p>`;
    }

    const monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    const todayStr = new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 10);

    // Mapear eventos por fecha (YYYY-MM-DD)
    const linkedGcalIds = new Set(orders.map(o => o.gcal_event_id).filter(Boolean));
    const eventsByDate = {};
    orders.forEach(o => {
      const d = o.vence;
      if (!eventsByDate[d]) eventsByDate[d] = { orders: [], mothers: [], profiles: [], gcal: [] };
      eventsByDate[d].orders.push(o);
    });
    mothers.forEach(m => {
      const d = m.vence;
      if (!eventsByDate[d]) eventsByDate[d] = { orders: [], mothers: [], profiles: [], gcal: [] };
      eventsByDate[d].mothers.push(m);
    });
    profiles.forEach(p => {
      const d = p.vence;
      if (!eventsByDate[d]) eventsByDate[d] = { orders: [], mothers: [], profiles: [], gcal: [] };
      eventsByDate[d].profiles.push(p);
    });
    gcalEvents.forEach(g => {
      g._isLinked = linkedGcalIds.has(g.id);
      if (g._isLinked) {
        g._order = orders.find(o => o.gcal_event_id === g.id);
      }
      const d = GCal.getEventDate(g);
      if (d) {
        if (!eventsByDate[d]) eventsByDate[d] = { orders: [], mothers: [], profiles: [], gcal: [] };
        eventsByDate[d].gcal.push(g);
      }
    });

    const totalOrdersMonth = orders.length;
    const totalMothersMonth = mothers.length;
    const totalProfilesMonth = profiles.length;
    const totalGcalMonth = gcalEvents.length;
    const todayEvents = eventsByDate[todayStr] || { orders: [], mothers: [], profiles: [], gcal: [] };
    const todayTotal = todayEvents.orders.length + todayEvents.mothers.length + (todayEvents.profiles?.length || 0) + (todayEvents.gcal || []).filter(g => !g._isLinked).length;

    // Calculo de celdas de calendario estilo Hoja de Calculo Google Sheets
    const firstDayIndex = new Date(state.year, state.month, 1).getDay(); // Domingo = 0
    const prevMonthDays = new Date(state.year, state.month, 0).getDate();

    const daysHtml = [];
    const weekHeaders = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'].map(d => `<div class="cal-sheet-th">${d}</div>`).join('');

    // Celdas del mes anterior
    for (let i = firstDayIndex - 1; i >= 0; i--) {
      const dNum = prevMonthDays - i;
      daysHtml.push(`<div class="cal-sheet-cell disabled"><span class="cal-sheet-num">${dNum}</span></div>`);
    }

    // Dias del mes actual
    for (let d = 1; d <= lastDayOfMonth; d++) {
      const dStr = `${state.year}-${pad(state.month + 1)}-${pad(d)}`;
      const ev = eventsByDate[dStr];
      const isToday = dStr === todayStr;
      const isSel = dStr === state.selectedDate;
      const numOrd = ev?.orders?.length || 0;
      const numProf = ev?.profiles?.length || 0;
      const totalCli = numOrd + numProf;
      const numMoth = ev?.mothers?.length || 0;
      const numGcalUnlinked = (ev?.gcal || []).filter(g => !g._isLinked).length;

      let itemsHtml = '';
      if (totalCli > 0) itemsHtml += `<div class="cal-item-pill order" title="${totalCli} clientes/perfiles">👤 ${totalCli} cliente${totalCli > 1 ? 's' : ''}</div>`;
      if (numMoth > 0) itemsHtml += `<div class="cal-item-pill mother" title="${numMoth} cuentas madre">🔑 ${numMoth} cuenta${numMoth > 1 ? 's' : ''}</div>`;
      if (numGcalUnlinked > 0) itemsHtml += `<div class="cal-item-pill gcal" style="background:#e8f0fe;color:#1a73e8;border-left:3px solid #1a73e8" title="${numGcalUnlinked} eventos en Google Calendar">📅 ${numGcalUnlinked} Calendar</div>`;

      daysHtml.push(`
        <div class="cal-sheet-cell ${isToday ? 'is-today' : ''} ${isSel ? 'is-selected' : ''}" data-day="${dStr}">
          <span class="cal-sheet-num">${d}</span>
          <div class="cal-sheet-items">${itemsHtml}</div>
        </div>
      `);
    }

    // Completar cuadrícula restante para múltiplos de 7
    const remainingDays = (7 - ((firstDayIndex + lastDayOfMonth) % 7)) % 7;
    for (let r = 1; r <= remainingDays; r++) {
      daysHtml.push(`<div class="cal-sheet-cell disabled"><span class="cal-sheet-num">${r}</span></div>`);
    }

    // Detalle del día seleccionado
    const selDate = state.selectedDate || todayStr;
    const selEvents = eventsByDate[selDate] || { orders: [], mothers: [], profiles: [], gcal: [] };
    const selTotal = (selEvents.orders?.length || 0) + (selEvents.mothers?.length || 0) + (selEvents.profiles?.length || 0) + (selEvents.gcal || []).filter(g => !g._isLinked).length;

    const noRenuevanGlobal = (profiles || []).filter(p => p.no_renueva);
    let noRenBannerHtml = '';
    if (noRenuevanGlobal.length > 0) {
      noRenBannerHtml = `
        <div style="background:rgba(239,68,68,.12);border:1.5px solid rgba(239,68,68,.4);border-radius:12px;padding:12px 16px;margin-bottom:14px;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px">
          <div style="display:flex;align-items:center;gap:10px">
            <span style="font-size:1.5rem">📢</span>
            <div>
              <b style="color:#f87171;font-size:.9rem">Reporte de Revendedores: ${noRenuevanGlobal.length} perfil(es) marcados como "NO RENUEVA"</b>
              <div class="mut" style="font-size:.76rem;margin-top:2px">
                Los clientes confirmaron que no continuarán. Cambia el PIN en la app de streaming y pulsa <b>"🔓 Liberar"</b> para sumarlos de inmediato al stock de la tienda.
              </div>
            </div>
          </div>
        </div>
      `;
    }

    let detailHtml = `
      <div class="cal-detail">
        ${noRenBannerHtml}
        <div style="display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:8px;margin-bottom:12px">
          <h4 style="margin:0;font-size:1.05rem">Vencimientos para el <b>${selDate}</b> ${selDate === todayStr ? '· (Hoy)' : ''}</h4>
          <span class="mut" style="font-size:.8rem">${selTotal} vencimiento${selTotal === 1 ? '' : 's'} en total</span>
        </div>
    `;

    if (selTotal === 0 && (!selEvents.gcal || selEvents.gcal.length === 0)) {
      detailHtml += '<p class="mut" style="margin:0">No hay servicios ni cuentas madre programados para vencer en esta fecha.</p>';
    } else {
      if (selEvents.profiles && selEvents.profiles.length > 0) {
        detailHtml += `
          <h5 style="margin:8px 0 6px;color:#00f5a0;display:flex;align-items:center;justify-content:space-between">
            <span>👤 Perfiles y Clientes Activos (${selEvents.profiles.length})</span>
            <span class="pill" style="font-size:.7rem;background:rgba(0,245,160,.12);color:#00f5a0;border:1px solid rgba(0,245,160,.3)">Inventario en Uso</span>
          </h5>
          <div class="wrap" style="margin-bottom:12px">
            <table>
              <tr><th>Cliente / Perfil</th><th>Servicio</th><th>Cuenta Madre</th><th>PIN</th><th>Vendedor</th><th>Vence</th><th>Acciones</th></tr>
              ${selEvents.profiles.map(p => {
                const srvName = p.products?.nombre || p.mother_accounts?.plataforma || 'Servicio';
                const motherMail = p.mother_accounts?.correo || '—';
                const clientName = p.nombre_perfil || 'Cliente';
                const waText = encodeURIComponent(`Hola ${clientName}! 👋 Te recordamos de Emprendimiento Gregory Izquierdo que tu servicio de ${srvName} tiene fecha de cobro/vencimiento el día de hoy (${p.vence}). Por favor indícanos si deseas renovar para mantener tu perfil activo.`);
                return `
                <tr style="${p.no_renueva ? 'background:rgba(239,68,68,.06)' : ''}">
                  <td>
                    <b>${esc(clientName)}</b>
                    ${p.no_renueva ? `<div style="margin-top:3px"><span class="pill" style="font-size:.68rem;padding:2px 6px;background:rgba(239,68,68,.18);color:#f87171;border:1px solid rgba(239,68,68,.4);font-weight:800">🔴 NO RENUEVA</span></div>` : ''}
                  </td>
                  <td><b style="color:var(--c)">${esc(srvName)}</b></td>
                  <td><small>${esc(motherMail)}</small></td>
                  <td>${(typeof p.pin === 'string' && p.pin.startsWith('enc:')) ? '<span class="pill" style="font-size:.68rem" title="PIN protegido en base de datos">🔒 Cifrado</span>' : `<code>${esc(p.pin || '—')}</code>`}</td>
                  <td><span class="pill" style="font-size:.7rem">${esc(p.vendedor || 'ADMIN')}</span></td>
                  <td><b style="color:#f59e0b">${esc(p.vence)}</b></td>
                  <td class="row" style="gap:5px">
                    <button class="g" data-cal-release-prof="${p.id}" data-cur-pin="${esc(p.pin||'')}" data-nom="${esc(clientName)}" data-srv="${esc(srvName)}" data-mail="${esc(motherMail)}" style="padding:4px 8px;font-size:.73rem;background:${p.no_renueva ? 'rgba(239,68,68,.22)' : 'rgba(0,245,160,.14)'};color:${p.no_renueva ? '#f87171' : '#00f5a0'};border:1.5px solid ${p.no_renueva ? 'rgba(239,68,68,.5)' : 'rgba(0,245,160,.35)'};font-weight:800" title="Liberar perfil para la venta en la tienda">
                      ${p.no_renueva ? '🔓 Liberar YA' : '🔓 Liberar'}
                    </button>
                    <button class="g" data-cal-tr-prof="${p.id}" style="padding:4px 8px;font-size:.73rem;background:rgba(56,189,248,.15);color:#38bdf8;border:1px solid rgba(56,189,248,.3)" title="Trasladar o reponer pantalla caída">
                      🔀 Reponer
                    </button>
                    <button class="g" data-cal-renov-prof="${p.id}" data-cal-renov-30d-prof="${p.id}" data-cur-date="${p.vence}" data-nom="${esc(clientName)}" data-srv="${esc(srvName)}" style="padding:4px 8px;font-size:.73rem;background:rgba(16,185,129,.18);color:#10b981;border:1px solid rgba(16,185,129,.35);font-weight:700" title="Renovar ciclo de suscripción (+30 días desde la fecha agendada)">
                      🔄 Renovar (+30d)
                    </button>
                    <button class="g" data-cal-edit-prof-date="${p.id}" data-cur-date="${p.vence}" data-nom="${esc(clientName)}" data-srv="${esc(srvName)}" style="padding:4px 8px;font-size:.73rem" title="Modificar fecha de vencimiento">
                      ✏️ Fecha
                    </button>
                    <a href="https://api.whatsapp.com/send?text=${waText}" target="_blank" rel="noopener noreferrer" class="cal-sheet-btn" style="text-decoration:none;padding:4px 8px;font-size:.73rem;background:rgba(0,245,160,.15);color:#00f5a0;border-radius:6px;border:1px solid rgba(0,245,160,.3)" title="Enviar recordatorio por WhatsApp">
                      💬 Recordar WA
                    </a>
                  </td>
                </tr>
              `;}).join('')}
            </table>
          </div>
        `;
      }
      if (selEvents.orders.length > 0) {
        detailHtml += `
          <h5 style="margin:8px 0 6px;color:var(--c)">Servicios de Clientes Web (${selEvents.orders.length})</h5>
          <div class="wrap" style="margin-bottom:12px">
            <table>
              <tr><th>Pedido</th><th>Cliente</th><th>Servicio</th><th>Contacto</th><th>Estado</th><th>Google Calendar</th><th>Acciones</th></tr>
              ${selEvents.orders.map(o => `
                <tr>
                  <td><b>#${esc(String(o.id).slice(0, 8))}</b></td>
                  <td>${esc(o.customers?.nombre || o.customers?.email || 'Cliente')}</td>
                  <td><b>${esc(o.products?.nombre || '—')}</b></td>
                  <td>${esc(o.customers?.telefono || o.customers?.email || '—')}</td>
                  <td><span class="pill ${o.estado === 'entregado' ? '' : 'off'}">${esc(o.estado)}</span></td>
                  <td>
                    ${o.gcal_event_id ? '<span class="pill" style="font-size:.68rem;background:rgba(0,245,160,.12);color:#00f5a0;border:1px solid rgba(0,245,160,.3)" title="Sincronizado con Google Calendar">🟢 En Calendar</span>' : '<span class="pill off" style="font-size:.68rem" title="Pendiente de sincronizar">⏳ No sync</span>'}
                  </td>
                  <td class="row" style="gap:5px">
                    <button class="g" data-cal-renov-order="${o.id}" data-cal-renov-30d-order="${o.id}" data-cur-date="${o.vence}" data-nom="${esc(o.customers?.nombre || o.customers?.email || 'Cliente')}" data-prod="${esc(o.products?.nombre || 'Servicio')}" data-gcal-id="${esc(o.gcal_event_id || '')}" style="padding:4px 8px;font-size:.73rem;background:rgba(16,185,129,.18);color:#10b981;border:1px solid rgba(16,185,129,.35);font-weight:700" title="Renovar ciclo de suscripción (+30 días desde la fecha agendada)">
                      🔄 Renovar (+30d)
                    </button>
                    <button class="g" data-cal-edit-date="${o.id}" data-cur-date="${o.vence}" data-prod="${esc(o.products?.nombre || 'Servicio')}" data-nom="${esc(o.customers?.nombre || o.customers?.email || 'Cliente')}" data-gcal-id="${esc(o.gcal_event_id || '')}" style="padding:4px 8px;font-size:.73rem" title="Modificar fecha y sincronizar con Calendar">
                      ✏️ Cambiar Fecha
                    </button>
                    <button class="g" data-cal-renov="${o.id}" data-pid="${o.product_id}" data-uid="${o.customer_id}" data-nom="${esc(o.customers?.nombre || o.customers?.email || 'Cliente')}" data-tel="${esc(o.customers?.telefono || '')}" data-prod="${esc(o.products?.nombre || 'Servicio')}" style="padding:4px 8px;font-size:.73rem">
                      💳 Renovar Crédito
                    </button>
                  </td>
                </tr>
              `).join('')}
            </table>
          </div>
        `;
      }
      if (selEvents.mothers.length > 0) {
        detailHtml += `
          <h5 style="margin:8px 0 6px;color:#ffb703;display:flex;align-items:center;justify-content:space-between">
            <span>🔑 Cuentas Madre (${selEvents.mothers.length})</span>
            <span class="pill" style="font-size:.7rem;background:rgba(255,183,3,.12);color:#ffb703;border:1px solid rgba(255,183,3,.3)">Suscripción con Proveedor</span>
          </h5>
          <div class="wrap" style="margin-bottom:12px">
            <table>
              <tr><th>Plataforma</th><th>Correo Madre</th><th>Proveedor</th><th>Estado</th><th>Vence</th><th>Acciones</th></tr>
              ${selEvents.mothers.map(m => `
                <tr>
                  <td><b>${esc(m.plataforma)}</b></td>
                  <td><code>${esc(m.correo)}</code></td>
                  <td><b>${esc(m.proveedor || '— Sin asignar —')}</b></td>
                  <td><span class="pill ${m.activa ? '' : 'off'}">${m.activa ? 'Activa' : 'Inactiva'}</span></td>
                  <td><b style="color:#ffb703">${esc(m.vence)}</b></td>
                  <td class="row" style="gap:5px">
                    <button class="g" data-cal-notify-mother="${m.id}" style="padding:4px 8px;font-size:.73rem;background:rgba(37,211,102,.15);color:#25d366;border:1px solid rgba(37,211,102,.35);font-weight:700" title="Avisar credenciales actualizadas a clientes/revendedores por WhatsApp">
                      📢 Avisar Clientes
                    </button>
                    <button class="g" data-cal-renov-mother="${m.id}" data-cur-date="${m.vence}" data-plat="${esc(m.plataforma)}" data-mail="${esc(m.correo)}" data-prov="${esc(m.proveedor || '')}" data-cost="${m.costo_usd || 0}" style="padding:4px 8px;font-size:.73rem;background:rgba(16,185,129,.18);color:#10b981;border:1px solid rgba(16,185,129,.35);font-weight:700" title="Renovar ciclo de suscripción (+30 días desde la fecha agendada)">
                      🔄 Renovar (+30d)
                    </button>
                    <button class="g" data-cal-edit-mother="${m.id}" data-cur-date="${m.vence}" data-plat="${esc(m.plataforma)}" data-mail="${esc(m.correo)}" data-prov="${esc(m.proveedor || '')}" style="padding:4px 8px;font-size:.73rem" title="Modificar fecha o asignar proveedor">
                      ✏️ Fecha / Proveedor
                    </button>
                  </td>
                </tr>
              `).join('')}
            </table>
          </div>
        `;
      }
      if (selEvents.gcal && selEvents.gcal.length > 0) {
        detailHtml += `
          <h5 style="margin:14px 0 6px;color:#4285f4;display:flex;align-items:center;justify-content:space-between">
            <span>📅 Eventos en Google Calendar (${selEvents.gcal.length})</span>
            <span class="mut" style="font-size:.74rem">Sincronización en vivo</span>
          </h5>
          <div class="wrap" style="margin-bottom:12px">
            <table>
              <tr><th>Evento</th><th>Horario</th><th>Descripción / Notas</th><th>Estado</th><th>Acciones</th></tr>
              ${selEvents.gcal.map(g => `
                <tr>
                  <td><b>${esc(g.summary || '(Sin título)')}</b></td>
                  <td>${esc(g.start?.dateTime ? g.start.dateTime.slice(11, 16) + ' VET' : 'Todo el día')}</td>
                  <td style="max-width:240px;font-size:.76rem">${esc(g.description || '—')}</td>
                  <td>${g._isLinked ? `<span class="pill" style="font-size:.68rem;background:rgba(0,245,160,.12);color:#00f5a0;border:1px solid rgba(0,245,160,.3)">🔗 Pedido #${esc(String(g._order?.id || '').slice(0, 8))}</span>` : '<span class="pill" style="font-size:.68rem;background:rgba(66,133,244,.12);color:#8ab4f8;border:1px solid rgba(66,133,244,.3)">📅 Google Calendar</span>'}</td>
                  <td class="row" style="gap:5px">
                    ${g.htmlLink ? `<a href="${esc(g.htmlLink)}" target="_blank" rel="noopener noreferrer" class="cal-sheet-btn" style="text-decoration:none;padding:4px 8px;font-size:.72rem" title="Abrir en Google Calendar Web">🌐 Ver</a>` : ''}
                    <button class="g" data-gcal-edit="${esc(g.id)}" data-gcal-sum="${esc(g.summary || '')}" data-gcal-date="${esc(GCal.getEventDate(g) || '')}" style="padding:4px 8px;font-size:.72rem">✏️ Fecha</button>
                    <button class="d" data-gcal-del="${esc(g.id)}" style="padding:4px 8px;font-size:.72rem">🗑️</button>
                  </td>
                </tr>
              `).join('')}
            </table>
          </div>
        `;
      }
    }
    detailHtml += '</div>';

    // Ensamblar interfaz completa del calendario estilo Hoja de Cálculo
    box.innerHTML = `
      <div class="cal-sheet-container">
        <div class="cal-sheet-header">
          <div>
            <div class="cal-sheet-title">Control de Vencimientos - Administracion</div>
            <h2 class="cal-sheet-month">${monthNames[state.month]} de ${state.year}</h2>
          </div>
          <div class="cal-sheet-tools" style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
            <button class="cal-sheet-btn" id="calPrev" type="button">◀ Anterior</button>
            <button class="cal-sheet-btn" id="calToday" type="button">Hoy</button>
            <button class="cal-sheet-btn" id="calNext" type="button">Siguiente ▶</button>
            <span style="border-left:1px solid rgba(255,255,255,.15);height:20px;margin:0 4px"></span>
            <button class="cal-sheet-btn" id="calSendTelegram" type="button" style="background:rgba(0,136,204,.15);border-color:#0088cc;color:#38bdf8;font-weight:700" title="Enviar listado de vencimientos de hoy a Telegram">
              ✈️ Enviar a Telegram
            </button>
            ${calConnected ? `
              <button class="cal-sheet-btn" id="calSyncGCal" type="button" style="background:rgba(0,245,160,.12);border-color:#00f5a0;color:#00f5a0;font-weight:700" title="Sincronizar cambios en ambos sentidos con Google Calendar">
                🔄 Sincronizar Google Calendar
              </button>
              <button class="cal-sheet-btn" id="calOpenGCal" type="button" title="Ver Google Calendar Oficial">
                🌐 Ver Calendar
              </button>
            ` : `
              <button class="cal-sheet-btn" id="calAuthGCal" type="button" style="background:var(--grad);color:#03121c;font-weight:800">
                🔑 Conectar Google Calendar
              </button>
            `}
          </div>
        </div>

        <div class="cal-sheet-grid">
          ${weekHeaders}
          ${daysHtml.join('')}
        </div>

        <div class="cal-sheet-notes" style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px">
          <div>NOTAS / RESUMEN: Hoy vencen ${todayTotal} · Total mes: ${totalOrdersMonth} servicios clientes, ${totalMothersMonth} cuentas madre${calConnected ? ` y ${totalGcalMonth} eventos en Google Calendar.` : '.'}</div>
          <div style="font-size:.76rem;color:#8ea8c8">
            Google Calendar (<code>${GCal.CAL_ID}</code>): <b style="${calConnected ? 'color:#00f5a0' : 'color:#ffb703'}">${calConnected ? '🟢 Sincronización Bidireccional Activa' : '⚠️ Desconectado'}</b>
          </div>
        </div>
      </div>
      ${detailHtml}
    `;

    // Asignar eventos de navegación y selección
    $('#calPrev').onclick = () => {
      if (state.month === 0) { state.month = 11; state.year--; } else { state.month--; }
      EXTRA.vencimientos(box);
    };
    $('#calNext').onclick = () => {
      if (state.month === 11) { state.month = 0; state.year++; } else { state.month++; }
      EXTRA.vencimientos(box);
    };
    $('#calToday').onclick = () => {
      const n = new Date();
      state.year = n.getFullYear(); state.month = n.getMonth(); state.selectedDate = todayStr;
      EXTRA.vencimientos(box);
    };

    if ($('#calAuthGCal')) {
      $('#calAuthGCal').onclick = () => GCal.connect();
    }
    if ($('#calOpenGCal')) {
      $('#calOpenGCal').onclick = () => GCal.openEmbedView();
    }

    // Sincronización Bidireccional Manual
    if ($('#calSyncGCal')) {
      $('#calSyncGCal').onclick = e => run(e.target, async () => {
        if (!GCal.isConnected()) throw new Error('Conecta Google Calendar primero.');

        // 1. Obtener eventos de Google Calendar del mes
        const gEvents = await GCal.listMonthEvents(state.year, state.month + 1);
        const gMap = new Map();
        for (const ev of gEvents) {
          gMap.set(ev.id, ev);
        }

        // 2. Traer todos los pedidos del mes y los vinculados a Google Calendar
        const [{ data: curOrders, error: curErr }, { data: linkedOrders }] = await Promise.all([
          sb.from('orders')
            .select('id,customer_id,product_id,profile_id,inicia,vence,gcal_event_id,estado,customers!customer_id(nombre,email,telefono),products(nombre)')
            .not('vence', 'is', null)
            .gte('vence', startMonth)
            .lte('vence', endMonth),
          sb.from('orders')
            .select('id,customer_id,product_id,profile_id,inicia,vence,gcal_event_id,estado,customers!customer_id(nombre,email,telefono),products(nombre)')
            .not('gcal_event_id', 'is', null)
        ]);
        if (curErr) throw curErr;

        const ordersMap = new Map();
        (curOrders || []).forEach(o => ordersMap.set(o.id, o));
        (linkedOrders || []).forEach(o => ordersMap.set(o.id, o));
        const allOrders = Array.from(ordersMap.values());

        let updatedFromCalendar = 0;
        let pushedToCalendar = 0;
        let linkedFromCalendar = 0;
        let totalGoogleEvents = gEvents.length;

        // A) Calendar -> Plataforma: Smart Matching y Actualización de fechas
        for (const ev of gEvents) {
          const evDate = GCal.getEventDate(ev);
          let matchedOrd = allOrders.find(o => o.gcal_event_id === ev.id);

          // Si no está vinculado por ID, buscar si el evento menciona el ID de pedido (#uuid o #8chars)
          if (!matchedOrd) {
            const txt = `${ev.summary || ''} ${ev.description || ''}`;
            matchedOrd = allOrders.find(o => {
              if (o.gcal_event_id) return false;
              return txt.includes(o.id) || txt.includes(o.id.slice(0, 8));
            });
            if (matchedOrd) {
              await sb.from('orders').update({ gcal_event_id: ev.id }).eq('id', matchedOrd.id);
              matchedOrd.gcal_event_id = ev.id;
              linkedFromCalendar++;
            }
          }

          // Si el evento está enlazado a un pedido y su fecha cambió en Google Calendar, actualizar pedido en Supabase
          if (matchedOrd && evDate && evDate !== matchedOrd.vence) {
            await sb.from('orders').update({ vence: evDate, proximo_pago: evDate }).eq('id', matchedOrd.id);
            if (matchedOrd.profile_id) {
              try { await sb.from('profiles_inventory').update({ vence: evDate }).eq('id', matchedOrd.profile_id); } catch(e){}
            }
            matchedOrd.vence = evDate;
            updatedFromCalendar++;
          }
        }

        // B) Plataforma -> Calendar: Si hay pedidos activos/entregados sin evento en Calendar, crearlos
        for (const ord of (curOrders || [])) {
          if (['pagado', 'entregado'].includes(ord.estado)) {
            const prodName = ord.products?.nombre || 'Servicio';
            const custName = ord.customers?.nombre || ord.customers?.email || 'Cliente';
            const evSummary = `Vence: ${prodName} · ${custName}`;
            const evDesc = `Pedido #${ord.id}\nCliente: ${custName}\nTeléfono: ${ord.customers?.telefono || 'N/A'}\nServicio: ${prodName}\nFecha Vencimiento: ${ord.vence}`;

            if (!ord.gcal_event_id) {
              const newEv = await GCal.createEvent({
                summary: evSummary,
                description: evDesc,
                date: ord.vence
              });
              if (newEv?.id) {
                await sb.from('orders').update({ gcal_event_id: newEv.id }).eq('id', ord.id);
                ord.gcal_event_id = newEv.id;
                pushedToCalendar++;
              }
            } else if (!gMap.has(ord.gcal_event_id)) {
              // Si el evento fue eliminado en Google Calendar, recrearlo
              const newEv = await GCal.createEvent({
                summary: evSummary,
                description: evDesc,
                date: ord.vence
              });
              if (newEv?.id) {
                await sb.from('orders').update({ gcal_event_id: newEv.id }).eq('id', ord.id);
                ord.gcal_event_id = newEv.id;
                pushedToCalendar++;
              }
            }
          }
        }

        EXTRA.vencimientos(box);
        let msg = `📅 Sincronización con Google Calendar completa:`;
        msg += `\n• Eventos en Google Calendar: ${totalGoogleEvents}`;
        if (pushedToCalendar > 0) msg += `\n• Pedidos subidos a Google Calendar: ${pushedToCalendar}`;
        if (updatedFromCalendar > 0) msg += `\n• Fechas actualizadas desde Calendar: ${updatedFromCalendar}`;
        if (linkedFromCalendar > 0) msg += `\n• Pedidos vinculados automáticamente: ${linkedFromCalendar}`;
        if (pushedToCalendar === 0 && updatedFromCalendar === 0 && linkedFromCalendar === 0) {
          msg += `\n• Todos los vencimientos y eventos están al día.`;
        }
        return msg;
      });
    }

    // Acciones sobre eventos propios de Google Calendar en el detalle
    box.querySelectorAll('[data-gcal-edit]').forEach(btn => {
      btn.onclick = () => {
        const evId = btn.dataset.gcalEdit;
        const curSum = btn.dataset.gcalSum;
        const curDate = btn.dataset.gcalDate;

        $('#dlgBody').innerHTML = `
          <h3>📅 Modificar Evento en Google Calendar</h3>
          <p class="mut" style="font-size:.82rem;margin:0 0 12px">Evento: <b>${esc(curSum)}</b></p>
          <div style="display:flex;flex-direction:column;gap:12px">
            <label class="mut" style="font-size:.76rem">Nuevo Título / Resumen:</label>
            <input type="text" id="dlgGcalNewSum" value="${esc(curSum)}" style="font-size:1rem;padding:8px 12px">
            <label class="mut" style="font-size:.76rem">Nueva Fecha:</label>
            <input type="date" id="dlgGcalNewDate" value="${curDate}" required style="font-size:1rem;padding:8px 12px">
          </div>
          <div style="display:flex;gap:10px;justify-content:flex-end;margin-top:16px">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="dlgSaveGcalEvent">💾 Guardar en Google Calendar</button>
          </div>
        `;
        dlg.showModal();

        $('#dlgSaveGcalEvent').onclick = async () => {
          const newSum = $('#dlgGcalNewSum').value.trim();
          const newDate = $('#dlgGcalNewDate').value;
          if (!newDate) return toast('Ingresa una fecha válida.');
          dlg.close();

          try {
            await GCal.updateEvent(evId, { summary: newSum || curSum, date: newDate });
            // Si estaba enlazado a un pedido, actualizarlo en Supabase
            await sb.from('orders').update({ vence: newDate, proximo_pago: newDate }).eq('gcal_event_id', evId);
            toast('✅ Evento actualizado en Google Calendar.');
            EXTRA.vencimientos(box);
          } catch(err) {
            toast('Error al actualizar evento: ' + err.message);
          }
        };
      };
    });

    box.querySelectorAll('[data-gcal-del]').forEach(btn => {
      btn.onclick = async () => {
        if (!confirm('¿Eliminar este evento de tu Google Calendar?')) return;
        const evId = btn.dataset.gcalDel;
        try {
          await GCal.deleteEvent(evId);
          // Desenlazar en orders si estaba asociado
          try { await sb.from('orders').update({ gcal_event_id: null }).eq('gcal_event_id', evId); } catch(e){}
          toast('🗑️ Evento eliminado de Google Calendar.');
          EXTRA.vencimientos(box);
        } catch(err) {
          toast('Error al eliminar evento: ' + err.message);
        }
      };
    });

    box.querySelectorAll('[data-day]').forEach(cell => {
      cell.onclick = () => {
        state.selectedDate = cell.dataset.day;
        EXTRA.vencimientos(box);
      };
    });

    // Acción: Modificar Fecha de Vencimiento individual y reflejar de inmediato en Google Calendar
    box.querySelectorAll('[data-cal-edit-date]').forEach(btn => {
      btn.onclick = () => {
        const orderId = btn.dataset.calEditDate;
        const curDate = btn.dataset.curDate;
        const prodNom = btn.dataset.prod;
        const custNom = btn.dataset.nom;
        const gcalId = btn.dataset.gcalId;

        $('#dlgBody').innerHTML = `
          <h3>📅 Modificar Fecha de Vencimiento</h3>
          <p class="mut" style="font-size:.82rem;margin:0 0 12px">Pedido: <b>#${orderId.slice(0, 8)}</b> · ${esc(prodNom)} (${esc(custNom)})</p>
          <div style="display:flex;flex-direction:column;gap:12px">
            <label class="mut" style="font-size:.76rem">Nueva Fecha de Vencimiento:</label>
            <input type="date" id="dlgNewVenceDate" value="${curDate}" required style="font-size:1rem;padding:8px 12px">
            <div style="font-size:.74rem;color:#8ea8c8;background:rgba(255,255,255,.04);border-radius:8px;padding:8px 10px">
              ℹ️ Al guardar, se actualizará el pedido en la tienda y se modificará o creará de inmediato el evento en tu <b>Google Calendar</b> (<code>${GCal.CAL_ID}</code>).
            </div>
          </div>
          <div style="display:flex;gap:10px;justify-content:flex-end;margin-top:16px">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="dlgSaveVenceDate">💾 Guardar y Sincronizar</button>
          </div>
        `;
        dlg.showModal();

        $('#dlgSaveVenceDate').onclick = async () => {
          const newDate = $('#dlgNewVenceDate').value;
          if (!newDate) return toast('Ingresa una fecha válida.');
          dlg.close();

          try {
            // 1. Supabase update
            const { data: oRow, error: oErr } = await sb.from('orders').update({
              vence: newDate,
              proximo_pago: newDate
            }).eq('id', orderId).select('profile_id,gcal_event_id').single();
            if (oErr) throw oErr;

            if (oRow?.profile_id) {
              try { await sb.from('profiles_inventory').update({ vence: newDate }).eq('id', oRow.profile_id); } catch(e){}
            }

            // 2. Google Calendar sync si está conectado
            if (GCal.isConnected()) {
              const evSummary = `Vence: ${prodNom} · ${custNom}`;
              const evDesc = `Pedido #${orderId}
Cliente: ${custNom}
Servicio: ${prodNom}
Fecha Vencimiento: ${newDate}`;
              const eventId = oRow?.gcal_event_id || gcalId;

              if (eventId) {
                try {
                  await GCal.updateEvent(eventId, { summary: evSummary, description: evDesc, date: newDate });
                } catch(patchErr) {
                  const newEv = await GCal.createEvent({ summary: evSummary, description: evDesc, date: newDate });
                  if (newEv?.id) {
                    await sb.from('orders').update({ gcal_event_id: newEv.id }).eq('id', orderId);
                  }
                }
              } else {
                const newEv = await GCal.createEvent({ summary: evSummary, description: evDesc, date: newDate });
                if (newEv?.id) {
                  await sb.from('orders').update({ gcal_event_id: newEv.id }).eq('id', orderId);
                }
              }
              toast(`✅ Vencimiento cambiado a ${newDate} y sincronizado con Google Calendar.`);
            } else {
              toast(`✅ Vencimiento cambiado a ${newDate} en la plataforma (Google Calendar no conectado).`);
            }

            EXTRA.vencimientos(box);
          } catch(err) {
            toast('Error al actualizar fecha: ' + err.message);
          }
        };
      };
    });

    // Acción: Modificar Fecha de Vencimiento de Perfil de Inventario
    box.querySelectorAll('[data-cal-edit-prof-date]').forEach(btn => {
      btn.onclick = () => {
        const profId = btn.dataset.calEditProfDate;
        const curDate = btn.dataset.curDate;
        const custNom = btn.dataset.nom;
        const srvNom = btn.dataset.srv;

        $('#dlgBody').innerHTML = `
          <h3>📅 Modificar Vencimiento de Perfil</h3>
          <p class="mut" style="font-size:.82rem;margin:0 0 12px">Cliente/Perfil: <b>${esc(custNom)}</b> · Servicio: <b>${esc(srvNom)}</b></p>
          <div style="display:flex;flex-direction:column;gap:12px">
            <label class="mut" style="font-size:.76rem">Nueva Fecha de Vencimiento:</label>
            <input type="date" id="dlgNewProfDate" value="${curDate}" required style="font-size:1rem;padding:8px 12px">
          </div>
          <div style="display:flex;gap:10px;justify-content:flex-end;margin-top:16px">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnSaveProfDate" style="background:var(--grad);color:#03121c;font-weight:800">💾 Guardar Fecha</button>
          </div>
        `;
        dlg.showModal();

        $('#btnSaveProfDate').onclick = async () => {
          const newDate = $('#dlgNewProfDate').value;
          if (!newDate) return toast('Ingresa una fecha válida.');
          try {
            const { error } = await sb.from('profiles_inventory').update({ vence: newDate }).eq('id', profId);
            if (error) throw error;
            dlg.close();
            toast('✅ Vencimiento de perfil actualizado correctamente.');
            EXTRA.vencimientos(box);
          } catch(err) {
            toast('Error al actualizar fecha: ' + err.message);
          }
        };
      };
    });

    // Acción: Renovar Suscripción de Perfil sumando 30 días exactos desde la fecha agendada
    box.querySelectorAll('[data-cal-renov-prof], [data-cal-renov-30d-prof]').forEach(btn => {
      btn.onclick = async () => {
        const profId = btn.getAttribute('data-cal-renov-prof') || btn.getAttribute('data-cal-renov-30d-prof') || btn.dataset.calRenovProf;
        const curDate = btn.dataset.curDate;
        const custNom = btn.dataset.nom;
        const srvNom = btn.dataset.srv;

        if (!profId || profId === 'undefined') return toast('Error: No se encontró el ID del perfil a renovar.');
        if (!curDate) return toast('El perfil no tiene una fecha agendada válida.');

        // Calcular +30 días exactos desde la fecha agendada
        const [y, m, d] = curDate.split('-').map(Number);
        const dt = new Date(Date.UTC(y, m - 1, d));
        dt.setUTCDate(dt.getUTCDate() + 30);
        const nextDateStr = dt.toISOString().slice(0, 10);

        const ok = confirm(
          `🔄 RENOVAR CICLO DE SUSCRIPCIÓN (+30 DÍAS)\n\n` +
          `• Cliente / Perfil: ${custNom}\n` +
          `• Servicio: ${srvNom}\n` +
          `• Vencimiento agendado: ${curDate}\n` +
          `• Nuevo vencimiento (+30 días): ${nextDateStr}\n\n` +
          `¿Confirmas la renovación del servicio a partir de la fecha agendada?`
        );
        if (!ok) return;

        btn.disabled = true;
        btn.textContent = '⏳...';

        try {
          // 1. Actualizar profiles_inventory (extendiendo fecha y reseteando no_renueva)
          const { error: pErr } = await sb.from('profiles_inventory').update({
            vence: nextDateStr,
            estado: 'vendido',
            no_renueva: false
          }).eq('id', profId);
          if (pErr) throw pErr;

          // 2. Sincronizar en orders vinculadas a este profile_id
          try {
            await sb.from('orders').update({
              vence: nextDateStr,
              proximo_pago: nextDateStr
            }).eq('profile_id', profId);
          } catch(e) {}

          toast(`✅ Renovación exitosa. "${custNom}" extendido hasta el ${nextDateStr} (+30 días).`);
          EXTRA.vencimientos(box);
        } catch(err) {
          toast('Error al renovar: ' + err.message);
          btn.disabled = false;
          btn.textContent = '🔄 Renovar (+30d)';
        }
      };
    });

    // Acción: Renovar Orden Web sumando 30 días exactos desde la fecha agendada
    box.querySelectorAll('[data-cal-renov-order], [data-cal-renov-30d-order]').forEach(btn => {
      btn.onclick = async () => {
        const orderId = btn.getAttribute('data-cal-renov-order') || btn.getAttribute('data-cal-renov-30d-order') || btn.dataset.calRenovOrder;
        const curDate = btn.dataset.curDate;
        const custNom = btn.dataset.nom;
        const prodNom = btn.dataset.prod;
        const gcalId = btn.dataset.gcalId;

        if (!orderId || orderId === 'undefined') return toast('Error: No se encontró el ID de la orden a renovar.');
        if (!curDate) return toast('La orden no tiene una fecha agendada válida.');

        const [y, m, d] = curDate.split('-').map(Number);
        const dt = new Date(Date.UTC(y, m - 1, d));
        dt.setUTCDate(dt.getUTCDate() + 30);
        const nextDateStr = dt.toISOString().slice(0, 10);

        const ok = confirm(
          `🔄 RENOVAR CICLO DE SUSCRIPCIÓN (+30 DÍAS)\n\n` +
          `• Cliente: ${custNom}\n` +
          `• Servicio: ${prodNom}\n` +
          `• Vencimiento agendado: ${curDate}\n` +
          `• Nuevo vencimiento (+30 días): ${nextDateStr}\n\n` +
          `¿Confirmas la renovación del servicio a partir de la fecha agendada?`
        );
        if (!ok) return;

        btn.disabled = true;
        btn.textContent = '⏳...';

        try {
          const { data: oRow, error: oErr } = await sb.from('orders').update({
            vence: nextDateStr,
            proximo_pago: nextDateStr
          }).eq('id', orderId).select('profile_id').single();
          if (oErr) throw oErr;

          if (oRow?.profile_id) {
            try {
              await sb.from('profiles_inventory').update({ vence: nextDateStr, estado: 'vendido', no_renueva: false }).eq('id', oRow.profile_id);
            } catch(e) {}
          }

          if (gcalId && typeof GCal !== 'undefined' && GCal.isAuthenticated && GCal.isAuthenticated()) {
            try {
              await GCal.updateEvent(gcalId, { date: nextDateStr, summary: `Vence: ${prodNom} · ${custNom}` });
            } catch(e) {}
          }

          toast(`✅ Renovación exitosa. "${custNom}" extendido hasta el ${nextDateStr} (+30 días).`);
          EXTRA.vencimientos(box);
        } catch(err) {
          toast('Error al renovar: ' + err.message);
          btn.disabled = false;
          btn.textContent = '🔄 Renovar (+30d)';
        }
      };
    });

    // Acción: Renovar a Crédito y sincronizar con Google Calendar
    box.querySelectorAll('[data-cal-renov]').forEach(btn => {
      btn.onclick = () => run(btn, async () => {
        const nom = btn.dataset.nom, prod = btn.dataset.prod, tel = (btn.dataset.tel||'').replace(/\D/g,'');
        const dias = prompt(`¿A cuántos días de crédito renuevas a ${nom}?`, '7');
        if(!dias || isNaN(dias)) return 'Renovación cancelada.';
        const fVenceCred = new Date(Date.now() + Number(dias) * 86400000).toISOString().slice(0, 10);
        
        // Renueva la orden existente sumando 30 dias a su vencimiento
        const { data: oData, error: oErr } = await sb.from('orders').select('*').eq('id', btn.dataset.calRenov).single();
        if(oErr) throw oErr;
        const curVence = oData.vence ? new Date(oData.vence) : new Date();
        const nextVence = new Date(curVence.getTime() + 30 * 86400000).toISOString().slice(0, 10);
        
        await sb.from('orders').update({
          vence: nextVence,
          proximo_pago: nextVence,
          referencia: `[RENOVACIÓN CRÉDITO] Cobrar antes de ${fVenceCred} ($${oData.total_usd} USD)`
        }).eq('id', btn.dataset.calRenov);

        if(oData.profile_id){
          try { await sb.from('profiles_inventory').update({ vence: nextVence }).eq('id', oData.profile_id); } catch(e){}
        }

        // Sincronizar de inmediato con Google Calendar si está conectado
        if (GCal.isConnected()) {
          const evSummary = `Vence: ${prod} · ${nom}`;
          const evDesc = `[RENOVACIÓN CRÉDITO] Pedido #${btn.dataset.calRenov}
Cliente: ${nom}
Teléfono: ${tel}
Servicio: ${prod}
Cobrar antes de ${fVenceCred}`;
          if (oData.gcal_event_id) {
            await GCal.updateEvent(oData.gcal_event_id, { summary: evSummary, description: evDesc, date: nextVence }).catch(async () => {
              const newEv = await GCal.createEvent({ summary: evSummary, description: evDesc, date: nextVence }).catch(() => null);
              if (newEv?.id) await sb.from('orders').update({ gcal_event_id: newEv.id }).eq('id', btn.dataset.calRenov);
            });
          } else {
            const newEv = await GCal.createEvent({ summary: evSummary, description: evDesc, date: nextVence }).catch(() => null);
            if (newEv?.id) {
              await sb.from('orders').update({ gcal_event_id: newEv.id }).eq('id', btn.dataset.calRenov);
            }
          }
        }

        if(tel){
          const rawMsg = formatMessageTemplate('entrega_credito', {
            cliente: nom,
            producto: prod,
            monto_usd: oData.total_usd,
            fecha_vence_credito: fVenceCred,
            dias_credito: dias
          });
          openWhatsApp(tel, rawMsg);
        }

        EXTRA.vencimientos(box);
        return `Suscripción de ${nom} renovada +30 días a crédito (Cobrar antes de ${fVenceCred}).`;
      });
    });

    // Enviar listado de vencimientos del día a Telegram
    if ($('#calSendTelegram')) {
      $('#calSendTelegram').onclick = async e => {
        const btn = e.target;
        btn.disabled = true;
        const oldText = btn.textContent;
        btn.textContent = '⏳ Enviando...';
        try {
          const res = await fetch(`/api/vencimientos?fecha=${state.selectedDate || todayStr}`);
          const data = await res.json();
          if (data.ok) {
            toast(`✅ Vencimientos enviados a Telegram (${data.itemsCount || 0} registros).`);
          } else {
            toast('⚠️ Aviso: ' + (data.error || 'No se pudo enviar'));
          }
        } catch (err) {
          toast('Error enviando a Telegram: ' + err.message);
        } finally {
          btn.disabled = false;
          btn.textContent = oldText;
        }
      };
    }

    // Liberar perfil para la venta directamente desde la lista de vencimientos
    box.querySelectorAll('[data-cal-release-prof]').forEach(btn => {
      btn.onclick = () => {
        const profId = btn.dataset.calReleaseProf;
        const nom = btn.dataset.nom || 'Perfil';
        const srv = btn.dataset.srv || 'Servicio';
        const curPin = btn.dataset.curPin || '';
        const mail = btn.dataset.mail || '';

        const isEncPin = typeof curPin === 'string' && curPin.startsWith('enc:');
        const pinInitial = isEncPin ? '' : curPin;
        const pinDisplay = isEncPin ? '🔒 Protegido / Cifrado (Asignar uno nuevo)' : (curPin ? esc(curPin) : 'Sin PIN');

        $('#dlgBody').innerHTML = `
          <h3>🔓 Liberar Perfil para la Venta</h3>
          <p class="mut" style="font-size:.85rem;margin:0 0 12px">
            El cliente no renovará o el perfil venció. ¿Deseas liberar el perfil <b>${esc(nom)}</b> (${esc(srv)}) para ponerlo inmediatamente a la venta en la tienda?
          </p>
          <div style="background:rgba(255,255,255,.04);border:1.5px solid rgba(0,245,160,.3);border-radius:12px;padding:12px;margin-bottom:14px;font-size:.82rem">
            <div>📧 Cuenta Madre: <b>${esc(mail || '—')}</b></div>
            <div style="margin-top:4px">🔒 PIN actual en sistema: <code style="color:#00f5a0">${pinDisplay}</code></div>
            <div class="mut" style="font-size:.74rem;margin-top:8px;line-height:1.4">
              ⚠️ <b>Paso Importante:</b> Recuerda cambiar el PIN en la app de streaming (${esc(srv)}) para que el cliente que venció ya no pueda usarlo.
            </div>
          </div>
          <label class="mut" style="font-size:.78rem;display:block;margin-bottom:4px;font-weight:700">1. Nombre del Perfil en Inventario (Catálogo):</label>
          <input id="inputReleaseCalNewNom" value="${esc(nom)}" placeholder="Ej: Perfil 1" style="width:100%;margin-bottom:12px">
          <label class="mut" style="font-size:.78rem;display:block;margin-bottom:4px;font-weight:700">2. Nuevo PIN para la Pantalla (4 dígitos):</label>
          <input id="inputReleaseCalNewPin" value="${esc(pinInitial)}" placeholder="Ej: 0102" style="width:100%;margin-bottom:14px">
          <div style="display:flex;gap:10px;justify-content:flex-end">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnConfirmReleaseCalProfile" style="background:var(--grad);color:#03121c;font-weight:800">
              🔓 Liberar y Poner en Venta
            </button>
          </div>
        `;
        dlg.showModal();

        $('#btnConfirmReleaseCalProfile').onclick = async () => {
          const cBtn = $('#btnConfirmReleaseCalProfile');
          cBtn.disabled = true;
          cBtn.textContent = '⏳ Liberando...';
          let newPin = $('#inputReleaseCalNewPin').value.trim();
          let newNom = $('#inputReleaseCalNewNom').value.trim();

          // Detección y auto-corrección si se invirtieron los campos accidentalmente
          if (/[a-zA-Z]/.test(newPin) && /^\d{2,6}$/.test(newNom)) {
            const temp = newPin;
            newPin = newNom;
            newNom = temp;
          }
          if (newPin.startsWith('enc:')) {
            newPin = '';
          }

          try {
            let rpcOk = false;
            try {
              const rpcP = sb.rpc('liberar_perfil_inventario', {
                p_profile_id: profId,
                p_nuevo_pin: newPin || null,
                p_nuevo_nombre: newNom || null
              });
              const toP = new Promise((_, reject) => setTimeout(() => reject(new Error('TIMEOUT')), 4000));
              const res = await Promise.race([rpcP, toP]);
              if (!res?.error) rpcOk = true;
            } catch(eRpc) {
              console.warn('RPC liberar_perfil_inventario tardío o no disponible, usando fallback directo:', eRpc);
            }

            if (!rpcOk) {
              const updData = {
                estado: 'disponible',
                inicia: null,
                vence: null,
                assigned_customer_id: null,
                no_renueva: false,
                no_renueva_reportado_at: null,
                no_renueva_motivo: null,
                no_renueva_por: null
              };
              if (newPin) updData.pin = newPin;
              if (newNom) updData.nombre_perfil = newNom;

              const { error: updErr } = await sb.from('profiles_inventory')
                .update(updData)
                .eq('id', profId);
              if (updErr) throw updErr;

              try {
                await sb.from('orders')
                  .update({ estado: 'vencido', no_renueva: false })
                  .eq('profile_id', profId)
                  .in('estado', ['entregado', 'pagado']);
              } catch(eOrd) {
                console.warn('Orders cleanup warning:', eOrd);
              }
            }

            dlg.close();
            toast(`✅ Perfil "${newNom || nom}" liberado con éxito. Ya está disponible en la tienda.`);
            setTimeout(() => {
              try {
                if (typeof EXTRA !== 'undefined' && EXTRA.vencimientos) {
                  EXTRA.vencimientos(box);
                }
              } catch(eRef) {
                console.warn('Error refrescando vista de vencimientos:', eRef);
              }
            }, 150);
          } catch(err){
            cBtn.disabled = false;
            cBtn.textContent = '🔓 Liberar y Poner en Venta';
            alert('Error al liberar perfil: ' + (err.message || err));
          }
        };
      };
    });

    // Reponer / trasladar perfil directamente desde el calendario
    box.querySelectorAll('[data-cal-tr-prof]').forEach(btn => {
      btn.onclick = () => {
        const profId = btn.dataset.calTrProf;
        openTransferModal({
          profileId: profId,
          done: () => EXTRA.vencimientos(box)
        });
      };
    });

    // Acción: Avisar Actualización de Credenciales a Clientes y Revendedores de Cuenta Madre
    box.querySelectorAll('[data-cal-notify-mother]').forEach(btn => {
      btn.onclick = () => notifyMotherClients(btn.dataset.calNotifyMother);
    });

    // Acción: Renovar Suscripción de Cuenta Madre (+30 días desde la fecha agendada)
    box.querySelectorAll('[data-cal-renov-mother]').forEach(btn => {
      btn.onclick = () => {
        const motherId = btn.dataset.calRenovMother;
        const curDate = btn.dataset.curDate;
        const plat = btn.dataset.plat;
        const mail = btn.dataset.mail;
        const curProv = btn.dataset.prov || '';
        const curCost = btn.dataset.cost || '0';

        if (!curDate) return toast('La cuenta madre no tiene una fecha agendada.');

        const [y, m, d] = curDate.split('-').map(Number);
        const dt = new Date(Date.UTC(y, m - 1, d));
        dt.setUTCDate(dt.getUTCDate() + 30);
        const nextDateStr = dt.toISOString().slice(0, 10);

        $('#dlgBody').innerHTML = `
          <h3>🔄 Renovar Cuenta Madre (+30 Días)</h3>
          <p class="mut" style="font-size:.85rem;margin:0 0 14px">
            Renovación de ciclo de suscripción con tu proveedor para la cuenta madre.
          </p>
          <div style="background:rgba(255,255,255,.04);padding:14px;border-radius:12px;border:1px solid rgba(255,255,255,.1);margin-bottom:14px">
            <div style="display:flex;justify-content:space-between;margin-bottom:8px">
              <span class="mut" style="font-size:.82rem">Plataforma:</span>
              <b style="color:var(--c)">${esc(plat)}</b>
            </div>
            <div style="display:flex;justify-content:space-between;margin-bottom:8px">
              <span class="mut" style="font-size:.82rem">Correo Cuenta:</span>
              <code>${esc(mail)}</code>
            </div>
            <div style="display:flex;justify-content:space-between;margin-bottom:12px">
              <span class="mut" style="font-size:.82rem">Ciclo de Vencimiento:</span>
              <span><b style="color:#f59e0b">${esc(curDate)}</b> ➔ <b style="color:#00f5a0">${nextDateStr}</b></span>
            </div>
            <label class="mut" style="font-size:.78rem;display:block;margin-bottom:4px">Proveedor Asignado:</label>
            <input id="renovMotherProv" list="list_proveedores_sugeridos" value="${esc(curProv)}" placeholder="Ej: ALEXANDER OJEDA, MOVIAX, ALEGG..." style="width:100%;margin-bottom:10px">
            <datalist id="list_proveedores_sugeridos">
              <option value="ALEXANDER OJEDA">
              <option value="MOVIAX">
              <option value="ALEGG">
            </datalist>

            <label style="display:flex;align-items:center;gap:8px;font-size:.85rem;cursor:pointer;margin-top:8px">
              <input type="checkbox" id="checkCreatePurchaseRecord" checked>
              <span>Registrar costo de renovación en 🛍️ Compras</span>
            </label>
            <div id="boxPurchaseCost" style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:8px">
              <div>
                <span class="mut" style="font-size:.74rem">Costo Renovación ($ USD):</span>
                <input id="renovMotherCost" type="number" step="0.01" min="0" value="${curCost}" style="width:100%">
              </div>
              <div>
                <span class="mut" style="font-size:.74rem">Condición de Pago:</span>
                <select id="renovMotherCredito" style="width:100%">
                  <option value="contado">💵 Contado</option>
                  <option value="credito">💳 A Crédito</option>
                </select>
              </div>
            </div>
          </div>
          <div style="display:flex;gap:10px;justify-content:flex-end">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnConfirmRenovMother" style="background:#10b981;color:#fff;font-weight:700">💾 Confirmar Renovación (+30d)</button>
          </div>
        `;
        dlg.showModal();

        $('#checkCreatePurchaseRecord').onchange = (e) => {
          $('#boxPurchaseCost').style.display = e.target.checked ? 'grid' : 'none';
        };

        $('#btnConfirmRenovMother').onclick = async () => {
          const btnSave = $('#btnConfirmRenovMother');
          btnSave.disabled = true;
          btnSave.textContent = '⏳ Guardando...';

          const provVal = ($('#renovMotherProv').value || '').trim();
          const shouldPurchase = $('#checkCreatePurchaseRecord').checked;
          const costVal = parseFloat($('#renovMotherCost').value) || 0;
          const isCred = $('#renovMotherCredito').value === 'credito';

          try {
            const upObj = { vence: nextDateStr };
            if (provVal) upObj.proveedor = provVal;
            if (costVal > 0) upObj.costo_usd = costVal;
            const { error: mErr } = await sb.from('mother_accounts').update(upObj).eq('id', motherId);
            if (mErr) throw mErr;

            if (shouldPurchase && costVal > 0) {
              const { error: pErr } = await sb.from('purchases').insert({
                fecha: new Date().toISOString().slice(0, 10),
                proveedor: provVal || 'Proveedor',
                plataforma: plat,
                mother_id: motherId,
                monto_usd: costVal,
                monto_usdt: costVal,
                es_credito: isCred,
                estado_pago: isCred ? 'pendiente' : 'pagado',
                notas: `Renovación cuenta madre (+30d hasta ${nextDateStr})`
              });
              if (pErr) console.warn('Error insert purchase:', pErr);
            }

            toast(`✅ Cuenta madre ${plat} renovada hasta ${nextDateStr}.`);
            dlg.close();
            EXTRA.vencimientos(box);
          } catch(err) {
            toast('Error al renovar cuenta madre: ' + err.message);
            btnSave.disabled = false;
            btnSave.textContent = '💾 Confirmar Renovación (+30d)';
          }
        };
      };
    });

    // Acción: Modificar Fecha o Proveedor de Cuenta Madre
    box.querySelectorAll('[data-cal-edit-mother]').forEach(btn => {
      btn.onclick = () => {
        const motherId = btn.dataset.calEditMother;
        const curDate = btn.dataset.curDate || '';
        const plat = btn.dataset.plat;
        const mail = btn.dataset.mail;
        const curProv = btn.dataset.prov || '';

        $('#dlgBody').innerHTML = `
          <h3>✏️ Editar Cuenta Madre</h3>
          <p class="mut" style="font-size:.85rem;margin:0 0 14px">
            Ajusta la fecha de vencimiento o asigna el proveedor para <b>${esc(plat)}</b> (<code>${esc(mail)}</code>).
          </p>
          <div style="background:rgba(255,255,255,.04);padding:14px;border-radius:12px;border:1px solid rgba(255,255,255,.1);margin-bottom:14px">
            <label class="mut" style="font-size:.78rem;display:block;margin-bottom:4px">Fecha de Vencimiento:</label>
            <input id="editMotherDate" type="date" value="${curDate}" style="width:100%;margin-bottom:10px">

            <label class="mut" style="font-size:.78rem;display:block;margin-bottom:4px">Proveedor Asignado:</label>
            <input id="editMotherProv" list="list_proveedores_sugeridos" value="${esc(curProv)}" placeholder="Ej: ALEXANDER OJEDA, MOVIAX, ALEGG..." style="width:100%">
            <datalist id="list_proveedores_sugeridos">
              <option value="ALEXANDER OJEDA">
              <option value="MOVIAX">
              <option value="ALEGG">
            </datalist>
          </div>
          <div style="display:flex;gap:10px;justify-content:flex-end">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnSaveEditMother">💾 Guardar Cambios</button>
          </div>
        `;
        dlg.showModal();

        $('#btnSaveEditMother').onclick = async () => {
          const btn = $('#btnSaveEditMother');
          btn.disabled = true;
          btn.textContent = '⏳ Guardando...';

          const newDate = $('#editMotherDate').value || null;
          const newProv = ($('#editMotherProv').value || '').trim() || null;

          try {
            const { error: err } = await sb.from('mother_accounts').update({
              vence: newDate,
              proveedor: newProv
            }).eq('id', motherId);
            if (err) throw err;

            toast('✅ Cuenta madre actualizada.');
            dlg.close();
            EXTRA.vencimientos(box);
          } catch(e) {
            toast('Error: ' + e.message);
            btn.disabled = false;
            btn.textContent = '💾 Guardar Cambios';
          }
        };
      };
    });
  },
  async finanzas(box) {
    if (!box) return;
    let data = [], error = null, mcOpsRes = { data: [] }, mcCfgRow = { data: null }, instRes = { data: [] };
    try {
      const res = await Promise.all([
        sb.rpc('finanzas', { p_meses: 12 }),
        sb.from('mesa_cambio_operaciones').select('*').eq('estado', 'completado_enviado'),
        sb.from('settings').select('value').eq('key', 'mesa_cambio_config').maybeSingle(),
        sb.from('installments').select('monto_usd, estado, pagada_at, fecha_vencimiento, created_at')
      ]);
      data = res[0]?.data || [];
      error = res[0]?.error || null;
      mcOpsRes = res[1] || { data: [] };
      mcCfgRow = res[2] || { data: null };
      instRes = res[3] || { data: [] };
    } catch(errFin) {
      console.warn('Error cargando finanzas:', errFin);
      if (box && box.isConnected) box.innerHTML = '<p>Error al cargar finanzas: ' + esc(errFin.message) + '</p>';
      return;
    }

    // Si el contenedor se desconectó del DOM durante el fetch de red, reasociar al contenedor activo
    if (!box.isConnected) {
      const activeBox = document.querySelector('#ex');
      if (activeBox) box = activeBox;
      else return; // El usuario navegó a otra vista o cerró el módulo
    }

    if (error) {
      box.innerHTML = '<p>' + esc(error.message) + '</p>';
      return;
    }

    // Calcular cuotas pagadas y pendientes por mes
    const allInsts = instRes?.data || [];
    const curMonthStr = new Date().toISOString().slice(0, 7);

    // Ajustar datos mensuales si la función SQL aún no incluye cuotas_cobradas
    data.forEach(row => {
      const rowMesStr = String(row.mes || '').slice(0, 7);
      const instPagadasMes = allInsts.filter(i => i.estado === 'pagada' && String(i.pagada_at || i.created_at || '').slice(0, 7) === rowMesStr);
      const sumInstPagadas = instPagadasMes.reduce((a, b) => a + Number(b.monto_usd || 0), 0);
      
      if (row.cuotas_cobradas == null) {
        row.cuotas_cobradas = sumInstPagadas;
        row.ventas = Number(row.ventas || 0) + sumInstPagadas;
        row.ganancia = Number(row.ganancia || 0) + sumInstPagadas;
      }
    });

    const m = data[0] || {};
    const f = n => (n < 0 ? '-$' : '$') + Math.abs(Number(n || 0)).toFixed(2);
    
    const cuotasCobradasMes = Number(m.cuotas_cobradas || 0);
    const cuotasPendientesCalle = allInsts.filter(i => ['pendiente', 'en_revision', 'vencida'].includes(i.estado)).reduce((a, b) => a + Number(b.monto_usd || 0), 0);

    const cards = [
      ['Ventas Cobradas', m.ventas],
      ['Cuotas Cobradas', cuotasCobradasMes],
      ['Por Cobrar (Calle)', cuotasPendientesCalle],
      ['Devoluciones', m.devoluciones],
      ['Gastos', m.gastos],
      ['Compras', m.compras]
    ];

    // Métricas de Mesa de Cambio USDT
    const mcCfg = mcCfgRow?.data?.value || S.settings?.mesa_cambio_config || {};
    const ops = mcOpsRes?.data || [];
    const mcTotalUsdt = ops.reduce((a, o) => a + Number(o.monto_usdt || 0), 0);
    const mcTotalBs = ops.reduce((a, o) => a + Number(o.total_bs || 0), 0);
    const costRate = mcCfg.tasa_adquisicion_bs || 0;
    const mcProfitBs = ops.reduce((a, o) => {
      const cr = costRate || (Number(o.tasa_bs || 0) * 0.98);
      return a + Math.max(0, (Number(o.tasa_bs || 0) - cr) * Number(o.monto_usdt || 0));
    }, 0);
    const mcProfitUsd = ops.reduce((a, o) => {
      const cr = costRate || (Number(o.tasa_bs || 0) * 0.98);
      const diffBs = Math.max(0, (Number(o.tasa_bs || 0) - cr) * Number(o.monto_usdt || 0));
      return a + (Number(o.tasa_bs || 0) > 0 ? (diffBs / Number(o.tasa_bs)) : 0);
    }, 0);
    const mcFloat = Number(mcCfg.fondo_caja_usdt || 0);

    box.innerHTML = `
      <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px">
        <div class="card" style="background:rgba(0,245,160,.08);border:1.5px solid rgba(0,245,160,.35)">
          <div class="mut" style="font-size:.76rem;font-weight:700;text-transform:uppercase">Ganancia Neta (${esc(String(m.mes || '').slice(0, 7))})</div>
          <div class="price" style="font-size:1.8rem;color:${m.ganancia < 0 ? '#f87171' : 'var(--a)'}">${f(m.ganancia)}</div>
          <div class="mut" style="font-size:.7rem;margin-top:2px">Ingresos reales − egresos totales</div>
        </div>
        ${cards.map(([n, v]) => `
          <div class="card" style="padding:14px">
            <div class="mut" style="font-size:.74rem;font-weight:700;text-transform:uppercase">${n}</div>
            <div class="price" style="font-size:1.45rem;color:${n.includes('Calle') ? '#fbbf24' : (n.includes('Cuotas') ? '#38bdf8' : 'inherit')}">${f(v)}</div>
            ${n.includes('Calle') ? '<div class="mut" style="font-size:.68rem;color:#fde047">Deudas activas y plazos</div>' : ''}
            ${n.includes('Cuotas') ? '<div class="mut" style="font-size:.68rem;color:#38bdf8">Recaudado este mes</div>' : ''}
          </div>
        `).join('')}
      </div>

      <!-- PANEL FINANCIERO MESA DE CAMBIO USDT -->
      <div style="margin-top:16px;background:linear-gradient(135deg,rgba(15,23,42,.95),rgba(30,41,59,.9));border:1.5px solid rgba(253,224,71,.35);border-radius:16px;padding:18px">
        <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:12px">
          <div style="display:flex;align-items:center;gap:8px">
            <span style="font-size:1.4rem">💱</span>
            <div>
              <h4 style="margin:0;color:#fde047;font-size:1.05rem">Rendimiento Mesa de Cambio USDT</h4>
              <div class="mut" style="font-size:.74rem">Operaciones de venta de USDT y spread cambiario</div>
            </div>
          </div>
          <button type="button" class="g" id="btnGoMesaFromFin" style="background:#fde047;color:#0f172a;font-weight:800;border:none;padding:6px 14px;font-size:.78rem">
            ⚙️ Gestionar Mesa de Cambio
          </button>
        </div>

        <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:10px">
          <div style="background:rgba(0,0,0,.3);padding:10px 12px;border-radius:12px;border:1px solid rgba(0,245,160,.25)">
            <span class="mut" style="font-size:.7rem;display:block">💼 Saldo Liquidez (Fondo de Caja)</span>
            <div style="font-size:1.35rem;font-weight:900;color:${mcFloat < 5 ? '#f87171' : '#00f5a0'}">$${mcFloat.toFixed(2)} USDT</div>
            <span class="mut" style="font-size:.68rem">${mcFloat < 5 ? '⚠️ Nivel Crítico (< $5)' : '🟢 Liquidez activa'}</span>
          </div>
          <div style="background:rgba(0,0,0,.3);padding:10px 12px;border-radius:12px;border:1px solid rgba(56,189,248,.25)">
            <span class="mut" style="font-size:.7rem;display:block">🚀 USDT Despachados</span>
            <div style="font-size:1.35rem;font-weight:900;color:#38bdf8">$${mcTotalUsdt.toFixed(2)} USDT</div>
            <span class="mut" style="font-size:.68rem">${ops.length} órdenes aprobadas</span>
          </div>
          <div style="background:rgba(0,0,0,.3);padding:10px 12px;border-radius:12px;border:1px solid rgba(168,85,247,.25)">
            <span class="mut" style="font-size:.7rem;display:block">💵 Bolívares Recibidos</span>
            <div style="font-size:1.2rem;font-weight:900;color:#c084fc">Bs. ${mcTotalBs.toLocaleString('es-VE', {minimumFractionDigits:2, maximumFractionDigits:2})}</div>
            <span class="mut" style="font-size:.68rem">Abonados en cuenta BNC</span>
          </div>
          <div style="background:rgba(0,0,0,.3);padding:10px 12px;border-radius:12px;border:1px solid rgba(34,197,94,.25)">
            <span class="mut" style="font-size:.7rem;display:block">📈 Ganancia Neta Estimada (Spread)</span>
            <div style="font-size:1.35rem;font-weight:900;color:#4ade80">+$${mcProfitUsd.toFixed(2)} USD</div>
            <span class="mut" style="font-size:.68rem">≈ Bs. ${mcProfitBs.toLocaleString('es-VE', {minimumFractionDigits:2, maximumFractionDigits:2})}</span>
          </div>
        </div>
      </div>

      <p class="mut" style="margin-top:14px;font-size:.82rem">
        💡 <b>Fórmula Contable:</b> Ganancia Neta = (Ventas Directas + Cuotas y Créditos Cobrados) − Devoluciones − Gastos Operativos − Compras Cuentas Madre. Las cuotas y deudas se suman a la ganancia en el momento exacto en que son conciliadas y marcadas como pagadas.
      </p>
      <div class="row" style="margin-bottom:12px">
        <button class="g" id="g1">+ Gasto</button>
        <button class="g" id="g2">+ Compra</button>
        <button class="g" id="g3">Ver devoluciones</button>
        <button class="g" id="g4" style="color:var(--c);border-color:rgba(0,212,255,.35)">💳 Ver Cuotas por Cobrar</button>
      </div>

      <div class="wrap" style="margin-top:12px">
        <table>
          <thead>
            <tr>
              <th>Mes</th>
              <th>Ventas Totales</th>
              <th>Cuotas Cobradas</th>
              <th>Devoluciones</th>
              <th>Gastos</th>
              <th>Compras</th>
              <th>Ganancia Neta</th>
            </tr>
          </thead>
          <tbody>
            ${data.map(r => `
              <tr>
                <td><b>${esc(String(r.mes).slice(0, 7))}</b></td>
                <td><b style="color:var(--c)">${f(r.ventas)}</b></td>
                <td><span style="color:#38bdf8;font-weight:700">${f(r.cuotas_cobradas || 0)}</span></td>
                <td>${f(r.devoluciones)}</td>
                <td>${f(r.gastos)}</td>
                <td>${f(r.compras)}</td>
                <td><b style="color:${r.ganancia < 0 ? '#f87171' : '#00f5a0'}">${f(r.ganancia)}</b></td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;
    const bG1 = box.querySelector('#g1') || document.querySelector('#g1');
    if (bG1) bG1.onclick = () => admin('expenses');

    const bG2 = box.querySelector('#g2') || document.querySelector('#g2');
    if (bG2) bG2.onclick = () => admin('purchases');

    const bG3 = box.querySelector('#g3') || document.querySelector('#g3');
    if (bG3) bG3.onclick = () => admin('refunds');

    const bG4 = box.querySelector('#g4') || document.querySelector('#g4');
    if (bG4) bG4.onclick = () => admin('cuotas');

    const bGoMesa = box.querySelector('#btnGoMesaFromFin') || document.querySelector('#btnGoMesaFromFin');
    if (bGoMesa) bGoMesa.onclick = () => admin('mesa_cambio');
  },
  async google(box) {
    box.innerHTML = '<div style="padding:24px;text-align:center"><p class="mut">Cargando integraciones de Google Cloud…</p></div>';
    let { data: gi } = await sb.from('google_integrations').select('*');
    if(!gi || gi.length === 0){
      try {
        await sb.from('google_integrations').upsert([
          { service: 'calendar' }, { service: 'sheets' }, { service: 'drive' }, { service: 'contacts' }, { service: 'gemini' }
        ], { onConflict: 'service' });
        const refetch = await sb.from('google_integrations').select('*');
        gi = refetch.data || [];
      } catch(e) {}
    }

    const currentTab = box._googleTab || 'servicios';
    const has = !!sessionStorage.getItem('gtk');
    const on = k => !!gi?.find(x => x.service === k)?.enabled;

    box.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:16px">
        <div>
          <h3 style="margin:0 0 4px;font-size:1.15rem">🌐 Google Cloud & Workspace Hub</h3>
          <p class="mut" style="margin:0;font-size:.82rem">Automatizaciones en Calendar, Sheets, Drive, Contactos y configuración OAuth 2.0 unificada.</p>
        </div>
        <div style="display:flex;gap:8px;align-items:center">
          <button id="tabGoogleSrv" class="${currentTab === 'servicios' ? '' : 'g'}" style="padding:6px 12px;font-size:.78rem">🚀 Servicios y Tareas</button>
          <button id="tabGoogleOAuth" class="${currentTab === 'oauth' ? '' : 'g'}" style="padding:6px 12px;font-size:.78rem">⚙️ Configuración OAuth & Cloud</button>
        </div>
      </div>

      ${currentTab === 'servicios' ? `
        <div class="card" style="margin-bottom:16px;background:linear-gradient(135deg,rgba(10,26,50,.85),rgba(5,15,30,.9))">
          <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px">
            <div>
              <span class="mut" style="font-size:.76rem;display:block">Estado de Conexión OAuth:</span>
              <b style="font-size:1.05rem;color:${has ? '#00f5a0' : '#ffb703'}">${has ? '🟢 Sesión Google Conectada (OAuth 2.0)' : '⚠️ Sin Conectar con Google'}</b>
              <p class="mut" style="margin:4px 0 0;font-size:.76rem">Permite sincronizar eventos de Calendar, crear copias en Drive/Sheets y respaldar contactos.</p>
            </div>
            <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">
              ${has ? `
                <button id="btnDisconnectG" class="g" style="padding:7px 13px;font-size:.76rem;color:#f87171;border-color:rgba(239,68,68,.35)">Desconectar</button>
                <button id="btnViewGCal" class="g" style="padding:7px 13px;font-size:.76rem;color:#38bdf8">📅 Ver Google Calendar</button>
              ` : `
                <button id="gc" style="padding:8px 16px;font-size:.82rem;font-weight:700">🔑 Conectar con Google</button>
              `}
            </div>
          </div>
        </div>

        <div class="grid" style="margin-top:12px">
          ${[
            ['calendar', '📅 Calendar', 'Sincroniza automáticamente los eventos de vencimiento de pedidos y servicios de clientes.'],
            ['sheets', '📊 Google Sheets', 'Genera y actualiza un libro de cálculo con respaldos de Clientes, Pedidos, Facturas e Inventario.'],
            ['drive', '☁️ Google Drive', 'Sube copias de seguridad completas de toda la base de datos en formato JSON comprimido.'],
            ['contacts', '👥 Google Contacts', 'Guarda automáticamente a los clientes con número telefónico y email en tus Contactos de Google.'],
            ['gemini', '🤖 Gemini AI', 'Asistente de inteligencia artificial para redacción y análisis de incidencias.']
          ].map(([k, n, d]) => `
            <div class="card" style="display:flex;flex-direction:column;justify-content:space-between">
              <div>
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">
                  <b>${n}</b>
                  <span class="pill ${on(k) ? '' : 'off'}" style="font-size:.7rem">${on(k) ? 'Habilitado' : 'Inactivo'}</span>
                </div>
                <div class="mut" style="font-size:.78rem;line-height:1.4">${d}</div>
              </div>
              <div style="margin-top:12px;padding-top:10px;border-top:1px solid rgba(255,255,255,.07)">
                <label class="row" style="margin:0 0 10px;font-size:.8rem;align-items:center;cursor:pointer">
                  <input type="checkbox" style="width:auto;margin-right:6px" data-sv="${k}" ${on(k) ? 'checked' : ''}>
                  <span>Habilitar servicio</span>
                </label>
                ${k === 'gemini' ? `
                  <button class="g" id="btnGoGemini" style="width:100%;font-size:.76rem;padding:6px">Ir al Asistente Gemini ➔</button>
                ` : `
                  <button data-go="${k}" style="width:100%;font-size:.76rem;padding:6px" ${on(k) && has ? '' : 'disabled'}>
                    ${has ? '⚡ Ejecutar Sincronización' : '⚠️ Conecta Google primero'}
                  </button>
                `}
              </div>
            </div>
          `).join('')}
        </div>
      ` : `
        <div class="card" style="margin-bottom:16px;background:rgba(13,29,54,.6)">
          <h4 style="margin:0 0 8px;color:var(--c);font-size:.95rem">⚙️ Configuración y Credenciales OAuth de Google Cloud</h4>
          <p class="mut" style="font-size:.8rem;margin:0 0 12px;line-height:1.5">
            Para que la autenticación y las APIs funcionen en producción, asegúrate de haber registrado estas URLs en la consola de Google Cloud (<b>APIs y Servicios ➔ Credenciales ➔ ID de cliente OAuth 2.0</b>):
          </p>
          <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:10px;margin-bottom:12px">
            <div style="background:rgba(0,0,0,.35);padding:10px;border-radius:8px;border:1px solid rgba(255,255,255,.08)">
              <span class="mut" style="font-size:.72rem;display:block">Orígenes autorizados de JavaScript:</span>
              <code style="font-size:.8rem;color:#38bdf8">https://www.gregoryizquierdo.xyz</code>
            </div>
            <div style="background:rgba(0,0,0,.35);padding:10px;border-radius:8px;border:1px solid rgba(255,255,255,.08)">
              <span class="mut" style="font-size:.72rem;display:block">URI de redireccionamiento autorizados:</span>
              <code style="font-size:.8rem;color:#00f5a0">https://tevjiqnnnjnakftrjgud.supabase.co/auth/v1/callback</code>
            </div>
          </div>
          <div style="font-size:.76rem;color:#8ea8c8">
            <b>Calendario Principal vinculado:</b> <code>${GCal.CAL_ID || 'emprendimientogregoryizquierdo@gmail.com'}</code>
          </div>
        </div>

        <div class="wrap">
          <table style="width:100%">
            <tr>
              <th>Servicio</th>
              <th>Estado</th>
              <th>Configuración JSON</th>
              <th>Última Actualización</th>
              <th>Acción</th>
            </tr>
            ${(gi || []).map(row => `
              <tr>
                <td><b>${esc(row.service)}</b></td>
                <td>
                  <label style="display:inline-flex;align-items:center;gap:6px;cursor:pointer">
                    <input type="checkbox" data-sv-oauth="${esc(row.service)}" ${row.enabled ? 'checked' : ''} style="width:auto">
                    <span class="pill ${row.enabled ? '' : 'off'}" style="font-size:.72rem">${row.enabled ? 'Activo' : 'Inactivo'}</span>
                  </label>
                </td>
                <td style="max-width:300px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">
                  <code style="font-size:.75rem">${esc(JSON.stringify(row.config || {}))}</code>
                </td>
                <td><span class="mut" style="font-size:.75rem">${esc(row.updated_at ? row.updated_at.slice(0,16).replace('T',' ') : '—')}</span></td>
                <td>
                  <button class="g" data-edit-g-cfg="${esc(row.service)}" style="padding:4px 8px;font-size:.74rem">✏️ Editar Config</button>
                </td>
              </tr>
            `).join('')}
          </table>
        </div>
      `}
    `;

    const tabSrv = box.querySelector('#tabGoogleSrv');
    if(tabSrv) tabSrv.onclick = () => { box._googleTab = 'servicios'; EXTRA.google(box); };
    const tabOAuth = box.querySelector('#tabGoogleOAuth');
    if(tabOAuth) tabOAuth.onclick = () => { box._googleTab = 'oauth'; EXTRA.google(box); };

    const btnConnect = box.querySelector('#gc');
    if(btnConnect) btnConnect.onclick = () => GCal.connect();
    const btnDisc = box.querySelector('#btnDisconnectG');
    if(btnDisc) btnDisc.onclick = () => {
      sessionStorage.removeItem('gtk');
      toast('Sesión de Google desconectada localmente.');
      EXTRA.google(box);
    };
    const btnVCal = box.querySelector('#btnViewGCal');
    if(btnVCal) btnVCal.onclick = () => GCal.openEmbedView();
    const btnGoGem = box.querySelector('#btnGoGemini');
    if(btnGoGem) btnGoGem.onclick = () => admin('gemini');

    box.querySelectorAll('[data-sv]').forEach(c => c.onchange = async () => {
      await sb.from('google_integrations').update({ enabled: c.checked, updated_at: new Date().toISOString() }).eq('service', c.dataset.sv);
      EXTRA.google(box);
    });

    box.querySelectorAll('[data-sv-oauth]').forEach(c => c.onchange = async () => {
      await sb.from('google_integrations').update({ enabled: c.checked, updated_at: new Date().toISOString() }).eq('service', c.dataset.svOauth);
      EXTRA.google(box);
    });

    box.querySelectorAll('[data-edit-g-cfg]').forEach(btn => {
      btn.onclick = () => {
        const sName = btn.dataset.editGCfg;
        const sRow = gi?.find(x => x.service === sName);
        const curCfg = JSON.stringify(sRow?.config || {}, null, 2);
        $('#dlgBody').innerHTML = `
          <h3>⚙️ Configuración para ${esc(sName)}</h3>
          <p class="mut" style="font-size:.8rem;margin:0 0 10px">Edita los parámetros en formato JSON para este servicio (ej. client_id, calendar_id, spreadsheet_id).</p>
          <textarea id="txtGoogleCfgJson" rows="10" style="width:100%;font-family:monospace;font-size:.8rem;background:rgba(3,8,18,.9);border:1px solid var(--line);border-radius:8px;padding:8px;color:#c0e0ff">${esc(curCfg)}</textarea>
          <div style="display:flex;gap:10px;justify-content:flex-end;margin-top:12px">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnSaveGCfgJson">💾 Guardar Configuración</button>
          </div>
        `;
        dlg.showModal();
        $('#btnSaveGCfgJson').onclick = async () => {
          try {
            const parsed = JSON.parse($('#txtGoogleCfgJson').value);
            const { error: upErr } = await sb.from('google_integrations').update({
              config: parsed,
              updated_at: new Date().toISOString()
            }).eq('service', sName);
            if(upErr) throw upErr;
            dlg.close();
            toast(`Configuración de ${sName} guardada exitosamente.`);
            EXTRA.google(box);
          } catch(err){
            toast('JSON inválido o error: ' + err.message);
          }
        };
      };
    });

    const jobs = {
      async calendar() {
        const { data } = await sb.from('orders').select('id,vence,products(nombre),customers!customer_id(nombre)').in('estado', ['pagado', 'entregado']).gte('vence', today()).is('gcal_event_id', null); let n = 0;
        for (const o of data || []) { const ev = await G('https://www.googleapis.com/calendar/v3/calendars/primary/events', { method: 'POST', body: JSON.stringify({ summary: `Vence: ${o.products?.nombre || ''} · ${o.customers?.nombre || ''}`, start: { date: o.vence }, end: { date: addDay(o.vence) } }) }); await sb.from('orders').update({ gcal_event_id: ev.id }).eq('id', o.id); n++; }
        const { data: rf } = await sb.from('orders').select('id,gcal_event_id').eq('estado', 'reembolsado').not('gcal_event_id', 'is', null); let d = 0;
        for (const o of rf || []) { await fetch('https://www.googleapis.com/calendar/v3/calendars/primary/events/' + o.gcal_event_id, { method: 'DELETE', headers: { Authorization: 'Bearer ' + sessionStorage.getItem('gtk') } }); await sb.from('orders').update({ gcal_event_id: null }).eq('id', o.id); d++; }
        return `${n} vencimientos agregados y ${d} eventos de reembolsos eliminados en Calendar.`;
      },
      async sheets() {
        const d = await dump(), { data: inv } = await sb.from('profiles_inventory').select('nombre_perfil,vendedor,estado,inicia,vence,mother_accounts(plataforma,correo)');
        const T = { Clientes: ['nombre', 'email', 'telefono', 'zeny_balance'], Pedidos: ['created_at', 'total_usd', 'estado', 'inicia', 'vence'], Facturas: ['numero', 'emitida', 'total_usd', 'total_bs', 'tasa_bs'] }, src = { Clientes: d.customers, Pedidos: d.orders, Facturas: d.invoices };
        const sh = await G('https://sheets.googleapis.com/v4/spreadsheets', { method: 'POST', body: JSON.stringify({ properties: { title: 'Respaldo Tienda ' + today() }, sheets: [...Object.keys(T), 'Inventario'].map(title => ({ properties: { title } })) }) });
        const data = Object.entries(T).map(([k, c]) => ({ range: k + '!A1', values: [c, ...src[k].map(r => c.map(x => r[x] ?? ''))] }));
        data.push({ range: 'Inventario!A1', values: [['plataforma', 'cuenta', 'perfil', 'vendedor', 'estado', 'inicia', 'vence'], ...(inv || []).map(r => [r.mother_accounts?.plataforma, r.mother_accounts?.correo, r.nombre_perfil, r.vendedor, r.estado, r.inicia, r.vence].map(x => x ?? ''))] });
        await G(`https://sheets.googleapis.com/v4/spreadsheets/${sh.spreadsheetId}/values:batchUpdate`, { method: 'POST', body: JSON.stringify({ valueInputOption: 'RAW', data }) });
        return 'Respaldo creado: ' + sh.spreadsheetUrl;
      },
      async drive() {
        const b = 'b' + Date.now(), meta = { name: `respaldo-tienda-${today()}.json`, mimeType: 'application/json' };
        const body = `--${b}\r\nContent-Type: application/json\r\n\r\n${JSON.stringify(meta)}\r\n--${b}\r\nContent-Type: application/json\r\n\r\n${JSON.stringify(await dump())}\r\n--${b}--`;
        const f = await G('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart', { method: 'POST', headers: { 'Content-Type': 'multipart/related; boundary=' + b }, body }); return 'Respaldo subido a Drive: ' + f.name;
      },
      async contacts() {
        const { data } = await sb.from('customers').select('id,nombre,email,telefono').is('gcontact_id', null); let n = 0;
        for (const c of data || []) { if (!c.email && !c.telefono) continue; const p = await G('https://people.googleapis.com/v1/people:createContact', { method: 'POST', body: JSON.stringify({ names: [{ givenName: c.nombre || c.email }], emailAddresses: c.email ? [{ value: c.email }] : [], phoneNumbers: c.telefono ? [{ value: c.telefono }] : [] }) }); await sb.from('customers').update({ gcontact_id: p.resourceName }).eq('id', c.id); n++; }
        return `${n} contactos creados.`;
      }
    };
    box.querySelectorAll('[data-go]').forEach(b => b.onclick = () => run(b, jobs[b.dataset.go]));
  },

  async telegram(box) {
    if (!box) return;
    const { data } = await sb.from('settings').select('value').eq('key', 'bot').maybeSingle();
    if (!box.isConnected) {
      const activeBox = document.querySelector('#ex');
      if (activeBox) box = activeBox;
      else return;
    }
    box.innerHTML = `<p class="mut">Bot: ${data?.value?.username ? '✅ @' + esc(data.value.username) : '⚠️ sin conectar'}. El token se guarda cifrado en el servidor y nunca vuelve al navegador.</p>
    <div class="row"><input id="tk" type="password" placeholder="Token de @BotFather" autocomplete="off" style="max-width:420px"><button id="cn">Conectar bot</button><button class="g" id="cm">Editar respuestas</button></div>
    <p class="mut">Variables en las respuestas: {tasa} {telefono} {correo}. El comando * es la respuesta por defecto.</p>`;
    const bCm = box.querySelector('#cm') || document.querySelector('#cm');
    if (bCm) bCm.onclick = () => admin('bot_commands');
    const bCn = box.querySelector('#cn') || document.querySelector('#cn');
    if (bCn) bCn.onclick = e => run(e.target, async () => { const r = await api('/api/telegram-setup', { token: ($('#tk')?.value || '').trim() }); if ($('#tk')) $('#tk').value = ''; EXTRA.telegram(box); return 'Conectado: @' + r.bot; });
  },

  async cuotas(box) {
    let instList = null, error = null;
    let res = await sb.from('installments')
      .select('*, customers!customer_id(id,nombre,email,telefono,codigo_identificacion,es_revendedor), reseller:customers!reseller_id(nombre,email,telefono), orders(referencia, products(nombre))')
      .order('fecha_vencimiento', { ascending: true });
    if (res.error) {
      res = await sb.from('installments')
        .select('*, customers!customer_id(id,nombre,email,telefono,codigo_identificacion,es_revendedor), orders(referencia, products(nombre))')
        .order('fecha_vencimiento', { ascending: true });
    }
    if (res.error) {
      res = await sb.from('installments')
        .select('*, orders(referencia, products(nombre))')
        .order('fecha_vencimiento', { ascending: true });
    }
    instList = res.data;
    error = res.error;

    if (error) {
      if (error.message?.includes('schema cache') || error.code === '42P01') {
        box.innerHTML = `
          <div class="card" style="border:1.5px solid rgba(0,212,255,.4);background:linear-gradient(135deg,rgba(10,26,50,.95),rgba(5,15,30,.98))">
            <h3 style="margin:0 0 8px;color:var(--c)">⚡ Activación de Cuotas en Supabase</h3>
            <p class="mut" style="margin:0 0 14px;font-size:.88rem;line-height:1.5">
              Para habilitar el módulo de cuotas, solo debes pegar y ejecutar el script SQL de migración en tu <b>SQL Editor</b> de Supabase.
            </p>
            <div style="display:flex;gap:10px;flex-wrap:wrap">
              <button id="btnCopySql" type="button" style="padding:10px 18px">📋 Copiar SQL de Migración</button>
              <a href="https://supabase.com/dashboard/project/tevjiqnnnjnakftrjgud/sql/new" target="_blank" rel="noopener noreferrer" class="g" style="text-decoration:none;display:inline-flex;align-items:center;padding:10px 18px;border-radius:12px;font-weight:700">
                ↗ Ir a SQL Editor en Supabase
              </a>
            </div>
          </div>
        `;
        $('#btnCopySql').onclick = async () => {
          const sql = `-- Migracion: Sistema de Financiamiento en Cuotas (BNPL)
create table if not exists installments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  numero_cuota int not null default 1,
  total_cuotas int not null default 2,
  monto_usd numeric(10,2) not null check (monto_usd > 0),
  monto_bs numeric(14,2),
  tasa_bs numeric(12,4),
  fecha_vencimiento date not null default current_date,
  estado text not null default 'pendiente' check (estado in ('pendiente','en_revision','pagada','vencida')),
  metodo_id uuid references payment_methods(id),
  referencia text,
  comprobante_url text,
  pagada_at timestamptz,
  created_at timestamptz not null default now()
);
alter table installments enable row level security;
drop policy if exists installments_user_select on installments;
create policy installments_user_select on installments for select to authenticated using (customer_id = auth.uid() or is_admin());
drop policy if exists installments_admin_all on installments;
create policy installments_admin_all on installments for all to authenticated using (is_admin()) with check (is_admin());`;
          await navigator.clipboard.writeText(sql);
          toast('¡SQL copiado al portapapeles! Pégalo y ejecútalo en Supabase.');
        };
        return;
      }
      box.innerHTML = `<p class="mut">Error al cargar cuotas: ${esc(error.message)}</p>`;
      return;
    }

    const todayStr = new Date().toISOString().slice(0, 10);
    const list = instList || [];
    const pendTotal = list.filter(c => c.estado !== 'pagada').reduce((a, c) => a + Number(c.monto_usd || 0), 0);
    const revCount = list.filter(c => c.estado === 'en_revision').length;
    const vencCount = list.filter(c => c.estado !== 'pagada' && c.fecha_vencimiento < todayStr).length;
    const pendCount = list.filter(c => c.estado === 'pendiente' && c.fecha_vencimiento >= todayStr).length;
    const pagCount = list.filter(c => c.estado === 'pagada').length;

    let filter = box._cuotasFilter || 'todas';
    let search = (box._cuotasSearch || '').toLowerCase().trim();

    const filtered = list.filter(c => {
      if (filter === 'revision' && c.estado !== 'en_revision') return false;
      if (filter === 'pendientes' && (c.estado !== 'pendiente' || c.fecha_vencimiento < todayStr)) return false;
      if (filter === 'vencidas' && (c.estado === 'pagada' || c.fecha_vencimiento >= todayStr)) return false;
      if (filter === 'pagadas' && c.estado !== 'pagada') return false;

      if (search) {
        const nom = (c.customers?.nombre || '').toLowerCase();
        const mail = (c.customers?.email || '').toLowerCase();
        const tel = (c.customers?.telefono || '').toLowerCase();
        const cod = (c.customers?.codigo_identificacion || '').toLowerCase();
        const prod = (c.orders?.products?.nombre || c.orders?.referencia || c.referencia || '').toLowerCase();
        const ref = (c.referencia || '').toLowerCase();
        if (!nom.includes(search) && !mail.includes(search) && !tel.includes(search) && !cod.includes(search) && !prod.includes(search) && !ref.includes(search)) {
          return false;
        }
      }
      return true;
    });

    box.innerHTML = `
      <div class="card" style="margin-bottom:16px;background:linear-gradient(135deg,rgba(13,39,76,.85),rgba(7,20,40,.9))">
        <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px">
          <div>
            <h3 style="margin:0 0 4px;font-size:1.15rem">💳 Control Integral y Cobranza de Cuotas (BNPL)</h3>
            <p class="mut" style="margin:0;font-size:.82rem">Gestiona los pagos en cuotas, aprueba abonos, asigna límites de crédito y exporta informes contables.</p>
          </div>
          <div style="display:flex;gap:10px;text-align:right;align-items:center;flex-wrap:wrap">
            <button id="btnExportCuotasCsv" class="g" style="padding:6px 12px;font-size:.76rem" title="Descargar reporte en formato CSV compatible con Excel">📥 Exportar CSV</button>
            <button id="btnConfigCuotas" class="g" style="padding:6px 12px;font-size:.76rem">⚙️ Configurar BNPL</button>
            <button id="btnManageCredits" class="g" style="padding:6px 12px;font-size:.76rem">👥 Límites de Crédito</button>
            <div>
              <span class="mut" style="font-size:.72rem;display:block">Por cobrar:</span>
              <b style="font-size:1.2rem;color:var(--c)">$${pendTotal.toFixed(2)} USD</b>
            </div>
          </div>
        </div>
      </div>

      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:14px">
        <div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center">
          <button data-filter-cuota="todas" class="${filter === 'todas' ? '' : 'g'}" style="padding:5px 11px;font-size:.76rem">
            Todas (${list.length})
          </button>
          <button data-filter-cuota="revision" class="${filter === 'revision' ? '' : 'g'}" style="padding:5px 11px;font-size:.76rem;color:${revCount ? '#fde047' : 'inherit'}">
            En revisión (${revCount})
          </button>
          <button data-filter-cuota="pendientes" class="${filter === 'pendientes' ? '' : 'g'}" style="padding:5px 11px;font-size:.76rem">
            Pendientes (${pendCount})
          </button>
          <button data-filter-cuota="vencidas" class="${filter === 'vencidas' ? '' : 'g'}" style="padding:5px 11px;font-size:.76rem;color:${vencCount ? '#ff4d6d' : 'inherit'}">
            Vencidas (${vencCount})
          </button>
          <button data-filter-cuota="pagadas" class="${filter === 'pagadas' ? '' : 'g'}" style="padding:5px 11px;font-size:.76rem;color:#00f5a0">
            Pagadas (${pagCount})
          </button>
        </div>
        <div style="flex:1;min-width:240px;max-width:380px">
          <input id="inputSearchCuotas" placeholder="🔍 Buscar cliente, código, teléfono o ref..." value="${esc(box._cuotasSearch || '')}" style="width:100%;font-size:.8rem;padding:6px 10px">
        </div>
      </div>

      <div class="wrap">
        <table>
          <tr>
            <th>Cuota</th>
            <th>Cliente</th>
            <th>Servicio</th>
            <th>Monto</th>
            <th>Vencimiento</th>
            <th>Estado</th>
            <th>Referencia</th>
            <th>Acciones</th>
          </tr>
          ${filtered.map(c => {
            const isVencida = c.estado !== 'pagada' && c.fecha_vencimiento < todayStr;
            const statusClass = isVencida ? 'vencida' : c.estado;
            const statusLabel = isVencida ? 'Vencida' : (c.estado === 'en_revision' ? 'En revisión' : (c.estado === 'pagada' ? 'Pagada' : 'Pendiente'));
            const tel = c.customers?.telefono || '';
            const nom = c.customers?.nombre || c.customers?.email || 'Cliente';
            const cod = c.customers?.codigo_identificacion || (c.customers?.es_revendedor ? 'RVD:1001' : 'CLT:001');
            const prod = c.orders?.products?.nombre || c.orders?.referencia || c.referencia || 'Servicio Digital';
            const rawMsg = formatMessageTemplate('cobro_cuota', {
              cliente: nom,
              producto: prod,
              servicio: prod,
              cuota: c.numero_cuota,
              total_cuotas: c.total_cuotas,
              monto_usd: Number(c.monto_usd).toFixed(2),
              monto_bs: (Number(c.monto_usd) * (S.rate || 0)).toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2}),
              tasa_bcv: (S.rate || 0).toLocaleString('es-VE'),
              fecha_vencimiento: c.fecha_vencimiento
            });

            return `
              <tr>
                <td>
                  <b>#${c.numero_cuota} de ${c.total_cuotas}</b>
                  <span class="mut" style="display:block;font-size:.7rem">${esc(c.created_at ? c.created_at.slice(0, 10) : '')}</span>
                </td>
                <td>
                  <div style="display:flex;align-items:center;gap:6px">
                    <span style="font-family:monospace;font-size:.74rem;color:var(--c);font-weight:700">${esc(cod)}</span>
                    <b>${esc(nom)}</b>
                  </div>
                  ${c.reseller?.nombre ? `<div style="font-size:.72rem;color:#f59e0b;margin-top:2px;font-weight:600">🏷️ Revendedor: ${esc(c.reseller.nombre)}</div>` : ''}
                  ${tel ? `<div style="font-size:.72rem;color:#38bdf8;margin-top:2px"><a href="https://wa.me/${tel.replace(/\D/g,'')}" target="_blank" style="color:inherit;text-decoration:none">📱 ${esc(tel)}</a></div>` : ''}
                  <span class="mut" style="display:block;font-size:.7rem">${esc(c.customers?.email || '')}</span>
                </td>
                <td>${esc(prod)}</td>
                <td>
                  <b style="color:var(--c);font-size:.92rem">$${Number(c.monto_usd).toFixed(2)}</b>
                  <div class="mut" style="font-size:.7rem">Bs. ${(Number(c.monto_usd) * (S.rate || 0)).toLocaleString('es-VE',{minimumFractionDigits:2,maximumFractionDigits:2})}</div>
                </td>
                <td>
                  <span style="color:${isVencida ? '#ff4d6d' : 'inherit'};font-weight:${isVencida ? '700' : 'normal'}">${esc(c.fecha_vencimiento)}</span>
                </td>
                <td><span class="bnpl-inst-pill ${statusClass}">${statusLabel}</span></td>
                <td>
                  <code>${esc(c.referencia || '—')}</code>
                  ${c.comprobante_url ? `<a href="${esc(c.comprobante_url)}" target="_blank" style="display:block;font-size:.72rem;color:var(--c);margin-top:2px">📎 Ver Comprobante</a>` : ''}
                </td>
                <td class="row" style="gap:4px;align-items:center">
                  ${c.estado !== 'pagada' ? `
                    <button data-ok-inst="${c.id}" style="padding:5px 8px;font-size:.74rem;font-weight:700" title="Aprobar pago de esta cuota">Aprobar</button>
                  ` : '<span class="mut" style="font-size:.74rem">✓ Pagada</span>'}
                  ${c.estado === 'en_revision' ? `
                    <button class="g" data-reset-inst="${c.id}" style="padding:5px 8px;font-size:.74rem;color:#f87171;border-color:rgba(239,68,68,.35)" title="Rechazar comprobante y devolver a pendiente">❌</button>
                  ` : ''}
                  <button class="g" data-edit-inst="${c.id}" style="padding:5px 8px;font-size:.74rem" title="Editar cuota (monto, fecha o referencia)">✏️</button>
                  ${c.estado !== 'pagada' ? `
                    <button class="g" data-wa-inst="${c.id}" data-tel="${esc(tel)}" data-nom="${esc(nom)}" data-prod="${esc(prod)}" data-c="${c.numero_cuota}" data-tc="${c.total_cuotas}" data-m="${Number(c.monto_usd).toFixed(2)}" data-f="${esc(c.fecha_vencimiento)}" style="padding:5px 8px;font-size:.74rem;color:#00f5a0;border-color:rgba(0,245,160,.35);font-weight:700" title="Enviar recordatorio de cobro por WhatsApp">
                      💬
                    </button>
                  ` : ''}
                  <button class="clean-copy-btn" data-clean-copy="${esc(rawMsg)}" style="padding:5px 8px;font-size:.74rem" title="Copiar plantilla de cobro">
                    📋
                  </button>
                  <button class="d" data-del-inst="${c.id}" style="padding:5px 8px;font-size:.74rem" title="Eliminar cuota">🗑️</button>
                </td>
              </tr>
            `;
          }).join('') || '<tr><td colspan="8" class="mut empty">No se encontraron cuotas con los filtros seleccionados.</td></tr>'}
        </table>
      </div>
    `;

    box.querySelectorAll('[data-filter-cuota]').forEach(btn => {
      btn.onclick = () => {
        box._cuotasFilter = btn.dataset.filterCuota;
        EXTRA.cuotas(box);
      };
    });

    const sInp = box.querySelector('#inputSearchCuotas');
    if (sInp) {
      let _st;
      sInp.oninput = () => {
        clearTimeout(_st);
        _st = setTimeout(() => {
          box._cuotasSearch = sInp.value;
          EXTRA.cuotas(box);
        }, 250);
      };
    }

    const bExport = box.querySelector('#btnExportCuotasCsv');
    if (bExport) {
      bExport.onclick = () => {
        const headers = ["ID", "Nro_Cuota", "Total_Cuotas", "Cliente", "Codigo", "Telefono", "Email", "Servicio", "Monto_USD", "Monto_BS", "Tasa_BS", "Fecha_Vencimiento", "Estado", "Referencia", "Pagada_At", "Fecha_Registro"];
        const lines = [headers.join(',')];
        filtered.forEach(c => {
          const nom = c.customers?.nombre || '';
          const cod = c.customers?.codigo_identificacion || (c.customers?.es_revendedor ? 'RVD:1001' : 'CLT:001');
          const tel = c.customers?.telefono || '';
          const mail = c.customers?.email || '';
          const prod = c.orders?.products?.nombre || c.orders?.referencia || c.referencia || 'Servicio Digital';
          const mUsd = Number(c.monto_usd || 0).toFixed(2);
          const tBs = Number(c.tasa_bs || S.rate || 0);
          const mBs = (Number(mUsd) * tBs).toFixed(2);
          const row = [
            `"${c.id}"`,
            c.numero_cuota,
            c.total_cuotas,
            `"${nom.replace(/"/g, '""')}"`,
            `"${cod}"`,
            `"${tel.replace(/"/g, '""')}"`,
            `"${mail.replace(/"/g, '""')}"`,
            `"${prod.replace(/"/g, '""')}"`,
            mUsd,
            mBs,
            tBs.toFixed(4),
            `"${c.fecha_vencimiento || ''}"`,
            `"${c.estado || ''}"`,
            `"${(c.referencia || '').replace(/"/g, '""')}"`,
            `"${c.pagada_at || ''}"`,
            `"${c.created_at || ''}"`
          ];
          lines.push(row.join(','));
        });
        const blob = new Blob(["\uFEFF" + lines.join("\r\n")], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `cuotas_cobranza_${todayStr}.csv`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        toast('Reporte CSV de cuotas exportado.');
      };
    }

    box.querySelectorAll('[data-ok-inst]').forEach(btn => {
      btn.onclick = () => run(btn, async () => {
        const id = btn.dataset.okInst;
        let { error } = await sb.rpc('approve_installment', { p_installment_id: id });
        if (error) {
          const { error: updErr } = await sb.from('installments').update({
            estado: 'pagada',
            pagada_at: new Date().toISOString()
          }).eq('id', id);
          if (updErr) throw updErr;
        }
        EXTRA.cuotas(box);
        return 'Cuota aprobada con éxito.';
      });
    });

    box.querySelectorAll('[data-reset-inst]').forEach(btn => {
      btn.onclick = () => run(btn, async () => {
        const id = btn.dataset.resetInst;
        if(!confirm('¿Deseas devolver esta cuota a estado pendiente para que el cliente adjunte un nuevo comprobante?')) return;
        const { error } = await sb.from('installments').update({ estado: 'pendiente', referencia: null }).eq('id', id);
        if (error) throw error;
        EXTRA.cuotas(box);
        return 'Cuota restablecida a pendiente.';
      });
    });

    box.querySelectorAll('[data-edit-inst]').forEach(btn => {
      btn.onclick = () => {
        const id = btn.dataset.editInst;
        const c = list.find(x => x.id === id);
        if (!c) return;

        $('#dlgBody').innerHTML = `
          <h3>✏️ Editar Registro de Cuota #${c.numero_cuota} de ${c.total_cuotas}</h3>
          <p class="mut" style="font-size:.8rem;margin:0 0 14px">Ajusta los valores financieros o el estado administrativo de la cuota.</p>
          <div style="display:flex;flex-direction:column;gap:12px;margin-bottom:14px">
            <div>
              <label class="mut" style="font-size:.74rem">Monto en Dólares ($ USD):</label>
              <input id="editInstMonto" type="number" step="0.01" min="0.01" value="${Number(c.monto_usd).toFixed(2)}" style="font-weight:700">
            </div>
            <div>
              <label class="mut" style="font-size:.74rem">Fecha de Vencimiento:</label>
              <input id="editInstVence" type="date" value="${c.fecha_vencimiento || todayStr}">
            </div>
            <div>
              <label class="mut" style="font-size:.74rem">Estado de la Cuota:</label>
              <select id="editInstEstado">
                <option value="pendiente" ${c.estado === 'pendiente' ? 'selected' : ''}>Pendiente</option>
                <option value="en_revision" ${c.estado === 'en_revision' ? 'selected' : ''}>En revisión</option>
                <option value="pagada" ${c.estado === 'pagada' ? 'selected' : ''}>Pagada</option>
                <option value="vencida" ${c.estado === 'vencida' ? 'selected' : ''}>Vencida</option>
              </select>
            </div>
            <div>
              <label class="mut" style="font-size:.74rem">Referencia de Pago:</label>
              <input id="editInstRef" value="${esc(c.referencia || '')}" placeholder="Ej: 123456 / Pago Móvil">
            </div>
          </div>
          <div style="display:flex;gap:10px;justify-content:flex-end">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnSaveInstEdit">💾 Guardar Cambios</button>
          </div>
        `;
        dlg.showModal();

        $('#btnSaveInstEdit').onclick = () => run($('#btnSaveInstEdit'), async () => {
          const newMonto = parseFloat($('#editInstMonto').value);
          const newVence = $('#editInstVence').value;
          const newEst = $('#editInstEstado').value;
          const newRef = $('#editInstRef').value.trim();

          if (isNaN(newMonto) || newMonto <= 0) throw new Error('El monto debe ser mayor a 0');
          if (!newVence) throw new Error('Ingresa una fecha de vencimiento');

          const updateData = {
            monto_usd: newMonto,
            fecha_vencimiento: newVence,
            estado: newEst,
            referencia: newRef || null
          };
          if (newEst === 'pagada' && !c.pagada_at) updateData.pagada_at = new Date().toISOString();

          const { error: upErr } = await sb.from('installments').update(updateData).eq('id', id);
          if (upErr) throw upErr;

          dlg.close();
          EXTRA.cuotas(box);
          return 'Cuota actualizada correctamente.';
        });
      };
    });

    box.querySelectorAll('[data-wa-inst]').forEach(btn => {
      btn.onclick = () => {
        let tel = btn.dataset.tel || '';
        const nom = btn.dataset.nom || 'Cliente';
        const prod = btn.dataset.prod || 'Servicio Digital';
        const cNum = btn.dataset.c || '1';
        const cTot = btn.dataset.tc || '2';
        const mUsd = btn.dataset.m || '0.00';
        const fVence = btn.dataset.f || '';
        const mBs = (Number(mUsd) * (S.rate || 0)).toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2});
        const tasaBcv = (S.rate || 0).toLocaleString('es-VE');

        if(!tel){
          tel = prompt(`Ingresa el número de WhatsApp para enviar el cobro a ${nom} (ej: 04121234567 o +58...):`, '') || '';
        }

        const rawMsg = formatMessageTemplate('cobro_cuota', {
          cliente: nom,
          producto: prod,
          servicio: prod,
          cuota: cNum,
          total_cuotas: cTot,
          monto_usd: mUsd,
          monto_bs: mBs,
          tasa_bcv: tasaBcv,
          fecha_vencimiento: fVence
        });

        openWhatsApp(tel, rawMsg);
        toast(`Recordatorio de cobro copiado y abriendo WhatsApp para ${nom}...`);
      };
    });

    box.querySelectorAll('[data-del-inst]').forEach(btn => {
      btn.onclick = () => run(btn, async () => {
        const id = btn.dataset.delInst;
        if(!confirm('¿Confirmas que deseas eliminar permanentemente este registro de cuota?')) return;
        const { error } = await sb.from('installments').delete().eq('id', id);
        if (error) throw error;
        EXTRA.cuotas(box);
        return 'Cuota eliminada.';
      });
    });

    if (window.setupCleanCopy) setupCleanCopy(box);

    const bCfg = box.querySelector('#btnConfigCuotas');
    if(bCfg){
      bCfg.onclick = async () => {
        let cfg = S.settings?.cuotas_config;
        if(!cfg){
          const { data } = await sb.from('settings').select('value').eq('key', 'cuotas_config').maybeSingle();
          cfg = data?.value || { inicial_porcentaje: 50, total_cuotas: 2, dias_frecuencia: 15, monto_minimo: 5.00 };
        }
        $('#dlgBody').innerHTML = `
          <h3>⚙️ Parámetros de Financiamiento en Cuotas (BNPL)</h3>
          <p class="mut" style="font-size:.8rem;margin:0 0 14px">Establece el porcentaje de la cuota inicial y el número de cuotas en las que tus clientes financiarán sus compras.</p>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:12px">
            <div>
              <label class="mut" style="font-size:.74rem">Cuota Inicial (% del total):</label>
              <input id="cfgCuotasPct" type="number" min="10" max="90" step="5" value="${cfg.inicial_porcentaje || 50}" style="margin-top:2px">
            </div>
            <div>
              <label class="mut" style="font-size:.74rem">Número Total de Cuotas:</label>
              <input id="cfgCuotasTotal" type="number" min="2" max="12" step="1" value="${cfg.total_cuotas || 2}" style="margin-top:2px">
            </div>
          </div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:16px">
            <div>
              <label class="mut" style="font-size:.74rem">Frecuencia entre cuotas (Días):</label>
              <input id="cfgCuotasDias" type="number" min="1" max="60" step="1" value="${cfg.dias_frecuencia || 15}" style="margin-top:2px">
            </div>
            <div>
              <label class="mut" style="font-size:.74rem">Monto mínimo elegible ($ USD):</label>
              <input id="cfgCuotasMin" type="number" min="1" max="100" step="1" value="${cfg.monto_minimo || 5.00}" style="margin-top:2px">
            </div>
          </div>
          <button id="btnSaveCuotasCfg" style="width:100%">💾 Guardar Parámetros de Cuotas</button>
        `;
        dlg.showModal();

        $('#btnSaveCuotasCfg').onclick = () => run($('#btnSaveCuotasCfg'), async () => {
          const newCfg = {
            inicial_porcentaje: Number($('#cfgCuotasPct')?.value || 50),
            total_cuotas: Number($('#cfgCuotasTotal')?.value || 2),
            dias_frecuencia: Number($('#cfgCuotasDias')?.value || 15),
            monto_minimo: Number($('#cfgCuotasMin')?.value || 5.00)
          };
          const { error } = await sb.from('settings').upsert({
            key: 'cuotas_config',
            value: newCfg,
            updated_at: new Date().toISOString()
          });
          if(error) throw error;
          S.settings = S.settings || {};
          S.settings.cuotas_config = newCfg;
          dlg.close();
          EXTRA.cuotas(box);
          return 'Configuración de cuotas actualizada con éxito.';
        });
      };
    }

    const bCred = box.querySelector('#btnManageCredits');
    if(bCred){
      bCred.onclick = async () => {
        const { data: users, error: uErr } = await sb.from('customers').select('id,nombre,email,telefono,codigo_identificacion,es_revendedor,limite_credito').order('creado', { ascending: false });
        if(uErr) return toast('Error al cargar usuarios: ' + uErr.message);
        const renderList = (term = '') => {
          const fl = (users || []).filter(u => {
            if(!term) return true;
            const q = term.toLowerCase();
            return (u.nombre || '').toLowerCase().includes(q) || (u.email || '').toLowerCase().includes(q) || (u.codigo_identificacion || '').toLowerCase().includes(q);
          });
          return `
            <div style="max-height:55vh;overflow-y:auto;margin:12px 0">
              <table style="width:100%;font-size:.82rem">
                <tr>
                  <th>Código / Usuario</th>
                  <th>Rol</th>
                  <th>Límite Crédito ($)</th>
                  <th>Acción</th>
                </tr>
                ${fl.map(u => `
                  <tr>
                    <td>
                      <b style="color:var(--c);font-family:monospace">${esc(u.codigo_identificacion || (u.es_revendedor ? 'RVD:1001' : 'CLT:001'))}</b>
                      <div style="font-weight:600">${esc(u.nombre || 'Sin nombre')}</div>
                      <span class="mut" style="font-size:.72rem">${esc(u.email || '')}</span>
                    </td>
                    <td>
                      <span class="pill ${u.es_revendedor ? '' : 'off'}" style="font-size:.72rem">
                        ${u.es_revendedor ? '⭐ Revendedor' : '👤 Cliente'}
                      </span>
                    </td>
                    <td>
                      <div style="display:flex;align-items:center;gap:4px">
                        <span>$</span>
                        <input type="number" step="1" min="0" value="${Number(u.limite_credito != null ? u.limite_credito : 10.00).toFixed(2)}" id="creditInp_${u.id}" style="width:75px;padding:4px;font-size:.82rem;font-weight:700">
                      </div>
                    </td>
                    <td>
                      <button class="g" data-save-usr-credit="${u.id}" style="padding:4px 8px;font-size:.72rem">💾 Guardar</button>
                    </td>
                  </tr>
                `).join('') || '<tr><td colspan="4" class="mut empty">No se encontraron usuarios</td></tr>'}
              </table>
            </div>
          `;
        };

        $('#dlgBody').innerHTML = `
          <h3>💳 Asignación Manual de Límites de Crédito</h3>
          <p class="mut" style="font-size:.8rem;margin:0 0 10px">Asigna o ajusta el crédito disponible a Clientes y Revendedores.</p>
          <input id="searchCreditUser" placeholder="🔍 Buscar por nombre, email o código..." style="width:100%;font-size:.82rem">
          <div id="creditUsersContainer">${renderList()}</div>
        `;
        dlg.showModal();

        const bindSaveEvents = () => {
          $('#creditUsersContainer').querySelectorAll('[data-save-usr-credit]').forEach(btn => {
            btn.onclick = async () => {
              const uid = btn.dataset.saveUsrCredit;
              const val = parseFloat($(`#creditInp_${uid}`)?.value);
              if (isNaN(val) || val < 0) return toast('Ingresa un monto válido mayor o igual a 0');
              btn.disabled = true;
              const { error } = await sb.from('customers').update({ limite_credito: val }).eq('id', uid);
              btn.disabled = false;
              if (error) return toast('Error: ' + error.message);
              if (S.me && S.me.id === uid) S.me.limite_credito = val;
              const uObj = users.find(x => x.id === uid);
              if (uObj) uObj.limite_credito = val;
              toast(`Límite actualizado a $${val.toFixed(2)} USD`);
            };
          });
        };
        bindSaveEvents();

        $('#searchCreditUser').oninput = e => {
          $('#creditUsersContainer').innerHTML = renderList(e.target.value);
          bindSaveEvents();
        };
      };
    }
  },

  async franquicias(box) {
    box.innerHTML = '<div style="padding:30px;text-align:center"><div class="sk" style="height:120px;max-width:500px;margin:auto"></div><p class="mut" style="margin-top:12px">Cargando Red de Franquicias…</p></div>';

    let franqList = [];
    let error = null;
    try {
      const resF = await sb.from('franchises').select('*').order('created_at', { ascending: false });
      if (resF.error) error = resF.error;
      else franqList = resF.data || [];
    } catch(errF) {
      error = errF;
    }

    let apps = [];
    try {
      const resA = await sb.from('franchise_applications').select('*').order('created_at', { ascending: false });
      if (!resA.error && resA.data) {
        apps = resA.data;
      }
    } catch(errA) {
      apps = [];
    }

    if (error && (error.message?.includes('schema cache') || error.code === '42P01')) {
      box.innerHTML = `
        <div class="card" style="border:1.5px solid rgba(0,212,255,.4);background:linear-gradient(135deg,rgba(10,26,50,.95),rgba(5,15,30,.98))">
          <h3 style="margin:0 0 8px;color:var(--c)">⚡ Activación de Red de Franquicias en Supabase</h3>
          <p class="mut" style="margin:0 0 14px;font-size:.88rem;line-height:1.5">
            Para habilitar el módulo de franquicias y contratos, solo debes pegar y ejecutar el script SQL de migración en tu <b>SQL Editor</b> de Supabase.
          </p>
          <div style="display:flex;gap:10px;flex-wrap:wrap">
            <button id="btnCopyFranqSql" type="button" style="padding:10px 18px">📋 Copiar SQL de Franquicias</button>
            <a href="https://supabase.com/dashboard/project/tevjiqnnnjnakftrjgud/sql/new" target="_blank" rel="noopener noreferrer" class="g" style="text-decoration:none;display:inline-flex;align-items:center;padding:10px 18px;border-radius:12px;font-weight:700">
              ↗ Ir a SQL Editor en Supabase
            </a>
          </div>
        </div>
      `;
      $('#btnCopyFranqSql').onclick = async () => {
        const sql = `-- Migracion 10: Modulo Completo de Franquicias SaaS (Multi-tenant y Contratos)
create table if not exists franchises (
  id uuid primary key default gen_random_uuid(),
  subdominio text not null unique,
  nombre_comercial text not null,
  titular_nombre text not null,
  titular_cedula_rif text,
  titular_telefono text not null,
  titular_correo text not null,
  titular_ciudad text,
  logo_url text,
  color_primario text not null default '#00d4ff',
  canon_mensual_usd numeric(10,2) not null default 25.00,
  estado text not null default 'activo' check (estado in ('activo','suspendido_mora','suspendido_fraude','en_revision')),
  fecha_inicio date not null default current_date,
  fecha_vencimiento_canon date not null default (current_date + interval '30 days'),
  modulos_activos jsonb not null default '{"bot_telegram":false,"cuotas_bnpl":false,"vencimientos":true,"gemini":false}',
  contrato_texto text,
  contrato_aceptado boolean not null default true,
  contrato_aceptado_at timestamptz not null default now(),
  notas_internas text,
  created_at timestamptz not null default now()
);

create index if not exists idx_franchises_subdomain on franchises(subdominio);
create index if not exists idx_franchises_estado on franchises(estado);

alter table franchises enable row level security;
drop policy if exists franchises_admin on franchises;
create policy franchises_admin on franchises for all to authenticated using (is_admin()) with check (is_admin());
drop policy if exists franchises_public_select on franchises;
create policy franchises_public_select on franchises for select to anon using (true);`;
        await navigator.clipboard.writeText(sql);
        toast('¡SQL copiado al portapapeles! Pégalo y ejecútalo en Supabase.');
      };
      return;
    }

    const list = franqList || [];
    const baseDomain = location.hostname.includes('.') ? location.hostname.replace(/^[^.]+\./, '') : 'gregoryizquierdo.xyz';

    let canonCfg = S.settings?.franquicia_canon_config;
    if (!canonCfg) {
      const { data: cData } = await sb.from('settings').select('value').eq('key', 'franquicia_canon_config').maybeSingle();
      canonCfg = cData?.value || { promo_quota: 10, promo_canon: 10.00, regular_canon: 25.00 };
    }
    const promoQuota = Number(canonCfg.promo_quota || 10);
    const promoCanon = Number(canonCfg.promo_canon || 10.00);
    const regularCanon = Number(canonCfg.regular_canon || 25.00);
    const activeCount = list.filter(f => f.estado === 'activo').length;
    const isPromoActive = activeCount < promoQuota;
    const currentSuggestedCanon = isPromoActive ? promoCanon : regularCanon;

    box.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:16px">
        <div>
          <h3 style="margin:0 0 4px;font-size:1.2rem">🏢 Red de Franquicias Digitales (SaaS)</h3>
          <p class="mut" style="margin:0;font-size:.82rem">Administra subdominios, contratos legales, canones mensuales y configuración técnica de tus franquiciados.</p>
        </div>
        <div class="row">
          <button id="btnNewFranq">+ Nueva Franquicia</button>
          <button class="g" id="btnCanonConfig">⚙️ Ajustar Canon & Cupos</button>
          <button class="g" id="btnAumentoDoc">📝 Circular Aumento Canon</button>
          <button class="g" id="btnFranqManual">📘 Manual para Franquiciado</button>
          <button class="g" id="btnFranqGuide">📖 Guía DNS</button>
        </div>
      </div>

      <!-- Resumen Métrico y Promoción de Lanzamiento -->
      <div class="grid" style="margin-bottom:18px">
        <div class="card">
          <div class="mut">Franquicias Activas</div>
          <div class="price">${activeCount}</div>
        </div>
        <div class="card">
          <div class="mut">🎁 Cupo Promo 10 ($${promoCanon.toFixed(2)} USD)</div>
          <div style="font-size:1.1rem;font-weight:700;margin-top:6px;color:${isPromoActive ? 'var(--a)' : '#ffb703'}">
            ${Math.min(activeCount, promoQuota)} / ${promoQuota} Cupos Ocupados
          </div>
          <span class="mut" style="font-size:.72rem">
            ${isPromoActive ? `🟢 Quedan ${promoQuota - activeCount} cupos a $${promoCanon.toFixed(2)}/mes` : `⚠️ Cupo promo agotado. Canon regular: $${regularCanon.toFixed(2)}/mes`}
          </span>
        </div>
        <div class="card">
          <div class="mut">Canon Mensual Proyectado</div>
          <div class="price" style="color:var(--a)">$${list.filter(f => f.estado === 'activo').reduce((a, b) => a + Number(b.canon_mensual_usd || 0), 0).toFixed(2)} USD</div>
        </div>
        <div class="card">
          <div class="mut">Dominio Base Red</div>
          <div style="font-size:1.05rem;font-weight:700;color:var(--c);margin-top:6px">*.${esc(baseDomain)}</div>
        </div>
      </div>

      <!-- Solicitudes Recibidas desde la Web -->
      <div style="margin-bottom:24px">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
          <h4 style="margin:0;font-size:1.05rem;color:var(--tx);display:flex;align-items:center;gap:8px">
            <span>📬 Solicitudes de Franquicia Web</span>
            <span class="pill" style="background:rgba(99,102,241,.2);color:#a5b4fc;border:1px solid rgba(129,140,248,.4)">${apps.length}</span>
          </h4>
        </div>
        <div class="wrap">
          <table>
            <tr>
              <th>Negocio / Aspirante</th>
              <th>Contacto</th>
              <th>Documento / Ciudad</th>
              <th>Verificación KYC</th>
              <th>Fecha</th>
              <th>Acciones</th>
            </tr>
            ${apps.map(app => {
              const waNum = (app.phone || '').replace(/[^\d]/g, '');
              const waDirectUrl = `https://wa.me/${waNum}?text=${encodeURIComponent(`Hola ${app.owner_name}, un gusto saludarte. Te escribe Gregory Izquierdo respecto a tu solicitud para la franquicia ${app.business_name}.`)}`;
              const hasKyc = !!(app.doc_frontal_url || app.selfie_doc_url);
              return `
                <tr>
                  <td>
                    <b>${esc(app.business_name)}</b>
                    <span class="mut" style="display:block;font-size:.75rem">Titular: ${esc(app.owner_name)}</span>
                    ${app.subdominio_deseado ? `<span style="font-size:.72rem;color:var(--c)">🔗 ${esc(app.subdominio_deseado)}.${esc(baseDomain)}</span>` : ''}
                  </td>
                  <td>
                    <b>${esc(app.phone)}</b>
                    <span class="mut" style="display:block;font-size:.73rem">${esc(app.email)}</span>
                  </td>
                  <td>
                    <b>${esc(app.cedula_rif || 'No especificada')}</b>
                    <span class="mut" style="display:block;font-size:.73rem">📍 ${esc(app.ciudad || 'Venezuela')}</span>
                  </td>
                  <td>
                    ${hasKyc ? `
                      <span class="pill" style="background:rgba(16,185,129,.15);color:#10b981;border-color:rgba(16,185,129,.35);font-size:.72rem;font-weight:700">
                        🛡️ 4 Fotos KYC
                      </span>
                      <button class="g" data-app-kyc="${app.id}" style="padding:3px 7px;font-size:.7rem;margin-left:4px" title="Ver fotos del documento y selfie">🔍 Ver</button>
                    ` : `
                      <span class="pill off" style="font-size:.72rem">Sin fotos</span>
                    `}
                  </td>
                  <td style="font-size:.75rem">${new Date(app.created_at).toLocaleDateString('es-VE')}</td>
                  <td class="row">
                    <button class="cta" data-app-approve="${app.id}" style="padding:5px 10px;font-size:.76rem" title="Aprobar postulación y crear franquicia activa">
                      ✅ Aprobar & Crear
                    </button>
                    <a href="${waDirectUrl}" target="_blank" rel="noopener noreferrer" class="g" style="color:#25d366;border-color:rgba(37,211,102,.4);font-weight:700;font-size:.76rem;padding:5px 10px;border-radius:10px;text-decoration:none">
                      💬 WA
                    </a>
                  </td>
                </tr>
              `;
            }).join('') || '<tr><td colspan="6" class="mut empty">No hay solicitudes web pendientes por contactar.</td></tr>'}
          </table>
        </div>
      </div>

      <!-- Tabla de Franquicias SaaS -->
      <div class="wrap">
        <table>
          <tr>
            <th>Franquicia / URL</th>
            <th>Titular / Contacto</th>
            <th>Billetera Central / Nivel</th>
            <th>Canon & Ciclo</th>
            <th>Estado</th>
            <th>Acciones</th>
          </tr>
          ${list.map(f => {
            const franqUrl = `https://${f.subdominio}.${baseDomain}`;
            const stLabel = f.estado === 'activo' ? '🟢 Activo' : (f.estado === 'suspendido_fraude' ? '🚨 Suspendido Fraude' : (f.estado === 'suspendido_mora' ? '🟡 Suspendido Mora' : 'En revisión'));
            
            // Cálculo de días de canon
            const now = new Date();
            const vencDate = f.fecha_vencimiento_canon ? new Date(f.fecha_vencimiento_canon + 'T23:59:59') : new Date();
            const diffDays = Math.ceil((vencDate - now) / (1000 * 60 * 60 * 24));
            let canonBadge = '';
            if (diffDays > 5) {
              canonBadge = `<span class="pill" style="background:rgba(16,185,129,.15);color:#10b981;font-size:.7rem;font-weight:700">🟢 Al día (${diffDays}d)</span>`;
            } else if (diffDays >= 0) {
              canonBadge = `<span class="pill" style="background:rgba(245,158,11,.15);color:#f59e0b;font-size:.7rem;font-weight:800">🟡 Vence en ${diffDays}d</span>`;
            } else {
              canonBadge = `<span class="pill" style="background:rgba(239,68,68,.2);color:#f87171;font-size:.7rem;font-weight:900">🔴 En mora (+${Math.abs(diffDays)}d)</span>`;
            }

            // Nivel de volumen
            const tier = f.nivel_volumen || 'bronce';
            const tierBadge = tier === 'oro' 
              ? '<span class="pill" style="background:rgba(245,158,11,.2);color:#fbbf24;border-color:rgba(245,158,11,.4);font-size:.68rem;font-weight:800">🥇 ORO (-6%)</span>'
              : (tier === 'plata'
                ? '<span class="pill" style="background:rgba(148,163,184,.2);color:#cbd5e1;border-color:rgba(148,163,184,.4);font-size:.68rem;font-weight:800">🥈 PLATA (-3%)</span>'
                : '<span class="pill" style="font-size:.68rem;color:#94a3b8">🥉 BRONCE</span>');

            const saldoBilletera = Number(f.saldo_billetera_usd || 0).toFixed(2);

            return `
              <tr>
                <td>
                  <b>${esc(f.nombre_comercial)}</b>
                  <div style="margin-top:3px">
                    <a href="${franqUrl}" target="_blank" rel="noopener noreferrer" style="color:var(--c);font-size:.8rem;text-decoration:none;font-weight:600">
                      🔗 ${esc(f.subdominio)}.${esc(baseDomain)}
                    </a>
                  </div>
                </td>
                <td>
                  <b>${esc(f.titular_nombre)}</b>
                  <span class="mut" style="display:block;font-size:.73rem">${esc(f.titular_telefono)} · ${esc(f.titular_correo)}</span>
                </td>
                <td>
                  <div style="display:flex;align-items:center;gap:6px">
                    <b style="color:#00f5a0;font-size:.95rem">$${saldoBilletera} USD</b>
                    <button class="g" data-fq-wallet="${f.id}" data-nom="${esc(f.nombre_comercial)}" data-saldo="${saldoBilletera}" style="padding:2px 7px;font-size:.7rem;color:#00f5a0;border-color:rgba(0,245,160,.4);font-weight:700" title="Recargar Billetera Mayorista Prepago">+ Recargar</button>
                  </div>
                  <div style="margin-top:4px">${tierBadge}</div>
                </td>
                <td>
                  <div><b>$${Number(f.canon_mensual_usd).toFixed(2)} USD/mes</b></div>
                  <div style="margin-top:3px;display:flex;align-items:center;gap:4px">
                    ${canonBadge}
                    <button class="g" data-fq-pay-canon="${f.id}" data-nom="${esc(f.nombre_comercial)}" style="padding:2px 6px;font-size:.68rem;color:#38bdf8" title="Registrar pago y sumar 30 días">💳 Cobro</button>
                  </div>
                </td>
                <td><span class="pill ${f.estado === 'activo' ? '' : 'off'}">${stLabel}</span></td>
                <td class="row">
                  <button class="g" data-fq-invoice="${f.id}" title="Emitir Factura / Recibo de Arrendamiento SaaS">🧾 Factura</button>
                  <button class="g" data-fq-view="${f.id}" title="Ver expediente, contrato y detalles comerciales">📄 Expediente</button>
                  <button class="g" data-fq-reset="${f.id}" data-email="${esc(f.titular_correo)}" title="Restaurar clave de acceso del franquiciado">🔑 Clave</button>
                  ${f.estado === 'activo' ? `
                    <button class="d" data-fq-kill="${f.id}" data-sub="${esc(f.subdominio)}" title="Kill-Switch: suspender inmediatamente">🚨 Kill-Switch</button>
                  ` : `
                    <button data-fq-reactivate="${f.id}">✅ Reactivar</button>
                  `}
                </td>
              </tr>
            `;
          }).join('') || '<tr><td colspan="6" class="mut empty">No hay franquicias registradas aún. Pulsa "+ Nueva Franquicia" para asentar la primera.</td></tr>'}
        </table>
      </div>
    `;

    // Manual para Franquiciado (listo para entregar o copiar)
    $('#btnFranqManual').onclick = () => {
      const manualMarkdown = `# 📘 GUÍA OFICIAL PARA EL FRANQUICIADO
Plataforma de Comercio Digital Multi-Tenant
Infraestructura provista por Gregory Izquierdo SaaS

1. TU DIRECCIÓN WEB:
Accede a tu tienda a través de tu subdominio asignado (ej: https://tumarca.${baseDomain}).

2. PRIMER ACCESO AL PANEL:
- Ingresa a tu tienda y pulsa "Admin" o "Ingresar".
- Accede con el correo oficial registrado en tu contrato.
- Si no tienes la contraseña, pulsa "¿Olvidaste tu contraseña?" o pide a la central un reset para recibir el enlace de acceso.

3. CONFIGURACIÓN OBLIGATORIA DE TUS MÉTODOS DE PAGO:
- En tu panel ve a "Métodos de Pago" y pulsa "+ Agregar".
- Ingresa tus datos de Pago Móvil, Transferencias Bancarias, Binance Pay o Zinli.
- ¡El 100% del dinero cobrado a tus clientes cae directo en tus cuentas personales! La central no retiene tus ganancias.

4. PERSONALIZACIÓN DE TU TIENDA:
- En "Ajustes ➔ Negocio", coloca tu número de WhatsApp de soporte, logo y correo.
- El botón flotante de WhatsApp de tu tienda conectará directo con tu teléfono celular.

5. CÓMO VENDER Y MODALIDAD DE INVENTARIO HÍBRIDO:
- Catálogo: Ajusta precios de venta al público en USD o activa promociones.
- Stock Propio: Registra cuentas madre y perfiles propios en tu panel para quedarte con el 100% de tu margen de venta.
- Respaldo con Stock Central (Híbrido): Si se te agota un servicio o prefieres no comprar cuentas por adelantado, tu tienda puede despachar directamente desde el inventario central a tarifa mayorista preferencial.
- Pedidos: Cuando un cliente reporta un pago, verifica en tu banco y pulsa "Aprobar" para que el sistema libere las credenciales al cliente.
- Vencimientos: El sistema te avisa quién vence hoy o en 3 días para cobrar la renovación por WhatsApp antes del corte.

6. PAGO DEL CANON MENSUAL:
- El canon mensual se cancela cada 30 días a la Central para mantener tus servidores y base de datos activa.
- Envía tu comprobante con 24h de anticipación para evitar interrupciones.

7. POLÍTICA DE SEGURIDAD Y TOLERANCIA CERO AL FRAUDE:
- Eres responsable directo de la atención y garantías a tus compradores.
- Cualquier reporte fundamentado de estafa o fraude conllevará la suspensión inmediata de la tienda mediante Kill-Switch.`;

      $('#dlgBody').innerHTML = `
        <h3>📘 Manual de Operación para el Franquiciado</h3>
        <p class="mut" style="font-size:.8rem;margin:0 0 10px">Puedes copiar este texto y enviárselo directamente por WhatsApp o correo a tu nuevo franquiciado.</p>
        <textarea id="txtFranqManual" rows="14" readonly style="font-size:.78rem;font-family:monospace;background:rgba(3,8,18,.9);border:1px solid var(--line);border-radius:10px;padding:10px;color:#c0e0ff;width:100%">${esc(manualMarkdown)}</textarea>
        <div class="row" style="margin-top:12px">
          <button id="btnCopyManual" style="flex:1">📋 Copiar Manual Completo</button>
          <button class="g" onclick="dlg.close()">Cerrar</button>
        </div>
      `;
      $('#btnCopyManual').onclick = async () => {
        await navigator.clipboard.writeText(manualMarkdown);
        toast('¡Manual copiado al portapapeles! Listo para enviar.');
      };
      dlg.showModal();
    };

    // Guía interactiva DNS
    $('#btnFranqGuide').onclick = () => {
      $('#dlgBody').innerHTML = `
        <h3>📖 Guía de Operación y Puesta en Marcha de Franquicias</h3>
        <div style="font-size:.85rem;line-height:1.6;color:var(--tx);max-height:65vh;overflow-y:auto;padding-right:6px">
          <p><b>1. Configuración de Subdominio DNS:</b><br>
          En tu proveedor de dominio (Cloudflare, Namecheap o Vercel), asegúrate de tener un registro CNAME wildcard: <code>*</code> apuntando a tu despliegue (ej. <code>cname.vercel-dns.com</code>). Así cualquier subdominio nuevo funcionará automáticamente sin tocar código.</p>

          <p><b>2. Cómo configura el Franquiciado su Logo y Métodos de Pago:</b><br>
          Al iniciar sesión en su panel con su correo, tendrá acceso a <b>Ajustes ➔ Métodos de Pago</b> para agregar sus números de Pago Móvil y cuentas bancarias donde cobrará directo sus ganancias, y en <b>Ajustes ➔ Negocio</b> colocará su Logo y teléfonos de soporte.</p>

          <p><b>3. Cobro del Canon Mensual:</b><br>
          El canon mensual ($25 USD o el acordado) se renueva cada 30 días. Si no cancela a tiempo, puedes pulsar <b>Suspender Mora</b> hasta que reporte su comprobante.</p>

          <p><b>4. Kill-Switch de Seguridad:</b><br>
          Si detectas anomalías o reportes de estafa contra un franquiciado, usa el botón <b>🚨 Suspender Fraude</b> para desconectar su subdominio al instante y proteger la reputación de tu red.</p>
        </div>
      `;
      dlg.showModal();
    };

    // Modal Crear Nueva Franquicia
    $('#btnNewFranq').onclick = () => {
      $('#dlgBody').innerHTML = `
        <h3>🏢 Asentar Nueva Franquicia y Contrato</h3>
        <p class="mut" style="font-size:.8rem;margin:0 0 12px">Completa los datos comerciales. La URL se generará automáticamente en tiempo real.</p>
        <div style="display:flex;flex-direction:column;gap:10px;max-height:65vh;overflow-y:auto;padding-right:4px">
          <label class="mut" style="font-size:.76rem">Nombre Comercial de la Franquicia:</label>
          <input id="fqName" placeholder="Ej: Streaming Cool" required>

          <label class="mut" style="font-size:.76rem">Subdominio deseado (sin espacios ni símbolos):</label>
          <input id="fqSub" placeholder="Ej: streamingcool" required>

          <!-- Previsualizador de URL guía en tiempo real -->
          <div style="background:rgba(0,212,255,.08);border:1px solid rgba(0,212,255,.3);border-radius:12px;padding:10px 14px">
            <span class="mut" style="font-size:.72rem;display:block">URL Guía asignada a la franquicia:</span>
            <b id="fqUrlPreview" style="color:var(--c);font-size:.92rem;word-break:break-all">https://streamingcool.${baseDomain}</b>
          </div>

          <label class="mut" style="font-size:.76rem">Nombre del Propietario / Titular:</label>
          <input id="fqOwner" placeholder="Ej: Carlos Rodríguez" required>

          <label class="mut" style="font-size:.76rem">Cédula / RIF:</label>
          <input id="fqDoc" placeholder="Ej: V-19876543">

          <label class="mut" style="font-size:.76rem">Teléfono / WhatsApp:</label>
          <input id="fqTel" placeholder="Ej: +58 412 1234567" required>

          <label class="mut" style="font-size:.76rem">Correo electrónico oficial (para acceso al panel):</label>
          <input id="fqEmail" type="email" placeholder="Ej: contacto@streamingcool.com" required>

          <label class="mut" style="font-size:.76rem">Ciudad / Estado:</label>
          <input id="fqCity" placeholder="Ej: Valencia, Carabobo">

          <label class="mut" style="font-size:.76rem">Canon Mensual Acordado (USD):</label>
          <div style="display:flex;align-items:center;gap:8px">
            <input id="fqCanon" type="number" value="${currentSuggestedCanon}" min="0" step="1" required style="font-weight:700;width:120px">
            <span class="pill" style="font-size:.72rem;background:${isPromoActive ? 'rgba(0,245,160,.12)' : 'rgba(255,183,3,.15)'};color:${isPromoActive ? 'var(--a)' : '#ffb703'}">
              ${isPromoActive ? `🎁 Promoción (${activeCount + 1} de ${promoQuota})` : '🏷️ Canon Regular'}
            </span>
          </div>

          <label class="mut" style="font-size:.76rem">Modalidad de Inventario:</label>
          <select id="fqStockMode">
            <option value="hibrido" selected>🔄 Híbrido (Stock Propio + Respaldo Central)</option>
            <option value="propio">📦 Solo Stock Propio</option>
            <option value="central">🔑 Solo Stock Central</option>
          </select>

          <label class="mut" style="font-size:.76rem;margin-top:4px">Notas internas / Acuerdos especiales:</label>
          <textarea id="fqNotes" rows="2" placeholder="Ej: Incluye módulo de Telegram bonificado el primer mes..."></textarea>
        </div>
        <button id="btnSaveFranq" style="margin-top:14px;width:100%">Crear Franquicia y Generar Contrato</button>
      `;

      $('#fqSub').oninput = e => {
        const cleanSub = e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, '');
        e.target.value = cleanSub;
        $('#fqUrlPreview').textContent = `https://${cleanSub || 'subdominio'}.${baseDomain}`;
      };

      $('#btnSaveFranq').onclick = async () => {
        const btn = $('#btnSaveFranq');
        if (btn.disabled) return;

        const sub = ($('#fqSub').value || '').trim().toLowerCase().replace(/[^a-z0-9-]/g, '');
        const name = ($('#fqName').value || '').trim();
        const owner = ($('#fqOwner').value || '').trim();
        const email = ($('#fqEmail').value || '').trim();
        const tel = ($('#fqTel').value || '').trim();
        const doc = ($('#fqDoc')?.value || '').trim();
        const city = ($('#fqCity')?.value || '').trim();
        const notes = ($('#fqNotes')?.value || '').trim();
        const canon = Number($('#fqCanon')?.value || 25);
        const stockMode = $('#fqStockMode')?.value || 'hibrido';

        if (!sub) return toast('Ingresa el subdominio para la franquicia.');
        if (sub.length < 2) return toast('El subdominio debe tener al menos 2 caracteres.');
        if (!name) return toast('Ingresa el nombre comercial de la franquicia.');
        if (!owner) return toast('Ingresa el nombre del propietario o titular.');
        if (!email) return toast('Ingresa el correo oficial de la franquicia.');
        if (!tel) return toast('Ingresa el teléfono o WhatsApp de contacto.');

        btn.disabled = true;
        const originalBtnText = btn.innerHTML;
        btn.innerHTML = '⏳ Guardando y generando contrato...';

        const contractText = `CONTRATO DE LICENCIA DE SOFTWARE Y FRANQUICIA DIGITAL MARCA BLANCA

Entre EMPRENDIMIENTO GREGORY IZQUIERDO (en adelante "El Proveedor Tecnológico") y ${owner}, titular de ${name} (en adelante "El Franquiciado").

1. OBJETO: El Proveedor otorga una licencia de uso de la plataforma web en el subdominio https://${sub}.${baseDomain}.
2. AUTONOMÍA Y DESLINDE DE RESPONSABILIDAD: El Franquiciado opera de manera comercialmente independiente. Todos los cobros, métodos de pago, garantías y atención al cliente son de su exclusiva responsabilidad. El Proveedor no asume responsabilidad solidaria ante clientes finales de la Franquicia.
3. CANON MENSUAL: El Franquiciado se compromete a cancelar un canon mensual de $${canon} USD cada 30 días continuos.
4. KILL-SWITCH Y TOLERANCIA CERO AL FRAUDE: El Proveedor se reserva el derecho de suspender de inmediato el subdominio y acceso ante cualquier denuncia fundamentada de fraude o estafa.
5. MODALIDAD DE INVENTARIO HÍBRIDO (${stockMode.toUpperCase()}): El Franquiciado comercializa servicios con cuentas y perfiles propios o, ante falta de stock, despacha directamente con respaldo del inventario central a tarifa mayorista preferencial.
Fecha de asentamiento: ${new Date().toISOString().slice(0, 10)}.`;

        try {
          let created = false;
          let errMsg = '';

          // 1. Intentar primero con RPC admin_create_franchise (seguridad definer)
          try {
            const rpcPromise = sb.rpc('admin_create_franchise', {
              p_subdominio: sub,
              p_nombre_comercial: name,
              p_titular_nombre: owner,
              p_titular_cedula_rif: doc,
              p_titular_telefono: tel,
              p_titular_correo: email,
              p_titular_ciudad: city,
              p_canon_mensual_usd: canon,
              p_notas_internas: notes,
              p_contrato_texto: contractText,
              p_modalidad_inventario: stockMode
            });

            const timeoutPromise = new Promise((_, reject) =>
              setTimeout(() => reject(new Error('Tiempo de espera agotado al conectar con el servidor')), 12000)
            );

            const rpcRes = await Promise.race([rpcPromise, timeoutPromise]);
            if (rpcRes && !rpcRes.error) {
              const resData = rpcRes.data;
              if (resData?.error) {
                errMsg = resData.error;
              } else if (resData?.success || resData?.franchise) {
                created = true;
              }
            } else if (rpcRes?.error) {
              errMsg = rpcRes.error.message || 'Error en RPC';
            }
          } catch(rpcErr) {
            console.warn('RPC admin_create_franchise no completó, intentando directo:', rpcErr);
            errMsg = rpcErr?.message || '';
          }

          // 2. Si RPC no logró crearlo, intentar inserción directa en la tabla
          if (!created && (!errMsg || errMsg.includes('function') || errMsg.includes('RPC'))) {
            const { error: insErr } = await sb.from('franchises').insert({
              subdominio: sub,
              nombre_comercial: name,
              titular_nombre: owner,
              titular_cedula_rif: doc,
              titular_telefono: tel,
              titular_correo: email,
              titular_ciudad: city,
              canon_mensual_usd: canon,
              notas_internas: notes,
              contrato_texto: contractText,
              estado: 'activo',
              saldo_billetera_usd: 0.00,
              nivel_volumen: 'bronce',
              compras_mes_usd: 0.00,
              kyc_estado: 'verificado'
            });

            if (!insErr) {
              created = true;
            } else {
              errMsg = insErr.message || 'Error al insertar en la base de datos';
            }
          }

          if (!created) {
            if (errMsg.includes('unique') || errMsg.includes('ya está en uso') || errMsg.includes('ya está registrado')) {
              return toast(`El subdominio "${sub}" ya está en uso. Elige otro.`);
            }
            return toast(`Error al registrar franquicia: ${errMsg || 'Verifica la conexión'}`);
          }

          dlg.close();
          toast(`🎉 ¡Franquicia ${name} creada exitosamente en ${sub}.${baseDomain}!`);
          EXTRA.franquicias(box);
        } catch (fatalErr) {
          console.error('Error fatal guardando franquicia:', fatalErr);
          toast(`Error inesperado: ${fatalErr.message || 'Intente nuevamente'}`);
        } finally {
          btn.disabled = false;
          btn.innerHTML = originalBtnText || 'Crear Franquicia y Generar Contrato';
        }
      };

      dlg.showModal();
    };

    // Expediente y Contrato
    box.querySelectorAll('[data-fq-view]').forEach(btn => {
      btn.onclick = () => {
        const f = list.find(x => x.id === btn.dataset.fqView);
        if (!f) return;
        const franqUrl = `https://${f.subdominio}.${baseDomain}`;
        $('#dlgBody').innerHTML = `
          <h3>Expediente: ${esc(f.nombre_comercial)}</h3>
          <div style="font-size:.85rem;line-height:1.5;max-height:65vh;overflow-y:auto;padding-right:6px">
            <div style="background:rgba(7,19,38,.9);border:1px solid var(--line);border-radius:12px;padding:12px;margin-bottom:12px">
              <b>URL de la Tienda:</b> <a href="${franqUrl}" target="_blank" style="color:var(--c)">${franqUrl}</a><br>
              <b>Titular:</b> ${esc(f.titular_nombre)} (${esc(f.titular_cedula_rif || 'Sin documento')})<br>
              <b>Contacto:</b> ${esc(f.titular_telefono)} · ${esc(f.titular_correo)}<br>
              <b>Ciudad:</b> ${esc(f.titular_ciudad || 'No especificada')}<br>
              <b>Canon:</b> $${Number(f.canon_mensual_usd).toFixed(2)} USD/mes · Vence: <b>${esc(f.fecha_vencimiento_canon)}</b><br>
              <b>Estado:</b> <span class="pill ${f.estado === 'activo' ? '' : 'off'}">${esc(f.estado)}</span>
            </div>

            <h4 style="margin:10px 0 6px;color:var(--a)">📜 Contrato Legal de Franquicia</h4>
            <pre style="background:rgba(3,8,18,.9);border:1px solid var(--line);border-radius:10px;padding:12px;font-size:.76rem;white-space:pre-wrap;color:#b3e9ff;font-family:monospace">${esc(f.contrato_texto || 'Sin contrato redactado')}</pre>

            <button id="btnCopyContract" style="width:100%;margin-top:10px">📋 Copiar Contrato para Enviar al Franquiciado</button>
          </div>
        `;
        $('#btnCopyContract').onclick = async () => {
          await navigator.clipboard.writeText(f.contrato_texto || '');
          toast('Contrato copiado al portapapeles.');
        };
        dlg.showModal();
      };
    });

    // Emitir Factura de Canon de Franquicia
    box.querySelectorAll('[data-fq-invoice]').forEach(btn => {
      btn.onclick = () => {
        const f = list.find(x => x.id === btn.dataset.fqInvoice);
        if (!f) return;
        const canonUsd = Number(f.canon_mensual_usd || 25);
        const canonBs = canonUsd * (S.rate || 0);
        openInvoiceModal({
          numero: String(Math.floor(Date.now() / 1000)).slice(-6),
          fecha: new Date().toLocaleString('es-VE'),
          tipo_documento: 'Factura de Servicio / Recibo de Arrendamiento Tecnológico SaaS',
          cliente_nombre: f.titular_nombre,
          cliente_doc: f.titular_cedula_rif || 'No especificado',
          cliente_extra: `Franquicia: ${f.nombre_comercial} · Subdominio: ${f.subdominio}.${baseDomain} · Ciudad: ${f.titular_ciudad || 'Venezuela'}`,
          cliente_telefono: f.titular_telefono,
          metodo_pago: 'Pago Móvil / Transferencia Bancaria (Primer Pago Registrado)',
          tasa_bs: S.rate,
          total_usd: canonUsd,
          total_bs: canonBs,
          items: [
            {
              concepto: `Canon mensual de infraestructura y licencia SaaS (${f.nombre_comercial})`,
              detalle: `Subdominio: https://${f.subdominio}.${baseDomain} · Ciclo: 30 días continuos (Vence: ${f.fecha_vencimiento_canon})`,
              cant: 1,
              precio_usd: canonUsd,
              total_usd: canonUsd
            }
          ]
        });
      };
    });

    // Reset Clave de acceso
    box.querySelectorAll('[data-fq-reset]').forEach(btn => {
      btn.onclick = async () => {
        const email = btn.dataset.email;
        if (!confirm(`¿Enviar correo de restablecimiento de contraseña a ${email}?`)) return;
        const { error: resetErr } = await sb.auth.resetPasswordForEmail(email, { redirectTo: location.origin + '/' });
        if (resetErr) return toast(resetErr.message);
        toast(`Correo de recuperación enviado con éxito a ${email}.`);
      };
    });

    // Kill-Switch (Suspender por Fraude)
    box.querySelectorAll('[data-fq-kill]').forEach(btn => {
      btn.onclick = async () => {
        const id = btn.dataset.fqKill, sub = btn.dataset.sub;
        if (!confirm(`🚨 ¿ACTIVAR KILL-SWITCH PARA ${sub}?\n\nLa tienda quedará inaccesible de inmediato y se bloqueará el acceso del propietario.`)) return;
        btn.disabled = true;
        btn.textContent = 'Suspendiendo…';
        try {
          const { error: killErr } = await sb.from('franchises').update({ estado: 'suspendido_fraude' }).eq('id', id);
          if (killErr) throw killErr;
          if (typeof invalidateAdminCache === 'function') invalidateAdminCache('franchises');
          toast(`Franquicia ${sub} suspendida preventivamente con Kill-Switch.`);
          await EXTRA.franquicias(box);
        } catch(err) {
          btn.disabled = false;
          btn.textContent = '🚨 Kill-Switch';
          toast('Error al suspender: ' + (err.message || 'Error de conexión'));
        }
      };
    });

    // Reactivar
    box.querySelectorAll('[data-fq-reactivate]').forEach(btn => {
      btn.onclick = async () => {
        const id = btn.dataset.fqReactivate;
        btn.disabled = true;
        btn.textContent = 'Reactivando…';
        try {
          const { error: reactErr } = await sb.from('franchises').update({ estado: 'activo' }).eq('id', id);
          if (reactErr) throw reactErr;
          if (typeof invalidateAdminCache === 'function') invalidateAdminCache('franchises');
          toast('Franquicia reactivada exitosamente.');
          await EXTRA.franquicias(box);
        } catch(err) {
          btn.disabled = false;
          btn.textContent = '✅ Reactivar';
          toast('Error al reactivar: ' + (err.message || 'Error de conexión'));
        }
      };
    });

    // Configuración de Canon Promocional y Regular
    $('#btnCanonConfig').onclick = () => {
      $('#dlgBody').innerHTML = `
        <h3>⚙️ Ajustar Canon & Cupos de Franquicia</h3>
        <p class="mut" style="font-size:.82rem;margin:0 0 14px">Establece el precio promocional para las primeras franquicias y el canon regular posterior.</p>
        <div style="display:flex;flex-direction:column;gap:12px;background:rgba(255,255,255,.03);padding:14px;border-radius:12px;border:1px solid rgba(255,255,255,.08);margin-bottom:14px">
          <div>
            <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Cupo de Franquicias en Promoción:</label>
            <input id="cfgPromoQuota" type="number" min="1" max="100" value="${promoQuota}" style="width:100%;font-size:1.05rem;font-weight:700">
            <span class="mut" style="font-size:.72rem">Cantidad de franquicias iniciales que gozan del canon promocional (por defecto 10).</span>
          </div>
          <div>
            <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Canon Promocional Inicial ($ USD/mes):</label>
            <input id="cfgPromoCanon" type="number" min="0" step="1" value="${promoCanon}" style="width:100%;font-size:1.05rem;font-weight:700">
            <span class="mut" style="font-size:.72rem">Tarifa preferencial en dólares para las primeras franquicias registradas.</span>
          </div>
          <div>
            <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Canon Estándar Regular ($ USD/mes):</label>
            <input id="cfgRegularCanon" type="number" min="0" step="1" value="${regularCanon}" style="width:100%;font-size:1.05rem;font-weight:700">
            <span class="mut" style="font-size:.72rem">Tarifa que se aplicará automáticamente a partir de la franquicia N° ${promoQuota + 1}.</span>
          </div>
        </div>
        <div style="display:flex;gap:10px;justify-content:flex-end">
          <button class="g" onclick="dlg.close()">Cancelar</button>
          <button id="btnSaveCanonCfg">💾 Guardar Configuración</button>
        </div>
      `;
      dlg.showModal();

      $('#btnSaveCanonCfg').onclick = async () => {
        const qVal = parseInt($('#cfgPromoQuota').value) || 10;
        const pVal = parseFloat($('#cfgPromoCanon').value) || 10;
        const rVal = parseFloat($('#cfgRegularCanon').value) || 25;
        const newCfg = { promo_quota: qVal, promo_canon: pVal, regular_canon: rVal };
        const { error } = await sb.from('settings').upsert({
          key: 'franquicia_canon_config',
          value: newCfg,
          updated_at: new Date().toISOString()
        });
        if (error) return toast('Error al guardar: ' + error.message);
        S.settings = S.settings || {};
        S.settings.franquicia_canon_config = newCfg;
        toast('¡Parámetros de canon y cupos guardados con éxito!');
        dlg.close();
        EXTRA.franquicias(box);
      };
    };

    // Circular y Documento Editable de Aumento de Canon
    $('#btnAumentoDoc').onclick = async () => {
      let docText = S.settings?.canon_aumento_documento;
      if (!docText) {
        const { data: dData } = await sb.from('settings').select('value').eq('key', 'canon_aumento_documento').maybeSingle();
        docText = dData?.value;
      }
      if (!docText) {
        docText = `# COMUNICADO OFICIAL: AJUSTE Y ACTUALIZACIÓN DEL CANON MENSUAL DE SERVICIO SAAS
Fecha de Emisión: ${new Date().toISOString().slice(0, 10)}
De: Gerencia de Infraestructura y Operaciones - Emprendimiento Gregory Izquierdo SaaS
Para: Red de Franquiciados Digitales Asociados

Estimado(a) Franquiciado(a),

Por medio de la presente comunicación oficial, nos dirigimos a usted para informarle que, en estricto cumplimiento de nuestro compromiso de garantizar la más alta disponibilidad, velocidad y seguridad para sus clientes, el canon mensual de mantenimiento tecnológico será actualizado a partir del próximo ciclo de facturación.

1. JUSTIFICACIÓN TÉCNICA Y MOTIVOS DEL AJUSTE:
- INFRAESTRUCTURA Y SERVIDORES DE ALTA VELOCIDAD:
  Ampliación de capacidad en clústeres de servidores dedicados de baja latencia con respaldo redundante, garantizando un uptime del 99.9% para su tienda web.
- CAPAS AVANZADAS DE SEGURIDAD Y SSL:
  Implementación de cortafuegos de aplicaciones (WAF) contra ataques DDoS, renovación automática de certificados SSL y monitoreo anti-fraude en tiempo real.
- NUEVAS HERRAMIENTAS Y AUTOMATIZACIONES:
  Mejoras en el sistema de cobranza en cuotas, recordatorios de vencimiento por WhatsApp e integración de inteligencia artificial para aumentar sus ventas.
- SOPORTE Y MANTENIMIENTO CONTINUO:
  Atención técnica prioritaria para traslados, reseteos y reactivaciones de incidencias sin costos adicionales por ticket.

2. CONDICIONES Y APLICACIÓN:
- Este ajuste se notifica con el debido preaviso reglamentario para que pueda planificar sus costos operativos con antelación.
- Su próxima factura digital oficial reflejará este importe, manteniendo activas todas las funciones y el subdominio de su tienda web.

Agradecemos profundamente su confianza y le reiteramos nuestro compromiso de seguir impulsando el crecimiento de su negocio digital.

Atentamente,
DIRECCIÓN DE OPERACIONES TECNOLÓGICAS
Gregory Izquierdo SaaS
Contacto Oficial: emprendimientogregoryizquierdo@gmail.com`;
      }

      $('#dlgBody').innerHTML = `
        <h3>📝 Circular Oficial de Aumento de Canon</h3>
        <p class="mut" style="font-size:.8rem;margin:0 0 10px">Redacta y edita el documento oficial con las razones y justificación del aumento del canon a futuro. Quedará guardado en tu sistema y podrás copiarlo para notificar a tus franquiciados.</p>
        <textarea id="txtCanonDoc" rows="16" style="width:100%;font-family:monospace;font-size:.78rem;background:rgba(3,8,18,.9);border:1px solid var(--line);border-radius:10px;padding:12px;color:#c0e0ff;line-height:1.5">${esc(docText)}</textarea>
        <div style="display:flex;gap:10px;margin-top:12px;flex-wrap:wrap">
          <button id="btnSaveCanonDoc" style="flex:1">💾 Guardar Documento Oficial</button>
          <button id="btnCopyCanonDoc" class="g" style="flex:1">📋 Copiar Comunicado</button>
          <button class="g" onclick="dlg.close()">Cerrar</button>
        </div>
      `;
      dlg.showModal();

      $('#btnSaveCanonDoc').onclick = async () => {
        const newText = $('#txtCanonDoc').value;
        const { error } = await sb.from('settings').upsert({
          key: 'canon_aumento_documento',
          value: newText,
          updated_at: new Date().toISOString()
        });
        if (error) return toast('Error al guardar: ' + error.message);
        S.settings = S.settings || {};
        S.settings.canon_aumento_documento = newText;
        toast('¡Documento de circular de aumento guardado con éxito en el sistema!');
      };

      $('#btnCopyCanonDoc').onclick = async () => {
        const text = $('#txtCanonDoc').value;
        await navigator.clipboard.writeText(text);
        toast('¡Circular copiada al portapapeles! Lista para enviar por WhatsApp o correo.');
      };
    };

    // Modificar Canon individual de una franquicia
    box.querySelectorAll('[data-edit-canon]').forEach(btn => {
      btn.onclick = () => {
        const id = btn.dataset.editCanon;
        const cur = Number(btn.dataset.cur || 25).toFixed(2);
        const nom = btn.dataset.nom;
        $('#dlgBody').innerHTML = `
          <h3>💲 Modificar Canon Mensual</h3>
          <p class="mut" style="font-size:.82rem;margin:0 0 12px">Ajusta el monto del canon mensual para la franquicia <b>${esc(nom)}</b>.</p>
          <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Nuevo Canon Mensual ($ USD/mes):</label>
          <input id="inputNewCanon" type="number" step="1" min="0" value="${cur}" style="width:100%;font-size:1.1rem;font-weight:700">
          <div style="display:flex;gap:8px;margin-top:10px;justify-content:flex-end">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnSaveNewCanon">💾 Actualizar Canon</button>
          </div>
        `;
        dlg.showModal();

        $('#btnSaveNewCanon').onclick = async () => {
          const val = parseFloat($('#inputNewCanon').value);
          if (isNaN(val) || val < 0) return toast('Ingresa un monto válido.');
          const { error } = await sb.from('franchises').update({ canon_mensual_usd: val }).eq('id', id);
          if (error) return toast('Error: ' + error.message);
          toast(`Canon de ${nom} actualizado a $${val.toFixed(2)} USD/mes`);
          dlg.close();
          EXTRA.franquicias(box);
        };
      };
    });

    // 1. Visor de Expediente KYC Digital
    box.querySelectorAll('[data-app-kyc]').forEach(btn => {
      btn.onclick = () => {
        const app = apps.find(a => a.id === btn.dataset.appKyc);
        if(!app) return;
        $('#dlgBody').innerHTML = `
          <div style="max-width:680px">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px">
              <span style="font-size:1.4rem">🛡️</span>
              <div>
                <h3 style="margin:0;color:#fff">Expediente de Verificación KYC</h3>
                <span class="mut" style="font-size:.76rem">${esc(app.business_name)} · Titular: <b>${esc(app.owner_name)}</b></span>
              </div>
            </div>
            <div style="background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.1);border-radius:12px;padding:12px;font-size:.82rem;margin-bottom:14px">
              <div>🪪 <b>Documento:</b> ${esc(app.cedula_rif || 'No especificado')}</div>
              <div>📱 <b>Contacto:</b> ${esc(app.phone)} · ${esc(app.email)}</div>
              <div>📍 <b>Ubicación:</b> ${esc(app.ciudad || 'No especificada')}</div>
              ${app.redes_sociales ? `<div>🌐 <b>Redes / Canal:</b> <a href="${esc(app.redes_sociales)}" target="_blank" style="color:var(--c)">${esc(app.redes_sociales)}</a></div>` : ''}
              ${app.notes ? `<div class="mut" style="margin-top:6px;font-size:.76rem"><b>Notas del postulante:</b> ${esc(app.notes)}</div>` : ''}
            </div>

            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:16px">
              <div style="background:#02050b;padding:8px;border-radius:10px;border:1px solid rgba(255,255,255,.08);text-align:center">
                <span style="font-size:.75rem;font-weight:700;color:#94a3b8;display:block;margin-bottom:6px">1. Cédula Frontal</span>
                ${app.doc_frontal_url ? `<img src="${app.doc_frontal_url}" style="width:100%;max-height:160px;object-fit:cover;border-radius:8px;cursor:pointer" onclick="window.open('${app.doc_frontal_url}','_blank')">` : '<span class="mut">No adjuntada</span>'}
              </div>
              <div style="background:#02050b;padding:8px;border-radius:10px;border:1px solid rgba(255,255,255,.08);text-align:center">
                <span style="font-size:.75rem;font-weight:700;color:#94a3b8;display:block;margin-bottom:6px">2. Cédula Reverso</span>
                ${app.doc_reverso_url ? `<img src="${app.doc_reverso_url}" style="width:100%;max-height:160px;object-fit:cover;border-radius:8px;cursor:pointer" onclick="window.open('${app.doc_reverso_url}','_blank')">` : '<span class="mut">No adjuntada</span>'}
              </div>
              <div style="background:#02050b;padding:8px;border-radius:10px;border:1px solid rgba(255,255,255,.08);text-align:center">
                <span style="font-size:.75rem;font-weight:700;color:#94a3b8;display:block;margin-bottom:6px">3. Selfie con Documento (Prueba de vida)</span>
                ${app.selfie_doc_url ? `<img src="${app.selfie_doc_url}" style="width:100%;max-height:160px;object-fit:cover;border-radius:8px;cursor:pointer" onclick="window.open('${app.selfie_doc_url}','_blank')">` : '<span class="mut">No adjuntada</span>'}
              </div>
              <div style="background:#02050b;padding:8px;border-radius:10px;border:1px solid rgba(255,255,255,.08);text-align:center">
                <span style="font-size:.75rem;font-weight:700;color:#94a3b8;display:block;margin-bottom:6px">4. Comprobante Domicilio / Recibo</span>
                ${app.comprobante_domicilio_url ? `<img src="${app.comprobante_domicilio_url}" style="width:100%;max-height:160px;object-fit:cover;border-radius:8px;cursor:pointer" onclick="window.open('${app.comprobante_domicilio_url}','_blank')">` : '<span class="mut">No adjuntada</span>'}
              </div>
            </div>

            <div style="display:flex;gap:10px;justify-content:flex-end">
              <button class="g" onclick="dlg.close()">Cerrar</button>
              <button class="cta" id="btnApproveKycModal">✅ Aprobar KYC y Crear Franquicia</button>
            </div>
          </div>
        `;

        $('#btnApproveKycModal').onclick = () => {
          dlg.close();
          const btnApprove = box.querySelector(`[data-app-approve="${app.id}"]`);
          if(btnApprove) btnApprove.click();
        };

        dlg.showModal();
      };
    });

    // 2. Aprobar KYC y Crear Franquicia Pre-llenada
    box.querySelectorAll('[data-app-approve]').forEach(btn => {
      btn.onclick = () => {
        const app = apps.find(a => a.id === btn.dataset.appApprove);
        if(!app) return;
        $('#btnNewFranq').click();
        setTimeout(() => {
          if($('#fqName')) $('#fqName').value = app.business_name || '';
          if($('#fqSub')) {
            const sub = (app.subdominio_deseado || app.business_name.toLowerCase().replace(/[^a-z0-9]/g, '')).slice(0, 20);
            $('#fqSub').value = sub;
            $('#fqSub').dispatchEvent(new Event('input'));
          }
          if($('#fqOwner')) $('#fqOwner').value = app.owner_name || '';
          if($('#fqDoc')) $('#fqDoc').value = app.cedula_rif || '';
          if($('#fqTel')) $('#fqTel').value = app.phone || '';
          if($('#fqEmail')) $('#fqEmail').value = app.email || '';
          if($('#fqCity')) $('#fqCity').value = app.ciudad || '';
          if($('#fqNotes')) $('#fqNotes').value = `KYC Aprobado de solicitud web. Notas: ${app.notes || 'Ninguna'}`;
        }, 150);
      };
    });

    // 3. Recarga de Billetera Prepago Central (Zero-Stock)
    box.querySelectorAll('[data-fq-wallet]').forEach(btn => {
      btn.onclick = () => {
        const fId = btn.dataset.fqWallet;
        const nom = btn.dataset.nom;
        const saldoAct = parseFloat(btn.dataset.saldo || 0);

        $('#dlgBody').innerHTML = `
          <h3>💎 Billetera Mayorista Prepago Central</h3>
          <p class="mut" style="font-size:.82rem;margin:0 0 14px">
            Acredita saldo en dólares para que la franquicia <b>${esc(nom)}</b> pueda despachar inventario desde la central en modo Zero-Stock.
          </p>

          <div style="background:rgba(0,245,160,.08);border:1px solid rgba(0,245,160,.25);border-radius:12px;padding:12px;margin-bottom:14px">
            <span class="mut" style="font-size:.72rem">Saldo actual en Billetera Central:</span>
            <div style="font-size:1.4rem;font-weight:900;color:#00f5a0">$${saldoAct.toFixed(2)} USD</div>
          </div>

          <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Monto a Acreditar ($ USD):</label>
          <input id="inputWalletAmount" type="number" step="0.50" min="1" placeholder="Ej: 30.00" style="width:100%;font-size:1.1rem;font-weight:700;margin-bottom:10px">

          <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Método y Referencia del Pago recibido:</label>
          <input id="inputWalletRef" placeholder="Ej: Binance USDT - Ref #9837123" style="width:100%;margin-bottom:14px">

          <div style="display:flex;gap:10px;justify-content:flex-end">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnConfirmWalletTopup" style="background:var(--grad);color:#03121c;font-weight:800">
              ✅ Acreditar Saldo en Billetera
            </button>
          </div>
        `;
        dlg.showModal();

        $('#btnConfirmWalletTopup').onclick = async () => {
          const btnSave = $('#btnConfirmWalletTopup');
          const addUsd = parseFloat($('#inputWalletAmount').value);
          const ref = $('#inputWalletRef').value.trim();

          if(isNaN(addUsd) || addUsd <= 0) return toast('Ingresa un monto válido mayor a 0.');
          btnSave.disabled = true;
          btnSave.textContent = '⏳ Acreditando...';

          const newSaldo = saldoAct + addUsd;
          const { error: fErr } = await sb.from('franchises').update({ saldo_billetera_usd: newSaldo }).eq('id', fId);
          if(fErr){
            btnSave.disabled = false;
            return toast('Error al actualizar billetera: ' + fErr.message);
          }

          try {
            await sb.from('franchise_wallet_ledger').insert([{
              franchise_id: fId,
              tipo: 'recarga',
              monto_usd: addUsd,
              saldo_previo_usd: saldoAct,
              saldo_posterior_usd: newSaldo,
              descripcion: `Recarga de saldo mayorista prepago (${nom})`,
              referencia: ref || 'Recarga administrativa'
            }]);
          } catch(errLedger){}

          toast(`¡Saldo acreditado! Nueva billetera: $${newSaldo.toFixed(2)} USD.`);
          dlg.close();
          EXTRA.franquicias(box);
        };
      };
    });

    // 4. Registro de Pago de Canon (Billing Engine)
    box.querySelectorAll('[data-fq-pay-canon]').forEach(btn => {
      btn.onclick = () => {
        const fId = btn.dataset.fqPayCanon;
        const nom = btn.dataset.nom;
        const f = list.find(x => x.id === fId);
        if(!f) return;

        const curCanon = Number(f.canon_mensual_usd || 25);
        const curVenc = f.fecha_vencimiento_canon || new Date().toISOString().slice(0, 10);
        const baseD = new Date(curVenc + 'T12:00:00');
        baseD.setDate(baseD.getDate() + 30);
        const nextVenc = baseD.toISOString().slice(0, 10);

        $('#dlgBody').innerHTML = `
          <h3>💳 Registrar Pago de Canon Mensual</h3>
          <p class="mut" style="font-size:.82rem;margin:0 0 12px">
            Registra la renovación de 30 días para la franquicia <b>${esc(nom)}</b>.
          </p>

          <div style="background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.08);border-radius:12px;padding:12px;font-size:.82rem;line-height:1.6;margin-bottom:14px">
            <div>💵 <b>Monto del Canon:</b> $${curCanon.toFixed(2)} USD</div>
            <div>📅 <b>Vencimiento actual:</b> ${esc(curVenc)}</div>
            <div style="color:#00f5a0"><b>📅 Nuevo vencimiento (+30 días):</b> <b>${nextVenc}</b></div>
          </div>

          <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Método de Cobro y Referencia:</label>
          <input id="inputCanonRef" placeholder="Ej: Pago Móvil BNC - Ref #123456" style="width:100%;margin-bottom:14px">

          <div style="display:flex;gap:10px;justify-content:flex-end">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnConfirmCanonPay" class="cta">
              ✅ Confirmar Pago y Extender 30 Días
            </button>
          </div>
        `;
        dlg.showModal();

        $('#btnConfirmCanonPay').onclick = async () => {
          const btnC = $('#btnConfirmCanonPay');
          btnC.disabled = true;
          btnC.textContent = '⏳ Procesando...';

          const { error: updErr } = await sb.from('franchises').update({
            fecha_vencimiento_canon: nextVenc,
            estado: 'activo'
          }).eq('id', fId);

          if(updErr){
            btnC.disabled = false;
            return toast('Error al actualizar fecha: ' + updErr.message);
          }

          toast(`¡Canon renovado exitosamente para ${nom} hasta el ${nextVenc}!`);
          dlg.close();
          EXTRA.franquicias(box);
        };
      };
    });
  },

  async tarjetas(box) {
    const [{ data: cards, error: cardErr }, { data: custs, error: custErr }] = await Promise.all([
      sb.from('zeny_cards').select('*, customers(id,nombre,email,telefono,codigo_identificacion,es_revendedor,zeny_balance)').order('created_at', { ascending: false }),
      sb.from('customers').select('id,nombre,email,telefono,codigo_identificacion,es_revendedor,limite_credito,zeny_balance').order('creado', { ascending: false })
    ]);

    if (cardErr && (cardErr.message?.includes('schema cache') || cardErr.code === '42P01')) {
      box.innerHTML = `
        <div class="card" style="border:1.5px solid rgba(0,212,255,.4);background:linear-gradient(135deg,rgba(10,26,50,.95),rgba(5,15,30,.98))">
          <h3 style="margin:0 0 8px;color:var(--c)">⚡ Activación de Tarjetas Zeny y Códigos CLT/RVD</h3>
          <p class="mut" style="margin:0 0 14px;font-size:.88rem;line-height:1.5">
            Para habilitar las tarjetas de crédito digitales Zeny y la asignación automática de códigos CLT:001 y RVD:1001, pega y ejecuta el script SQL en Supabase.
          </p>
          <div style="display:flex;gap:10px;flex-wrap:wrap">
            <button id="btnCopyTdcSql" type="button" style="padding:10px 18px">📋 Copiar SQL Migración 11</button>
            <a href="https://supabase.com/dashboard/project/tevjiqnnnjnakftrjgud/sql/new" target="_blank" rel="noopener noreferrer" class="g" style="text-decoration:none;display:inline-flex;align-items:center;padding:10px 18px;border-radius:12px;font-weight:700">
              ↗ Ir a SQL Editor en Supabase
            </a>
          </div>
        </div>
      `;
      $('#btnCopyTdcSql').onclick = async () => {
        const sql = `-- Migracion 11: Códigos de Identificación Únicos (CLT:001 / RVD:1001) y Tarjetas TDC Zeny
alter table customers add column if not exists codigo_identificacion text unique;

create or replace function get_next_customer_code(p_es_revendedor boolean)
returns text language plpgsql security definer set search_path = public as $fn$
declare prefix text; start_num int; candidate int; code_candidate text; exists_code boolean;
begin
  if p_es_revendedor then prefix := 'RVD'; start_num := 1001; else prefix := 'CLT'; start_num := 1; end if;
  candidate := start_num;
  loop
    if p_es_revendedor then code_candidate := prefix || ':' || candidate::text;
    else code_candidate := prefix || ':' || lpad(candidate::text, 3, '0'); end if;
    select exists(select 1 from customers where codigo_identificacion = code_candidate) into exists_code;
    if not exists_code then return code_candidate; end if;
    candidate := candidate + 1;
  end loop;
end;
$fn$;

create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $fn$
declare assigned_code text;
begin
  assigned_code := get_next_customer_code(false);
  insert into customers(id, nombre, email, telefono, codigo_identificacion, es_revendedor)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'nombre'), new.email, coalesce(new.phone, new.raw_user_meta_data->>'telefono'), assigned_code, false)
  on conflict (id) do update set codigo_identificacion = coalesce(customers.codigo_identificacion, assigned_code);
  return new;
end;
$fn$;

do $do$ declare r record; new_code text; begin
  for r in select id, coalesce(es_revendedor, false) as es_revendedor from customers where codigo_identificacion is null order by creado asc loop
    new_code := get_next_customer_code(r.es_revendedor);
    update customers set codigo_identificacion = new_code where id = r.id;
  end loop;
end;
$do$;

create or replace function switch_customer_role(p_customer_id uuid, p_make_reseller boolean)
returns text language plpgsql security definer set search_path = public as $fn$
declare new_code text;
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  new_code := get_next_customer_code(p_make_reseller);
  update customers set es_revendedor = p_make_reseller, codigo_identificacion = new_code where id = p_customer_id;
  return new_code;
end;
$fn$;
grant execute on function switch_customer_role(uuid, boolean) to authenticated;

create table if not exists zeny_cards (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade unique,
  numero_tarjeta text not null unique,
  nombre_titular text not null,
  codigo_activacion text not null,
  fecha_vencimiento text not null default '12/31',
  estado text not null default 'activa' check (estado in ('activa', 'por_activar', 'bloqueada', 'vencida')),
  descuento_porcentaje numeric(5,2) not null default 5.00,
  activada_at timestamptz,
  created_at timestamptz not null default now()
);
alter table zeny_cards enable row level security;
drop policy if exists zeny_cards_user_select on zeny_cards;
create policy zeny_cards_user_select on zeny_cards for select to authenticated using (customer_id = (select auth.uid()) or is_admin());
drop policy if exists zeny_cards_admin_all on zeny_cards;
create policy zeny_cards_admin_all on zeny_cards for all to authenticated using (is_admin()) with check (is_admin());

create or replace function activate_zeny_card(p_numero text, p_codigo text)
returns void language plpgsql security definer set search_path = public as $fn$
declare card zeny_cards;
begin
  if auth.uid() is null then raise exception 'Inicia sesion primero'; end if;
  select * into card from zeny_cards where customer_id = auth.uid() for update;
  if not found then raise exception 'No tienes una tarjeta asignada'; end if;
  if replace(card.numero_tarjeta, ' ', '') <> replace(p_numero, ' ', '') or card.codigo_activacion <> trim(p_codigo) then
    raise exception 'Número o código de activación incorrecto';
  end if;
  update zeny_cards set estado = 'activa', activada_at = coalesce(activada_at, now()) where id = card.id;
end;
$fn$;
grant execute on function activate_zeny_card(text, text) to authenticated;`;
        await navigator.clipboard.writeText(sql);
        toast('¡SQL copiado! Pégalo y ejecútalo en Supabase SQL Editor.');
      };
      return;
    }

    const cardList = cards || [];
    const custList = custs || [];

    box.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:16px">
        <div>
          <h3 style="margin:0 0 4px;font-size:1.2rem">💳 Tarjetas de Crédito Digitales Zeny & Códigos de Usuario</h3>
          <p class="mut" style="margin:0;font-size:.82rem">Emite tarjetas personalizadas (anverso/reverso), cambia roles Cliente ⇄ Revendedor y gestiona saldos Zeny.</p>
        </div>
        <div class="row">
          <button id="btnEmitCard">+ Emitir Tarjeta para Cliente</button>
        </div>
      </div>

      <!-- Resumen de Tarjetas y Usuarios -->
      <div class="grid" style="margin-bottom:18px">
        <div class="card">
          <div class="mut">Tarjetas Emitidas</div>
          <div class="price">${cardList.length}</div>
        </div>
        <div class="card">
          <div class="mut">Tarjetas Activas</div>
          <div class="price" style="color:var(--a)">${cardList.filter(c => c.estado === 'activa').length}</div>
        </div>
        <div class="card">
          <div class="mut">Total Clientes / Revendedores</div>
          <div style="font-size:1.1rem;font-weight:700;color:var(--c);margin-top:6px">
            👤 ${custList.filter(c => !c.es_revendedor).length} Clientes · 🤝 ${custList.filter(c => c.es_revendedor).length} Revendedores
          </div>
        </div>
      </div>

      <!-- Tabla de Tarjetas Emitidas -->
      <h4 style="margin:16px 0 8px">Tarjetas en Circulación</h4>
      <div class="wrap" style="margin-bottom:24px">
        <table>
          <tr>
            <th>Titular / Código</th>
            <th>N° de Tarjeta</th>
            <th>Código Activación</th>
            <th>Vence</th>
            <th>Saldo Zeny</th>
            <th>Estado</th>
            <th>Acciones</th>
          </tr>
          ${cardList.map(c => `
            <tr>
              <td>
                <b>${esc(c.nombre_titular)}</b>
                <span class="mut" style="display:block;font-size:.73rem">
                  ${esc(c.customers?.codigo_identificacion || 'S/C')} · ${esc(c.customers?.email || '')}
                </span>
              </td>
              <td><code style="color:#fde047;font-weight:700">${esc(c.numero_tarjeta)}</code></td>
              <td><span style="font-family:monospace;background:#ffffff;color:#0f172a;padding:2px 6px;border-radius:4px;font-weight:800">${esc(c.codigo_activacion)}</span></td>
              <td>${esc(c.fecha_vencimiento)}</td>
              <td><b style="color:var(--c)">${Number(c.customers?.zeny_balance || 0).toFixed(2)} ZP</b></td>
              <td><span class="pill ${c.estado === 'activa' ? '' : 'off'}">${esc(c.estado)}</span></td>
              <td class="row">
                <button class="g" data-card-preview="${c.id}">👁️ Ver Tarjeta 3D</button>
                <button class="d" data-card-del="${c.id}">Quitar</button>
              </td>
            </tr>
          `).join('') || '<tr><td colspan="7" class="mut empty">No hay tarjetas emitidas aún. Pulsa "+ Emitir Tarjeta" para crear la primera.</td></tr>'}
        </table>
      </div>

      <!-- Tabla de Clientes con Cambio Rápido de Rol (Cliente <-> Revendedor) -->
      <h4 style="margin:16px 0 8px">Gestión de Usuarios y Códigos (CLT:001 ⇄ RVD:1001)</h4>
      <div class="wrap">
        <table>
          <tr>
            <th>Código Único</th>
            <th>Nombre / Email</th>
            <th>Teléfono</th>
            <th>Rol Actual</th>
            <th>Límite Crédito</th>
            <th>Saldo Zeny</th>
            <th>Acciones</th>
          </tr>
          ${custList.map(u => `
            <tr>
              <td><b style="color:var(--c);font-family:monospace">${esc(u.codigo_identificacion || (u.es_revendedor ? 'RVD:1001' : 'CLT:001'))}</b></td>
              <td>
                <b>${esc(u.nombre || 'Sin nombre')}</b>
                <span class="mut" style="display:block;font-size:.73rem">${esc(u.email || '')}</span>
              </td>
              <td>${esc(u.telefono || '—')}</td>
              <td>
                <span class="pill ${u.es_revendedor ? '' : 'off'}" style="background:${u.es_revendedor ? 'rgba(255,183,3,.15)' : 'rgba(0,245,160,.12)'};color:${u.es_revendedor ? '#ffb703' : 'var(--a)'}">
                  ${u.es_revendedor ? '🤝 Revendedor' : '👤 Cliente'}
                </span>
              </td>
              <td><b style="color:var(--c)">$${Number(u.limite_credito != null ? u.limite_credito : 10.00).toFixed(2)} USD</b></td>
              <td>${Number(u.zeny_balance || 0).toFixed(2)} ZP</td>
              <td class="row">
                <button class="g" data-set-credit="${u.id}" data-cur="${u.limite_credito != null ? u.limite_credito : 10}" data-nom="${esc(u.nombre || u.email)}" style="padding:5px 9px;font-size:.76rem" title="Modificar límite de crédito manual">
                  💳 Asignar Límite
                </button>
                <button class="g" data-switch-role="${u.id}" data-to-rev="${!u.es_revendedor}" data-nom="${esc(u.nombre || u.email)}" style="padding:5px 9px;font-size:.76rem">
                  ${u.es_revendedor ? '⬇️ Pasar a Cliente' : '⬆️ Ascender a Revendedor'}
                </button>
              </td>
            </tr>
          `).join('')}
        </table>
      </div>
    `;

    // Modal para Emitir Tarjeta
    $('#btnEmitCard').onclick = () => {
      const options = custList.map(c => `
        <option value="${c.id}" data-name="${esc(c.nombre || c.email)}">
          ${esc(c.nombre || c.email)} (${esc(c.codigo_identificacion || 'S/C')}) - ${c.es_revendedor ? 'Revendedor' : 'Cliente'}
        </option>
      `).join('');

      const genRand = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
      const autoNum = `4${genRand(100, 999)} ${genRand(1000, 9999)} ${genRand(1000, 9999)} ${genRand(1000, 9999)}`;
      const autoCvv = String(genRand(100, 999));
      const expDate = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);
      const autoExp = `${String(expDate.getMonth() + 1).padStart(2, '0')}/${String(expDate.getFullYear()).slice(-2)}`;

      $('#dlgBody').innerHTML = `
        <h3>💳 Emitir Tarjeta de Crédito Digital Zeny</h3>
        <p class="mut" style="font-size:.82rem;margin:0 0 12px">Personaliza la tarjeta con los datos del cliente. Podrá verla en su portal personal.</p>
        <div style="display:flex;flex-direction:column;gap:10px;max-height:65vh;overflow-y:auto;padding-right:4px">
          <label class="mut" style="font-size:.76rem">Selecciona al Cliente:</label>
          <select id="emitCustSelect">${options}</select>

          <label class="mut" style="font-size:.76rem">Nombre y Apellido Impreso en la Tarjeta:</label>
          <input id="emitHolderInput" placeholder="Ej: GREGORY IZQUIERDO" value="${esc(custList[0]?.nombre || 'CLIENTE VIP')}" style="text-transform:uppercase" required>

          <label class="mut" style="font-size:.76rem">Número de Tarjeta (16 dígitos):</label>
          <input id="emitNumInput" value="${autoNum}" style="font-family:monospace;letter-spacing:2px" required>

          <label class="mut" style="font-size:.76rem">Código de Activación (CVV reverso):</label>
          <input id="emitCvvInput" value="${autoCvv}" maxlength="4" style="font-family:monospace;letter-spacing:2px;max-width:140px" required>

          <label class="mut" style="font-size:.76rem">Fecha de Vencimiento (365 días - MM/YY):</label>
          <input id="emitExpInput" value="${autoExp}" maxlength="5" style="font-family:monospace;max-width:140px" required>

          <label class="mut" style="font-size:.76rem">Estado Inicial:</label>
          <select id="emitStateSelect">
            <option value="activa">🟢 Activa para Compras</option>
            <option value="por_activar">🟡 Por Activar (Cliente debe ingresar su código)</option>
          </select>
        </div>
        <button id="btnSaveCard" style="margin-top:14px;width:100%">Emitir y Asignar Tarjeta</button>
      `;

      $('#emitCustSelect').onchange = e => {
        const selOpt = e.target.selectedOptions[0];
        if (selOpt) $('#emitHolderInput').value = selOpt.dataset.name.toUpperCase();
      };

      $('#btnSaveCard').onclick = async () => {
        const btn = $('#btnSaveCard');
        btn.disabled = true;
        const custId = $('#emitCustSelect').value;
        const holder = $('#emitHolderInput').value.trim().toUpperCase();
        const num = $('#emitNumInput').value.trim();
        const cvv = $('#emitCvvInput').value.trim();
        const exp = $('#emitExpInput').value.trim();
        const state = $('#emitStateSelect').value;

        if (!custId || !holder || !num || !cvv || !exp) {
          btn.disabled = false;
          return toast('Por favor completa todos los campos.');
        }

        const { error: insErr } = await sb.from('zeny_cards').upsert({
          customer_id: custId,
          nombre_titular: holder,
          numero_tarjeta: num,
          codigo_activacion: cvv,
          fecha_vencimiento: exp,
          estado: state
        }, { onConflict: 'customer_id' });

        if (insErr) {
          btn.disabled = false;
          return toast(insErr.message);
        }

        dlg.close();
        toast('¡Tarjeta Zeny emitida exitosamente!');
        EXTRA.tarjetas(box);
      };

      dlg.showModal();
    };

    // Previsualizar Tarjeta 3D
    box.querySelectorAll('[data-card-preview]').forEach(btn => {
      btn.onclick = () => {
        const c = cardList.find(x => x.id === btn.dataset.cardPreview);
        if (!c) return;
        $('#dlgBody').innerHTML = `
          <h3>Tarjeta de ${esc(c.nombre_titular)}</h3>
          <p class="mut" style="font-size:.8rem;text-align:center;margin:0 0 10px">Toca la tarjeta para ver el anverso o reverso con su código de activación.</p>
          <div class="zeny-card-stage" id="previewStage" style="margin:0 auto">
            <div class="zeny-card-inner">
              <div class="zeny-card-face zeny-card-front">
                <div class="zeny-card-front-number-box">
                  <div class="zeny-card-number-text">${esc(c.numero_tarjeta)}</div>
                </div>
                <div class="zeny-card-front-expiry-box">
                  <span class="zeny-card-expiry-text">${esc(c.fecha_vencimiento)}</span>
                </div>
                <div class="zeny-card-front-holder-box">
                  <div class="zeny-card-holder-name">${esc(c.nombre_titular)}</div>
                </div>
              </div>
              <div class="zeny-card-face zeny-card-back">
                <div class="zeny-card-magstrip"></div>
                <div class="zeny-card-back-body">
                  <div style="display:flex;justify-content:space-between;align-items:center">
                    <span style="font-size:.68rem;color:#94a3b8">BANDA / CVV</span>
                    <span style="font-size:.68rem;color:#fde047">CÓDIGO SECRETO</span>
                  </div>
                  <div class="zeny-card-cvv-box">
                    <span class="zeny-card-cvv-text">${esc(c.codigo_activacion)}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        `;
        $('#previewStage').onclick = () => $('#previewStage').classList.toggle('flipped');
        dlg.showModal();
      };
    });

    // Eliminar Tarjeta
    box.querySelectorAll('[data-card-del]').forEach(btn => {
      btn.onclick = async () => {
        if (!confirm('¿Eliminar esta tarjeta?')) return;
        await sb.from('zeny_cards').delete().eq('id', btn.dataset.cardDel);
        toast('Tarjeta eliminada.');
        EXTRA.tarjetas(box);
      };
    });

    // Cambiar Rol de Usuario (Cliente ⇄ Revendedor)
    box.querySelectorAll('[data-switch-role]').forEach(btn => {
      btn.onclick = async () => {
        const id = btn.dataset.switchRole;
        const toRev = btn.dataset.toRev === 'true';
        const nom = btn.dataset.nom;
        const msg = toRev 
          ? `¿Ascender a ${nom} como REVENDEDOR MAYORISTA? Se le asignará un código RVD.`
          : `¿Pasar a ${nom} como CLIENTE FINAL? Se le asignará un código CLT.`;
        if (!confirm(msg)) return;

        const { data: newCode, error: swErr } = await sb.rpc('switch_customer_role', {
          p_customer_id: id,
          p_make_reseller: toRev
        });

        if (swErr) return toast(swErr.message);
        toast(`¡Rol actualizado! Nuevo código asignado: ${newCode}`);
        EXTRA.tarjetas(box);
      };
    });

    // Asignar Límite de Crédito Manual (Cliente y Revendedor)
    box.querySelectorAll('[data-set-credit]').forEach(btn => {
      btn.onclick = () => {
        const uid = btn.dataset.setCredit;
        const nom = btn.dataset.nom;
        const cur = Number(btn.dataset.cur || 10).toFixed(2);
        $('#dlgBody').innerHTML = `
          <h3>💳 Asignar Límite de Crédito</h3>
          <p class="mut" style="font-size:.85rem;margin:0 0 14px">
            Establece manualmente la línea de crédito autorizada para <b>${esc(nom)}</b>.
          </p>
          <div style="background:rgba(255,255,255,.04);padding:14px;border-radius:12px;border:1px solid rgba(255,255,255,.1);margin-bottom:14px">
            <div style="display:flex;justify-content:space-between;margin-bottom:8px">
              <span class="mut" style="font-size:.82rem">Límite actual:</span>
              <b style="color:var(--c);font-size:1.1rem">$${cur} USD</b>
            </div>
            <label class="mut" style="font-size:.78rem;display:block;margin-bottom:4px">Nuevo Límite de Crédito ($ USD):</label>
            <input id="inputNewCreditLimit" type="number" step="1" min="0" value="${cur}" style="width:100%;font-size:1.15rem;font-weight:700" placeholder="Ej: 10, 25, 50, 100">
            <div style="display:flex;gap:6px;margin-top:10px;flex-wrap:wrap">
              <button type="button" class="g" style="padding:4px 8px;font-size:.72rem" onclick="$('#inputNewCreditLimit').value=10">$10 (Base)</button>
              <button type="button" class="g" style="padding:4px 8px;font-size:.72rem" onclick="$('#inputNewCreditLimit').value=20">$20</button>
              <button type="button" class="g" style="padding:4px 8px;font-size:.72rem" onclick="$('#inputNewCreditLimit').value=30">$30</button>
              <button type="button" class="g" style="padding:4px 8px;font-size:.72rem" onclick="$('#inputNewCreditLimit').value=50">$50</button>
              <button type="button" class="g" style="padding:4px 8px;font-size:.72rem" onclick="$('#inputNewCreditLimit').value=100">$100</button>
            </div>
          </div>
          <div style="display:flex;gap:10px;justify-content:flex-end">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnSaveCreditLimit">💾 Guardar Límite</button>
          </div>
        `;
        dlg.showModal();
        $('#btnSaveCreditLimit').onclick = async () => {
          const val = parseFloat($('#inputNewCreditLimit').value);
          if (isNaN(val) || val < 0) return toast('Ingresa un monto válido mayor o igual a 0');
          const { error: err } = await sb.from('customers').update({ limite_credito: val }).eq('id', uid);
          if (err) return toast('Error al actualizar límite: ' + err.message);
          toast(`Límite de crédito asignado a $${val.toFixed(2)} USD para ${nom}`);
          dlg.close();
          EXTRA.tarjetas(box);
        };
      };
    });
  },

  async recargas247(box) {
    box.innerHTML = '<div style="text-align:center;padding:30px"><p class="mut">Cargando Red de Recargas247…</p></div>';

    let subTab = box._r247Tab || 'abonos';

    let puntos = [];
    let abonos = [];
    let tableError = false;

    try {
      const [rPuntos, rAbonos] = await Promise.all([
        sb.from('recargas_puntos').select('*').order('created_at', { ascending: false }),
        sb.from('recargas_abonos').select('*, recargas_puntos(nombre, apellido, telefono, nombre_taquilla)').order('created_at', { ascending: false })
      ]);

      if (rPuntos.error && rPuntos.error.code === 'PGRST205') tableError = true;
      if (rAbonos.error && rAbonos.error.code === 'PGRST205') tableError = true;

      puntos = rPuntos.data || [];
      abonos = rAbonos.data || [];
    } catch (e) {
      console.warn('Tablas recargas247 no creadas aún:', e);
      tableError = true;
    }

    const todayStr = new Date().toISOString().slice(0, 10);

    // Métricas
    const taquillasActivas = puntos.filter(p => p.estado === 'activo').length;
    const canonesProyectadosUsd = puntos.filter(p => p.estado === 'activo').reduce((acc, p) => acc + Number(p.canon_mensual_usd || 0), 0);
    const abonosPendientes = abonos.filter(a => a.estado === 'pendiente');
    const totalGananciaComisiones = abonos.filter(a => a.estado === 'conciliado_abonado').reduce((acc, a) => acc + Number(a.ganancia_gregory_usd || 0), 0);

    const render = () => {
      box._r247Tab = subTab;
      box.innerHTML = `
        <div style="display:flex;justify-content:space-between;align-items:flex-start;flex-wrap:wrap;gap:12px;margin-bottom:18px">
          <div>
            <h2 style="margin:0 0 6px;display:flex;align-items:center;gap:8px">
              <span>📱 Red de Distribuidores de Recargas</span>
              <span class="pill" style="font-size:.72rem;background:rgba(56,189,248,.15);color:#38bdf8;border:1px solid rgba(56,189,248,.3)">Recargas247.net</span>
            </h2>
            <p class="mut" style="font-size:.84rem;margin:0;max-width:680px">
              Control maestro de revendedor: da de alta nuevas taquillas en tu red, supervisa el cobro de cánones mensuales y concilia compras de saldo obteniendo tu comisión de distribuidor.
            </p>
          </div>
          <div style="display:flex;gap:8px;flex-wrap:wrap">
            <a href="https://www.recargas247.net" target="_blank" rel="noopener noreferrer" class="g" style="display:inline-flex;align-items:center;gap:6px;padding:8px 14px;border-radius:10px;text-decoration:none;font-weight:700;border:1px solid rgba(56,189,248,.4);color:#38bdf8">
              <span>🌐 Abrir Panel Recargas247.net</span>
              <svg style="width:14px;height:14px" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
            </a>
            <button id="btnNewTaquilla" style="background:var(--grad);color:#03121c;font-weight:800;border:none;border-radius:10px;padding:8px 14px;cursor:pointer">
              ➕ Registrar Nueva Taquilla
            </button>
            <button id="btnNewAbono" class="g" style="padding:8px 14px;border-radius:10px;cursor:pointer">
              💰 Cargar Solicitud de Abono
            </button>
          </div>
        </div>

        ${tableError ? `
          <div style="margin-bottom:18px;padding:14px 18px;background:rgba(234,179,8,.12);border:1.5px solid rgba(234,179,8,.4);border-radius:14px">
            <div style="display:flex;align-items:center;gap:10px;margin-bottom:6px">
              <span style="font-size:1.3rem">⚠️</span>
              <b style="color:#fde047;font-size:.92rem">Tablas de Base de Datos no detectadas</b>
            </div>
            <p class="mut" style="font-size:.82rem;margin:0 0 10px;color:#fef08a">
              Para comenzar a guardar taquillas y abonos en Supabase, ejecuta el script <b>supabase/migracion_20_gaming_y_recargas247.sql</b> en tu panel SQL de Supabase.
            </p>
          </div>
        ` : ''}

        <!-- Tarjetas de Métricas -->
        <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:14px;margin-bottom:20px">
          <div class="card" style="padding:16px">
            <div class="mut" style="font-size:.78rem">🏪 Taquillas en Red</div>
            <div class="price" style="font-size:1.75rem;margin:6px 0 2px">${taquillasActivas} <span style="font-size:.9rem;color:var(--mut)">/ ${puntos.length}</span></div>
            <div class="mut" style="font-size:.74rem">Puntos de recarga activos</div>
          </div>
          <div class="card" style="padding:16px">
            <div class="mut" style="font-size:.78rem">💵 Cánones Mensuales</div>
            <div class="price" style="font-size:1.75rem;margin:6px 0 2px">$${canonesProyectadosUsd.toFixed(2)} <span style="font-size:.85rem;color:var(--mut)">USD/mes</span></div>
            <div class="mut" style="font-size:.74rem">Mantenimiento de plataforma</div>
          </div>
          <div class="card" style="padding:16px">
            <div class="mut" style="font-size:.78rem">⏳ Abonos por Conciliar</div>
            <div class="price" style="font-size:1.75rem;margin:6px 0 2px;color:${abonosPendientes.length ? '#fde047' : 'var(--tx)'}">${abonosPendientes.length}</div>
            <div class="mut" style="font-size:.74rem">Depósitos de saldo pendientes</div>
          </div>
          <div class="card" style="padding:16px">
            <div class="mut" style="font-size:.78rem">💰 Ganancia Comisiones</div>
            <div class="price" style="font-size:1.75rem;margin:6px 0 2px;color:var(--c)">$${totalGananciaComisiones.toFixed(2)} <span style="font-size:.85rem;color:var(--mut)">USD</span></div>
            <div class="mut" style="font-size:.74rem">Comisión retenida en depósitos</div>
          </div>
        </div>

        <!-- Pestañas de sub-módulos -->
        <div style="display:flex;gap:8px;border-bottom:1px solid var(--line);margin-bottom:16px">
          <button id="tabAbonos" class="${subTab === 'abonos' ? '' : 'g'}" style="border-radius:10px 10px 0 0;padding:10px 18px;font-size:.84rem;font-weight:700;border-bottom:none">
            📥 Solicitudes de Abono de Saldo (${abonos.length})
          </button>
          <button id="tabTaquillas" class="${subTab === 'taquillas' ? '' : 'g'}" style="border-radius:10px 10px 0 0;padding:10px 18px;font-size:.84rem;font-weight:700;border-bottom:none">
            🏪 Directorio de Taquillas & Cánones (${puntos.length})
          </button>
        </div>

        <!-- Vista Pestaña 1: Abonos y Depósitos -->
        ${subTab === 'abonos' ? `
          ${abonos.length ? `
            <div class="wrap">
              <table>
                <tr>
                  <th>Taquilla / Titular</th>
                  <th>Depósito USD</th>
                  <th>Comisión Gregory</th>
                  <th>Saldo Acreditar 247</th>
                  <th>Método / Ref</th>
                  <th>Estado</th>
                  <th>Fecha</th>
                  <th>Acción</th>
                </tr>
                ${abonos.map(a => {
                  const taqNom = a.recargas_puntos?.nombre_taquilla || 'Taquilla';
                  const titNom = `${a.recargas_puntos?.nombre || ''} ${a.recargas_puntos?.apellido || ''}`.trim() || 'Titular';
                  const tel = a.recargas_puntos?.telefono || '';
                  const stPill = a.estado === 'conciliado_abonado' 
                    ? '<span class="pill" style="font-size:.7rem;background:rgba(0,245,160,.15);color:#00f5a0">✅ Conciliado</span>'
                    : (a.estado === 'pendiente' 
                      ? '<span class="pill" style="font-size:.7rem;background:rgba(234,179,8,.15);color:#fde047">⏳ Pendiente</span>'
                      : '<span class="pill off" style="font-size:.7rem">❌ Rechazado</span>');

                  return `
                    <tr>
                      <td>
                        <b>${esc(taqNom)}</b>
                        <div style="font-size:.74rem;color:var(--mut)">${esc(titNom)}</div>
                      </td>
                      <td><b>$${Number(a.monto_depositado_usd).toFixed(2)}</b></td>
                      <td>
                        <span style="color:var(--c);font-weight:700">+$${Number(a.ganancia_gregory_usd || 0).toFixed(2)}</span>
                        <div style="font-size:.72rem;color:var(--mut)">(${Number(a.comision_distribuidor_pct || 3)}%)</div>
                      </td>
                      <td>
                        <b style="color:#38bdf8;font-size:.95rem">$${Number(a.saldo_acreditado_usd || (a.monto_depositado_usd - (a.ganancia_gregory_usd||0))).toFixed(2)}</b>
                      </td>
                      <td>
                        <div style="font-size:.78rem"><b>${esc(a.metodo_pago)}</b></div>
                        <div style="font-size:.72rem;color:var(--mut)">Ref: <code>${esc(a.referencia)}</code></div>
                      </td>
                      <td>${stPill}</td>
                      <td style="font-size:.74rem;color:var(--mut)">${a.created_at?.slice(0, 10)}</td>
                      <td>
                        ${a.estado === 'pendiente' ? `
                          <div style="display:flex;gap:4px">
                            <button data-abono-ok="${a.id}" data-ptoid="${a.punto_id}" data-monto="${a.monto_depositado_usd}" data-saldo="${a.saldo_acreditado_usd}" data-gan="${a.ganancia_gregory_usd}" data-nom="${esc(titNom)}" data-taq="${esc(taqNom)}" data-tel="${esc(tel)}" style="padding:4px 10px;font-size:.75rem">
                              ✅ Conciliar
                            </button>
                            <button class="g" data-abono-rej="${a.id}" style="padding:4px 8px;font-size:.75rem">
                              ✕
                            </button>
                          </div>
                        ` : (a.estado === 'conciliado_abonado' && tel ? `
                          <button class="g" data-abono-wa="${a.id}" data-nom="${esc(titNom)}" data-taq="${esc(taqNom)}" data-tel="${esc(tel)}" data-saldo="${a.saldo_acreditado_usd}" style="padding:4px 8px;font-size:.72rem">
                            💬 Avisar WA
                          </button>
                        ` : '<span class="mut" style="font-size:.75rem">—</span>')}
                      </td>
                    </tr>
                  `;
                }).join('')}
              </table>
            </div>
          ` : '<p class="mut empty">No hay solicitudes de abono registradas aún. Puedes cargar depósitos de saldo usando el botón superior.</p>'}
        ` : `
          <!-- Vista Pestaña 2: Directorio de Taquillas & Cánones -->
          ${puntos.length ? `
            <div class="wrap">
              <table>
                <tr>
                  <th>Taquilla</th>
                  <th>Titular & Contacto</th>
                  <th>Ubicación</th>
                  <th>Canon Mensual</th>
                  <th>Vencimiento Canon</th>
                  <th>Comisión</th>
                  <th>Saldo Red</th>
                  <th>Acción</th>
                </tr>
                ${puntos.map(p => {
                  const isMora = p.fecha_vencimiento_canon < todayStr;
                  const diffDays = Math.ceil((new Date(p.fecha_vencimiento_canon) - new Date(todayStr)) / 86400000);
                  const isSoon = !isMora && diffDays <= 3;
                  
                  const duePill = isMora 
                    ? `<span class="pill off" style="font-size:.7rem">⚠️ Vencido (${esc(p.fecha_vencimiento_canon)})</span>`
                    : (isSoon 
                      ? `<span class="pill" style="font-size:.7rem;background:rgba(234,179,8,.15);color:#fde047">⏳ Vence en ${diffDays}d (${esc(p.fecha_vencimiento_canon)})</span>`
                      : `<span class="pill" style="font-size:.7rem;background:rgba(0,245,160,.15);color:#00f5a0">✅ Al día (${esc(p.fecha_vencimiento_canon)})</span>`);

                  return `
                    <tr>
                      <td>
                        <b>${esc(p.nombre_taquilla)}</b>
                        <div style="font-size:.72rem;color:var(--mut)">Estado: <b style="color:${p.estado === 'activo' ? '#00f5a0' : '#ef4444'}">${esc(p.estado)}</b></div>
                      </td>
                      <td>
                        <div><b>${esc(p.nombre)} ${esc(p.apellido)}</b></div>
                        <div style="font-size:.74rem;color:var(--mut)">${esc(p.email)}</div>
                        <div style="font-size:.74rem;color:#38bdf8">${esc(p.telefono)}</div>
                      </td>
                      <td>
                        <div style="font-size:.78rem">${esc(p.estado_region)}</div>
                        <div style="font-size:.72rem;color:var(--mut)">${esc(p.pais)}</div>
                      </td>
                      <td><b>$${Number(p.canon_mensual_usd).toFixed(2)}</b> <span style="font-size:.72rem;color:var(--mut)">/mes</span></td>
                      <td>${duePill}</td>
                      <td><b>${Number(p.comision_deposito_pct || 3)}%</b></td>
                      <td><b style="color:var(--c)">$${Number(p.saldo_actual_247 || 0).toFixed(2)}</b></td>
                      <td>
                        <div style="display:flex;gap:4px;flex-wrap:wrap">
                          <button class="g" data-wa-canon="${p.id}" data-nom="${esc(p.nombre)}" data-taq="${esc(p.nombre_taquilla)}" data-tel="${esc(p.telefono)}" data-canon="${p.canon_mensual_usd}" data-vence="${p.fecha_vencimiento_canon}" title="Cobrar canon por WhatsApp" style="padding:4px 8px;font-size:.72rem">
                            💬 Cobrar WA
                          </button>
                          <button class="g" data-renovar-canon="${p.id}" data-taq="${esc(p.nombre_taquilla)}" title="Renovar canon por 30 días" style="padding:4px 8px;font-size:.72rem">
                            📅 Renovar 30d
                          </button>
                          <button class="g" data-ver-clave="${p.id}" data-nom="${esc(p.nombre)}" data-mail="${esc(p.email)}" data-clave="${esc(p.clave_acceso || 'No registrada')}" style="padding:4px 8px;font-size:.72rem" title="Ver credenciales">
                            🔑 Ver
                          </button>
                        </div>
                      </td>
                    </tr>
                  `;
                }).join('')}
              </table>
            </div>
          ` : '<p class="mut empty">No hay taquillas registradas todavía. Pulsa el botón "Registrar Nueva Taquilla" para agregar la primera.</p>'}
        `}
      `;

      // Eventos de Pestañas
      const tabA = $('#tabAbonos');
      const tabT = $('#tabTaquillas');
      if (tabA) tabA.onclick = () => { subTab = 'abonos'; render(); };
      if (tabT) tabT.onclick = () => { subTab = 'taquillas'; render(); };

      // Modal: REGISTRAR NUEVA TAQUILLA (Exactos 8 campos oficiales pedidos por Gregory)
      const btnNewTaq = $('#btnNewTaquilla');
      if (btnNewTaq) btnNewTaq.onclick = () => {
        $('#dlgBody').innerHTML = `
          <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px">
            <span style="font-size:1.4rem">🏪</span>
            <div>
              <h3 style="margin:0">REGISTRAR NUEVA TAQUILLA</h3>
              <p class="mut" style="font-size:.78rem;margin:2px 0 0">Ingrese los datos del titular de la nueva taquilla en Recargas247.</p>
            </div>
          </div>
          
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:12px">
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Nombre *</label>
              <input id="taqNombre" placeholder="Ej: Pedro" required>
            </div>
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Apellido *</label>
              <input id="taqApellido" placeholder="Ej: Perez" required>
            </div>
            <div style="grid-column:1/-1">
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Email *</label>
              <input id="taqEmail" type="email" placeholder="correo@ejemplo.com" required>
            </div>
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Contraseña *</label>
              <input id="taqClave" type="password" placeholder="Mínimo 6 caracteres" required>
            </div>
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Confirmar contraseña *</label>
              <input id="taqClaveConf" type="password" placeholder="Repite la contraseña" required>
            </div>
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">País *</label>
              <input id="taqPais" value="Venezuela" required>
            </div>
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Estado *</label>
              <input id="taqEstado" placeholder="Ej: Miranda / Distrito Capital" value="Distrito Capital" required>
            </div>
            <div style="grid-column:1/-1">
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Teléfono * (Ej: 584126665544)</label>
              <input id="taqTelefono" placeholder="584126665544" required>
            </div>
            <div style="grid-column:1/-1">
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Nombre de la Taquilla (Punto Comercial)</label>
              <input id="taqNombreComercial" placeholder="Ej: Bodega San Juan / Inversiones 2026" required>
            </div>
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Canon Mensual ($ USD)</label>
              <input id="taqCanon" type="number" step="0.5" value="5.00" required>
            </div>
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Comisión sobre Depósito (%)</label>
              <input id="taqComision" type="number" step="0.1" value="3.00" required>
            </div>
          </div>

          <div style="margin-top:16px;display:flex;gap:8px;justify-content:flex-end">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnSaveTaquilla" style="background:var(--grad);color:#03121c;font-weight:800;border:none">
              Guardar y Crear Taquilla
            </button>
          </div>
        `;
        dlg.showModal();

        $('#btnSaveTaquilla').onclick = async () => {
          const btn = $('#btnSaveTaquilla');
          btn.disabled = true;

          const nom = $('#taqNombre').value.trim();
          const ape = $('#taqApellido').value.trim();
          const mail = $('#taqEmail').value.trim().toLowerCase();
          const pass = $('#taqClave').value;
          const passConf = $('#taqClaveConf').value;
          const pais = $('#taqPais').value.trim() || 'Venezuela';
          const est = $('#taqEstado').value.trim() || 'Distrito Capital';
          const tel = $('#taqTelefono').value.replace(/\D/g, '');
          const nomCom = $('#taqNombreComercial').value.trim() || `Taquilla ${nom}`;
          const canon = parseFloat($('#taqCanon').value) || 5.00;
          const comPct = parseFloat($('#taqComision').value) || 3.00;

          if (!nom || !ape || !mail || !pass || !passConf || !tel) {
            btn.disabled = false;
            return toast('Por favor completa todos los campos obligatorios (*).');
          }

          if (pass !== passConf) {
            btn.disabled = false;
            return toast('Las contraseñas no coinciden. Verifícalas.');
          }

          if (pass.length < 6) {
            btn.disabled = false;
            return toast('La contraseña debe tener al menos 6 caracteres.');
          }

          const { data: newPt, error } = await sb.from('recargas_puntos').insert({
            nombre: nom,
            apellido: ape,
            email: mail,
            clave_acceso: pass,
            pais: pais,
            estado_region: est,
            telefono: tel,
            nombre_taquilla: nomCom,
            canon_mensual_usd: canon,
            comision_deposito_pct: comPct,
            fecha_vencimiento_canon: new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10),
            estado: 'activo'
          }).select().single();

          if (error) {
            btn.disabled = false;
            return toast('Error al registrar taquilla: ' + error.message);
          }

          fetch('/api/notify-event', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              type: 'solicitud_taquilla',
              data: {
                nombre_punto: nomCom,
                titular: `${nom} ${ape}`,
                telefono: tel,
                ubicacion: `${est}, ${pais}`,
                usuario_247: mail,
                canon_usd: canon
              }
            })
          }).catch(()=>{});

          dlg.close();

          const waMsg = encodeURIComponent(
            `🎉 ¡Bienvenido a nuestra Red de Puntos de Recargas247!\n\n` +
            `*Titular:* ${nom} ${ape}\n` +
            `*Punto / Taquilla:* ${nomCom}\n` +
            `*Panel Oficial:* https://www.recargas247.net\n` +
            `*Usuario / Email:* ${mail}\n` +
            `*Contraseña de acceso:* ${pass}\n\n` +
            `*Condiciones de tu red:*\n` +
            `• Canon mensual de mantenimiento: $${canon.toFixed(2)} USD\n` +
            `• Comisión sobre compras de saldo: ${comPct}%\n\n` +
            `Ya puedes acceder a la plataforma para comenzar a recargar. ¡Mucho éxito en tus ventas!`
          );

          $('#dlgBody').innerHTML = `
            <div style="text-align:center;padding:10px 0">
              <span style="font-size:2.5rem">🎉</span>
              <h3 style="margin:10px 0 4px">¡Taquilla Creada Exitosamente!</h3>
              <p class="mut" style="font-size:.85rem;margin:0 0 16px">
                Se guardó <b>${esc(nomCom)}</b> (${esc(nom)} ${esc(ape)}) en tu base de datos.
              </p>
              
              <div style="display:flex;flex-direction:column;gap:10px;max-width:340px;margin:0 auto">
                <a href="https://wa.me/${tel}?text=${waMsg}" target="_blank" rel="noopener noreferrer" style="background:#25D366;color:#fff;padding:12px;border-radius:12px;text-decoration:none;font-weight:800;display:flex;align-items:center;justify-content:center;gap:8px">
                  <span>💬 Enviar Accesos por WhatsApp</span>
                </a>
                <a href="https://www.recargas247.net" target="_blank" rel="noopener noreferrer" class="g" style="padding:10px;border-radius:12px;text-decoration:none;font-weight:700;display:flex;align-items:center;justify-content:center;gap:6px">
                  <span>🌐 Abrir Recargas247.net para validar</span>
                </a>
                <button class="g" onclick="dlg.close()">Cerrar</button>
              </div>
            </div>
          `;
          dlg.showModal();
          EXTRA.recargas247(box);
        };
      };

      // Modal: CARGAR SOLICITUD DE ABONO DE SALDO
      const btnNewAb = $('#btnNewAbono');
      if (btnNewAb) btnNewAb.onclick = () => {
        if (!puntos.length) {
          return toast('Primero debes registrar al menos una taquilla para cargar abonos.');
        }

        const ptoOptions = puntos.map(p => `<option value="${p.id}" data-pct="${p.comision_deposito_pct || 3}" data-nom="${esc(p.nombre_taquilla)}">${esc(p.nombre_taquilla)} (${esc(p.nombre)} ${esc(p.apellido)})</option>`).join('');

        $('#dlgBody').innerHTML = `
          <h3>Cargar Solicitud de Abono de Saldo</h3>
          <p class="mut" style="font-size:.8rem;margin:0 0 14px">Registra un depósito solicitado por una taquilla. El sistema calculará tu ganancia por comisión automáticamente.</p>

          <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Seleccionar Taquilla *</label>
          <select id="abPuntoSelect" style="margin-bottom:10px">${ptoOptions}</select>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:10px">
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Monto Depositado ($ USD) *</label>
              <input id="abMontoUsd" type="number" step="0.5" placeholder="Ej: 50.00" value="50.00" required>
            </div>
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">% Comisión Distribuidor</label>
              <input id="abComPct" type="number" step="0.1" value="${puntos[0]?.comision_deposito_pct || 3.00}" required>
            </div>
          </div>

          <div style="background:rgba(56,189,248,.08);padding:10px 14px;border-radius:10px;border:1px solid rgba(56,189,248,.25);margin-bottom:12px">
            <div style="display:flex;justify-content:space-between;margin-bottom:4px;font-size:.82rem">
              <span>Ganancia para ti (Comisión):</span>
              <b id="abGananciaText" style="color:var(--c)">$1.50 USD</b>
            </div>
            <div style="display:flex;justify-content:space-between;font-size:.84rem">
              <span>Saldo a Acreditar en Recargas247:</span>
              <b id="abSaldoText" style="color:#38bdf8;font-size:1.05rem">$48.50 USD</b>
            </div>
          </div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:10px">
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Método de Pago *</label>
              <select id="abMetodo">
                <option value="Pago Móvil">Pago Móvil</option>
                <option value="Binance USDT">Binance USDT</option>
                <option value="Transferencia Bancaria">Transferencia Bancaria</option>
                <option value="Billetera Zeny">Billetera Zeny</option>
              </select>
            </div>
            <div>
              <label class="mut" style="font-size:.76rem;display:block;margin-bottom:3px">Referencia Bancaria *</label>
              <input id="abRef" placeholder="Ej: 8 dígitos comprobante" required>
            </div>
          </div>

          <div style="margin-top:16px;display:flex;gap:8px;justify-content:flex-end">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnSaveAbono" style="background:var(--grad);color:#03121c;font-weight:800;border:none">
              Registrar Abono
            </button>
          </div>
        `;
        dlg.showModal();

        const updateCalc = () => {
          const m = parseFloat($('#abMontoUsd').value) || 0;
          const p = parseFloat($('#abComPct').value) || 0;
          const gan = Math.round((m * (p / 100)) * 100) / 100;
          const sal = Math.round((m - gan) * 100) / 100;
          $('#abGananciaText').textContent = `$${gan.toFixed(2)} USD`;
          $('#abSaldoText').textContent = `$${sal.toFixed(2)} USD`;
        };

        $('#abMontoUsd').oninput = updateCalc;
        $('#abComPct').oninput = updateCalc;
        $('#abPuntoSelect').onchange = () => {
          const opt = $('#abPuntoSelect').selectedOptions[0];
          if (opt && opt.dataset.pct) {
            $('#abComPct').value = opt.dataset.pct;
            updateCalc();
          }
        };

        $('#btnSaveAbono').onclick = async () => {
          const btn = $('#btnSaveAbono');
          btn.disabled = true;

          const ptoId = $('#abPuntoSelect').value;
          const mUsd = parseFloat($('#abMontoUsd').value) || 0;
          const cPct = parseFloat($('#abComPct').value) || 0;
          const met = $('#abMetodo').value;
          const ref = $('#abRef').value.trim();

          if (mUsd <= 0 || !ref) {
            btn.disabled = false;
            return toast('Ingresa un monto válido y la referencia del depósito.');
          }

          const gan = Math.round((mUsd * (cPct / 100)) * 100) / 100;
          const sal = Math.round((mUsd - gan) * 100) / 100;

          const { error: abErr } = await sb.from('recargas_abonos').insert({
            punto_id: ptoId,
            monto_depositado_usd: mUsd,
            comision_distribuidor_pct: cPct,
            ganancia_gregory_usd: gan,
            saldo_acreditado_usd: sal,
            metodo_pago: met,
            referencia: ref,
            estado: 'pendiente'
          });

          if (abErr) {
            btn.disabled = false;
            return toast('Error al registrar abono: ' + abErr.message);
          }

          dlg.close();
          toast('Solicitud de abono registrada con éxito.');
          EXTRA.recargas247(box);
        };
      };

      // Acciones de Abono: CONCILIAR Y ACREDITAR
      box.querySelectorAll('[data-abono-ok]').forEach(btn => {
        btn.onclick = async () => {
          const abId = btn.dataset.abonoOk;
          const ptoId = btn.dataset.ptoid;
          const monto = parseFloat(btn.dataset.monto);
          const saldo = parseFloat(btn.dataset.saldo);
          const nom = btn.dataset.nom;
          const taq = btn.dataset.taq;
          const tel = btn.dataset.tel;

          if (!confirm(`¿Confirmas la conciliación del abono de $${monto.toFixed(2)} USD para la taquilla "${taq}"? Se le acreditarán $${saldo.toFixed(2)} USD en Recargas247.`)) {
            return;
          }

          btn.disabled = true;
          const { error: updErr } = await sb.from('recargas_abonos').update({
            estado: 'conciliado_abonado',
            abonado_at: new Date().toISOString()
          }).eq('id', abId);

          if (updErr) {
            btn.disabled = false;
            return toast('Error al conciliar abono: ' + updErr.message);
          }

          if (ptoId) {
            const pto = puntos.find(x => x.id === ptoId);
            const curSaldo = Number(pto?.saldo_actual_247 || 0);
            try {
              await sb.from('recargas_puntos').update({
                saldo_actual_247: Math.round((curSaldo + saldo) * 100) / 100,
                updated_at: new Date().toISOString()
              }).eq('id', ptoId);
            } catch(e){}
          }

          toast(`¡Abono conciliado con éxito para ${taq}!`);

          if (tel) {
            const waText = encodeURIComponent(
              `✅ ¡Tu compra de saldo ha sido conciliada exitosamente!\n\n` +
              `*Taquilla:* ${taq}\n` +
              `*Monto pagado:* $${monto.toFixed(2)} USD\n` +
              `*Saldo acreditado en Recargas247:* $${saldo.toFixed(2)} USD\n\n` +
              `Ya tienes tus fondos disponibles en https://www.recargas247.net para seguir recargando. ¡Gracias por tu confianza!`
            );
            window.open(`https://wa.me/${tel}?text=${waText}`, '_blank');
          }

          EXTRA.recargas247(box);
        };
      });

      // Acciones de Abono: RECHAZAR
      box.querySelectorAll('[data-abono-rej]').forEach(btn => {
        btn.onclick = async () => {
          const abId = btn.dataset.abonoRej;
          if (!confirm('¿Deseas rechazar esta solicitud de abono?')) return;
          await sb.from('recargas_abonos').update({ estado: 'rechazado' }).eq('id', abId);
          toast('Abono marcado como rechazado.');
          EXTRA.recargas247(box);
        };
      });

      // Acciones de Abono: AVISO POR WHATSAPP
      box.querySelectorAll('[data-abono-wa]').forEach(btn => {
        btn.onclick = () => {
          const tel = btn.dataset.tel;
          const taq = btn.dataset.taq;
          const saldo = btn.dataset.saldo;
          const waText = `✅ ¡Hola! Te confirmamos que tu saldo de *$${saldo} USD* se encuentra disponible y activo en tu taquilla *${taq}* en https://www.recargas247.net. ¡Éxitos en tus ventas!`;
          openWhatsApp(tel, waText);
        };
      });

      // Acciones de Taquillas: COBRAR CANON WA
      box.querySelectorAll('[data-wa-canon]').forEach(btn => {
        btn.onclick = () => {
          const tel = btn.dataset.tel;
          const nom = btn.dataset.nom;
          const taq = btn.dataset.taq;
          const canon = btn.dataset.canon;
          const vence = btn.dataset.vence;

          const msg = `👋 Hola ${nom}, te saludamos de la administración.\n\n` +
            `Te recordamos que el canon mensual de mantenimiento para tu punto de recarga *${taq}* ($${Number(canon).toFixed(2)} USD) vence el *${vence}*.\n\n` +
            `Por favor remítenos tu comprobante de pago por esta vía para mantener tu taquilla operativa en nuestra red de https://www.recargas247.net.\n\n` +
            `¡Muchas gracias y feliz jornada!`;
          openWhatsApp(tel, msg);
        };
      });

      // Acciones de Taquillas: RENOVAR CANON 30 DÍAS
      box.querySelectorAll('[data-renovar-canon]').forEach(btn => {
        btn.onclick = async () => {
          const pId = btn.dataset.renovarCanon;
          const taq = btn.dataset.taq;
          const nextDate = new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10);
          if (!confirm(`¿Renovar por 30 días el canon de la taquilla "${taq}" hasta el ${nextDate}?`)) return;

          const { error } = await sb.from('recargas_puntos').update({
            fecha_vencimiento_canon: nextDate,
            estado: 'activo',
            updated_at: new Date().toISOString()
          }).eq('id', pId);

          if (error) return toast(error.message);
          toast(`Canon de ${taq} renovado hasta el ${nextDate}.`);
          EXTRA.recargas247(box);
        };
      });

      // Acciones de Taquillas: VER CREDENCIALES
      box.querySelectorAll('[data-ver-clave]').forEach(btn => {
        btn.onclick = () => {
          $('#dlgBody').innerHTML = `
            <h3>Credenciales de la Taquilla</h3>
            <div style="background:rgba(255,255,255,.05);padding:14px;border-radius:12px;margin:12px 0">
              <div style="margin-bottom:8px"><b>Titular:</b> ${esc(btn.dataset.nom)}</div>
              <div style="margin-bottom:8px"><b>Email / Usuario:</b> <code>${esc(btn.dataset.mail)}</code></div>
              <div><b>Contraseña registrada:</b> <code>${esc(btn.dataset.clave)}</code></div>
            </div>
            <div style="display:flex;gap:8px;justify-content:flex-end">
              <a href="https://www.recargas247.net" target="_blank" rel="noopener noreferrer" class="g" style="padding:8px 12px;border-radius:8px;text-decoration:none;font-size:.82rem">Abrir Recargas247</a>
              <button class="g" onclick="dlg.close()">Cerrar</button>
            </div>
          `;
          dlg.showModal();
        };
      });
    };

    render();
  },

  async mesa_cambio(box) {
    box.innerHTML = '<div style="padding:30px;text-align:center"><div class="sk" style="height:120px;max-width:500px;margin:auto"></div><p class="mut" style="margin-top:12px">Cargando Mesa de Cambio USDT y tasa Al Cambio en vivo…</p></div>';

    // 1. Cargar Configuración de Mesa de Cambio desde settings
    let cfg = S.settings?.mesa_cambio_config || {
      activo: true,
      tasa_usdt_bs: 1020.00,
      tasa_adquisicion_bs: 1004.43,
      fondo_caja_usdt: 50.00,
      min_usdt: 1,
      max_usdt: 500,
      metodo_pago: 'Pago Móvil (BNC)',
      banco: 'BNC (0191)',
      telefono: '04242809333',
      documento: 'V 18931731',
      titular: 'Gregory Izquierdo',
      mensaje_aviso: '⚠️ IMPORTANTE: Por favor verifica cuidadosamente tu ID de Binance Pay o Correo electrónico antes de enviar la solicitud. No nos hacemos responsables ni realizaremos reembolsos por mala identificación de sus datos.'
    };
    cfg.fondo_caja_usdt = Number(cfg.fondo_caja_usdt != null ? cfg.fondo_caja_usdt : 50.00);
    cfg.tasa_adquisicion_bs = Number(cfg.tasa_adquisicion_bs || 1004.43);

    // 2. Consultar tasa oficial en vivo de Al Cambio (GraphQL de Binance P2P oficial)
    let alCambioData = null;
    const fetchAlCambioLive = async () => {
      try {
        const acRes = await fetch('https://api.alcambio.app/graphql', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            query: 'query getBinanceP2PAverages { getBinanceP2PAverages { sellAverage buyAverage sellChangePct buyChangePct totalChangePct pagesUsed asset updatedAt } }'
          })
        });
        const acJson = await acRes.json();
        const d = acJson?.data?.getBinanceP2PAverages;
        if (d && d.sellAverage) {
          alCambioData = {
            sellAverage: Number(d.sellAverage),
            buyAverage: Number(d.buyAverage),
            totalChangePct: Number(d.totalChangePct || 0),
            updatedAt: d.updatedAt ? new Date(d.updatedAt) : new Date(),
            fuente: 'Al Cambio (Binance P2P)'
          };
        }
      } catch (e) {
        console.warn('Error consultando AlCambio en vivo:', e);
      }
      if (!alCambioData) {
        try {
          const r2 = await fetch('https://ve.dolarapi.com/v1/dolares/paralelo');
          const j2 = await r2.json();
          alCambioData = {
            sellAverage: Number(j2.promedio || j2.venta || 1005.00),
            buyAverage: Number(j2.promedio || j2.compra || 1005.00),
            totalChangePct: 0,
            updatedAt: j2.fechaActualizacion ? new Date(j2.fechaActualizacion) : new Date(),
            fuente: 'DolarApi (Paralelo Referencial)'
          };
        } catch(e2){}
      }
    };
    await fetchAlCambioLive();

    // 3. Determinar sesión de corte de mercado en Venezuela (9:00 AM, 1:00 PM, 6:00 PM)
    const getMarketSession = () => {
      const d = new Date();
      const utc = d.getTime() + (d.getTimezoneOffset() * 60000);
      const veDate = new Date(utc - (4 * 3600000));
      const h = veDate.getHours();
      const m = veDate.getMinutes();
      const timeNum = h + m / 60;
      if (timeNum < 9) return { id: 'pre', name: 'Pre-Apertura', next: '09:00 AM', currentCorte: 'Cierre Previo (6:00 PM)' };
      if (timeNum < 13) return { id: '9am', name: 'Apertura de la Mañana (9:00 AM)', next: '01:00 PM', currentCorte: '09:00 AM' };
      if (timeNum < 18) return { id: '1pm', name: 'Ronda de Mediodía (1:00 PM)', next: '06:00 PM', currentCorte: '01:00 PM' };
      return { id: '6pm', name: 'Cierre de la Tarde (6:00 PM)', next: '09:00 AM (Mañana)', currentCorte: '06:00 PM' };
    };

    // 4. Cargar operaciones desde mesa_cambio_operaciones con fallback a settings si la tabla no existe
    let operaciones = [];
    let tableError = false;
    try {
      const { data, error } = await sb.from('mesa_cambio_operaciones').select('*').order('created_at', { ascending: false });
      if (error) {
        if (error.code === '42P01' || error.message?.includes('does not exist')) {
          tableError = true;
          operaciones = S.settings?.mesa_cambio_operaciones || [];
        } else {
          toast('Aviso: ' + error.message);
        }
      } else {
        operaciones = data || [];
      }
    } catch(err) {
      tableError = true;
      operaciones = S.settings?.mesa_cambio_operaciones || [];
    }

    let filterEstado = 'todos';
    let searchQuery = '';

    const render = () => {
      const session = getMarketSession();
      const liveAcRate = alCambioData?.sellAverage || 1004.43;
      const liveBuyRate = alCambioData?.buyAverage || 1007.12;
      const liveVar = alCambioData?.totalChangePct || 0;

      // Filtrar operaciones
      const filtered = operaciones.filter(op => {
        if (filterEstado !== 'todos' && op.estado !== filterEstado) return false;
        if (searchQuery) {
          const q = searchQuery.toLowerCase();
          const matchNom = (op.cliente_nombre || '').toLowerCase().includes(q);
          const matchTel = (op.cliente_telefono || '').includes(q);
          const matchDest = (op.destino_valor || '').toLowerCase().includes(q);
          const matchRef = (op.referencia_bancaria || '').toLowerCase().includes(q);
          return matchNom || matchTel || matchDest || matchRef;
        }
        return true;
      });

      const pendientes = operaciones.filter(o => o.estado === 'pendiente');
      const completados = operaciones.filter(o => o.estado === 'completado_enviado');
      const totalUsdtDespachado = completados.reduce((acc, o) => acc + Number(o.monto_usdt || 0), 0);
      const totalBsRecaudado = completados.reduce((acc, o) => acc + Number(o.total_bs || 0), 0);

      // Ganancia neta estimada de Mesa de Cambio
      const totalProfitBs = completados.reduce((acc, o) => {
        const costRate = cfg.tasa_adquisicion_bs || (o.tasa_bs * 0.98);
        return acc + Math.max(0, (o.tasa_bs - costRate) * Number(o.monto_usdt || 0));
      }, 0);
      const totalProfitUsd = completados.reduce((acc, o) => {
        const costRate = cfg.tasa_adquisicion_bs || (o.tasa_bs * 0.98);
        const diffBs = Math.max(0, (o.tasa_bs - costRate) * Number(o.monto_usdt || 0));
        return acc + (o.tasa_bs > 0 ? (diffBs / o.tasa_bs) : 0);
      }, 0);

      const isFloatLow = cfg.fondo_caja_usdt < 5.00;

      box.innerHTML = `
        <div style="display:flex;flex-direction:column;gap:20px">
          
          <!-- TARJETA CABECERA: WIDGET AL CAMBIO EN TIEMPO REAL & CONFIGURACIÓN DE TASA PRIVADA -->
          <div style="background:linear-gradient(135deg,rgba(15,23,42,.98),rgba(30,41,59,.92));border:1.5px solid rgba(253,224,71,.35);border-radius:16px;padding:22px;box-shadow:0 8px 30px rgba(0,0,0,.4)">
            
            <div style="display:flex;justify-content:space-between;align-items:flex-start;flex-wrap:wrap;gap:12px;margin-bottom:18px">
              <div>
                <div style="display:flex;align-items:center;gap:10px">
                  <span style="font-size:1.8rem">💱</span>
                  <div>
                    <h3 style="margin:0;font-size:1.3rem;color:#fde047">Mesa de Cambio USDT</h3>
                    <div style="font-size:.8rem;color:#94a3b8">Venta directa de USDT con abono verificado a Binance Pay o Correo Binance</div>
                  </div>
                </div>
              </div>
              <div style="display:flex;align-items:center;gap:12px">
                <label style="display:flex;align-items:center;gap:8px;cursor:pointer;background:rgba(255,255,255,.05);padding:8px 14px;border-radius:10px;border:1px solid rgba(255,255,255,.1)">
                  <input type="checkbox" id="mcActivo" ${cfg.activo ? 'checked' : ''} style="accent-color:#00f5a0;transform:scale(1.2)">
                  <span style="font-weight:700;font-size:.85rem;color:${cfg.activo ? '#00f5a0' : '#f87171'}">
                    ${cfg.activo ? '🟢 Mesa Operativa (Abierta)' : '🔴 Mesa Cerrada / Pausada'}
                  </span>
                </label>
              </div>
            </div>

            <!-- APARTADO EN VIVO: TASA OFICIAL AL CAMBIO & CORTES DE MERCADO VENEZUELA -->
            <div style="background:linear-gradient(135deg,rgba(14,165,233,.12),rgba(3,105,161,.08));border:1.5px solid rgba(56,189,248,.35);border-radius:14px;padding:16px;margin-bottom:18px">
              <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:12px">
                <div style="display:flex;align-items:center;gap:8px">
                  <span class="pill" style="background:#0284c7;color:#fff;font-weight:800;font-size:.76rem">
                    ⚡ Tasa USDT en Vivo: Al Cambio
                  </span>
                  <span style="font-size:.76rem;color:#94a3b8">
                    Fuente: <b>Binance P2P Oficial</b> · ${alCambioData?.updatedAt ? new Date(alCambioData.updatedAt).toLocaleTimeString('es-VE', {timeZone:'America/Caracas', hour:'2-digit', minute:'2-digit'}) : 'Actualizado'}
                  </span>
                </div>
                <button type="button" class="g" id="btnRefreshAlCambio" style="padding:4px 10px;font-size:.74rem;background:rgba(56,189,248,.15);color:#38bdf8;border-color:rgba(56,189,248,.4);font-weight:700">
                  🔄 Refrescar Al Cambio
                </button>
              </div>

              <!-- Píldoras de Cortes Oficiales: 9:00 AM, 1:00 PM y 6:00 PM -->
              <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-bottom:14px">
                <span class="mut" style="font-size:.72rem;font-weight:700">Horarios del Mercado:</span>
                <span class="pill" style="font-size:.72rem;${session.id==='9am'?'background:rgba(0,245,160,.2);color:#00f5a0;border-color:#00f5a0;font-weight:800':'background:rgba(255,255,255,.05);color:#94a3b8'}">
                  🌅 9:00 AM ${session.id==='9am'?'(Activo)':''}
                </span>
                <span class="pill" style="font-size:.72rem;${session.id==='1pm'?'background:rgba(0,245,160,.2);color:#00f5a0;border-color:#00f5a0;font-weight:800':'background:rgba(255,255,255,.05);color:#94a3b8'}">
                  ☀️ 1:00 PM ${session.id==='1pm'?'(Activo)':''}
                </span>
                <span class="pill" style="font-size:.72rem;${session.id==='6pm'?'background:rgba(0,245,160,.2);color:#00f5a0;border-color:#00f5a0;font-weight:800':'background:rgba(255,255,255,.05);color:#94a3b8'}">
                  🌆 6:00 PM ${session.id==='6pm'?'(Activo)':''}
                </span>
                <span class="mut" style="font-size:.72rem;margin-left:auto">
                  Próxima actualización: <b style="color:#fde047">${session.next}</b>
                </span>
              </div>

              <!-- Tasas Promedio Al Cambio y Botones de Acción Rápida -->
              <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px;background:rgba(0,0,0,.3);border-radius:12px;padding:12px;align-items:center">
                <div>
                  <div class="mut" style="font-size:.72rem;text-transform:uppercase">Tasa Venta Promedio (Al Cambio)</div>
                  <div style="font-size:1.6rem;font-weight:900;color:#38bdf8">
                    Bs. ${liveAcRate.toFixed(2)}
                    <span style="font-size:.75rem;font-weight:700;color:${liveVar>=0?'#4ade80':'#f87171'};margin-left:6px">
                      ${liveVar >= 0 ? '+' : ''}${liveVar.toFixed(2)}%
                    </span>
                  </div>
                  <div class="mut" style="font-size:.7rem">Compra: Bs. ${liveBuyRate.toFixed(2)} / USDT</div>
                </div>

                <div style="display:flex;flex-direction:column;gap:6px">
                  <div class="mut" style="font-size:.72rem;font-weight:700">Asignar a tu Tasa Privada:</div>
                  <div style="display:flex;gap:6px;flex-wrap:wrap">
                    <button type="button" class="g" id="btnApplyAcDirect" style="padding:5px 10px;font-size:.74rem;background:#0284c7;color:#fff;font-weight:800;border:none" title="Asignar exactamente la tasa de Al Cambio">
                      ⚡ Aplicar Directa (Bs. ${liveAcRate.toFixed(2)})
                    </button>
                    <button type="button" class="g" data-mc-margin="1" style="padding:5px 8px;font-size:.72rem;font-weight:700" title="Sumar 1% de margen">
                      +1%
                    </button>
                    <button type="button" class="g" data-mc-margin="2" style="padding:5px 8px;font-size:.72rem;font-weight:700" title="Sumar 2% de margen">
                      +2%
                    </button>
                    <button type="button" class="g" data-mc-margin="3" style="padding:5px 8px;font-size:.72rem;font-weight:700" title="Sumar 3% de margen">
                      +3%
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <!-- FORMULARIO DE TASA PRIVADA Y CONDICIONES (MANUAL Y EDITABLE) -->
            <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px;margin-bottom:16px">
              <div style="background:rgba(0,0,0,.25);padding:12px;border-radius:12px;border:1px solid rgba(253,224,71,.35)">
                <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px;color:#fde047;font-weight:700">
                  Tu Tasa Privada de Venta USDT (Bs/USDT) *
                </label>
                <div style="display:flex;align-items:center;gap:6px">
                  <span style="font-weight:800;font-size:1.1rem;color:#fde047">Bs.</span>
                  <input id="mcTasaBs" type="number" step="0.01" value="${cfg.tasa_usdt_bs || liveAcRate || 1020.00}" style="font-size:1.2rem;font-weight:800;color:#fde047;background:rgba(255,255,255,.07);border:1px solid rgba(253,224,71,.4);border-radius:8px;padding:6px 10px;width:100%" required>
                </div>
                <span class="mut" style="font-size:.72rem;display:block;margin-top:4px">
                  Puedes editarla manualmente en cualquier momento o usar los botones de Al Cambio arriba.
                </span>
              </div>

              <div style="background:rgba(0,0,0,.25);padding:12px;border-radius:12px;border:1px solid rgba(255,255,255,.1)">
                <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Mínimo de Compra (USDT)</label>
                <input id="mcMinUsdt" type="number" step="1" value="${cfg.min_usdt || 1}" style="font-size:1rem;font-weight:700;padding:7px 10px;width:100%">
                <span class="mut" style="font-size:.72rem;display:block;margin-top:4px">Límite mínimo por transacción</span>
              </div>

              <div style="background:rgba(0,0,0,.25);padding:12px;border-radius:12px;border:1px solid rgba(255,255,255,.1)">
                <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Máximo de Compra (USDT)</label>
                <input id="mcMaxUsdt" type="number" step="1" value="${cfg.max_usdt || 500}" style="font-size:1rem;font-weight:700;padding:7px 10px;width:100%">
                <span class="mut" style="font-size:.72rem;display:block;margin-top:4px">Límite máximo por transacción</span>
              </div>

              <div style="background:rgba(0,0,0,.25);padding:12px;border-radius:12px;border:1px solid rgba(255,255,255,.1)">
                <label class="mut" style="font-size:.76rem;display:block;margin-bottom:4px">Método para recibir Bs</label>
                <input id="mcMetodo" type="text" value="${esc(cfg.metodo_pago || 'Pago Móvil (BNC)')}" style="font-size:.9rem;padding:7px 10px;width:100%">
                <span class="mut" style="font-size:.72rem;display:block;margin-top:4px">Ej: Pago Móvil / BNC</span>
              </div>
            </div>

            <!-- DATOS BANCARIOS EDITABLES -->
            <details style="background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.08);border-radius:10px;padding:10px 14px;margin-bottom:16px">
              <summary style="cursor:pointer;font-weight:700;font-size:.82rem;color:#94a3b8">
                🏦 Configurar tus Datos de Pago Móvil / Bancarios para recibir los Bolívares
              </summary>
              <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:10px;margin-top:12px">
                <div>
                  <label class="mut" style="font-size:.72rem;display:block;margin-bottom:2px">Banco</label>
                  <input id="mcBanco" type="text" value="${esc(cfg.banco || 'BNC (0191)')}">
                </div>
                <div>
                  <label class="mut" style="font-size:.72rem;display:block;margin-bottom:2px">Teléfono Pago Móvil</label>
                  <input id="mcTel" type="text" value="${esc(cfg.telefono || '04242809333')}">
                </div>
                <div>
                  <label class="mut" style="font-size:.72rem;display:block;margin-bottom:2px">Cédula / RIF</label>
                  <input id="mcDoc" type="text" value="${esc(cfg.documento || 'V 18931731')}">
                </div>
                <div>
                  <label class="mut" style="font-size:.72rem;display:block;margin-bottom:2px">Titular de la cuenta</label>
                  <input id="mcTitular" type="text" value="${esc(cfg.titular || 'Gregory Izquierdo')}">
                </div>
              </div>
            </details>

            <div style="display:flex;justify-content:flex-end">
              <button id="btnSaveMesaCfg" style="background:#fde047;color:#0f172a;font-weight:800;border:none;padding:10px 22px;border-radius:10px;display:inline-flex;align-items:center;gap:8px;cursor:pointer">
                <span>💾 Guardar Tasa y Configuración</span>
              </button>
            </div>
          </div>

          <!-- TARJETAS DE ESTADÍSTICAS Y FONDO DE CAJA USDT (LIQUIDEZ) -->
          <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:14px">
            <!-- 1. Fondo de Caja USDT Disponible -->
            <div class="card" style="padding:16px;background:rgba(15,23,42,.6);border:1.5px solid ${isFloatLow ? '#ef4444' : 'rgba(0,245,160,.3)'}">
              <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:4px">
                <div style="font-size:.76rem;color:#94a3b8;font-weight:700;text-transform:uppercase">💼 Fondo de Caja (Liquidez USDT)</div>
                <span class="pill" style="${isFloatLow ? 'background:rgba(239,68,68,.15);color:#f87171;border-color:rgba(239,68,68,.4);font-weight:800' : 'background:rgba(0,245,160,.12);color:#00f5a0;border-color:rgba(0,245,160,.3);font-weight:700'}">
                  ${isFloatLow ? '⚠️ Liquidez Crítica (< $5)' : '🟢 Liquidez Óptima'}
                </span>
              </div>
              <div style="font-size:1.8rem;font-weight:900;color:${isFloatLow ? '#f87171' : '#00f5a0'};margin:6px 0">
                $${cfg.fondo_caja_usdt.toFixed(2)} USDT
              </div>
              <div class="mut" style="font-size:.74rem;margin-bottom:10px">
                Saldo rotativo para despachos inmediatos a clientes
              </div>
              <div style="display:flex;gap:6px">
                <button type="button" id="btnAddFloatUsdt" class="g" style="padding:5px 10px;font-size:.74rem;background:rgba(0,245,160,.15);color:#00f5a0;border-color:rgba(0,245,160,.4);font-weight:800">
                  ➕ Inyectar Liquidez
                </button>
                <button type="button" id="btnEditFloatDirect" class="g" style="padding:5px 8px;font-size:.74rem">
                  ✏️ Ajustar
                </button>
              </div>
            </div>

            <!-- 2. Solicitudes Pendientes -->
            <div class="card" style="padding:16px;background:rgba(15,23,42,.6);border:1px solid rgba(253,224,71,.25)">
              <div style="font-size:.76rem;color:#94a3b8;font-weight:700;text-transform:uppercase">⏳ Solicitudes Pendientes</div>
              <div style="font-size:1.8rem;font-weight:900;color:#fde047;margin:6px 0">${pendientes.length}</div>
              <div class="mut" style="font-size:.74rem">En espera de verificación y transferencia</div>
            </div>

            <!-- 3. Total USDT Despachados -->
            <div class="card" style="padding:16px;background:rgba(15,23,42,.6);border:1px solid rgba(56,189,248,.25)">
              <div style="font-size:.76rem;color:#94a3b8;font-weight:700;text-transform:uppercase">🚀 USDT Despachados</div>
              <div style="font-size:1.8rem;font-weight:900;color:#38bdf8;margin:6px 0">$${totalUsdtDespachado.toFixed(2)} USDT</div>
              <div class="mut" style="font-size:.74rem">Volumen total operado a través de Binance Pay</div>
            </div>

            <!-- 4. Total Bolívares Recibidos -->
            <div class="card" style="padding:16px;background:rgba(15,23,42,.6);border:1px solid rgba(168,85,247,.25)">
              <div style="font-size:.76rem;color:#94a3b8;font-weight:700;text-transform:uppercase">💵 Total Bolívares Recibidos</div>
              <div style="font-size:1.6rem;font-weight:900;color:#c084fc;margin:6px 0">Bs. ${totalBsRecaudado.toLocaleString('es-VE', {minimumFractionDigits:2, maximumFractionDigits:2})}</div>
              <div class="mut" style="font-size:.74rem">Ingresados en cuentas bancarias</div>
            </div>

            <!-- 5. Ganancia Estimada de Mesa de Cambio -->
            <div class="card" style="padding:16px;background:rgba(15,23,42,.6);border:1px solid rgba(34,197,94,.25)">
              <div style="font-size:.76rem;color:#94a3b8;font-weight:700;text-transform:uppercase">📈 Ganancia Estimada Mesa</div>
              <div style="font-size:1.6rem;font-weight:900;color:#4ade80;margin:6px 0">+$${totalProfitUsd.toFixed(2)} USD</div>
              <div class="mut" style="font-size:.74rem">Bs. ${totalProfitBs.toLocaleString('es-VE', {minimumFractionDigits:2, maximumFractionDigits:2})} (Spread neto acumulado)</div>
            </div>
          </div>

          <!-- LISTA DE SOLICITUDES Y OPERACIONES -->
          <div style="background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.08);border-radius:16px;padding:18px">
            <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;margin-bottom:14px">
              <div style="display:flex;align-items:center;gap:8px">
                <h4 style="margin:0;font-size:1.05rem">Historial de Operaciones de USDT</h4>
                <span class="pill" style="font-size:.75rem">${filtered.length} operaciones</span>
              </div>
              <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
                <input id="mcSearchInput" type="search" placeholder="🔍 Buscar por cliente, ID, ref..." value="${esc(searchQuery)}" style="padding:6px 12px;font-size:.8rem;border-radius:8px">
                <div class="tabs" style="margin:0">
                  <button class="${filterEstado==='todos'?'':'g'}" data-mc-st="todos" style="padding:6px 12px;font-size:.78rem">Todos</button>
                  <button class="${filterEstado==='pendiente'?'':'g'}" data-mc-st="pendiente" style="padding:6px 12px;font-size:.78rem">⏳ Pendientes (${pendientes.length})</button>
                  <button class="${filterEstado==='completado_enviado'?'':'g'}" data-mc-st="completado_enviado" style="padding:6px 12px;font-size:.78rem">✅ Enviados (${completados.length})</button>
                  <button class="${filterEstado==='rechazado'?'':'g'}" data-mc-st="rechazado" style="padding:6px 12px;font-size:.78rem">❌ Rechazados</button>
                </div>
              </div>
            </div>

            ${filtered.length ? `
              <div class="wrap">
                <table>
                  <tr>
                    <th>Fecha / Hora</th>
                    <th>Cliente</th>
                    <th>Monto USDT</th>
                    <th>Tasa & Total Bs</th>
                    <th>Destino Binance</th>
                    <th>Pago / Referencia</th>
                    <th>Estado</th>
                    <th>Acciones</th>
                  </tr>
                  ${filtered.map(op => {
                    const dt = op.created_at ? new Date(op.created_at).toLocaleString('es-VE', { timeZone: 'America/Caracas', dateStyle: 'short', timeStyle: 'short' }) : '—';
                    const isPend = op.estado === 'pendiente';
                    const isComp = op.estado === 'completado_enviado';
                    const isRech = op.estado === 'rechazado';
                    const telClean = (op.cliente_telefono || '').replace(/\D/g, '');

                    const stBadge = isPend
                      ? '<span class="pill" style="background:rgba(234,179,8,.15);color:#fde047;border-color:rgba(234,179,8,.35)">⏳ Pendiente</span>'
                      : (isComp
                        ? '<span class="pill" style="background:rgba(0,245,160,.15);color:#00f5a0;border-color:rgba(0,245,160,.35)">✅ Enviado</span>'
                        : '<span class="pill off">❌ Rechazado</span>');

                    const destTypeLabel = op.destino_tipo === 'binance_email' ? '📧 Binance Email' : '🆔 Binance Pay ID';

                    return `
                      <tr>
                        <td style="font-size:.78rem;white-space:nowrap">${esc(dt)}</td>
                        <td>
                          <b>${esc(op.cliente_nombre || 'Cliente')}</b>
                          ${telClean ? `
                            <div style="font-size:.75rem;margin-top:2px">
                              <a href="https://wa.me/${telClean}" target="_blank" rel="noopener noreferrer" style="color:#25d366;text-decoration:none">
                                💬 ${esc(op.cliente_telefono)}
                              </a>
                            </div>
                          ` : ''}
                        </td>
                        <td>
                          <b style="color:#00f5a0;font-size:1.1rem;font-family:monospace">$${Number(op.monto_usdt).toFixed(2)} USDT</b>
                        </td>
                        <td>
                          <div style="font-size:.85rem;font-weight:700;color:#fde047">Bs. ${Number(op.total_bs).toLocaleString('es-VE',{minimumFractionDigits:2,maximumFractionDigits:2})}</div>
                          <span class="mut" style="font-size:.72rem">Tasa: Bs. ${Number(op.tasa_bs).toFixed(2)}</span>
                        </td>
                        <td>
                          <div style="font-size:.72rem;color:#818cf8;font-weight:700">${destTypeLabel}</div>
                          <div style="display:flex;align-items:center;gap:6px;margin-top:2px">
                            <code style="font-size:.82rem;font-weight:800;background:rgba(255,255,255,.08);padding:3px 6px;border-radius:6px">${esc(op.destino_valor)}</code>
                            <button type="button" class="g" data-mc-copy="${esc(op.destino_valor)}" title="Copiar destino para transferir en Binance" style="padding:3px 7px;font-size:.72rem">📋</button>
                          </div>
                        </td>
                        <td>
                          <div style="font-size:.78rem;font-weight:700">${esc(op.metodo_pago || 'Pago Móvil')}</div>
                          <div style="display:flex;align-items:center;gap:6px;margin-top:2px">
                            <span class="mut" style="font-size:.74rem">Ref:</span>
                            <code style="font-size:.8rem">${esc(op.referencia_bancaria)}</code>
                            <button type="button" class="g" data-mc-copy="${esc(op.referencia_bancaria)}" title="Copiar referencia" style="padding:2px 5px;font-size:.68rem">📋</button>
                          </div>
                        </td>
                        <td>${stBadge}</td>
                        <td class="row">
                          ${isPend ? `
                            <button class="cta" data-mc-send="${op.id}" data-usdt="${op.monto_usdt}" data-dest="${esc(op.destino_valor)}" data-dest-tipo="${esc(op.destino_tipo)}" data-nom="${esc(op.cliente_nombre||'Cliente')}" data-tel="${esc(op.cliente_telefono||'')}" style="background:#00f5a0;color:#000;font-size:.76rem;padding:5px 10px;font-weight:800">
                              ⚡ Marcar Enviado
                            </button>
                            <button class="g" data-mc-reject="${op.id}" data-nom="${esc(op.cliente_nombre||'Cliente')}" style="font-size:.74rem;padding:5px 8px;color:#f87171">
                              ✕ Rechazar
                            </button>
                          ` : (isComp ? `
                            <button class="g" data-mc-wa="${op.id}" data-usdt="${op.monto_usdt}" data-dest="${esc(op.destino_valor)}" data-nom="${esc(op.cliente_nombre||'Cliente')}" data-tel="${esc(op.cliente_telefono||'')}" style="font-size:.74rem;padding:4px 8px">
                              💬 WA
                            </button>
                          ` : '<span class="mut" style="font-size:.75rem">—</span>')}
                        </td>
                      </tr>
                    `;
                  }).join('')}
                </table>
              </div>
            ` : `
              <div style="text-align:center;padding:34px 14px">
                <span style="font-size:2.2rem">💱</span>
                <p class="mut" style="margin:8px 0 0;font-size:.85rem">No se encontraron operaciones registradas con los filtros actuales.</p>
              </div>
            `}
          </div>

        </div>
      `;

      // Eventos: Refrescar Al Cambio
      const btnRefresh = $('#btnRefreshAlCambio');
      if (btnRefresh) {
        btnRefresh.onclick = async () => {
          btnRefresh.disabled = true;
          btnRefresh.textContent = '⏳ Consultando...';
          alCambioData = await fetchAlCambioData();
          toast('✅ Tasa Al Cambio actualizada en tiempo real.');
          render();
        };
      }

      // Eventos: Aplicar Tasa Al Cambio Directa
      const btnAcDirect = $('#btnApplyAcDirect');
      if (btnAcDirect) {
        btnAcDirect.onclick = () => {
          const inp = $('#mcTasaBs');
          if (inp) {
            inp.value = liveAcRate.toFixed(2);
            toast(`⚡ Tasa Al Cambio (Bs. ${liveAcRate.toFixed(2)}) asignada en el campo. Haz clic en "Guardar Tasa" para activarla.`);
          }
        };
      }

      // Eventos: Aplicar Margen (+1%, +2%, +3%)
      box.querySelectorAll('[data-mc-margin]').forEach(btn => {
        btn.onclick = () => {
          const marginPct = parseFloat(btn.dataset.mcMargin) || 0;
          const inp = $('#mcTasaBs');
          if (inp) {
            const margined = liveAcRate * (1 + marginPct / 100);
            inp.value = margined.toFixed(2);
            toast(`➕ Margen +${marginPct}% aplicado: Bs. ${margined.toFixed(2)}. Haz clic en "Guardar Tasa" para activarla.`);
          }
        };
      });

      // Eventos: Inyectar Liquidez USDT al Fondo de Caja
      const btnAddFloat = $('#btnAddFloatUsdt');
      if (btnAddFloat) {
        btnAddFloat.onclick = async () => {
          const pAmt = prompt('¿Cuántos USDT deseas inyectar a tu Fondo de Caja (Liquidez)?', '50.00');
          if (pAmt === null) return;
          const addAmt = parseFloat(pAmt);
          if (isNaN(addAmt) || addAmt <= 0) return toast('Ingresa una cantidad válida mayor a 0.');

          const pRate = prompt(`¿A qué tasa en Bolívares compraste estos ${addAmt} USDT? (Opcional, para contabilidad de margen):`, (liveAcRate || cfg.tasa_usdt_bs || 50.00).toFixed(2));
          const buyRate = parseFloat(pRate) || null;
          const costBs = buyRate ? (addAmt * buyRate) : null;

          const newSaldo = (Number(cfg.fondo_caja_usdt) || 0) + addAmt;
          cfg.fondo_caja_usdt = newSaldo;
          if (buyRate) cfg.tasa_adquisicion_bs = buyRate;

          // Guardar en settings
          try {
            await sb.from('settings').upsert({ key: 'mesa_cambio_config', value: cfg });
            const { data: negRow } = await sb.from('settings').select('value').eq('key', 'negocio').maybeSingle();
            const negVal = negRow?.value || {};
            negVal.mesa_cambio_config = cfg;
            await sb.from('settings').upsert({ key: 'negocio', value: negVal });
            S.settings.mesa_cambio_config = cfg;
            if (S.settings.negocio) S.settings.negocio.mesa_cambio_config = cfg;

            // Registrar en mesa_cambio_caja
            await sb.from('mesa_cambio_caja').insert({
              tipo: 'ingreso_liquidez',
              monto_usdt: addAmt,
              tasa_compra_bs: buyRate,
              costo_total_bs: costBs,
              saldo_posterior_usdt: newSaldo,
              notas: 'Inyección manual de liquidez USDT'
            });
          } catch(e) { console.warn('Error guardando mesa_cambio_caja:', e); }

          toast(`✅ Liquidez inyectada: +${addAmt.toFixed(2)} USDT. Nuevo saldo de caja: $${newSaldo.toFixed(2)} USDT`);
          render();
        };
      }

      // Eventos: Ajustar Fondo de Caja Directamente
      const btnEditFloat = $('#btnEditFloatDirect');
      if (btnEditFloat) {
        btnEditFloat.onclick = async () => {
          const curVal = (Number(cfg.fondo_caja_usdt) || 0).toFixed(2);
          const pVal = prompt('Ajustar el saldo del Fondo de Caja USDT directamente a:', curVal);
          if (pVal === null) return;
          const newVal = parseFloat(pVal);
          if (isNaN(newVal) || newVal < 0) return toast('Ingresa un valor válido mayor o igual a 0.');

          cfg.fondo_caja_usdt = newVal;
          try {
            await sb.from('settings').upsert({ key: 'mesa_cambio_config', value: cfg });
            const { data: negRow } = await sb.from('settings').select('value').eq('key', 'negocio').maybeSingle();
            const negVal = negRow?.value || {};
            negVal.mesa_cambio_config = cfg;
            await sb.from('settings').upsert({ key: 'negocio', value: negVal });
            S.settings.mesa_cambio_config = cfg;
            if (S.settings.negocio) S.settings.negocio.mesa_cambio_config = cfg;

            await sb.from('mesa_cambio_caja').insert({
              tipo: 'ajuste_manual',
              monto_usdt: newVal,
              saldo_posterior_usdt: newVal,
              notas: `Ajuste manual de saldo de caja a $${newVal.toFixed(2)} USDT`
            });
          } catch(e) { console.warn('Error ajustando caja:', e); }

          toast(`✅ Fondo de Caja actualizado a $${newVal.toFixed(2)} USDT`);
          render();
        };
      }

      // Eventos: Guardar Configuración
      const btnSave = $('#btnSaveMesaCfg');
      if (btnSave) {
        btnSave.onclick = async () => {
          const tasa = parseFloat($('#mcTasaBs').value);
          if (isNaN(tasa) || tasa <= 0) return toast('Ingresa una tasa de cambio válida (mayor a 0).');

          const newCfg = {
            ...cfg,
            activo: $('#mcActivo').checked,
            tasa_usdt_bs: tasa,
            min_usdt: parseFloat($('#mcMinUsdt').value) || 1,
            max_usdt: parseFloat($('#mcMaxUsdt').value) || 500,
            metodo_pago: $('#mcMetodo').value.trim() || 'Pago Móvil (BNC)',
            banco: $('#mcBanco').value.trim(),
            telefono: $('#mcTel').value.trim(),
            documento: $('#mcDoc').value.trim(),
            titular: $('#mcTitular').value.trim(),
            mensaje_aviso: cfg.mensaje_aviso
          };

          btnSave.disabled = true;
          btnSave.innerHTML = '<span>⏳ Guardando...</span>';

          try {
            const { error } = await sb.from('settings').upsert({ key: 'mesa_cambio_config', value: newCfg });
            if (error) throw error;

            // Guardar copia directa dentro de la clave 'negocio' para que cualquier teléfono móvil lo lea de inmediato
            const { data: negRow } = await sb.from('settings').select('value').eq('key', 'negocio').maybeSingle();
            const negVal = negRow?.value || {};
            try {
              await sb.from('settings').upsert({ key: 'negocio', value: negVal });
            } catch(e) {}

            S.settings.mesa_cambio_config = newCfg;
            if (S.settings.negocio) S.settings.negocio.mesa_cambio_config = newCfg;
            cfg = newCfg;
            toast('✅ Configuración guardada. Tasa activa sincronizada con todos los clientes: Bs. ' + tasa.toFixed(2));
            render();
          } catch(err) {
            toast('Error al guardar: ' + err.message);
          } finally {
            btnSave.disabled = false;
          }
        };
      }

      // Copiar al portapapeles
      box.querySelectorAll('[data-mc-copy]').forEach(b => {
        b.onclick = async () => {
          const val = b.dataset.mcCopy;
          if (!val) return;
          try {
            await navigator.clipboard.writeText(val);
            const orig = b.textContent;
            b.textContent = '✓';
            setTimeout(() => b.textContent = orig, 1200);
          } catch(e) {
            toast('Copia manualmente: ' + val);
          }
        };
      });

      // Filtros de estado
      box.querySelectorAll('[data-mc-st]').forEach(b => {
        b.onclick = () => {
          filterEstado = b.dataset.mcSt;
          render();
        };
      });

      // Buscador
      const sInput = $('#mcSearchInput');
      if (sInput) {
        sInput.oninput = () => {
          searchQuery = sInput.value.trim();
          render();
        };
      }

      // Marcar Enviado (Abono completado y descuento automático del fondo de caja)
      box.querySelectorAll('[data-mc-send]').forEach(b => {
        b.onclick = async () => {
          const opId = b.dataset.mcSend;
          const usdt = parseFloat(b.dataset.usdt) || 0;
          const dest = b.dataset.dest;
          const destTipo = b.dataset.destTipo === 'binance_email' ? 'Correo de Binance' : 'Binance Pay ID';
          const nom = b.dataset.nom;
          const tel = (b.dataset.tel || '').replace(/\D/g, '');

          if (!confirm(`¿Confirmas que ya enviaste ${usdt} USDT a ${destTipo} ${dest} (${nom})?\n\n• Se descontarán automáticamente ${usdt} USDT del Fondo de Caja.`)) return;

          const now = new Date().toISOString();
          let err = null;
          if (!tableError) {
            const res = await sb.from('mesa_cambio_operaciones').update({ estado: 'completado_enviado', enviado_at: now }).eq('id', opId);
            err = res.error;
          }

          if (err) return toast('Error al actualizar: ' + err.message);

          // Descontar automáticamente del fondo de caja USDT
          const prevFloat = Number(cfg.fondo_caja_usdt) || 0;
          const newFloat = Math.max(0, prevFloat - usdt);
          cfg.fondo_caja_usdt = newFloat;

          // Sincronizar en settings
          try {
            await sb.from('settings').upsert({ key: 'mesa_cambio_config', value: cfg });
            const { data: negRow } = await sb.from('settings').select('value').eq('key', 'negocio').maybeSingle();
            const negVal = negRow?.value || {};
            negVal.mesa_cambio_config = cfg;
            await sb.from('settings').upsert({ key: 'negocio', value: negVal });
            S.settings.mesa_cambio_config = cfg;
            if (S.settings.negocio) S.settings.negocio.mesa_cambio_config = cfg;

            // Registrar egreso en mesa_cambio_caja
            await sb.from('mesa_cambio_caja').insert({
              tipo: 'egreso_despacho',
              monto_usdt: usdt,
              saldo_posterior_usdt: newFloat,
              operacion_id: opId,
              notas: `Despacho completado a ${nom} (${dest})`
            });
          } catch(e) { console.warn('Error registrando egreso caja:', e); }

          // Actualizar en memoria local
          const f = operaciones.find(o => o.id === opId);
          if (f) {
            f.estado = 'completado_enviado';
            f.enviado_at = now;
          }

          const waMsg = encodeURIComponent(
            `¡Hola ${nom}! 🎉 Tus *${usdt} USDT* de la Mesa de Cambio han sido transferidos exitosamente a tu cuenta de Binance (${dest}).\n\n` +
            `Por favor verifica en tu aplicación de Binance Pay / Fondos. ¡Muchas gracias por tu confianza!`
          );

          $('#dlgBody').innerHTML = `
            <div style="text-align:center;padding:12px 0">
              <span style="font-size:2.5rem">⚡</span>
              <h3 style="margin:10px 0 6px">¡Operación Marcada como Enviada!</h3>
              <p class="mut" style="font-size:.85rem;margin:0 0 10px">Se registraron los ${usdt} USDT como despachados para <b>${esc(nom)}</b> (${esc(dest)}).</p>
              <div style="background:rgba(0,245,160,.1);border:1px solid rgba(0,245,160,.3);border-radius:10px;padding:8px;margin-bottom:14px;font-size:.8rem;color:#00f5a0">
                💼 Fondo de Caja restante: <b>$${newFloat.toFixed(2)} USDT</b>
              </div>
              ${tel ? `
                <a href="https://wa.me/${tel}?text=${waMsg}" target="_blank" rel="noopener noreferrer" style="background:#25D366;color:#fff;padding:12px;border-radius:12px;text-decoration:none;font-weight:800;display:flex;align-items:center;justify-content:center;gap:8px;margin-bottom:10px">
                  <span>💬 Enviar Notificación de Abono por WhatsApp</span>
                </a>
              ` : ''}
              <button class="g" onclick="dlg.close()">Cerrar</button>
            </div>
          `;
          dlg.showModal();
          render();
        };
      });

      // Rechazar Operación
      box.querySelectorAll('[data-mc-reject]').forEach(b => {
        b.onclick = async () => {
          const opId = b.dataset.mcReject;
          const nom = b.dataset.nom;
          const motivo = prompt(`Ingresa el motivo del rechazo para la solicitud de ${nom}:`, 'Pago no verificado / Referencia no encontrada');
          if (motivo === null) return;

          let err = null;
          if (!tableError) {
            const res = await sb.from('mesa_cambio_operaciones').update({ estado: 'rechazado', notas_admin: motivo }).eq('id', opId);
            err = res.error;
          }

          if (err) return toast('Error al rechazar: ' + err.message);

          const f = operaciones.find(o => o.id === opId);
          if (f) {
            f.estado = 'rechazado';
            f.notas_admin = motivo;
          }
          toast('Operación marcada como rechazada.');
          render();
        };
      });

      // Reenviar WA
      box.querySelectorAll('[data-mc-wa]').forEach(b => {
        b.onclick = () => {
          const usdt = b.dataset.usdt;
          const dest = b.dataset.dest;
          const nom = b.dataset.nom;
          const tel = (b.dataset.tel || '').replace(/\D/g, '');
          const waMsg = encodeURIComponent(
            `¡Hola ${nom}! 🎉 Comprobante de tu operación en la Mesa de Cambio: Tus *${usdt} USDT* fueron enviados a tu Binance (${dest}). ¡Muchas gracias por tu preferencia!`
          );
          if (tel) window.open(`https://wa.me/${tel}?text=${waMsg}`, '_blank');
          else toast('El cliente no registró teléfono.');
        };
      });
    };

    render();
  },

  async liquidaciones(box) {
    box.innerHTML = '<div style="padding:30px;text-align:center"><div class="sk" style="height:120px;max-width:500px;margin:auto"></div><p class="mut" style="margin-top:12px">Cargando módulo de Liquidación de Socios y Comisiones…</p></div>';

    // 1. Cargar comisiones, datos del socio oficial Pablo Gonzalez, tasa actual y cuotas/créditos
    const [{ data: coms, error: comsErr }, { data: pabloData }, { data: exRate }, { data: instData }] = await Promise.all([
      sb.from('partner_commissions')
        .select('*, customers!customer_id(nombre,telefono,email), vendedor:customers!vendedor_id(nombre,telefono,email,codigo_identificacion)')
        .order('created_at', { ascending: false }),
      sb.from('customers').select('id,nombre,email,telefono,codigo_identificacion,limite_credito')
        .or('codigo_identificacion.eq.RVD:1001,nombre.ilike.%Pablo Gonzalez%')
        .limit(1)
        .maybeSingle(),
      sb.from('exchange_rates').select('bs_por_usd').order('fecha', { ascending: false }).limit(1).maybeSingle(),
      sb.from('installments').select('id, order_id, customer_id, reseller_id, numero_cuota, total_cuotas, monto_usd, monto_bs, estado, fecha_vencimiento, referencia, pagada_at')
    ]);

    if (comsErr) {
      console.error('Error cargando partner_commissions:', comsErr);
      box.innerHTML = `<div class="card" style="border:1.5px solid #ef4444;background:rgba(239,68,68,.08);padding:24px;border-radius:14px;max-width:640px;margin:20px auto;text-align:center">
        <h3 style="color:#f87171;margin:0 0 8px">⚠️ No se pudieron cargar las liquidaciones</h3>
        <p class="mut" style="margin:0 0 14px">${esc(comsErr.message)}</p>
        <p class="mut" style="font-size:.82rem">Asegúrate de ejecutar la <b>Migración 27</b> en el SQL Editor de Supabase para activar las tablas y cálculos.</p>
        <button class="g" onclick="EXTRA.liquidaciones(box)">🔄 Reintentar</button>
      </div>`;
      return;
    }

    // Exclusividad estricta: Únicamente Pablo Gonzalez es Socio Oficial con liquidación de ganancias y sociedad.
    // Nelson, Josuanny, Leandro y nuevos revendedores operan por margen de compra mayorista, NO en liquidaciones de socios.
    const pabloSocio = pabloData || {
      id: null,
      nombre: 'Pablo Gonzalez',
      codigo_identificacion: 'RVD:1001',
      telefono: '584120000000'
    };

    const curRate = Number(exRate?.bs_por_usd || 50.00);

    // Mapear cada comisión con sus cuotas/créditos
    const allDebts = instData || [];
    const allComms = (coms || []).map(c => {
      const ordDebts = allDebts.filter(d => d.order_id && d.order_id === c.order_id);
      const pendDebts = ordDebts.filter(d => d.estado !== 'pagada');
      const isCreditSale = ordDebts.length > 0;
      const isCreditPending = pendDebts.length > 0;
      const creditPendingUsd = pendDebts.reduce((sum, d) => sum + Number(d.monto_usd || 0), 0);
      return {
        ...c,
        isCreditSale,
        isCreditPending,
        creditPendingUsd,
        ordDebts
      };
    });

    // Cuotas adeudadas por Pablo Gonzalez (por créditos de revendedor activos)
    const pabloDebts = allDebts.filter(d => {
      if (d.estado === 'pagada') return false;
      if (d.reseller_id && pabloSocio.id && d.reseller_id === pabloSocio.id) return true;
      if (d.customer_id && pabloSocio.id && d.customer_id === pabloSocio.id && d.referencia && d.referencia.toUpperCase().includes('CRÉDITO')) return true;
      if (/pablo\s*gonzalez|\[crédito pablo/i.test(d.referencia || '')) return true;
      return false;
    });
    const pabloTotalDeuda = pabloDebts.reduce((sum, d) => sum + Number(d.monto_usd || 0), 0);
    let filterPeriodo = 'lanzamiento'; // 'lanzamiento' (>= 2026-10-16) | 'todos'
    let filterConcepto = 'todos';
    let filterStatus = 'pendiente';
    const selectedIds = new Set();

    const render = () => {
      let filtered = allComms;
      if (filterPeriodo === 'lanzamiento') {
        filtered = filtered.filter(c => (c.created_at || '').slice(0, 10) >= '2026-10-16');
      }
      if (filterStatus !== 'todos') filtered = filtered.filter(c => c.estado === filterStatus);
      if (filterConcepto === 'autogestion_bs') {
        filtered = filtered.filter(c => c.tipo_venta === 'autogestion_bs');
      } else if (filterConcepto === 'otro_revendedor') {
        filtered = filtered.filter(c => c.tipo_venta === 'otro_revendedor' || (c.vendedor_id && c.vendedor_id !== pabloSocio.id));
      } else if (filterConcepto === 'binance_usdt') {
        filtered = filtered.filter(c => c.tipo_venta === 'binance_usdt' || c.metodo_origen === 'binance');
      }

      // Comisiones disponibles para liquidar (excluyendo ventas a crédito cuyas cuotas aún están pendientes en calle)
      const liquidableComms = filtered.filter(c => c.estado === 'pendiente' && !c.isCreditPending);
      const retencionCreditoComms = filtered.filter(c => c.estado === 'pendiente' && c.isCreditPending);

      const totPendUsd = liquidableComms.reduce((a, c) => a + Number(c.ganancia_vendedor_usd || 0), 0);
      const totPendBs = liquidableComms.reduce((a, c) => a + Number(c.ganancia_vendedor_bs || (c.ganancia_vendedor_usd * curRate) || 0), 0);

      const totRetenidoUsd = retencionCreditoComms.reduce((a, c) => a + Number(c.ganancia_vendedor_usd || 0), 0);
      const totRetenidoBs = retencionCreditoComms.reduce((a, c) => a + Number(c.ganancia_vendedor_bs || (c.ganancia_vendedor_usd * curRate) || 0), 0);

      const totGregUsd = filtered.reduce((a, c) => a + Number(c.ganancia_gregory_usd || 0), 0);
      const totGregBs = filtered.reduce((a, c) => a + Number(c.ganancia_gregory_bs || (c.ganancia_gregory_usd * curRate) || 0), 0);
      const totNegUsd = filtered.reduce((a, c) => a + Number(c.ganancia_negocio_usd || 0), 0);
      const totReservaUsd = filtered.reduce((a, c) => a + Number(c.reserva_estrategica_usd || (c.ganancia_negocio_usd * 0.10) || 0), 0);
      const totCajaUsd = filtered.reduce((a, c) => a + Number(c.caja_negocio_usd || (c.ganancia_negocio_usd * 0.90) || 0), 0);
      const totLiqUsd = filtered.filter(c => c.estado === 'liquidada').reduce((a, c) => a + Number(c.ganancia_vendedor_usd || 0), 0);

      // Saldo neto real a favor de Pablo descontando su deuda por créditos
      const pabloSaldoNetoUsd = totPendUsd - pabloTotalDeuda;
      const pabloSaldoNetoBs = pabloSaldoNetoUsd * curRate;

      const selComms = allComms.filter(c => selectedIds.has(c.id));
      const selTotUsd = selComms.reduce((a, c) => a + Number(c.ganancia_vendedor_usd || 0), 0);
      const selTotBs = selComms.reduce((a, c) => a + Number(c.ganancia_vendedor_bs || (c.ganancia_vendedor_usd * curRate) || 0), 0);
      const selGregUsd = selComms.reduce((a, c) => a + Number(c.ganancia_gregory_usd || 0), 0);
      const selGregBs = selComms.reduce((a, c) => a + Number(c.ganancia_gregory_bs || (c.ganancia_gregory_usd * curRate) || 0), 0);

      box.innerHTML = `
        <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;margin-bottom:14px">
          <div>
            <h3 style="margin:0;display:flex;align-items:center;gap:8px">
              <span>💼 Liquidación de Ganancias & Socios</span>
              <span class="pill" style="font-size:.74rem;background:rgba(56,189,248,.12);color:#38bdf8;border-color:rgba(56,189,248,.3)">Tasa BCV: Bs. ${curRate.toFixed(2)}</span>
            </h3>
            <p class="mut" style="font-size:.84rem;margin:4px 0 0">
              Modelo oficial de autogestión, ventas por revendedores, Binance y Reserva Estratégica. Socio oficial: <b>Pablo Gonzalez</b>.
            </p>
          </div>
          <div style="display:flex;gap:8px;flex-wrap:wrap">
            <button class="g" id="btnWAComms" style="background:rgba(37,211,102,.12);border-color:#25d366;color:#25d366;font-weight:700">
              💬 Enviar Estado a Pablo por WhatsApp
            </button>
            <button id="btnLiquidateGregory" style="background:linear-gradient(135deg,#00f5a0,#00d98b);color:#000;font-weight:800;border:none;padding:7px 14px;border-radius:8px">
              💳 Liquidar a Gregory (Personal)
            </button>
            <button id="btnDoLiquidation" style="background:linear-gradient(135deg,#ffb703,#fb8500);color:#000;font-weight:800;border:none;padding:7px 14px;border-radius:8px">
              ${selectedIds.size > 0 ? `💳 Liquidar a Pablo (${selectedIds.size})` : '💳 Liquidar a Pablo (Socio)'}
            </button>
          </div>
        </div>

        <!-- Banner de Inicio Oficial de Operaciones en Plataforma -->
        <div style="background:rgba(0,245,160,.06);border:1px solid rgba(0,245,160,.25);padding:10px 14px;border-radius:10px;margin-bottom:16px;font-size:.82rem;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:8px">
          <div style="display:flex;align-items:center;gap:8px">
            <span style="font-size:1.1rem">🚀</span>
            <span><b>Puesta en Marcha Oficial:</b> El conteo de comisiones en la plataforma inicia el <b>16 de Octubre de 2026</b> con las transacciones reales. Todo lo anterior fue cancelado y saldado externamente.</span>
          </div>
          <span class="pill" style="font-size:.7rem;background:rgba(0,245,160,.15);color:#00f5a0;border-color:rgba(0,245,160,.3)">Corte Oficial 16/10/2026</span>
        </div>

        <!-- Tarjetas de Métricas Globales con Reserva Estratégica (10%) -->
        <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(185px, 1fr));gap:12px;margin-bottom:20px">
          <div class="card" style="border-color:rgba(255,183,3,.4);background:rgba(255,183,3,.04)">
            <div class="mut" style="font-size:.76rem;text-transform:uppercase;color:#fde047;font-weight:700">Comisión Socio (Pablo)</div>
            <div style="font-size:1.55rem;font-weight:800;color:#fde047;margin:6px 0 2px">$${totPendUsd.toFixed(2)}</div>
            <div class="mut" style="font-size:.76rem">Equiv: <b>Bs. ${totPendBs.toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</b></div>
            ${totRetenidoUsd > 0 ? `
              <div style="font-size:.68rem;color:#f87171;margin-top:4px;border-top:1px dashed rgba(255,255,255,.1);padding-top:4px" title="Comisiones retenidas porque la venta fue a crédito y aún no se concilia la cuota">
                ⏳ Retenido por cuotas en calle: <b>$${totRetenidoUsd.toFixed(2)}</b> (${retencionCreditoComms.length} ventas)
              </div>
            ` : ''}
          </div>
          ${pabloTotalDeuda > 0 ? `
            <div class="card" style="border-color:rgba(239,68,68,.4);background:rgba(239,68,68,.06)">
              <div class="mut" style="font-size:.76rem;text-transform:uppercase;color:#f87171;font-weight:700">💳 Deuda Crédito Pablo</div>
              <div style="font-size:1.55rem;font-weight:800;color:#f87171;margin:6px 0 2px">-$${pabloTotalDeuda.toFixed(2)}</div>
              <div class="mut" style="font-size:.74rem">
                ${pabloSaldoNetoUsd >= 0 ? `
                  <span style="color:#4ade80;font-weight:700">Neto liquidable: $${pabloSaldoNetoUsd.toFixed(2)} USD</span>
                ` : `
                  <span style="color:#ef4444;font-weight:700">Pablo adeuda neto: $${Math.abs(pabloSaldoNetoUsd).toFixed(2)} USD</span>
                `}
              </div>
              <div class="mut" style="font-size:.68rem;margin-top:2px">${pabloDebts.length} cuotas de crédito activas</div>
            </div>
          ` : ''}
          <div class="card" style="border-color:rgba(0,245,160,.4);background:rgba(0,245,160,.04)">
            <div class="mut" style="font-size:.76rem;text-transform:uppercase;color:#00f5a0;font-weight:700">Ganancia Gregory</div>
            <div style="font-size:1.55rem;font-weight:800;color:#00f5a0;margin:6px 0 2px">$${totGregUsd.toFixed(2)}</div>
            <div class="mut" style="font-size:.76rem">Equiv: <b style="color:#00f5a0">Bs. ${totGregBs.toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</b></div>
          </div>
          <div class="card" style="border-color:rgba(56,189,248,.4);background:rgba(56,189,248,.04)">
            <div class="mut" style="font-size:.76rem;text-transform:uppercase;color:#38bdf8;font-weight:700">Caja Negocio (90%)</div>
            <div style="font-size:1.55rem;font-weight:800;color:#38bdf8;margin:6px 0 2px">$${totCajaUsd.toFixed(2)}</div>
            <div class="mut" style="font-size:.76rem">Utilidad operativa disponible</div>
          </div>
          <div class="card" style="border-color:rgba(244,63,94,.4);background:rgba(244,63,94,.06)">
            <div class="mut" style="font-size:.76rem;text-transform:uppercase;color:#fb7185;font-weight:800">🛡️ Reserva Estratégica (10%)</div>
            <div style="font-size:1.55rem;font-weight:800;color:#fb7185;margin:6px 0 2px">$${totReservaUsd.toFixed(2)}</div>
            <div class="mut" style="font-size:.76rem">Fondo caídas y reposiciones</div>
          </div>
          <div class="card">
            <div class="mut" style="font-size:.76rem;text-transform:uppercase;font-weight:700">Total Ya Liquidado</div>
            <div style="font-size:1.55rem;font-weight:800;color:#94a3b8;margin:6px 0 2px">$${totLiqUsd.toFixed(2)}</div>
            <div class="mut" style="font-size:.76rem">Historial de cortes cerrados</div>
          </div>
        </div>

        <!-- Barra Dinámica de Selección Parcial -->
        ${selectedIds.size > 0 ? `
          <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;background:rgba(255,183,3,.08);border:1.5px solid rgba(255,183,3,.45);padding:12px 16px;border-radius:12px;margin-bottom:14px">
            <div>
              <b style="color:#fde047;font-size:.9rem">📌 ${selectedIds.size} comisiones seleccionadas para liquidar</b>
              <div style="display:flex;gap:16px;flex-wrap:wrap;margin-top:6px;font-size:.82rem">
                <div>
                  <span class="mut">A Pagar a Pablo (Socio):</span>
                  <b style="color:#fde047;font-size:.95rem">$${selTotUsd.toFixed(2)} USD</b>
                  <span class="mut">(Bs. ${selTotBs.toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})})</span>
                </div>
                <div style="border-left:1px solid rgba(255,255,255,.15);padding-left:14px">
                  <span class="mut">Ganancia Personal Gregory:</span>
                  <b style="color:#00f5a0;font-size:.95rem">$${selGregUsd.toFixed(2)} USD</b>
                  <span class="mut">(Bs. ${selGregBs.toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})})</span>
                </div>
              </div>
            </div>
            <div style="display:flex;gap:8px;flex-wrap:wrap">
              <button class="g" id="btnClearSelection" style="padding:6px 12px;font-size:.78rem">Deseleccionar</button>
              <button id="btnQuickLiquidateGregory" style="background:linear-gradient(135deg,#00f5a0,#00d98b);color:#000;font-weight:800;border:none;padding:7px 14px;border-radius:8px">
                💳 Liquidar a Gregory ($${selGregUsd.toFixed(2)})
              </button>
              <button id="btnQuickLiquidateSelected" style="background:linear-gradient(135deg,#ffb703,#fb8500);color:#000;font-weight:800;border:none;padding:7px 14px;border-radius:8px">
                💳 Liquidar a Pablo ($${selTotUsd.toFixed(2)})
              </button>
            </div>
          </div>
        ` : ''}

        <!-- Filtros Rápidos -->
        <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:14px;background:rgba(255,255,255,.02);padding:10px 14px;border-radius:12px;border:1px solid rgba(255,255,255,.06)">
          <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap">
            <label class="mut" style="font-size:.8rem">Socio Oficial:</label>
            <select id="selFilterSeller" style="padding:6px 12px;font-size:.82rem;background:rgba(3,8,18,.8);border-radius:8px;border:1px solid rgba(255,183,3,.4);color:#fde047;font-weight:700" disabled>
              <option value="${pabloSocio.id || ''}">💼 ${esc(pabloSocio.nombre || 'Pablo Gonzalez')} (Socio Oficial - ${esc(pabloSocio.codigo_identificacion || 'RVD:1001')})</option>
            </select>

            <label class="mut" style="font-size:.8rem;margin-left:8px">Origen / Concepto:</label>
            <select id="selFilterConcepto" style="padding:6px 10px;font-size:.82rem;background:rgba(3,8,18,.8);border-radius:8px">
              <option value="todos" ${filterConcepto === 'todos' ? 'selected' : ''}>Todos los Conceptos</option>
              <option value="autogestion_bs" ${filterConcepto === 'autogestion_bs' ? 'selected' : ''}>🛒 Directo Tienda / Autogestión</option>
              <option value="otro_revendedor" ${filterConcepto === 'otro_revendedor' ? 'selected' : ''}>🤝 Por Concepto de Revendedores</option>
              <option value="binance_usdt" ${filterConcepto === 'binance_usdt' ? 'selected' : ''}>🟡 Ventas Binance USDT</option>
            </select>

            <label class="mut" style="font-size:.8rem;margin-left:8px">Período:</label>
            <select id="selFilterPeriodo" style="padding:6px 10px;font-size:.82rem;background:rgba(3,8,18,.8);border-radius:8px;border:1px solid rgba(0,245,160,.35);color:#00f5a0;font-weight:700">
              <option value="lanzamiento" ${filterPeriodo === 'lanzamiento' ? 'selected' : ''}>🚀 Desde Puesta en Marcha (16/10/2026)</option>
              <option value="todos" ${filterPeriodo === 'todos' ? 'selected' : ''}>📜 Todo el Historial (Pre-lanzamiento)</option>
            </select>

            <label class="mut" style="font-size:.8rem;margin-left:8px">Estado:</label>
            <select id="selFilterStatus" style="padding:6px 10px;font-size:.82rem;background:rgba(3,8,18,.8);border-radius:8px">
              <option value="todos" ${filterStatus === 'todos' ? 'selected' : ''}>Todos los Estados</option>
              <option value="pendiente" ${filterStatus === 'pendiente' ? 'selected' : ''}>🟡 Solo Pendientes</option>
              <option value="liquidada" ${filterStatus === 'liquidada' ? 'selected' : ''}>🟢 Solo Liquidadas</option>
            </select>
          </div>
          <div class="mut" style="font-size:.8rem">
            Mostrando <b>${filtered.length}</b> registros de comisión
          </div>
        </div>

        <!-- Tabla Detallada con Selección por Checkbox -->
        <div class="wrap">
          <table>
            <thead>
              <tr>
                <th style="width:36px;text-align:center">
                  <input type="checkbox" id="chkAllComms" title="Seleccionar todas las comisiones pendientes visibles">
                </th>
                <th>Fecha</th>
                <th>Concepto / Origen</th>
                <th>Cliente</th>
                <th>Servicio</th>
                <th>Cobrado</th>
                <th>Comisión Pablo</th>
                <th>Gregory</th>
                <th>Caja Neg. (90%)</th>
                <th>🛡️ Reserva (10%)</th>
                <th>Estado</th>
              </tr>
            </thead>
            <tbody>
              ${filtered.length ? filtered.map(c => {
                const isPend = c.estado === 'pendiente';
                const isBin = c.metodo_origen === 'binance' || c.tipo_venta === 'binance_usdt';
                const cCaja = Number(c.caja_negocio_usd || (Number(c.ganancia_negocio_usd || 0) * 0.90));
                const cRes = Number(c.reserva_estrategica_usd || (Number(c.ganancia_negocio_usd || 0) * 0.10));
                const cNom = c.customers?.nombre || c.customers?.email || 'Cliente';
                
                // Concepto / Origen Badge
                let conceptoBadge = '';
                if (c.tipo_venta === 'otro_revendedor' || (c.vendedor_id && c.vendedor_id !== pabloSocio.id)) {
                  const rNom = c.vendedor?.nombre || c.vendedor?.codigo_identificacion || 'Revendedor';
                  conceptoBadge = `<span class="pill" style="font-size:.68rem;background:rgba(168,85,247,.15);color:#c084fc;border-color:rgba(168,85,247,.3)">🤝 Revendedor: ${esc(rNom)}</span>`;
                } else if (isBin) {
                  conceptoBadge = `<span class="pill" style="font-size:.68rem;background:rgba(234,179,8,.15);color:#fde047;border-color:rgba(234,179,8,.3)">🟡 Binance USDT</span>`;
                } else {
                  conceptoBadge = `<span class="pill" style="font-size:.68rem;background:rgba(56,189,248,.12);color:#38bdf8;border-color:rgba(56,189,248,.3)">🛒 Autogestión Tienda</span>`;
                }

                const isChecked = selectedIds.has(c.id);

                return `
                  <tr style="${isChecked ? 'background:rgba(255,183,3,.06)' : ''}">
                    <td style="text-align:center">
                      ${c.isCreditPending ? `
                        <input type="checkbox" disabled title="Orden a crédito: cuota de crédito pendiente por cobrar en calle ($${c.creditPendingUsd.toFixed(2)} USD). Al conciliarse la cuota, se habilitará para liquidar." style="opacity:.25;cursor:not-allowed">
                      ` : `
                        <input type="checkbox" class="chk-single-comm" data-id="${c.id}" ${isChecked ? 'checked' : ''} ${!isPend ? 'disabled style="opacity:.3"' : ''}>
                      `}
                    </td>
                    <td style="font-size:.76rem;color:#94a3b8">${(c.created_at || '').slice(0, 10)}</td>
                    <td>${conceptoBadge}</td>
                    <td>${esc(cNom)}</td>
                    <td><b>${esc(c.servicio_nombre)}</b></td>
                    <td>$${Number(c.monto_cobrado_usd).toFixed(2)}</td>
                    <td style="color:#fde047;font-weight:800">
                      +$${Number(c.ganancia_vendedor_usd).toFixed(2)}
                      <div style="font-size:.72rem;color:${isBin ? '#fde047' : '#94a3b8'};font-weight:400">
                        ${isBin ? 'USDT' : 'Bs. ' + Number(c.ganancia_vendedor_bs || (c.ganancia_vendedor_usd * curRate)).toFixed(2)}
                      </div>
                    </td>
                    <td style="color:#00f5a0;font-weight:700">+$${Number(c.ganancia_gregory_usd).toFixed(2)}</td>
                    <td style="color:#38bdf8;font-weight:600">+$${cCaja.toFixed(2)}</td>
                    <td style="color:#fb7185;font-weight:700">+$${cRes.toFixed(2)}</td>
                    <td>
                      ${c.isCreditPending ? `
                        <span class="pill" style="font-size:.68rem;background:rgba(239,68,68,.15);color:#f87171;border-color:rgba(239,68,68,.3)" title="Cuota de crédito pendiente por cobrar">
                          ⏳ Cuota en Calle ($${c.creditPendingUsd.toFixed(2)})
                        </span>
                      ` : c.isCreditSale ? `
                        <span class="pill" style="font-size:.68rem;background:rgba(34,197,94,.12);color:#4ade80;border-color:rgba(34,197,94,.3)" title="Cuota conciliada y cobrada">
                          ${isPend ? '🟢 Lista (Cuota Cobrada)' : '🟢 Liquidada'}
                        </span>
                      ` : `
                        <span class="pill" style="font-size:.7rem;${isPend ? 'background:rgba(234,179,8,.15);color:#fde047;border-color:rgba(234,179,8,.3)' : 'background:rgba(0,245,160,.12);color:#00f5a0;border-color:rgba(0,245,160,.3)'}">
                          ${isPend ? '🟡 Pendiente' : '🟢 Liquidada'}
                        </span>
                      `}
                    </td>
                  </tr>
                `;
              }).join('') : `
                <tr>
                  <td colspan="11" style="text-align:center;padding:24px" class="mut">
                    No hay comisiones registradas con los filtros seleccionados.
                  </td>
                </tr>
              `}
            </tbody>
          </table>
        </div>
      `;

      // Eventos de Filtro
      const pSel = $('#selFilterPeriodo');
      if (pSel) pSel.onchange = (e) => { filterPeriodo = e.target.value; render(); };
      const cSel = $('#selFilterConcepto');
      if (cSel) cSel.onchange = (e) => { filterConcepto = e.target.value; render(); };
      const stSel = $('#selFilterStatus');
      if (stSel) stSel.onchange = (e) => { filterStatus = e.target.value; render(); };

      // Checkbox Maestro (Seleccionar/Deseleccionar todas las pendientes visibles que NO estén retenidas por cuotas)
      const chkMaster = $('#chkAllComms');
      if (chkMaster) {
        const visiblePending = filtered.filter(c => c.estado === 'pendiente' && !c.isCreditPending);
        chkMaster.checked = visiblePending.length > 0 && visiblePending.every(c => selectedIds.has(c.id));
        chkMaster.onchange = (e) => {
          if (e.target.checked) {
            visiblePending.forEach(c => selectedIds.add(c.id));
          } else {
            visiblePending.forEach(c => selectedIds.delete(c.id));
          }
          render();
        };
      }

      // Checkboxes individuales
      box.querySelectorAll('.chk-single-comm').forEach(chk => {
        chk.onchange = (e) => {
          const id = e.target.dataset.id;
          if (e.target.checked) selectedIds.add(id);
          else selectedIds.delete(id);
          render();
        };
      });

      // Botón Limpiar Selección
      const btnClear = $('#btnClearSelection');
      if (btnClear) {
        btnClear.onclick = () => {
          selectedIds.clear();
          render();
        };
      }

      // Función disparadora del modal de liquidación (Socio Pablo o Personal Gregory)
      const triggerLiquidationModal = (idsToPay, beneficiary = 'pablo') => {
        const isGregory = beneficiary === 'gregory';
        const targetComms = allComms.filter(c => idsToPay.includes(c.id));
        if (!targetComms.length) {
          return toast('No hay comisiones seleccionadas para liquidar.');
        }

        const sTotUsd = targetComms.reduce((a, c) => a + Number(isGregory ? (c.ganancia_gregory_usd || 0) : (c.ganancia_vendedor_usd || 0)), 0);
        const sTotBs = targetComms.reduce((a, c) => a + Number(isGregory 
          ? (c.ganancia_gregory_bs || (c.ganancia_gregory_usd * curRate) || 0)
          : (c.ganancia_vendedor_bs || (c.ganancia_vendedor_usd * curRate) || 0)), 0);

        const maxCompensacion = (!isGregory && pabloTotalDeuda > 0) ? Math.min(sTotUsd, pabloTotalDeuda) : 0;
        const netoInicial = (!isGregory && pabloTotalDeuda > 0) ? Math.max(0, sTotUsd - pabloTotalDeuda) : sTotUsd;
        const netoInicialBs = netoInicial * curRate;

        $('#dlgBody').innerHTML = `
          <h3>${isGregory ? '💳 Liquidar Ganancia Personal de Gregory' : '✅ Registrar Liquidación y Pago a Socio (Pablo)'}</h3>
          <p class="mut" style="font-size:.84rem;margin:0 0 14px">
            ${isGregory 
              ? `Registrar pago de utilidades personales a cuenta bancaria de Gregory (${targetComms.length} ventas seleccionadas).`
              : `Se marcarán como pagadas las comisiones de Pablo Gonzalez (${targetComms.length} ventas seleccionadas).`}
          </p>
          <div style="background:rgba(255,255,255,.04);padding:14px;border-radius:12px;border:1px solid rgba(255,255,255,.1);margin-bottom:14px">
            <div style="display:flex;justify-content:space-between;margin-bottom:8px">
              <span class="mut" style="font-size:.82rem">Destinatario:</span>
              <b>${isGregory ? '👑 Gregory Izquierdo (Cuenta Personal)' : esc(pabloSocio.nombre || 'Pablo Gonzalez')}</b>
            </div>
            <div style="display:flex;justify-content:space-between;margin-bottom:8px">
              <span class="mut" style="font-size:.82rem">Ventas Seleccionadas:</span>
              <b style="color:${isGregory ? '#00f5a0' : '#fde047'}">${targetComms.length} ventas</b>
            </div>
            <div style="display:flex;justify-content:space-between;margin-bottom:8px">
              <span class="mut" style="font-size:.82rem">Total Comisiones ($):</span>
              <b style="color:${isGregory ? '#00f5a0' : '#fde047'};font-size:1.15rem">$${sTotUsd.toFixed(2)} USD</b>
            </div>
            <div style="display:flex;justify-content:space-between">
              <span class="mut" style="font-size:.82rem">Total en Bolívares (Bs):</span>
              <b style="color:#00f5a0;font-size:1.15rem">Bs. ${sTotBs.toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</b>
            </div>
          </div>

          ${!isGregory && pabloTotalDeuda > 0 ? `
            <div style="background:rgba(239,68,68,.08);border:1.5px solid rgba(239,68,68,.3);padding:12px;border-radius:10px;margin-bottom:14px">
              <div style="display:flex;justify-content:space-between;align-items:center">
                <b style="color:#f87171">💳 Cruce de Cuentas: Créditos Activos de Pablo ($${pabloTotalDeuda.toFixed(2)} USD)</b>
                <span class="mut" style="font-size:.74rem">${pabloDebts.length} cuotas pendientes</span>
              </div>
              <p class="mut" style="font-size:.76rem;margin:6px 0 10px;line-height:1.4">
                Pablo tiene cuotas de crédito pendientes en la plataforma. Puedes compensar automáticamente esta deuda descontándola de sus comisiones por cobrar.
              </p>
              <label style="display:flex;align-items:center;gap:8px;font-size:.84rem;cursor:pointer">
                <input type="checkbox" id="chkCompensarDeuda" checked>
                <b>Cruzar y cancelar créditos de Pablo (-$${maxCompensacion.toFixed(2)} USD)</b>
              </label>
              <div id="boxNetoCompensado" style="margin-top:10px;padding-top:10px;border-top:1px dashed rgba(255,255,255,.15);display:flex;justify-content:space-between;align-items:center">
                <span class="mut" style="font-size:.82rem">Neto Real a Transferir a Pablo:</span>
                <b style="color:#fde047;font-size:1.15rem" id="lblNetoUsd">$${netoInicial.toFixed(2)} USD</b>
              </div>
              <div style="display:flex;justify-content:space-between;font-size:.76rem;color:#00f5a0;margin-top:2px">
                <span>Equivalente en Bolívares:</span>
                <b id="lblNetoBs">Bs. ${netoInicialBs.toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</b>
              </div>
            </div>
          ` : ''}

          <label class="mut" style="font-size:.8rem;display:block;margin-bottom:4px">Método de Pago / Destino:</label>
          <select id="selLiqMetodo" style="width:100%;margin-bottom:12px;padding:8px 10px;background:rgba(3,8,18,.8);border-radius:8px;border:1px solid rgba(255,255,255,.15);color:#fff">
            ${isGregory ? `
              <option value="Pago Móvil BNC Personal">Pago Móvil BNC Personal</option>
              <option value="Transferencia Bancaria BNC">Transferencia Bancaria BNC</option>
              <option value="Binance Pay USDT">Binance Pay USDT</option>
              <option value="Efectivo / Caja">Efectivo / Caja</option>
            ` : `
              <option value="Pago Móvil">Pago Móvil Banco Venezuela / Banesco</option>
              <option value="Binance Pay USDT">Binance Pay USDT</option>
              <option value="Transferencia Bancaria">Transferencia Bancaria</option>
              <option value="Efectivo / Acordado">Efectivo / Acordado</option>
            `}
          </select>
          <label class="mut" style="font-size:.8rem;display:block;margin-bottom:4px">Referencia de Pago / Comprobante:</label>
          <input id="inpLiqRef" placeholder="Ej: Pago Móvil #928374 / Binance Pay ID / Compensación" style="width:100%;margin-bottom:12px" required>
          <label class="mut" style="font-size:.8rem;display:block;margin-bottom:4px">Notas u Observaciones (opcional):</label>
          <input id="inpLiqNotas" placeholder="Ej: Pago quincenal de utilidades personales / Pago socio" style="width:100%;margin-bottom:14px">
          <div style="display:flex;gap:10px;justify-content:flex-end">
            <button class="g" onclick="dlg.close()">Cancelar</button>
            <button id="btnConfirmLiquidation" style="background:${isGregory ? 'linear-gradient(135deg,#00f5a0,#00d98b)' : 'linear-gradient(135deg,#ffb703,#fb8500)'};color:#000;font-weight:800;border:none">
              💾 Confirmar Liquidación Pagada
            </button>
          </div>
        `;

        const chkComp = $('#chkCompensarDeuda');
        if (chkComp) {
          chkComp.onchange = (e) => {
            const isComp = e.target.checked;
            const finalUsd = isComp ? Math.max(0, sTotUsd - pabloTotalDeuda) : sTotUsd;
            const finalBs = finalUsd * curRate;
            if ($('#lblNetoUsd')) $('#lblNetoUsd').textContent = `$${finalUsd.toFixed(2)} USD`;
            if ($('#lblNetoBs')) $('#lblNetoBs').textContent = `Bs. ${finalBs.toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
          };
        }

        dlg.showModal();

        $('#btnConfirmLiquidation').onclick = async () => {
          const ref = $('#inpLiqRef').value.trim();
          if (!ref) return toast('Ingresa el número de referencia bancaria o comprobante.');

          const metodo = $('#selLiqMetodo').value;
          const notas = $('#inpLiqNotas').value.trim();
          const btn = $('#btnConfirmLiquidation');
          btn.disabled = true;
          btn.textContent = '⏳ Procesando...';

          const doCompensate = !isGregory && $('#chkCompensarDeuda')?.checked;
          const compensatedDebts = [];
          if (doCompensate) {
            let remOffset = maxCompensacion;
            for (const debt of pabloDebts) {
              if (remOffset <= 0) break;
              const dMonto = Number(debt.monto_usd || 0);
              try {
                let { error: rpcErr } = await sb.rpc('approve_installment', { p_installment_id: debt.id });
                if (rpcErr) {
                  await sb.from('installments').update({
                    estado: 'pagada',
                    pagada_at: new Date().toISOString(),
                    referencia: (debt.referencia ? debt.referencia + ' · ' : '') + `Compensado Liq: ${ref}`
                  }).eq('id', debt.id);
                }
                compensatedDebts.push(debt);
              } catch(eComp) {
                console.warn('Error compensando cuota:', eComp);
              }
              remOffset -= dMonto;
            }
          }

          const finalUsdPaid = doCompensate ? Math.max(0, sTotUsd - pabloTotalDeuda) : sTotUsd;
          const finalBsPaid = finalUsdPaid * curRate;

          const updateData = isGregory ? {
            metodo_pago: metodo,
            pagado_gregory_usd: sTotUsd,
            pagado_gregory_bs: sTotBs,
            referencia_pago: ref,
            notas: notas || `Liquidado ganancia personal Gregory vía ${metodo}`
          } : {
            estado: 'liquidada',
            liquidada_at: new Date().toISOString(),
            metodo_pago: metodo,
            pagado_usd: finalUsdPaid,
            pagado_bs: finalBsPaid,
            referencia_pago: ref,
            notas: notas || (compensatedDebts.length > 0 
              ? `Liquidado a socio Pablo vía ${metodo}. Compensado -$${maxCompensacion.toFixed(2)} USD en ${compensatedDebts.length} créditos adeudados.`
              : `Liquidado a socio Pablo Gonzalez vía ${metodo}`)
          };

          const { error: updErr } = await sb.from('partner_commissions')
            .update(updateData)
            .in('id', targetComms.map(x => x.id));

          if (updErr) {
            btn.disabled = false;
            btn.textContent = '💾 Confirmar Liquidación Pagada';
            return toast('Error al registrar liquidación: ' + updErr.message);
          }

          toast(`Liquidación registrada con éxito (${isGregory ? 'Ganancia Gregory' : 'Socio Pablo'}). ${compensatedDebts.length > 0 ? `Se compensaron $${maxCompensacion.toFixed(2)} USD de créditos de Pablo.` : ''}`);
          selectedIds.clear();
          dlg.close();
          EXTRA.liquidaciones(box);
        };
      };

      // Botón Liquidar a Gregory (Encabezado)
      const bLiqGreg = $('#btnLiquidateGregory');
      if (bLiqGreg) {
        bLiqGreg.onclick = () => {
          const idsToPay = selectedIds.size > 0 
            ? Array.from(selectedIds) 
            : filtered.map(c => c.id);
          if (!idsToPay.length) return toast('No hay comisiones para liquidar a Gregory.');
          triggerLiquidationModal(idsToPay, 'gregory');
        };
      }

      // Botón Liquidar a Gregory (Barra rápida de selección)
      const bQuickGreg = $('#btnQuickLiquidateGregory');
      if (bQuickGreg) {
        bQuickGreg.onclick = () => {
          triggerLiquidationModal(Array.from(selectedIds), 'gregory');
        };
      }

      // Botón Liquidar a Pablo (Encabezado)
      const bDo = $('#btnDoLiquidation');
      if (bDo) {
        bDo.onclick = () => {
          const idsToPay = selectedIds.size > 0 
            ? Array.from(selectedIds) 
            : filtered.filter(c => c.estado === 'pendiente' && !c.isCreditPending).map(c => c.id);
          if (!idsToPay.length) {
            return toast('No hay comisiones pendientes y liberadas para liquidar a Pablo.');
          }
          triggerLiquidationModal(idsToPay, 'pablo');
        };
      }

      // Botón Liquidar a Pablo (Barra rápida de selección)
      const bQuick = $('#btnQuickLiquidateSelected');
      if (bQuick) {
        bQuick.onclick = () => {
          triggerLiquidationModal(Array.from(selectedIds), 'pablo');
        };
      }

      // Enviar Estado a WhatsApp (con las seleccionadas o todas las pendientes)
      const bWA = $('#btnWAComms');
      if (bWA) {
        bWA.onclick = () => {
          const targetSeller = pabloSocio;
          if (!targetSeller || !targetSeller.id) return toast('No se encontró el registro de Pablo Gonzalez.');

          const sComms = selectedIds.size > 0 
            ? allComms.filter(c => selectedIds.has(c.id) && c.estado === 'pendiente')
            : allComms.filter(c => c.estado === 'pendiente');

          if (!sComms.length) return toast('No hay comisiones pendientes para enviar.');

          const commsBs = sComms.filter(c => c.metodo_origen !== 'binance' && c.tipo_venta !== 'binance_usdt');
          const commsBin = sComms.filter(c => c.metodo_origen === 'binance' || c.tipo_venta === 'binance_usdt');

          const totUsd = sComms.reduce((a, c) => a + Number(c.ganancia_vendedor_usd || 0), 0);
          const totBs = commsBs.reduce((a, c) => a + Number(c.ganancia_vendedor_bs || (c.ganancia_vendedor_usd * curRate) || 0), 0);
          const totUsdt = commsBin.reduce((a, c) => a + Number(c.ganancia_vendedor_usd || 0), 0);

          const fechaHoy = new Date().toLocaleDateString('es-VE');
          const itemsTxt = sComms.slice(0, 15).map((x, i) => `  ${i + 1}. ${x.servicio_nombre} (${x.customers?.nombre || 'Cliente'}): +$${Number(x.ganancia_vendedor_usd).toFixed(2)} [${x.metodo_origen === 'binance' ? 'Binance USDT' : 'Bs.'}]${x.isCreditPending ? ' ⏳(Cuota en calle)' : ''}`).join('\n');

          let msg = `¡Hola ${targetSeller.nombre || 'Pablo'}! 👋 Te comparto tu *Corte de Liquidación de Comisiones* al ${fechaHoy}:\n\n` +
            `🛒 *Ventas Seleccionadas:* ${sComms.length}\n` +
            (itemsTxt ? `${itemsTxt}\n\n` : '') +
            (commsBs.length ? `🇻🇪 *Comisiones en Bolívares:* Bs. ${totBs.toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})} (Tasa BCV: ${curRate.toFixed(2)})\n` : '') +
            (commsBin.length ? `🟡 *Comisiones en Binance Pay (USDT):* $${totUsdt.toFixed(2)} USDT\n` : '') +
            `💵 *Total Bruto en Dólares:* $${totUsd.toFixed(2)} USD\n`;

          if (pabloTotalDeuda > 0) {
            const neto = totUsd - pabloTotalDeuda;
            msg += `\n💳 *Deudas por Créditos Pendientes:* -$${pabloTotalDeuda.toFixed(2)} USD (${pabloDebts.length} cuotas activas)\n` +
                   `👉 *Saldo Neto Liquidable:* ${neto >= 0 ? `*$${neto.toFixed(2)} USD* a tu favor` : `*$${Math.abs(neto).toFixed(2)} USD* a pagar a Gregory`}\n` +
                   (neto > 0 ? `🇻🇪 *Neto a Transferir en Bs:* Bs. ${(neto * curRate).toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}\n` : '');
          }

          msg += `\nAvísame para coordinar el pago o cruzar con tus créditos. ¡Seguimos creciendo socio! 🚀`;

          navigator.clipboard.writeText(msg).catch(() => {});

          const cleanTel = (targetSeller.telefono || '').replace(/\D/g, '');
          if (cleanTel) {
            const waUrl = `https://wa.me/${cleanTel.startsWith('58') ? cleanTel : ('58' + cleanTel.replace(/^0+/, ''))}?text=${encodeURIComponent(msg)}`;
            window.open(waUrl, '_blank');
          } else {
            toast('Comprobante copiado al portapapeles (el socio no tiene WhatsApp registrado).');
          }
        };
      }
    };

    render();
  },

  async gemini(box) {
    if (!box._chatHistory) {
      box._chatHistory = [];
    }
    const history = box._chatHistory;

    const renderChat = () => {
      const msgsHtml = history.length === 0 ? `
        <div class="ai-welcome">
          <div class="ai-welcome-sparkle">✨</div>
          <h3 style="margin:0 0 6px;font-size:1.3rem;background:linear-gradient(135deg,#00f5a0,#00d4ff);-webkit-background-clip:text;-webkit-text-fill-color:transparent">¿En qué puedo ayudarte hoy, Gregory?</h3>
          <p class="mut" style="font-size:.85rem;max-width:540px;margin:0 auto 20px;line-height:1.5">
            Soy tu Asistente de IA comercial impulsado por <b>Gemini 2.5 Flash</b>. Puedo redactar promociones de WhatsApp, mensajes de cobro, respuestas para reclamos o sugerir estrategias para tu tienda.
          </p>
          <div class="ai-prompts-grid">
            <button type="button" class="ai-prompt-chip" data-p="Redacta un mensaje de WhatsApp atractivo y con emojis para promocionar combos de pantallas de Netflix y Disney+ este fin de semana.">
              <span class="ai-chip-title">📢 Combo Fin de Semana</span>
              <span class="ai-chip-sub">Mensaje para WhatsApp y estados con emojis y llamado a la acción</span>
            </button>
            <button type="button" class="ai-prompt-chip" data-p="Escribe un mensaje de cobro muy educado, respetuoso pero firme para un cliente que tiene una cuota o crédito vencido en la plataforma.">
              <span class="ai-chip-title">💬 Recordatorio de Cobro</span>
              <span class="ai-chip-sub">Cobro respetuoso y formal para clientes en mora</span>
            </button>
            <button type="button" class="ai-prompt-chip" data-p="Redacta una respuesta amable y tranquilizadora para un cliente cuya pantalla presentó caída de acceso y le estamos reponiendo un nuevo PIN de inmediato.">
              <span class="ai-chip-title">🛡️ Reposición de PIN / Soporte</span>
              <span class="ai-chip-sub">Respuesta tranquilizadora ante fallas de proveedor</span>
            </button>
            <button type="button" class="ai-prompt-chip" data-p="Dame 3 estrategias comerciales rápidas y prácticas para incentivar a los clientes a comprar cuentas completas en lugar de solo pantallas individuales.">
              <span class="ai-chip-title">📊 Estrategia de Ventas</span>
              <span class="ai-chip-sub">Tácticas para potenciar venta de cuentas completas</span>
            </button>
          </div>
        </div>
      ` : `
        <div class="ai-messages-list" id="aiMsgList">
          ${history.map((m, i) => `
            <div class="ai-msg ${m.role}">
              <div class="ai-msg-avatar">${m.role === 'user' ? '👤' : '✨'}</div>
              <div class="ai-msg-bubble">
                <div class="ai-msg-header">
                  <span class="ai-msg-author">${m.role === 'user' ? 'Tú (Gregory)' : 'Gemini 2.5 Flash'}</span>
                  ${m.role === 'model' ? `<button class="ai-copy-btn" data-copy="${i}" title="Copiar texto al portapapeles">📋 Copiar</button>` : ''}
                </div>
                <div class="ai-msg-text">${esc(m.text).replace(/\n/g, '<br>')}</div>
              </div>
            </div>
          `).join('')}
          <div id="aiScrollAnchor"></div>
        </div>
      `;

      box.innerHTML = `
        <div class="ai-chat-container">
          <div class="ai-chat-header">
            <div class="ai-chat-header-brand">
              <span class="ai-badge-icon">✨</span>
              <div>
                <div class="ai-chat-title">Gemini AI Workspace</div>
                <div class="ai-chat-sub">Modelo activo: <b>Gemini 2.5 Flash</b> · Contexto Comercial</div>
              </div>
            </div>
            <div class="row" style="gap:8px">
              <span class="pill" style="font-size:.72rem;background:rgba(0,245,160,.12);color:#00f5a0;border:1px solid rgba(0,245,160,.3)">🟢 Conectado</span>
              <button class="g" id="aiClearBtn" type="button" style="padding:5px 10px;font-size:.75rem">🗑️ Limpiar Chat</button>
            </div>
          </div>

          <div class="ai-chat-body" id="aiChatBody">
            ${msgsHtml}
          </div>

          <div class="ai-chat-footer">
            <div class="ai-input-wrap">
              <textarea id="aiPromptInput" rows="1" placeholder="Pregúntale a Gemini algo o pídele una tarea... (Enter para enviar, Shift+Enter para nueva línea)"></textarea>
              <button id="aiSendBtn" type="button" title="Enviar mensaje">➤</button>
            </div>
            <div class="ai-input-hint">Presiona <b>Enter</b> para enviar · <b>Shift + Enter</b> para salto de línea</div>
          </div>
        </div>
      `;

      const input = $('#aiPromptInput');
      const sendBtn = $('#aiSendBtn');
      const clearBtn = $('#aiClearBtn');

      if (clearBtn) {
        clearBtn.onclick = () => {
          box._chatHistory = [];
          renderChat();
        };
      }

      box.querySelectorAll('.ai-copy-btn').forEach(btn => {
        btn.onclick = () => {
          const idx = Number(btn.dataset.copy);
          const txt = history[idx]?.text || '';
          navigator.clipboard.writeText(txt).then(() => toast('Texto copiado al portapapeles.'));
        };
      });

      box.querySelectorAll('.ai-prompt-chip').forEach(btn => {
        btn.onclick = () => {
          if (input) {
            input.value = btn.dataset.p;
            doSend();
          }
        };
      });

      const doSend = async () => {
        const text = (input?.value || '').trim();
        if (!text) return;
        input.value = '';
        input.style.height = 'auto';

        history.push({ role: 'user', text });
        renderChat();

        setTimeout(() => {
          const anc = $('#aiScrollAnchor');
          if (anc) anc.scrollIntoView({ behavior: 'smooth' });
        }, 50);

        const curSend = $('#aiSendBtn');
        if (curSend) curSend.disabled = true;

        const loadingDiv = document.createElement('div');
        loadingDiv.className = 'ai-msg model ai-typing';
        loadingDiv.innerHTML = `
          <div class="ai-msg-avatar">✨</div>
          <div class="ai-msg-bubble">
            <div class="ai-msg-text" style="color:#00d4ff">✨ Gemini está redactando respuesta…</div>
          </div>
        `;
        const bodyEl = $('#aiChatBody');
        const listEl = $('#aiMsgList') || bodyEl;
        listEl.appendChild(loadingDiv);
        loadingDiv.scrollIntoView({ behavior: 'smooth' });

        try {
          const contents = history.map(h => ({
            role: h.role === 'user' ? 'user' : 'model',
            parts: [{ text: h.text }]
          }));

          const r = await api('/api/gemini', { contents });
          loadingDiv.remove();
          history.push({ role: 'model', text: r.text || 'Sin respuesta generada.' });
          renderChat();
          setTimeout(() => {
            const anc = $('#aiScrollAnchor');
            if (anc) anc.scrollIntoView({ behavior: 'smooth' });
          }, 50);
        } catch (err) {
          loadingDiv.remove();
          history.push({ role: 'model', text: '⚠️ Error al consultar Gemini: ' + err.message });
          renderChat();
        }
      };

      if (sendBtn) sendBtn.onclick = doSend;
      if (input) {
        input.onkeydown = e => {
          if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            doSend();
          }
        };
        input.oninput = () => {
          input.style.height = 'auto';
          input.style.height = Math.min(input.scrollHeight, 140) + 'px';
        };
        input.focus();
      }
    };

    renderChat();
  },

  async importar(box) {
    const { data: prods } = await sb.from('products').select('id,nombre').order('nombre');
    box.innerHTML = `<p class="mut">Sube tu archivo Excel de control de cuentas (hoja unificada con columnas Servicio / Correo / Clave / Vence o formato tradicional por pestañas). Se procesa directamente en tu navegador de forma 100% segura; las claves y PIN se cifran al guardar. Las cuentas ya existentes se actualizan u omiten.</p><input type="file" id="xf" accept=".xlsx,.xls,.csv"><div id="pv"></div>`;
    $('#xf').onchange = async e => {
      try { await loadXLSX(); } catch (err) { return toast(err.message); }
      const wb = XLSX.read(await e.target.files[0].arrayBuffer(), { type: 'array', cellDates: true }), found = [];
      for (const name of wb.SheetNames) {
        const results = parseAnySheet(wb.Sheets[name], name.trim());
        if (Array.isArray(results)) {
          results.forEach(r => { if (r.profiles.length || r.mothers.length) found.push(r); });
        } else if (results.profiles.length || results.mothers.length) {
          found.push(results);
        }
      }
      $('#pv').innerHTML = found.length ? `<div class="wrap"><table><tr><th>Plataforma / Servicio</th><th>Cuentas</th><th>Vendidos</th><th>Libres (Stock)</th><th>Asignar a Producto</th></tr>${found.map((f, i) => {
        const bestPid = matchProduct(f.plataforma, prods || []);
        const disps = f.profiles.filter(p => p.estado === 'disponible').length;
        const vends = f.profiles.filter(p => p.estado === 'vendido').length;
        return `<tr><td><b>${esc(f.plataforma)}</b></td><td>${f.mothers.length}</td><td style="color:#f59e0b">${vends}</td><td style="color:#00f5a0">${disps}</td><td><select data-i="${i}"><option value="">(sin asignar)</option>${(prods || []).map(p => `<option value="${p.id}" ${p.id === bestPid ? 'selected' : ''}>${esc(p.nombre)}</option>`).join('')}</select></td></tr>`;
      }).join('')}</table></div><button id="im" style="margin-top:10px">Importar Inventario</button>` : '<p>No se encontraron datos reconocibles en el archivo (se buscan columnas de Servicio o Correo y Clave).</p>';
      if (found.length) $('#im').onclick = ev => run(ev.target, async () => {
        let nm = 0, np = 0; const { data: ex } = await sb.from('mother_accounts').select('id,plataforma,correo'); const key = (p, c) => (p || '').trim().toUpperCase() + '|' + (c || '').trim().toLowerCase(), ids = Object.fromEntries((ex || []).map(m => [key(m.plataforma, m.correo), m.id]));
        for (const [i, f] of found.entries()) {
          const pid = $(`[data-i="${i}"]`).value || null, add = f.mothers.filter(m => !ids[key(f.plataforma, m.correo)]);
          if (add.length) {
            const { data, error } = await sb.from('mother_accounts').insert(add).select('id,plataforma,correo');
            if (error) throw error;
            data.forEach(m => ids[key(m.plataforma, m.correo)] = m.id);
            nm += data.length;
          }
          const rows = f.profiles.map(p => ({
            mother_id: ids[key(f.plataforma, p.correo)],
            product_id: pid,
            nombre_perfil: p.perfil,
            pin: p.pin,
            vendedor: p.vendedor,
            inicia: p.inicia,
            vence: p.vence,
            estado: p.estado
          })).filter(r => r.mother_id);
          for (let k = 0; k < rows.length; k += 400) {
            const { error } = await sb.from('profiles_inventory').insert(rows.slice(k, k + 400));
            if (error) throw error;
            np += Math.min(400, rows.length - k);
          }
        }
        return `Importación completada: ${nm} cuentas madre registradas y ${np} perfiles en inventario.`;
      });
    };
  },

  async plantillas(box) {
    box.innerHTML = '<div style="padding:40px 10px;text-align:center"><div class="sk" style="max-width:300px;margin:auto"></div><p class="mut" style="margin-top:10px">Cargando plantillas de mensajes…</p></div>';

    let tpls = S.settings?.plantillas_mensajes;
    if(!tpls){
      const { data } = await sb.from('settings').select('value').eq('key', 'plantillas_mensajes').maybeSingle();
      if(data?.value && typeof data.value === 'object'){
        tpls = Object.assign({}, DEFAULT_MESSAGE_TEMPLATES, data.value);
      } else {
        tpls = JSON.parse(JSON.stringify(DEFAULT_MESSAGE_TEMPLATES));
      }
      S.settings = S.settings || {};
      S.settings.plantillas_mensajes = tpls;
    } else {
      tpls = Object.assign({}, DEFAULT_MESSAGE_TEMPLATES, tpls);
    }

    let activeChannelFilter = 'todos';

    const getSampleData = () => ({
      cliente: 'Carlos Pérez',
      codigo_id: 'CLT:0042',
      producto: 'Netflix 4K Ultra HD',
      servicio: 'Netflix 4K Ultra HD',
      correo: 'netflix.vip@ejemplo.com',
      clave: 'Stream2026*',
      perfil: 'Perfil 1 (Carlos)',
      pin: '4920',
      vence: '12/11/2026',
      fecha_vence: '12/11/2026',
      fecha_vencimiento: '12/11/2026',
      fecha_vence_credito: '19/10/2026',
      dias_credito: '7',
      cuota: '1',
      total_cuotas: '2',
      monto_usd: '15.00',
      monto_bs: '600.00',
      tasa_bcv: '40.00',
      garantia: '30',
      numero_tarjeta: '**** **** **** 8842',
      codigo_activacion: '782',
      numero_factura: 'FACT-000128',
      fecha: '12/10/2026',
      total_usd: '15.00',
      total_bs: '600.00',
      negocio: S.franchise?.nombre_comercial || S.settings?.negocio?.nombre || 'Emprendimiento Gregory Izquierdo',
      telefono_negocio: S.settings?.negocio?.telefono || '+584241983648',
      rif: S.settings?.negocio?.rif || 'J-50639379-4',
      portal_url: location.origin,
      estado: 'Activo',
      nuevo_balance: '45.00',
      tipo_operacion: 'Venta de USDT a Bolívares (Binance)',
      monto_usdt: '25.00',
      tasa_cambio: '879.12',
      motivo: 'Garantía por pantalla caída de proveedor',
      destino: 'Tarjeta Digital Zeny (Saldo a Favor)',
      operadora: 'Digitel',
      telefono_recarga: '04121234567',
      player_id: '192837465',
      nickname: 'GREGORY_PRO',
      usuario_247: 'pablo_recargas',
      nombre_punto: 'Inversiones Gonzalez',
      titular: 'Pablo Gonzalez',
      referencia: '00982341'
    });

    const formatSample = (raw) => {
      const sample = getSampleData();
      let text = raw || '';
      for(const [k, v] of Object.entries(sample)){
        text = text.split(`{${k}}`).join(String(v));
      }
      return text;
    };

    const render = () => {
      const allEntries = Object.entries(tpls);
      const filtered = activeChannelFilter === 'todos' 
        ? allEntries 
        : allEntries.filter(([_, t]) => (t.canal || 'whatsapp') === activeChannelFilter);

      const countWa = allEntries.filter(([_, t]) => (t.canal || 'whatsapp') === 'whatsapp').length;
      const countTg = allEntries.filter(([_, t]) => t.canal === 'telegram').length;
      const countEm = allEntries.filter(([_, t]) => t.canal === 'email').length;

      box.innerHTML = `
        <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;margin-bottom:18px">
          <div>
            <h3 style="margin:0;display:flex;align-items:center;gap:8px">💬 Plantillas de Mensajes Multicanal</h3>
            <p class="mut" style="font-size:.82rem;margin:4px 0 0">
              Personaliza el texto de los mensajes que se envían por WhatsApp, Telegram y correos. Inserta variables dinámicas como <code>{cliente}</code>, <code>{monto_usd}</code>, etc.
            </p>
          </div>
          <div class="row">
            <button id="btnResetTpls" class="g" style="font-size:.76rem;padding:6px 12px">🔄 Restaurar por Defecto</button>
            <button id="btnNewTpl" style="font-size:.76rem;padding:6px 14px">+ Nueva Plantilla</button>
          </div>
        </div>

        <!-- Filtros por canal -->
        <div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:18px;align-items:center">
          <button class="g chan-filter-btn ${activeChannelFilter==='todos'?'active':''}" data-chan="todos" style="padding:6px 14px;font-size:.78rem;border-radius:99px;font-weight:700">
            🌐 Todos (${allEntries.length})
          </button>
          <button class="g chan-filter-btn ${activeChannelFilter==='whatsapp'?'active':''}" data-chan="whatsapp" style="padding:6px 14px;font-size:.78rem;border-radius:99px;font-weight:700;color:#25d366;border-color:rgba(37,211,102,.4)">
            📱 WhatsApp (${countWa})
          </button>
          <button class="g chan-filter-btn ${activeChannelFilter==='telegram'?'active':''}" data-chan="telegram" style="padding:6px 14px;font-size:.78rem;border-radius:99px;font-weight:700;color:#0088cc;border-color:rgba(0,136,204,.4)">
            🤖 Telegram (${countTg})
          </button>
          <button class="g chan-filter-btn ${activeChannelFilter==='email'?'active':''}" data-chan="email" style="padding:6px 14px;font-size:.78rem;border-radius:99px;font-weight:700;color:#f59e0b;border-color:rgba(245,158,11,.4)">
            📧 Email / Otros (${countEm})
          </button>
        </div>

        <!-- Lista de plantillas en cuadrícula -->
        <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:16px">
          ${filtered.map(([key, tpl]) => {
            const ch = tpl.canal || 'whatsapp';
            const chBadge = ch === 'whatsapp'
              ? '<span class="chan-badge whatsapp">📱 WhatsApp</span>'
              : (ch === 'telegram' ? '<span class="chan-badge telegram">🤖 Telegram</span>' : '<span class="chan-badge email">📧 Email / Web</span>');

            const previewText = tpl.cuerpo.length > 140 ? tpl.cuerpo.slice(0, 140) + '…' : tpl.cuerpo;

            return `
              <div class="card" style="display:flex;flex-direction:column;justify-content:space-between;padding:18px;border-radius:16px;background:rgba(9,19,34,.7);border:1px solid rgba(255,255,255,.08)">
                <div>
                  <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:8px;margin-bottom:8px">
                    <b style="font-size:.92rem;color:var(--tx)">${esc(tpl.titulo || key)}</b>
                    ${chBadge}
                  </div>
                  <p class="mut" style="font-size:.76rem;margin:0 0 12px;line-height:1.4">${esc(tpl.descripcion || '')}</p>
                  
                  <div style="background:#070d14;border:1px solid #1a2838;border-radius:10px;padding:10px 12px;font-size:.78rem;color:#cbd5e1;font-family:monospace;white-space:pre-wrap;line-height:1.4;margin-bottom:12px;max-height:100px;overflow:hidden;position:relative">
                    ${esc(previewText)}
                  </div>

                  <div style="margin-bottom:14px">
                    <span style="font-size:.7rem;color:var(--mut);text-transform:uppercase;font-weight:700;display:block;margin-bottom:6px">Variables disponibles:</span>
                    <div style="display:flex;flex-wrap:wrap;gap:4px">
                      ${(tpl.tags || []).map(tag => `<span class="tpl-tag-chip" style="cursor:default">{${esc(tag)}}</span>`).join('')}
                    </div>
                  </div>
                </div>

                <div class="row" style="margin-top:auto;padding-top:10px;border-top:1px solid rgba(255,255,255,.06)">
                  <button class="g" data-preview-tpl="${esc(key)}" style="padding:6px 12px;font-size:.76rem;flex:1">👁️ Vista Previa</button>
                  <button data-edit-tpl="${esc(key)}" style="padding:6px 14px;font-size:.76rem;flex:1">✏️ Editar</button>
                </div>
              </div>
            `;
          }).join('')}
        </div>
      `;

      // Eventos de filtros
      box.querySelectorAll('.chan-filter-btn').forEach(btn => {
        btn.onclick = () => {
          activeChannelFilter = btn.dataset.chan;
          render();
        };
      });

      // Restaurar por defecto
      const bReset = box.querySelector('#btnResetTpls');
      if(bReset){
        bReset.onclick = () => run(bReset, async () => {
          if(!confirm('¿Estás seguro de restaurar todas las plantillas a los textos por defecto? Se perderán las modificaciones personalizadas.')) return;
          tpls = JSON.parse(JSON.stringify(DEFAULT_MESSAGE_TEMPLATES));
          const { error } = await sb.from('settings').upsert({
            key: 'plantillas_mensajes',
            value: tpls,
            updated_at: new Date().toISOString()
          });
          if(error) throw error;
          S.settings.plantillas_mensajes = tpls;
          render();
          return 'Plantillas restauradas a los valores por defecto.';
        });
      }

      // Crear nueva plantilla
      const bNew = box.querySelector('#btnNewTpl');
      if(bNew){
        bNew.onclick = () => openEditTplModal(null);
      }

      // Vista previa modal
      box.querySelectorAll('[data-preview-tpl]').forEach(btn => {
        btn.onclick = () => {
          const k = btn.dataset.previewTpl;
          const tpl = tpls[k];
          if(!tpl) return;
          openPreviewTplModal(tpl);
        };
      });

      // Editar plantilla modal
      box.querySelectorAll('[data-edit-tpl]').forEach(btn => {
        btn.onclick = () => {
          const k = btn.dataset.editTpl;
          openEditTplModal(k);
        };
      });
    };

    const openPreviewTplModal = (tpl) => {
      const formatted = formatSample(tpl.cuerpo || '');
      const ch = tpl.canal || 'whatsapp';

      $('#dlgBody').innerHTML = `
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
          <h3 style="margin:0">${esc(tpl.titulo)}</h3>
          <span class="chan-badge ${ch}">${ch.toUpperCase()}</span>
        </div>
        <p class="mut" style="font-size:.8rem;margin:0 0 12px">${esc(tpl.descripcion)}</p>

        <label class="mut" style="font-size:.74rem;text-transform:uppercase;font-weight:700;display:block;margin-bottom:6px">
          Vista previa renderizada en vivo (Burbuja ${ch === 'whatsapp' ? 'WhatsApp' : 'Telegram'}):
        </label>
        <div class="chat-preview-bubble" style="${ch==='telegram'?'background:#17212b;border-color:#242f3d':''}">
          ${esc(formatted)}
        </div>

        <div style="margin-top:16px;display:flex;gap:10px;flex-wrap:wrap">
          <button id="btnCopyPreview" class="g" style="flex:1;padding:8px 14px;font-size:.8rem">📋 Copiar Texto Renderizado</button>
        </div>
      `;
      dlg.showModal();

      const btnCp = $('#btnCopyPreview');
      if(btnCp){
        btnCp.onclick = async () => {
          try {
            await navigator.clipboard.writeText(formatted);
            btnCp.innerHTML = '✅ Copiado al portapapeles';
            setTimeout(() => btnCp.innerHTML = '📋 Copiar Texto Renderizado', 2000);
          } catch(e) {
            toast('Copia manual: ' + formatted);
          }
        };
      }
    };

    const openEditTplModal = (key) => {
      const isNew = !key;
      const tpl = !isNew ? (tpls[key] || {}) : {
        id: 'nueva_plantilla_' + Date.now(),
        canal: 'whatsapp',
        titulo: 'Nueva Plantilla',
        descripcion: 'Descripción del mensaje',
        tags: ['cliente', 'producto', 'monto_usd', 'portal_url', 'negocio'],
        cuerpo: 'Hola {cliente}! Te informamos sobre tu servicio de {producto}.\nMonto: ${monto_usd} USD.\nSaludos de {negocio}.'
      };

      const availableTags = Array.from(new Set([
        ...(tpl.tags || []),
        'cliente', 'codigo_id', 'producto', 'servicio', 'correo', 'clave', 'perfil', 'pin',
        'vence', 'fecha_vence', 'fecha_vencimiento', 'fecha_vence_credito', 'dias_credito',
        'cuota', 'total_cuotas', 'monto_usd', 'monto_bs', 'tasa_bcv', 'numero_factura',
        'numero_tarjeta', 'codigo_activacion', 'garantia', 'portal_url', 'negocio', 'rif',
        'nuevo_balance', 'tipo_operacion', 'monto_usdt', 'tasa_cambio', 'motivo', 'destino',
        'operadora', 'telefono_recarga', 'player_id', 'nickname', 'usuario_247', 'nombre_punto', 'titular', 'referencia'
      ]));

      $('#dlgBody').innerHTML = `
        <h3>${isNew ? '✨ Crear Nueva Plantilla' : '✏️ Editar Plantilla: ' + esc(tpl.titulo)}</h3>
        <p class="mut" style="font-size:.8rem;margin:0 0 12px">Edita el formato del mensaje y haz clic en las etiquetas para insertarlas directamente en el cursor.</p>

        <div style="display:grid;grid-template-columns:1fr 140px;gap:10px;margin-bottom:10px">
          <div>
            <label class="mut" style="font-size:.74rem">Título de la plantilla:</label>
            <input id="edTplTitle" value="${esc(tpl.titulo || '')}" style="margin-top:2px" required>
          </div>
          <div>
            <label class="mut" style="font-size:.74rem">Canal:</label>
            <select id="edTplChannel" style="margin-top:2px">
              <option value="whatsapp" ${tpl.canal==='whatsapp'?'selected':''}>WhatsApp</option>
              <option value="telegram" ${tpl.canal==='telegram'?'selected':''}>Telegram</option>
              <option value="email" ${tpl.canal==='email'?'selected':''}>Email / Web</option>
            </select>
          </div>
        </div>

        <div style="margin-bottom:10px">
          <label class="mut" style="font-size:.74rem">Descripción de uso / disparador:</label>
          <input id="edTplDesc" value="${esc(tpl.descripcion || '')}" style="margin-top:2px">
        </div>

        <div style="margin-bottom:8px">
          <label class="mut" style="font-size:.74rem;display:flex;justify-content:space-between">
            <span>Tags dinámicos (toca uno para insertarlo):</span>
            <span style="color:var(--c)">{variable}</span>
          </label>
          <div id="edTplTagsBox" style="display:flex;flex-wrap:wrap;gap:5px;margin-top:4px;max-height:85px;overflow-y:auto;background:rgba(0,0,0,.25);padding:6px;border-radius:8px">
            ${availableTags.map(t => `<button type="button" class="tpl-tag-chip" data-insert-tag="${esc(t)}">+{${esc(t)}}</button>`).join('')}
          </div>
        </div>

        <div style="margin-bottom:12px">
          <label class="mut" style="font-size:.74rem">Cuerpo del mensaje:</label>
          <textarea id="edTplBody" rows="8" style="font-family:monospace;font-size:.84rem;line-height:1.45;margin-top:4px;resize:vertical">${esc(tpl.cuerpo || '')}</textarea>
        </div>

        <div style="margin-bottom:14px">
          <label class="mut" style="font-size:.74rem;text-transform:uppercase;font-weight:700;display:block;margin-bottom:4px">Vista previa en tiempo real:</label>
          <div id="edTplPreview" class="chat-preview-bubble" style="max-height:140px;overflow-y:auto">
            ${esc(formatSample(tpl.cuerpo || ''))}
          </div>
        </div>

        <div class="row" style="justify-content:flex-end;gap:10px">
          ${!isNew && !DEFAULT_MESSAGE_TEMPLATES[key] ? `<button id="btnDeleteTpl" class="d" style="padding:8px 14px;font-size:.8rem;margin-right:auto">Borrar Plantilla</button>` : ''}
          <button id="btnSaveTpl" style="padding:8px 18px;font-size:.82rem;font-weight:700">💾 Guardar Cambios</button>
        </div>
      `;
      dlg.showModal();

      const ta = $('#edTplBody');
      const prevBox = $('#edTplPreview');

      ta.oninput = () => {
        prevBox.textContent = formatSample(ta.value);
      };

      $('#edTplTagsBox').querySelectorAll('[data-insert-tag]').forEach(btnTag => {
        btnTag.onclick = () => {
          const tag = `{${btnTag.dataset.insertTag}}`;
          const start = ta.selectionStart || ta.value.length;
          const end = ta.selectionEnd || ta.value.length;
          const val = ta.value;
          ta.value = val.substring(0, start) + tag + val.substring(end);
          ta.selectionStart = ta.selectionEnd = start + tag.length;
          ta.focus();
          prevBox.textContent = formatSample(ta.value);
        };
      });

      $('#btnSaveTpl').onclick = () => run($('#btnSaveTpl'), async () => {
        const titleVal = $('#edTplTitle')?.value?.trim();
        const bodyVal = $('#edTplBody')?.value?.trim();
        const descVal = $('#edTplDesc')?.value?.trim();
        const chanVal = $('#edTplChannel')?.value;

        if(!titleVal) throw new Error('El título es requerido.');
        if(!bodyVal) throw new Error('El cuerpo del mensaje no puede estar vacío.');

        const finalKey = key || titleVal.toLowerCase().replace(/[^a-z0-9]+/g, '_');
        
        const matches = bodyVal.match(/\{([a-zA-Z0-9_]+)\}/g) || [];
        const usedTags = Array.from(new Set(matches.map(m => m.slice(1, -1))));

        tpls[finalKey] = {
          id: finalKey,
          canal: chanVal,
          titulo: titleVal,
          descripcion: descVal,
          tags: usedTags.length ? usedTags : (tpl.tags || []),
          cuerpo: bodyVal
        };

        const { error } = await sb.from('settings').upsert({
          key: 'plantillas_mensajes',
          value: tpls,
          updated_at: new Date().toISOString()
        });
        if(error) throw error;

        S.settings.plantillas_mensajes = tpls;
        dlg.close();
        render();
        return 'Plantilla guardada exitosamente.';
      });

      const bDel = $('#btnDeleteTpl');
      if(bDel){
        bDel.onclick = () => run(bDel, async () => {
          if(!confirm(`¿Eliminar la plantilla "${tpl.titulo}"?`)) return;
          delete tpls[key];
          const { error } = await sb.from('settings').upsert({
            key: 'plantillas_mensajes',
            value: tpls,
            updated_at: new Date().toISOString()
          });
          if(error) throw error;
          S.settings.plantillas_mensajes = tpls;
          dlg.close();
          render();
          return 'Plantilla eliminada.';
        });
      }
    };

    render();
  },

  async niveles(box) {
    box.innerHTML = '<div style="padding:40px 10px;text-align:center"><div class="sk" style="max-width:300px;margin:auto"></div><p class="mut" style="margin-top:10px">Cargando niveles y beneficios…</p></div>';

    let niveles = S.settings?.niveles_beneficios;
    if(!niveles){
      const { data } = await sb.from('settings').select('value').eq('key', 'niveles_beneficios').maybeSingle();
      if(data?.value && typeof data.value === 'object'){
        niveles = data.value;
      } else {
        niveles = JSON.parse(JSON.stringify(DEFAULT_NIVELES_BENEFICIOS));
      }
      S.settings = S.settings || {};
      S.settings.niveles_beneficios = niveles;
    }

    const render = () => {
      const keys = ['cliente', 'revendedor', 'franquiciado'];

      box.innerHTML = `
        <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;margin-bottom:18px">
          <div>
            <h3 style="margin:0;display:flex;align-items:center;gap:8px">🎖️ Configuración de Niveles & Beneficios</h3>
            <p class="mut" style="font-size:.82rem;margin:4px 0 0">
              Personaliza el nombre de cada nivel de usuario, su código de identificación, margen/descuento comercial y los beneficios tangibles visibles en el portal del cliente.
            </p>
          </div>
          <div class="row">
            <button id="btnResetNiveles" class="g" style="font-size:.76rem;padding:6px 12px">🔄 Restaurar Niveles</button>
            <button id="btnCompModal" class="g" style="font-size:.76rem;padding:6px 14px">📊 Comparativa Completa</button>
          </div>
        </div>

        <div class="level-grid">
          ${keys.map(k => {
            const lvl = niveles[k] || DEFAULT_NIVELES_BENEFICIOS[k];
            if(!lvl) return '';
            const color = lvl.color || '#00d4ff';
            const benefits = lvl.beneficios || [];

            return `
              <div class="level-card" style="border-color:${color}44">
                <div class="level-card-top" style="background:${color}"></div>
                <div>
                  <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:8px;margin-bottom:6px">
                    <span style="font-size:1.8rem">${lvl.badge_icon || '👤'}</span>
                    <span class="pill" style="font-size:.72rem;background:${color}22;color:${color};border:1px solid ${color}55;font-weight:800">
                      ID: <b>${esc(lvl.prefijo_codigo || 'CLT')}:XXXX</b>
                    </span>
                  </div>

                  <h3 style="margin:0 0 4px;font-size:1.15rem;color:var(--tx)">${esc(lvl.nombre)}</h3>
                  <p class="mut" style="font-size:.78rem;margin:0 0 12px;line-height:1.4">${esc(lvl.subtitulo || '')}</p>

                  <div style="background:rgba(0,0,0,.3);border:1px solid rgba(255,255,255,.07);border-radius:10px;padding:10px;margin-bottom:14px;display:flex;flex-direction:column;gap:6px;font-size:.76rem">
                    <div style="display:flex;justify-content:space-between">
                      <span class="mut">Margen / Descuento:</span>
                      <b style="color:${color}">${esc(lvl.descuento_porcentaje)}</b>
                    </div>
                    <div style="display:flex;justify-content:space-between">
                      <span class="mut">Requisito de acceso:</span>
                      <span style="color:#cbd5e1;text-align:right">${esc(lvl.requisito_acceso)}</span>
                    </div>
                  </div>

                  <div>
                    <span style="font-size:.72rem;color:var(--mut);text-transform:uppercase;font-weight:700;display:block;margin-bottom:8px">
                      Beneficios Activos (${benefits.length}):
                    </span>
                    <div class="level-benefit-list">
                      ${benefits.map(b => `
                        <div class="level-benefit-item">
                          <span class="level-benefit-icon" style="color:${color}">${b.icono || '✓'}</span>
                          <div>
                            <div style="font-weight:700;color:var(--tx)">${esc(b.titulo)}</div>
                            <div class="mut" style="font-size:.74rem">${esc(b.descripcion)}</div>
                          </div>
                        </div>
                      `).join('')}
                    </div>
                  </div>
                </div>

                <div style="margin-top:18px;padding-top:12px;border-top:1px solid rgba(255,255,255,.07)">
                  <button data-edit-level="${esc(k)}" style="width:100%;padding:8px 12px;font-size:.8rem;font-weight:700;background:linear-gradient(135deg,${color}33,${color}55);color:#fff;border:1px solid ${color}88">
                    ✏️ Configurar Nivel & Beneficios
                  </button>
                </div>
              </div>
            `;
          }).join('')}
        </div>
      `;

      const bComp = box.querySelector('#btnCompModal');
      if(bComp){
        bComp.onclick = () => openComparisonModal();
      }

      const bRes = box.querySelector('#btnResetNiveles');
      if(bRes){
        bRes.onclick = () => run(bRes, async () => {
          if(!confirm('¿Restaurar la configuración de los 3 niveles a los valores predeterminados?')) return;
          niveles = JSON.parse(JSON.stringify(DEFAULT_NIVELES_BENEFICIOS));
          const { error } = await sb.from('settings').upsert({
            key: 'niveles_beneficios',
            value: niveles,
            updated_at: new Date().toISOString()
          });
          if(error) throw error;
          S.settings.niveles_beneficios = niveles;
          render();
          return 'Niveles restaurados correctamente.';
        });
      }

      box.querySelectorAll('[data-edit-level]').forEach(btn => {
        btn.onclick = () => {
          const k = btn.dataset.editLevel;
          openEditLevelModal(k);
        };
      });
    };

    const openComparisonModal = () => {
      const keys = ['cliente', 'revendedor', 'franquiciado'];
      $('#dlgBody').innerHTML = `
        <h3>📊 Comparativa Oficial de Niveles</h3>
        <p class="mut" style="font-size:.82rem;margin:0 0 14px">Resumen comparativo que orienta a los usuarios hacia el crecimiento y la adquisición de servicios mayoristas.</p>

        <div style="overflow-x:auto">
          <table class="level-comp-table">
            <thead>
              <tr>
                <th>Característica</th>
                ${keys.map(k => {
                  const lvl = niveles[k];
                  return `<th style="color:${lvl.color}">${lvl.badge_icon || '•'} ${esc(lvl.nombre)}</th>`;
                }).join('')}
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><b>Prefijo de Código</b></td>
                ${keys.map(k => `<td><code>${esc(niveles[k].prefijo_codigo)}:XXXX</code></td>`).join('')}
              </tr>
              <tr>
                <td><b>Margen / Tarifas</b></td>
                ${keys.map(k => `<td style="color:${niveles[k].color};font-weight:700">${esc(niveles[k].descuento_porcentaje)}</td>`).join('')}
              </tr>
              <tr>
                <td><b>Requisito de Entrada</b></td>
                ${keys.map(k => `<td class="mut">${esc(niveles[k].requisito_acceso)}</td>`).join('')}
              </tr>
              <tr>
                <td><b>Tarjeta Zeny Digital</b></td>
                <td>✓ Sí, vinculada a billetera</td>
                <td>✓ Sí + crédito disponible</td>
                <td>✓ Facturación corporativa</td>
              </tr>
              <tr>
                <td><b>Reenvío Limpio Credenciales</b></td>
                <td class="mut">—</td>
                <td>✓ Sí (Botón 1 clic)</td>
                <td>✓ Sí (Automatizado)</td>
              </tr>
              <tr>
                <td><b>Tienda Web Propia SaaS</b></td>
                <td class="mut">—</td>
                <td class="mut">—</td>
                <td style="color:#a855f7;font-weight:700">✓ Sí (Subdominio y marca)</td>
              </tr>
            </tbody>
          </table>
        </div>
      `;
      dlg.showModal();
    };

    const openEditLevelModal = (key) => {
      const lvl = JSON.parse(JSON.stringify(niveles[key] || DEFAULT_NIVELES_BENEFICIOS[key]));
      lvl.beneficios = lvl.beneficios || [];

      const renderLevelForm = () => {
        $('#dlgBody').innerHTML = `
          <h3>✏️ Editar Nivel: ${esc(lvl.nombre)}</h3>
          <p class="mut" style="font-size:.8rem;margin:0 0 12px">Configura la identidad del nivel y administra los beneficios que ven los usuarios.</p>

          <div style="display:grid;grid-template-columns:1fr 100px 90px;gap:10px;margin-bottom:10px">
            <div>
              <label class="mut" style="font-size:.74rem">Nombre oficial del nivel:</label>
              <input id="edLvlName" value="${esc(lvl.nombre)}" style="margin-top:2px" required>
            </div>
            <div>
              <label class="mut" style="font-size:.74rem">Prefijo ID:</label>
              <input id="edLvlPrefix" value="${esc(lvl.prefijo_codigo)}" maxlength="6" style="margin-top:2px;font-family:monospace;text-transform:uppercase" required>
            </div>
            <div>
              <label class="mut" style="font-size:.74rem">Icono / Emoji:</label>
              <input id="edLvlIcon" value="${esc(lvl.badge_icon || '👤')}" style="margin-top:2px;text-align:center" required>
            </div>
          </div>

          <div style="display:grid;grid-template-columns:1fr 120px;gap:10px;margin-bottom:10px">
            <div>
              <label class="mut" style="font-size:.74rem">Subtítulo explicativo:</label>
              <input id="edLvlSub" value="${esc(lvl.subtitulo || '')}" style="margin-top:2px">
            </div>
            <div>
              <label class="mut" style="font-size:.74rem">Color distintivo:</label>
              <div style="display:flex;align-items:center;gap:6px;margin-top:2px">
                <input id="edLvlColorPicker" type="color" value="${esc(lvl.color || '#00d4ff')}" style="width:36px;height:34px;padding:2px;cursor:pointer;border-radius:6px;border:none">
                <input id="edLvlColor" value="${esc(lvl.color || '#00d4ff')}" style="font-family:monospace;font-size:.8rem">
              </div>
            </div>
          </div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:14px">
            <div>
              <label class="mut" style="font-size:.74rem">Margen de Ganancia / Descuento:</label>
              <input id="edLvlDiscount" value="${esc(lvl.descuento_porcentaje || '')}" style="margin-top:2px" placeholder="Ej: 15% a 25% Descuento">
            </div>
            <div>
              <label class="mut" style="font-size:.74rem">Requisito de acceso:</label>
              <input id="edLvlReq" value="${esc(lvl.requisito_acceso || '')}" style="margin-top:2px" placeholder="Ej: Registro gratuito">
            </div>
          </div>

          <div style="margin-bottom:14px">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
              <span style="font-size:.8rem;font-weight:700;color:var(--tx)">Beneficios adjuntos (${lvl.beneficios.length}):</span>
              <button type="button" id="btnAddBenefit" class="g" style="font-size:.74rem;padding:4px 10px">+ Agregar Beneficio</button>
            </div>

            <div id="benefitsListContainer" style="display:flex;flex-direction:column;gap:8px;max-height:220px;overflow-y:auto;background:rgba(0,0,0,.2);padding:8px;border-radius:10px;border:1px solid rgba(255,255,255,.06)">
              ${lvl.beneficios.map((b, idx) => `
                <div style="display:grid;grid-template-columns:40px 1fr 1fr 34px;gap:6px;align-items:center;background:rgba(12,24,42,.6);padding:6px 8px;border-radius:8px;border:1px solid rgba(255,255,255,.05)">
                  <input data-b-idx="${idx}" data-b-field="icono" value="${esc(b.icono || '✓')}" style="text-align:center;padding:4px" title="Icono / Emoji">
                  <input data-b-idx="${idx}" data-b-field="titulo" value="${esc(b.titulo || '')}" placeholder="Título del beneficio" style="padding:4px 8px;font-size:.8rem;font-weight:700">
                  <input data-b-idx="${idx}" data-b-field="descripcion" value="${esc(b.descripcion || '')}" placeholder="Breve descripción" style="padding:4px 8px;font-size:.78rem">
                  <button type="button" class="d" data-remove-b="${idx}" style="padding:4px;height:32px;display:grid;place-items:center;font-size:.76rem" title="Eliminar beneficio">✕</button>
                </div>
              `).join('')}
            </div>
          </div>

          <div class="row" style="justify-content:flex-end;gap:10px">
            <button id="btnSaveLevel" style="padding:8px 20px;font-size:.82rem;font-weight:700">💾 Guardar Cambios del Nivel</button>
          </div>
        `;

        const cp = $('#edLvlColorPicker'), ct = $('#edLvlColor');
        if(cp && ct){
          cp.oninput = () => ct.value = cp.value;
          ct.oninput = () => { if(/^#[0-9A-Fa-f]{6}$/.test(ct.value)) cp.value = ct.value; };
        }

        $('#btnAddBenefit').onclick = () => {
          saveCurrentFormState();
          lvl.beneficios.push({ icono: '⭐', titulo: 'Nuevo Beneficio', descripcion: 'Descripción del beneficio otorgado.', destacado: false });
          renderLevelForm();
        };

        $('#benefitsListContainer').querySelectorAll('[data-remove-b]').forEach(btn => {
          btn.onclick = () => {
            saveCurrentFormState();
            const idx = Number(btn.dataset.removeB);
            lvl.beneficios.splice(idx, 1);
            renderLevelForm();
          };
        });

        $('#btnSaveLevel').onclick = () => run($('#btnSaveLevel'), async () => {
          saveCurrentFormState();
          niveles[key] = {
            id: key,
            nombre: lvl.nombre,
            subtitulo: lvl.subtitulo,
            prefijo_codigo: lvl.prefijo_codigo.toUpperCase(),
            color: lvl.color,
            badge_icon: lvl.badge_icon,
            descuento_porcentaje: lvl.descuento_porcentaje,
            requisito_acceso: lvl.requisito_acceso,
            beneficios: lvl.beneficios
          };

          const { error } = await sb.from('settings').upsert({
            key: 'niveles_beneficios',
            value: niveles,
            updated_at: new Date().toISOString()
          });
          if(error) throw error;

          S.settings.niveles_beneficios = niveles;
          dlg.close();
          render();
          return `Nivel "${lvl.nombre}" guardado con éxito.`;
        });
      };

      const saveCurrentFormState = () => {
        lvl.nombre = $('#edLvlName')?.value?.trim() || lvl.nombre;
        lvl.prefijo_codigo = $('#edLvlPrefix')?.value?.trim().toUpperCase() || lvl.prefijo_codigo;
        lvl.badge_icon = $('#edLvlIcon')?.value?.trim() || lvl.badge_icon;
        lvl.subtitulo = $('#edLvlSub')?.value?.trim() || lvl.subtitulo;
        lvl.color = $('#edLvlColor')?.value?.trim() || lvl.color;
        lvl.descuento_porcentaje = $('#edLvlDiscount')?.value?.trim() || lvl.descuento_porcentaje;
        lvl.requisito_acceso = $('#edLvlReq')?.value?.trim() || lvl.requisito_acceso;

        $('#benefitsListContainer')?.querySelectorAll('input[data-b-idx]').forEach(inp => {
          const idx = Number(inp.dataset.bIdx);
          const fld = inp.dataset.bField;
          if(lvl.beneficios[idx]){
            lvl.beneficios[idx][fld] = inp.value;
          }
        });
      };

      renderLevelForm();
      dlg.showModal();
    };

    render();
  },

  async transfers(box) {
    box.innerHTML = '<div style="text-align:center;padding:30px"><p class="mut">Cargando Centro de Traslados y Reposiciones...</p></div>';

    // Consultar historial de transferencias, perfiles libres e inventario
    const [trRes, libresRes, prodsRes] = await Promise.all([
      sb.from('transfers')
        .select('*, customers(nombre,email,telefono), orders(referencia,vence)')
        .order('created_at', { ascending: false })
        .limit(100),
      sb.from('profiles_inventory')
        .select('id,estado,mother_accounts(plataforma)')
        .eq('estado', 'disponible'),
      sb.from('profiles_inventory')
        .select('id,nombre_perfil,pin,mother_id,mother_accounts(plataforma,correo)')
    ]);

    const transfers = trRes.data || [];
    const libres = libresRes.data || [];
    const allProfiles = prodsRes.data || [];
    const profById = Object.fromEntries(allProfiles.map(p => [p.id, p]));

    const libresNetflix = libres.filter(p => (p.mother_accounts?.plataforma || '').toLowerCase().includes('netflix')).length;

    let filterText = '';

    const render = () => {
      const filtered = transfers.filter(t => {
        if (!filterText) return true;
        const q = filterText.toLowerCase();
        const cli = (t.customers?.nombre || t.customers?.email || '').toLowerCase();
        const mot = (t.motivo || '').toLowerCase();
        const fromP = profById[t.from_profile];
        const toP = profById[t.to_profile];
        const plat = (fromP?.mother_accounts?.plataforma || toP?.mother_accounts?.plataforma || '').toLowerCase();
        return cli.includes(q) || mot.includes(q) || plat.includes(q);
      });

      box.innerHTML = `
        <div style="display:flex;justify-content:space-between;align-items:flex-start;flex-wrap:wrap;gap:12px;margin-bottom:18px">
          <div>
            <h2 style="margin:0 0 6px;display:flex;align-items:center;gap:8px">
              <span>🔀 Centro de Traslados & Reposiciones</span>
              <span class="pill" style="font-size:.72rem;background:rgba(56,189,248,.15);color:#38bdf8">Garantías & Reubicación</span>
            </h2>
            <p class="mut" style="font-size:.84rem;margin:0;max-width:680px">
              Gestiona reposiciones inmediatas de cuentas caídas (Netflix, Max, Disney+, etc.) y migraciones entre servicios sin que el cliente pierda sus días contratados.
            </p>
          </div>
          <div style="display:flex;gap:8px;flex-wrap:wrap">
            <button id="btnNewTransferAction" style="background:var(--grad);color:#03121c;font-weight:800;border:none;border-radius:10px;padding:9px 16px;cursor:pointer;display:inline-flex;align-items:center;gap:6px">
              <span>➕ Realizar Traslado / Reposición</span>
            </button>
          </div>
        </div>

        <!-- TARJETAS DE ESTADÍSTICAS -->
        <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:14px;margin-bottom:20px">
          <div class="card" style="padding:14px;border-radius:14px">
            <div class="mut" style="font-size:.78rem">📊 Total Traslados Realizados</div>
            <div class="price" style="font-size:1.75rem;margin:6px 0 2px">${transfers.length}</div>
            <div class="mut" style="font-size:.72rem">Historial de reposiciones</div>
          </div>
          <div class="card" style="padding:14px;border-radius:14px;border-color:rgba(229,9,20,.35)">
            <div class="mut" style="font-size:.78rem;color:#f87171">🔴 Stock Disponible Netflix</div>
            <div class="price" style="font-size:1.75rem;margin:6px 0 2px;color:#f87171">${libresNetflix}</div>
            <div class="mut" style="font-size:.72rem">Pantallas libres para reposición inmediata</div>
          </div>
          <div class="card" style="padding:14px;border-radius:14px;border-color:rgba(0,245,160,.3)">
            <div class="mut" style="font-size:.78rem;color:#00f5a0">🟢 Stock Total Disponible</div>
            <div class="price" style="font-size:1.75rem;margin:6px 0 2px;color:#00f5a0">${libres.length}</div>
            <div class="mut" style="font-size:.72rem">En todas las 10 plataformas activas</div>
          </div>
        </div>

        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;gap:12px;flex-wrap:wrap">
          <input id="inputFilterTransfers" placeholder="🔍 Filtrar por cliente, plataforma o motivo..." value="${esc(filterText)}" style="max-width:380px;font-size:.82rem;padding:8px 12px;border-radius:10px">
          <span class="mut" style="font-size:.8rem">${filtered.length} registro(s)</span>
        </div>

        ${filtered.length ? `
          <div class="wrap">
            <table>
              <tr>
                <th>Fecha</th>
                <th>Cliente</th>
                <th>Origen (Anterior)</th>
                <th>Destino (Nuevo)</th>
                <th>Motivo</th>
                <th>Acción</th>
              </tr>
              ${filtered.map(t => {
                const fP = profById[t.from_profile];
                const tP = profById[t.to_profile];
                const cliName = t.customers?.nombre || t.customers?.email || 'Cliente sin registrar';
                const cliTel = t.customers?.telefono || '';
                const fPlat = fP?.mother_accounts?.plataforma || 'Servicio';
                const tPlat = tP?.mother_accounts?.plataforma || 'Servicio';
                const fMail = fP?.mother_accounts?.correo || '—';
                const tMail = tP?.mother_accounts?.correo || '—';

                return `
                  <tr>
                    <td style="white-space:nowrap;font-size:.78rem">${new Date(t.created_at).toLocaleString('es-VE', { month:'short', day:'2-digit', hour:'2-digit', minute:'2-digit' })}</td>
                    <td>
                      <b>${esc(cliName)}</b>
                      ${cliTel ? `<div style="font-size:.74rem;color:#38bdf8">📱 <a href="https://wa.me/${cliTel.replace(/\D/g,'')}" target="_blank" style="color:var(--c)">${esc(cliTel)}</a></div>` : ''}
                    </td>
                    <td>
                      <span class="pill" style="font-size:.68rem">${esc(fPlat)}</span>
                      <div style="font-size:.74rem;margin-top:2px"><code>${esc(fMail)}</code></div>
                      <div class="mut" style="font-size:.72rem">${esc(fP?.nombre_perfil || '—')}</div>
                    </td>
                    <td>
                      <span class="pill" style="font-size:.68rem;background:rgba(0,245,160,.12);color:#00f5a0">${esc(tPlat)}</span>
                      <div style="font-size:.74rem;margin-top:2px"><code>${esc(tMail)}</code></div>
                      <div class="mut" style="font-size:.72rem">${esc(tP?.nombre_perfil || '—')} ${tP?.pin ? `(PIN: ${esc(tP.pin)})` : ''}</div>
                    </td>
                    <td style="max-width:220px;font-size:.78rem">
                      <i>${esc(t.motivo || '—')}</i>
                    </td>
                    <td>
                      ${cliTel ? `
                        <button class="g" data-wa-remind="${t.id}" data-tel="${esc(cliTel)}" data-nom="${esc(cliName)}" data-plat="${esc(tPlat)}" data-mail="${esc(tMail)}" data-prof="${esc(tP?.nombre_perfil||'')}" data-pin="${esc(tP?.pin||'')}" style="padding:4px 8px;font-size:.74rem">
                          💬 Enviar WA
                        </button>
                      ` : '<span class="mut">—</span>'}
                    </td>
                  </tr>
                `;
              }).join('')}
            </table>
          </div>
        ` : `
          <div class="card" style="padding:32px 20px;text-align:center;border-radius:14px;margin-top:10px">
            <div style="font-size:2.5rem;margin-bottom:8px">🔀</div>
            <h3 style="margin:0 0 6px">No hay traslados registrados todavía</h3>
            <p class="mut" style="font-size:.85rem;max-width:520px;margin:0 auto 16px">
              Cuando una pantalla compartida de Netflix u otra plataforma sufra una caída, pulsa el botón de abajo para asignarle al cliente un nuevo perfil de inmediato conservando sus días.
            </p>
            <button id="btnEmptyNewTransfer" style="background:var(--grad);color:#03121c;font-weight:800;border:none;border-radius:10px;padding:10px 18px;cursor:pointer">
              ➕ Realizar Primer Traslado / Reposición
            </button>
          </div>
        `}
      `;

      const btnNew = $('#btnNewTransferAction') || $('#btnEmptyNewTransfer');
      if (btnNew) btnNew.onclick = () => openTransferModal({ done: () => EXTRA.transfers(box) });

      const inpF = $('#inputFilterTransfers');
      if (inpF) {
        inpF.oninput = () => {
          filterText = inpF.value.trim();
          render();
        };
      }

      box.querySelectorAll('[data-wa-remind]').forEach(b => {
        b.onclick = () => {
          const d = b.dataset;
          const msg = encodeURIComponent(
            `¡Hola ${d.nom}! 👋 Te recordamos tus accesos activos de *${d.plat}*:\n\n` +
            `📧 *Correo:* ${d.mail}\n` +
            `👤 *Perfil:* ${d.prof}\n` +
            (d.pin ? `🔢 *PIN:* ${d.pin}\n\n` : '\n') +
            `¡Cualquier detalle nos avisas por aquí!`
          );
          window.open(`https://wa.me/${d.tel.replace(/\D/g,'')}?text=${msg}`, '_blank');
        };
      });
    };

    render();
  },

  async resellers(box) {
    box.innerHTML = '<p class="mut">Cargando red de revendedores…</p>';

    try {
      // 1. Consultar revendedores, clientes asignados, perfiles activos y cuentas por cobrar
      const [resellersRes, clientsRes, profilesRes, debtsRes] = await Promise.all([
        sb.from('customers').select('*').eq('es_revendedor', true).order('codigo_identificacion'),
        sb.from('customers').select('id, nombre, email, telefono, vendedor_id, vendedor_nombre, limite_credito').not('vendedor_id', 'is', null),
        sb.from('profiles_inventory').select('id, nombre_perfil, pin, vendedor_id, vendedor, estado, vence, assigned_customer_id, products(nombre), mother_accounts(plataforma, correo)').eq('estado', 'vendido'),
        sb.from('installments').select('id, order_id, customer_id, reseller_id, numero_cuota, total_cuotas, monto_usd, monto_bs, fecha_vencimiento, estado, referencia, pagada_at, orders(referencia, products(nombre)), customers!customer_id(nombre, email, telefono)')
      ]);

      const resellers = resellersRes.data || [];
      const allAssignedClients = clientsRes.data || [];
      const allAssignedProfiles = profilesRes.data || [];
      const allDebts = debtsRes.data || [];

      // Mapear clientes por revendedor
      const clientsBySeller = {};
      allAssignedClients.forEach(c => {
        if (c.vendedor_id) {
          clientsBySeller[c.vendedor_id] = clientsBySeller[c.vendedor_id] || [];
          clientsBySeller[c.vendedor_id].push(c);
        }
      });

      // Mapear perfiles por revendedor
      const profilesBySeller = {};
      allAssignedProfiles.forEach(p => {
        if (p.vendedor_id) {
          profilesBySeller[p.vendedor_id] = profilesBySeller[p.vendedor_id] || [];
          profilesBySeller[p.vendedor_id].push(p);
        }
      });

      // Mapear deudas por revendedor
      const debtsBySeller = {};
      resellers.forEach(r => {
        const isPablo = r.nombre?.toLowerCase().includes('pablo') || r.email?.toLowerCase().includes('pacun');
        const rDebts = allDebts.filter(d => {
          if (d.reseller_id === r.id) return true;
          if (d.customer_id === r.id && d.referencia && d.referencia.toUpperCase().includes('CRÉDITO')) return true;
          if (isPablo && d.referencia && /pablo\s*gonzalez|\[crédito pablo/i.test(d.referencia)) return true;
          return false;
        });
        debtsBySeller[r.id] = rDebts;
      });

      // Totales para KPIs
      const totalResellers = resellers.length;
      const totalClients = allAssignedClients.length;
      const totalProfiles = allAssignedProfiles.length;
      const totalCredit = resellers.reduce((sum, r) => sum + Number(r.limite_credito || (r.nombre?.toLowerCase().includes('pablo') ? 30.00 : 0.00)), 0);
      const totalUsedCredit = Object.values(debtsBySeller).flat().filter(d => d.estado !== 'pagada').reduce((sum, d) => sum + Number(d.monto_usd || 0), 0);
      const totalAvailable = Math.max(0, totalCredit - totalUsedCredit);

      const render = (filterQuery = '') => {
        const q = filterQuery.toLowerCase().trim();
        const filtered = resellers.filter(r => {
          if (!q) return true;
          return (r.nombre || '').toLowerCase().includes(q) ||
                 (r.email || '').toLowerCase().includes(q) ||
                 (r.telefono || '').toLowerCase().includes(q) ||
                 (r.codigo_identificacion || '').toLowerCase().includes(q);
        });

        box.innerHTML = `
          <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;margin-bottom:18px;flex-wrap:wrap">
            <div>
              <h3 style="margin:0 0 4px;font-size:1.18rem;display:flex;align-items:center;gap:8px">
                🤝 Red Oficial de Revendedores
                <span class="pill" style="font-size:.72rem;background:rgba(56,189,248,.15);color:#38bdf8;border-color:rgba(56,189,248,.3)">
                  ${totalResellers} Registrados
                </span>
              </h3>
              <p class="mut" style="margin:0;font-size:.82rem">
                Gestión integral de socios comerciales con código oficial <b>RVD:100x</b>, líneas de crédito mayorista rotativas y carteras de clientes.
              </p>
            </div>
            <div style="display:flex;gap:8px;flex-wrap:wrap">
              <button id="btnSyncRvdCodes" class="g" style="background:rgba(56,189,248,.12);border-color:#38bdf8;color:#38bdf8;font-weight:700">
                ⚡ Sincronizar Códigos RVD
              </button>
              <button id="btnNewReseller" style="background:linear-gradient(135deg,#00f5a0,#00d4ff);color:#03121c;font-weight:800;border:none">
                + Nuevo Revendedor
              </button>
            </div>
          </div>

          <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px;margin-bottom:20px">
            <div class="card" style="padding:14px;background:rgba(15,23,42,.6);border:1px solid rgba(56,189,248,.25)">
              <div class="mut" style="font-size:.76rem;text-transform:uppercase;font-weight:700">🤝 Revendedores Activos</div>
              <div style="font-size:1.5rem;font-weight:800;color:#38bdf8;margin-top:4px">${totalResellers}</div>
              <div class="mut" style="font-size:.72rem;margin-top:2px">Socios mayoristas registrados</div>
            </div>
            <div class="card" style="padding:14px;background:rgba(15,23,42,.6);border:1px solid rgba(168,85,247,.25)">
              <div class="mut" style="font-size:.76rem;text-transform:uppercase;font-weight:700">👥 Clientes en Red</div>
              <div style="font-size:1.5rem;font-weight:800;color:#c084fc;margin-top:4px">${totalClients}</div>
              <div class="mut" style="font-size:.72rem;margin-top:2px">Asignados a revendedores</div>
            </div>
            <div class="card" style="padding:14px;background:rgba(15,23,42,.6);border:1px solid rgba(239,68,68,.25)">
              <div class="mut" style="font-size:.76rem;text-transform:uppercase;font-weight:700">🔴 Deuda Activa en Red</div>
              <div style="font-size:1.5rem;font-weight:800;color:#f87171;margin-top:4px">$${totalUsedCredit.toFixed(2)} USD</div>
              <div class="mut" style="font-size:.72rem;margin-top:2px">Por cobrar a revendedores</div>
            </div>
            <div class="card" style="padding:14px;background:rgba(15,23,42,.6);border:1px solid rgba(34,197,94,.25)">
              <div class="mut" style="font-size:.76rem;text-transform:uppercase;font-weight:700">🟢 Crédito Disponible</div>
              <div style="font-size:1.5rem;font-weight:800;color:#4ade80;margin-top:4px">$${totalAvailable.toFixed(2)} USD</div>
              <div class="mut" style="font-size:.72rem;margin-top:2px">Cupo libre de $${totalCredit.toFixed(2)} USD</div>
            </div>
          </div>

          <div style="margin-bottom:14px;display:flex;gap:10px;align-items:center">
            <input id="resellerSearch" placeholder="🔍 Buscar por nombre, código RVD (ej: RVD:1001), email o teléfono..." 
                   value="${esc(filterQuery)}" 
                   style="flex:1;padding:8px 14px;border-radius:10px;background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.15);color:#fff;font-size:.85rem">
            ${filterQuery ? `<button class="g" id="btnClearResellerSearch" style="padding:8px 12px">✕ Limpiar</button>` : ''}
          </div>

          <div class="wrap card" style="padding:0;overflow:hidden">
            <table style="width:100%;margin:0;border-collapse:collapse">
              <thead>
                <tr style="background:rgba(255,255,255,.04);text-align:left;border-bottom:1px solid var(--line)">
                  <th style="padding:10px 14px">Código</th>
                  <th style="padding:10px 14px">Revendedor</th>
                  <th style="padding:10px 14px">Contacto WA</th>
                  <th style="padding:10px 14px">Cartera Asignada</th>
                  <th style="padding:10px 14px">Línea de Crédito (Deuda / Cupo)</th>
                  <th style="padding:10px 14px">Saldo Zeny</th>
                  <th style="padding:10px 14px;text-align:right">Acciones</th>
                </tr>
              </thead>
              <tbody>
                ${filtered.length === 0 ? `
                  <tr><td colspan="7" style="padding:32px;text-align:center" class="mut">No se encontraron revendedores con el criterio de búsqueda.</td></tr>
                ` : filtered.map(r => {
                  const cList = clientsBySeller[r.id] || [];
                  const pList = profilesBySeller[r.id] || [];
                  const rDebts = debtsBySeller[r.id] || [];
                  const pendDebts = rDebts.filter(d => d.estado !== 'pagada');
                  const usedCredit = pendDebts.reduce((sum, d) => sum + Number(d.monto_usd || 0), 0);
                  const isPablo = r.nombre?.toLowerCase().includes('pablo') || r.email?.toLowerCase().includes('pacun');
                  const limitCredit = Number(r.limite_credito || (isPablo ? 30.00 : 0.00));
                  const availableCredit = Math.max(0, limitCredit - usedCredit);

                  const cleanPhone = (r.telefono || '').replace(/\D/g, '');
                  const waUrl = cleanPhone ? `https://wa.me/${cleanPhone.startsWith('58') ? cleanPhone : ('58' + cleanPhone.replace(/^0+/, ''))}` : '';
                  const code = r.codigo_identificacion || (isPablo ? 'RVD:1001' : 'RVD');
                  return `
                    <tr style="border-bottom:1px solid rgba(255,255,255,.05)">
                      <td style="padding:10px 14px">
                        <span class="pill" style="font-family:monospace;font-weight:800;font-size:.82rem;background:rgba(0,212,255,.15);color:#00d4ff;border-color:rgba(0,212,255,.4)">
                          ${esc(code)}
                        </span>
                      </td>
                      <td style="padding:10px 14px">
                        <b style="font-size:.9rem;color:#fff">${esc(r.nombre || 'Sin nombre')}</b>
                        <div class="mut" style="font-size:.76rem">${esc(r.email || 'Sin correo')}</div>
                      </td>
                      <td style="padding:10px 14px">
                        ${cleanPhone ? `
                          <a href="${waUrl}" target="_blank" class="g" style="padding:4px 8px;font-size:.74rem;display:inline-flex;align-items:center;gap:4px;text-decoration:none;border-radius:6px;background:rgba(37,211,102,.12);color:#25d366;border-color:rgba(37,211,102,.3)">
                            📱 ${esc(r.telefono)}
                          </a>
                        ` : '<span class="mut" style="font-size:.76rem">—</span>'}
                      </td>
                      <td style="padding:10px 14px">
                        <div style="display:flex;gap:6px;flex-wrap:wrap">
                          <span class="pill" style="font-size:.74rem;background:rgba(168,85,247,.12);color:#c084fc;border-color:rgba(168,85,247,.3);font-weight:700">
                            👥 ${cList.length} clientes
                          </span>
                          <span class="pill" style="font-size:.74rem;background:rgba(56,189,248,.12);color:#38bdf8;border-color:rgba(56,189,248,.3);font-weight:700">
                            👤 ${pList.length} perfiles
                          </span>
                        </div>
                      </td>
                      <td style="padding:10px 14px">
                        <div style="font-size:.82rem">
                          <span class="mut" style="font-size:.68rem;display:block">Límite Otorgado:</span>
                          <b style="color:#fbbf24">$${limitCredit.toFixed(2)} USD</b>
                        </div>
                        ${usedCredit > 0 ? `
                          <div style="font-size:.76rem;margin-top:2px">
                            <span style="color:#f87171;font-weight:800">Debe: $${usedCredit.toFixed(2)} USD</span>
                            <span class="mut" style="font-size:.68rem">(${pendDebts.length} cuotas)</span>
                          </div>
                          <div style="font-size:.7rem;color:#00f5a0;font-weight:700">
                            Disponible: $${availableCredit.toFixed(2)} USD
                          </div>
                        ` : `
                          <div style="font-size:.7rem;color:#00f5a0;font-weight:700;margin-top:2px">
                            ✓ 100% Disponible ($${limitCredit.toFixed(2)})
                          </div>
                        `}
                      </td>
                      <td style="padding:10px 14px">
                        <b style="color:#00f5a0">${Number(r.zeny_balance || 0).toFixed(2)} pts</b>
                      </td>
                      <td style="padding:10px 14px;text-align:right">
                        <div class="row" style="justify-content:flex-end;gap:4px">
                          <button class="g" data-reseller-debts="${esc(r.id)}" data-nom="${esc(r.nombre)}" data-tel="${esc(r.telefono || '')}" style="padding:4px 8px;font-size:.74rem;background:${usedCredit > 0 ? 'rgba(239,68,68,.18)' : 'rgba(255,255,255,.05)'};color:${usedCredit > 0 ? '#f87171' : 'var(--tx)'};border-color:${usedCredit > 0 ? 'rgba(239,68,68,.4)' : 'var(--line)'};font-weight:700" title="Ver deudas y conciliar créditos de este revendedor">
                            💳 Créditos (${pendDebts.length})
                          </button>
                          <button class="g" data-view-portfolio="${esc(r.id)}" data-nom="${esc(r.nombre)}" data-code="${esc(code)}" style="padding:4px 8px;font-size:.74rem" title="Ver clientes y perfiles">
                            👥 Cartera
                          </button>
                          <button class="g" data-reseller-credit="${esc(r.id)}" data-cur="${limitCredit}" data-nom="${esc(r.nombre)}" style="padding:4px 8px;font-size:.74rem" title="Ajustar límite de crédito">
                            ⚙️ Línea
                          </button>
                          <button class="g" data-reseller-pw="${esc(r.id)}" data-nom="${esc(r.nombre)}" data-tel="${esc(r.telefono || '')}" style="padding:4px 8px;font-size:.74rem" title="Restablecer clave">
                            🔑 Clave
                          </button>
                          <button class="g" data-reseller-edit="${esc(r.id)}" style="padding:4px 8px;font-size:.74rem" title="Editar datos">
                            ✏️
                          </button>
                          <button class="d" data-reseller-demote="${esc(r.id)}" data-nom="${esc(r.nombre)}" style="padding:4px 8px;font-size:.74rem" title="Revertir a cliente estándar CLT">
                            Revertir
                          </button>
                        </div>
                      </td>
                    </tr>
                  `;
                }).join('')}
              </tbody>
            </table>
          </div>
        `;

        // Event listeners
        const searchInput = $('#resellerSearch');
        if (searchInput) {
          searchInput.oninput = e => render(e.target.value);
          if (filterQuery) {
            searchInput.focus();
            searchInput.setSelectionRange(filterQuery.length, filterQuery.length);
          }
        }
        if ($('#btnClearResellerSearch')) {
          $('#btnClearResellerSearch').onclick = () => render('');
        }

        if ($('#btnSyncRvdCodes')) {
          $('#btnSyncRvdCodes').onclick = async () => {
            if (!confirm('¿Sincronizar y corregir códigos de todos los revendedores registrados a sus códigos oficiales RVD:1001..RVD:1004?')) return;
            try {
              await sb.from('customers').update({ es_revendedor: true, codigo_identificacion: 'RVD:1001', nombre: 'Pablo Gonzalez' })
                .or('email.ilike.pacun1989@gmail.com,nombre.ilike.%pablo gonzalez%');
              await sb.from('customers').update({ es_revendedor: true, codigo_identificacion: 'RVD:1002', nombre: 'Leandro Perdomo' })
                .or('email.ilike.perdomoleandro39@gmail.com,nombre.ilike.%leandro%');
              await sb.from('customers').update({ es_revendedor: true, codigo_identificacion: 'RVD:1003', nombre: 'Nelson Bustamante' })
                .or('email.ilike.584120266710@cliente.gregoryizquierdo.xyz,nombre.ilike.%nelson%');
              await sb.from('customers').update({ es_revendedor: true, codigo_identificacion: 'RVD:1004', nombre: 'Josuanny' })
                .or('email.ilike.584129939848@cliente.gregoryizquierdo.xyz,nombre.ilike.%josuanny%');

              toast('✅ Códigos oficiales RVD sincronizados con éxito.');
              EXTRA.resellers(box);
            } catch (e) {
              toast('Error al sincronizar: ' + e.message);
            }
          };
        }

        if ($('#btnNewReseller')) {
          $('#btnNewReseller').onclick = () => {
            $('#dlgBody').innerHTML = `
              <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px">
                <h3 style="margin:0">🤝 Registrar Nuevo Revendedor Oficial</h3>
                <button class="g" onclick="dlg.close()" style="padding:4px 8px">✕</button>
              </div>
              <p class="mut" style="font-size:.84rem;margin:0 0 14px;line-height:1.4">
                Se registrará el revendedor en la red oficial, se le asignará el código consecutivo <b>RVD</b> y tendrá acceso mayorista al portal.
              </p>
              <div style="display:flex;flex-direction:column;gap:12px;margin-bottom:18px">
                <div>
                  <label class="mut" style="display:block;font-size:.76rem;margin-bottom:4px">Nombre y Apellido *</label>
                  <input id="inputNewResellerName" placeholder="Ej: Pedro Pérez" style="width:100%">
                </div>
                <div>
                  <label class="mut" style="display:block;font-size:.76rem;margin-bottom:4px">Correo Electrónico *</label>
                  <input id="inputNewResellerEmail" type="email" placeholder="Ej: pedro@gmail.com" style="width:100%">
                </div>
                <div>
                  <label class="mut" style="display:block;font-size:.76rem;margin-bottom:4px">Teléfono WhatsApp *</label>
                  <input id="inputNewResellerPhone" placeholder="Ej: 04121234567" style="width:100%">
                </div>
                <div>
                  <label class="mut" style="display:block;font-size:.76rem;margin-bottom:4px">Límite de Crédito Mayorista Inicial (USD)</label>
                  <input id="inputNewResellerCredit" type="number" step="0.5" value="0.00" style="width:100%">
                </div>
              </div>
              <div style="display:flex;gap:10px;justify-content:flex-end">
                <button class="g" onclick="dlg.close()">Cancelar</button>
                <button id="btnSubmitNewReseller" style="background:linear-gradient(135deg,#00f5a0,#00d4ff);color:#03121c;font-weight:800;border:none">
                  💾 Registrar Revendedor
                </button>
              </div>
            `;
            dlg.showModal();

            $('#btnSubmitNewReseller').onclick = async () => {
              const nom = ($('#inputNewResellerName')?.value || '').trim();
              const email = ($('#inputNewResellerEmail')?.value || '').trim().toLowerCase();
              const tel = ($('#inputNewResellerPhone')?.value || '').trim();
              const credit = parseFloat($('#inputNewResellerCredit')?.value || '0') || 0;

              if (!nom || !email || !tel) {
                return toast('Completa nombre, email y teléfono');
              }

              try {
                let rvdCode = 'RVD:1005';
                try {
                  const { data: codeData } = await sb.rpc('get_next_customer_code', { p_es_revendedor: true });
                  if (codeData) rvdCode = codeData;
                } catch(e) {}

                const { data: inserted, error: insErr } = await sb.from('customers').insert({
                  nombre: nom,
                  email: email,
                  telefono: tel,
                  es_revendedor: true,
                  codigo_identificacion: rvdCode,
                  limite_credito: credit,
                  permite_cuotas: true
                }).select('id').single();

                if (insErr) throw insErr;

                toast(`✅ Revendedor ${nom} registrado con código ${rvdCode}`);
                dlg.close();
                EXTRA.resellers(box);
              } catch (e) {
                toast('Error al registrar: ' + e.message);
              }
            };
          };
        }

        box.querySelectorAll('[data-view-portfolio]').forEach(b => {
          b.onclick = () => {
            const sellerId = b.dataset.viewPortfolio;
            const sellerNom = b.dataset.nom;
            const sellerCode = b.dataset.code;
            const cList = clientsBySeller[sellerId] || [];
            const pList = profilesBySeller[sellerId] || [];

            $('#dlgBody').innerHTML = `
              <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px">
                <div>
                  <h3 style="margin:0 0 2px">👥 Cartera: ${esc(sellerNom)}</h3>
                  <span class="pill" style="font-family:monospace;font-size:.76rem;background:rgba(0,212,255,.15);color:#00d4ff;border-color:rgba(0,212,255,.4)">
                    ${esc(sellerCode)}
                  </span>
                </div>
                <button class="g" onclick="dlg.close()" style="padding:4px 8px">✕</button>
              </div>
              <div style="display:flex;gap:8px;margin-bottom:16px">
                <span class="pill" style="font-size:.76rem;background:rgba(168,85,247,.15);color:#c084fc;font-weight:700">
                  👥 ${cList.length} Clientes Asignados
                </span>
                <span class="pill" style="font-size:.76rem;background:rgba(56,189,248,.15);color:#38bdf8;font-weight:700">
                  👤 ${pList.length} Perfiles Activos
                </span>
              </div>
              <div style="max-height:420px;overflow-y:auto;border:1px solid var(--line);border-radius:10px;padding:8px">
                ${cList.length === 0 ? `
                  <p class="mut" style="text-align:center;padding:20px">No hay clientes asignados actualmente a este revendedor.</p>
                ` : `
                  <table style="width:100%;font-size:.82rem;border-collapse:collapse">
                    <thead>
                      <tr style="border-bottom:1px solid var(--line);text-align:left">
                        <th style="padding:6px 8px">Cliente</th>
                        <th style="padding:6px 8px">Teléfono</th>
                        <th style="padding:6px 8px">Perfiles</th>
                        <th style="padding:6px 8px;text-align:right">WA</th>
                      </tr>
                    </thead>
                    <tbody>
                      ${cList.map(c => {
                        const clientProfiles = pList.filter(p => p.assigned_customer_id === c.id);
                        const cleanTel = (c.telefono || '').replace(/\D/g, '');
                        const waUrl = cleanTel ? `https://wa.me/${cleanTel.startsWith('58') ? cleanTel : ('58' + cleanTel.replace(/^0+/, ''))}` : '';
                        return `
                          <tr style="border-bottom:1px solid rgba(255,255,255,.05)">
                            <td style="padding:8px">
                              <b>${esc(c.nombre || 'Cliente')}</b>
                              <div class="mut" style="font-size:.72rem">${esc(c.email || '')}</div>
                            </td>
                            <td style="padding:8px">${esc(c.telefono || '—')}</td>
                            <td style="padding:8px">
                              ${clientProfiles.length ? clientProfiles.map(p => `
                                <span class="pill" style="font-size:.68rem;background:rgba(56,189,248,.1);color:#38bdf8;margin:2px">
                                  ${esc(p.mother_accounts?.plataforma || '')}: ${esc(p.nombre_perfil || '')}
                                </span>
                              `).join('') : '<span class="mut" style="font-size:.72rem">Sin perfil activo</span>'}
                            </td>
                            <td style="padding:8px;text-align:right">
                              ${cleanTel ? `
                                <a href="${waUrl}" target="_blank" class="g" style="padding:3px 7px;font-size:.7rem;text-decoration:none;border-radius:6px;background:rgba(37,211,102,.12);color:#25d366">
                                  💬
                                </a>
                              ` : '—'}
                            </td>
                          </tr>
                        `;
                      }).join('')}
                    </tbody>
                  </table>
                `}
              </div>
              <div style="margin-top:16px;text-align:right">
                <button class="g" onclick="dlg.close()">Cerrar</button>
              </div>
            `;
            dlg.showModal();
          };
        });

        box.querySelectorAll('[data-reseller-debts]').forEach(b => {
          b.onclick = () => {
            const sellerId = b.dataset.resellerDebts;
            const nom = b.dataset.nom;
            const tel = (b.dataset.tel || '').trim();
            const cleanTel = tel.replace(/\D/g, '');
            const waPhone = cleanTel ? (cleanTel.startsWith('58') ? cleanTel : ('58' + cleanTel.replace(/^0+/, ''))) : '';

            const showDebtsDialog = (currentDebts) => {
              const debts = currentDebts || debtsBySeller[sellerId] || [];
              const pendDebts = debts.filter(d => d.estado !== 'pagada');
              const paidDebts = debts.filter(d => d.estado === 'pagada');
              const usedCredit = pendDebts.reduce((sum, d) => sum + Number(d.monto_usd || 0), 0);
              const seller = resellers.find(r => r.id === sellerId);
              const isPablo = nom.toLowerCase().includes('pablo') || seller?.email?.toLowerCase().includes('pacun');
              const limitCredit = Number(seller?.limite_credito || (isPablo ? 30.00 : 0.00));
              const availableCredit = Math.max(0, limitCredit - usedCredit);

              // Generar mensaje detallado para WhatsApp
              let waMsg = `👋 Hola *${nom}*, te comparto tu estado de cuenta actual en *Gregory Shop*:\n\n` +
                          `💳 *Línea de Crédito Otorgada:* $${limitCredit.toFixed(2)} USD\n` +
                          `🔴 *Deuda Pendiente:* $${usedCredit.toFixed(2)} USD (${pendDebts.length} cuotas)\n` +
                          `🟢 *Crédito Disponible:* $${availableCredit.toFixed(2)} USD\n\n`;

              if (pendDebts.length > 0) {
                waMsg += `📋 *Detalle de Cuotas por Conciliar:*\n` +
                         pendDebts.map((d, i) => {
                           const srv = d.orders?.products?.nombre || (d.referencia && d.referencia.split('·')[0]) || 'Servicio';
                           return `${i + 1}. *${srv.trim()}* — Cuota ${d.numero_cuota}/${d.total_cuotas}: *$${Number(d.monto_usd).toFixed(2)} USD* (Vence: ${d.fecha_vencimiento || 'Inmediato'})`;
                         }).join('\n') + `\n\n` +
                         `🏦 *Formas de Pago:* Pago Móvil / Binance USDT / Zinli.\n` +
                         `Al transferir, envíanos el comprobante por acá para conciliar tu saldo y reactivar tu cupo de inmediato. ¡Muchas gracias!`;
              } else {
                waMsg += `🎉 ¡Excelente! No tienes cuotas pendientes. Tu línea está 100% disponible ($${availableCredit.toFixed(2)} USD).`;
              }

              const waUrl = waPhone ? `https://wa.me/${waPhone}?text=${encodeURIComponent(waMsg)}` : '';

              $('#dlgBody').innerHTML = `
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px">
                  <div>
                    <h3 style="margin:0;display:flex;align-items:center;gap:8px">
                      💳 Línea de Crédito y Cuotas: ${esc(nom)}
                    </h3>
                    <div class="mut" style="font-size:.78rem;margin-top:2px">
                      Auditoría directa y conciliación de créditos mayoristas
                    </div>
                  </div>
                  <button class="g" onclick="dlg.close()" style="padding:4px 8px">✕</button>
                </div>

                <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(130px, 1fr));gap:8px;margin-bottom:14px">
                  <div class="card" style="padding:10px;background:rgba(15,23,42,.6);border:1px solid rgba(251,191,36,.25)">
                    <div class="mut" style="font-size:.7rem;text-transform:uppercase;font-weight:700">Límite Otorgado</div>
                    <div style="font-size:1.2rem;font-weight:800;color:#fbbf24">$${limitCredit.toFixed(2)} USD</div>
                  </div>
                  <div class="card" style="padding:10px;background:rgba(15,23,42,.6);border:1px solid ${usedCredit > 0 ? 'rgba(239,68,68,.3)' : 'rgba(255,255,255,.1)'}">
                    <div class="mut" style="font-size:.7rem;text-transform:uppercase;font-weight:700">Deuda Activa</div>
                    <div style="font-size:1.2rem;font-weight:800;color:${usedCredit > 0 ? '#f87171' : '#fff'}">$${usedCredit.toFixed(2)} USD</div>
                    <div class="mut" style="font-size:.66rem">${pendDebts.length} cuotas pendientes</div>
                  </div>
                  <div class="card" style="padding:10px;background:rgba(15,23,42,.6);border:1px solid rgba(34,197,94,.25)">
                    <div class="mut" style="font-size:.7rem;text-transform:uppercase;font-weight:700">Cupo Disponible</div>
                    <div style="font-size:1.2rem;font-weight:800;color:#4ade80">$${availableCredit.toFixed(2)} USD</div>
                  </div>
                </div>

                <div style="display:flex;gap:8px;margin-bottom:14px;flex-wrap:wrap">
                  ${waUrl ? `
                    <a href="${waUrl}" target="_blank" class="g" style="display:inline-flex;align-items:center;gap:6px;padding:6px 12px;background:rgba(37,211,102,.15);color:#25d366;border:1px solid rgba(37,211,102,.3);border-radius:8px;text-decoration:none;font-weight:700;font-size:.82rem">
                      💬 Cobrar Estado de Cuenta por WhatsApp
                    </a>
                  ` : ''}
                </div>

                <div style="max-height:360px;overflow-y:auto;border:1px solid rgba(255,255,255,.08);border-radius:8px">
                  <table style="width:100%;border-collapse:collapse;font-size:.82rem">
                    <thead style="background:rgba(255,255,255,.03);border-bottom:1px solid rgba(255,255,255,.08)">
                      <tr>
                        <th style="padding:8px 10px;text-align:left">Servicio / Ref</th>
                        <th style="padding:8px 10px;text-align:left">Cuota</th>
                        <th style="padding:8px 10px;text-align:left">Vence</th>
                        <th style="padding:8px 10px;text-align:left">Monto</th>
                        <th style="padding:8px 10px;text-align:left">Estado</th>
                        <th style="padding:8px 10px;text-align:right">Acción</th>
                      </tr>
                    </thead>
                    <tbody>
                      ${debts.length === 0 ? `
                        <tr><td colspan="6" style="padding:20px;text-align:center" class="mut">No hay registros de cuotas ni créditos cargados para este revendedor.</td></tr>
                      ` : debts.map(d => {
                        const isPaid = d.estado === 'pagada';
                        const srvName = d.orders?.products?.nombre || (d.referencia && d.referencia.split('·')[0]) || 'Servicio';
                        return `
                          <tr style="border-bottom:1px solid rgba(255,255,255,.04);background:${isPaid ? 'transparent' : 'rgba(239,68,68,.03)'}">
                            <td style="padding:8px 10px">
                              <b style="color:var(--tx)">${esc(srvName)}</b>
                              ${d.referencia ? `<div class="mut" style="font-size:.7rem;max-width:180px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis" title="${esc(d.referencia)}">${esc(d.referencia)}</div>` : ''}
                            </td>
                            <td style="padding:8px 10px">
                              ${d.numero_cuota}/${d.total_cuotas}
                            </td>
                            <td style="padding:8px 10px">
                              <span style="font-size:.78rem">${esc(d.fecha_vencimiento || '—')}</span>
                            </td>
                            <td style="padding:8px 10px">
                              <b style="color:${isPaid ? '#4ade80' : '#fbbf24'}">$${Number(d.monto_usd || 0).toFixed(2)}</b>
                              ${d.monto_bs ? `<div class="mut" style="font-size:.68rem">Bs. ${Number(d.monto_bs).toLocaleString('es-VE')}</div>` : ''}
                            </td>
                            <td style="padding:8px 10px">
                              <span style="display:inline-block;padding:2px 6px;border-radius:4px;font-size:.7rem;font-weight:700;background:${isPaid ? 'rgba(34,197,94,.15)' : 'rgba(239,68,68,.15)'};color:${isPaid ? '#4ade80' : '#f87171'}">
                                ${isPaid ? '✓ PAGADA' : '⏳ PENDIENTE'}
                              </span>
                              ${isPaid && d.pagada_at ? `<div class="mut" style="font-size:.66rem">${d.pagada_at.slice(0, 10)}</div>` : ''}
                            </td>
                            <td style="padding:8px 10px;text-align:right">
                              ${!isPaid ? `
                                <button class="g" data-conciliar-inst="${esc(d.id)}" style="padding:4px 8px;font-size:.72rem;background:rgba(34,197,94,.18);color:#4ade80;border-color:rgba(34,197,94,.4);font-weight:700">
                                  ✅ Conciliar
                                </button>
                              ` : `
                                <span class="mut" style="font-size:.7rem">Conciliada</span>
                              `}
                            </td>
                          </tr>
                        `;
                      }).join('')}
                    </tbody>
                  </table>
                </div>

                <div style="margin-top:16px;display:flex;justify-content:space-between;align-items:center">
                  <div class="mut" style="font-size:.74rem">
                    💡 Al conciliar una cuota, el ingreso se suma automáticamente a Finanzas y se libera el cupo del revendedor.
                  </div>
                  <button class="g" onclick="dlg.close()">Cerrar</button>
                </div>
              `;

              // Listeners dentro del modal
              $('#dlgBody').querySelectorAll('[data-conciliar-inst]').forEach(cBtn => {
                cBtn.onclick = async () => {
                  const instId = cBtn.dataset.conciliarInst;
                  cBtn.disabled = true;
                  cBtn.textContent = 'Conciliando…';
                  try {
                    let { error: rpcErr } = await sb.rpc('approve_installment', { p_installment_id: instId });
                    if (rpcErr) {
                      const { error: updErr } = await sb.from('installments').update({
                        estado: 'pagada',
                        pagada_at: new Date().toISOString()
                      }).eq('id', instId);
                      if (updErr) throw updErr;
                    }
                    toast('✅ Cuota conciliada con éxito. Venta agregada a Finanzas y crédito liberado.');
                    const target = debts.find(x => x.id === instId);
                    if (target) {
                      target.estado = 'pagada';
                      target.pagada_at = new Date().toISOString();
                    }
                    showDebtsDialog(debts);
                    EXTRA.resellers(box);
                  } catch (err) {
                    toast('Error conciliando cuota: ' + err.message);
                    cBtn.disabled = false;
                    cBtn.textContent = '✅ Conciliar';
                  }
                };
              });

              dlg.showModal();
            };

            showDebtsDialog();
          };
        });

        box.querySelectorAll('[data-reseller-credit]').forEach(b => {
          b.onclick = () => {
            const sellerId = b.dataset.resellerCredit;
            const nom = b.dataset.nom;
            const cur = parseFloat(b.dataset.cur || '0');
            const val = prompt(`Límite de crédito mayorista para "${nom}" (en USD):`, cur.toString());
            if (val === null) return;
            const num = parseFloat(val);
            if (isNaN(num) || num < 0) return toast('Monto inválido');
            sb.from('customers').update({ limite_credito: num }).eq('id', sellerId)
              .then(({ error }) => {
                if (error) return toast('Error: ' + error.message);
                toast(`Límite de crédito actualizado a $${num.toFixed(2)} USD para ${nom}`);
                EXTRA.resellers(box);
              });
          };
        });

        box.querySelectorAll('[data-reseller-pw]').forEach(b => {
          b.onclick = async () => {
            const sellerId = b.dataset.resellerPw;
            const nom = b.dataset.nom;
            const tel = (b.dataset.tel || '').trim();
            const cleanTel = tel.replace(/\D/g, '');
            const pass = cleanTel.length >= 6 ? cleanTel.slice(-6) : '123456';
            if (!confirm(`¿Restablecer contraseña para "${nom}"?\n\n• Clave temporal: ${pass}\n• Al ingresar al portal se le pedirá cambiarla.`)) return;
            let resetErr = null;
            try {
              const { error } = await sb.rpc('resetear_clave_cliente', { p_customer_id: sellerId });
              resetErr = error;
            } catch(e) { resetErr = e; }
            if (resetErr) return toast('Error: ' + resetErr.message);
            toast(`Contraseña restablecida a "${pass}" para ${nom}`);
          };
        });

        box.querySelectorAll('[data-reseller-edit]').forEach(b => {
          b.onclick = () => {
            const seller = resellers.find(r => r.id === b.dataset.resellerEdit);
            if (!seller) return;
            $('#dlgBody').innerHTML = `
              <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px">
                <h3 style="margin:0">✏️ Editar Revendedor: ${esc(seller.nombre)}</h3>
                <button class="g" onclick="dlg.close()" style="padding:4px 8px">✕</button>
              </div>
              <div style="display:flex;flex-direction:column;gap:12px;margin-bottom:18px">
                <div>
                  <label class="mut" style="display:block;font-size:.76rem;margin-bottom:4px">Código Identificación (RVD)</label>
                  <input id="editResellerCode" value="${esc(seller.codigo_identificacion || '')}" style="width:100%">
                </div>
                <div>
                  <label class="mut" style="display:block;font-size:.76rem;margin-bottom:4px">Nombre y Apellido</label>
                  <input id="editResellerName" value="${esc(seller.nombre || '')}" style="width:100%">
                </div>
                <div>
                  <label class="mut" style="display:block;font-size:.76rem;margin-bottom:4px">Correo Electrónico</label>
                  <input id="editResellerEmail" type="email" value="${esc(seller.email || '')}" style="width:100%">
                </div>
                <div>
                  <label class="mut" style="display:block;font-size:.76rem;margin-bottom:4px">Teléfono WhatsApp</label>
                  <input id="editResellerPhone" value="${esc(seller.telefono || '')}" style="width:100%">
                </div>
              </div>
              <div style="display:flex;gap:10px;justify-content:flex-end">
                <button class="g" onclick="dlg.close()">Cancelar</button>
                <button id="btnSaveResellerEdit" style="background:linear-gradient(135deg,#00f5a0,#00d4ff);color:#03121c;font-weight:800;border:none">
                  💾 Guardar Cambios
                </button>
              </div>
            `;
            dlg.showModal();

            $('#btnSaveResellerEdit').onclick = async () => {
              const newCode = ($('#editResellerCode')?.value || '').trim();
              const newNom = ($('#editResellerName')?.value || '').trim();
              const newEmail = ($('#editResellerEmail')?.value || '').trim().toLowerCase();
              const newTel = ($('#editResellerPhone')?.value || '').trim();

              const { error: updErr } = await sb.from('customers').update({
                codigo_identificacion: newCode,
                nombre: newNom,
                email: newEmail,
                telefono: newTel
              }).eq('id', seller.id);

              if (updErr) return toast('Error al actualizar: ' + updErr.message);
              toast('Revendedor actualizado con éxito');
              dlg.close();
              EXTRA.resellers(box);
            };
          };
        });

        box.querySelectorAll('[data-reseller-demote]').forEach(b => {
          b.onclick = async () => {
            const sellerId = b.dataset.resellerDemote;
            const nom = b.dataset.nom;
            if (!confirm(`¿Revertir a "${nom}" a cliente estándar?\n\n• Su código cambiará a formato CLT:xxx.\n• Dejará de tener acceso a precios de revendedor.`)) return;
            try {
              const { data: newCode, error } = await sb.rpc('switch_customer_role', { p_customer_id: sellerId, p_make_reseller: false });
              if (error) throw error;
              toast(`${nom} revertido a cliente final con código ${newCode || 'CLT'}`);
              EXTRA.resellers(box);
            } catch (e) {
              toast('Error: ' + e.message);
            }
          };
        });
      };

      render();
    } catch (err) {
      console.error('Error cargando módulo resellers:', err);
      box.innerHTML = `<div class="card" style="border:1.5px solid #ef4444;background:rgba(239,68,68,.08);padding:20px;text-align:center"><h3 style="color:#f87171">Error al cargar red de revendedores</h3><p class="mut">${esc(err.message)}</p></div>`;
    }
  }
};

function cleanValStr(v) {
  if (v == null) return null;
  let s = String(v).trim();
  if (s === '1.515151E7') return '15151510';
  if (s.endsWith('.0') && /^\d+\.0$/.test(s)) return s.slice(0, -2);
  return s;
}

function parseExcelDate(v) {
  if (!v) return null;
  if (v instanceof Date) {
    const y = v.getFullYear();
    return y < 2000 ? null : new Date(v.getTime() + 43200000).toISOString().slice(0, 10);
  }
  const s = String(v).trim();
  if (s === '21/1026') return '2026-10-21';
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  const num = Number(s);
  if (!isNaN(num) && num > 30000 && num < 80000) {
    const d = new Date(Math.round((num - 25569) * 86400 * 1000));
    return d.toISOString().slice(0, 10);
  }
  const dmy = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$/);
  if (dmy) {
    let [_, day, mon, yr] = dmy;
    if (yr.length === 2) yr = '20' + yr;
    return `${yr}-${mon.padStart(2, '0')}-${day.padStart(2, '0')}`;
  }
  return null;
}

function normStr(s) {
  return String(s || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]/g, '');
}

function matchProduct(plat, prods) {
  if (!plat || !prods || !prods.length) return '';
  const np = normStr(plat);
  let hit = prods.find(p => normStr(p.nombre) === np);
  if (hit) return hit.id;
  hit = prods.find(p => normStr(p.nombre).includes(np) || np.includes(normStr(p.nombre)));
  if (hit) return hit.id;
  if (np.includes('perfilextra')) return prods.find(p => normStr(p.nombre).includes('extra') || normStr(p.nombre).includes('perfilextra'))?.id || '';
  if (np.includes('disney')) return prods.find(p => normStr(p.nombre).includes('disney'))?.id || '';
  if (np.includes('max')) return prods.find(p => normStr(p.nombre).includes('max'))?.id || '';
  if (np.includes('prime')) return prods.find(p => normStr(p.nombre).includes('prime'))?.id || '';
  if (np.includes('vix')) return prods.find(p => normStr(p.nombre).includes('vix'))?.id || '';
  if (np.includes('crunchy')) return prods.find(p => normStr(p.nombre).includes('crunchy'))?.id || '';
  if (np.includes('paramount')) return prods.find(p => normStr(p.nombre).includes('paramount'))?.id || '';
  if (np.includes('telelatino')) return prods.find(p => normStr(p.nombre).includes('telelatino'))?.id || '';
  if (np.includes('flujo')) return prods.find(p => normStr(p.nombre).includes('flujo'))?.id || '';
  if (np.includes('netflix')) return prods.find(p => normStr(p.nombre).includes('netflix') && !normStr(p.nombre).includes('extra'))?.id || '';
  return '';
}

// Analizador universal compatible con hoja unificada y formato tradicional de pestañas
function parseAnySheet(ws, sheetName) {
  const rows = XLSX.utils.sheet_to_json(ws, { header: 1, raw: true, defval: null });
  const N = v => String(v ?? '').trim().toUpperCase().replace(/\s+/g, ' ');
  if (!rows || !rows.length) return { plataforma: sheetName, mothers: [], profiles: [] };

  // 1. Detectar si es hoja unificada con columna SERVICIO
  const unifiedHeaderIdx = rows.findIndex(r => r && r.some(c => N(c) === 'SERVICIO' || N(c).includes('SERVICIO')));
  if (unifiedHeaderIdx >= 0) {
    const H = {};
    rows[unifiedHeaderIdx].forEach((c, i) => { if (c != null && !(N(c) in H)) H[N(c)] = i; });
    const g = (r, ...keys) => {
      for (const k of keys) {
        if (H[k] !== undefined) {
          const v = r[H[k]];
          if (v != null && typeof v !== 'object' || v instanceof Date) return v;
        }
      }
      return null;
    };

    const byPlatform = {};
    for (const r of rows.slice(unifiedHeaderIdx + 1)) {
      const srv = g(r, 'SERVICIO');
      const email = g(r, 'CORREO DE LA CUENTA / CLIENTE', 'CORREO DE LA CUENTA', 'CORREO');
      if (!srv || !email) continue;
      const platKey = String(srv).trim().toUpperCase();
      if (!byPlatform[platKey]) {
        byPlatform[platKey] = { plataforma: platKey, mothers: [], profiles: [] };
      }
      const pGroup = byPlatform[platKey];
      const mailStr = String(email).trim();
      let clave = cleanValStr(g(r, 'CLAVE / ACCESO', 'CLAVE', 'ACCESO'));
      if (platKey === 'NETFLIX' && mailStr === 'dyny-94.skate.AR@xposemail.com') clave = 'XZ8585';
      if (platKey === 'TELELATINO' && mailStr === 'yynqkh') clave = 'maxter1112';

      let m = pGroup.mothers.find(x => x.correo.toLowerCase() === mailStr.toLowerCase());
      if (!m) {
        const sharedStr = String(g(r, '¿ES COMPARTIDA CON PERFILES?', 'COMPARTIDA') || '').toUpperCase();
        m = { plataforma: platKey, correo: mailStr, clave: clave || null, max_perfiles: sharedStr === 'NO' ? 1 : 5 };
        pGroup.mothers.push(m);
      } else if (clave && !m.clave) {
        m.clave = clave;
      }

      const perfilRaw = g(r, 'CLIENTE / PERFIL', 'PERFIL', 'CLIENTE');
      const pinRaw = cleanValStr(g(r, 'PIN'));
      const venceRaw = parseExcelDate(g(r, 'FECHA VENCE', 'VENCE', 'FECHA'));
      const vendRaw = cleanValStr(g(r, 'VENDEDOR / REVENDEDOR', 'VENDEDOR'));

      const isLibre = (!perfilRaw && !venceRaw) || (perfilRaw && ['disponible','libre','vacio','vacío','stock'].includes(String(perfilRaw).trim().toLowerCase()));
      const estado = isLibre ? 'disponible' : 'vendido';
      const profIndex = pGroup.profiles.filter(x => x.correo.toLowerCase() === mailStr.toLowerCase()).length + 1;
      const perfilNom = isLibre ? (platKey === 'PERFIL EXTRA NETFLIX' ? `Perfil Extra ${profIndex}` : `Perfil ${profIndex}`) : (perfilRaw ? String(perfilRaw).trim() : `Perfil ${profIndex}`);

      pGroup.profiles.push({
        correo: mailStr,
        perfil: perfilNom,
        pin: pinRaw || null,
        vendedor: isLibre ? null : (vendRaw || 'ADMIN'),
        inicia: null,
        vence: venceRaw || null,
        estado: estado
      });
    }

    return Object.values(byPlatform);
  }

  // 2. Formato tradicional por pestañas (CORREO + CLAVE)
  return parseSheet(ws, sheetName);
}

// Lee una hoja de plataforma tradicional: busca encabezados CORREO + CLAVE
function parseSheet(ws, plataforma) {
  const rows = XLSX.utils.sheet_to_json(ws, { header: 1, raw: true, defval: null }), N = v => String(v ?? '').trim().toUpperCase().replace(/\s+/g, ' ');
  const hi = rows.findIndex(r => r.some(c => N(c) === 'CORREO') && r.some(c => N(c) === 'CLAVE')); const out = { plataforma, mothers: [], profiles: [] };
  if (hi < 0) return out; const H = {}; rows[hi].forEach((c, i) => { if (c != null && !(N(c) in H)) H[N(c)] = i; });
  const g = (r, k) => { const v = r[H[k]]; return v == null || typeof v === 'object' && !(v instanceof Date) || String(v).startsWith('#') ? null : v; };
  const plus = (d, n) => { if (!d) return null; const x = new Date(d + 'T12:00:00Z'); x.setUTCDate(x.getUTCDate() + n); return x.toISOString().slice(0, 10); };
  let cur = null; const seen = new Set();
  for (const r of rows.slice(hi + 1)) {
    const mail = g(r, 'CORREO'), clave = cleanValStr(g(r, 'CLAVE'));
    if (typeof mail === 'string' && (mail.includes('@') || mail.trim().length > 3)) {
      const mailClean = mail.trim();
      cur = { plataforma, correo: mailClean, clave: clave == null ? null : String(clave) };
      if (!seen.has(cur.correo)) { seen.add(cur.correo); out.mothers.push(cur); }
    } else if (cur && clave != null && !cur.clave) cur.clave = String(clave);
    const perfil = g(r, 'PERFIL'), pin = cleanValStr(g(r, 'PIN')), ini = parseExcelDate(g(r, 'FECHA INICIO')), ven = parseExcelDate(g(r, 'FECHA VENCE') || g(r, 'VENCE'));
    if (!cur || (perfil == null && pin == null && !ini && !ven)) continue;
    out.profiles.push({
      correo: cur.correo,
      perfil: perfil == null ? null : String(perfil).trim(),
      pin: pin == null ? null : String(pin),
      vendedor: g(r, 'VENDEDOR') ? String(g(r, 'VENDEDOR')).trim() : null,
      inicia: ini,
      vence: ven || plus(ini, 30),
      estado: perfil != null || ini || ven ? 'vendido' : 'disponible'
    });
  }
  return out;
}
