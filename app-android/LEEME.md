# Nexavacío · App de Android (el juego va DENTRO de la app)

- Ya no se abre el navegador: el juego viaja dentro de la app.
- Cada actualización del juego = una versión nueva en Play Store.
- GitHub arma y firma el archivo .aab solo (pestaña Actions).

Archivos:
- `android/` · el proyecto de Android (Capacitor). Nombre del paquete: com.nexavacio.laberinto
- `copiar-juego.js` · copia index.html, config_nube.js e iconos de la raíz del repositorio dentro de la app
- `../.github/workflows/app-android.yml` · las instrucciones para que GitHub compile

Para sacar una versión nueva:
1. Sube el index.html nuevo a la raíz del repositorio (como siempre).
2. Actions → "App Android (Play Store)" → Run workflow → número de versión MAYOR que el anterior.
3. Descarga el .aab de "Artifacts" y súbelo a Play Console.

La llave de firma NUNCA va en el repositorio: solo en Settings → Secrets.
