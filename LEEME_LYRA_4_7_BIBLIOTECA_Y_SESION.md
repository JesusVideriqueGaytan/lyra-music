# Lyra 4.7 — Biblioteca, guardado masivo y sesión

Base: **Lyra 4.6 Descargas Internas**. Esta actualización no toca
`lib/features/ytmusic/data/ytmusic_audio_resolver.dart`, `tools/diagnosticar_audio.py`
ni la integración de Deno/BgUtils que permitió recuperar la reproducción.

## Cambios

1. Descargas: se retira el acceso fijo del sidebar y de la barra móvil. Un botón
   flotante **«Descargando · N»** aparece mientras existan descargas pendientes.
   Al tocarlo abre un panel cerrable. Desaparece automáticamente al finalizar.
   Se elimina el aviso de confirmación persistente de descargas encoladas.
   La ruta `/downloads` permanece internamente por compatibilidad, pero no aparece
   en la navegación principal. Las marcas de canciones descargadas permanecen.
2. Biblioteca: «Me gusta» es ahora una **playlist especial** colocada primero;
   comparte la misma fuente de datos con favoritos existentes y no puede
   renombrarse ni eliminarse. Después aparecen otras playlists, artistas seguidos
   e historial reciente. El historial se limita a 30 canciones diferentes,
   pero las estadísticas acumuladas no se borran.
3. Álbum y artista: nuevos botones para guardar el álbum entero o todas las
   canciones **disponibles en el catálogo del artista** en una playlist existente
   o una nueva. El agregado es por lotes y deduplica por ID. Una playlist usa
   la portada de la primera pista. La disponibilidad de la discografía depende
   del proveedor; no implica que se hayan obtenido todas sus grabaciones.
4. Playlists: el botón «Añadir a playlist» y la descarga individual se ocultan
   en sus filas. «Descargar todas» permanece en la cabecera, y las funciones
   de favorito, siguiente y quitar se mantienen según el tipo de lista.
5. Sesión de reproducción: guarda cola (máximo 500 pistas), índice, posición,
   aleatorio, repetición y estado de radio en SharedPreferences, sin almacenar
   URLs firmadas. Al iniciar restaura el estado **en pausa** y solo carga audio
   al primer Play. Guarda periódicamente; no ofrece una garantía de persistencia
   si el proceso se mata durante los primeros segundos tras un cambio.
6. Recomendaciones: si falta una duración, intenta consultarla por el **ID del
   mismo vídeo** usando `youtube_explode_dart`; si falla, muestra «—». No inventa
   metadatos ni modifica el resolvedor de streaming.

## Instalación (fish/CachyOS)

Primero guarda tus cambios locales (`git status`, commit o backup). El parche
contiene la carpeta `lyra-music-main`, que corresponde a la raíz del proyecto.

```fish
mkdir -p /tmp/lyra47_patch
unzip -o ~/Descargas/Lyra_4_7_Biblioteca_Sesion_Parche.zip -d /tmp/lyra47_patch
cp -a /tmp/lyra47_patch/lyra-music-main/. ~/Lyra-GitHub/
cd ~/Lyra-GitHub
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

Si el navegador guarda el ZIP en otra ubicación, ajusta la ruta.

## Pruebas funcionales recomendadas

- En Biblioteca: «Me gusta» como primera playlist, después listas, artistas e
  historial. Favoritos existentes siguen presentes. Playlist «Me gusta» no se
  puede borrar ni renombrar. La imagen de otra playlist es su primera canción.
- Desde un artista: guardar canciones disponibles en lista existente y crear
  nueva. Volver a pulsar no duplica. Desde un álbum: repetir el proceso.
- Descargar una playlist: comprobar que el botón flotante abre el panel, puede
  cerrarse y se oculta al acabar. La marca de canción descargada permanece.
- Reproducir, cambiar de canción, avanzar posición y cerrar/reabrir Lyra:
  última cola restaurada, posición cercana a la anterior, sin reproducir sola.
  Pulsar Play debe obtener el audio y permitir continuar. Validar además radio.
- Verificar que el streaming y las teclas multimedia siguen funcionando.

## Limitaciones

- No se ha compilado con Flutter en el entorno donde se generó el ZIP. Se
  revisaron las importaciones, estructuras Dart y pruebas Python de diagnóstico,
  pero es necesario ejecutar `flutter analyze` y `flutter test` en CachyOS.
- Restaurar una radio conserva la cola visible y su modo, pero no todos los IDs
  históricos que se habían descartado de la ventana. La continuidad depende de
  nuevas recomendaciones del proveedor.
- El aviso `MPV: mkv: Failed to create file cache` sigue sin resolverse; este
  parche no modifica la caché de MPV para proteger la reproducción actual.
- Descargas de escritorio solo para archivos permitidos y flujos accesibles.
  Continúan mientras Lyra esté abierta; no son tareas del sistema operativo.
