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
