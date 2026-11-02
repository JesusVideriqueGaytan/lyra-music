# Lyra 4.3 — correcciones puntuales de metadatos, navegación, cola y diagnóstico de audio

Este incremento parte de Lyra 4.2 y conserva el motor de reproducción.

## Modificaciones

- Un resultado cuyo campo de artista sea una duración (`2:54`) **no** se presenta como artista. Se intenta recuperar el nombre de `longBylineText`, `shortBylineText` o `subtitle`; si no existe se muestra «Artista desconocido».
- Las canciones que ya quedaron guardadas con una duración en `artist` muestran la etiqueta corregida en Inicio, mini reproductor, Now Playing y cola. El archivo de favoritos antiguo **no se modifica automáticamente**.
- El botón «Contraer» del reproductor navega siempre a `/home`.
- Escritorio ancho (contenido ≥1040 px): la cola queda acoplada a la derecha, abierta por defecto y con botón para ocultarla/mostrarla. En móvil y ventanas estrechas usa la hoja/panel habitual.
- Resolución experimental de audio: cuando existe yt-dlp, en escritorio se prueba primero su cliente Android y después el cliente habitual. El adaptador Dart sigue siendo un respaldo independiente. La comprobación HTTP ahora exige recibir bytes, no solo un código 200/206.
- Pruebas adicionales para errores de interpretación de artista y metadatos guardados.

## Lo que todavía requiere verificación

Las URLs de `googlevideo.com` pueden responder HTTP 403 aunque la búsqueda y las miniaturas funcionen. Esto está documentado también para `youtube_explode_dart` 3.1.0 y extractores alternativos. **No se garantiza que el audio de YouTube Music vuelva a funcionar con este parche.**

Para comprobarlo en CachyOS:

```bash
cd ~/Lyra-GitHub
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

Para comprobar un ID de 11 caracteres sin compartir una URL firmada, si ya tienes yt-dlp instalado:

```bash
python tools/diagnosticar_audio.py ID_DEL_VIDEO
```

No compartas con terceros URLs `googlevideo.com` completas, cookies ni tokens. Para diagnosticar el fallo importa el **código HTTP** y si la lectura del primer fragmento funciona, no el enlace firmado.

**Comprobaciones de entrega:** archivos comparados con Lyra 4.2 y ZIP revisados. Sin SDK Flutter en este entorno, por lo que compilación y reproducción siguen pendientes de prueba en el equipo real.
