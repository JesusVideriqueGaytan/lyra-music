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
