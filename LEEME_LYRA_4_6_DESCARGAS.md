# Lyra 4.6 — Descargas sin ventanas bloqueantes

## Cambios

- Nueva pantalla «Descargas» (`/downloads`) en la navegación de escritorio y móvil.
- La descarga de una playlist **se encola y regresa inmediatamente a la app**. Se pueden abrir otras pantallas, cancelar pendientes, reintentar fallidos y eliminar descargas terminadas desde la aplicación. Las descargas se procesan una a una para no saturar el proveedor.
- No se muestra el selector de carpeta. En escritorio se usa `path_provider.getApplicationSupportDirectory()/lyra-private-audio/<Artista>/<Título> [ID].ext`. La ubicación corresponde al almacenamiento privado de la aplicación; en Linux suele estar dentro de `~/.local/share/`. No es un cifrado: quien tiene acceso a los archivos del usuario podría inspeccionarla.
- El índice `index.json` persiste las descargas **completadas** para conservar su marca después de reiniciar. Una tarea en curso no se reanuda automáticamente al cerrar la aplicación.
- Un indicador de descarga aparece sobre las portadas de las pistas guardadas. Las pistas guardadas por Lyra se reproducen desde el archivo local antes de solicitar un enlace temporal de red.
- Los archivos parciales tienen la extensión `.lyra-part` y no se consideran completos; se eliminan al fallar/cancelar una tarea.
- No se modificó `ytmusic_audio_resolver.dart`, los scripts de tokens ni las preferencias de `just_audio_media_kit`.

## Limitaciones

- Las descargas directas están disponibles en escritorio (Linux/Windows/macOS). La pantalla existe en móvil, pero la función todavía no está habilitada allí.
- La cola continúa al navegar entre pantallas **mientras la aplicación permanezca abierta**. No es un servicio del sistema que siga ejecutándose después de cerrar Lyra.
- Las canciones previamente descargadas fuera de Lyra no se importan automáticamente al índice. No se mueven ni borran carpetas existentes.
- Solo se guardan fuentes permitidas que respondan correctamente al resolvedor y entreguen un archivo completo; no se eluden protecciones ni restricciones.
- No se habilitan descargas automáticas de canciones de terceros sin confirmación de permiso.

## Caché de MPV

`MPV: [error] mkv: Failed to create file cache` es un mensaje de la caché interna **temporal** del demuxer, no del gestor de descargas de Lyra. MPV ofrece la opción `cache-on-disk=no` para mantener la caché en RAM, pero `just_audio_media_kit 2.1.0` no la expone como ajuste público; manipular la instancia interna podría romper el streaming que ya funciona. Este parche **no afirma resolver el aviso**. Mantendremos el motor intacto hasta contar con una integración verificable para ese ajuste o confirmar el comportamiento del backend en CachyOS. `dynamic_color: Accent color detected` es informativo; las advertencias de archivos `.desktop` pertenecen al sistema y son independientes de MPV.

## Instalar y validar

1. Haz commit o copia de respaldo del proyecto actual.
2. Extrae el ZIP **Parche** sobre la raíz de `~/Lyra-GitHub`, respetando las rutas.
3. Ejecuta `flutter pub get`, `dart format lib test`, `flutter analyze`, `flutter test`, `flutter run -d linux`.
4. Descarga una canción permitida y abre Descargas: verifica que se encola, que puedes navegar sin detenerla y que aparece una insignia al finalizar.
5. Verifica que la canción finalizada se reproduce incluso sin conexión; la radio automática requiere conexión para buscar recomendaciones nuevas.

**Nota**: el SDK de Flutter no estaba disponible en el entorno de preparación, por lo que estos cambios requieren compilarse y probarse en tu CachyOS.
