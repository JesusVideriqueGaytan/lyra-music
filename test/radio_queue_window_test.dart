import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/player/domain/models/radio_queue_window.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

Track song(int n) => Track(
  id: 'ytmusic:track$n', title: 'Tema $n', artist: 'Artista $n',
  album: 'Radio', filePath: 'https://music.youtube.com/watch?v=track$n',
  duration: const Duration(minutes: 3),
);

void main() {
  const window = RadioQueueWindow();

  test('la radio conserva hasta 10 recientes y 20 siguientes', () {
    final queue = [for (var i = 0; i < 38; i++) song(i)];
    final history = [for (var i = 4; i <= 13; i++) queue[i]];
    final snap = window.rebalance(queue, 13, [],
      recent: history, playedIds: history.map((e) => e.id).toSet());
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
    final snap = window.rebalance(queue, 5, [],
      recent: history, playedIds: history.map((e) => e.id).toSet());
    expect(snap.queue[0].id, queue[0].id);
    expect(snap.queue[1].id, queue[5].id);
    expect(snap.queue[snap.currentIndex + 1].id, queue[6].id);
    expect(snap.queue.map((e) => e.id), isNot(contains(queue[4].id)));
    expect(snap.pending.map((e) => e.id), isNot(contains(queue[4].id)));
    expect(snap.queue.map((e) => e.id).toSet().length, snap.queue.length);
  });

  test('opción A: saltar 2→5, continuar por 6 (sin reinsertar 3 ni 4)', () {
    final queue = [for (var i = 1; i <= 10; i++) song(i)];
    final history = [song(1), song(2), song(5)];
    final snap = window.rebalance(queue, 4, [],
        recent: history, playedIds: history.map((t) => t.id).toSet());
    expect(snap.queue.map((t) => t.id), [
      song(1).id, song(2).id, song(5).id,
      song(6).id, song(7).id, song(8).id, song(9).id, song(10).id,
    ]);
    expect(snap.currentIndex, 2);
    // Volver atrás recorre 5→2→1 y siguiente devuelve 5.
    final back = window.rebalance(snap.queue, 1, snap.pending,
        recent: history, playedIds: history.map((t) => t.id).toSet());
    expect(back.queue[back.currentIndex].id, song(2).id);
    expect(back.queue[back.currentIndex + 1].id, song(5).id);
  });

  test('arrastrar canción anterior añade una segunda escucha pendiente', () {
    final queue = [song(1), song(2), song(3), song(1), song(4), song(5)];
    final history = [song(1), song(2), song(3)];
    final snap = window.rebalance(queue, 2, [],
      recent: history,
      playedIds: history.map((t) => t.id).toSet(),
      manualReplayCounts: {song(1).id: 1},
    );
    expect(snap.queue.map((t) => t.id), [
      song(1).id, song(2).id, song(3).id, song(1).id, song(4).id, song(5).id,
    ]);
    expect(snap.currentIndex, 2);
  });

  test('si se reprodujo una repetición, el cursor distingue ambas copias', () {
    final queue = [song(1), song(2), song(3), song(1), song(4)];
    final recent = [song(1), song(2), song(3), song(1)];
    final played = recent.map((t) => t.id).toSet();
    final nowReplay = window.rebalance(queue, 3, [],
        recent: recent, playedIds: played);
    expect(nowReplay.currentIndex, 3);
    final previous = window.rebalance(nowReplay.queue, 2,
        nowReplay.pending, recent: recent, playedIds: played);
    expect(previous.queue[previous.currentIndex].id, song(3).id);
    final original = window.rebalance(previous.queue, 0,
        previous.pending, recent: recent, playedIds: played);
    expect(original.currentIndex, 0);
    expect(original.queue[original.currentIndex].id, song(1).id);
    expect(original.queue[original.currentIndex + 1].id, song(2).id);
  });

  test('no se permiten replays si no los pidió el usuario', () {
    final queue = [song(1), song(2), song(3), song(1), song(4)];
    final history = [song(1), song(2), song(3)];
    final snap = window.rebalance(queue, 2, [], recent: history,
        playedIds: history.map((t) => t.id).toSet());
    expect(snap.queue.map((t) => t.id).toList(),
        [song(1).id, song(2).id, song(3).id, song(4).id]);
  });

  test('al terminar un tramo se incorporan pendientes sin repetir', () {
    final queue = [for (var i = 0; i < 14; i++) song(i)];
    final pending = [for (var i = 14; i < 35; i++) song(i)];
    final snap = window.rebalance(queue, 8, pending,
      recent: queue.sublist(0, 9),
      playedIds: queue.sublist(0, 9).map((e) => e.id).toSet());
    expect(snap.currentIndex, 8);
    expect(snap.queue.length, 29); // 9 recientes + 20 futuras
    expect(snap.pending.length, 6);
    expect(snap.queue.map((e) => e.id).toSet().length, snap.queue.length);
  });

  test('Anterior retrocede 5→4→3 sin alternar 5 y 4', () {
    final queue = [for (var i = 0; i < 26; i++) song(i)];
    final chronological = [for (var i = 0; i <= 5; i++) queue[i]];
    final played = chronological.map((t) => t.id).toSet();
    final onFive = window.rebalance(queue, 5, [],
        recent: chronological, playedIds: played);
    expect(onFive.queue[onFive.currentIndex].id, song(5).id);
    final onFour = window.rebalance(onFive.queue, onFive.currentIndex - 1,
        onFive.pending, recent: chronological, playedIds: played);
    expect(onFour.queue[onFour.currentIndex].id, song(4).id);
    expect(onFour.queue[onFour.currentIndex + 1].id, song(5).id);
    final onThree = window.rebalance(onFour.queue, onFour.currentIndex - 1,
        onFour.pending, recent: chronological, playedIds: played);
    expect(onThree.queue[onThree.currentIndex].id, song(3).id);
    expect(onThree.queue[onThree.currentIndex + 1].id, song(4).id);
    final forwardAgain = window.rebalance(onThree.queue,
        onThree.currentIndex + 1, onThree.pending,
        recent: chronological, playedIds: played);
    expect(forwardAgain.queue[forwardAgain.currentIndex].id, song(4).id);
    expect(forwardAgain.queue[forwardAgain.currentIndex + 1].id, song(5).id);
  });

  test('10 pistas pasadas y 20 futuras no se duplican', () {
    final queue = [for (var i = 0; i < 52; i++) song(i)];
    final chronological = queue.sublist(0, 11);
    final snap = window.rebalance(queue, 10, [],
        recent: chronological,
        playedIds: chronological.map((t) => t.id).toSet());
    expect(snap.queue.length, 31);
    expect(snap.currentIndex, 10);
    expect(snap.queue.first.id, song(0).id);
    expect(snap.queue[10].id, song(10).id);
    expect(snap.queue[30].id, song(30).id);
    expect(snap.queue.map((t) => t.id).toSet().length, 31);
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
