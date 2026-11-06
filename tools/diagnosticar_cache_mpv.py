#!/usr/bin/env python3
"""Diagnóstico seguro de caché de libmpv en Lyra (Linux/CachyOS).

No descarga canciones, no modifica la configuración de MPV y no imprime URLs.
El aviso 'mkv: Failed to create file cache' puede surgir incluso si el audio
funciona; esta prueba solo discrimina permisos, espacio y ruta de caché.
"""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import sys
import tempfile


def cache_location(env: dict[str, str]) -> Path | None:
    mpv_home = env.get('MPV_HOME', '').strip()
    if mpv_home.startswith('/'):
        return Path(mpv_home)
    xdg_cache = env.get('XDG_CACHE_HOME', '').strip()
    if xdg_cache.startswith('/'):
        return Path(xdg_cache) / 'mpv'
    home = env.get('HOME', '').strip()
    if home.startswith('/'):
        return Path(home) / '.cache' / 'mpv'
    return None


def check_writable(directory: Path) -> tuple[bool, str]:
    try:
        directory.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            prefix='lyra-mpv-test-', dir=directory, delete=True
        ) as test_file:
            test_file.write(b'cache-test')
            test_file.flush()
        return True, 'Se pudo crear y borrar un archivo temporal.'
    except OSError as exc:
        return False, f'No se pudo escribir: {type(exc).__name__} (errno {exc.errno}).'


def main() -> int:
    if sys.platform != 'linux':
        print('Este diagnóstico está dirigido a Linux. No se realizaron cambios.')
        return 0
    directory = cache_location(os.environ)
    if directory is None:
        print('No se pudo determinar la caché: faltan HOME/XDG_CACHE_HOME absolutos.')
        return 2
    print('Lyra: diagnóstico local de caché de MPV')
    print(f'Carpeta de caché: {directory}')
    writable, reason = check_writable(directory)
    print(('Escritura: OK — ' if writable else 'Escritura: FALLÓ — ') + reason)
    try:
        stat = shutil.disk_usage(directory)
        print(f'Espacio libre en esa unidad: {stat.free // (1024 * 1024)} MiB')
    except OSError:
        print('No se pudo consultar el espacio disponible.')
    print('Ejecutable mpv:', shutil.which('mpv') or 'no encontrado (no imprescindible para libmpv)')
    for filename in ('bshell.desktop', 'hwloc-ls.desktop'):
        file = Path('/usr/share/applications') / filename
        if file.is_file():
            try:
                first = file.read_text(encoding='utf-8', errors='replace').lstrip()
                if not first.startswith('['):
                    print(f'Aviso GTK independiente: {filename} no comienza por [grupo].')
            except OSError:
                pass
    if writable:
        print('Interpretación: esta carpeta permite escritura. Si el aviso '
              'mkv persiste, hay que revisar la configuración de la instancia '
              'libmpv (no las descargas de Lyra).')
    else:
        print('Interpretación: existe un problema local de permisos/ruta que '
              'debemos solucionar antes de modificar libmpv.')
    print('No se ha desactivado ninguna caché ni modificado el motor de audio.')
    return 0 if writable else 1


if __name__ == '__main__':
    raise SystemExit(main())
