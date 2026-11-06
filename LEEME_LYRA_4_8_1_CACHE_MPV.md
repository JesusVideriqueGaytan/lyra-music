# Lyra 4.8.1 — Caché MPV en memoria (prueba reversible)

Esta revisión es una **intervención localizada y reversible** sobre `just_audio_media_kit` **en Linux**. No cambia la extracción de YouTube Music, los PO Tokens, la biblioteca musical ni las descargas offline.

## Motivación

El diagnóstico anterior comprobó que `~/.cache/mpv` existe y permite crear archivos, y que el audio se reproduce. Sin embargo, MPV aún registra `mkv: Failed to create file cache`.

La documentación de mpv admite `cache-on-disk=no` para conservar la caché en memoria. El plugin `just_audio_media_kit` 2.1.0 no ofrece un parámetro público para ello; la propiedad debe aplicarse a su `Player` interno **después de la inicialización nativa pero antes de empezar a reproducir**.

## Aplicación desde Lyra 4.8

1. Guarda tus cambios con Git o realiza un respaldo.
2. Extrae este parche sobre la raíz del proyecto (incluye solo `tools/` y este LEEME).
3. En la terminal Fish, desde `~/Lyra-GitHub`:

```fish
flutter pub get
python tools/configurar_cache_mpv_481.py --apply
flutter pub get
flutter analyze
flutter test
flutter run -d linux
```

`--apply` copia la versión **ya resuelta** de `just_audio_media_kit` desde el caché de paquetes a `third_party/just_audio_media_kit`. Nunca edita `~/.pub-cache`. Modifica el método `ready()` únicamente si reconoce el código esperado y añade un `dependency_overrides` de ruta en `pubspec.yaml`, respaldando antes ese archivo como `.lyra481_pubspec_original`.

La copia local invoca `setProperty(_player, 'cache-on-disk', 'no')` **solo en Linux**, espera el resultado y luego termina su inicialización. Si la operación falla, emite un aviso y conserva el comportamiento anterior, sin bloquear la reproducción. En Windows y móvil no se aplica el ajuste.

## Comprobaciones

```fish
python -m unittest discover -s tools -p 'test_configurar_cache_mpv_481.py' -v
python tools/configurar_cache_mpv_481.py --status
```

Luego en la app comprueba tres canciones en línea, tres cambios de canción, adelantar/retroceder y una canción descargada. Comprueba que no se detenga el sonido y observa si desaparece `mkv: Failed to create file cache`.

## Reversión segura

```fish
python tools/configurar_cache_mpv_481.py --restore
flutter pub get
flutter run -d linux
```

El respaldo de `pubspec.yaml` se conserva hasta `--restore`, pero el restablecimiento solo retira el override y preserva otras modificaciones del archivo. `third_party/just_audio_media_kit` se conserva, sin utilizarse, para evitar borrar datos que el usuario pudiera editar. Tras comprobar la reversión, puede eliminarse manualmente si se desea.

## Limitaciones

- No se ha probado esta revisión en la máquina del usuario ni compilado con Flutter en este entorno.
- Desactivar el caché en disco **puede** eliminar el aviso. No se garantiza, porque la librería nativa y otros subsistemas pueden generar mensajes similares por razones diferentes.
- No se usa `cache=no`: el almacenamiento temporal en memoria y el buffer de red permanecen habilitados.
- No se modifica el aviso de OpenGL al redimensionar la ventana ni los archivos `.desktop` inválidos: son problemas distintos.
- Este parche está diseñado para la estructura de `just_audio_media_kit` 2.1.0; si cambia su API, el instalador se detiene sin modificar el proyecto.

## Fuentes

- https://mpv.io/manual/stable/#options-cache-on-disk
- https://pub.dev/packages/just_audio_media_kit/versions/2.1.0
- https://github.com/Pato05/just_audio_media_kit
