/// Guardado directo desde Lyra de contenido cuya descarga está autorizada.
/// No requiere ejecutables externos. No elude DRM ni autenticación.
library;

import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_audio_resolver.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';

bool get supportsDesktopDownloads =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;

String _safeFileName(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
      .trim();
  final limited = cleaned.length > 110 ? cleaned.substring(0, 110) : cleaned;
  return limited.isEmpty ? 'Lyra audio' : limited;
}

Future<void> showPermittedDownloadDialog(
  BuildContext context,
  Track track,
) async {
  if (!supportsDesktopDownloads) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Guardar archivos desde Lyra aún no está disponible en móvil.',
        ),
      ),
    );
    return;
  }
  final id = track.id.startsWith('ytmusic:')
      ? track.id.substring('ytmusic:'.length)
      : '';
  if (!RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Guardar audio desde Lyra'),
      content: const Text(
        'Lyra puede guardar directamente un flujo cuando '
        'el servidor lo permite. Confirma que tienes autorización para descargar '
        'este contenido. Si el proveedor restringe el acceso, la descarga fallará. '
        'No se requieren aplicaciones adicionales.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Tengo permiso'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final folder = await getDirectoryPath(confirmButtonText: 'Guardar aquí');
  if (folder == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Preparando descarga en Lyra…')),
  );
  File? output;
  var startedWriting = false;
  HttpClient? client;
  try {
    // Mismo resolvedor que la reproducción: evita rutas divergentes donde
    // Lyra puede reproducir una pista pero la descarga consulta otra fuente.
    // No requiere herramientas externas; si están instaladas, el resolvedor
    // puede aprovecharlas como respaldo opcional.
    final stream = await const YtMusicAudioResolver().resolve(
      YtMusicSong(
        videoId: id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        thumbnail: track.artworkUrl,
      ),
    );
    final mime = stream.uri.queryParameters['mime'] ?? '';
    final ext = mime.contains('mp4')
        ? 'm4a'
        : mime.contains('mpeg')
        ? 'mp3'
        : 'webm';
    output = File(
      '$folder${Platform.pathSeparator}${_safeFileName(track.title)} [$id].$ext',
    );
    if (await output.exists())
      throw const FileSystemException('El archivo ya existe.');
    client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    final request = await client
        .getUrl(stream.uri)
        .timeout(const Duration(seconds: 15));
    for (final entry in stream.headers.entries) {
      if (!entry.key.contains('\n') && !entry.value.contains('\n')) {
        request.headers.set(entry.key, entry.value);
      }
    }
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    const maxBytes = 200 * 1024 * 1024;
    var bytes = 0;
    startedWriting = true;
    final sink = output.openWrite(mode: FileMode.writeOnly);
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes += chunk.length;
        if (bytes > maxBytes)
          throw const FileSystemException('Archivo demasiado grande');
        sink.add(chunk);
      }
      await sink.flush();
      if (bytes == 0) throw const FileSystemException('Respuesta vacía');
    } finally {
      await sink.close();
    }
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Audio guardado. Añade la carpeta a la biblioteca si deseas reproducirlo sin conexión.',
        ),
      ),
    );
  } catch (_) {
    if (startedWriting && output != null && await output.exists()) {
      await output.delete();
    }
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo descargar: el servidor rechazó el flujo o no fue posible guardar el archivo.',
        ),
      ),
    );
  } finally {
    client?.close(force: true);
  }
}

/// Descargas secuenciales y cancelables. No vuelve a convertir enlaces
/// efímeros en referencias persistentes; únicamente guarda archivos locales.
/// La autorización y disponibilidad del origen son responsabilidad del usuario
/// y del servidor, respectivamente. No elude protección de contenido.
Future<void> showAuthorizedPlaylistDownloadDialog(
  BuildContext context,
  List<Track> tracks, {
  required String playlistName,
}) async {
  if (!supportsDesktopDownloads) return;
  final compatible = tracks
      .where(
        (track) =>
            track.id.startsWith('ytmusic:') &&
            RegExp(
              r'^[a-zA-Z0-9_-]{11}$',
            ).hasMatch(track.id.substring('ytmusic:'.length)),
      )
      .toList();
  if (compatible.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Esta lista no tiene canciones remotas compatibles para guardar.',
        ),
      ),
    );
    return;
  }
  final authorized = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Descargar la playlist'),
      content: Text(
        'Se intentarán guardar ${compatible.length} canciones de '
        '«$playlistName», una por una. Confirma que tienes autorización '
        'para descargar esos contenidos. Algunos proveedores pueden '
        'rechazar el guardado aunque permitan reproducirlos.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Tengo permiso'),
        ),
      ],
    ),
  );
  if (authorized != true || !context.mounted) return;
  final folder = await getDirectoryPath(
    confirmButtonText: 'Guardar playlist aquí',
  );
  if (folder == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PlaylistDownloadProgress(
      tracks: compatible,
      folder: folder,
      title: playlistName,
    ),
  );
}

class _PlaylistDownloadProgress extends StatefulWidget {
  const _PlaylistDownloadProgress({
    required this.tracks,
    required this.folder,
    required this.title,
  });
  final List<Track> tracks;
  final String folder;
  final String title;
  @override
  State<_PlaylistDownloadProgress> createState() =>
      _PlaylistDownloadProgressState();
}

class _PlaylistDownloadProgressState extends State<_PlaylistDownloadProgress> {
  var _processed = 0;
  var _saved = 0;
  var _skipped = 0;
  var _failed = 0;
  var _done = false;
  var _cancelled = false;
  String _current = '';
  double? _fraction;
  HttpClient? _currentClient;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_run);
  }

  @override
  void dispose() {
    _cancelled = true;
    _currentClient?.close(force: true);
    super.dispose();
  }

  Future<void> _run() async {
    for (final track in widget.tracks) {
      if (_cancelled || !mounted) break;
      setState(() {
        _current = track.title;
        _fraction = null;
      });
      try {
        final result = await _save(track);
        if (result == 'saved') _saved++;
        if (result == 'exists') _skipped++;
      } catch (_) {
        if (!_cancelled) _failed++;
      }
      if (!mounted) break;
      setState(() => _processed++);
    }
    if (mounted) setState(() => _done = true);
  }

  Future<String> _save(Track track) async {
    final videoId = track.id.substring('ytmusic:'.length);
    final stream = await const YtMusicAudioResolver().resolve(
      YtMusicSong(
        videoId: videoId,
        title: track.title,
        artist: track.displayArtist,
        album: track.album,
        thumbnail: track.artworkUrl,
      ),
    );
    if (_cancelled) throw const FileSystemException('Cancelada');
    final mime = stream.uri.queryParameters['mime'] ?? '';
    final ext = mime.contains('mp4')
        ? 'm4a'
        : mime.contains('mpeg')
        ? 'mp3'
        : 'webm';
    final destination = File(
      '${widget.folder}${Platform.pathSeparator}'
      '${_safeFileName(track.title)} [$videoId].$ext',
    );
    if (await destination.exists()) return 'exists';
    final partial = File('${destination.path}.lyra-part');
    if (await partial.exists()) await partial.delete();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    _currentClient = client;
    try {
      final request = await client
          .getUrl(stream.uri)
          .timeout(const Duration(seconds: 20));
      for (final header in stream.headers.entries) {
        if (!header.key.contains('\n') && !header.value.contains('\n')) {
          request.headers.set(header.key, header.value);
        }
      }
      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('Audio no disponible: ${response.statusCode}');
      }
      // La respuesta parcial debe empezar en el primer byte. De lo contrario
      // podríamos guardar un fragmento que no sea reproducible.
      if (response.statusCode == 206) {
        final contentRange = response.headers.value('content-range');
        if (contentRange != null) {
          final match = RegExp(
            r'^bytes (\d+)-(\d+)/(\d+|\*)$',
          ).firstMatch(contentRange);
          if (match == null || match.group(1) != '0') {
            throw const HttpException('Fragmento incompleto');
          }
          final last = int.tryParse(match.group(2) ?? '');
          final total = int.tryParse(match.group(3) ?? '');
          if (last != null && total != null && last + 1 != total) {
            throw const HttpException(
              'El proveedor entregó un fragmento, no el archivo entero',
            );
          }
        }
      }
      final expected = response.contentLength;
      const maxBytes = 200 * 1024 * 1024;
      var bytes = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response.timeout(
          const Duration(seconds: 40),
        )) {
          if (_cancelled) throw const FileSystemException('Cancelada');
          bytes += chunk.length;
          if (bytes > maxBytes)
            throw const FileSystemException('Archivo demasiado grande');
          sink.add(chunk);
          if (expected > 0 && mounted && bytes % 131072 < chunk.length) {
            setState(
              () => _fraction = (bytes / expected).clamp(0.0, 1.0).toDouble(),
            );
          }
        }
        await sink.flush();
        if (bytes == 0 || (expected > 0 && bytes != expected)) {
          throw const FileSystemException('Respuesta incompleta');
        }
      } finally {
        await sink.close();
      }
      if (_cancelled) throw const FileSystemException('Cancelada');
      await partial.rename(destination.path);
      return 'saved';
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      client.close(force: true);
      if (identical(_currentClient, client)) _currentClient = null;
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_done ? 'Descargas terminadas' : 'Descargando playlist'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: widget.tracks.isEmpty
                ? 1
                : (_processed + (_fraction ?? 0)) / widget.tracks.length,
          ),
          const SizedBox(height: 10),
          Text('$_processed / ${widget.tracks.length} procesadas'),
          if (!_done)
            Text(
              _cancelled ? 'Cancelando…' : _current,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 12),
          Text(
            'Guardadas: $_saved  ·  Existentes: $_skipped  ·  Fallidas: $_failed',
          ),
          const SizedBox(height: 8),
          const Text('No se guarda contenido rechazado por el proveedor.'),
        ],
      ),
    ),
    actions: [
      if (!_done)
        TextButton(
          onPressed: _cancelled
              ? null
              : () {
                  setState(() => _cancelled = true);
                  _currentClient?.close(force: true);
                },
          child: const Text('Cancelar pendientes'),
        ),
      if (_done)
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
    ],
  );
}
