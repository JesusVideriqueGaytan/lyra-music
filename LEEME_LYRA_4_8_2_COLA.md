# Lyra 4.8.2 — Cola centrada en la canción actual

Esta revisión visual de Lyra 4.8 modifica la presentación de la cola, **no** su
orden real, el resolvedor de audio, las descargas ni los PO Tokens.

## Interfaz de la cola

- La canción activa es siempre la primera fila al abrir la cola.
- Debajo aparecen las canciones que todavía siguen en cola.
- Las canciones anteriores se mantienen al final, bajo el título
  «Escuchadas anteriormente», accesibles al desplazarse hacia abajo.
- El asa de arrastre de las próximas canciones está a la **izquierda** de la
  portada, no junto a los botones de la derecha.
- No se puede arrastrar la canción que suena ni las canciones anteriores;
  sí se pueden seleccionar para reproducirlas, y quitar elementos.
- Al cambiar de pista la lista vuelve al principio. No se recortan las
  playlists locales ni se altera la ventana de radio del controlador.

## Caché de MPV

El aviso `mkv: Failed to create file cache` **no se declara corregido**.
La prueba anterior demostró que la carpeta del sistema permite escritura.

Para verificar si el hotfix experimental 4.8.1 está realmente seleccionado
por Flutter:

```fish
cd ~/Lyra-GitHub
flutter pub get
python tools/diagnosticar_config_mpv_482.py
python tools/configurar_cache_mpv_481.py --status
```

Si el diagnóstico dice que **NO** está activo, consulta
`LEEME_LYRA_4_8_1_CACHE_MPV.md` y aplica sus instrucciones solo si
no las ejecutaste previamente. No es necesario reinstalar MPV ni cambiar
la carpeta de caché de tus canciones.

Si está activo y aún se muestra el error, debemos investigar por qué
la instancia nativa no adopta la propiedad (o si el mensaje proviene de
otro proceso de `libmpv`). No se modifican ahora los controles de caché
para conservar la reproducción actual.

La advertencia gráfica `Timed out waiting for OpenGL frame` es independiente.

## Instalar

Este parche se aplica **encima de Lyra 4.8 o 4.8.1**. Extrae el contenido de
`lyra-music-main/` sobre la raíz de `~/Lyra-GitHub`.

```fish
cd ~/Lyra-GitHub
flutter analyze
flutter test
flutter run -d linux
```

Para probar: inicia radio, avanza 10 canciones, abre la cola y verifica que
la actual esté arriba, que las anteriores aparezcan al desplazarte hasta
el final y que puedas mover las próximas desde la izquierda.

**Verificación de desarrollo**: pruebas Python del diagnóstico aprobadas,
ZIP comprobado. La compilación Dart y la prueba gráfica necesitan Flutter
en CachyOS.
