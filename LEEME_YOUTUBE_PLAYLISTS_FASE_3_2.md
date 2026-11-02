# Lyra Fase 3.2 — Playlists de YouTube (Google OAuth Desktop)

Esta revisión solo conecta una cuenta de Google a través del navegador del
sistema (OAuth 2.0 + PKCE) para **leer listas de reproducción y sus primeros
50 elementos** mediante YouTube Data API v3. No reproduce ni descarga audio
de YouTube; los elementos abren YouTube en el navegador cuando se seleccionan.

## Configuración en Google Cloud

1. Accede a https://console.cloud.google.com/ y crea o selecciona proyecto.
2. En **APIs y servicios > Biblioteca**, habilita **YouTube Data API v3**.
3. En **Google Auth Platform**, configura pantalla de consentimiento;
   si está en estado Testing, incorpora tu cuenta como usuario de prueba.
4. En **Clientes / Credenciales**, crea OAuth client ID tipo
   **Aplicación de escritorio** (no aplicación web ni Android).
5. Copia solamente el **Client ID** (no incluyas el Client Secret en el
   código de una aplicación de escritorio).
6. Configura Spotify por separado si lo deseas, creando una aplicación en
   https://developer.spotify.com/dashboard con callback exacto
   `http://127.0.0.1:8765/callback`.

## Ejecutar en Linux

```bash
cd ~/Lyra-GitHub
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux \
  --dart-define=LYRA_SPOTIFY_CLIENT_ID=TU_SPOTIFY_CLIENT_ID \
  --dart-define=LYRA_GOOGLE_DESKTOP_CLIENT_ID=TU_GOOGLE_CLIENT_ID
```

Puedes omitir flags de proveedores que aún no configures.

En **Cuentas y servicios > YouTube · Playlists**, pulsa **Conectar YouTube**.
El navegador solicita permisos únicamente de lectura. Se listan hasta 100
playlists y hasta 50 elementos de la lista seleccionada.

## Consideraciones

- El acceso solo dura en memoria durante la sesión de Lyra y se descarta
  al desconectar o salir (la API puede caducar el token después de un tiempo).
- La integración **no equivale a iniciar sesión en music.youtube.com**;
  ciertas listas privadas y colecciones de YouTube Music no se publican a
  través de YouTube Data API y podrían faltar.
- No se usa Client Secret, no se almacenan contraseñas ni cookies, no se
  extrae audio ni se habilita reproducción/descargas de YouTube.
- Google OAuth instalado en Android o iOS requiere un flujo de autenticación
  nativo diferente; esta versión funciona solo en escritorio.
- Spotify requiere una app y Client ID independientes; en modo desarrollo
  está sujeto a límites de cuenta Premium y usuarios autorizados.
- Validar `flutter analyze`, pruebas y comportamiento real en tu Linux:
  aquí no se ejecutó el SDK de Flutter.
