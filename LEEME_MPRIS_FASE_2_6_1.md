# Lyra — Fase 2.6.1 — Teclas multimedia Linux

## Cambios

- Registrado el `LyraAudioHandler` existente mediante `AudioService.init` **solo en Linux**, conectándolo al sistema MPRIS mediante `audio_service_mpris` estable.
- Sin segundo reproductor: las órdenes remotas usan el mismo `AudioPlayerController` que la interfaz.
- La notificación publica anterior, reproducir/pausar, siguiente, detener, metadatos y posición (cada ~2 s).
- Si el registro por D-Bus falla, Lyra debe seguir pudiendo reproducir música en su interfaz.
- Eliminada la dependencia de `just_audio_background` no utilizada, para evitar dos capas de servicio multimedia.
- Incluidos tests unitarios de los controles de sistema (el funcionamiento real de MPRIS requiere probar Linux).

## Instalación en CachyOS

1. Respaldar o confirmar los cambios propios del repositorio: `git status`.
2. Extraer los archivos del ZIP en una carpeta temporal y copiar los cambios al proyecto, respetando `lib/`, `test/` y `pubspec.yaml`. No borrar tu `.git`.
3. Ejecutar desde la raíz del repositorio:

```bash
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

`flutter pub get` debe resolver la nueva dependencia y actualizar `pubspec.lock`.

## Prueba con Lyra reproduciendo audio

En una terminal:

```bash
sudo pacman -S playerctl  # herramienta opcional de diagnóstico
playerctl --list-all
playerctl --player=Lyra metadata
playerctl --player=Lyra play-pause
playerctl --player=Lyra next
playerctl --player=Lyra previous
```

La denominación concreta de la sesión puede variar. Primero usa `playerctl --list-all` para identificarla; si aparece otro nombre, sustitúyelo en los comandos. También puedes usar `busctl --user list | grep -i mpris` sin instalar playerctl.

## Límites

- No es una prueba ejecutada en CachyOS/Niri; requiere verificar el registro DBus y la asociación de teclas del compositor.
- Esta revisión es exclusivamente para teclas multimedia Linux y no añade streaming.
- Se mantiene la dependencia nativa `libmpv` usada por `media_kit`.
- En Android se necesita completar la configuración nativa de audio_service en una fase específica; no se cambió su inicialización aquí.
