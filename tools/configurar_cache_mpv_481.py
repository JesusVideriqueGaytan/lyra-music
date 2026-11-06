#!/usr/bin/env python3
"""Lyra 4.8.4: instalador revisado de cache-on-disk=no para MPV en Linux.

Uso:
  python tools/configurar_cache_mpv_481.py --inspect
  python tools/configurar_cache_mpv_481.py --apply
  python tools/configurar_cache_mpv_481.py --status
  python tools/configurar_cache_mpv_481.py --restore

Localiza el adaptador realmente instalado. Si no reconoce su API, NO hace cambios.
El override se crea en el proyecto, no en ~/.pub-cache.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile
from urllib.parse import unquote, urlparse

PROJECT = Path(__file__).resolve().parents[1]
VENDOR_REL = Path('third_party/just_audio_media_kit')
BACKUP_REL = Path('.lyra481_pubspec_original')
MARKER = 'LYRA_483_CACHE_ON_DISK'
PACKAGE = 'just_audio_media_kit'


def find_installed_package(project: Path) -> Path:
    config = project / '.dart_tool/package_config.json'
    if not config.is_file():
        raise RuntimeError('Falta .dart_tool/package_config.json: ejecuta flutter pub get.')
    data = json.loads(config.read_text(encoding='utf-8'))
    entry = next((p for p in data.get('packages', []) if p.get('name') == PACKAGE), None)
    if entry is None:
        raise RuntimeError('Flutter no resolvió just_audio_media_kit en package_config.json.')
    uri = entry.get('rootUri', '')
    parsed = urlparse(uri)
    if parsed.scheme == 'file':
        root = Path(unquote(parsed.path)).resolve()
    elif not parsed.scheme:
        root = (config.parent / unquote(uri)).resolve()
    else:
        raise RuntimeError(f'Esquema de paquete no compatible: {parsed.scheme}')
    if not (root / 'pubspec.yaml').is_file():
        raise RuntimeError(f'No se encontró pubspec.yaml del adaptador: {root}')
    return root


def locate_player_source(root: Path) -> Path:
    """Busca por clase, no por nombre/ruta asumidos de un archivo."""
    lib = root / 'lib'
    if not lib.is_dir():
        raise RuntimeError('La dependencia no tiene carpeta lib/.')
    matches = []
    for path in lib.rglob('*.dart'):
        try:
            content = path.read_text(encoding='utf-8')
        except (OSError, UnicodeError):
            continue
        if re.search(r'\bclass\s+MediaKitPlayer\b', content):
            matches.append(path)
    if len(matches) != 1:
        candidates = ', '.join(str(x.relative_to(root)) for x in sorted(lib.rglob('*.dart'))[:12])
        raise RuntimeError(
            f'Se encontraron {len(matches)} implementaciones MediaKitPlayer (se esperaba 1). '
            f'Archivos Dart detectados: {candidates}. No se modificó nada.'
        )
    return matches[0]


def patch_source(source: str) -> str:
    if MARKER in source:
        raise RuntimeError('El archivo ya está modificado con este parche.')
    # En just_audio_media_kit 2.1.0 el import real es src/set_property.dart.
    imports_set_property = any(token in source for token in (
        "import 'src/set_property.dart';", "import 'set_property.dart';",
        'import "src/set_property.dart";', 'import "set_property.dart";',
    ))
    if 'setProperty(' not in source or not imports_set_property:
        raise RuntimeError(
            'No se encontró la importación y uso compatibles de setProperty '
            'en MediaKitPlayer; se cancela por seguridad.'
        )
    if not re.search(r'\bFuture<void>\s+ready\(\)', source):
        raise RuntimeError('No se encontró ready() compatible; se cancela por seguridad.')
    if not re.search(r'\bclass\s+MediaKitPlayer\b', source):
        raise RuntimeError('No es la implementación MediaKitPlayer.')
    # La API de v2.1.0 espera ready() desde JustAudioMediaKit.init antes de reproducir.
    pattern = re.compile(r'(?m)^(?P<indent>[ \t]*)Future<void>\s+ready\(\)\s*=>\s*_readyCompleter\.future\s*;')
    found = list(pattern.finditer(source))
    if len(found) != 1:
        raise RuntimeError('No se reconoció ready() en este adaptador. Se cancela sin cambiar código.')
    indent = found[0].group('indent')
    replacement = f'''{indent}Future<void> ready() async {{
{indent}  await _readyCompleter.future;
{indent}  // {MARKER}: la propiedad se envía ANTES del primer load().
{indent}  if (UniversalPlatform.isLinux) {{
{indent}    try {{
{indent}      await setProperty(_player, 'cache-on-disk', 'no');
{indent}    }} catch (error) {{
{indent}      // Este ajuste es opcional: no debe bloquear la reproducción.
{indent}      _logger.warning('Lyra: no se pudo ajustar cache-on-disk', error);
{indent}    }}
{indent}  }}
{indent}}}'''
    updated = pattern.sub(lambda _: replacement, source, count=1)
    imp = "import 'package:universal_platform/universal_platform.dart';"
    if imp not in updated:
        # UniversalPlatform ya es dependencia directa del adaptador 2.1.0.
        # Una declaración `library` debe preceder a todos los imports en Dart.
        library = re.search(r'(?m)^[ \t]*library[ \t]+[A-Za-z_][A-Za-z0-9_.]*[ \t]*;[ \t]*$', updated)
        if library:
            updated = updated[:library.end()] + '\n' + imp + updated[library.end():]
        else:
            updated = imp + '\n' + updated
    return updated


def override_pubspec(original: str) -> str:
    if 'path: third_party/just_audio_media_kit' in original:
        raise RuntimeError('El pubspec ya contiene el override local.')
    # No sobrescribir overrides de otra persona.
    m = re.search(r'(?m)^dependency_overrides:\s*(?:#[^\n]*)?$', original)
    block = '  just_audio_media_kit:\n    path: third_party/just_audio_media_kit\n'
    if m:
        section = original[m.end():]
        end = re.search(r'(?m)^\S', section)
        section = section[:end.start()] if end else section
        if re.search(r'(?m)^  just_audio_media_kit\s*:', section):
            raise RuntimeError('Ya hay un override para just_audio_media_kit.')
        return original[:m.end()] + '\n' + block + original[m.end():].lstrip('\n')
    return original.rstrip() + '\n\ndependency_overrides:\n' + block


def status(project: Path) -> str:
    pubspec = project / 'pubspec.yaml'
    active = 'path: third_party/just_audio_media_kit' in pubspec.read_text(encoding='utf-8') if pubspec.is_file() else False
    vendor = project / VENDOR_REL
    patched = []
    if vendor.is_dir():
        patched = [p for p in vendor.rglob('*.dart') if MARKER in p.read_text(encoding='utf-8')]
    if active and len(patched) == 1:
        return f'ACTIVADO: override local y ajuste en {patched[0].relative_to(project)}.'
    if not active:
        if patched:
            return 'NO ACTIVADO: override desactivado; permanece copia local sin uso.'
        return 'NO ACTIVADO: se usa el adaptador publicado sin cambios locales.'
    return 'ESTADO PARCIAL: el override existe pero no se detectó código compatible.'


def apply(project: Path) -> None:
    pubspec = project / 'pubspec.yaml'
    backup = project / BACKUP_REL
    vendor = project / VENDOR_REL
    if not pubspec.is_file():
        raise RuntimeError('No se encontró pubspec.yaml en el proyecto.')
    if backup.exists() or vendor.exists():
        if status(project).startswith('ACTIVADO'):
            print('El parche ya está aplicado; no se repitieron cambios.')
            return
        raise RuntimeError('Ya hay respaldo o third_party previo; no se sobrescribe. Usa --status.')
    root = find_installed_package(project)
    source_path = locate_player_source(root)
    source_content = source_path.read_text(encoding='utf-8')
    new_content = patch_source(source_content)
    original = pubspec.read_text(encoding='utf-8')
    new_pubspec = override_pubspec(original)
    (project / 'third_party').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='lyra483-stage-', dir=project / 'third_party') as temp:
        staged = Path(temp) / PACKAGE
        shutil.copytree(root, staged, ignore=shutil.ignore_patterns('.dart_tool', 'build', '.git'))
        target = staged / source_path.relative_to(root)
        target.write_text(new_content, encoding='utf-8')
        backup.write_text(original, encoding='utf-8')
        try:
            staged.rename(vendor)
            pubspec.write_text(new_pubspec, encoding='utf-8')
        except Exception:
            pubspec.write_text(original, encoding='utf-8')
            if vendor.exists():
                shutil.rmtree(vendor)
            backup.unlink(missing_ok=True)
            raise
    print(f'Adaptador detectado: {source_path.relative_to(root)}')
    print(status(project))
    print('Ahora ejecuta: flutter pub get; flutter analyze; flutter test')
    print('Reversión: python tools/configurar_cache_mpv_481.py --restore')


def restore(project: Path) -> None:
    pubspec = project / 'pubspec.yaml'
    backup = project / BACKUP_REL
    if not backup.is_file():
        raise RuntimeError('No existe el respaldo original; no se modificó pubspec.yaml.')
    current = pubspec.read_text(encoding='utf-8')
    old = backup.read_text(encoding='utf-8')
    block = '  just_audio_media_kit:\n    path: third_party/just_audio_media_kit\n'
    if current.count(block) != 1:
        raise RuntimeError('El override fue modificado manualmente: se cancela para proteger tus cambios.')
    if re.search(r'(?m)^dependency_overrides:', old):
        restored = current.replace(block, '', 1)
    else:
        header = 'dependency_overrides:\n' + block
        if header not in current:
            raise RuntimeError('No se reconoció el bloque introducido: se cancela.')
        restored = current.replace(header, '', 1)
    if restored.rstrip('\n') == old.rstrip('\n'):
        # Si no hubo otros cambios, recupera exactamente los bytes originales.
        restored = old
    pubspec.write_text(restored, encoding='utf-8')
    backup.unlink()
    print('Revertido el override. Los archivos third_party quedan sin uso, sin eliminarlos.')
    print('Ejecuta flutter pub get y prueba de nuevo.')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--inspect', action='store_true')
    group.add_argument('--apply', action='store_true')
    group.add_argument('--restore', action='store_true')
    group.add_argument('--status', action='store_true')
    args = parser.parse_args()
    try:
        if args.status:
            print(status(PROJECT))
        elif args.inspect:
            root = find_installed_package(PROJECT)
            print(f'Ruta del paquete: {root}')
            src = locate_player_source(root)
            print(f'Archivo real del adaptador: {src.relative_to(root)}')
            # Comprueba que se puede aplicar, sin tocar archivos.
            patch_source(src.read_text(encoding='utf-8'))
            print('API reconocida. Puedes ejecutar --apply.')
        elif args.apply:
            apply(PROJECT)
        elif args.restore:
            restore(PROJECT)
        return 0
    except (OSError, RuntimeError, KeyError, ValueError, json.JSONDecodeError) as error:
        print(f'Lyra: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
