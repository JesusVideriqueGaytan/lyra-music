# Lyra Fase 3.4 — Sin Jamendo, fuentes abiertas y audio directo

## Qué cambió

- Se retiró completamente la integración de Jamendo: ya no se necesita su Client ID.
- Buscar música usa MusicBrainz sin requerir una cuenta.
- El resultado de MusicBrainz **es metadato**, no contiene un enlace directo al audio.
- Si la canción existe en la biblioteca local con título/artista coincidentes,
  Lyra permite escuchar el archivo local desde Explorar.
- Se incorpora un adaptador extensible de fuentes de audio. El primer adaptador
  permite agregar un **URL HTTPS directo** de una fuente de audio autorizada,
  con título/artista opcionales, y reproducir con el mismo motor y cola.
- En cada ficha se puede abrir la página de MusicBrainz o buscar el título
  en el **YouTube Music oficial**, en el navegador.
- Las cuentas YouTube/Google para consultar playlists se mantienen opcionales.
- No se instala ni ejecuta código de extensiones de terceros.

## Límites reales

- La búsqueda de MusicBrainz no garantiza que una grabación pueda escucharse.
- No transformamos páginas de Spotify/YouTube en URLs de audio.
- No hacemos descargas, elusión de DRM, ni reproducción de fondo no autorizada.
- Algunos enlaces HTTPS no son archivos de audio directos, pueden caducar,
  necesitar autenticación, bloquear clientes externos o no ser compatibles con el códec.
  En esos casos el motor de audio mostrará el error correspondiente.
- Los enlaces introducidos por el usuario no se guardan permanentemente.

## Instalar sobre la versión 3.3

1. Hacer una copia o commit de tu proyecto en Git.
2. Extraer el parche 3.4 sobre `~/Lyra-GitHub`.
3. **Eliminar los archivos obsoletos** (el ZIP no borra archivos al extraer):

```bash
cd ~/Lyra-GitHub
bash limpiar_jamendo_3_4.sh
```

4. Ejecutar:

```bash
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

No se necesita `--dart-define=LYRA_JAMENDO_CLIENT_ID`.

## Próximas fases

Definir otros proveedores que entreguen audio con autorización, disponer de
comprobaciones de disponibilidad, manejo de fallos, licencias por fuente y
reproducción sin conexión solo donde esté permitido. Nunca prometer que todas
las canciones del catálogo mundial se pueden reproducir sin restricciones.

## Sobre YouTube Music

Lyra puede abrir resultados en YouTube Music mediante el navegador oficial.
Las APIs oficiales de YouTube no autorizan extraer audio para un reproductor
independiente ni descargarlo para uso offline. Véase:
https://developers.google.com/youtube/terms/developer-policies-guide
