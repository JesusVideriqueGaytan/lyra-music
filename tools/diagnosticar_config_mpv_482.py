#!/usr/bin/env python3
"""Diagnóstico SOLO LECTURA de la configuración libmpv de Lyra 4.8.1/4.8.2.

Comprueba la resolución real de just_audio_media_kit sin abrir ni
modificar el reproductor, los archivos de música o el sistema.
"""
from __future__ import annotations

import json
from pathlib import Path
import sys
from urllib.parse import urlparse, unquote

ROOT = Path(__file__).resolve().parents[1]
MARKER = "setProperty(_player, 'cache-on-disk', 'no')"
VENDOR = Path('third_party/just_audio_media_kit')


def resolved_package(project: Path) -> Path | None:
    config = project / '.dart_tool/package_config.json'
    if not config.is_file():
        return None
    packages = json.loads(config.read_text(encoding='utf-8')).get('packages', [])
    item = next((p for p in packages if p.get('name') == 'just_audio_media_kit'), None)
    if item is None:
        return None
    uri = item.get('rootUri', '')
    parsed = urlparse(uri)
    if parsed.scheme == 'file':
        return Path(unquote(parsed.path)).resolve()
    if not parsed.scheme:
        return (config.parent / unquote(uri)).resolve()
    return None


def diagnosis(project: Path) -> tuple[bool, list[str]]:
    lines = ['Lyra: verificación del adaptador MPV (solo lectura).']
    pubspec = project / 'pubspec.yaml'
    if not pubspec.is_file():
        return False, lines + ['No existe pubspec.yaml.']
    content = pubspec.read_text(encoding='utf-8')
    override = 'path: third_party/just_audio_media_kit' in content
    lines.append('Override local en pubspec.yaml: ' + ('SÍ' if override else 'NO'))
    package = resolved_package(project)
    if package is None:
        return False, lines + [
            'Sin ruta resuelta: ejecuta flutter pub get y repite la prueba.'
        ]
    vendor = (project / VENDOR).resolve()
    matches = package == vendor
    lines.append('Paquete usado por Flutter: ' + str(package))
    lines.append('Es la copia local: ' + ('SÍ' if matches else 'NO'))
    source = package / 'lib/src/mediakit_player.dart'
    if not source.is_file():
        return False, lines + ['No existe el archivo mediakit_player.dart.']
    patched = MARKER in source.read_text(encoding='utf-8')
    lines.append('Propiedad cache-on-disk=no en el código usado: ' +
                 ('SÍ' if patched else 'NO'))
    ready = 'Future<void> ready() async' in source.read_text(encoding='utf-8')
    lines.append('Método ready() modificado por Lyra 4.8.1: ' +
                 ('SÍ' if ready else 'NO'))
    active = override and matches and patched and ready
    if active:
        lines.append('RESULTADO: el parche está resuelto en el código de Flutter.')
        lines.append('Si MPV sigue registrando el aviso, no está demostrado que')
        lines.append('la propiedad esté siendo aceptada por libmpv en ejecución.')
        lines.append('Conviene revisar la inicialización nativa, no los permisos de ~/cache.')
    else:
        lines.append('RESULTADO: el parche 4.8.1 NO está completamente activo.')
        lines.append('Consulta LEEME_LYRA_4_8_1_CACHE_MPV.md antes de reintentar.')
    return active, lines


def main() -> int:
    try:
        active, lines = diagnosis(ROOT)
        print('\n'.join(lines))
        # No es error fatal si no está aplicado: herramienta informativa.
        return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(f'No pudo completarse la verificación: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
