import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';

void main() {
  test('identifica artistas sin confundirlos con canciones', () {
    final payload = <String, dynamic>{
      'contents': {
        'items': [
          {
            'musicResponsiveListItemRenderer': {
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'UC_artist_test'},
              },
              'flexColumns': [
                {
                  'musicResponsiveListItemFlexColumnRenderer': {
                    'text': {
                      'runs': [
                        {'text': 'Artista de prueba'},
                      ],
                    },
                  },
                },
              ],
            },
          },
          {
            'musicResponsiveListItemRenderer': {
              'playlistItemData': {'videoId': 'abcdefghijk'},
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'UC_artist_test'},
              },
              'flexColumns': [
                {
                  'musicResponsiveListItemFlexColumnRenderer': {
                    'text': {
                      'runs': [
                        {'text': 'Canción de prueba'},
                      ],
                    },
                  },
                },
              ],
            },
          },
        ],
      },
    };
    final artists = YtMusicClient.parseArtists(payload);
    expect(artists.length, 1);
    expect(artists.single.name, 'Artista de prueba');
    expect(artists.single.id, 'UC_artist_test');
  });

  test('solo clasifica lanzamientos de álbumes con browseId válido', () {
    final payload = <String, dynamic>{
      'contents': [
        {
          'musicTwoRowItemRenderer': {
            'title': {
              'runs': [
                {'text': 'Primer álbum'},
              ],
            },
            'navigationEndpoint': {
              'browseEndpoint': {'browseId': 'MPREb_123'},
            },
          },
        },
        {
          'musicTwoRowItemRenderer': {
            'title': {
              'runs': [
                {'text': 'Lista cualquiera'},
              ],
            },
            'navigationEndpoint': {
              'browseEndpoint': {'browseId': 'VL_PL123'},
            },
          },
        },
      ],
    };
    final albums = YtMusicClient.parseArtistReleases(payload);
    expect(albums.length, 1);
    expect(albums.single.title, 'Primer álbum');
  });
}
