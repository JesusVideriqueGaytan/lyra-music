/// Entrada visual a la cola interna de descargas de Lyra.
/// Nunca se solicita una carpeta al usuario; los archivos quedan en el
/// directorio privado de soporte de la aplicación, agrupados por artista.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lyra_music/features/downloads/download_manager.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

bool get supportsDesktopDownloads =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;

bool _authorizedThisSession = false;

Future<bool> _confirmIfNeeded(BuildContext context, int count) async {
  if (_authorizedThisSession) return true;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Guardar audio en Lyra'),
      content: Text(
        'Se añadirán $count canciones a Descargas. Lyra las '
        'organizará automáticamente por artista en su biblioteca interna, '
        'sin solicitar carpetas. Confirma que tienes permiso para descargar '
        'el contenido. No se evitan restricciones del proveedor.',
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
  if (accepted == true) _authorizedThisSession = true;
  return accepted == true;
}

Future<void> _enqueue(BuildContext context, List<Track> tracks) async {
  if (!supportsDesktopDownloads) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Las descargas internas están disponibles actualmente en escritorio.',
        ),
      ),
    );
    return;
  }
  final manager = LyraDownloadManager.instance;
  await manager.initialize();
  final compatible = tracks
      .where(
        (track) =>
            track.id.startsWith('ytmusic:') &&
            RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(track.id.substring(8)),
      )
      .toList();
  final needed = compatible
      .where((t) => !manager.isDownloaded(t.id) && !manager.isPending(t.id))
      .length;
  if (!context.mounted) return;
  if (needed == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Estas canciones ya están guardadas, en cola o no son compatibles.',
        ),
      ),
    );
    return;
  }
  if (!await _confirmIfNeeded(context, needed) || !context.mounted) return;
  final added = await manager.enqueue(compatible);
  if (!context.mounted) return;
  // No mostrar un SnackBar persistente sobre el mini reproductor.
  // El botón flotante de progreso se actualiza desde DownloadManager.
  if (added == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('No hay nuevas canciones que descargar.'),
      ),
    );
  }
}

Future<void> showPermittedDownloadDialog(BuildContext context, Track track) =>
    _enqueue(context, [track]);

Future<void> showAuthorizedPlaylistDownloadDialog(
  BuildContext context,
  List<Track> tracks, {
  required String playlistName,
}) => _enqueue(context, tracks);
