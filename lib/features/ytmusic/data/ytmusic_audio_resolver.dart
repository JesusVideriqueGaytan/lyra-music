/// Resolución experimental de flujos. No guarda audio ni URL firmadas.
/// Verifica que un enlace realmente entregue bytes antes de dárselo a MPV.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'ytmusic_client.dart';

/// Enlace efímero más cabeceras específicas de ese flujo.
class ResolvedAudioStream {
  const ResolvedAudioStream(this.uri, {this.headers = const {}});
  final Uri uri;
  final Map<String, String> headers;
}

class UnavailableAudioException implements Exception {
  const UnavailableAudioException(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

/// Convierte un estado HTTP en una explicación sin mostrar tokens ni URLs.
String audioHttpFailureMessage(int status) => switch (status) {
  401 => 'El origen del audio requiere iniciar sesión.',
  403 =>
    'El servidor rechazó el audio (HTTP 403). Puede requerir un token de reproducción o haber cambiado su sistema.',
  404 || 410 => 'Este archivo de audio ya no está disponible.',
  429 => 'El proveedor limitó temporalmente las solicitudes (HTTP 429).',
  >= 500 => 'El servidor del proveedor no está disponible (HTTP $status).',
  _ => 'No se pudo acceder al flujo de audio (HTTP $status).',
};

class YtMusicAudioResolver {
  const YtMusicAudioResolver();

  static const _timeout = Duration(seconds: 9);
  static const _desktopTimeout = Duration(seconds: 25);

  /// Un éxito HTTP 200/206 no garantiza reproducción, pero descarta enlaces
  /// claramente rechazados antes de abrir MPV. Usa Range para evitar bajar
  /// el archivo completo y cancela la respuesta inmediatamente.
  Future<int> probe(ResolvedAudioStream stream) async {
    final http = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await http.getUrl(stream.uri).timeout(_timeout);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      for (final e in stream.headers.entries) {
        if (!e.key.contains('\n') && !e.value.contains('\n')) {
          request.headers.set(e.key, e.value);
        }
      }
      final response = await request.close().timeout(_timeout);
      final status = response.statusCode;
      await response.detachSocket().then((s) => s.destroy()).timeout(_timeout);
      return status;
    } finally {
      http.close(force: true);
    }
  }

  /// youtube_explode_dart puede devolver URLs que el CDN rechaza por tokens.
  /// Probamos hasta tres variantes antes de pasar al segundo adaptador.
  Future<ResolvedAudioStream> _fromExplode(
    String videoId, {
    bool alternativeClient = false,
  }) async {
    final yt = YoutubeExplode();
    try {
      final manifest = alternativeClient
          ? await yt.videos.streams.getManifest(
              videoId,
              ytClients: [YoutubeApiClient.androidVr, YoutubeApiClient.safari],
            )
          : await yt.videos.streams.getManifest(videoId);
      final candidates = manifest.audioOnly.toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
      if (candidates.isEmpty) {
        throw const UnavailableAudioException(
          'No hay un flujo de audio para esta canción.',
        );
      }
      var status = 0;
      for (final info in candidates.take(3)) {
        final stream = ResolvedAudioStream(info.url);
        if (stream.uri.scheme != 'https') continue;
        try {
          status = await probe(stream);
          if (status == 200 || status == 206) return stream;
        } catch (_) {
          // El CDN o red puede rechazar una variante, probar otra.
        }
      }
      throw UnavailableAudioException(
        status == 0
            ? 'No se pudo verificar ningún flujo de audio.'
            : audioHttpFailureMessage(status),
      );
    } finally {
      yt.close();
    }
  }

  /// Para almacenamiento propio autorizado, solo adaptador Dart.
  /// No requiere herramientas instaladas ni usa cookies; no sortea restricciones.
  Future<ResolvedAudioStream> resolveWithoutExternal(String videoId) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
      throw const UnavailableAudioException('ID de contenido no válido.');
    }
    try {
      return await _fromExplode(videoId);
    } catch (_) {
      return _fromExplode(videoId, alternativeClient: true);
    }
  }

  /// Alternativa SOLO para escritorio con yt-dlp instalado por el usuario.
  /// No ejecuta shell, no usa cookies y no descarga ficheros. Usamos URL e
  /// indicadores de cabeceras devueltos por yt-dlp, nunca su salida en logs.
  Future<ResolvedAudioStream> _fromYtDlp(String videoId) async {
    if (!(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      throw const UnavailableAudioException(
        'El extractor alternativo está disponible solo en escritorio.',
      );
    }
    ProcessResult result;
    try {
      result = await Process.run('yt-dlp', [
        '--no-playlist',
        '--no-warnings',
        '--skip-download',
        '--no-config',
        '--dump-single-json',
        '-f',
        'bestaudio',
        'https://www.youtube.com/watch?v=$videoId',
      ]).timeout(_desktopTimeout);
    } on ProcessException {
      throw const UnavailableAudioException(
        'El extractor integrado no obtuvo un flujo válido. '
        'Puedes probar instalando yt-dlp desde el repositorio oficial de tu distribución.',
      );
    } on TimeoutException {
      throw const UnavailableAudioException(
        'La búsqueda del flujo tardó demasiado.',
      );
    }
    if (result.exitCode != 0) {
      throw const UnavailableAudioException(
        'Tampoco fue posible obtener un flujo con el extractor alternativo. '
        'El proveedor puede haber restringido la canción.',
      );
    }
    try {
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final uri = Uri.tryParse(json['url'] as String? ?? '');
      if (uri == null || uri.scheme != 'https') {
        throw const FormatException('URL inválida');
      }
      final headers = <String, String>{};
      final raw = json['http_headers'];
      if (raw is Map) {
        for (final item in raw.entries) {
          final key = item.key.toString();
          final value = item.value.toString();
          if (const [
            'User-Agent',
            'Referer',
            'Origin',
            'Accept',
            'Accept-Language',
          ].any((allowed) => allowed.toLowerCase() == key.toLowerCase())) {
            headers[key] = value;
          }
        }
      }
      return ResolvedAudioStream(uri, headers: headers);
    } catch (_) {
      throw const UnavailableAudioException(
        'El extractor devolvió información incompleta.',
      );
    }
  }

  /// En escritorio preferimos el extractor actualizado del sistema, cuando
  /// exista. El adaptador Dart permanece como respaldo y como ruta móvil.
  /// Ninguna estrategia garantiza acceso a flujos con restricciones del origen.
  Future<ResolvedAudioStream> resolve(YtMusicSong song) async {
    if (!RegExp(r'^[\w-]{11}$').hasMatch(song.videoId)) {
      throw const UnavailableAudioException('ID de canción no válido.');
    }
    final failures = <String>[];
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      try {
        final extracted = await _fromYtDlp(song.videoId);
        final status = await probe(extracted);
        if (status == 200 || status == 206) return extracted;
        failures.add(audioHttpFailureMessage(status));
      } catch (e) {
        failures.add(
          e is UnavailableAudioException
              ? e.reason
              : 'El extractor de escritorio no obtuvo audio utilizable.',
        );
      }
    }
    try {
      return await _fromExplode(song.videoId);
    } catch (e) {
      failures.add(
        e is UnavailableAudioException
            ? e.reason
            : 'No fue posible resolver la fuente primaria.',
      );
    }
    try {
      return await _fromExplode(song.videoId, alternativeClient: true);
    } catch (e) {
      failures.add(
        e is UnavailableAudioException
            ? e.reason
            : 'La fuente alternativa tampoco devolvió audio utilizable.',
      );
    }
    // Mantener mensajes breves y sin enlaces firmados, cookies o tokens.
    throw UnavailableAudioException(
      'No se encontró un flujo que el servidor permitiera reproducir. '
      '${failures.isNotEmpty ? failures.first : 'Origen no disponible.'}',
    );
  }
}
