/// Última sesión de reproducción, guardada únicamente en el dispositivo.
/// Nunca persistimos URL temporales googlevideo, tokens ni cabeceras HTTP.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart'
    show persistentTrack;

const playbackSessionKey = 'lyra_playback_session_v1';

class SavedPlaybackSession {
  const SavedPlaybackSession({required this.queue, required this.index,
    required this.position, required this.shuffle, required this.repeat,
    required this.autoRadio});
  final List<Track> queue;
  final int index;
  final Duration position;
  final bool shuffle;
  final int repeat;
  final bool autoRadio;

  Map<String, Object?> toMap() => {
    'version': 1,
    'queue': queue.map((t) => persistentTrack(t).toMap()).toList(),
    'index': index, 'positionMs': position.inMilliseconds,
    'shuffle': shuffle, 'repeat': repeat, 'autoRadio': autoRadio,
  };

  factory SavedPlaybackSession.fromMap(Map<String, dynamic> map) {
    final queue = <Track>[];
    for (final item in (map['queue'] as List? ?? const []).take(500)) {
      try {
        if (item is Map) {
          final track = Track.fromMap(Map<String, dynamic>.from(item));
          if (track.id.trim().isNotEmpty && track.title.trim().isNotEmpty &&
              (track.id.startsWith('ytmusic:') || track.filePath.isNotEmpty)) {
            queue.add(track);
          }
        }
      } catch (_) { /* Saltar registros dañados. */ }
    }
    final requestedIndex = (map['index'] as num?)?.toInt() ?? 0;
    final index = queue.isEmpty ? -1 : requestedIndex.clamp(0, queue.length - 1);
    final milliseconds = (map['positionMs'] as num?)?.toInt() ?? 0;
    var safePosition = Duration(milliseconds: milliseconds.clamp(0, 86400000));
    // No reanudar encima del final de una canción ya terminada: evitar un
    // salto automático o un estado completed al pulsar Reproducir.
    if (index >= 0 && queue[index].duration != null) {
      final end = queue[index].duration!;
      if (end > const Duration(seconds: 2) &&
          safePosition >= end - const Duration(seconds: 1)) {
        safePosition = Duration.zero;
      }
    }
    return SavedPlaybackSession(
      queue: queue, index: index,
      position: safePosition,
      shuffle: map['shuffle'] == true,
      repeat: (map['repeat'] as num?)?.toInt() ?? 0,
      autoRadio: map['autoRadio'] == true,
    );
  }
}

class PlaybackSessionStore {
  const PlaybackSessionStore();

  static Future<void> _writeChain = Future<void>.value();

  Future<void> _ordered(Future<void> Function() task) {
    final operation = _writeChain.then((_) => task());
    _writeChain = operation.catchError((Object _) {});
    return operation;
  }

  Future<SavedPlaybackSession?> load() async {
    try {
      await _writeChain;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(playbackSessionKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic> || map['version'] != 1) return null;
      final snapshot = SavedPlaybackSession.fromMap(map);
      return snapshot.queue.isEmpty ? null : snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SavedPlaybackSession snapshot) => _ordered(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(playbackSessionKey, jsonEncode(snapshot.toMap()));
  });

  Future<void> clear() => _ordered(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(playbackSessionKey);
  });
}
