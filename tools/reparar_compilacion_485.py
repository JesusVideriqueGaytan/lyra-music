#!/usr/bin/env python3
"""Hotfix Lyra 4.8.5: corrige imports del adaptador y excluye código vendorizado del análisis.
No cambia el comportamiento de MPV ni las descargas, y no toca ~/.pub-cache.
Uso: python tools/reparar_compilacion_485.py [--check]
"""
from pathlib import Path
import argparse
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PLAYER = ROOT / 'third_party/just_audio_media_kit/lib/mediakit_player.dart'
OPTIONS = ROOT / 'analysis_options.yaml'
IMPORT = "import 'package:universal_platform/universal_platform.dart';"
LIBRARY = 'library just_audio_media_kit;'
MARKER = 'LYRA_483_CACHE_ON_DISK'
EXCLUSION = 'third_party/just_audio_media_kit/**'


def correct_player(text: str) -> tuple[str, bool]:
    if MARKER not in text:
        raise ValueError('No está el parche de caché esperado. No se modifica el adaptador.')
    lines = text.splitlines(keepends=True)
    libraries = [i for i, line in enumerate(lines) if line.strip() == LIBRARY]
    imports = [i for i, line in enumerate(lines) if line.strip() == IMPORT]
    if len(libraries) != 1 or len(imports) != 1:
        raise ValueError('Estructura del adaptador no reconocida. No se modifica nada.')
    library_index, import_index = libraries[0], imports[0]
    if import_index > library_index:
        return text, False
    moved = lines.pop(import_index)
    library_index = next(i for i, line in enumerate(lines) if line.strip() == LIBRARY)
    lines.insert(library_index + 1, moved)
    return ''.join(lines), True


def exclude_vendor(text: str) -> tuple[str, bool]:
    if EXCLUSION in text:
        return text, False
    lines = text.splitlines(keepends=True)
    # Evitamos sobrescribir otras opciones del usuario.
    sections = [i for i, line in enumerate(lines) if re.match(r'^analyzer:\s*(?:#.*)?$', line.rstrip('\r\n'))]
    if not sections:
        return text.rstrip('\n') + '\n\nanalyzer:\n  exclude:\n    - ' + EXCLUSION + '\n', True
    if len(sections) != 1:
        raise ValueError('Se encontraron múltiples secciones analyzer:; revisa analysis_options.yaml.')
    start = sections[0]
    end = next((i for i in range(start + 1, len(lines)) if lines[i].strip() and not lines[i][0].isspace() and not lines[i].lstrip().startswith('#')), len(lines))
    existing = [i for i in range(start + 1, end) if re.match(r'^  exclude:\s*(?:#.*)?$', lines[i].rstrip('\r\n'))]
    if not existing:
        lines.insert(start + 1, '  exclude:\n    - ' + EXCLUSION + '\n')
        return ''.join(lines), True
    if len(existing) != 1:
        raise ValueError('Múltiples secciones analyzer.exclude; no se modifica el archivo.')
    lines.insert(existing[0] + 1, '    - ' + EXCLUSION + '\n')
    return ''.join(lines), True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Solo comprobar, sin escribir archivos')
    args = parser.parse_args()
    if not PLAYER.exists() or not OPTIONS.exists():
        print('No encuentro el adaptador activo o analysis_options.yaml. Comprueba la ruta del proyecto.', file=sys.stderr)
        return 1
    source = PLAYER.read_text(encoding='utf-8')
    options = OPTIONS.read_text(encoding='utf-8')
    try:
        new_source, source_changed = correct_player(source)
        new_options, options_changed = exclude_vendor(options)
    except ValueError as exc:
        print(f'No se aplicó el parche: {exc}', file=sys.stderr)
        return 1
    print('Adaptador: ' + ('necesita reordenar la importación' if source_changed else 'orden de importaciones correcto'))
    print('Analizador: ' + ('se excluirá código de terceros' if options_changed else 'exclusión de terceros ya presente'))
    if args.check:
        print('Verificación terminada; no se cambiaron archivos.')
        return 0
    if source_changed:
        PLAYER.with_suffix('.dart.lyra485.bak').write_text(source, encoding='utf-8')
        PLAYER.write_text(new_source, encoding='utf-8')
    if options_changed:
        OPTIONS.with_suffix('.yaml.lyra485.bak').write_text(options, encoding='utf-8')
        OPTIONS.write_text(new_options, encoding='utf-8')
    print('Lyra 4.8.5: corrección aplicada. Ejecuta flutter analyze, flutter test y flutter run -d linux.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
