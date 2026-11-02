# Lyra 4.0 — Artistas, búsqueda y biblioteca unificada

Base: Lyra 3.9 Radio / Artistas / Biblioteca.

## Cambios del incremento

- El cambio de una pista a otra detiene primero el reproductor actual, antes de resolver el audio remoto. Un contador de generación evita que una carga antigua reemplace una selección nueva.
- Pantalla de artista renovada: identifica perfiles cuando hay channel ID, encabezado, seguimiento de artistas guardado localmente, buscador y orden alfabético, canciones destacadas y álbumes/sencillos cuando el catálogo los devuelve.
- Vista de un álbum con sus pistas disponibles y reproducción dentro de Lyra.
- Búsqueda: sugerencias de texto según el término escrito, resultados de artistas y acceso directo a sus perfiles. Debounce de 350 ms y descarte de respuestas antiguas.
- Inicio: sección “Artistas para ti” a partir de artistas escuchados o guardados (sin enviar el historial completo al proveedor).
- Biblioteca unificada: pestañas “Archivos locales” y “Mi colección” con favoritos, playlists, historial y artistas seguidos. Se elimina el acceso redundante “Mi música” de la barra lateral, pero se conserva la ruta antigua para compatibilidad.
- El menú de tres puntos del reproductor utiliza un menú contextual cerca del control, en lugar de una hoja inferior.
- Descarga experimental en Linux/Windows/macOS para contenidos propios o cuya descarga esté autorizada: requiere `yt-dlp` instalado y elegir la carpeta. Guarda un archivo en formato de audio original; no lo convierte automáticamente a MP3 ni modifica la colección existente.
- Se conserva la reproducción de escritorio y los controles multimedia existentes; no se cambia el extractor.

## Instalación

1. Guarda tus cambios con Git antes de actualizar:
   `git status`, `git add .`, `git commit -m 'backup: antes de Lyra 4.0'`.
2. Extrae el **parche** desde la raíz de tu proyecto `~/Lyra-GitHub`, respetando la estructura de carpetas `lib/` y `test/`.
3. Ejecuta:

```bash
cd ~/Lyra-GitHub
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

El paquete completo se extrae en una carpeta separada y NO debe sobrescribir automáticamente tu historial Git.

## Pruebas manuales recomendadas

1. Inicia una canción y selecciona otra mientras la primera suena: la anterior debe detenerse inmediatamente. El tiempo para iniciar la nueva puede depender de la red.
2. Abre un artista desde Buscar o Reproduciendo ahora, entra en un álbum y reproduce una de sus canciones.
3. Sigue un artista, cierra y vuelve a abrir Lyra y confirma que aparece en Biblioteca > Mi colección > Artistas favoritos.
4. Introduce 3 letras en Buscar y revisa las sugerencias; los resultados pueden tardar y dependen del proveedor.
5. Comprueba playlist, favoritos, estadísticas, mini reproductor, MPRIS y el diseño en ventana estrecha.
6. Opcional: instala `yt-dlp` (`sudo pacman -S yt-dlp`) y prueba la descarga de material propio o autorizado, eligiendo una carpeta ya añadida a Biblioteca.

## Limitaciones conocidas

- Este paquete NO se ha compilado ni ejecutado en CachyOS: debe validarse con los comandos anteriores. Se han verificado sintaxis estructural y composición del ZIP, no un build Flutter.
- YouTube Music es una integración experimental de interfaces privadas: la búsqueda de álbumes y artistas puede devolver resultados parciales, faltar imágenes, sugerencias o URLs, o cambiar sin aviso.
- La lista “Destacadas” conserva el orden recibido; no se atribuyen reproducciones o rankings inventados.
- Se añadieron artistas favoritos guardados en el dispositivo, no sincronización de suscripciones con una cuenta de Google.
- La descarga experimental existe únicamente en escritorio y requiere que el usuario tenga autorización para guardar el contenido. Puede fallar según el proveedor, los derechos o la herramienta externa. Android/iOS y un gestor de descargas persistente están pendientes.
- La descarga no debe confundirse con añadir a favoritos o guardar referencias en una playlist: después de descargar, añade la carpeta a Biblioteca para que el archivo aparezca allí.
