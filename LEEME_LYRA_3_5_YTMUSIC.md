# Lyra 3.5 — YouTube Music experimental

Esta versión conserva la música local y MPRIS. Introduce un proveedor de YouTube Music **no oficial** separado del reproductor, de modo que pueda actualizarse si cambia la interfaz interna de YouTube.

## Funciones de esta revisión

- Explorar: YouTube Music por defecto, buscando canciones sin cuenta mediante la interfaz interna WEB_REMIX / InnerTube.
- Resolución de flujos de audio bajo demanda mediante `youtube_explode_dart` 3.1.0. Se pasan al mismo motor `just_audio` que utiliza la música local. No hay descarga de archivos en esta revisión.
- Cuentas y servicios: consulta experimental de playlists de una sesión personal de YouTube Music, solo lectura. No hay que contratar Spotify Premium.
- MusicBrainz queda disponible como catálogo de metadatos.

## Instalación

Copia el parche sobre una copia de tu proyecto Lyra 3.4, o usa el proyecto completo. En CachyOS:

```bash
cd ~/Lyra-GitHub
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

Para algunas versiones de `youtube_explode_dart`, resolver desafíos de firmas puede requerir `deno` en escritorio. Instálalo solo si aparece un error que lo solicite.

## Vincular una cuenta de YouTube Music — escritorio

Esta opción es experimental y emplea la sesión que ya has autorizado en tu navegador. No se le debe proporcionar a nadie una copia de estas cabeceras.

1. Abre <https://music.youtube.com> en tu navegador e inicia sesión normalmente.
2. Abre las herramientas de desarrollador (F12), pestaña **Red / Network**.
3. Selecciona **Biblioteca** para generar una solicitud `POST /youtubei/v1/browse` al dominio `music.youtube.com`.
4. Haz clic derecho sobre esa solicitud y elige **Copy request headers / Copiar cabeceras de la solicitud** (no el cuerpo ni la respuesta).
5. Sin compartirlas ni pegarlas en sitios externos, vuelve a Lyra > **Cuentas y servicios** > **Conectar desde portapapeles**.
6. Lyra usa las cookies localmente durante la sesión y borra el contenido del portapapeles tras leerlo. Al cerrar la aplicación o pulsar Desconectar, se descarta la sesión en memoria.

Si el navegador no permite copiar las cabeceras en ese formato, se puede estudiar posteriormente una alternativa de importación local compatible con su versión.

**Seguridad:** las cabeceras copiadas son tan delicadas como una sesión iniciada. No las pegues en el chat, en GitHub o en capturas. Nunca recolectamos tu contraseña. La aplicación no usa ni necesita un servidor propio para autenticar esta sesión.

## Limitaciones conocidas

- YouTube puede cambiar las estructuras JSON, las versiones de cliente, los tokens y las condiciones de acceso en cualquier momento.
- Las listas de reproducción privadas, canciones con limitaciones regionales, restricciones por edad o DRM pueden no funcionar.
- Los flujos son URLs efímeras. Esta revisión resuelve cada canción al seleccionarla, no carga todavía una cola extensa de flujos con renovación automática.
- El inicio de sesión desde navegador y la exportación de cabeceras aún no es un OAuth nativo con botón único ni debe presentarse como tal.
- No se integra subida, edición de playlists, favoritos remotos ni descarga. Esas acciones requieren fases propias y verificaciones adicionales.
- Este método no está avalado por Google y puede incumplir sus términos de uso. La distribución pública debe evaluarse por separado.

## Verificación

Este entorno no tiene Flutter ni acceso a una sesión real de YouTube Music. La entrega es código de desarrollo; ejecutar `flutter analyze`, `flutter test` y pruebas de reproducción en tu CachyOS es necesario antes de fusionar en `main`.
