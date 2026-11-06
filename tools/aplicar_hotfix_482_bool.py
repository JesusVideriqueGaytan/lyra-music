#!/usr/bin/env python3
"""Lyra 4.8.2: corrige un bool? en el listener de visibilidad de cola.

Uso: desde la raíz de Lyra, python tools/aplicar_hotfix_482_bool.py
Solo modifica una línea. Conserva el resto de los cambios locales.
"""
from pathlib import Path
import sys

SOURCE = Path(__file__).resolve().parents[1] / 'lib/features/player/presentation/screens/now_playing_screen.dart'
OLD = 'if (next && !previous) _showCurrentFirst();'
NEW = 'if (next && previous != true) _showCurrentFirst();'

def main():
    if not SOURCE.exists():
        print(f'No se encontró el archivo: {SOURCE}', file=sys.stderr)
        return 1
    content = SOURCE.read_text(encoding='utf-8')
    if NEW in content and OLD not in content:
        print('Hotfix ya aplicado; no se modificó nada.')
        return 0
    if content.count(OLD) != 1:
        print('No se reconoció la línea esperada: no se modificó el archivo.', file=sys.stderr)
        return 1
    SOURCE.write_text(content.replace(OLD, NEW), encoding='utf-8')
    print('Corrección aplicada: bool? tratado explícitamente como valor anulable.')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
