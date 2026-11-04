import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/player/domain/models/radio_queue_window.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

Track song(int n) => Track(
  id: 'ytmusic:track$n',
  title: 'Tema $n',
  artist: 'Artista $n',
  album: 'Radio',
  filePath: 'https://music.youtube.com/watch?v=track$n',
  duration: const Duration(minutes: 3),
);

void main() {
  const window = RadioQueueWindow();

  test('la radio conserva hasta 10 recientes y 20 siguientes', () {
    final queue = [for (var i = 0; i < 38; i++) song(i)];
    final history = [for (var i = 4; i <= 13; i++) queue[i]];
    final snap = window.rebalance(
      queue,
      13,
      [],
      recent: history,
      playedIds: history.map((e) => e.id).toSet(),
    );
    expect(snap.queue.length, 30);
    expect(snap.currentIndex, 9);
    expect(snap.queue.first.id, 'ytmusic:track4');
    expect(snap.queue[9].id, 'ytmusic:track13');
    expect(snap.queue[29].id, 'ytmusic:track33');
    expect(snap.pending.map((t) => t.id), contains('ytmusic:track37'));
  });

  test('saltar una canción no convierte las anteriores en escuchadas', () {
    final queue = [for (var i = 0; i < 24; i++) song(i)];
    final history = [queue.first, queue[5]];
    final snap = window.rebalance(
      queue,
      5,
      [],
      recent: history,
      playedIds: history.map((e) => e.id).toSet(),
    );
    expect(snap.queue[0].id, queue[0].id);
    expect(snap.queue[1].id, queue[5].id);
    expect(snap.queue[snap.currentIndex + 1].id, queue[6].id);
    expect(snap.pending.map((e) => e.id), contains(queue[4].id));
    expect(snap.queue.map((e) => e.id).toSet().length, snap.queue.length);
  });

  test('al terminar un tramo se incorporan pendientes sin repetir', () {
    final queue = [for (var i = 0; i < 14; i++) song(i)];
    final pending = [for (var i = 14; i < 35; i++) song(i)];
    final snap = window.rebalance(
      queue,
      8,
      pending,
      recent: queue.sublist(0, 9),
      playedIds: queue.sublist(0, 9).map((e) => e.id).toSet(),
    );
    expect(snap.currentIndex, 8);
    expect(snap.queue.length, 29); // 9 recientes + 20 futuras
    expect(snap.pending.length, 6);
    expect(snap.queue.map((e) => e.id).toSet().length, snap.queue.length);
  });

  test('las sugerencias repetidas no vuelven a entrar en una radio', () {
    final seen = <String>{song(0).id};
    final batch1 = window.uniqueSuggestions([song(1), song(2), song(1)], seen);
    final batch2 = window.uniqueSuggestions([song(2), song(3), song(0)], seen);
    expect(batch1.map((t) => t.id), ['ytmusic:track1', 'ytmusic:track2']);
    expect(batch2.map((t) => t.id), ['ytmusic:track3']);
    expect(seen.length, 4);
  });

  test('las playlists explícitas no se convierten en radio infinita', () {
    final playlist = [for (var i = 0; i < 60; i++) song(i)];
    expect(window.shouldStartRadio(playlist), isFalse);
    expect(window.shouldStartRadio([song(0)], enabled: false), isFalse);
    expect(window.shouldStartRadio([song(0)]), isTrue);
    expect(playlist.length, 60);
  });
}
