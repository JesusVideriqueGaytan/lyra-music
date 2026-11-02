# Lyra — corrección de errores reportados

Base: ZIP proporcionado en esta conversación. No contiene posibles cambios posteriores de tu equipo.

## Aplicación
1. Respalda tu carpeta Lyra.
2. Copia las carpetas lib y test de este paquete sobre las de tu proyecto.
3. Conserva tu pubspec.yaml, pubspec.lock y configuración local actuales.
4. Desde la raíz ejecuta, en orden:

```sh
flutter pub get
dart format lib test
flutter analyzecl
Ejecuta `flutter run -d linux` después de resolver cualquier error restante.

## Correcciones
- Imports internos canónicos y rutas reparadas.
- Provider de rendimiento importado desde su definición.
- ShellRoute para envolver las pantallas con MiniPlayer.
- ConstrainedBox, MaterialBanner y posición no nula del progreso.
- AudioSource.file usa tag con MediaItem; eliminado parámetro id inexistente.
- Resuelto conflicto RepeatMode y prefijo de importación.
- Umbral Ultra: 85 puntos (el ejemplo de 8 GiB obtiene 75 y queda en High).
- Batería menor de 20% sin cargar fuerza Low en clasificación automática; override manual conservado.
- Tests de widgets actualizados para la biblioteca y con reproductor simulado.
- Prueba adicional de límite de batería y override manual.

## Validación y límites
Comprobadas las rutas de imports internos y revisados los cambios contra el registro de errores.
Flutter y Dart no están instalados en el entorno de revisión: NO se ejecutaron analyze, test ni compilación.
Las pruebas con reproductor simulado no validan reproducción nativa, notificaciones ni backend de audio Linux.
El arranque del servicio de audio y el soporte de audio Linux requieren una revisión funcional posterior; este paquete corrige los errores reportados, no certifica esas funciones.
No se actualizaron dependencias. Se excluyen cachés y archivos del IDE del ZIP.

## Segunda corrección
ConstrainedBox recibe constraints: const BoxConstraints(maxWidth: 220). Eliminado import sin uso y ordenado child al final. El usuario confirmó 15 pruebas de lógica aprobadas antes de este cambio. Pruebas de widgets aún pendientes. Para esta revisión basta copiar lib/app/router.dart y lib/features/library/presentation/screens/library_screen.dart.

## Selector de carpetas de escritorio
Copia solo library_screen.dart y library_controller.dart en sus rutas originales dentro de lib/features/library/presentation/. Ejecuta flutter pub add file_selector en tu proyecto para resolver y registrar la dependencia. Cierra la aplicación y vuelve a ejecutar flutter run -d linux: un hot reload no registra el plugin nuevo. Se valida acceso antes de persistir la ruta; cancelar no añade ninguna carpeta; se informa cuando no hay audio compatible. Se comparte la inicialización para evitar recargas duplicadas durante la selección. El selector nativo se aplica a Linux, Windows y macOS; en móvil se conserva la entrada manual. En macOS hace falta configurar los entitlements de acceso a archivos seleccionados antes de distribuir. No se ha ejecutado Flutter aquí ni se ha probado el diálogo nativo. El rediseño visual es una propuesta, no está incluido.


## Revisión Lyra — escritorio y audio (1 noviembre 2026)

- Backend de `just_audio` para Linux y Windows: `just_audio_media_kit` y bibliotecas nativas; inicialización antes del primer AudioPlayer. Esto atiende el error `MissingPluginException ... com.ryanheise.just_audio.methods` (requiere una compilación completa).
- Identidad visible Lyra en Linux (GTK), Windows, macOS y Android. Se conserva deliberadamente `name: lyra_music` como identificador Dart para evitar romper todos los imports y referencias internas.
- GTK: título compacto, controles nativos para minimizar/maximizar/cerrar; la ubicación y visibilidad de botones pueden depender del compositor Wayland / configuración del usuario.
- Vista de escritorio: panel lateral persistente para Biblioteca, Reproductor y Rendimiento, selección de ruta activa y mini reproductor. Ajustes también incluye Volver.
- Biblioteca: mejoras visuales a las filas, búsqueda y estado vacío. Se conserva selección de carpetas mediante file_selector y escaneo recursivo.
- Principios preservados: código abierto GPLv3, privacidad, reproducción local, ligereza, arquitectura modular y efectos según capacidad del equipo.

### Instalación / comprobación (CachyOS)

Extrae el ZIP en una carpeta nueva para no mezclar código con archivos generados de una compilación anterior. Luego:

```bash
cd lyra-music-main
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

En Linux debe estar disponible el entorno de compilación Flutter desktop (CMake, Ninja, clang, pkg-config, GTK3 dev). Revisa primero que la carpeta elegida contenga `.mp3`, `.flac`, `.ogg`, `.wav` o `.m4a`. Evita hot reload para cambios de plugins nativos.

**Validación pendiente:** en este entorno no está instalado `flutter` ni `dart`, por lo que los cambios no están compilados ni ensayados en Linux. Si `flutter pub get` encuentra un conflicto de versiones, conserva el mensaje para ajustar las restricciones. El archivo `pubspec.lock` original queda incluido como base y se regenerará con `flutter pub get`.

## Hotfix 2.5.1 — fallos reportados tras primera compilación

- `linux/runner/my_application.cc`: se cambió `gtk_widget_get_screen(window)` por `gtk_window_get_screen(window)` porque `window` es `GtkWindow*`. Resuelve el error C++ «no matching function for call to gtk_widget_get_screen».
- `test/widget_test.dart`: la aserción ahora busca el título real `Tu música` mostrado por `LibraryScreen`, en lugar del título anterior `Biblioteca`; se mantiene la verificación de `MaterialApp` y del `AppBar` en el segundo test.
- `flutter analyze` ya pasó sin incidencias en el equipo del usuario antes del hotfix. Flutter y el SDK de compilación GTK no están disponibles en este entorno, por lo que queda pendiente ejecutar de nuevo pruebas y compilación en CachyOS.

En la raíz del proyecto actualizado:

```bash
flutter test
flutter run -d linux
```

Si el sistema de archivos aún tiene una compilación anterior, ejecuta `flutter clean && flutter pub get` antes de repetir.
