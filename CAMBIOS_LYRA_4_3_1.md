# Lyra 4.3.1 — diagnóstico de HTTP 403

## Hallazgo

El diagnóstico externo con `tools/diagnosticar_audio.py` devolvió `Estado HTTP: 403` para `dQw4w9WgXcQ`. El CDN rechaza bytes del audio incluso fuera de Flutter. No hay evidencia de que el motor de audio de Linux sea la causa principal.

`yt-dlp` documenta que algunos clientes de YouTube requieren PO Token para la entrega de los flujos de Google Video. Una URL firmada puede existir pero no ser reproducible. También puede haber otras restricciones o problemas de compatibilidad.

## Cambios

- En escritorio, probar primero la configuración predeterminada de `yt-dlp` en lugar de forzar `android`, que puede requerir validaciones adicionales.
- Como segunda opción, probar `mweb`; para muchos contenidos esto solo funciona si la persona ha instalado y configurado un proveedor de PO Tokens compatible, según su documentación. El parche no instala ninguno ni obtiene tokens por sí mismo.
- Conservar los dos mecanismos Dart de respaldo para reproducción local y otros casos; no tocar el motor MPV ni la cola de reproducción.
- Mensaje de fallo del reproductor más útil cuando detecta HTTP 403.
- Nuevo diagnóstico con `--client default`, `--client mweb`, o `--client all` (predeterminado), imprimiendo versión, código HTTP, y si entregó bytes. No muestra cookies, tokens, URLs firmadas, ni stderr de extractores.

## Cómo aplicar

Desde la raíz del proyecto Lyra 4.3, descomprime este parche conservando las carpetas y sobrescribe los archivos incluidos. Después:

```bash
cd ~/Lyra-GitHub
python tools/diagnosticar_audio.py dQw4w9WgXcQ
flutter analyze
flutter test
flutter run -d linux
```

Para actualizar la versión de `yt-dlp` instalada con `pacman`, utiliza `sudo pacman -Syu yt-dlp` (actualización del sistema y del paquete), y comprueba `yt-dlp --version`.

Si ambos clientes devuelven HTTP 403, la modificación no puede forzar al CDN a entregar el audio. Sigue la guía del proyecto yt-dlp en https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide, revisa sus condiciones de uso y evita compartir credenciales o URLs firmadas.

**Verificación local de este parche**: comprobación sintáctica del script Python y ZIP; **no** compilado con Flutter ni probado contra CDN. No se garantiza recuperar reproducción con YouTube.
