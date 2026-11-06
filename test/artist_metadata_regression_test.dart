import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/core/metadata/artist_name.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';

void main() {
  test('nunca presenta vistas, duración ni el año como artista', () {
    for (final invalid in [
      '2:54', '2024', '20 M de visualizaciones', '2,1 M reproducciones',
      '3.4K views', 'Vídeo', 'Official Audio', 'Artista desconocido',
    ]) {
      expect(isUsableArtistName(invalid), isFalse, reason: invalid);
      expect(hasKnownArtist(invalid), isFalse, reason: invalid);
      final track = Track(id: 'ytmusic:abc123', title: 'Prueba',
        artist: invalid, album: '', filePath: 'https://example.com');
      expect(track.displayArtist, 'Artista desconocido');
    }
  });

  test('conserva nombres reales internacionales', () {
    for (final name in ['Eve', '米津玄師', '백예린', 'Kenshi Yonezu',
        'Mrs. GREEN APPLE', 'No, No, No', '100 gecs']) {
      expect(isUsableArtistName(name), isTrue, reason: name);
    }
  });

  test('prioriza autor real después de etiqueta y estadísticas', () {
    final song = YtMusicClient.parseSongs({
      'musicResponsiveListItemRenderer': {
        'playlistItemData': {'videoId': 'AbCdEfGhIjK'},
        'flexColumns': [
          {'musicResponsiveListItemFlexColumnRenderer': {'text': {'runs': [
            {'text': 'KICK BACK'},
          ]}}},
          {'musicResponsiveListItemFlexColumnRenderer': {'text': {'runs': [
            {'text': 'Vídeo'}, {'text': ' • '},
            {'text': '20 M de visualizaciones'}, {'text': ' • '},
            {'text': '米津玄師'}, {'text': ' • '}, {'text': '3:13'},
          ]}}},
        ],
      },
    }).single;
    expect(song.artist, '米津玄師');
    expect(song.duration, const Duration(minutes: 3, seconds: 13));
  });

  test('repara la biblioteca solo con coincidencia exacta de ID', () {
    const missing = Track(id: 'ytmusic:123', title: 'Test',
      artist: '3.4K views', album: 'Álbum desconocido',
      filePath: 'https://example.com');
    const known = Track(id: 'ytmusic:123', title: 'Test', artist: 'Eve',
      album: 'Bunka', filePath: 'https://example.com',
      duration: Duration(minutes: 3));
    final updated = mergeTrackMetadata(missing, known);
    expect(updated.artist, 'Eve');
    expect(updated.duration, const Duration(minutes: 3));
    final differentId = known.copyWith(artist: 'Cantante');
    expect(mergeTrackMetadata(missing, Track(id: 'ytmusic:456',
      title: differentId.title, artist: differentId.artist,
      album: differentId.album, filePath: differentId.filePath)).artist,
      '3.4K views');
  });
}
