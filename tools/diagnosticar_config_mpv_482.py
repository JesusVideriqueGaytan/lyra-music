#!/usr/bin/env python3
"""Lyra: comprueba la resolución real del adaptador MPV (solo lectura)."""
from __future__ import annotations

from pathlib import Path
import json
import sys

from configurar_cache_mpv_481 import (
    find_installed_package, locate_player_source, MARKER, PROJECT, VENDOR_REL,
)


def diagnosis(project: Path) -> tuple[bool, list[str]]:
    lines = ['Lyra: diagnóstico MPV y adaptador (solo lectura).']
    spec = project / 'pubspec.yaml'
    if not spec.is_file():
        return False, lines + ['No existe pubspec.yaml.']
    active_spec = 'path: third_party/just_audio_media_kit' in spec.read_text(encoding='utf-8')
    lines.append('Override local en pubspec.yaml: ' + ('SÍ' if active_spec else 'NO'))
    try:
        pkg = find_installed_package(project)
        lines.append(f'Dependencia efectiva: {pkg}')
        relative = pkg.resolve() == (project / VENDOR_REL).resolve()
        lines.append('Flutter usa la copia del proyecto: ' + ('SÍ' if relative else 'NO'))
        src = locate_player_source(pkg)
        lines.append('Fuente del reproductor: ' + str(src.relative_to(pkg)))
        data = src.read_text(encoding='utf-8')
        patched = MARKER in data and "await setProperty(_player, 'cache-on-disk', 'no')" in data
        lines.append('Ajuste cache-on-disk presente: ' + ('SÍ' if patched else 'NO'))
        enabled = active_spec and relative and patched
    except (RuntimeError, OSError, json.JSONDecodeError, ValueError) as error:
        return False, lines + [f'No se pudo verificar la fuente: {error}']
    if enabled:
        lines.append('Código seleccionado: PATCH ACTIVO.')
        lines.append('Este análisis no prueba que libmpv acepte la propiedad en ejecución.')
    else:
        lines.append('Código seleccionado: PARCHE NO ACTIVO.')
    return enabled, lines


def main() -> int:
    _, lines = diagnosis(PROJECT)
    print('\n'.join(lines))
    return 0


if __name__ == '__main__':
    sys.exit(main())
