# Lyra 4.8.4 — reconocimiento de setProperty en just_audio_media_kit 2.1.0

## Qué corrige

Lyra 4.8.3 localiza correctamente `lib/mediakit_player.dart`, pero comprueba únicamente
`import 'set_property.dart';`. La versión 2.1.0 instalada en CachyOS usa
`import 'src/set_property.dart';`, de modo que el comprobador rechaza erróneamente
un adaptador compatible.

La versión 4.8.4 admite ambas variantes; NO cambia la reproducción, las fuentes
musicales, las canciones, el historial ni la configuración global de Flutter.

Al aplicar el parche se crea una copia local en `third_party/just_audio_media_kit`
y se añade un `dependency_overrides` reversible. El ajuste llama
`setProperty(_player, 'cache-on-disk', 'no')` en `ready()` después de que MPV
esté listo y antes de entregar el reproductor a just_audio.

**Este ajuste es experimental**. Un error `mkv: Failed to create file cache`
podría venir de otra caché interna de MKV, por lo que no se garantiza que desaparezca.

## Instalar (Fish/CachyOS)

1. Guarda tus cambios actuales en Git antes de copiar los archivos.
2. Extrae el ZIP y copia la carpeta `lyra-music-main/.` al directorio raíz de tu proyecto.
3. Dentro de `~/Lyra-GitHub` ejecuta:

```fish
python tools/configurar_cache_mpv_481.py --inspect
python -m unittest discover -s tools -p 'test_configurar_cache_mpv_483.py' -v
python tools/configurar_cache_mpv_481.py --apply
flutter pub get
python tools/diagnosticar_config_mpv_482.py
flutter analyze
flutter test
flutter run -d linux
```

El diagnóstico debe mostrar `Override local ... SÍ`, `Flutter usa la copia del
proyecto: SÍ` y `Ajuste cache-on-disk presente: SÍ`.

## Revertir

```fish
cd ~/Lyra-GitHub
python tools/configurar_cache_mpv_481.py --restore
flutter pub get
flutter run -d linux
```

El script evita escribir en `~/.pub-cache` y no altera el ejecutable MPV del sistema.

## Verificación

Se ejecutaron diez pruebas Python de la lógica del instalador y su reversión.
No se ejecutó `flutter analyze`, `flutter test` ni MPV en CachyOS, por lo que
la corrección necesita prueba real en la computadora del usuario.
