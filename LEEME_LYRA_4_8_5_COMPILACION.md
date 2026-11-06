# Lyra 4.8.5 — corrección de compilación del adaptador MPV

Esta corrección no modifica `yt-dlp`, BgUtils, MPV nativo ni la lógica de reproducción de Lyra. Solo recoloca un import que el instalador 4.8.4 puso erróneamente antes de la declaración `library` y evita analizar el ejemplo de un paquete externo.

## Instalación

Extraer el ZIP; copiar `lyra-music-main/.` sobre la raíz del proyecto; a continuación:

```sh
cd ~/Lyra-GitHub
python tools/reparar_compilacion_485.py --check
python tools/reparar_compilacion_485.py
dart format third_party/just_audio_media_kit/lib/mediakit_player.dart
flutter analyze
flutter test
flutter run -d linux
```

Se crean copias `.lyra485.bak` de los archivos alterados. El script es idempotente. No sustituir `pubspec.yaml` ni volver a aplicar el parche 4.8.4.

El problema de la caché `mkv: Failed to create file cache` puede persistir: este hotfix solo asegura que la configuración experimental ya aplicada se pueda compilar y probar. Si hay problemas de reproducción, ejecutar `python tools/configurar_cache_mpv_481.py --restore` y `flutter pub get`.
