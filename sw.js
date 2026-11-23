// ======================================================================
// Nexavacio · sw.js  (service worker) · v183
// Permite INSTALAR el juego en el celular, abrir MÁS RÁPIDO y jugar SIN INTERNET.
//   · index.html y los demás archivos sueltos: primero internet (siempre la versión nueva);
//     sin internet, lo guardado.
//   · carpeta recursos/ (imágenes, video, librerías): sus nombres cambian cuando cambia el archivo,
//     así que se guardan en el teléfono UNA vez y luego se abren al instante, sin volver a bajarlos.
// Al subir una versión nueva: cambia VERSION aquí abajo.
// ======================================================================
const VERSION = 'v183';
const CACHE = 'nexavacio-' + VERSION;
const RES = 'nexavacio-recursos';            // no se borra entre versiones: los archivos tienen huella

self.addEventListener('install', e => {
    e.waitUntil((async () => {
        const c = await caches.open(CACHE), r = await caches.open(RES);
        const put = async (cache, u) => { try { if (cache === r && await r.match(u)) return; const res = await fetch(u, { cache: 'no-cache' }); if (res && res.ok) await cache.put(u, res); } catch (e) {} };
        await Promise.all(['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png', './config_nube.js'].map(u => put(c, u)));
        try {
            const html = await (await fetch('./index.html', { cache: 'no-cache' })).text();
            const files = [...new Set([...html.matchAll(/recursos\/[\w.-]+/g)].map(m => './' + m[0]))];
            for (let i = 0; i < files.length; i += 6) await Promise.all(files.slice(i, i + 6).map(u => put(r, u)));
        } catch (e) {}
    })());
    self.skipWaiting();
});

self.addEventListener('activate', e => {
    e.waitUntil((async () => {
        for (const k of await caches.keys()) if (k.startsWith('nexavacio-') && k !== CACHE && k !== RES) await caches.delete(k);
        // borrar recursos que ya no usa la versión actual
        try {
            const html = await (await caches.open(CACHE)).match('./index.html');
            if (html) {
                const keep = new Set([...(await html.text()).matchAll(/recursos\/[\w.-]+/g)].map(m => m[0]));
                const r = await caches.open(RES);
                for (const req of await r.keys()) { const m = req.url.match(/recursos\/[\w.-]+/); if (m && !keep.has(m[0])) await r.delete(req); }
            }
        } catch (e) {}
        await self.clients.claim();
    })());
});

self.addEventListener('fetch', e => {
    const req = e.request;
    if (req.method !== 'GET') return;
    const url = new URL(req.url);
    if (url.origin !== location.origin) return;
    if (/\/recursos\/[\w.-]+$/.test(url.pathname)) {
        // recursos: primero lo guardado
        e.respondWith((async () => {
            const r = await caches.open(RES), hit = await r.match(req, { ignoreSearch: true });
            if (hit) return hit;
            const res = await fetch(req);
            if (res && res.ok) r.put(req, res.clone());
            return res;
        })());
        return;
    }
    e.respondWith((async () => {
        try {
            const res = await fetch(req, { cache: 'no-cache' });
            if (res && res.ok) { const c = await caches.open(CACHE); c.put(req, res.clone()); }
            return res;
        } catch (err) {
            const hit = await caches.match(req, { ignoreSearch: true });
            return hit || caches.match('./index.html');
        }
    })());
});
