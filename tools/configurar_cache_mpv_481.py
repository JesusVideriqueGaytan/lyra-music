#!/usr/bin/env python3
"""Lyra 4.8.1: parche reversible para cache-on-disk=no en libmpv de Linux.

No cambia archivos del caché global de pub; copia localmente la versión
resuelta de just_audio_media_kit y agrega un override de ruta al proyecto.
Usar: python tools/configurar_cache_mpv_481.py --apply|--restore|--status
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile
from urllib.parse import urlparse, unquote

PROJECT = Path(__file__).resolve().parents[1]
VENDOR_REL = Path('third_party/just_audio_media_kit')
BACKUP_REL = Path('.lyra481_pubspec_original')


def find_installed_package(project: Path) -> Path:
    config = project / '.dart_tool' / 'package_config.json'
    if not config.is_file():
        raise RuntimeError('Falta .dart_tool/package_config.json. Ejecuta flutter pub get primero.')
    packages = json.loads(config.read_text(encoding='utf-8')).get('packages', [])
    pkg = next((p for p in packages if p.get('name') == 'just_audio_media_kit'), None)
    if not pkg:
        raise RuntimeError('El proyecto no tiene just_audio_media_kit resuelto.')
    uri = pkg.get('rootUri', '')
    parsed = urlparse(uri)
    if parsed.scheme == 'file':
        root = Path(unquote(parsed.path)).resolve()
    elif not parsed.scheme:
        root = (config.parent / unquote(uri)).resolve()
    else:
        raise RuntimeError('Ruta de paquete no soportada: ' + parsed.scheme)
    if not (root / 'pubspec.yaml').is_file():
        raise RuntimeError('No se encontró pubspec.yaml en el paquete resuelto.')
    return root


def patch_source(original: str) -> str:
    marker = 'Future<void> ready() => _readyCompleter.future;'
    if original.count(marker) != 1:
        raise RuntimeError('El adaptador cambió su API ready(); se cancela para evitar errores.')
    imp = "import 'package:universal_platform/universal_platform.dart';"
    if imp not in original:
        original = imp + '\n' + original
    replacement = '''Future<void> ready() async {
    await _readyCompleter.future;
    // Lyra 4.8.1: configuración exclusiva de Linux y ANTES de abrir un flujo.
    // Conserva cache de red y en RAM; solo evita el archivo temporal en disco.
    if (UniversalPlatform.isLinux) {
      try {
        await setProperty(_player, 'cache-on-disk', 'no');
      } catch (error) {
        // Fallar en este ajuste NO debe impedir reproducir la canción.
        _logger.warning('Lyra: cache-on-disk=no no disponible', error);
      }
    }
  }'''
    return original.replace(marker, replacement)


def override_pubspec(original: str) -> str:
    path_line = '    path: third_party/just_audio_media_kit'
    if path_line in original:
        raise RuntimeError('Ya existe un override Lyra 4.8.1 en pubspec.yaml.')
    if re.search(r'^\s{2}just_audio_media_kit\s*:', original, flags=re.M) and 'dependency_overrides:' in original:
        # La dependencia normal es válida: solo rechazamos un override existente.
        section = original.split('dependency_overrides:', 1)[1]
        section = re.split(r'^\S', section, maxsplit=1, flags=re.M)[0]
        if re.search(r'^  just_audio_media_kit\s*:', section, flags=re.M):
            raise RuntimeError('Ya existe dependency_override para just_audio_media_kit.')
    if re.search(r'^dependency_overrides:\s*$', original, flags=re.M):
        return re.sub(
            r'^(dependency_overrides:\s*)$',
            '\\1\n  just_audio_media_kit:\n' + path_line,
            original,
            count=1,
            flags=re.M,
        )
    return original.rstrip() + '\n\ndependency_overrides:\n  just_audio_media_kit:\n' + path_line + '\n'


def status(project: Path) -> str:
    pubspec = project / 'pubspec.yaml'
    vendor = project / VENDOR_REL / 'lib/src/mediakit_player.dart'
    configured = pubspec.is_file() and 'path: third_party/just_audio_media_kit' in pubspec.read_text(encoding='utf-8')
    patched = vendor.is_file() and "setProperty(_player, 'cache-on-disk', 'no')" in vendor.read_text(encoding='utf-8')
    if configured and patched:
        return 'Lyra 4.8.1: configuración de caché activada en la copia local.'
    if configured or patched:
        return 'Estado parcial: revisa pubspec.yaml y third_party/just_audio_media_kit.'
    return 'Lyra 4.8.1: sin cambios de caché aplicados.'


def apply(project: Path) -> None:
    pubspec = project / 'pubspec.yaml'
    backup = project / BACKUP_REL
    vendor = project / VENDOR_REL
    if not pubspec.is_file():
        raise RuntimeError('No existe pubspec.yaml en el proyecto.')
    if backup.exists() or vendor.exists():
        if "configuración de caché activada" in status(project):
            print('Ya aplicado. No se modificó nada.')
            return
        raise RuntimeError('Hay un respaldo o proveedor local previo. No se sobrescribe.')
    root = find_installed_package(project)
    src = root / 'lib/src/mediakit_player.dart'
    if not src.is_file():
        raise RuntimeError('No existe mediakit_player.dart en la versión instalada.')
    new_source = patch_source(src.read_text(encoding='utf-8'))
    original_pubspec = pubspec.read_text(encoding='utf-8')
    patched_pubspec = override_pubspec(original_pubspec)
    (project / 'third_party').mkdir(exist_ok=True)
    # Validamos en directorio temporal: nunca modificamos ~/.pub-cache.
    with tempfile.TemporaryDirectory(prefix='lyra481-', dir=project / 'third_party') as tmp:
        staged = Path(tmp) / 'just_audio_media_kit'
        shutil.copytree(root, staged, ignore=shutil.ignore_patterns('.dart_tool', 'build', '.git'))
        (staged / 'lib/src/mediakit_player.dart').write_text(new_source, encoding='utf-8')
        backup.write_text(original_pubspec, encoding='utf-8')
        try:
            staged.rename(vendor)
            pubspec.write_text(patched_pubspec, encoding='utf-8')
        except Exception:
            pubspec.write_text(original_pubspec, encoding='utf-8')
            if vendor.exists():
                shutil.rmtree(vendor)
            backup.unlink(missing_ok=True)
            raise
    print(status(project))
    print('Ahora ejecuta: flutter pub get && flutter analyze && flutter test')
    print('Para revertir: python tools/configurar_cache_mpv_481.py --restore')


def restore(project: Path) -> None:
    backup = project / BACKUP_REL
    pubspec = project / 'pubspec.yaml'
    if not backup.is_file():
        raise RuntimeError('No hay copia de seguridad automática; no se modifica pubspec.yaml.')
    current = pubspec.read_text(encoding='utf-8')
    if 'path: third_party/just_audio_media_kit' not in current:
        raise RuntimeError('El override ya no existe: no se sobreescriben otros cambios.')
    original = backup.read_text(encoding='utf-8')
    # Quitar solamente la ruta introducida, preservando posibles cambios
    # que el usuario haya hecho a pubspec.yaml tras activar el parche.
    block = '  just_audio_media_kit:\n    path: third_party/just_audio_media_kit\n'
    if current.count(block) != 1:
        raise RuntimeError('El override fue editado: se cancela para no perder cambios.')
    if re.search(r'^dependency_overrides:\s*$', original, flags=re.M):
        restored = current.replace(block, '', 1)
    else:
        header_block = 'dependency_overrides:\n' + block
        if header_block not in current:
            raise RuntimeError('Estructura del override cambiada: no se toca pubspec.yaml.')
        restored = current.replace(header_block, '', 1)
    pubspec.write_text(restored, encoding='utf-8')
    backup.unlink()
    print('Override revertido sin reemplazar otros cambios de pubspec.yaml.')
    print('La carpeta third_party queda sin usarse y no se borra.')
    print('Ejecuta flutter pub get para volver al adaptador original.')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--apply', action='store_true')
    group.add_argument('--restore', action='store_true')
    group.add_argument('--status', action='store_true')
    args = parser.parse_args()
    try:
        if args.apply:
            apply(PROJECT)
        elif args.restore:
            restore(PROJECT)
        else:
            print(status(PROJECT))
        return 0
    except (OSError, ValueError, RuntimeError, KeyError, json.JSONDecodeError) as exc:
        print(f'Lyra: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
