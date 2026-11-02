/// Conexión de escritorio a playlists de YouTube mediante OAuth oficial.
///
/// Alcance limitado: únicamente lectura de listas y sus metadatos; no obtiene
/// audio, no descarga vídeos, ni expone tokens fuera del proceso de Lyra.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

const youtubeDesktopClientId = String.fromEnvironment(
  'LYRA_GOOGLE_DESKTOP_CLIENT_ID',
);
const youtubeReadOnlyScope = 'https://www.googleapis.com/auth/youtube.readonly';

class YouTubePlaylist {
  const YouTubePlaylist({
    required this.id,
    required this.title,
    required this.videoCount,
    this.thumbnail,
  });

  final String id;
  final String title;
  final int videoCount;
  final String? thumbnail;

  factory YouTubePlaylist.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    final details = json['contentDetails'];
    return YouTubePlaylist(
      id: json['id'] is String ? json['id'] as String : '',
      title: _titleOf(snippet),
      videoCount: details is Map ? _intValue(details['itemCount']) : 0,
      thumbnail: _thumbnailOf(snippet),
    );
  }
}

class YouTubePlaylistVideo {
  const YouTubePlaylistVideo({
    required this.videoId,
    required this.title,
    required this.channel,
    this.thumbnail,
  });

  final String videoId;
  final String title;
  final String channel;
  final String? thumbnail;

  factory YouTubePlaylistVideo.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    final data = snippet is Map ? snippet : const <String, dynamic>{};
    final resource = data['resourceId'];
    final id = resource is Map && resource['videoId'] is String
        ? resource['videoId'] as String
        : '';
    return YouTubePlaylistVideo(
      videoId: id,
      title: _titleOf(snippet),
      channel: data['videoOwnerChannelTitle'] is String
          ? data['videoOwnerChannelTitle'] as String
          : 'YouTube',
      thumbnail: _thumbnailOf(snippet),
    );
  }
}

String _titleOf(Object? snippet) {
  if (snippet is! Map) return 'Sin título';
  final title = snippet['title'];
  return title is String && title.trim().isNotEmpty
      ? title.trim()
      : 'Sin título';
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String? _thumbnailOf(Object? snippet) {
  if (snippet is! Map) return null;
  final thumbs = snippet['thumbnails'];
  if (thumbs is! Map) return null;
  for (final key in ['medium', 'default', 'high']) {
    final image = thumbs[key];
    if (image is Map && image['url'] is String) {
      final uri = Uri.tryParse(image['url'] as String);
      if (uri != null && uri.scheme == 'https') return uri.toString();
    }
  }
  return null;
}

class YouTubeAccountState {
  const YouTubeAccountState({
    this.connecting = false,
    this.loading = false,
    this.connected = false,
    this.playlists = const [],
    this.videos = const [],
    this.selectedPlaylistId,
    this.error,
  });

  final bool connecting;
  final bool loading;
  final bool connected;
  final List<YouTubePlaylist> playlists;
  final List<YouTubePlaylistVideo> videos;
  final String? selectedPlaylistId;
  final String? error;
}

class YouTubeAccountController extends Notifier<YouTubeAccountState> {
  String? _accessToken;

  @override
  YouTubeAccountState build() {
    ref.onDispose(() => _accessToken = null);
    return const YouTubeAccountState();
  }

  Future<void> connect() async {
    if (state.connecting) return;
    if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      state = const YouTubeAccountState(
        error:
            'La autorización de Google para Android/iOS necesitará '
            'Google Sign-In nativo y se implementará por separado.',
      );
      return;
    }
    if (youtubeDesktopClientId.isEmpty) {
      state = const YouTubeAccountState(
        error:
            'Falta LYRA_GOOGLE_DESKTOP_CLIENT_ID. Crea un cliente OAuth '
            'de tipo Aplicación de escritorio en Google Cloud y habilita '
            'YouTube Data API v3.',
      );
      return;
    }

    state = const YouTubeAccountState(connecting: true);
    HttpServer? server;
    try {
      // Puerto efímero en 127.0.0.1, soportado por el flujo desktop Google.
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final redirect = 'http://127.0.0.1:${server.port}/';
      final verifier = _secureRandom(64);
      final challenge = base64Url
          .encode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', '');
      final nonce = _secureRandom(36);
      final callback = Completer<Uri>();

      server.listen((request) async {
        if (request.uri.path != '/' ||
            request.uri.queryParameters['state'] != nonce) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('Solicitud no válida.');
        } else {
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            '<!doctype html><html lang="es"><meta charset="utf-8">'
            '<title>Lyra</title><body>Autorización recibida. '
            'Puedes volver a Lyra.</body></html>',
          );
          if (!callback.isCompleted) callback.complete(request.uri);
        }
        await request.response.close();
      });

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': youtubeDesktopClientId,
        'response_type': 'code',
        'redirect_uri': redirect,
        'scope': youtubeReadOnlyScope,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': nonce,
      });
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw StateError('No se pudo abrir el navegador del sistema.');
      }
      final result = await callback.future.timeout(const Duration(minutes: 3));
      if (result.queryParameters.containsKey('error')) {
        throw StateError('Google rechazó la autorización.');
      }
      final code = result.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const FormatException('Falta el código de autorización.');
      }
      _accessToken = await _exchange(code, verifier, redirect);
      state = const YouTubeAccountState(connected: true, loading: true);
      await refreshPlaylists();
    } catch (e) {
      _accessToken = null;
      state = YouTubeAccountState(error: _readableError(e));
    } finally {
      await server?.close(force: true);
    }
  }

  String _secureRandom(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<String> _exchange(
    String code,
    String verifier,
    String redirect,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.https('oauth2.googleapis.com', '/token'),
      );
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
      request.write(
        Uri(
          queryParameters: {
            'client_id': youtubeDesktopClientId,
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': redirect,
            'code_verifier': verifier,
          },
        ).query,
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'Google rechazó la autorización '
          '(HTTP ${response.statusCode})',
        );
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final token = data['access_token'];
      if (token is! String || token.isEmpty) {
        throw const FormatException('Google no devolvió access_token.');
      }
      return token;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _get(Uri url) async {
    final token = _accessToken;
    if (token == null) throw StateError('La sesión está desconectada.');
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 401) {
        throw StateError('La sesión caducó. Desconecta y vuelve a conectar.');
      }
      if (response.statusCode != 200) {
        throw HttpException(
          'YouTube Data API rechazó la solicitud '
          '(HTTP ${response.statusCode}); revisa la API, los permisos y la cuota.',
        );
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> refreshPlaylists() async {
    if (_accessToken == null) return;
    state = YouTubeAccountState(
      connected: true,
      loading: true,
      playlists: state.playlists,
      selectedPlaylistId: state.selectedPlaylistId,
      videos: state.videos,
    );
    try {
      final playlists = <YouTubePlaylist>[];
      String? nextPage;
      // Límite para prototipo: 100 listas como máximo (2 páginas).
      do {
        final data = await _get(
          Uri.https('www.googleapis.com', '/youtube/v3/playlists', {
            'part': 'snippet,contentDetails',
            'mine': 'true',
            'maxResults': '50',
            if (nextPage != null) 'pageToken': nextPage,
          }),
        );
        final items = data['items'];
        if (items is List) {
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final playlist = YouTubePlaylist.fromJson(item);
              if (playlist.id.isNotEmpty) playlists.add(playlist);
            }
          }
        }
        nextPage = data['nextPageToken'] is String
            ? data['nextPageToken'] as String
            : null;
      } while (nextPage != null && playlists.length < 100);
      state = YouTubeAccountState(connected: true, playlists: playlists);
    } catch (e) {
      state = YouTubeAccountState(
        connected: true,
        playlists: state.playlists,
        error: _readableError(e),
      );
    }
  }

  Future<void> loadPlaylist(String id) async {
    if (_accessToken == null || state.loading) return;
    state = YouTubeAccountState(
      connected: true,
      loading: true,
      playlists: state.playlists,
      selectedPlaylistId: id,
    );
    try {
      final data = await _get(
        Uri.https('www.googleapis.com', '/youtube/v3/playlistItems', {
          'part': 'snippet',
          'playlistId': id,
          'maxResults': '50',
        }),
      );
      final items = data['items'];
      final videos = <YouTubePlaylistVideo>[];
      if (items is List) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            videos.add(YouTubePlaylistVideo.fromJson(item));
          }
        }
      }
      state = YouTubeAccountState(
        connected: true,
        playlists: state.playlists,
        selectedPlaylistId: id,
        videos: videos,
      );
    } catch (e) {
      state = YouTubeAccountState(
        connected: true,
        playlists: state.playlists,
        selectedPlaylistId: id,
        error: _readableError(e),
      );
    }
  }

  void closePlaylist() {
    state = YouTubeAccountState(
      connected: state.connected,
      playlists: state.playlists,
    );
  }

  void disconnect() {
    _accessToken = null;
    state = const YouTubeAccountState();
  }

  String _readableError(Object e) {
    if (e is TimeoutException) {
      return 'Tiempo de espera agotado. Intenta conectar nuevamente.';
    }
    // No exponer posibles parámetros con códigos OAuth en mensajes públicos.
    return e is HttpException || e is StateError || e is FormatException
        ? '$e'
        : 'No se pudo conectar o consultar YouTube. Comprueba tu conexión.';
  }
}

final youtubeAccountProvider =
    NotifierProvider<YouTubeAccountController, YouTubeAccountState>(
      YouTubeAccountController.new,
    );
