# Lyra 4.1 — revisión de catálogo, biblioteca y estabilidad

Base: Lyra 4.0. Esta revisión no cambia el nombre interno de la aplicación ni elimina tus favoritos, listas o historial.

## Cambios implementados

- Artistas recomendados: cada candidato debe corresponder a un perfil con identificador de artista real; de lo contrario se omite para evitar mostrar títulos de canciones como nombres de artistas o repetir perfiles.
- YouTube Music: las miniaturas se leen también de contenedores anidados y se selecciona la mayor resolución devuelta por el servicio. Esto no puede mejorar una imagen de origen pequeña.
- Álbumes: si un elemento no incluye el artista o la carátula de la pista, se utiliza el artista y la portada del álbum desde el que se abrió. Se añadió una cabecera a la pantalla.
- Artista: intenta ampliar la lista de canciones cuando la API contiene el acceso al listado completo; botón «Ver todas» después de las primeras seis y filtros con presentación compacta.
- Biblioteca: «Mi colección» es la primera pestaña y se selecciona automáticamente, seguida de «Archivos locales».
- Estadísticas: gráficas de barras para tiempo de escucha por artista y canciones por número de reproducciones. Se calculan únicamente a partir de los datos locales existentes.
- Reproductor: eliminada la acción redundante de tres puntos. Descarga como botón independiente en escritorio.
- Descargas: se añadió guardado directo mediante Dart, sin `yt-dlp` ni herramientas externas, exclusivamente para flujos accesibles cuyo almacenamiento autorice el titular. No evita DRM, bloqueos o errores 403. El servicio puede seguir rechazando descargas; Android/iOS no están implementados.
- Buscar: al borrar el texto se invalidan las peticiones pendientes y se limpian los resultados antiguos.
- Cabeceras visuales: reutilizables en Biblioteca, Mi colección, Álbum, Estadísticas, Cuentas, Ajustes y Rendimiento. Inicio, Buscar, Artista y Extensiones ya tenían cabeceras propias.
- Mini reproductor: retirado `AnimatedSize` del contenedor que actualiza constantemente su contenido, como mitigación del error de layout de Flutter.

## Instalación

1. Confirma o respalda tu trabajo actual con Git.
2. Extrae el parche en la raíz del proyecto y sobrescribe los archivos que contiene.
3. Ejecuta:

```bash
cd ~/Lyra-GitHub
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

## Validación pendiente

No se pudo ejecutar el SDK de Flutter en el entorno de preparación. En CachyOS hay que comprobar especialmente: carga de artista/álbum, descarga autorizada, mini reproductor, resultados de búsqueda y barras de estadísticas.

## Mensajes de sistema que NO deben confundirse

- `dynamic_color: Accent color detected.` es informativo.
- Avisos sobre `bshell.desktop` y `hwloc-ls.desktop` se refieren a archivos de lanzadores del sistema con formato inválido, no a la reproducción de Lyra.
- `MPV: mkv: Failed to create file cache.` puede estar relacionado con la caché o el acceso al medio; comprobar espacio del disco, permisos de directorios temporales y si ocurre con audio local.
- `MPV: stream: Failed to open https://...googlevideo.com` indica fallo de acceso al flujo remoto. Una mejor portada o un nuevo menú no resuelven por sí solos rechazos del proveedor.
- Las URLs completas de `googlevideo.com` incluyen firmas de acceso temporales: no compartirlas públicamente.
