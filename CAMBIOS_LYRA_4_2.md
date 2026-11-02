# Lyra 4.2 — Correcciones de navegación y acciones

- Se eliminaron accesos de barra superior que duplicaban secciones de navegación: Inicio, Explorar, Biblioteca y Estadísticas.
- En Biblioteca, el banner precede a la selección «Mi colección / Archivos locales».
- Artista y álbum: acciones directas Me gusta, playlist, descarga (cuando esté disponible) y duración si existe en la respuesta del proveedor.
- El menú de tres puntos de las canciones se reserva para «Reproducir a continuación» y, en pantallas móviles, descarga autorizada cuando corresponda.
- `AudioPlayerController.playNext` incorpora la pista a continuación sin detener la actual. No cambia el motor de resolución de streaming.
- Búsqueda: menú de tres puntos exclusivamente para reproducir a continuación.

## Importante
La reproducción y las descargas pueden fallar por rechazos del proveedor, disponibilidad de fuentes o integración MPV. Este paquete **no acredita** que se hayan solucionado esas incidencias: es necesaria una prueba en la máquina donde falla. La descarga integrada desde `desktop_download.dart` sigue limitada a contenido autorizado y a flujos accesibles; no se implementa evasión de controles de acceso ni DRM.

## Pruebas
```bash
cd ~/Lyra-GitHub
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```
Las advertencias sobre «57 packages» no son fallos; no actualices todos los paquetes sin una migración planificada.
