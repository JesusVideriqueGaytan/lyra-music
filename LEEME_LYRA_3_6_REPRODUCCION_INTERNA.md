# Lyra 3.6 · Reproducción integrada y búsqueda rediseñada

## Cambios

- Inicio original de Lyra con secciones de acceso a búsqueda, música local, listas y extensiones.
- Navegación de escritorio: Inicio, Buscar, Biblioteca, Reproductor y ajustes.
- Navegación móvil: Inicio, Buscar, Biblioteca, Ajustes; el mini reproductor abre Reproductor.
- Buscar ahora usa YouTube Music como la fuente principal experimental.
- Al tocar un resultado se intenta reproducir automáticamente en Lyra; **no se abre un sitio externo**.
- El menú redundante «Reproducir en Lyra / Abrir en YouTube Music» desaparece. Las opciones de canción son información y copiar enlace.
- MusicBrainz continúa en el código como fuente de metadatos, pero ya no se muestra como si fuese un servicio de reproducción.
- Se corrigió una espera del `Future` de `just_audio`: el estado cargando ya no se mantiene hasta que termina la canción.
- Encabezado visual, búsqueda protagonista, géneros con búsqueda real, historial de búsquedas en memoria, vista de resultados, miniaturas y estado de pista actual.

## Qué NO hace todavía

- No se garantiza que todas las canciones tengan un flujo de audio accesible.
- Las interfaces no oficiales de YouTube Music pueden cambiar y afectar búsqueda o reproducción.
- La cola online todavía reproduce una pista por selección. Queda pendiente crear una **cola remota con resolución diferida**, renovación de URLs, avance automático y saltos entre resultados.
- No hay descargas automáticas, historial persistente ni recomendaciones personalizadas.
- No se han añadido accesos a páginas externas como parte de la reproducción.

## Instalar el parche

1. Realiza una copia de tu proyecto o usa Git (`git status`).
2. Descomprime el parche sobre la raíz de `~/Lyra-GitHub` **sobrescribiendo** los archivos, conservando la estructura `lib/`, `test/`.
3. En CachyOS:

```bash
cd ~/Lyra-GitHub
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

## Validación manual

- Abre Inicio y pulsa Buscar música.
- Busca una canción en YouTube Music; toca una fila sin abrir navegador.
- Comprueba aparición del mini reproductor y su reproducción.
- Prueba buscar por un género desde Inicio.
- Usa menú de canción para ver detalles o copiar un enlace, sin navegación externa.
- Comprueba que Biblioteca y ajustes mantienen sus vistas y que el mini reproductor no cubre contenido.
- En Android prueba que la navegación inferior se acomoda a la pantalla.

La compilación Flutter y la prueba de reproducción real deben hacerse en el equipo de desarrollo. La integridad de este paquete no equivale a una prueba de ejecución.
