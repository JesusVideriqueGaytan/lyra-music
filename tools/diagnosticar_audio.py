#!/usr/bin/env python3
"""Diagnóstico local y sin descarga de un enlace de reproducción de YouTube.

No imprime URLs firmadas, cookies, tokens ni identificadores de red. Ejecuta
el extractor instalado y prueba solo los primeros bytes con HTTP Range.
No identifica problemas de autenticación específicos, ni garantiza que MPV
pueda reproducir la URL obtenida.
"""
import json
import re
import subprocess
import sys
from urllib import error, request


def main():
    if len(sys.argv) != 2:
        print('Uso: python tools/diagnosticar_audio.py ID_VIDEO_11_CARACTERES')
        return 2
    video_id = sys.argv[1]
    if not re.fullmatch(r'[A-Za-z0-9_-]{11}', video_id):
        print('Indica únicamente el identificador de video (11 caracteres).')
        return 2

    print('Probando extracción local con yt-dlp, sin descargar canción…')
    try:
        run = subprocess.run(
            [
                'yt-dlp', '--no-config', '--no-playlist', '--no-warnings',
                '--skip-download', '--dump-single-json', '-f', 'bestaudio',
                'https://www.youtube.com/watch?v=' + video_id,
            ],
            capture_output=True, text=True, timeout=45,
            check=False,
        )
    except FileNotFoundError:
        print('No se encontró yt-dlp. Instálalo con: sudo pacman -S yt-dlp')
        return 1
    except subprocess.TimeoutExpired:
        print('Timeout del extractor (45 segundos).')
        return 1

    if run.returncode != 0:
        print('El extractor no obtuvo una fuente. Código:', run.returncode)
        print('No se muestra el registro completo para evitar exponer enlaces firmados.')
        return 1
    try:
        data = json.loads(run.stdout)
        url = data.get('url', '')
        if not isinstance(url, str) or not url.startswith('https://'):
            print('La respuesta del extractor no incluyó una URL HTTPS válida.')
            return 1
        http_headers = data.get('http_headers', {})
        allowed = {'user-agent', 'referer', 'origin', 'accept', 'accept-language'}
        headers = {'Range': 'bytes=0-1023'}
        if isinstance(http_headers, dict):
            headers.update({str(k): str(v) for k, v in http_headers.items()
                            if k.lower() in allowed and isinstance(v, str)})
        req = request.Request(url, headers=headers)
        try:
            with request.urlopen(req, timeout=15) as response:
                print('Estado HTTP:', response.status)
                print('Tipo de contenido:', response.headers.get('Content-Type', 'desconocido'))
                response.read(1024)
                print('El CDN permitió leer el fragmento inicial.')
                print('Si Lyra aún falla, revisar cabeceras del backend MPV.')
        except error.HTTPError as exc:
            print('Estado HTTP:', exc.code)
            if exc.code == 403:
                print('El CDN rechazó el acceso al enlace; no es un error de sonido de Linux.')
            else:
                print('El servidor no entregó bytes de audio.')
            return 1
    except (ValueError, TypeError, KeyError):
        print('Respuesta del extractor incompleta.')
        return 1
    except error.URLError:
        print('No se pudo conectar al servidor de audio.')
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
