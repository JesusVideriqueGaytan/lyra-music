# Lyra 4.3.2 — configuración de proveedores de audio

## Qué modifica
- `lib/features/ytmusic/data/ytmusic_audio_resolver.dart`: respeta la configuración local de yt-dlp.
- `tools/diagnosticar_audio.py`: respeta la configuración local y presenta motivos de error sin compartir stderr/URLs.

## Instalación
Extrae sobre la raíz de `~/Lyra-GitHub`. No borres tu base de datos ni cambies la biblioteca. Después:

    cd ~/Lyra-GitHub
    flutter analyze
    flutter test
    python tools/diagnosticar_audio.py dQw4w9WgXcQ --client mweb
    flutter run -d linux

## IMPORTANTE
Este parche NO instala un proveedor PO Token, NO garantiza HTTP 200/206 y NO desbloquea contenido protegido. Para acceder a flujos que requieren tokens, sigue la documentación del proveedor de yt-dlp y revisa el código externo antes de instalarlo.

https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide
https://github.com/Brainicism/bgutil-ytdlp-pot-provider
