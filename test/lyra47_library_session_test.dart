import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/player/data/playback_session_store.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

Track song(int n) => Track(
  id: 'ytmusic:${n.toString().padLeft(11, '0')}',
  title: 'Tema $n', artist: 'Artista $n', album: 'Álbum',
  artworkUrl: 'https://example.com/art$n.jpg',
  filePath: 'https://music.youtube.com/watch?v=${n.toString().padLeft(11, '0')}',
  duration: Duration(seconds: n + 100),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guardar un álbum evita canciones duplicadas y respeta su portada', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(musicCollectionProvider.notifier);
    final id = controller.createPlaylist('Álbum guardado');
    expect(controller.addTracksToPlaylist(id, [song(1), song(2)]), 2);
    expect(controller.addTracksToPlaylist(id, [song(1), song(3)]), 1);
    final playlist = container.read(musicCollectionProvider).playlists.single;
    expect(playlist.tracks.map((t) => t.id).toList(),
      [song(1).id, song(2).id, song(3).id]);
    expect(playlist.tracks.first.artworkUrl, song(1).artworkUrl);
  });

  test('Me gusta es playlist virtual protegida y compartida con favoritos', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(musicCollectionProvider.notifier);
    controller.addTracksToPlaylist(likedPlaylistId, [song(2), song(3)]);
    final state = container.read(musicCollectionProvider);
    expect(state.likedPlaylist.tracks.length, 2);
    expect(state.isFavorite(song(2)), isTrue);
    expect(state.playlists, isEmpty);
    controller.removePlaylist(likedPlaylistId);
    controller.renamePlaylist(likedPlaylistId, 'Renombrado');
    expect(container.read(musicCollectionProvider).likedPlaylist.name, 'Me gusta');
    expect(container.read(musicCollectionProvider).likedPlaylist.tracks.length, 2);
  });

  test('el historial guarda solo las últimas 30 canciones diferentes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(musicCollectionProvider.notifier);
    for (var i = 0; i < 36; i++) { controller.recordStarted(song(i)); }
    var history = container.read(musicCollectionProvider).history;
    expect(history.length, 30);
    expect(history.first.id, song(35).id);
    controller.recordStarted(song(12));
    history = container.read(musicCollectionProvider).history;
    expect(history.length, 30);
    expect(history.first.id, song(12).id);
  });

  test('la sesión conserva cola y posición sin persistir enlaces firmados', () {
    final signed = Track(id: song(1).id, title: 'Tema', artist: 'Eve',
      album: '', filePath: 'https://rr.googlevideo.com/videoplayback?sig=secreto');
    final snapshot = SavedPlaybackSession(queue: [signed, song(2)],
      index: 1, position: const Duration(seconds: 56),
      shuffle: true, repeat: 2, autoRadio: true);
    final encoded = jsonEncode(snapshot.toMap());
    expect(encoded, isNot(contains('googlevideo.com')));
    expect(encoded, isNot(contains('secreto')));
    final restored = SavedPlaybackSession.fromMap(
      Map<String, dynamic>.from(jsonDecode(encoded) as Map));
    expect(restored.queue.length, 2);
    expect(restored.index, 1);
    expect(restored.position.inSeconds, 56);
    expect(restored.shuffle, isTrue);
    expect(restored.autoRadio, isTrue);
    expect(restored.repeat, 2);
  });

  test('la sesión se restaura desde preferencias y puede limpiarse', () async {
    const store = PlaybackSessionStore();
    final snapshot = SavedPlaybackSession(queue: [song(2)], index: 0,
      position: const Duration(seconds: 42), shuffle: false,
      repeat: 0, autoRadio: false);
    await store.save(snapshot);
    final restored = await store.load();
    expect(restored?.queue.single.id, song(2).id);
    expect(restored?.position.inSeconds, 42);
    await store.clear();
    expect(await store.load(), isNull);
  });
}
