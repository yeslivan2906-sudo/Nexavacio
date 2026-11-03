// Copia el juego (los mismos archivos de GitHub Pages) dentro de la app: carpeta www/.
// Se ejecuta solo en GitHub al compilar. No hace falta tocarlo.
const fs = require('fs'), path = require('path');
const raiz = path.resolve(__dirname, '..'), www = path.join(__dirname, 'www');
fs.rmSync(www, { recursive: true, force: true });
fs.mkdirSync(www, { recursive: true });
// (la app abre el juego publicado en GitHub Pages: así se actualiza solo, sin pasar por Play Store.
//  Esta copia queda adentro solo de respaldo, junto con la pantalla "sin internet")
fs.copyFileSync(path.join(__dirname, 'sin-internet.html'), path.join(www, 'sin-internet.html'));
const archivos = ['index.html', 'config_nube.js', 'manifest.webmanifest', 'icon-180.png', 'icon-192.png', 'icon-512.png', 'privacidad.html', 'borrar-cuenta.html'];
for (const f of archivos) {
    const src = path.join(raiz, f);
    if (fs.existsSync(src)) { fs.copyFileSync(src, path.join(www, f)); console.log('✔', f); }
    else if (f === 'index.html' || f === 'config_nube.js') { console.error('FALTA', f, 'en la raíz del repositorio'); process.exit(1); }
}
// la app no usa service worker (el juego ya va dentro)
const idx = path.join(www, 'index.html');
const html = fs.readFileSync(idx, 'utf8');
const m = html.match(/v\d{2,4}/); console.log('versión del juego:', m ? m[0] : '?');
