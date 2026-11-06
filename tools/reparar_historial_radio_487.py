#!/usr/bin/env python3
# Lyra 4.8.7: historial de radio; modifica solamente fragmentos validados.
# No toca Riverpod, el motor MPV ni la caché.
from pathlib import Path
import argparse
import sys
import shutil

FILE = Path('lib/features/player/presentation/controllers/audio_player_controller.dart')
BACKUP = '.bak-lyra487'
OLD = '''  void _markRadioPlayed(Track track) {
    if (!state.autoRadio) return;
    _radioPlayed.add(track.id);
    if (_radioRecentlyPlayed.isNotEmpty &&
        _radioRecentlyPlayed.last.id == track.id) return;
    _radioRecentlyPlayed.removeWhere((item) => item.id == track.id);
    _radioRecentlyPlayed.add(track);
    if (_radioRecentlyPlayed.length > 10) _radioRecentlyPlayed.removeAt(0);
  }'''
NEW = '''  void _markRadioPlayed(Track track) {
    if (!state.autoRadio) return;
    // Revisitar una canción del historial no debe moverla al final de él.
    // Ese comportamiento hacía que Anterior alternara entre dos pistas.
    if (_radioPlayed.contains(track.id)) return;
    _radioPlayed.add(track.id);
    _radioRecentlyPlayed.add(track);
    // Mantener diez escuchadas anteriormente, además de la canción actual.
    if (_radioRecentlyPlayed.length > 11) _radioRecentlyPlayed.removeAt(0);
  }'''
OLD_RESUME = 'toList().reversed.take(10).toList().reversed'
NEW_RESUME = 'toList().reversed.take(11).toList().reversed'
OLD_COMMENT = '/// Update the 30-slot visible window'
NEW_COMMENT = '/// Update the 31-slot visible window'
OLD_PREVIOUS = '    if (state.position > const Duration(seconds: 3)) {'
NEW_PREVIOUS = '    if (!state.autoRadio && state.position > const Duration(seconds: 3)) {'


def transform(src):
    if src.count(OLD) != 1 or src.count(OLD_RESUME) != 1 or src.count(OLD_PREVIOUS) != 1:
        raise ValueError('La versión del controlador no coincide con Lyra 4.8.6. Se cancela.')
    result=src.replace(OLD,NEW,1).replace(OLD_RESUME,NEW_RESUME,1)
    result=result.replace(OLD_PREVIOUS,NEW_PREVIOUS,1)
    return result.replace(OLD_COMMENT,NEW_COMMENT,1)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    a=p.add_mutually_exclusive_group(required=True)
    a.add_argument('--check',action='store_true')
    a.add_argument('--apply',action='store_true')
    a.add_argument('--restore',action='store_true')
    args=p.parse_args()
    src=Path(__file__).resolve().parent.parent / FILE
    backup=src.with_name(src.name+BACKUP)
    if not src.is_file():
        print(f'No existe {src}',file=sys.stderr); return 2
    current=src.read_text(encoding='utf-8')
    if args.check:
        print('Lyra 4.8.7: ' + ('pendiente' if OLD in current else 'ya corregido' if NEW in current else 'NO reconocido'))
        return 0 if OLD in current or NEW in current else 2
    if args.apply:
        if NEW in current:
            print('Ya corregido; no se modifica.'); return 0
        if backup.exists():
            print('Ya existe un respaldo: se cancela para no sobrescribirlo.',file=sys.stderr); return 2
        try: fixed=transform(current)
        except ValueError as e: print(e,file=sys.stderr); return 2
        shutil.copy2(src,backup)
        src.write_text(fixed,encoding='utf-8')
        print(f'CORREGIDO el historial de la radio. Respaldo: {backup}')
        return 0
    if not backup.is_file():
        print('No hay respaldo de 4.8.7.',file=sys.stderr); return 2
    original=backup.read_text(encoding='utf-8')
    try: expected=transform(original)
    except ValueError:
        print('El respaldo no coincide con el código esperado.',file=sys.stderr); return 2
    if current!=expected:
        print('El controlador tiene cambios posteriores; no se sobrescribe.',file=sys.stderr); return 2
    shutil.copy2(backup,src)
    backup.unlink()
    print('Revertido el controlador de radio.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
