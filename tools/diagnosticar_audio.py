#!/usr/bin/env python3
"""Diagnóstico sin descarga ni filtración de URLs o cookies.

Compara los clientes yt-dlp predeterminado y mweb. Un HTTP 403 significa
rechazo del servidor, no una avería del sistema de sonido local. Para algunos
clientes puede ser necesario un proveedor externo de PO Token autorizado.
"""
import argparse
import json
import re
import subprocess
import sys
import time
from urllib import error, request, parse


ALLOWED_HEADERS = {
    'user-agent', 'referer', 'origin', 'accept', 'accept-language',
    'sec-fetch-mode', 'sec-fetch-dest', 'sec-fetch-site',
}



def probe_url(url: str, headers: dict[str, str], *,
              opener=None, sleeper=None) -> bool:
    """Lee 10 KiB y reintenta una vez tras 6s si googlevideo rechaza 403.

    No imprime ni almacena la URL firmada, las cabeceras ni los tokens.
    """
    opener = opener or request.urlopen
    sleeper = sleeper or time.sleep
    host = (parse.urlsplit(url).hostname or '').lower()
    googlevideo = host == 'googlevideo.com' or host.endswith('.googlevideo.com')
    for attempt in range(2):
        try:
            req = request.Request(url, headers=headers)
            with opener(req, timeout=15) as response:
                chunk = response.read(10240)
                print('Estado HTTP:', response.status)
                print('Primer fragmento:', 'recibido' if chunk else 'vacío')
                return response.status in (200, 206) and bool(chunk)
        except error.HTTPError as exc:
            print('Estado HTTP:', exc.code)
            if exc.code == 403 and googlevideo and attempt == 0:
                print('Enlace recién emitido: reintentando el MISMO flujo en 6 segundos...')
                sleeper(6)
                continue
            if exc.code == 403:
                print('El CDN sigue rechazando el acceso; el token o la sesión pueden no ser válidos.')
            return False
        except error.URLError:
            print('No hubo conexión con el servidor de medios.')
            return False
    return False


def inspect(video_id: str, client: str) -> bool:
    command = [
        'yt-dlp', '--no-playlist', '--no-warnings',
        '--skip-download', '--dump-single-json', '-f', 'bestaudio',
    ]
    if client != 'default':
        command += ['--extractor-args', f'youtube:player_client={client}']
    command.append('https://www.youtube.com/watch?v=' + video_id)
    print(f'\nCliente: {client} — extrayendo metadatos (sin descargar)...')
    try:
        result = subprocess.run(command, capture_output=True, text=True,
                                timeout=50, check=False)
    except subprocess.TimeoutExpired:
        print('Extracción agotó el tiempo de espera.')
        return False
    if result.returncode != 0:
        print('No se obtuvo una fuente. Código de proceso:', result.returncode)
        # No mostrar stderr original: algunos extractores revelan URLs,
        # cabeceras de sesión o parámetros firmados en diagnósticos.
        details = result.stderr.lower()
        if 'po token' in details or 'pot' in details or 'gvs' in details:
            print('Aviso del extractor: posible falta de PO Token para este cliente.')
        elif 'js runtime' in details or 'deno' in details or 'ejs' in details:
            print('Aviso del extractor: comprobar el motor JavaScript y yt-dlp-ejs.')
        elif 'sign in' in details or 'login' in details:
            print('Aviso del extractor: el contenido requiere autenticación.')
        elif 'no video formats' in details or 'requested format' in details:
            print('Aviso del extractor: no se encontraron formatos reproducibles.')
        else:
            print('No hay detalle público suficiente; se omite stderr por privacidad.')
        return False

    try:
        data = json.loads(result.stdout)
        url = data.get('url', '')
        if not isinstance(url, str) or not url.startswith('https://'):
            print('La respuesta no contiene una URL HTTPS de audio.')
            return False
        raw_headers = data.get('http_headers', {})
        headers = {'Range': 'bytes=0-10239'}
        if isinstance(raw_headers, dict):
            for key, value in raw_headers.items():
                if str(key).lower() in ALLOWED_HEADERS and isinstance(value, str):
                    if '\n' not in value and '\r' not in value:
                        headers[str(key)] = value
        return probe_url(url, headers)
    except (ValueError, TypeError):
        print('El extractor devolvió datos incompletos.')
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description='Prueba segura de acceso a audio, sin descargar.')
    parser.add_argument('video_id', help='ID público de YouTube (11 caracteres)')
    parser.add_argument('--client', choices=['default', 'mweb', 'all'], default='all',
                        help='Cliente que se probará; predeterminado: all')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]{11}', args.video_id):
        parser.error('El ID debe tener exactamente 11 caracteres alfanuméricos, _ o -.')
    try:
        version = subprocess.run(['yt-dlp', '--version'], capture_output=True,
                                 text=True, timeout=8, check=False)
    except FileNotFoundError:
        print('yt-dlp no está instalado o no está en PATH.')
        return 2
    except subprocess.TimeoutExpired:
        print('yt-dlp no responde a --version.')
        return 2
    print('yt-dlp:', version.stdout.strip() if version.returncode == 0 else 'versión no disponible')
    clients = ('default', 'mweb') if args.client == 'all' else (args.client,)
    outcomes = [inspect(args.video_id, c) for c in clients]
    if any(outcomes):
        print('\nAl menos una estrategia obtuvo bytes. Si MPV falla, revisar cabeceras y backend.')
        return 0
    print('\nNinguna estrategia proporcionó audio. Verifica la versión de yt-dlp y')
    print('las condiciones del proveedor (por ejemplo, requerimientos de PO Token).')
    print('Guía oficial: https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide')
    return 1


if __name__ == '__main__':
    sys.exit(main())
