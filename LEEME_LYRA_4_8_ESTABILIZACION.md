# Lyra 4.8 — Estabilización inicial (versión de prueba)

Base: Lyra 4.7. Se conservan **sin modificar** `lib/features/ytmusic/data/ytmusic_audio_resolver.dart`, `tools/diagnosticar_audio.py`, el gestor de descargas y la configuración de Deno/BgUtils/PO Tokens.

## Cambios

1. **Nombres de artista**: validador único en `lib/core/metadata/artist_name.dart` para evitar tratar duración, año, categoría de vídeo o contador de reproducciones como nombre. No traduce ni altera nombres en japonés, coreano y otras escrituras. Se utiliza en el parser, la colección y `Track.displayArtist`. Enriquecimiento de registros guardados sigue exigiendo ID de vídeo idéntico.
2. **Fallos de reproducción**: si falla la carga, el controlador desactiva `buffering`/`playing`, muestra error legible y deja de mostrar un indicador de carga permanente. Las respuestas tardías de selecciones anteriores no deben sobrescribir el error de una pista posterior. El cambio de canción todavía detiene primero el audio anterior.
3. **Recuperación de sesión**: se ignoran pistas corruptas en la sesión guardada. Si la posición corresponde al final de una canción conocida, la siguiente apertura la recupera desde el inicio; la restauración sigue sin reproducir automáticamente.
4. **Caché MPV**: en Linux se prepara la carpeta estándar de caché si no existe. Incluimos `tools/diagnosticar_cache_mpv.py` para comprobar ruta, espacio y escritura. **No se ha desactivado ni alterado la caché interna de libmpv.** El aviso `mkv: Failed to create file cache` puede persistir: el adaptador `just_audio_media_kit` 2.1.0 no ofrece una opción pública `cache-on-disk=no`. Resolverlo a nivel de backend requiere pruebas de integración adicionales.
5. **Pruebas nuevas**: `test/artist_metadata_regression_test.dart` y `test/playback_stability_regression_test.dart`. Las pruebas Python cubren los diagnósticos de audio y caché.

## Aplicar el parche

Haz primero un commit/respaldo de tu proyecto. Si el ZIP está en `~/Descargas`:

```fish
mkdir -p /tmp/lyra48_patch
unzip -o ~/Descargas/Lyra_4_8_Estabilidad_Parche.zip -d /tmp/lyra48_patch
cp -a /tmp/lyra48_patch/lyra-music-main/. ~/Lyra-GitHub/
cd ~/Lyra-GitHub
flutter pub get
dart format lib test
flutter analyze
flutter test
python -m unittest discover -s tools -p 'test_*.py' -v
python tools/diagnosticar_cache_mpv.py
flutter run -d linux
```

## Pruebas manuales prioritarias

- Cambiar rápidamente entre dos pistas remotas; comprobar que no se superponen y que no aparece error antiguo de otra pista.
- Buscar canciones con columnas `2:54`, `20 M de visualizaciones` y nombres internacionales. No confundir cifras con artistas.
- Intentar una pista no disponible; comprobar que desaparece el spinner y aparece un error legible.
- Cerrar y reabrir sin sonido automático, con la cola y posición conservadas.
- Probar archivos locales y audio online; confirmar que la reproducción que ya funciona no se ha visto afectada.
- Ejecutar el diagnóstico de caché y comprobar si el aviso persiste. Si persiste con permisos correctos y audio funcional, conservar el registro para la investigación del backend; no atribuirlo a las descargas.

## Limitaciones de la entrega

No se ha ejecutado Flutter dentro del entorno de creación del parche (SDK no disponible). La validación real de compilación, interfaz y audio debe realizarse en CachyOS. No prometemos que el aviso de caché quede eliminado. Tampoco se cambian las dependencias ni se introducen mecanismos para sortear restricciones de proveedores.
