# Lyra 4.5 — Cola por arrastre, radio continua y acciones directas

Esta revisión se aplica encima de Lyra 4.4 e incluye las correcciones de audio que ya formaban parte del proyecto completo 4.4. **No cambia** `lib/features/ytmusic/data/ytmusic_audio_resolver.dart`, el script de diagnóstico de HTTP 403 ni las integraciones de MPV, Deno y BgUtils.

## Cambios

1. Buscar: las filas de canción muestran su duración, favoritos, añadir a playlist, descarga autorizada (escritorio) y «Reproducir a continuación» como acción visible; en pantallas estrechas las acciones se colocan debajo para evitar desbordamientos.
2. Playlists: mismas acciones directas y menú adicional reservado a «Quitar de esta playlist»; reproducir una playlist explícita, incluso si tiene solo una canción online, **no** inicia radio automática.
3. Cola de reproducción: `ReorderableListView.builder` con asa de arrastre para mover una canción a cualquier posición y acción compacta para quitarla. Se eliminan los tres puntos de «Subir/Bajar». Arrastra el icono de líneas con el ratón; en móviles puedes arrastrar el asa.
4. Panel de cola: apertura y cierre animados mediante anchura progresiva (`AnimatedContainer` + recorte) cuando el hardware admite animaciones. La transición dura 300 ms. No se utiliza `AnimatedSize`.
5. Radio en línea: muestra **como máximo 30 pistas**: hasta diez del historial de reproducción reciente, incluyendo la actual, y hasta veinte futuras. Las canciones saltadas no se marcan como escuchadas. Las siguientes pistas se obtienen del catálogo al aproximarse al final, y un conjunto de IDs de sesión evita nuevas recomendaciones repetidas. Si el proveedor deja de devolver pistas únicas, la radio termina en lugar de inventar música o repetirla. El contador «en pantalla» no representa toda la duración histórica de la sesión.
6. Playlists explícitas del usuario: **mantienen todas sus pistas en la cola** y se reproducen en el orden elegido; no se aplica el límite de treinta canciones. Esto no implica que las referencias remotas se hayan descargado; el audio se resuelve al reproducirse.
7. Duración: extracción desde columnas flexibles, texto fijo y overlays cuando el catálogo la proporciona. Las playlists antiguas podrán actualizar duración desde los metadatos reales del reproductor al escuchar la pista. Si no hay duración verificable, se deja «—».

## Instalación

Realiza primero un commit o copia de seguridad, y extrae el archivo `Lyra_4_5_Cola_Radio_Parche.zip` sobre la raíz de `~/Lyra-GitHub`, conservando la estructura de carpetas.

```bash
cd ~/Lyra-GitHub
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

No actualices masivamente las dependencias solo para aplicar este parche.

## Pruebas sugeridas

- Buscar *Kenshi Yonezu*: verificar acciones directas y duraciones donde estén disponibles.
- Abrir una playlist de una canción online: reproducir y comprobar que la cola sigue teniendo solo esa canción, sin radio automática.
- Abrir una playlist de más de 30 canciones: debe mostrarlas todas.
- Iniciar una canción online **desde Buscar**: se inicia radio automática. A medida que avanzas, nunca más de 30 temas permanecen en pantalla, y los antiguos salen del panel.
- Arrastrar un tema situado al final de la cola hasta justo después del actual. El tema en reproducción no debe detenerse al arrastrar en una radio remota.
- Abrir/cerrar el panel en escritorio ancho: debe deslizarse desde la derecha.
- Si YouTube Music devuelve solo 5, 10 o 15 recomendaciones, Lyra mostrará esas: **no crea canciones falsas**.

## Verificación y limitaciones

- Verificada la integridad de ambos ZIP y sintaxis estructural (paréntesis, llaves y cadenas) de los nueve archivos Dart modificados.
- Las 4 pruebas Python simuladas del diagnóstico HTTP 403 pasan; el resolvedor de audio se mantiene byte a byte.
- Añadidas pruebas Flutter para la ventana de radio, desduplicación, salto de canciones y extracción de duración; **no se ejecutaron aquí** porque el SDK de Flutter/Dart no está instalado en el contenedor. La compilación y prueba de reproducción real deben confirmarse en CachyOS.
- El proveedor de YouTube Music es no oficial: la radio no puede garantizar infinitas canciones disponibles si el servicio deja de responder o repite contenidos.
- Las duraciones faltantes en las respuestas remotas no se inventan; pueden seguir apareciendo guiones en algunos resultados.
