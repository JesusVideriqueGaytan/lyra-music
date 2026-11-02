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
  });
  final String videoId;
  final String title;
  final String artist;
  final String album;
  final String? thumbnail;
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
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Respuesta inesperada de YouTube Music.');
      }
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

  static String? _thumb(dynamic raw) {
    if (raw is Map) {
      final thumbs = raw['thumbnails'];
      if (thumbs is List && thumbs.isNotEmpty) {
        final last = thumbs.last;
        if (last is Map && last['url'] is String) return last['url'] as String;
      }
      for (final key in [
        'thumbnail',
        'musicThumbnailRenderer',
        'croppedSquareThumbnailRenderer',
      ]) {
        final value = _thumb(raw[key]);
        if (value != null) return value;
      }
    }
    return null;
  }

  static String? _videoId(Map<String, dynamic> renderer) {
    final item = renderer['playlistItemData'];
    if (item is Map && item['videoId'] is String) {
      return item['videoId'] as String;
    }
    for (final endpoint in _findNamed(renderer, 'watchEndpoint')) {
      if (endpoint['videoId'] is String) return endpoint['videoId'] as String;
    }
    return renderer['videoId'] as String?;
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
        out.add(
          YtMusicSong(
            videoId: id,
            title: title,
            artist: artist.isEmpty ? 'Artista desconocido' : artist,
            thumbnail: _thumb(item['thumbnail']) ?? _thumb(item),
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
