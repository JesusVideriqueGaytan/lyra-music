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
  static const _desktopTimeout = Duration(seconds: 45);
  static const _cdnRetryDelay = Duration(seconds: 6);

  /// Un éxito HTTP 200/206 no garantiza reproducción, pero descarta enlaces
  /// claramente rechazados antes de abrir MPV. Usa Range para evitar bajar
  /// el archivo completo y cancela la respuesta inmediatamente.
  Future<int> probe(ResolvedAudioStream stream) async {
    final http = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await http.getUrl(stream.uri).timeout(_timeout);
      // Mismo rango de 10 KiB empleado por `yt-dlp --test`.
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-10239');
      for (final e in stream.headers.entries) {
        if (!e.key.contains('\n') && !e.value.contains('\n')) {
          request.headers.set(e.key, e.value);
        }
      }
      final response = await request.close().timeout(_timeout);
      final status = response.statusCode;
      // El estado HTTP no basta: algunos CDN confirman la cabecera pero
      // cortan la respuesta antes del primer byte. Leer solo el primer
      // fragmento Range y cerrar después evita darlo por reproducible.
      if (status == 200 || status == 206) {
        final bytes = await response.first.timeout(_timeout);
        if (bytes.isEmpty) {
          throw const UnavailableAudioException(
            'El servidor respondió sin entregar audio.',
          );
        }
      }
      return status;
    } finally {
      http.close(force: true);
    }
  }

  /// Algunos enlaces recién emitidos por googlevideo.com responden 403
  /// durante sus primeros segundos, aunque luego entregan audio. Antes de
  /// descartarlos, reintentamos UNA vez la misma URL y con las mismas
  /// cabeceras. No generamos otra URL y no repetimos el reintento en bucle.
  Future<int> probeWithStartupRetry(ResolvedAudioStream stream) async {
    final firstStatus = await probe(stream);
    final host = stream.uri.host.toLowerCase();
    final isGoogleVideo =
        host == 'googlevideo.com' || host.endsWith('.googlevideo.com');
    if (firstStatus != 403 || !isGoogleVideo) return firstStatus;
    await Future<void>.delayed(_cdnRetryDelay);
    return probe(stream);
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
  Future<ResolvedAudioStream> _fromYtDlp(
    String videoId, {
    String? playerClient,
  }) async {
    if (!(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      throw const UnavailableAudioException(
        'El extractor alternativo está disponible solo en escritorio.',
      );
    }
    ProcessResult result;
    try {
      result = await Process.run('yt-dlp', [
        '--no-playlist', '--no-warnings', '--skip-download',
        '--dump-single-json', '-f', 'bestaudio',
        // Respetar la configuración local de yt-dlp para permitir los
        // complementos y proveedores de tokens elegidos por el usuario.
        // mweb es una segunda prueba opcional: en
        // muchos casos necesita un proveedor de PO Token configurado aparte.
        if (playerClient != null) ...[
          '--extractor-args',
          'youtube:player_client=$playerClient',
        ],
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
            'Sec-Fetch-Mode',
            'Sec-Fetch-Dest',
            'Sec-Fetch-Site',
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
      // Estrategias independientes, no reutilizar una URL rechazada.
      // yt-dlp es OPCIONAL: la ruta Dart continúa disponible sin él.
      for (final playerClient in <String?>[null, 'mweb']) {
        try {
          final extracted = await _fromYtDlp(
            song.videoId,
            playerClient: playerClient,
          );
          final status = await probeWithStartupRetry(extracted);
          if (status == 200 || status == 206) return extracted;
          failures.add(audioHttpFailureMessage(status));
        } catch (e) {
          failures.add(
            e is UnavailableAudioException
                ? e.reason
                : 'El extractor de escritorio no obtuvo audio utilizable.',
          );
          // Si el comando no existe, el segundo intento también fallaría.
          if (e is UnavailableAudioException &&
              e.reason.startsWith('El extractor integrado no obtuvo'))
            break;
        }
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
      'No se encontró un flujo de audio aceptado por el servidor. '
      '${failures.any((f) => f.contains('403')) ? 'La fuente puede requerir un PO Token o estar restringida. ' : ''}'
      '${failures.isNotEmpty ? failures.first : 'Origen no disponible.'}',
    );
  }
}
