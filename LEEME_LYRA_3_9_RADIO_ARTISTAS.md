# Lyra 3.9 — Cola lateral, radio automática y artistas

Esta revisión parte de **Lyra 3.8.3**, conservando su motor de audio, biblioteca y configuraciones.

## Cambios

- **Cola**: panel lateral derecho animado en escritorio; bottom sheet en móvil. Portadas, selección de pista, mover y quitar elementos.
- **Radio automática**: cuando se elige una sola canción de YouTube Music, Lyra consulta la lista relacionada del proveedor y añade hasta 20 canciones diferentes, sin reemplazar playlists elegidas explícitamente. Si falla el servicio, la canción sigue sonando y la cola queda sin recomendaciones.
- **Perfil de artista**: pulsar el nombre del artista en el reproductor abre su página y permite escuchar las canciones encontradas. Se usa el identificador de artista cuando viene en los resultados y se intenta abrir su sección ampliada de canciones. **No prometemos una lista exhaustiva ni un orden verificado por número de reproducciones** cuando el proveedor no facilita esos datos.
- **Me gusta**: contraído inicialmente y con lista desplazable propia de máximo 360 puntos cuando se expande, para no empujar las playlists al final de una página interminable.
- Se guarda el campo opcional `artistId` en los metadatos de una pista; los datos antiguos siguen siendo compatibles.

## Instalar

1. Confirma qué cambios tienes: `git status`.
2. Si guardas tu versión en Git, registra un punto de recuperación antes de aplicar el parche.
3. Extrae el contenido del parche ZIP directamente sobre la raíz de `~/Lyra-GitHub`, manteniendo la jerarquía `lib/`, `test/`.
4. Desde el proyecto ejecuta:

```sh
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

## Pruebas manuales

1. Busca una canción en Lyra y tócala. Abre la cola; si el servicio entregó recomendaciones, deberán aparecer debajo y el encabezado mostrará «Radio automática».
2. Comprueba que el panel aparezca desde **la derecha** en escritorio y desde abajo en móvil.
3. Reproduce una playlist creada por ti: no debe reemplazarse con radio automática.
4. Pulsa el nombre del artista desde la pantalla «Reproduciendo ahora» y usa «Reproducir todas las disponibles».
5. Abre «Mi música»: «Me gusta» debe permanecer contraído al principio; al abrirlo, los favoritos se desplazan sin desplazar infinitamente las listas.

## Limitaciones y seguridad

- YouTube Music se consulta por una interfaz no oficial; las respuestas pueden cambiar o estar bloqueadas.
- La radio es una recomendación provista por YouTube Music; **no se afirma que los resultados pertenezcan todos al mismo género**.
- Una página de artista puede mostrar solo canciones destacadas o un listado parcial. No se inventan cifras de popularidad.
- El parche **no altera el resolver de audio que ya funciona en tu equipo**.
- Esta entrega solo fue validada mediante verificaciones estáticas de archivos aquí; no hay SDK de Flutter instalado en el entorno de empaquetado. La compilación y las pruebas de reproducción deben hacerse con los comandos anteriores en CachyOS.
