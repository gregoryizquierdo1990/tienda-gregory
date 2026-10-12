// Herramientas avanzadas del panel: Google, Telegram, Gemini e importador de la hoja de control
const today = () => new Date().toISOString().slice(0, 10);
const addDay = d => { const x = new Date(d + 'T12:00:00Z'); x.setUTCDate(x.getUTCDate() + 1); return x.toISOString().slice(0, 10); };
const jwt = async () => (await sb.auth.getSession()).data.session?.access_token;
const api = async (path, body) => { const r = await fetch(path, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + await jwt() }, body: JSON.stringify(body) }); const j = await r.json().catch(() => ({})); if (!r.ok) throw new Error(j.error || r.status); return j; };
const G = async (url, opt = {}) => {
  const t = sessionStorage.getItem('gtk'); if (!t) throw new Error('Conecta Google primero (botón "Conectar Google").');
  const r = await fetch(url, { ...opt, headers: { Authorization: 'Bearer ' + t, 'Content-Type': 'application/json', ...(opt.headers || {}) } });
  if (r.status === 401) { sessionStorage.removeItem('gtk'); throw new Error('Sesión de Google vencida: vuelve a conectar.'); }
  if (!r.ok) throw new Error((await r.text()).slice(0, 200)); return r.json();
};
const dump = async () => { const o = {}; for (const t of ['settings', 'customers', 'products', 'categories', 'banners', 'orders', 'invoices', 'zeny_ledger', 'payment_methods', 'faqs', 'incidents', 'bot_commands', 'exchange_rates']) o[t] = (await sb.from(t).select('*')).data || []; return o; };
const loadXLSX = () => window.XLSX ? Promise.resolve() : new Promise((ok, ko) => { const s = document.createElement('script'); s.src = 'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js'; s.onload = ok; s.onerror = () => ko(new Error('No se pudo cargar el lector de Excel')); document.head.appendChild(s); });
const run = async (btn, fn) => { btn.disabled = true; try { toast(await fn()); } catch (e) { toast('Error: ' + e.message); } btn.disabled = false; };

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

    box.innerHTML = '<p class="mut">Cargando calendario de vencimientos…</p>';

    // Consultamos pedidos entregados/activos y cuentas madre activas con fecha de vencimiento
    const [{ data: orders, error: errOrd }, { data: mothers, error: errMoth }] = await Promise.all([
      sb.from('orders')
        .select('id,customer_id,product_id,inicia,vence,estado,customers(nombre,email,telefono),products(nombre)')
        .not('vence', 'is', null)
        .gte('vence', `${state.year}-${pad(state.month + 1)}-01`)
        .lte('vence', `${state.year}-${pad(state.month + 1)}-${pad(lastDayOfMonth)}`),
      sb.from('mother_accounts')
        .select('id,plataforma,correo,vence,activa,proveedor')
        .not('vence', 'is', null)
        .gte('vence', `${state.year}-${pad(state.month + 1)}-01`)
        .lte('vence', `${state.year}-${pad(state.month + 1)}-${pad(lastDayOfMonth)}`)
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
              <tr><th>Pedido</th><th>Cliente</th><th>Servicio</th><th>Contacto</th><th>Estado</th><th>Acciones</th></tr>
              ${selEvents.orders.map(o => `
                <tr>
                  <td><b>#${esc(String(o.id).slice(0, 8))}</b></td>
                  <td>${esc(o.customers?.nombre || o.customers?.email || 'Cliente')}</td>
                  <td><b>${esc(o.products?.nombre || '—')}</b></td>
                  <td>${esc(o.customers?.telefono || o.customers?.email || '—')}</td>
                  <td><span class="pill ${o.estado === 'entregado' ? '' : 'off'}">${esc(o.estado)}</span></td>
                  <td class="row">
                    <button class="g" data-cal-renov="${o.id}" data-pid="${o.product_id}" data-uid="${o.customer_id}" data-nom="${esc(o.customers?.nombre || o.customers?.email || 'Cliente')}" data-tel="${esc(o.customers?.telefono || '')}" data-prod="${esc(o.products?.nombre || 'Servicio')}" style="padding:5px 9px;font-size:.73rem">
                      💳 Renovar a Crédito
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
          <div class="cal-sheet-tools">
            <button class="cal-sheet-btn" id="calPrev" type="button">◀ Anterior</button>
            <button class="cal-sheet-btn" id="calToday" type="button">Hoy</button>
            <button class="cal-sheet-btn" id="calNext" type="button">Siguiente ▶</button>
          </div>
        </div>

        <div class="cal-sheet-grid">
          ${weekHeaders}
          ${daysHtml.join('')}
        </div>

        <div class="cal-sheet-notes">
          NOTAS / RESUMEN: Hoy vencen ${todayTotal} · Total mes: ${totalOrdersMonth} servicios clientes y ${totalMothersMonth} cuentas madre.
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

    box.querySelectorAll('[data-day]').forEach(cell => {
      cell.onclick = () => {
        state.selectedDate = cell.dataset.day;
        EXTRA.vencimientos(box);
      };
    });

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

        if(tel){
          const waMsg = encodeURIComponent(`Hola ${nom}! Te saludamos de Emprendimiento Gregory Izquierdo. Tu suscripción de ${prod} ha sido RENOVADA a CRÉDITO por 30 días más (vence el ${nextVence}). Monto pendiente: $${oData.total_usd} USD. Fecha límite para el pago: ${fVenceCred}. ¡Muchas gracias por tu preferencia!`);
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

alter table customers add column if not exists limite_credito numeric(10,2) not null default 30.00;
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
          <div style="display:flex;gap:12px;text-align:right">
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
            const prod = c.orders?.products?.nombre || 'Servicio';
            const waMsg = encodeURIComponent(`Hola ${nom}! Te saludamos de Emprendimiento Gregory Izquierdo. Te recordamos tu cuota #${c.numero_cuota} de ${prod} por $${Number(c.monto_usd).toFixed(2)} USD (vence el ${c.fecha_vencimiento}). Puedes reportar tu pago móvil o transferencia desde tu portal.`);

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

    box.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:16px">
        <div>
          <h3 style="margin:0 0 4px;font-size:1.2rem">🏢 Red de Franquicias Digitales (SaaS)</h3>
          <p class="mut" style="margin:0;font-size:.82rem">Administra subdominios, contratos legales, canones mensuales y configuración técnica de tus franquiciados.</p>
        </div>
        <div class="row">
          <button id="btnNewFranq">+ Nueva Franquicia</button>
          <button class="g" id="btnFranqManual">📘 Manual para Franquiciado</button>
          <button class="g" id="btnFranqGuide">📖 Guía de Operación DNS</button>
        </div>
      </div>

      <!-- Resumen Métrico -->
      <div class="grid" style="margin-bottom:18px">
        <div class="card">
          <div class="mut">Franquicias Activas</div>
          <div class="price">${list.filter(f => f.estado === 'activo').length}</div>
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
                <td><b>$${Number(f.canon_mensual_usd).toFixed(2)} USD/mes</b></td>
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

5. CÓMO VENDER Y ENTREGAR:
- Catálogo: Ajusta precios de venta al público en USD o activa promociones.
- Pedidos: Cuando un cliente reporta un pago, verifica en tu banco y pulsa "Aprobar" para que el sistema le libere el servicio de forma automática.
- Cuentas y Perfiles: Registra cuentas madre o perfiles para despacho inmediato.
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
          <input id="fqCanon" type="number" value="25" min="0" step="1" required>

          <label class="mut" style="font-size:.76rem">Notas internas / Acuerdos especiales:</label>
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
  },

  async tarjetas(box) {
    const [{ data: cards, error: cardErr }, { data: custs, error: custErr }] = await Promise.all([
      sb.from('zeny_cards').select('*, customers(id,nombre,email,telefono,codigo_identificacion,es_revendedor,zeny_balance)').order('created_at', { ascending: false }),
      sb.from('customers').select('id,nombre,email,telefono,codigo_identificacion,es_revendedor,zeny_balance').order('creado', { ascending: false })
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
            <th>Saldo Zeny</th>
            <th>Acción de Rol</th>
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
              <td>${Number(u.zeny_balance || 0).toFixed(2)} ZP</td>
              <td>
                <button class="g" data-switch-role="${u.id}" data-to-rev="${!u.es_revendedor}" data-nom="${esc(u.nombre || u.email)}" style="padding:5px 10px;font-size:.76rem">
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
