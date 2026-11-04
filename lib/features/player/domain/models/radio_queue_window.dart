/// Pure, testable sliding window for online radio.
/// Holds the last 10 tracks including the active track, plus 20 upcoming.
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
    this.previousIncludingCurrent = 10,
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
    final chronological = <Track>[
      ...recent.where((track) => track.id != current.id),
      current,
    ];
    final keptHistory = chronological.length <= previousIncludingCurrent
        ? chronological
        : chronological.sublist(
            chronological.length - previousIncludingCurrent,
          );
    final knownPlayed = <String>{
      ...?playedIds,
      ...keptHistory.map((e) => e.id),
    };
    final orderedFuture = <Track>[
      ...queue.skip(currentIndex + 1),
      // Songs skipped with a jump should not be labeled as "heard".
      ...queue.take(currentIndex),
      ...pending,
    ];
    final seen = <String>{...keptHistory.map((e) => e.id)};
    final unplayedFuture = <Track>[
      for (final song in orderedFuture)
        if (!knownPlayed.contains(song.id) && seen.add(song.id)) song,
    ];
    final visible = <Track>[...keptHistory, ...unplayedFuture.take(upcoming)];
    return RadioWindowSnapshot(
      visible,
      keptHistory.length - 1,
      unplayedFuture.skip(upcoming).toList(),
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
