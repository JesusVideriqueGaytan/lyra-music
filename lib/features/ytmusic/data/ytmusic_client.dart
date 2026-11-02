/// Proveedor experimental de YouTube Music (InnerTube WEB_REMIX).
/// No usa servidor de Lyra ni solicita contraseñas. La sesión, si la hay,
/// permanece exclusivamente en memoria y nunca debe escribirse en logs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class YtMusicSong {
  const YtMusicSong({
    required this.videoId,
    required this.title,
    required this.artist,
    this.album = 'YouTube Music',
    this.thumbnail,
    this.artistId,
  });
  final String videoId;
  final String title;
  final String artist;
  final String album;
  final String? thumbnail;
  final String? artistId;
}

class YtMusicArtist {
  const YtMusicArtist({required this.id, required this.name, this.thumbnail});
  final String id;
  final String name;
  final String? thumbnail;
}

class YtMusicRelease {
  const YtMusicRelease({
    required this.id,
    required this.title,
    this.thumbnail,
    this.subtitle = '',
  });
  final String id;
  final String title;
  final String? thumbnail;
  final String subtitle;
}

class YtMusicArtistCatalog {
  const YtMusicArtistCatalog({
    required this.name,
    this.thumbnail,
    required this.songs,
    required this.releases,
  });
  final String name;
  final String? thumbnail;
  final List<YtMusicSong> songs;
  final List<YtMusicRelease> releases;
}

class YtMusicSearchCatalog {
  const YtMusicSearchCatalog({required this.songs, required this.artists});
  final List<YtMusicSong> songs;
  final List<YtMusicArtist> artists;
}

class YtMusicPlaylist {
  const YtMusicPlaylist({
    required this.id,
    required this.title,
    this.thumbnail,
  });
  final String id;
  final String title;
  final String? thumbnail;
}

/// Cabeceras copiadas por el propietario de la sesión, desde su navegador.
/// Nunca se guardan en SharedPreferences ni se envían a servidores de Lyra.
class YtMusicBrowserSession {
  YtMusicBrowserSession._(this.cookie, this.authUser);
  final String cookie;
  final String authUser;

  factory YtMusicBrowserSession.fromRequestHeaders(String raw) {
    final headers = <String, String>{};
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final pos = line.indexOf(':');
      if (pos <= 0) continue;
      final key = line.substring(0, pos).trim().toLowerCase();
      if (key == 'cookie' || key == 'x-goog-authuser') {
        headers[key] = line.substring(pos + 1).trim();
      }
    }
    final cookie = headers['cookie'];
    if (cookie == null || cookie.isEmpty) {
      throw const FormatException(
        'No se encontraron cookies de la sesión. Copia las cabeceras de una petición de music.youtube.com.',
      );
    }
    // Hay cuentas donde el SAPISID solo aparece en la cookie segura.
    final cookies = parseCookiePairs(cookie);
    if (!cookies.containsKey('SAPISID') &&
        !cookies.containsKey('__Secure-3PAPISID') &&
        !cookies.containsKey('__Secure-1PAPISID')) {
      throw const FormatException(
        'Falta la cookie de autenticación SAPISID. Inicia sesión en music.youtube.com y vuelve a copiar las cabeceras.',
      );
    }
    return YtMusicBrowserSession._(cookie, headers['x-goog-authuser'] ?? '0');
  }

  static Map<String, String> parseCookiePairs(String raw) {
    final result = <String, String>{};
    for (final pair in raw.split(';')) {
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      result[pair.substring(0, index).trim()] = pair
          .substring(index + 1)
          .trim();
    }
    return result;
  }

  String get authorization {
    final cookies = parseCookiePairs(cookie);
    final sid =
        cookies['SAPISID'] ??
        cookies['__Secure-3PAPISID'] ??
        cookies['__Secure-1PAPISID']!;
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const origin = 'https://music.youtube.com';
    final input = '$timestamp $sid $origin';
    final signature = sha1.convert(utf8.encode(input)).toString();
    return 'SAPISIDHASH ${timestamp}_$signature';
  }
}

class YtMusicClient {
  const YtMusicClient();
  static const _origin = 'https://music.youtube.com';
  static const _defaultVersion = '1.20260327.10.00';
  static String? _clientVersion;
  static String? _apiKey;

  Future<void> _bootstrap() async {
    if (_clientVersion != null) return;
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await http.getUrl(Uri.parse(_origin));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final page = await response.transform(utf8.decoder).join();
      _clientVersion =
          RegExp(
            r'INNERTUBE_CONTEXT_CLIENT_VERSION["\\]*\s*:\s*["\\]*([^"\\]+)',
          ).firstMatch(page)?.group(1) ??
          _defaultVersion;
      _apiKey = RegExp(
        r'INNERTUBE_API_KEY["\\]*\s*:\s*["\\]*([^"\\]+)',
      ).firstMatch(page)?.group(1);
    } catch (_) {
      _clientVersion = _defaultVersion;
    } finally {
      http.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body, {
    YtMusicBrowserSession? session,
  }) async {
    await _bootstrap();
    final uri = Uri.https('music.youtube.com', '/youtubei/v1/$endpoint', {
      'prettyPrint': 'false',
      if (_apiKey != null) 'key': _apiKey!,
    });
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await http
          .postUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.headers.set('Origin', _origin);
      request.headers.set(HttpHeaders.refererHeader, '$_origin/');
      request.headers.set('X-YouTube-Client-Name', '67');
      request.headers.set(
        'X-YouTube-Client-Version',
        _clientVersion ?? _defaultVersion,
      );
      if (session != null) {
        request.headers.set('Cookie', session.cookie);
        request.headers.set(
          HttpHeaders.authorizationHeader,
          session.authorization,
        );
        request.headers.set('X-Goog-AuthUser', session.authUser);
      }
      request.write(
        jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': _clientVersion ?? _defaultVersion,
              'hl': 'es',
              'gl': 'MX',
            },
          },
          ...body,
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        // Nunca mostrar ni registrar cabeceras privadas ni cookies.
        throw StateError(
          'YouTube Music respondió HTTP ${response.statusCode}. La sesión podría estar vencida.',
        );
      }
      final data = jsonDecode(await response.transform(utf8.decoder).join());
      if (data is! Map<String, dynamic>)
        throw const FormatException('Respuesta inesperada de YouTube Music.');
      return data;
    } finally {
      http.close(force: true);
    }
  }

  Future<List<YtMusicSong>> search(
    String query, {
    YtMusicBrowserSession? session,
  }) async {
    if (query.trim().isEmpty) return [];
    final data = await _post('search', {
      'query': query.trim(),
    }, session: session);
    return parseSongs(data);
  }

  Future<YtMusicSearchCatalog> searchCatalog(
    String query, {
    YtMusicBrowserSession? session,
  }) async {
    if (query.trim().isEmpty) {
      return const YtMusicSearchCatalog(songs: [], artists: []);
    }
    final data = await _post('search', {
      'query': query.trim(),
    }, session: session);
    return YtMusicSearchCatalog(
      songs: parseSongs(data),
      artists: parseArtists(data),
    );
  }

  Future<List<String>> getSearchSuggestions(String input) async {
    if (input.trim().length < 2) return [];
    final data = await _post('music/get_search_suggestions', {
      'input': input.trim(),
    });
    final results = <String>[];
    for (final suggestion in _findNamed(data, 'searchSuggestionRenderer')) {
      final value = _runs(suggestion['suggestion']).trim();
      if (value.isNotEmpty && !results.contains(value)) results.add(value);
      if (results.length >= 7) break;
    }
    return results;
  }

  Future<YtMusicArtistCatalog> getArtistCatalog(
    String artistId, {
    YtMusicBrowserSession? session,
  }) async {
    final data = await _post('browse', {
      'browseId': artistId,
    }, session: session);
    final headers = [
      ..._findNamed(data, 'musicImmersiveHeaderRenderer'),
      ..._findNamed(data, 'musicVisualHeaderRenderer'),
      ..._findNamed(data, 'musicDetailHeaderRenderer'),
    ];
    final head = headers.isEmpty ? <String, dynamic>{} : headers.first;
    final name = _runs(head['title']);
    return YtMusicArtistCatalog(
      name: name,
      thumbnail: _thumb(head) ?? _thumb(data['header']),
      songs: parseSongs(data),
      releases: parseArtistReleases(data),
    );
  }

  Future<List<YtMusicSong>> getAlbumSongs(
    String albumId, {
    YtMusicBrowserSession? session,
    String fallbackArtist = '',
    String? fallbackArtwork,
    String fallbackAlbum = '',
  }) async {
    if (!albumId.startsWith('MPRE') && !albumId.startsWith('OLAK')) {
      return [];
    }
    final data = await _post('browse', {'browseId': albumId}, session: session);
    return parseSongs(data)
        .map(
          (song) => YtMusicSong(
            videoId: song.videoId,
            title: song.title,
            artist: _invalidArtist(song.artist) && fallbackArtist.isNotEmpty
                ? fallbackArtist
                : song.artist,
            artistId: song.artistId,
            album: fallbackAlbum.isNotEmpty ? fallbackAlbum : song.album,
            thumbnail: fallbackArtwork ?? song.thumbnail,
          ),
        )
        .toList();
  }

  Future<List<YtMusicPlaylist>> getLibraryPlaylists(
    YtMusicBrowserSession session,
  ) async {
    final data = await _post('browse', {
      'browseId': 'FEmusic_liked_playlists',
    }, session: session);
    return parsePlaylists(data);
  }

  Future<List<YtMusicSong>> getPlaylistSongs(
    String id, {
    YtMusicBrowserSession? session,
  }) async {
    final clean = id.startsWith('VL') ? id : 'VL$id';
    final data = await _post('browse', {'browseId': clean}, session: session);
    return parseSongs(data);
  }

  /// Cola de temas relacionados: se obtiene del endpoint interno `next`.
  /// No requiere cuenta y nunca inventa resultados; puede fallar si cambia
  /// la respuesta de YouTube Music.
  Future<List<YtMusicSong>> getRadioSongs(
    String videoId, {
    YtMusicBrowserSession? session,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) return [];
    final data = await _post('next', {
      'videoId': videoId,
      'playlistId': 'RDAMVM$videoId',
      'enablePersistentPlaylistPanel': true,
      'isAudioOnly': true,
      'tunerSettingValue': 'AUTOMIX_SETTING_NORMAL',
      'params': 'wAEB',
    }, session: session);
    return parseSongs(
      data,
    ).where((song) => song.videoId != videoId).take(24).toList();
  }

  /// Canciones destacadas del artista en el orden del propio proveedor.
  /// La respuesta puede ser parcial; no fabricamos cifras de popularidad.
  Future<List<YtMusicSong>> getArtistSongs(
    String artistId, {
    YtMusicBrowserSession? session,
  }) async {
    if (!artistId.startsWith('UC') || artistId.length > 100) return [];
    final data = await _post('browse', {
      'browseId': artistId,
    }, session: session);
    final featured = parseSongs(data);
    // El panel de canciones suele tener un enlace 'Ver todo'. Probamos
    // ese listado completo cuando la respuesta incluye su browseId.
    for (final shelf in _findNamed(data, 'musicShelfRenderer')) {
      final heading = _runs(shelf['title']).toLowerCase();
      if (!['songs', 'canciones', 'titres', 'tracks'].any(heading.contains)) {
        continue;
      }
      for (final endpoint in _findNamed(
        shelf['bottomEndpoint'],
        'browseEndpoint',
      )) {
        final browseId = endpoint['browseId'];
        if (browseId is! String || browseId.isEmpty) continue;
        try {
          final full = await _post('browse', {
            'browseId': browseId,
          }, session: session);
          final tracks = parseSongs(full);
          if (tracks.length > featured.length) return tracks;
        } catch (_) {
          // Respuesta parcial o acceso no disponible: mostrar destacadas.
        }
      }
    }
    return featured;
  }

  static Iterable<Map<String, dynamic>> _findNamed(
    dynamic input,
    String target,
  ) sync* {
    if (input is Map) {
      for (final entry in input.entries) {
        if (entry.key == target && entry.value is Map<String, dynamic>) {
          yield entry.value as Map<String, dynamic>;
        }
        yield* _findNamed(entry.value, target);
      }
    } else if (input is List) {
      for (final item in input) {
        yield* _findNamed(item, target);
      }
    }
  }

  static String _runs(dynamic text) {
    if (text is String) return text;
    if (text is Map) {
      if (text['simpleText'] is String) return text['simpleText'] as String;
      if (text['runs'] is List) {
        return (text['runs'] as List)
            .whereType<Map>()
            .map((r) => r['text']?.toString() ?? '')
            .join();
      }
    }
    return '';
  }

  /// Recorre los contenedores de miniaturas usados por WEB_REMIX.
  /// Evita asumir que thumbnailRenderer siempre está en el nivel superior.
  /// Prefiere la imagen de mayor resolución que el proveedor devuelve.
  static String? _thumb(dynamic raw) {
    final candidates = <Map<String, dynamic>>[];
    void visit(dynamic value, int depth) {
      if (depth > 12) return;
      if (value is List) {
        for (final element in value) {
          visit(element, depth + 1);
        }
      } else if (value is Map) {
        final thumbnails = value['thumbnails'];
        if (thumbnails is List) {
          for (final item in thumbnails) {
            if (item is Map && item['url'] is String) {
              candidates.add(Map<String, dynamic>.from(item));
            }
          }
        }
        for (final entry in value.entries) {
          if (entry.key != 'thumbnails') visit(entry.value, depth + 1);
        }
      }
    }

    visit(raw, 0);
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final aw = (a['width'] as num?)?.toInt() ?? 0;
      final ah = (a['height'] as num?)?.toInt() ?? 0;
      final bw = (b['width'] as num?)?.toInt() ?? 0;
      final bh = (b['height'] as num?)?.toInt() ?? 0;
      return (bw * bh).compareTo(aw * ah);
    });
    final url = candidates.first['url'] as String;
    return url.startsWith('https://') ? url : null;
  }

  static String? _videoId(Map<String, dynamic> renderer) {
    final item = renderer['playlistItemData'];
    if (item is Map && item['videoId'] is String)
      return item['videoId'] as String;
    for (final endpoint in _findNamed(renderer, 'watchEndpoint')) {
      if (endpoint['videoId'] is String) return endpoint['videoId'] as String;
    }
    return renderer['videoId'] as String?;
  }

  static List<YtMusicArtist> parseArtists(Map<String, dynamic> data) {
    final result = <YtMusicArtist>[];
    final seen = <String>{};
    for (final item in _findNamed(data, 'musicResponsiveListItemRenderer')) {
      // Artist rows don't contain a watchEndpoint; never confuse a video
      // credited to an artist with an actual artist search result.
      if (_videoId(item) != null) continue;
      String? artistId;
      for (final browse in _findNamed(item, 'browseEndpoint')) {
        if ((browse['browseId'] as String? ?? '').startsWith('UC')) {
          artistId = browse['browseId'] as String;
          break;
        }
      }
      if (artistId == null || !seen.add(artistId)) continue;
      final cols = item['flexColumns'] as List?;
      final name = cols != null && cols.isNotEmpty && cols.first is Map
          ? _runs(
              (cols.first
                  as Map)['musicResponsiveListItemFlexColumnRenderer']?['text'],
            )
          : _runs(item['title']);
      if (name.isEmpty) continue;
      result.add(
        YtMusicArtist(id: artistId, name: name, thumbnail: _thumb(item)),
      );
    }
    return result;
  }

  static List<YtMusicRelease> parseArtistReleases(Map<String, dynamic> data) {
    final result = <YtMusicRelease>[];
    final seen = <String>{};
    for (final item in _findNamed(data, 'musicTwoRowItemRenderer')) {
      String? id;
      for (final endpoint in _findNamed(item, 'browseEndpoint')) {
        final candidate = endpoint['browseId'] as String? ?? '';
        if (candidate.startsWith('MPRE') || candidate.startsWith('OLAK')) {
          id = candidate;
          break;
        }
      }
      if (id == null || !seen.add(id)) continue;
      final title = _runs(item['title']);
      if (title.isEmpty) continue;
      result.add(
        YtMusicRelease(
          id: id,
          title: title,
          thumbnail: _thumb(item),
          subtitle: _runs(item['subtitle']),
        ),
      );
    }
    return result;
  }

  static bool _invalidArtist(String name) {
    final normalized = name.trim().toLowerCase();
    return normalized.isEmpty ||
        const {
          'video',
          'vídeo',
          'song',
          'canción',
          'music video',
          'artista desconocido',
          'unknown artist',
          'album',
          'álbum',
        }.contains(normalized) ||
        normalized.startsWith('vídeo •') ||
        normalized.startsWith('video •') ||
        normalized.startsWith('canción •');
  }

  static List<YtMusicSong> parseSongs(Map<String, dynamic> data) {
    final out = <YtMusicSong>[];
    final seen = <String>{};
    for (final kind in [
      'musicResponsiveListItemRenderer',
      'playlistPanelVideoRenderer',
    ]) {
      for (final item in _findNamed(data, kind)) {
        final id = _videoId(item);
        if (id == null || id.isEmpty || !seen.add(id)) continue;
        final columns = item['flexColumns'] as List?;
        final title =
            columns != null && columns.isNotEmpty && columns.first is Map
            ? _runs(
                (columns.first
                    as Map)['musicResponsiveListItemFlexColumnRenderer']?['text'],
              )
            : _runs(item['title']);
        final artist =
            columns != null && columns.length > 1 && columns[1] is Map
            ? _runs(
                (columns[1]
                    as Map)['musicResponsiveListItemFlexColumnRenderer']?['text'],
              )
            : _runs(item['longBylineText']);
        if (title.isEmpty) continue;
        String? artistNameFromChannel;
        String? artistId;
        final artistColumn =
            columns != null && columns.length > 1 && columns[1] is Map
            ? (columns[1] as Map)['musicResponsiveListItemFlexColumnRenderer']
            : item['longBylineText'];
        for (final endpoint in _findNamed(artistColumn, 'browseEndpoint')) {
          final browseId = endpoint['browseId'];
          if (browseId is String && browseId.startsWith('UC')) {
            artistId = browseId;
            break;
          }
        }
        // En algunos clientes el subtítulo empieza con "Vídeo" o "Canción".
        // Preferir el texto asociado al enlace del canal real del artista.
        if (artistColumn is Map && artistId != null) {
          final text = artistColumn['text'];
          if (text is Map && text['runs'] is List) {
            for (final run in text['runs'] as List) {
              if (run is! Map) continue;
              for (final browse in _findNamed(run, 'browseEndpoint')) {
                if (browse['browseId'] == artistId) {
                  artistNameFromChannel = run['text']?.toString().trim();
                  break;
                }
              }
              if (artistNameFromChannel != null) break;
            }
          }
        }
        final candidateParts = artist.split(RegExp(r'\s*•\s*'));
        final inferredArtist = candidateParts
            .where(
              (part) =>
                  !_invalidArtist(part) &&
                  !RegExp(
                    r'^\d+[,.]?\d*\s*([mMkK]|millones)?\s*(de )?visualizaciones$',
                    caseSensitive: false,
                  ).hasMatch(part.trim()) &&
                  !RegExp(r'^\d{4}$').hasMatch(part.trim()),
            )
            .toList();
        final cleanedArtist =
            artistNameFromChannel != null &&
                !_invalidArtist(artistNameFromChannel)
            ? artistNameFromChannel
            : inferredArtist.isNotEmpty
            ? inferredArtist.first.trim()
            : 'Artista desconocido';
        out.add(
          YtMusicSong(
            videoId: id,
            title: title,
            artist: cleanedArtist!,
            artistId: artistId,
            thumbnail: _thumb(item),
          ),
        );
        if (out.length >= 60) return out;
      }
    }
    return out;
  }

  static List<YtMusicPlaylist> parsePlaylists(Map<String, dynamic> data) {
    final out = <YtMusicPlaylist>[];
    final seen = <String>{};
    for (final item in _findNamed(data, 'musicTwoRowItemRenderer')) {
      String? id;
      for (final browse in _findNamed(item, 'browseEndpoint')) {
        final raw = browse['browseId'];
        if (raw is String && raw.startsWith('VL')) {
          id = raw.substring(2);
          break;
        }
      }
      if (id == null || !seen.add(id)) continue;
      out.add(
        YtMusicPlaylist(
          id: id,
          title: _runs(item['title']),
          thumbnail: _thumb(item),
        ),
      );
      if (out.length >= 100) break;
    }
    return out;
  }
}
