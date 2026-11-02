import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';

void main() {
  test('analiza pistas de musicResponsiveListItemRenderer', () {
    final result = YtMusicClient.parseSongs({
      'contents': {
        'musicResponsiveListItemRenderer': {
          'playlistItemData': {'videoId': 'abc123'},
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
          'thumbnail': {
            'musicThumbnailRenderer': {
              'thumbnail': {
                'thumbnails': [
                  {'url': 'https://example.org/cover.jpg'},
                ],
              },
            },
          },
        },
      },
    });
    expect(result, hasLength(1));
    expect(result.single.videoId, 'abc123');
    expect(result.single.title, 'Canción de prueba');
    expect(result.single.artist, 'Artista de prueba');
    expect(result.single.thumbnail, 'https://example.org/cover.jpg');
  });

  test('analiza playlists de biblioteca', () {
    final result = YtMusicClient.parsePlaylists({
      'contents': [
        {
          'musicTwoRowItemRenderer': {
            'title': {
              'runs': [
                {'text': 'Mis canciones'},
              ],
            },
            'navigationEndpoint': {
              'browseEndpoint': {'browseId': 'VLPLtest123'},
            },
          },
        },
      ],
    });
    expect(result.single.id, 'PLtest123');
    expect(result.single.title, 'Mis canciones');
  });

  test('rechaza cabeceras sin sesión válida', () {
    expect(
      () => YtMusicBrowserSession.fromRequestHeaders(
        'accept: application/json\nuser-agent: local-test',
      ),
      throwsFormatException,
    );
  });

  test('acepta sesión de navegador sin exponer cookies en la UI', () {
    final session = YtMusicBrowserSession.fromRequestHeaders(
      'cookie: __Secure-3PAPISID=valor_de_prueba; SID=otra_prueba\n'
      'x-goog-authuser: 1',
    );
    expect(session.authUser, '1');
    expect(session.authorization, startsWith('SAPISIDHASH '));
  });
}
