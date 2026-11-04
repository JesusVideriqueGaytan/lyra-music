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

  test('recupera duración cuando el catálogo la facilita', () {
    final tracks = YtMusicClient.parseSongs({
      'musicResponsiveListItemRenderer': {
        'playlistItemData': {'videoId': 'abcdefghijk'},
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
        'fixedColumns': [
          {
            'musicResponsiveListItemFixedColumnRenderer': {
              'text': {
                'runs': [
                  {'text': '3:45'},
                ],
              },
            },
          },
        ],
      },
    });
    expect(tracks.single.duration, const Duration(minutes: 3, seconds: 45));
  });

  test('recupera duración desde flexColumns de resultados de búsqueda', () {
    final tracks = YtMusicClient.parseSongs({
      'musicResponsiveListItemRenderer': {
        'playlistItemData': {'videoId': 'abcdefghij9'},
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'Canción buscada'},
                ],
              },
            },
          },
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'Artista'},
                  {'text': ' • '},
                  {'text': '3:29'},
                ],
              },
            },
          },
        ],
      },
    });
    expect(tracks.single.duration, const Duration(minutes: 3, seconds: 29));
  });

  test('recupera duración del overlay del vídeo', () {
    final tracks = YtMusicClient.parseSongs({
      'playlistPanelVideoRenderer': {
        'videoId': 'abcdefghij8',
        'title': {
          'runs': [
            {'text': 'Canción de radio'},
          ],
        },
        'longBylineText': {
          'runs': [
            {'text': 'Artista'},
          ],
        },
        'thumbnailOverlay': {
          'thumbnailOverlayTimeStatusRenderer': {
            'text': {'simpleText': '4:07'},
          },
        },
      },
    });
    expect(tracks.single.duration, const Duration(minutes: 4, seconds: 7));
  });

  test('no confunde etiquetas de video con artistas', () {
    final songs = YtMusicClient.parseSongs({
      'musicResponsiveListItemRenderer': {
        'playlistItemData': {'videoId': 'abc12345678'},
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'Insomnia'},
                ],
              },
            },
          },
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'Vídeo'},
                  {'text': ' • '},
                  {'text': 'Eve'},
                  {'text': ' • '},
                  {'text': '20 M de visualizaciones'},
                ],
              },
            },
          },
        ],
      },
    });
    expect(songs.single.artist, 'Eve');
  });

  test('no confunde duración de una canción con el artista', () {
    final songs = YtMusicClient.parseSongs({
      'musicResponsiveListItemRenderer': {
        'playlistItemData': {'videoId': 'aBcDeFgHiJ1'},
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'Ghost Avenue'},
                ],
              },
            },
          },
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': '2:54'},
                ],
              },
            },
          },
        ],
        'longBylineText': {
          'runs': [
            {'text': 'Eve'},
          ],
        },
      },
    });
    expect(songs.single.artist, 'Eve');
  });

  test('si solo existe la duración no inventa un artista', () {
    final songs = YtMusicClient.parseSongs({
      'musicResponsiveListItemRenderer': {
        'playlistItemData': {'videoId': 'aBcDeFgHiJ2'},
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'Ghost Avenue'},
                ],
              },
            },
          },
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': '2:54'},
                ],
              },
            },
          },
        ],
      },
    });
    expect(songs.single.artist, 'Artista desconocido');
  });

  test('recupera miniaturas anidadas y elige la más grande', () {
    final releases = YtMusicClient.parseArtistReleases({
      'items': [
        {
          'musicTwoRowItemRenderer': {
            'title': {
              'runs': [
                {'text': 'Under Blue'},
              ],
            },
            'navigationEndpoint': {
              'browseEndpoint': {'browseId': 'MPREabc'},
            },
            'thumbnailRenderer': {
              'musicThumbnailRenderer': {
                'thumbnail': {
                  'thumbnails': [
                    {
                      'url': 'https://example.org/small.jpg',
                      'width': 64,
                      'height': 64,
                    },
                    {
                      'url': 'https://example.org/large.jpg',
                      'width': 544,
                      'height': 544,
                    },
                  ],
                },
              },
            },
          },
        },
      ],
    });
    expect(releases.single.thumbnail, 'https://example.org/large.jpg');
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
