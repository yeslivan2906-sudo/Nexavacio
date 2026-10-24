// ======================================================================
// Nexavacio · sw.js  (service worker)
// Permite INSTALAR el juego en el celular y jugar SIN INTERNET.
// Cómo funcionan las actualizaciones:
//   · Cada vez que subes archivos nuevos, cambia VERSION aquí abajo (v69 → v70…).
//   · Con internet, el juego siempre pide primero los archivos nuevos al servidor;
//     sin internet, usa los guardados en el teléfono.
//   · Cuando el teléfono detecta la versión nueva, el juego muestra un aviso
//     "Hay una versión nueva · Tocar para actualizar".
// No hace falta escribir la lista de archivos: se leen solos de index.html.
// ======================================================================
const VERSION = 'v69-sueltos';
const CACHE = 'nexavacio-' + VERSION;

self.addEventListener('install', e => {
    e.waitUntil((async () => {
        const c = await caches.open(CACHE);
        // Uno por uno: si un archivo falta (p. ej. un icono en otra carpeta), la instalación NO se cae
        // y la versión nueva siempre llega.
        const put = async u => { try { const r = await fetch(u, { cache: 'no-cache' }); if (r && r.ok) await c.put(u, r); } catch (e) {} };
        await Promise.all(['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png', './icons/icon-192.png', './icons/icon-512.png'].map(put));
        try {
            const html = await (await fetch('./index.html', { cache: 'no-cache' })).text();
            const files = [...html.matchAll(/src="(\.\/[^"]+)"/g)].map(m => m[1]);
            await Promise.all(files.map(put));
        } catch (e) {}
    })());
    self.skipWaiting();
});

self.addEventListener('activate', e => {
    e.waitUntil((async () => {
        for (const k of await caches.keys()) if (k.startsWith('nexavacio-') && k !== CACHE) await caches.delete(k);
        await self.clients.claim();
    })());
});

// Primero internet (archivos frescos); si no hay conexión, lo guardado.
self.addEventListener('fetch', e => {
    const req = e.request;
    if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
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
