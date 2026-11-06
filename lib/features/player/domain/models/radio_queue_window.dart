/// Pure, testable sliding window for online radio.
/// Holds up to ten previous tracks, the active track, plus 20 upcoming.
library;

import 'dart:math' as math;
import 'package:lyra_music/features/player/domain/models/track.dart';

class RadioWindowSnapshot {
  const RadioWindowSnapshot(this.queue, this.currentIndex, this.pending);
  final List<Track> queue;
  final int currentIndex;
  final List<Track> pending;
}

class RadioQueueWindow {
  const RadioQueueWindow({
    this.previousIncludingCurrent = 11,
    this.upcoming = 20,
  });
  final int previousIncludingCurrent;
  final int upcoming;

  /// A user-selected playlist (even a one-song online playlist) must not
  /// become an automatic radio station.
  bool shouldStartRadio(List<Track> tracks, {bool enabled = true}) =>
      enabled && tracks.length == 1 && tracks.first.id.startsWith('ytmusic:');

  /// [recent] is chronological listening history including the current
  /// track. This avoids treating unplayed tracks skipped by a jump as "heard".
  RadioWindowSnapshot rebalance(
    List<Track> queue,
    int currentIndex,
    List<Track> pending, {
    List<Track>? recent,
    Set<String>? playedIds,
    Map<String, int>? manualReplayCounts,
  }) {
    if (queue.isEmpty || currentIndex < 0 || currentIndex >= queue.length) {
      return RadioWindowSnapshot(
        List<Track>.of(queue),
        currentIndex,
        List<Track>.of(pending),
      );
    }
    if (recent == null) {
      final start = math.max(0, currentIndex - previousIncludingCurrent + 1);
      final end = math.min(queue.length, currentIndex + upcoming + 1);
      final visible = <Track>[...queue.sublist(start, end)];
      final waiting = <Track>[...pending];
      final active = currentIndex - start;
      if (end < queue.length) waiting.insertAll(0, queue.sublist(end));
      while (visible.length - active - 1 < upcoming && waiting.isNotEmpty) {
        visible.add(waiting.removeAt(0));
      }
      return RadioWindowSnapshot(visible, active, waiting);
    }
    // La cola es la secuencia elegida por el usuario: NO reconstruirla
    // únicamente a partir de [recent]. De hacerlo, saltar 2→5 borra 3 y 4
    // aunque sigan siendo pistas disponibles, todavía NO escuchadas.
    //
    // Conservamos hasta 10 entradas REPRODUCIDAS a la izquierda, pero
    // dejamos TODAS las omitidas en su posición, incluso si hay más de 10.
    // Las omitidas jamás se incluyen en [playedIds] ni en estadísticas.
    final played = playedIds ?? recent.map((t) => t.id).toSet();
    final prefix = queue.take(currentIndex).toList();
    final history = <Track>[];
    var keptPlayed = 0;
    for (var i = prefix.length - 1; i >= 0; i--) {
      final track = prefix[i];
      if (played.contains(track.id)) {
        if (keptPlayed >= previousIncludingCurrent - 1) continue;
        keptPlayed++;
      }
      history.insert(0, track);
    }

    // Las entradas ya existentes, incluidas las repeticiones manuales, son
    // autoritativas. Nunca descartarlas ni trasladarlas por el simple hecho
    // de que ahora están antes de la pista activa.
    final future = <Track>[...queue.skip(currentIndex + 1)];
    final seen = <String>{
      ...history.map((t) => t.id),
      queue[currentIndex].id,
      ...future.map((t) => t.id),
    };

    // Solo depurar recomendaciones externas pendientes. Una repetición
    // expresamente programada puede tener el mismo ID que una escuchada.
    final permittedReplays = <String, int>{...?manualReplayCounts};
    for (final track in pending) {
      final requested = permittedReplays[track.id] ?? 0;
      if (requested > 0 && played.contains(track.id)) {
        permittedReplays[track.id] = requested - 1;
        future.add(track);
      } else if (!played.contains(track.id) && seen.add(track.id)) {
        future.add(track);
      }
    }

    final visible = <Track>[
      ...history,
      queue[currentIndex],
      ...future.take(upcoming),
    ];
    return RadioWindowSnapshot(
      visible,
      history.length,
      future.skip(upcoming).toList(),
    );
  }

  /// Keep a session-wide set of IDs, including tracks removed from the
  /// 30-item window. A provider can resend the same songs on later pages.
  List<Track> uniqueSuggestions(Iterable<Track> suggestions, Set<String> seen) {
    final result = <Track>[];
    for (final track in suggestions) {
      if (seen.add(track.id)) result.add(track);
    }
    return result;
  }

  /// Future songs already visible or waiting in memory.
  int bufferedAhead(List<Track> queue, int currentIndex, List<Track> pending) {
    if (currentIndex < 0 || currentIndex >= queue.length) return pending.length;
    return queue.length - currentIndex - 1 + pending.length;
  }
}
