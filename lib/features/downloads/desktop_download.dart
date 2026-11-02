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
