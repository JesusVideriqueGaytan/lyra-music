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
    final current = queue[currentIndex];
    // La secuencia [recent] representa el orden CRONOLÓGICO de la escucha.
    // Al retroceder, la pista actual puede estar en medio del historial:
    // nunca la reubiques al final, pues entonces Anterior alterna A/B.
    final matching = <int>[
      for (var i = 0; i < recent.length; i++)
        if (recent[i].id == current.id) i,
    ];
    // Si una canción se programó por segunda vez, puede estar dos veces en
    // el historial. Distinguir la primera reproducción de la repetición por
    // el número de ocurrencias presentes antes del cursor de la cola.
    final visibleOccurrences = queue
        .take(currentIndex + 1)
        .where((track) => track.id == current.id)
        .length;
    final cursorInHistory = matching.isEmpty
        ? -1
        : matching[(visibleOccurrences - 1).clamp(0, matching.length - 1)];
    final chronological = cursorInHistory >= 0
        ? List<Track>.of(recent)
        : <Track>[...recent, current];
    final cursor = cursorInHistory >= 0
        ? cursorInHistory
        : chronological.length - 1;
    final historyStart = math.max(0, cursor - previousIncludingCurrent + 1);
    final history = chronological.sublist(historyStart, cursor + 1);

    // Las pistas escuchadas DESPUÉS del cursor (al navegar hacia atrás)
    // continúan por delante, en lugar de descartarse como duplicados.
    final forwardHistory = chronological.skip(cursor + 1).toList();
    // Si saltamos de la canción 2 a la 5, las canciones 3 y 4 NO vuelven a
    // insertarse tras la 5. Solo quedan las que siguen realmente después del
    // nuevo cursor y las recomendaciones que aún están pendientes.
    final proposals = <Track>[...queue.skip(currentIndex + 1), ...pending];
    final seen = <String>{...history.map((track) => track.id)};
    final future = <Track>[...forwardHistory];
    seen.addAll(forwardHistory.map((track) => track.id));

    // Única excepción a la deduplicación: el usuario pidió explícitamente
    // volver a escuchar una canción pasada arrastrándola a las siguientes.
    final replays = <String, int>{...?manualReplayCounts};
    for (final track in proposals) {
      final remaining = replays[track.id] ?? 0;
      if (remaining > 0) {
        replays[track.id] = remaining - 1;
        future.add(track);
        continue;
      }
      if (playedIds?.contains(track.id) == true) continue;
      if (seen.add(track.id)) future.add(track);
    }
    final visible = <Track>[...history, ...future.take(upcoming)];
    return RadioWindowSnapshot(
      visible,
      history.length - 1,
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
