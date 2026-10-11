// Офлайн-режим: приложение целиком хранится на устройстве.
// При каждом обновлении приложения меняется номер версии ниже.
const VERSION = 'moyden-v5';
const ASSETS = [
  './', './index.html', './config.js', './manifest.webmanifest',
  './icons/icon-180.png', './icons/icon-192.png', './icons/icon-512.png', './icons/icon-maskable-512.png',
  './fonts/jost-cyrillic-400-normal.woff2', './fonts/jost-cyrillic-500-normal.woff2', './fonts/jost-cyrillic-600-normal.woff2',
  './fonts/jost-latin-400-normal.woff2', './fonts/jost-latin-500-normal.woff2', './fonts/jost-latin-600-normal.woff2'
];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k.startsWith('moyden-') && k !== VERSION).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  if (req.mode === 'navigate'){
    e.respondWith(caches.match('./index.html').then(r => r || fetch(req)));
    return;
  }
  if (url.pathname.endsWith('/config.js')){
    const fresh = fetch(req).then(r => {
      if (r.ok){ const copy = r.clone(); caches.open(VERSION).then(c => c.put('./config.js', copy)); }
      return r;
    });
    e.respondWith(caches.match('./config.js').then(r => r || fresh));
    e.waitUntil(fresh.catch(() => {}));
    return;
  }
  e.respondWith(caches.match(req, { ignoreSearch: true }).then(r => r || fetch(req)));
});
