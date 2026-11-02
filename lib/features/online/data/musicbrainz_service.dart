/// Metadatos de MusicBrainz: solo búsqueda, no contiene enlaces de audio.
/// https://musicbrainz.org/doc/MusicBrainz_API
library;

import 'dart:convert';
import 'dart:io';

class MusicBrainzRecording {
  const MusicBrainzRecording({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;

  Uri get website => Uri.https('musicbrainz.org', '/recording/$id');

  factory MusicBrainzRecording.fromJson(Map<String, dynamic> json) {
    final credits = json['artist-credit'];
    final artists = <String>[];
    if (credits is List) {
      for (final credit in credits) {
        if (credit is Map) {
          final name =
              credit['name'] ??
              (credit['artist'] is Map
                  ? (credit['artist'] as Map)['name']
                  : null);
          if (name is String && name.trim().isNotEmpty)
            artists.add(name.trim());
        }
      }
    }
    final releases = json['releases'];
    String album = 'Álbum no identificado';
    if (releases is List && releases.isNotEmpty && releases.first is Map) {
      final title = (releases.first as Map)['title'];
      if (title is String && title.trim().isNotEmpty) album = title;
    }
    final millis = json['length'];
    final length = millis is num ? millis.toInt() : 0;
    return MusicBrainzRecording(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'Sin título'}',
      artist: artists.isEmpty ? 'Artista desconocido' : artists.join(', '),
      album: album,
      duration: Duration(milliseconds: length < 0 ? 0 : length),
    );
  }
}

class MusicBrainzService {
  const MusicBrainzService();

  // MusicBrainz solicita un User-Agent identificable y máximo ~1 req/seg.
  static DateTime? _lastRequest;
  static Future<void> _queue = Future<void>.value();

  static Future<void> _waitForSlot() {
    final job = _queue.then((_) async {
      if (_lastRequest != null) {
        final wait =
            const Duration(milliseconds: 1100) -
            DateTime.now().difference(_lastRequest!);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastRequest = DateTime.now();
    });
    _queue = job;
    return job;
  }

  Future<List<MusicBrainzRecording>> search(String text) async {
    final query = text.trim();
    if (query.isEmpty) return [];
    await _waitForSlot();
    final uri = Uri.https('musicbrainz.org', '/ws/2/recording/', {
      'query': query,
      'fmt': 'json',
      'limit': '20',
    });
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Lyra/0.3.3 (https://github.com/JesusVideriqueGaytan/lyra-music)',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'MusicBrainz respondió HTTP ${response.statusCode}',
        );
      }
      final raw = jsonDecode(await response.transform(utf8.decoder).join());
      if (raw is! Map<String, dynamic> || raw['recordings'] is! List) {
        throw const FormatException('Respuesta inesperada de MusicBrainz');
      }
      return (raw['recordings'] as List)
          .whereType<Map<String, dynamic>>()
          .map(MusicBrainzRecording.fromJson)
          .where((r) => r.id.isNotEmpty)
          .toList(growable: false);
    } finally {
      client.close(force: true);
    }
  }
}
