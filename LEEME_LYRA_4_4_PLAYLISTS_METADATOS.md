# Lyra 4.4 — Playlists, metadatos y cola

Esta entrega está basada en **Lyra 4.3 + hotfixes 4.3.1, 4.3.2 y 4.3.3**, no en una copia de un repositorio Git personal. Se ha mantenido **sin cambios** `lib/features/ytmusic/data/ytmusic_audio_resolver.dart`, que contiene la lógica de streaming que se recuperó con `mweb`, BgUtils y reintentos HTTP.

## Cambios

1. **Metadatos de artista**: el parser prioriza los `runs` enlazados a un identificador de artista del proveedor (`UC...` / `MPLA...`) sobre las etiquetas, duraciones, visualizaciones o títulos. Sigue sin prometer metadatos completos cuando el proveedor no los entrega.
2. **Búsqueda de artistas**: si la búsqueda general no incluye un perfil coincidente, se hace una consulta adicional con el filtro de artistas del catálogo. Se ordena por coincidencia y se dejan fuera de la sección de perfiles aquellos que no coincidan con la consulta; las canciones siguen mostrándose.
3. **Historial y colección**: al encontrar datos mejores para el mismo ID de vídeo, se actualizan favoritos, listas, historial y estadísticas sin alterar los conteos y tiempos. Inicio intenta reparar hasta cuatro canciones antiguas por sesión, exigiendo una coincidencia de ID exacta para no asignar autores incorrectos.
4. **Cola**: muestra la duración proporcionada por el catálogo, o la duración medida por el reproductor para la canción actual. Si es desconocida, muestra `—` en vez de un número inventado.
5. **Menús de biblioteca**: se elimina la hoja inferior de acciones antiguas, reemplazándola por un menú contextual anclado. Incluye favoritos, añadir a playlist, reproducir a continuación y (cuando procede) guardar audio autorizado.
6. **Listas independientes**: pulsar una playlist en Biblioteca abre `/playlist/:playlistId` con su encabezado, lista completa, reproducción, aleatorio, duración conocida, menú contextual y opción para quitar una pista de esa lista.
7. **Descarga por lotes (escritorio, experimental)**: autorización y directorio una sola vez, procesamiento secuencial, conteo de descargas/archivos existentes/errores, cancelación de pendientes, límite de tamaño por archivo, archivos temporales `.lyra-part` eliminados en fallo. No se almacenan URL temporales en la colección ni se usan archivos `part` incompletos como canciones.
8. **Pruebas nuevas**: `test/playlist_metadata_navigation_test.dart` contiene pruebas de serialización, reparación conservadora de metadatos, extracción de autor y ordenación de perfiles.

## Limitaciones y seguridad

- **No se verificó con Flutter SDK en este entorno**. Ejecutar `flutter analyze`, `flutter test` y `flutter run -d linux` en CachyOS antes de considerar estable la versión.
- El proveedor YouTube Music es una interfaz **no oficial**, por lo que los datos pueden faltar y las estructuras pueden cambiar. Lyra no deduce artistas solo por el nombre de la canción.
- Las **descargas por lotes** solo funcionan en Linux, Windows o macOS y solo para contenido cuyo almacenamiento esté autorizado y cuyo servidor entregue los bytes. No sortean DRM, geobloqueos, rechazos de acceso ni autorizaciones. En esta versión no incluyen pausa/reanudación ni descargas simultáneas; fallos individuales no detienen automáticamente los siguientes elementos.
- La ruta de resolución de audio existente puede usar `yt-dlp` si está instalado y configurado. Sigue existiendo la alternativa Dart; ninguna garantiza acceso universal. **No modificar la configuración de Deno, BgUtils o MPV por aplicar este parche**.
- La duración total de una playlist se indica como **minutos conocidos** si faltan duraciones individuales; no es necesariamente el total real.
- La reparación de historial es deliberadamente limitada (hasta 4 pistas por sesión). No cambia datos que no se puedan verificar con exactitud.

## Aplicación recomendada

1. En `~/Lyra-GitHub`, guardar cambios: `git status` y un commit, o copiar el proyecto como respaldo.
2. Extraer el ZIP de **parche** en la raíz de `~/Lyra-GitHub`, respetando las rutas y sobrescribiendo solo los archivos que incluye. La carpeta raíz del proyecto debe contener `pubspec.yaml`.
3. En una terminal Fish:

```fish
cd ~/Lyra-GitHub
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

4. Probar: buscar `Kenshi Yonezu` (perfil y pistas), Inicio (recomendaciones), Biblioteca (favoritos e historial, menú de tres puntos), abrir una playlist, reproducirla y, **solo con contenido permitido**, probar descarga de una playlist pequeña y su cancelación.
5. Si falla Flutter, compartir la **primera línea de error**, el archivo y la ubicación, sin URL firmadas de `googlevideo` ni secretos de sesión.

El ZIP **completo** trae todo el proyecto del punto de partida más esta actualización; no contiene los cambios que el usuario haya hecho localmente después de instalar Lyra 4.3.3. Para conservar modificaciones propias se recomienda usar el parche y revisar el diff.
