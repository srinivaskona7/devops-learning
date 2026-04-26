/* sw.js — DevOps Learning Lab service worker.
 * Strategy: stale-while-revalidate for HTML/CSS/JS/SVG; cache-first for assets.
 */
const VERSION = 'dl-v1';
const CORE = [
  '/',
  '/index.html',
  '/manifest.webmanifest',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(VERSION).then(c => c.addAll(CORE).catch(() => {}))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== VERSION).map(k => caches.delete(k))
    ))
  );
  self.clients.claim();
});

function cacheable(req) {
  if (req.method !== 'GET') return false;
  const u = new URL(req.url);
  if (u.origin !== location.origin) return false;
  return /\.(html|css|js|svg|png|jpg|jpeg|webp|woff2?)$/.test(u.pathname)
    || u.pathname.endsWith('/')
    || u.pathname.includes('/assets/diagrams/');
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (!cacheable(req)) return;
  event.respondWith((async () => {
    const cache = await caches.open(VERSION);
    const cached = await cache.match(req);
    const network = fetch(req).then(res => {
      if (res && res.ok) cache.put(req, res.clone()).catch(() => {});
      return res;
    }).catch(() => cached);
    return cached || network;
  })());
});
