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
flutter analyze
flutter test
```

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
