# Lyra 3.8 — reproducción, descubrimiento y navegación

## Alcance real

- El reproductor ya no abre enlaces `googlevideo` sin comprobar primero si
  responden con HTTP 200/206. Si se detecta rechazo HTTP, intenta otra variante
  y, en Linux/macOS/Windows, opcionalmente el ejecutable externo `yt-dlp`.
- No se descarga audio ni se registran URLs firmadas o cookies en la biblioteca.
- Los encabezados HTTP que devuelve el extractor alternativo se propagan a
  `just_audio`. El controlador también escucha `errorStream` para mostrar errores
  de reproducción asíncronos.
- Controles de **Me gusta**, **Añadir a lista** y **Más opciones** debajo del
  título/artista en «Reproduciendo ahora».
- Entrada **Estadísticas** propia en el menú lateral de escritorio.
- Sección **Te puede gustar** en Inicio: calcula localmente el artista preferido
  usando favoritos, número de reproducciones y minutos escuchados. Solo consulta
  un término de búsqueda al proveedor; muestra canciones reales, sin inventarlas.
- Ajustes → Privacidad: interruptor para activar/desactivar las sugerencias.

## Límites importantes

YouTube a veces exige tokens adicionales y devuelve 403. Ni `yt-dlp` ni
`youtube_explode_dart` garantizan resolver todas las canciones. La verificación
HTTP también puede pasar y luego producirse un rechazo durante la reproducción;
por eso el controlador sigue escuchando errores del motor.

La integración con YouTube no es oficial y podría incumplir las condiciones de
su proveedor. No estamos intentando eludir DRM ni autenticación obligatoria.

La instalación de `yt-dlp` es **opcional** y solo se usa como respaldo para
escritorio. No forma parte del binario Flutter ni da soporte Android.

## Instalar sobre Lyra 3.7

1. Desde `~/Lyra-GitHub`: guarda tus cambios de Git antes de aplicar el parche.
2. Extrae el archivo ZIP del parche sobre la carpeta raíz, respetando las rutas.
3. Ejecuta:

```bash
cd ~/Lyra-GitHub
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

Para habilitar el respaldo opcional en CachyOS/Arch:

```bash
sudo pacman -S yt-dlp
yt-dlp --version
```

**No uses `--cookies-from-browser` ni copies cookies en el terminal** para la
reproducción. Se mantiene una conexión independiente de cuentas, no obligatoria.

## Validación recomendada

1. Reproducir un MP3 local y comprobar que continúa funcionando.
2. Buscar una canción online, tocarla y comprobar si suena o si Lyra explica un rechazo.
3. Probar anterior/siguiente y MPRIS (`playerctl`).
4. Comprobar «Me gusta / Añadir a lista / Más opciones» debajo del artista.
5. Abrir Estadísticas desde el menú lateral y verificar los registros locales.
6. Escuchar varias canciones que **sí** carguen, regresar a Inicio y comprobar
   que «Te puede gustar» ofrece resultados reales.
7. Desactivar las sugerencias en Ajustes; deben desaparecer de Inicio.

Esta revisión no se ha compilado aquí con Flutter; debe validarse en el equipo.
