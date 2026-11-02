# Lyra 3.8.1 — corrección puntual de MusicBrainz

Este parche sustituye **únicamente** `test/musicbrainz_model_test.dart` con la versión sintácticamente correcta procedente del proyecto completo Lyra 3.8.

## Instalación

1. Guarda una copia del archivo original:
   `cp test/musicbrainz_model_test.dart test/musicbrainz_model_test.dart.bak`
2. Extrae este ZIP en la raíz de `~/Lyra-GitHub`, sobrescribiendo `test/musicbrainz_model_test.dart`.
3. Ejecuta desde la raíz del proyecto:

```bash
dart format test/musicbrainz_model_test.dart
dart fix --apply --code=curly_braces_in_flow_control_structures
flutter analyze
flutter test
```

La línea 30 es el cierre legítimo de `main()` y los dos tests. El error local indicaba una discrepancia en los cierres anteriores, no necesariamente que hubiera que eliminar esa última línea.

**Validación**: el ZIP y el archivo Dart son legibles; no se ha ejecutado Flutter/Dart en el contenedor, por lo que queda pendiente comprobar la compilación y las pruebas en CachyOS.
