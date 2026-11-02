# Lyra 4.3.3 — Corrección experimental para enlaces de audio HTTP 403

## Contexto
La prueba `yt-dlp --test -f bestaudio` consiguió recibir 10 KiB con el cliente `mweb`, el proveedor BgUtils y Deno; el diagnóstico anterior de Lyra abría el enlace de `--dump-single-json` inmediatamente y recibía HTTP 403.

Hay informes de octubre de 2026 de enlaces de `googlevideo.com` que rechazan su primera petición durante los primeros ~4–6 segundos después de la extracción. Por ello se añadió un *reintento con la misma URL* tras 6 segundos **solo cuando la respuesta inicial es 403 y el dominio es googlevideo.com**.

## Archivos
- `lib/features/ytmusic/data/ytmusic_audio_resolver.dart`: reintento controlado de la misma URL firmada; consulta Range 10 KiB; transmite cabeceras adicionales del extractor. Se mantienen las alternativas anteriores y el motor de audio sin cambios.
- `tools/diagnosticar_audio.py`: realiza exactamente la misma prueba, sin imprimir URLs firmadas ni tokens.
- `tools/test_diagnosticar_audio.py`: 4 pruebas locales simuladas, sin acceso a Internet.

## Instalar
1. Guardar los cambios actuales con Git o una copia del proyecto.
2. Extraer este parche directamente en la raíz de `~/Lyra-GitHub`, sobreescribiendo archivos.
3. Ejecutar:

    cd ~/Lyra-GitHub
    python -m unittest discover -s tools -p 'test_diagnosticar_audio.py' -v
    python tools/diagnosticar_audio.py dQw4w9WgXcQ --client mweb
    dart format lib test
    flutter analyze
    flutter test
    flutter run -d linux

## Qué significa un resultado
- `HTTP 206`, primer fragmento recibido: ya podemos entregar la URL a MPV; probar en Lyra.
- Continúa `403`: puede haber una restricción de la fuente o del proveedor; no se ha demostrado que sea un fallo de MPV.
- El diagnóstico funciona, Lyra no: revisar el transporte de `AudioSource.uri` con sus cabeceras y el backend `just_audio_media_kit`.

La prueba `yt-dlp --test` transfiere **solo 10 KiB**, así que por sí sola no confirma la reproducción completa de la pista. Este parche es experimental; no se ha ejecutado `flutter analyze` ni `flutter test` en este entorno por falta de Flutter SDK. No evade controles de acceso ni garantiza disponibilidad de todas las canciones.

Referencias:
- https://github.com/nukeop/nuclear/discussions/2218
- https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide
