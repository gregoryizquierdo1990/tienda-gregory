// Service worker: solo guarda la "cascara" de la app (mismo origen). Los datos viven en Supabase y NUNCA se guardan aqui,
// por eso la app siempre muestra informacion en tiempo real y no se cachean credenciales ni datos personales.
const V = 'gi-v9', SHELL = ['/', '/index.html', '/config.js', '/manifest.webmanifest', '/icon-192.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(V).then(c => c.addAll(SHELL))); self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(k => Promise.all(k.filter(x => x !== V).map(x => caches.delete(x)))).then(() => clients.claim())); });
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin || u.pathname.startsWith('/api/')) return;
  e.respondWith(fetch(e.request).then(r => { const c = r.clone(); caches.open(V).then(x => x.put(e.request, c)); return r; })
    .catch(() => caches.match(e.request).then(m => m || caches.match('/index.html'))));
});

// Notificaciones push (llegan con la app cerrada)
self.addEventListener('push', e => {
  let d = {}; try { d = e.data.json(); } catch {}
  e.waitUntil(self.registration.showNotification(d.title || 'Gregory Izquierdo', { body: d.body || '', icon: '/icon-192.png', badge: '/icon-192.png', tag: d.tag || 'gi', renotify: true, vibrate: [200, 100, 200], data: { url: d.url || '/' } }));
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(l => { for (const c of l) if ('focus' in c) return c.focus(); return clients.openWindow(e.notification.data?.url || '/'); }));
});
