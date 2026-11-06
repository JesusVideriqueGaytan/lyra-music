#!/usr/bin/env python3
'''Lyra 4.8.6: repara el acceso prematuro a state durante Notifier.build().

No toca las dependencias, la caché MPV, la biblioteca ni los archivos multimedia.
Se niega a editar versiones que no reconoce y deja copia de seguridad.
'''
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import sys

RELATIVE = Path('lib/features/player/presentation/controllers/audio_player_controller.dart')
BACKUP_SUFFIX = '.bak-lyra486'

OLD_BUILD = '''    // El resto de inicialización (servicio de audio) es asíncrona:
    // devolvemos estado vacío y exponemos waitUntilReady() para main().
    unawaited(_initAudioService());
    unawaited(_restoreLastSession());
    return const PlaybackState();'''
NEW_BUILD = '''    // El AudioHandler ya está vinculado a este controller en build().
    // No leer state hasta que Riverpod haya recibido el estado inicial.
    // La restauración sí es asíncrona y se ejecuta tras el primer await.
    unawaited(_restoreLastSession());
    return const PlaybackState(handlerReady: true);'''
OLD_READY = '''  /// Espera a que el handler de audio_service esté registrado. Usado en
  /// `main()` y en tests para arrancar de forma determinista.
  Future<void> waitUntilReady() => _readyFuture ??= _initAudioService();

  Future<void> _initAudioService() async {
    try {
      // AudioService.init se registra en main() cuando hay plataforma MPRIS.
      // Este indicador solo declara que el controlador puede aceptar órdenes.
      state = state.copyWith(handlerReady: true);
    } catch (e) {
      state = state.copyWith(error: 'Servicio de audio no disponible: $e');
    }
  }'''
NEW_READY = '''  /// El handler queda vinculado de forma síncrona durante build().
  /// La integración MPRIS se registra aparte en main.dart.
  Future<void> waitUntilReady() => Future<void>.value();'''


def inspect(source: str) -> str:
    if NEW_BUILD in source and NEW_READY in source and '_initAudioService()' not in source and '_readyFuture' not in source:
        return 'patched'
    if (OLD_BUILD in source and OLD_READY in source and '  Future<void>? _readyFuture;\n' in source):
        return 'original'
    return 'unknown'


def patched(source: str) -> str:
    if inspect(source) != 'original':
        raise ValueError('El archivo no coincide exactamente con la versión que conoce este parche.')
    result = source.replace(OLD_BUILD, NEW_BUILD, 1)
    result = result.replace(OLD_READY, NEW_READY, 1)
    result = result.replace('  Future<void>? _readyFuture;\n\n', '', 1)
    if inspect(result) != 'patched':
        raise ValueError('La transformación no quedó completa; no se escribió ningún cambio.')
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    act = parser.add_mutually_exclusive_group(required=True)
    act.add_argument('--check', action='store_true', help='Verificar sin modificar archivos')
    act.add_argument('--apply', action='store_true', help='Aplicar el cambio con respaldo')
    act.add_argument('--restore', action='store_true', help='Restaurar el respaldo')
    parser.add_argument('--project', type=Path,
        default=Path(__file__).resolve().parent.parent,
        help=argparse.SUPPRESS)
    args=parser.parse_args(argv)
    path=args.project.resolve()/RELATIVE
    backup=path.with_name(path.name+BACKUP_SUFFIX)
    if not path.is_file():
        print(f'ERROR: No existe {path}', file=sys.stderr)
        return 2
    current=path.read_text(encoding='utf-8')
    status=inspect(current)
    if args.check:
        print(f'Lyra 4.8.6: estado {status}; copia de seguridad: {"sí" if backup.is_file() else "no"}.')
        if status=='unknown':
            print('No se reconoce esta revisión. No se modificará. Conserva tu código actual.')
            return 2
        return 0
    if args.apply:
        if status=='patched':
            print('Ya estaba corregido. No se modificó ningún archivo.')
            return 0
        if status!='original':
            print('ERROR: código inesperado; se cancela sin modificar nada.', file=sys.stderr)
            return 2
        if backup.exists():
            print(f'ERROR: existe un respaldo previo ({backup}); no se sobrescribirá.', file=sys.stderr)
            return 2
        new=patched(current)
        shutil.copy2(path, backup)
        try:
            path.write_text(new, encoding='utf-8')
        except Exception:
            shutil.copy2(backup, path)
            raise
        print('CORREGIDO: inicialización de Riverpod. MPV y motor de audio no modificados.')
        print(f'Respaldo: {backup}')
        return 0
    if not backup.is_file():
        print('ERROR: No existe respaldo para restaurar.', file=sys.stderr)
        return 2
    if status!='patched':
        print('ERROR: el archivo ha cambiado desde el hotfix; no se sobrescriben cambios.', file=sys.stderr)
        return 2
    previous=backup.read_text(encoding='utf-8')
    if inspect(previous)!='original':
        print('ERROR: el respaldo no coincide con el código original esperado.', file=sys.stderr)
        return 2
    if current != patched(previous):
        print('ERROR: hay modificaciones posteriores; restaurar manualmente con el respaldo si deseas descartarlas.', file=sys.stderr)
        return 2
    shutil.copy2(backup,path)
    backup.unlink()
    print('RESTAURADO: versión anterior de audio_player_controller.dart.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
