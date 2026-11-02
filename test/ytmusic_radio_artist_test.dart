import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

void main() {
  test('interpreta la radio en el orden entregado por el servicio', () {
    final songs = YtMusicClient.parseSongs({
      'contents': {
        'singleColumnMusicWatchNextResultsRenderer': {
          'items': [
            {
              'playlistPanelVideoRenderer': {
                'videoId': '01234567890',
                'title': {
                  'runs': [
                    {'text': 'Original'},
                  ],
                },
                'longBylineText': {
                  'runs': [
                    {
                      'text': 'Artista A',
                      'navigationEndpoint': {
                        'browseEndpoint': {'browseId': 'UC_artist_A'},
                      },
                    },
                  ],
                },
              },
            },
            {
              'playlistPanelVideoRenderer': {
                'videoId': '12345678901',
                'title': {
                  'runs': [
                    {'text': 'Relacionado'},
                  ],
                },
                'longBylineText': {
                  'runs': [
                    {'text': 'Artista B'},
                  ],
                },
              },
            },
          ],
        },
      },
    });
    expect(songs.map((song) => song.title).toList(), [
      'Original',
      'Relacionado',
    ]);
    expect(songs.first.artistId, 'UC_artist_A');
  });

  test('artista de una canción sobrevive al almacenamiento', () {
    const track = Track(
      id: 'ytmusic:12345678901',
      title: 'Ejemplo',
      artist: 'Artista',
      artistId: 'UC_TEST123',
      album: 'Álbum',
      filePath: 'https://music.youtube.com/watch?v=12345678901',
    );
    expect(Track.fromMap(track.toMap()).artistId, 'UC_TEST123');
    final old = {...track.toMap()}..remove('artistId');
    expect(Track.fromMap(old).artistId, isNull);
  });
}
