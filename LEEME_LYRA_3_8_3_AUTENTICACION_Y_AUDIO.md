# Lyra 3.8.3 — Autenticación visible y diagnóstico de audio

## Cambios

1. **Cuentas y servicios** tiene ahora dos bloques claramente diferenciados.
   - **Google (OAuth)**: consulta playlists del usuario mediante YouTube Data API v3, usando un cliente OAuth de tipo **Aplicación de escritorio**. Es de solo lectura; **no reproduce** audio ni accede a toda la biblioteca específica de YouTube Music.
   - **YouTube Music experimental**: permanece el método avanzado de sesión del navegador. No se solicita la contraseña ni se almacena la sesión en disco.
2. En **Linux/Windows/macOS**, el resolver de audio intenta primero `yt-dlp` si está instalado, verificando HTTP antes de entregar la URL firmada a MPV; después prueba los flujos de youtube_explode_dart. El procedimiento no garantiza solucionar HTTP 403.
3. `tools/diagnosticar_audio.py` permite diagnosticar un video sin mostrar URLs firmadas ni tokens y sin guardar el audio.
4. Se conserva el test corregido de MusicBrainz para que la base coincida con 3.8.2.

## Configurar Google OAuth (escritorio)

- Abre https://console.cloud.google.com/ y crea/selecciona un proyecto.
- Habilita **YouTube Data API v3**.
- Configura Google Auth Platform (consentimiento). Añade el correo propio como usuario de prueba si el proyecto está en modo **Testing**.
- Crea **OAuth Client ID** de tipo **Desktop / Aplicación de escritorio**.
- Copia **Client ID**. Nunca añadas Client Secret ni tokens al repositorio.
- Ejecuta:

```bash
flutter run -d linux --dart-define=LYRA_GOOGLE_DESKTOP_CLIENT_ID=TU_CLIENT_ID
```

En **Ajustes → Cuentas y servicios → Conectar cuenta de Google**, pulsa **Iniciar sesión con Google**. El navegador abrirá una ventana de autorización; el acceso concedido es únicamente a listas y metadatos disponibles mediante la API. No habilita YouTube Music playback.

## Diagnóstico del audio

Instala yt-dlp si no lo tienes: `sudo pacman -S yt-dlp`.

Para obtener el ID público de un video: copia el parámetro de 11 caracteres después de `v=` en la dirección de la canción. No compartas cookies, cabeceras de autenticación ni URLs `googlevideo.com`.

```bash
python tools/diagnosticar_audio.py ID_DEL_VIDEO
```

Interpretación:
- **403**: el servidor rechazó el flujo. No equivale a un problema de mpv, libmpv o volumen. Requiere un acceso que el proveedor permita; cambiar el reproductor no garantiza resolverlo.
- **200/206** y Lyra sigue fallando: investigar cabeceras enviadas por el backend de just_audio_media_kit a MPV o formatos del flujo.
- **yt-dlp falla**: actualizar o revisar el extractor y sus dependencias; puede deberse al proveedor.

## Probar

```bash
cd ~/Lyra-GitHub
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux --dart-define=LYRA_GOOGLE_DESKTOP_CLIENT_ID=TU_CLIENT_ID
```

Nota: esta revisión no fue compilada en este entorno. Requiere validación en Linux/Flutter real.
