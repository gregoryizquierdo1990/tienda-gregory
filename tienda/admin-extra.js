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
    return sb.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: location.origin + '/',
        scopes: 'https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/contacts',
        queryParams: { prompt: 'consent' }
      }
    });
  },

  async listEvents({ timeMin, timeMax, maxResults = 100 } = {}) {
    const min = timeMin || new Date(Date.now() - 30 * 86400000).toISOString();
    let q = `timeMin=${encodeURIComponent(min)}&timeZone=${encodeURIComponent(this.TZ)}&maxResults=${maxResults}&singleEvents=true&orderBy=startTime`;
    if (timeMax) q += `&timeMax=${encodeURIComponent(timeMax)}`;
    try {
      const res = await G(`https://www.googleapis.com/calendar/v3/calendars/primary/events?${q}`);
      return res.items || [];
    } catch(e) {
      const res = await G(`https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(this.CAL_ID)}/events?${q}`);
      return res.items || [];
    }
  },

  async listMonthEvents(year, month) {
    const pad = n => String(n).padStart(2, '0');
    const startStr = `${year}-${pad(month)}-01T00:00:00Z`;
    const lastDay = new Date(year, month, 0).getDate();
    const endStr = `${year}-${pad(month)}-${pad(lastDay)}T23:59:59Z`;
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

function refundDlg(id, total, done) {
  $('#dlgBody').innerHTML = `<h3>Devolución</h3><p class="mut">Total del pedido: $${esc(total)}. Si dejas el monto vacío se devuelve todo (se libera el perfil y se anula la factura).</p>
  <input id="rm" type="number" step="0.01" min="0.01" max="${esc(total)}" placeholder="Monto USD (vacío = total)">
  <select id="rd" style="margin-top:8px"><option value="zeny">Devolver como ZenyPoints (automático)</option><option value="externo">Devolver por fuera (pago móvil, etc.)</option></select>
  <input id="rr" placeholder="Motivo" style="margin-top:8px"><select id="rl" style="margin-top:8px"><option value="true">Liberar el perfil (vuelve a disponible)</option><option value="false">Suspender el perfil (revisar o cambiar PIN antes)</option></select>
  <button id="rok" class="d" style="margin-top:10px;width:100%">Confirmar devolución</button>`; dlg.showModal();
  $('#rok').onclick = e => run(e.target, async () => { const { error } = await sb.rpc('refund_order', { p_order: id, p_monto: $('#rm').value ? +$('#rm').value : null, p_destino: $('#rd').value, p_motivo: $('#rr').value, p_liberar: $('#rl').value === 'true' }); if (error) throw error; done && done(); return 'Devolución registrada.'; });
}

async function transferDlg(orderId, done) {
  const { data: o } = await sb.from('orders').select('profile_id,products(nombre),profiles_inventory(nombre_perfil,mother_accounts(plataforma,correo))').eq('id', orderId).single();
  const pl = o?.profiles_inventory?.mother_accounts?.plataforma;
  const { data: libres } = await sb.from('profiles_inventory').select('id,nombre_perfil,mother_accounts(plataforma,correo)').eq('estado', 'disponible');
  const opts = (libres || []).filter(p => p.mother_accounts?.plataforma === pl);
  $('#dlgBody').innerHTML = `<h3>Trasladar cliente</h3><p class="mut">Actual: ${esc(pl)} · ${esc(o?.profiles_inventory?.mother_accounts?.correo)} · ${esc(o?.profiles_inventory?.nombre_perfil)}. Conserva los días que le quedan.</p>
  <select id="tp">${opts.length ? opts.map(p => `<option value="${p.id}">${esc(p.mother_accounts.correo)} · ${esc(p.nombre_perfil)}</option>`).join('') : '<option value="">No hay perfiles libres en esa plataforma</option>'}</select>
  <input id="tm" placeholder="Motivo (ej. cuenta con falla, cambio solicitado)" style="margin-top:8px">
  <select id="tl" style="margin-top:8px"><option value="true">Perfil anterior: liberarlo (vuelve a disponible)</option><option value="false">Perfil anterior: suspenderlo (la cuenta tiene fallas)</option></select>
  <button id="tok" style="margin-top:10px;width:100%" ${opts.length ? '' : 'disabled'}>Confirmar traslado</button>`; dlg.showModal();
  $('#tok').onclick = e => run(e.target, async () => { const { error } = await sb.rpc('transfer_order', { p_order: orderId, p_new_profile: $('#tp').value, p_motivo: $('#tm').value, p_liberar_anterior: $('#tl').value === 'true' }); if (error) throw error; done && done(); return 'Traslado registrado. El cliente ya ve sus nuevos accesos.'; });
}
async function genDlg(motherId, done) {
  const { data: prods } = await sb.from('products').select('id,nombre,tipo').order('nombre');
  $('#dlgBody').innerHTML = `<h3>Generar perfiles</h3><p class="mut">Crea perfiles disponibles para esta cuenta. Para vender la cuenta completa, genera 1 con un producto tipo cuenta_completa. Luego agrega el PIN de cada uno en profiles_inventory.</p>
  <select id="gp">${(prods || []).map(p => `<option value="${p.id}">${esc(p.nombre)} (${esc(p.tipo)})</option>`).join('')}</select>
  <input id="gq" type="number" min="1" max="20" value="5" style="margin-top:8px"><input id="gx" value="Perfil" style="margin-top:8px">
  <button id="gok" style="margin-top:10px;width:100%">Crear</button>`; dlg.showModal();
  $('#gok').onclick = e => run(e.target, async () => { const { error } = await sb.rpc('generate_profiles', { p_mother: motherId, p_product: $('#gp').value, p_cantidad: +$('#gq').value, p_prefijo: $('#gx').value || 'Perfil' }); if (error) throw error; done && done(); return 'Perfiles creados.'; });
}

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
    const { data: cfg } = await sb.from('settings').select('value').eq('key', 'notificaciones').maybeSingle();
    const { data: subs } = await sb.from('push_subscriptions').select('id,user_agent,created_at').order('created_at', { ascending: false });
    box.innerHTML = `<p class="mut">Avisos de pedidos, recargas, incidencias y vencimientos del día por <b>Telegram</b> y <b>push</b>: llegan aunque la app esté cerrada. Para Telegram, el bot debe estar conectado (pestaña telegram) y debes haberle escrito /start.</p>
    <label class="mut">Tu ID de Telegram</label><input id="tg" value="${esc(cfg?.value?.telegram_chat_id || '')}" inputmode="numeric" style="max-width:260px">
    <div class="row" style="margin:10px 0"><button id="n1">1. Activar / guardar</button><button id="n2">2. Activar push en este dispositivo</button><button class="g" id="n3">Enviar prueba</button></div>
    <h3>Dispositivos con push (${(subs || []).length})</h3>${(subs || []).map(s => `<div class="row card" style="margin-bottom:6px;justify-content:space-between"><span class="mut">${esc((s.user_agent || '').slice(0, 70))} · ${esc(String(s.created_at).slice(0, 10))}</span><button class="d" data-del="${s.id}">Quitar</button></div>`).join('') || '<p class="mut">Ninguno todavía.</p>'}`;
    $('#n1').onclick = e => run(e.target, async () => { await api('/api/notify-setup', { telegram_chat_id: $('#tg').value.trim() }); return 'Notificaciones activadas y datos guardados.'; });
    $('#n2').onclick = e => run(e.target, async () => { await pushSub(); EXTRA.notificaciones(box); return 'Este dispositivo recibirá notificaciones push.'; });
    $('#n3').onclick = e => run(e.target, async () => { const r = await api('/api/notify-test', {}); return `Prueba enviada. Telegram: ${r.telegram ? 'sí' : 'no'} · Push: ${r.push} dispositivo(s).` + (r.errores?.length ? '\n' + r.errores.join(' | ') : ''); });
    box.querySelectorAll('[data-del]').forEach(b => b.onclick = async () => { await sb.from('push_subscriptions').delete().eq('id', b.dataset.del); EXTRA.notificaciones(box); });
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

    box.innerHTML = '<p class="mut">Cargando calendario de vencimientos…</p>';

    // Consultamos pedidos entregados/activos y cuentas madre activas con fecha de vencimiento
    const [{ data: orders, error: errOrd }, { data: mothers, error: errMoth }] = await Promise.all([
      sb.from('orders')
        .select('id,customer_id,product_id,profile_id,total_usd,referencia,inicia,vence,gcal_event_id,estado,customers(nombre,email,telefono),products(nombre)')
        .not('vence', 'is', null)
        .gte('vence', startMonth)
        .lte('vence', endMonth),
      sb.from('mother_accounts')
        .select('id,plataforma,correo,vence,activa,proveedor')
        .not('vence', 'is', null)
        .gte('vence', startMonth)
        .lte('vence', endMonth)
    ]);

    if (errOrd || errMoth) {
      return box.innerHTML = `<p class="mut">Error al cargar datos: ${esc((errOrd || errMoth).message)}</p>`;
    }

    const monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    const todayStr = new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 10);

    // Mapear eventos por fecha (YYYY-MM-DD)
    const eventsByDate = {};
    (orders || []).forEach(o => {
      const d = o.vence;
      if (!eventsByDate[d]) eventsByDate[d] = { orders: [], mothers: [] };
      eventsByDate[d].orders.push(o);
    });
    (mothers || []).forEach(m => {
      const d = m.vence;
      if (!eventsByDate[d]) eventsByDate[d] = { orders: [], mothers: [] };
      eventsByDate[d].mothers.push(m);
    });

    const totalOrdersMonth = (orders || []).length;
    const totalMothersMonth = (mothers || []).length;
    const todayEvents = eventsByDate[todayStr] || { orders: [], mothers: [] };
    const todayTotal = todayEvents.orders.length + todayEvents.mothers.length;

    // Calculo de celdas de calendario estilo Hoja de Calculo Google Sheets (Empieza en DOMINGO como la plantilla)
    const firstDayIndex = new Date(state.year, state.month, 1).getDay(); // Domingo = 0, Lunes = 1, etc.
    const prevMonthDays = new Date(state.year, state.month, 0).getDate();

    const daysHtml = [];
    const weekHeaders = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'].map(d => `<div class="cal-sheet-th">${d}</div>`).join('');

    // Celdas del mes anterior (sombreadas en gris azulado como en la plantilla)
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
      const numMoth = ev?.mothers?.length || 0;

      let itemsHtml = '';
      if (numOrd > 0) itemsHtml += `<div class="cal-item-pill order" title="${numOrd} clientes">👤 ${numOrd} servicio${numOrd > 1 ? 's' : ''}</div>`;
      if (numMoth > 0) itemsHtml += `<div class="cal-item-pill mother" title="${numMoth} cuentas madre">🔑 ${numMoth} cuenta${numMoth > 1 ? 's' : ''}</div>`;

      daysHtml.push(`
        <div class="cal-sheet-cell ${isToday ? 'is-today' : ''} ${isSel ? 'is-selected' : ''}" data-day="${dStr}">
          <span class="cal-sheet-num">${d}</span>
          <div class="cal-sheet-items">${itemsHtml}</div>
        </div>
      `);
    }

    // Completar cuadrícula restante para múltiplos de 7 (sombreadas en gris azulado)
    const remainingDays = (7 - ((firstDayIndex + lastDayOfMonth) % 7)) % 7;
    for (let r = 1; r <= remainingDays; r++) {
      daysHtml.push(`<div class="cal-sheet-cell disabled"><span class="cal-sheet-num">${r}</span></div>`);
    }

    // Detalle del día seleccionado
    const selDate = state.selectedDate || todayStr;
    const selEvents = eventsByDate[selDate] || { orders: [], mothers: [] };
    const selTotal = selEvents.orders.length + selEvents.mothers.length;

    let detailHtml = `
      <div class="cal-detail">
        <div style="display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:8px;margin-bottom:12px">
          <h4 style="margin:0;font-size:1.05rem">Vencimientos para el <b>${selDate}</b> ${selDate === todayStr ? '· (Hoy)' : ''}</h4>
          <span class="mut" style="font-size:.8rem">${selTotal} vencimiento${selTotal === 1 ? '' : 's'} en total</span>
        </div>
    `;

    if (selTotal === 0) {
      detailHtml += '<p class="mut" style="margin:0">No hay servicios ni cuentas madre programados para vencer en esta fecha.</p>';
    } else {
      if (selEvents.orders.length > 0) {
        detailHtml += `
          <h5 style="margin:8px 0 6px;color:var(--c)">Servicios de Clientes (${selEvents.orders.length})</h5>
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
          <h5 style="margin:8px 0 6px;color:#ffb703">Cuentas Madre (${selEvents.mothers.length})</h5>
          <div class="wrap">
            <table>
              <tr><th>Plataforma</th><th>Correo Madre</th><th>Proveedor</th><th>Estado</th></tr>
              ${selEvents.mothers.map(m => `
                <tr>
                  <td><b>${esc(m.plataforma)}</b></td>
                  <td>${esc(m.correo)}</td>
                  <td>${esc(m.proveedor || '—')}</td>
                  <td><span class="pill ${m.activa ? '' : 'off'}">${m.activa ? 'Activa' : 'Inactiva'}</span></td>
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
            <div class="cal-sheet-title">Control de Vencimientos · Gregory Izquierdo</div>
            <h2 class="cal-sheet-month">${monthNames[state.month]} de ${state.year}</h2>
          </div>
          <div class="cal-sheet-tools" style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
            <button class="cal-sheet-btn" id="calPrev" type="button">◀ Anterior</button>
            <button class="cal-sheet-btn" id="calToday" type="button">Hoy</button>
            <button class="cal-sheet-btn" id="calNext" type="button">Siguiente ▶</button>
            <span style="border-left:1px solid rgba(255,255,255,.15);height:20px;margin:0 4px"></span>
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
          <div>NOTAS / RESUMEN: Hoy vencen ${todayTotal} · Total mes: ${totalOrdersMonth} servicios clientes y ${totalMothersMonth} cuentas madre.</div>
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

        // 2. Traer todos los pedidos del mes para comparar
        const { data: curOrders, error: curErr } = await sb.from('orders')
          .select('id,customer_id,product_id,profile_id,inicia,vence,gcal_event_id,estado,customers(nombre,email,telefono),products(nombre)')
          .not('vence', 'is', null)
          .gte('vence', startMonth)
          .lte('vence', endMonth);
        if (curErr) throw curErr;

        let updatedFromCalendar = 0;
        let pushedToCalendar = 0;

        // A) Calendar -> Plataforma: si el evento se movió de fecha en Google Calendar, actualizar pedidos en Supabase
        for (const ord of (curOrders || [])) {
          if (ord.gcal_event_id && gMap.has(ord.gcal_event_id)) {
            const ev = gMap.get(ord.gcal_event_id);
            const evDate = ev.start?.date || (ev.start?.dateTime ? ev.start.dateTime.slice(0, 10) : null);
            if (evDate && evDate !== ord.vence) {
              await sb.from('orders').update({ vence: evDate, proximo_pago: evDate }).eq('id', ord.id);
              if (ord.profile_id) {
                await sb.from('profiles_inventory').update({ vence: evDate }).eq('id', ord.profile_id).catch(() => {});
              }
              ord.vence = evDate;
              updatedFromCalendar++;
            }
          }
        }

        // B) Plataforma -> Calendar: si hay pedidos activos sin evento en Calendar, crearlos
        for (const ord of (curOrders || [])) {
          if (['pagado', 'entregado'].includes(ord.estado)) {
            const prodName = ord.products?.nombre || 'Servicio';
            const custName = ord.customers?.nombre || ord.customers?.email || 'Cliente';
            const evSummary = `Vence: ${prodName} · ${custName}`;
            const evDesc = `Pedido #${ord.id}
Cliente: ${custName}
Teléfono: ${ord.customers?.telefono || 'N/A'}
Servicio: ${prodName}
Fecha Vencimiento: ${ord.vence}`;

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
              // Si el ID guardado no existe en Google Calendar (fue borrado allá), recrear
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
        return `Sincronización completa: ${pushedToCalendar} eventos creados en Calendar, ${updatedFromCalendar} actualizados desde Calendar.`;
      });
    }

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
              await sb.from('profiles_inventory').update({ vence: newDate }).eq('id', oRow.profile_id).catch(() => {});
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
          await sb.from('profiles_inventory').update({ vence: nextVence }).eq('id', oData.profile_id).catch(()=>{});
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
          const waMsg = encodeURIComponent(rawMsg);
          window.open(`https://wa.me/${tel}?text=${waMsg}`, '_blank');
        }

        EXTRA.vencimientos(box);
        return `Suscripción de ${nom} renovada +30 días a crédito (Cobrar antes de ${fVenceCred}).`;
      });
    });
  },
  async finanzas(box) {
    const { data, error } = await sb.rpc('finanzas', { p_meses: 12 });
    if (error) return box.innerHTML = '<p>' + esc(error.message) + '</p>';
    const m = data[0] || {}, f = n => (n < 0 ? '-$' : '$') + Math.abs(Number(n || 0)).toFixed(2), cards = [['Ventas', m.ventas], ['Devoluciones', m.devoluciones], ['Gastos', m.gastos], ['Compras', m.compras]];
    box.innerHTML = `<div class="grid"><div class="card"><div class="mut">Ganancia de ${esc(String(m.mes || '').slice(0, 7))}</div><div class="price" style="color:${m.ganancia < 0 ? '#f87171' : 'var(--a)'}">${f(m.ganancia)}</div></div>${cards.map(([n, v]) => `<div class="card"><div class="mut">${n}</div><div class="price">${f(v)}</div></div>`).join('')}</div>
    <p class="mut">Ganancia = ventas − devoluciones − gastos − compras (USD). Las ventas cuentan al confirmar el pago; las devoluciones, el día que las registras. Las recargas Zeny no son venta hasta que se usan. Las cuentas madre con costo se anotan solas como compra.</p>
    <div class="row"><button class="g" id="g1">+ Gasto</button><button class="g" id="g2">+ Compra</button><button class="g" id="g3">Ver devoluciones</button></div>
    <div class="wrap" style="margin-top:12px"><table><tr><th>Mes</th><th>Ventas</th><th>Devol.</th><th>Gastos</th><th>Compras</th><th>Ganancia</th></tr>${data.map(r => `<tr><td>${esc(String(r.mes).slice(0, 7))}</td><td>${f(r.ventas)}</td><td>${f(r.devoluciones)}</td><td>${f(r.gastos)}</td><td>${f(r.compras)}</td><td><b>${f(r.ganancia)}</b></td></tr>`).join('')}</table></div>`;
    $('#g1').onclick = () => admin('expenses'); $('#g2').onclick = () => admin('purchases'); $('#g3').onclick = () => admin('refunds');
  },
  async google(box) {
    const { data: gi } = await sb.from('google_integrations').select('*');
    const on = k => !!gi?.find(x => x.service === k)?.enabled, has = !!sessionStorage.getItem('gtk');
    box.innerHTML = `<p class="mut">Estado: ${has ? '✅ conectado' : '⚠️ sin conectar'}. Cada servicio se puede activar o desactivar.</p>
    <div class="row"><button id="gc">Conectar Google</button></div>
    <div class="grid" style="margin-top:12px">${[['calendar', 'Calendar', 'Crear eventos de vencimientos'], ['sheets', 'Sheets', 'Respaldar clientes, pedidos e inventario'], ['drive', 'Drive', 'Subir respaldo JSON completo'], ['contacts', 'Contactos', 'Guardar clientes como contactos'], ['gemini', 'Gemini', 'Asistente (ver pestaña gemini)']].map(([k, n, d]) => `<div class="card"><b>${n}</b><div class="mut">${d}</div><label class="row" style="margin:8px 0"><input type="checkbox" style="width:auto" data-sv="${k}" ${on(k) ? 'checked' : ''}> Activado</label>${k !== 'gemini' ? `<button data-go="${k}" ${on(k) ? '' : 'disabled'}>Ejecutar</button>` : ''}</div>`).join('')}</div>`;
    $('#gc').onclick = () => sb.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: location.origin + '/', scopes: 'https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/contacts', queryParams: { prompt: 'consent' } } });
    box.querySelectorAll('[data-sv]').forEach(c => c.onchange = async () => { await sb.from('google_integrations').update({ enabled: c.checked, updated_at: new Date().toISOString() }).eq('service', c.dataset.sv); EXTRA.google(box); });
    const jobs = {
      async calendar() {
        const { data } = await sb.from('orders').select('id,vence,products(nombre),customers(nombre)').in('estado', ['pagado', 'entregado']).gte('vence', today()).is('gcal_event_id', null); let n = 0;
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
    const { data } = await sb.from('settings').select('value').eq('key', 'bot').maybeSingle();
    box.innerHTML = `<p class="mut">Bot: ${data?.value?.username ? '✅ @' + esc(data.value.username) : '⚠️ sin conectar'}. El token se guarda cifrado en el servidor y nunca vuelve al navegador.</p>
    <div class="row"><input id="tk" type="password" placeholder="Token de @BotFather" autocomplete="off" style="max-width:420px"><button id="cn">Conectar bot</button><button class="g" id="cm">Editar respuestas</button></div>
    <p class="mut">Variables en las respuestas: {tasa} {telefono} {correo}. El comando * es la respuesta por defecto.</p>`;
    $('#cm').onclick = () => admin('bot_commands');
    $('#cn').onclick = e => run(e.target, async () => { const r = await api('/api/telegram-setup', { token: $('#tk').value.trim() }); $('#tk').value = ''; EXTRA.telegram(box); return 'Conectado: @' + r.bot; });
  },

  async cuotas(box) {
    const { data: instList, error } = await sb.from('installments')
      .select('*, customers(nombre,email,telefono), orders(referencia, products(nombre))')
      .order('fecha_vencimiento', { ascending: true });

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
create policy installments_admin_all on installments for all to authenticated using (is_admin()) with check (is_admin());

alter table customers add column if not exists limite_credito numeric(10,2) not null default 10.00;
alter table customers add column if not exists nivel_credito text not null default 'Bronce';

create or replace function pay_installment(p_installment_id uuid, p_metodo_id uuid, p_referencia text)
returns void language plpgsql security definer set search_path = public as $$
declare inst installments; r numeric;
begin
  if auth.uid() is null then raise exception 'Inicia sesion'; end if;
  select * into inst from installments where id = p_installment_id for update;
  if not found then raise exception 'Cuota no encontrada'; end if;
  if inst.customer_id <> auth.uid() and not is_admin() then raise exception 'No autorizado'; end if;
  select bs_por_usd into r from exchange_rates order by fecha desc limit 1;
  update installments set estado = 'en_revision', metodo_id = p_metodo_id, referencia = left(coalesce(p_referencia,''), 120), tasa_bs = r, monto_bs = inst.monto_usd * coalesce(r, 0) where id = p_installment_id;
end $$;
grant execute on function pay_installment(uuid, uuid, text) to authenticated;

create or replace function approve_installment(p_installment_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'No autorizado'; end if;
  update installments set estado = 'pagada', pagada_at = coalesce(pagada_at, now()) where id = p_installment_id;
end $$;
grant execute on function approve_installment(uuid) to authenticated;`;
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
    const pendTotal = list.filter(c => c.estado !== 'pagada').reduce((a, c) => a + Number(c.monto_usd), 0);
    const revCount = list.filter(c => c.estado === 'en_revision').length;

    box.innerHTML = `
      <div class="card" style="margin-bottom:16px;background:linear-gradient(135deg,rgba(13,39,76,.85),rgba(7,20,40,.9))">
        <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px">
          <div>
            <h3 style="margin:0 0 4px;font-size:1.15rem">💳 Control y Cobranza de Cuotas (BNPL)</h3>
            <p class="mut" style="margin:0;font-size:.82rem">Gestiona los pagos en cuotas, aprueba abonos y envía recordatorios automáticos por WhatsApp.</p>
          </div>
          <div style="display:flex;gap:10px;text-align:right;align-items:center;flex-wrap:wrap">
            <button id="btnConfigCuotas" class="g" style="padding:6px 12px;font-size:.76rem">⚙️ Configurar % Inicial y N° Cuotas</button>
            <button id="btnManageCredits" class="g" style="padding:6px 12px;font-size:.76rem">👥 Asignar Límites a Usuarios</button>
            <div>
              <span class="mut" style="font-size:.72rem;display:block">Por cobrar:</span>
              <b style="font-size:1.2rem;color:var(--c)">$${pendTotal.toFixed(2)} USD</b>
            </div>
            ${revCount ? `
              <div>
                <span class="mut" style="font-size:.72rem;display:block">En revisión:</span>
                <span class="pill" style="font-size:.8rem">${revCount} por validar</span>
              </div>
            ` : ''}
          </div>
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
          ${list.map(c => {
            const isVencida = c.estado !== 'pagada' && c.fecha_vencimiento < todayStr;
            const statusClass = isVencida ? 'vencida' : c.estado;
            const statusLabel = isVencida ? 'Vencida' : (c.estado === 'en_revision' ? 'En revisión' : (c.estado === 'pagada' ? 'Pagada' : 'Pendiente'));
            const tel = (c.customers?.telefono || '').replace(/\D/g, '');
            const nom = c.customers?.nombre || c.customers?.email || 'Cliente';
            const rawMsg = formatMessageTemplate('cobro_cuota', {
              cliente: nom,
              producto: prod,
              cuota: c.numero_cuota,
              total_cuotas: c.total_cuotas,
              monto_usd: Number(c.monto_usd).toFixed(2),
              monto_bs: (Number(c.monto_usd) * (S.rate || 0)).toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2}),
              tasa_bcv: (S.rate || 0).toLocaleString('es-VE'),
              fecha_vencimiento: c.fecha_vencimiento
            });
            const waMsg = encodeURIComponent(rawMsg);

            return `
              <tr>
                <td><b>#${c.numero_cuota} de ${c.total_cuotas}</b></td>
                <td>
                  <b>${esc(nom)}</b>
                  <span class="mut" style="display:block;font-size:.72rem">${esc(c.customers?.email || '')}</span>
                </td>
                <td>${esc(prod)}</td>
                <td><b style="color:var(--c)">$${Number(c.monto_usd).toFixed(2)}</b></td>
                <td><span style="color:${isVencida ? '#ff4d6d' : 'inherit'}">${esc(c.fecha_vencimiento)}</span></td>
                <td><span class="bnpl-inst-pill ${statusClass}">${statusLabel}</span></td>
                <td><code>${esc(c.referencia || '—')}</code></td>
                <td class="row">
                  ${c.estado !== 'pagada' ? `
                    <button data-ok-inst="${c.id}" style="padding:6px 10px;font-size:.75rem">Aprobar</button>
                  ` : '<span class="mut" style="font-size:.75rem">✓ Pagada</span>'}
                  ${tel && c.estado !== 'pagada' ? `
                    <a class="g" href="https://wa.me/${tel}?text=${waMsg}" target="_blank" rel="noopener noreferrer" style="text-decoration:none;padding:6px 10px;font-size:.75rem;display:inline-flex;align-items:center;gap:4px">
                      💬 Recordar WA
                    </a>
                  ` : ''}
                </td>
              </tr>
            `;
          }).join('') || '<tr><td colspan="8" class="mut empty">Aún no hay compras con cuotas registradas.</td></tr>'}
        </table>
      </div>
    `;

    box.querySelectorAll('[data-ok-inst]').forEach(btn => {
      btn.onclick = () => run(btn, async () => {
        const id = btn.dataset.okInst;
        const { error } = await sb.rpc('approve_installment', { p_installment_id: id });
        if (error) throw error;
        EXTRA.cuotas(box);
        return 'Cuota aprobada con éxito.';
      });
    });

    const bCfg = box.querySelector('#btnConfigCuotas');
    if(bCfg){
      bCfg.onclick = async () => {
        let cfg = S.settings?.cuotas_config;
        if(!cfg){
          const { data } = await sb.from('settings').select('value').eq('key', 'cuotas_config').maybeSingle();
          cfg = data?.value || { inicial_porcentaje: 50, total_cuotas: 2, dias_frecuencia: 15, monto_minimo: 5.00 };
        }
        $('#dlgBody').innerHTML = `
          <h3>⚙️ Parámetros de Financiamiento en Cuotas</h3>
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
    const { data: franqList, error } = await sb.from('franchises').select('*').order('created_at', { ascending: false });

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

      <!-- Tabla de Franquicias -->
      <div class="wrap">
        <table>
          <tr>
            <th>Franquicia / URL</th>
            <th>Titular / Contacto</th>
            <th>Canon Mensual</th>
            <th>Vencimiento</th>
            <th>Estado</th>
            <th>Acciones</th>
          </tr>
          ${list.map(f => {
            const franqUrl = `https://${f.subdominio}.${baseDomain}`;
            const stLabel = f.estado === 'activo' ? '🟢 Activo' : (f.estado === 'suspendido_fraude' ? '🚨 Suspendido Fraude' : (f.estado === 'suspendido_mora' ? '🟡 Suspendido Mora' : 'En revisión'));
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
                  <b>$${Number(f.canon_mensual_usd).toFixed(2)} USD/mes</b>
                  <button class="g" data-edit-canon="${f.id}" data-cur="${f.canon_mensual_usd}" data-nom="${esc(f.nombre_comercial)}" style="padding:2px 6px;font-size:.7rem;margin-left:4px" title="Modificar canon de esta franquicia">✏️</button>
                </td>
                <td>${esc(f.fecha_vencimiento_canon)}</td>
                <td><span class="pill ${f.estado === 'activo' ? '' : 'off'}">${stLabel}</span></td>
                <td class="row">
                  <button class="g" data-fq-invoice="${f.id}" title="Emitir Factura / Recibo de Arrendamiento SaaS">🧾 Factura Canon</button>
                  <button class="g" data-fq-view="${f.id}" title="Ver expediente, contrato y detalles comerciales">📄 Expediente</button>
                  <button class="g" data-fq-reset="${f.id}" data-email="${esc(f.titular_correo)}" title="Restaurar clave de acceso del franquiciado">🔑 Reset Clave</button>
                  ${f.estado === 'activo' ? `
                    <button class="d" data-fq-kill="${f.id}" data-sub="${esc(f.subdominio)}" title="Kill-Switch: suspender inmediatamente">🚨 Suspender</button>
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
        btn.disabled = true;
        const sub = $('#fqSub').value.trim().toLowerCase();
        const name = $('#fqName').value.trim();
        const owner = $('#fqOwner').value.trim();
        const email = $('#fqEmail').value.trim();
        const tel = $('#fqTel').value.trim();
        const canon = Number($('#fqCanon').value || 25);
        const stockMode = $('#fqStockMode')?.value || 'hibrido';

        if (!sub || !name || !owner || !email || !tel) {
          btn.disabled = false;
          return toast('Por favor completa todos los campos requeridos.');
        }

        const contractText = `CONTRATO DE LICENCIA DE SOFTWARE Y FRANQUICIA DIGITAL MARCA BLANCA

Entre EMPRENDIMIENTO GREGORY IZQUIERDO (en adelante "El Proveedor Tecnológico") y ${owner}, titular de ${name} (en adelante "El Franquiciado").

1. OBJETO: El Proveedor otorga una licencia de uso de la plataforma web en el subdominio https://${sub}.${baseDomain}.
2. AUTONOMÍA Y DESLINDE DE RESPONSABILIDAD: El Franquiciado opera de manera comercialmente independiente. Todos los cobros, métodos de pago, garantías y atención al cliente son de su exclusiva responsabilidad. El Proveedor no asume responsabilidad solidaria ante clientes finales de la Franquicia.
3. CANON MENSUAL: El Franquiciado se compromete a cancelar un canon mensual de $${canon} USD cada 30 días continuos.
4. KILL-SWITCH Y TOLERANCIA CERO AL FRAUDE: El Proveedor se reserva el derecho de suspender de inmediato el subdominio y acceso ante cualquier denuncia fundamentada de fraude o estafa.
5. MODALIDAD DE INVENTARIO HÍBRIDO (${stockMode.toUpperCase()}): El Franquiciado comercializa servicios con cuentas y perfiles propios o, ante falta de stock, despacha directamente con respaldo del inventario central a tarifa mayorista preferencial.
Fecha de asentamiento: ${new Date().toISOString().slice(0, 10)}.`;

        const { error: insErr } = await sb.from('franchises').insert({
          subdominio: sub,
          nombre_comercial: name,
          titular_nombre: owner,
          titular_cedula_rif: $('#fqDoc').value.trim(),
          titular_telefono: tel,
          titular_correo: email,
          titular_ciudad: $('#fqCity').value.trim(),
          canon_mensual_usd: canon,
          notas_internas: $('#fqNotes').value.trim(),
          contrato_texto: contractText,
          estado: 'activo'
        });

        if (insErr) {
          btn.disabled = false;
          return toast(insErr.message.includes('unique') ? 'Ese subdominio ya está en uso. Elige otro.' : insErr.message);
        }

        dlg.close();
        toast(`¡Franquicia ${name} creada exitosamente!`);
        EXTRA.franquicias(box);
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
        await sb.from('franchises').update({ estado: 'suspendido_fraude' }).eq('id', id);
        toast(`Franquicia ${sub} suspendida preventivamente.`);
        EXTRA.franquicias(box);
      };
    });

    // Reactivar
    box.querySelectorAll('[data-fq-reactivate]').forEach(btn => {
      btn.onclick = async () => {
        await sb.from('franchises').update({ estado: 'activo' }).eq('id', btn.dataset.fqReactivate);
        toast('Franquicia reactivada exitosamente.');
        EXTRA.franquicias(box);
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

          <label class="mut" style="font-size:.76rem">Fecha de Vencimiento (MM/YY):</label>
          <input id="emitExpInput" value="12/31" maxlength="5" style="font-family:monospace;max-width:140px" required>

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
                <div style="display:flex;justify-content:space-between;align-items:flex-start">
                  <div class="zeny-card-chip"></div>
                  <span style="font-size:.65rem;font-weight:800;letter-spacing:1px;color:#fde047">ZENY CARD</span>
                </div>
                <div>
                  <div class="zeny-card-number">${esc(c.numero_tarjeta)}</div>
                  <div style="display:flex;justify-content:space-between;align-items:flex-end">
                    <div>
                      <span style="font-size:.65rem;color:#cbd5e1;display:block">TITULAR</span>
                      <div class="zeny-card-holder">${esc(c.nombre_titular)}</div>
                    </div>
                    <div style="text-align:right">
                      <span style="font-size:.65rem;color:#cbd5e1;display:block">VENCE</span>
                      <div class="zeny-card-expiry">${esc(c.fecha_vencimiento)}</div>
                    </div>
                  </div>
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

  async gemini(box) {
    box.innerHTML = `<textarea id="gp" rows="5" placeholder="Pídele a Gemini: redactar promociones, mensajes de cobro, respuestas para clientes…"></textarea><div class="row" style="margin:8px 0"><button id="gg2">Preguntar</button></div><pre id="go" style="white-space:pre-wrap" class="card"></pre>`;
    $('#gg2').onclick = e => run(e.target, async () => { const r = await api('/api/gemini', { prompt: $('#gp').value }); $('#go').textContent = r.text; return 'Listo'; });
  },

  async importar(box) {
    const { data: prods } = await sb.from('products').select('id,nombre').order('nombre');
    box.innerHTML = `<p class="mut">Sube tu hoja CONTROL_CUENTAS. Se lee en tu navegador (no se sube a ningún servidor), las claves y PIN se cifran al guardar. Es seguro repetirlo: las cuentas ya existentes se omiten.</p><input type="file" id="xf" accept=".xlsx"><div id="pv"></div>`;
    $('#xf').onchange = async e => {
      try { await loadXLSX(); } catch (err) { return toast(err.message); }
      const wb = XLSX.read(await e.target.files[0].arrayBuffer(), { type: 'array', cellDates: true }), found = [];
      for (const name of wb.SheetNames) { const r = parseSheet(wb.Sheets[name], name.trim()); if (r.profiles.length || r.mothers.length) found.push(r); }
      $('#pv').innerHTML = found.length ? `<div class="wrap"><table><tr><th>Plataforma</th><th>Cuentas</th><th>Perfiles</th><th>Asignar a producto</th></tr>${found.map((f, i) => `<tr><td>${esc(f.plataforma)}</td><td>${f.mothers.length}</td><td>${f.profiles.length}</td><td><select data-i="${i}"><option value="">(sin asignar)</option>${(prods || []).map(p => `<option value="${p.id}">${esc(p.nombre)}</option>`).join('')}</select></td></tr>`).join('')}</table></div><button id="im" style="margin-top:10px">Importar</button>` : '<p>No se encontraron hojas con columnas CORREO y CLAVE.</p>';
      if (found.length) $('#im').onclick = ev => run(ev.target, async () => {
        let nm = 0, np = 0; const { data: ex } = await sb.from('mother_accounts').select('id,plataforma,correo'); const key = (p, c) => p + '|' + c, ids = Object.fromEntries((ex || []).map(m => [key(m.plataforma, m.correo), m.id]));
        for (const [i, f] of found.entries()) {
          const pid = $(`[data-i="${i}"]`).value || null, add = f.mothers.filter(m => !ids[key(m.plataforma, m.correo)]);
          if (add.length) { const { data, error } = await sb.from('mother_accounts').insert(add).select('id,plataforma,correo'); if (error) throw error; data.forEach(m => ids[key(m.plataforma, m.correo)] = m.id); nm += data.length; }
          const rows = f.profiles.map(p => ({ mother_id: ids[key(f.plataforma, p.correo)], product_id: pid, nombre_perfil: p.perfil, pin: p.pin, vendedor: p.vendedor, inicia: p.inicia, vence: p.vence, estado: p.estado })).filter(r => r.mother_id);
          for (let k = 0; k < rows.length; k += 400) { const { error } = await sb.from('profiles_inventory').insert(rows.slice(k, k + 400)); if (error) throw error; np += Math.min(400, rows.length - k); }
        }
        return `Importado: ${nm} cuentas madre y ${np} perfiles.`;
      });
    };
  },

  async plantillas(box) {
    box.innerHTML = '<div style="padding:40px 10px;text-align:center"><div class="sk" style="max-width:300px;margin:auto"></div><p class="mut" style="margin-top:10px">Cargando plantillas de mensajes…</p></div>';

    let tpls = S.settings?.plantillas_mensajes;
    if(!tpls){
      const { data } = await sb.from('settings').select('value').eq('key', 'plantillas_mensajes').maybeSingle();
      if(data?.value && typeof data.value === 'object'){
        tpls = data.value;
      } else {
        tpls = JSON.parse(JSON.stringify(DEFAULT_MESSAGE_TEMPLATES));
      }
      S.settings = S.settings || {};
      S.settings.plantillas_mensajes = tpls;
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
      estado: 'Activo'
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
        'numero_tarjeta', 'codigo_activacion', 'garantia', 'portal_url', 'negocio', 'rif'
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
  }
};

// Lee una hoja de plataforma: encuentra la fila de encabezados (CORREO + CLAVE) y arrastra la cuenta madre hacia abajo
function parseSheet(ws, plataforma) {
  const rows = XLSX.utils.sheet_to_json(ws, { header: 1, raw: true, defval: null }), N = v => String(v ?? '').trim().toUpperCase().replace(/\s+/g, ' ');
  const hi = rows.findIndex(r => r.some(c => N(c) === 'CORREO') && r.some(c => N(c) === 'CLAVE')); const out = { plataforma, mothers: [], profiles: [] };
  if (hi < 0) return out; const H = {}; rows[hi].forEach((c, i) => { if (c != null && !(N(c) in H)) H[N(c)] = i; });
  const g = (r, k) => { const v = r[H[k]]; return v == null || typeof v === 'object' && !(v instanceof Date) || String(v).startsWith('#') ? null : v; };
  const D = v => { if (v instanceof Date) { const y = v.getFullYear(); return y < 2000 ? null : new Date(v.getTime() + 43200000).toISOString().slice(0, 10); } return null; };
  const plus = (d, n) => { if (!d) return null; const x = new Date(d + 'T12:00:00Z'); x.setUTCDate(x.getUTCDate() + n); return x.toISOString().slice(0, 10); };
  let cur = null; const seen = new Set();
  for (const r of rows.slice(hi + 1)) {
    const mail = g(r, 'CORREO'), clave = g(r, 'CLAVE');
    if (typeof mail === 'string' && mail.includes('@')) { cur = { plataforma, correo: mail.trim().toLowerCase(), clave: clave == null ? null : String(clave) }; if (!seen.has(cur.correo)) { seen.add(cur.correo); out.mothers.push(cur); } }
    else if (cur && clave != null && !cur.clave) cur.clave = String(clave);
    const perfil = g(r, 'PERFIL'), pin = g(r, 'PIN'), ini = D(r[H['FECHA INICIO']]);
    if (!cur || (perfil == null && pin == null && !ini)) continue;
    out.profiles.push({ correo: cur.correo, perfil: perfil == null ? null : String(perfil).trim(), pin: pin == null ? null : String(pin), vendedor: g(r, 'VENDEDOR') ? String(g(r, 'VENDEDOR')).trim() : null, inicia: ini, vence: plus(ini, 30), estado: perfil != null || ini ? 'vendido' : 'disponible' });
  }
  return out;
}
