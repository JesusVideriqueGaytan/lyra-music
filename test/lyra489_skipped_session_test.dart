import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/player/data/playback_session_store.dart';
import 'package:lyra_music/features/player/domain/models/radio_queue_window.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

Track song(int n) => Track(
  id: 'ytmusic:track$n',
  title: 'Tema $n',
  artist: 'Artista',
  album: 'Radio',
  filePath: 'https://music.youtube.com/watch?v=track$n',
);

void main() {
  test('2→5: se recuperan las omitidas tras cerrar Lyra', () {
    final original = [for (var i = 1; i <= 6; i++) song(i)];
    final listened = [song(1).id, song(2).id, song(5).id];
    final saved = SavedPlaybackSession(
      queue: original,
      index: 4,
      position: const Duration(seconds: 48),
      shuffle: false,
      repeat: 0,
      autoRadio: true,
      radioPlayedIds: listened,
      radioRecentIds: listened,
    );
    final encoded = jsonEncode(saved.toMap());
    final restored = SavedPlaybackSession.fromMap(
      Map<String, dynamic>.from(jsonDecode(encoded) as Map),
    );
    expect(restored.radioPlayedIds, listened);
    expect(restored.radioPlayedIds, isNot(contains(song(3).id)));
    expect(restored.radioPlayedIds, isNot(contains(song(4).id)));
    expect(restored.radioRecentIds, listened);
    expect(restored.position.inSeconds, 48);
    final snap = const RadioQueueWindow().rebalance(
      restored.queue,
      restored.index,
      [],
      recent: listened
          .map((id) => original.firstWhere((t) => t.id == id))
          .toList(),
      playedIds: restored.radioPlayedIds!.toSet(),
    );
    expect(snap.queue.map((t) => t.id), original.map((t) => t.id));
    expect(snap.currentIndex, 4);
  });

  test('las sesiones antiguas siguen cargando sin campos nuevos', () {
    final previous = SavedPlaybackSession.fromMap({
      'version': 1,
      'queue': [song(1).toMap(), song(2).toMap()],
      'index': 1,
      'positionMs': 42000,
      'autoRadio': true,
      'repeat': 0,
      'shuffle': false,
    });
    expect(previous.queue.length, 2);
    expect(previous.radioPlayedIds, isNull);
    expect(previous.radioRecentIds, isNull);
  });

  test('una sesión malformada no acepta IDs inválidos', () {
    final previous = SavedPlaybackSession.fromMap({
      'version': 1,
      'queue': [song(5).toMap()],
      'index': 0,
      'positionMs': 0,
      'autoRadio': true,
      'repeat': 0,
      'shuffle': false,
      'radioPlayedIds': [song(5).id, '', 123, 'x' * 300],
      'radioRecentIds': [song(5).id],
    });
    expect(previous.radioPlayedIds, [song(5).id]);
    expect(previous.radioRecentIds, [song(5).id]);
  });
}
