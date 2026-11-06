# Lyra 4.8.3 — Instalador de caché adaptativo

Este parche **no cambia el reproductor Lyra, la cola ni el resolvedor de audio**. Corrige el instalador 4.8.1, que tenía una ruta rígida `lib/src/mediakit_player.dart`. La dependencia resuelta en el equipo puede tener otra organización interna.

## Cómo aplicar desde CachyOS (Fish)

1. Conserva una copia de tu trabajo o haz un `git commit`.
2. Extrae este parche en la raíz del proyecto, conservando la estructura `tools/`.
3. Ejecuta los siguientes comandos:

```fish
cd ~/Lyra-GitHub
flutter pub get
python tools/configurar_cache_mpv_481.py --inspect
```

La inspección **no cambia nada**. Si detecta la implementación y la API `ready()` compatible, ejecuta:

```fish
python tools/configurar_cache_mpv_481.py --apply
flutter pub get
python tools/diagnosticar_config_mpv_482.py
flutter analyze
flutter test
flutter run -d linux
```

El instalador hace una copia local de `just_audio_media_kit`, introduce `cache-on-disk=no` en `ready()` (después de que `media_kit` inicialice el reproductor y antes del primer `load`) y agrega un `dependency_overrides` local. Si la API no coincide, **no altera el proyecto**. La copia original de `~/.pub-cache` no se modifica.

## Reversión

```fish
cd ~/Lyra-GitHub
python tools/configurar_cache_mpv_481.py --restore
flutter pub get
flutter run -d linux
```

El script conserva posibles cambios posteriores de `pubspec.yaml` y desactiva el override sin borrar la copia local. Si durante la prueba se altera la reproducción, vuelve a la versión anterior.

## Precisión importante

El mensaje `MPV: [error] mkv: Failed to create file cache` **no se considera resuelto** hasta comprobarlo en Linux. Puede proceder de mecanismos internos del demultiplexor MKV que no dependan directamente de `cache-on-disk`. El diagnóstico solo confirma cuál código está seleccionado, no el resultado de ejecutar la propiedad nativa. Las advertencias de OpenGL y los archivos `.desktop` son independientes.

## Pruebas

```fish
python -m unittest discover -s tools -p 'test_configurar_cache_mpv_483.py' -v
```

Las pruebas incluidas son simulaciones del instalador en directorios temporales; no sustituyen `flutter analyze` y `flutter test` en CachyOS.
