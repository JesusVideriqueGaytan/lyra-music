#!/usr/bin/env python3
"""Lyra 4.8.8: opción A (salto real) y repetición de canciones del historial.

Cambios mínimos al controlador: preserva las correcciones de Riverpod 4.8.6,
la sesión y el override de MPV. Crea respaldo y se niega a editar código ajeno.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import shutil

REL = Path('lib/features/player/presentation/controllers/audio_player_controller.dart')
SUFFIX = '.bak-lyra488'

FIELDS = '''  /// Reproducciones solicitadas por el usuario al arrastrar el historial.
  /// No se confunden con recomendaciones repetidas del proveedor.
  final Map<String, int> _radioRequestedReplays = <String, int>{};
'''
MARK_METHOD = '''  void _markRadioPlayed(Track track, {bool isRequestedReplay = false}) {
    if (!state.autoRadio) return;
    // Navegar hacia atrás no reordena el historial. Una reproducción
    // PROGRAMADA por arrastre sí cuenta como una nueva escucha real.
    if (_radioPlayed.contains(track.id) && !isRequestedReplay) return;
    _radioPlayed.add(track.id);
    _radioRecentlyPlayed.add(track);
    if (_radioRecentlyPlayed.length > 11) _radioRecentlyPlayed.removeAt(0);
  }

  void _consumeRadioReplay(String id) {
    final count = _radioRequestedReplays[id] ?? 0;
    if (count <= 1) {
      _radioRequestedReplays.remove(id);
    } else {
      _radioRequestedReplays[id] = count - 1;
    }
  }

'''
RESTORE_EXTRA = '''      // Una copia futura del mismo ID es una repetición manual pendiente.
      for (final track in snapshot.queue.skip(index + 1)) {
        if (_radioPlayed.contains(track.id)) {
          _radioRequestedReplays.update(track.id, (n) => n + 1,
              ifAbsent: () => 1);
        }
      }
'''
PLAYAT_EXTRA = '''    // Opción A: elegir una canción más adelante es SALTAR a ella.
    // Las intermedias no pasan al historial ni vuelven a colocarse detrás.
    final oldIndex = state.currentIndex;
    if (state.autoRadio && index > oldIndex + 1) {
      for (final skipped in state.queue.sublist(oldIndex + 1, index)) {
        // Si se saltó una repetición programada, dejar de reservarla.
        if ((_radioRequestedReplays[skipped.id] ?? 0) > 0) {
          _consumeRadioReplay(skipped.id);
        }
      }
    }
    final isReplay = state.autoRadio && index > oldIndex &&
        (_radioRequestedReplays[requestedTrack.id] ?? 0) > 0;
    if (isReplay) _consumeRadioReplay(requestedTrack.id);

'''
REPLAY_METHOD = '''  /// Programa de nuevo una canción anterior sin retirarla del historial.
  /// El índice de inserción se refiere a la cola antes de añadir la copia.
  Future<void> replayFromHistory(int historyIndex, int insertIndex) async {
    final existing = state.queue;
    final active = state.currentIndex;
    if (historyIndex < 0 || historyIndex >= active || active < 0 ||
        insertIndex <= active || insertIndex > existing.length) return;
    final track = existing[historyIndex];
    final index = insertIndex.clamp(active + 1, existing.length);

    // En colas de archivos, sincronizar just_audio ANTES de modificar la UI.
    // En radio en línea, cada pista se carga al comenzar y no requiere esto.
    if (!_restoredNeedsSource && !_singleSourceQueue) {
      try {
        await _player.insertAudioSource(index, _audioSourceFor(track));
      } catch (e) {
        state = state.copyWith(error:
            'No se pudo programar la canción anterior: $e');
        return;
      }
    }
    final updated = <Track>[...state.queue]..insert(index, track);
    if (state.autoRadio) {
      _radioRequestedReplays.update(track.id, (n) => n + 1,
          ifAbsent: () => 1);
    }
    state = state.copyWith(queue: List<Track>.unmodifiable(updated),
        clearError: true);
    _publishQueue(updated, state.currentIndex);
    if (_restoredNeedsSource) {
      _restoredSession = _captureSession();
    } else if (state.autoRadio) {
      _balanceRadioWindow();
    }
    _scheduleSessionSave();
  }

'''


def unique_sub(src: str, pattern: str, repl: str, flags=0) -> str:
    if len(list(re.finditer(pattern, src, flags))) != 1:
        raise ValueError(f'No se puede reconocer de forma única: {pattern!r}')
    return re.sub(pattern, lambda _: repl, src, count=1, flags=flags)


def transform(src: str) -> str:
    if 'return const PlaybackState(handlerReady: true);' not in src:
        raise ValueError('Primero instala Lyra 4.8.6. Se protege la inicialización de Riverpod.')
    if 'void _consumeRadioReplay(' in src:
        raise ValueError('La versión 4.8.8 ya aparece aplicada.')
    src = unique_sub(src,
        r'(?m)^  final List<Track> _radioRecentlyPlayed = <Track>\[\];\n',
        '  final List<Track> _radioRecentlyPlayed = <Track>[];\n'+FIELDS)
    src = unique_sub(src,
        r'(?m)^    _radioRecentlyPlayed\.clear\(\);\n',
        '    _radioRecentlyPlayed.clear();\n    _radioRequestedReplays.clear();\n')
    src = unique_sub(src,
        r'playedIds:\s*_radioPlayed\s*\);',
        'playedIds: _radioPlayed,\n        manualReplayCounts: _radioRequestedReplays);')
    src = unique_sub(src,
        r'(?ms)^  void _markRadioPlayed\(Track track\)\s*\{.*?\n  \}\n\n(?=  static bool _sameTrackIds)',
        MARK_METHOD)
    src = unique_sub(src,
        r'(?m)^\s*_radioPlayed\.addAll\(_radioRecentlyPlayed\.map\(\(t\) => t\.id\)\);\n',
        '      _radioPlayed.addAll(_radioRecentlyPlayed.map((t) => t.id));\n'+RESTORE_EXTRA)
    start = src.index('  Future<void> playAt(int index) async {')
    end = src.index('  Future<void> play() async {',start)
    part = src[start:end]
    part = unique_sub(part, r'(?m)^    final generation = \+\+_switchGeneration;\n',
        PLAYAT_EXTRA+'    final generation = ++_switchGeneration;\n')
    part = unique_sub(part, r'_markRadioPlayed\(\s*state\.queue\[index\]\s*\);',
        '_markRadioPlayed(state.queue[index],\n              isRequestedReplay: isReplay);')
    src = src[:start]+part+src[end:]
    src = unique_sub(src,
        r'(?m)^(  /// Reordena la cola por arrastre; el índice activo sigue a su pista\.)',
        REPLAY_METHOD+'  /// Reordena la cola por arrastre; el índice activo sigue a su pista.')
    src = unique_sub(src,
        r'(?m)^\s*if \(state\.autoRadio\) _radioSeen\.add\(track\.id\);\n',
        '''    if (state.autoRadio) {
      _radioSeen.add(track.id);
      if (_radioPlayed.contains(track.id)) {
        _radioRequestedReplays.update(track.id, (n) => n + 1,
            ifAbsent: () => 1);
      }
    }
''')
    return src


def run() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    a = ap.add_mutually_exclusive_group(required=True)
    a.add_argument('--check', action='store_true')
    a.add_argument('--apply', action='store_true')
    a.add_argument('--restore', action='store_true')
    ap.add_argument('--project', type=Path, default=Path(__file__).resolve().parent.parent)
    args=ap.parse_args()
    target=args.project.resolve()/REL
    backup=target.with_name(target.name+SUFFIX)
    if not target.is_file():
        print(f'Archivo no encontrado: {target}')
        return 2
    current=target.read_text(encoding='utf8')
    if args.restore:
        if not backup.exists():
            print('No existe el respaldo de 4.8.8.')
            return 2
        original=backup.read_text(encoding='utf8')
        try:
            expected=transform(original)
        except ValueError as ex:
            print(f'El respaldo no coincide: {ex}')
            return 2
        if current!=expected:
            print('El archivo fue editado después: para evitar pérdida de trabajo, usa Git.')
            return 2
        shutil.copy2(backup,target)
        backup.unlink()
        print('Controlador restaurado a 4.8.7 (con arreglo de Riverpod).')
        return 0
    if 'void _consumeRadioReplay(' in current:
        print('Lyra 4.8.8: YA APLICADO al controlador.')
        return 0
    try:
        modified=transform(current)
    except ValueError as ex:
        print(f'No se aplicó nada: {ex}')
        return 2
    if args.check:
        print('Lyra 4.8.8: controlador compatible, pendiente de instalar.')
        return 0
    if backup.exists():
        print(f'Ya existe el respaldo {backup}. No se sobrescribe.')
        return 2
    shutil.copy2(target,backup)
    target.write_text(modified,encoding='utf8')
    print(f'Controlador corregido. Respaldo: {backup}')
    return 0

if __name__=='__main__':
    raise SystemExit(run())
