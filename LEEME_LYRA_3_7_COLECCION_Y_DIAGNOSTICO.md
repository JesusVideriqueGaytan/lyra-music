# Lyra 3.7 – Colección personal, reproducción por referencia y diagnóstico

## Estado de esta revisión

Esta entrega **no implementa todas las funciones de OpenTune**, ni arregla de forma demostrada los bloqueos de audio que puede imponer YouTube. Se centra en funciones locales fiables y mejoras estructurales para integrar streaming.

### Implementado en el código

- Favoritos persistentes (archivos propios y referencias de YouTube Music).
- Creación, renombrado y eliminación de playlists locales; añadir, quitar y reproducir canciones.
- Historial de canciones iniciadas y estadísticas locales (reproducciones, tiempo escuchado, artistas y canciones más escuchados). Aproximaciones; no incluye sincronización entre dispositivos.
- Rutas **Mi música** y **Estadísticas**, y enlaces desde Inicio, Biblioteca, Reproductor y pantalla de cuentas.
- Colas con referencias `ytmusic:<id>`: se intenta renovar la dirección de audio cada vez que se selecciona una canción; no se guardan URLs firmadas efímeras en la colección.
- Acciones de favoritos y playlists desde la búsqueda; nueva etiqueta neutra en Reproduciendo ahora; eliminación de la mención promocional a Spotify Premium.
- Reintento manual del audio que falla. No es garantía de reproducción.
- Almacenamiento local `SharedPreferences` en JSON. **No cifrado**: no se almacenan credenciales de las cuentas en esta colección.

### Diagnóstico del error MPV

El log `MPV: stream: Failed to open https://...googlevideo...` significa que el audio de la URL recuperada no pudo abrirse; puede ser enlace caducado, bloqueo del proveedor, acceso restringido, cabeceras de petición, incompatibilidad o error de red. El mensaje `ytdl_hook: Subprocess failed: init` puede ser **secundario**: MPV trata de usar un extractor alternativo al fallar la apertura directa. Instalar yt-dlp por sí solo no arregla el fallo original.

Este paquete intenta renovar la URL al pulsar Reintentar y al abrir una pista guardada, pero no incluye pruebas de reproducción real contra YouTube, ni garantiza que ese proveedor autorice todas las canciones. El texto de diagnóstico evita mostrar URLs firmadas en el banner.

### Limitaciones reales

- La conexión a YouTube Music sigue siendo **experimental y avanzada**. Importar sesión del navegador no es inicio de sesión OAuth integrado. No se ha corregido ni validado aquí la sincronización de playlists de Google.
- Las playlists creadas en Lyra se almacenan localmente; **no se escriben en la cuenta de YouTube Music**.
- Estadísticas locales sin periodos semana/mes ni respaldos. No está implementada la copia de seguridad.
- Portadas: las miniaturas proporcionadas por el proveedor pueden tener baja resolución. No se enriquecen las carátulas todavía.
- Modo local, MPRIS y sistema adaptable conservados.
- **Sin pruebas Flutter ejecutadas en este entorno**: deben correrse en el equipo del desarrollador.

## Cómo aplicar

1. Copia de seguridad o `git commit` de los cambios actuales.
2. Extraer el parche **sobre Lyra 3.6** dentro de `~/Lyra-GitHub`, conservando rutas `lib/` y `test/`.
3. Ejecutar:

```bash
cd ~/Lyra-GitHub
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

4. Probar el flujo: buscar pista, marcar favorito en opciones, abrir Mi música, crear playlist, añadir canción, volver a reproducir, comprobar historial y estadísticas. Reiniciar la app y comprobar que la colección se conserva.
5. Ante error de reproducción, anotar **código HTTP si aparece** y mensajes sin incluir URLs `googlevideo`, cookies, tokens, ni cabeceras privadas.

## Inventario funcional de OpenTune y plan para Lyra

| Área | Características de referencia | Lyra 3.7 |
| --- | --- | --- |
| Base de reproducción | Búsqueda, reproducción en segundo plano, cola, anterior/siguiente, MPRIS/controles del sistema | Parcial; error de streaming pendiente |
| Biblioteca | Favoritos, playlists, historial, artistas, álbumes, descargas | Favoritos, playlists locales e historial; resto parcial |
| Estadísticas | Ranking por artista/canción, periodos, tiempo escuchado | Totales acumulados locales, sin periodos |
| Metadatos | Portadas, artistas, álbumes, recomendaciones, novedades | Búsqueda básica; imágenes variables |
| Cuenta | Sincronización de bibliotecas y listas | Experimental y sin flujo cómodo |
| Letras | Sincronizadas, animación, traducción/romanización | Pendiente |
| Sonido | Normalización, ecualizador, velocidad/tono, silencio inteligente | Pendiente/no verificado |
| Experiencia | Temporizador, AOD, gestos, temas, mini-player, widgets | Temas y mini-player parcial; resto pendiente |
| Integraciones | Android Auto, Discord, ListenBrainz/Last.fm | MPRIS en Linux; resto pendiente |
| Sin conexión | Descargas, gestión de caché | Archivos propios, sin descargas de fuentes no autorizadas |
| Plataforma | Android optimizado | Lyra busca Android + escritorio, requiere validación separada |

Referencias para estudio (no implica reutilizar el código de OpenTune):
- https://github.com/Arturo254/OpenTune/blob/master/README.en.md
- https://f-droid.org/en/packages/com.Arturo254.opentune/
- https://github.com/Arturo254/OpenTune/releases

## Próximos hitos

1. **Audio robusto**: trazas seguras del error HTTP, pruebas de formatos y fuentes, manejo de stream caducado/403/401, estado de carga y reintento; sin prometer acceso universal.
2. **Conexión de cuenta usable y segura**: decidir OAuth oficial de YouTube Data API vs integración experimental claramente identificada; pruebas reales; manejo seguro de token/sesión.
3. **Biblioteca enriquecida**: portadas de mayor resolución, álbum/artista, cola mixta, historial detallado, restauración.
4. **Funciones avanzadas**: letras, temporizador de reposo, controles de sonido, periodos de estadísticas, backups e integraciones.
5. **Compatibilidad**: tests manuales/reales en CachyOS/niri, Android, Windows y macOS, no solo `flutter analyze`.
