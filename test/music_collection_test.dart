import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/library/presentation/screens/listening_statistics_screen.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

void main() {
  const remote = Track(
    id: 'ytmusic:test_video_123',
    title: 'Prueba',
    artist: 'Artista',
    album: 'Álbum',
    filePath: 'https://rr.example.com/videoplayback?sig=expiring',
  );

  test('favoritos remotos nunca guardan enlaces temporales', () {
    final stored = persistentTrack(remote);
    expect(stored.filePath, 'https://music.youtube.com/watch?v=test_video_123');
    expect(stored.filePath, isNot(contains('sig=')));
    expect(stored.id, remote.id);
  });

  test('serializar playlists conserva referencias y orden', () {
    final playlist = LyraPlaylist(
      id: 'x',
      name: 'Mis favoritas',
      tracks: [remote],
    );
    final restored = LyraPlaylist.fromMap(playlist.toMap());
    expect(restored.name, 'Mis favoritas');
    expect(restored.tracks.single.id, remote.id);
    expect(restored.tracks.single.filePath, contains('music.youtube.com'));
  });

  test('estadísticas reflejan tiempo escuchado y reproducciones', () {
    final initial = ListeningRecord(track: remote, plays: 0, ms: 0);
    final updated = initial.withPlay(remote).withListen(remote, 65000);
    final restored = ListeningRecord.fromMap(updated.toMap());
    expect(restored.plays, 1);
    expect(restored.ms, 65000);
    expect(formatListeningTime(restored.ms), '1 min 5 s');
  });

  test('la fuente local no se altera al guardar', () {
    const local = Track(
      id: '/tmp/song.flac',
      title: 'Canción',
      artist: 'Autor',
      album: 'Local',
      filePath: '/tmp/song.flac',
    );
    expect(persistentTrack(local).filePath, '/tmp/song.flac');
  });
}
