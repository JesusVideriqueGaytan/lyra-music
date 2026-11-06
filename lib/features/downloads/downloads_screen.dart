/// Descargas en segundo plano dentro del proceso de Lyra, sin modal bloqueante.
library;

import 'package:flutter/material.dart';
import 'package:lyra_music/features/downloads/download_manager.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final manager = LyraDownloadManager.instance;
    final scheme = Theme.of(context).colorScheme;
    final content = AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final tasks = manager.tasks;
        final active = manager.activeCount;
        final completed = tasks
            .where((t) => t.phase == DownloadPhase.completed)
            .length;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [
                    scheme.primaryContainer,
                    scheme.surfaceContainerHigh,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.download_for_offline_rounded,
                    size: 56,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tu música sin conexión',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '$active pendientes · $completed guardadas',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Las canciones se organizan automáticamente por artista en '
              'el almacenamiento interno de Lyra. Las tareas continúan mientras '
              'la aplicación permanezca abierta.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (active > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: manager.cancelPending,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar pendientes'),
                ),
              ),
            const SizedBox(height: 14),
            if (tasks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(42),
                  child: Text('No tienes descargas todavía.'),
                ),
              ),
            for (final task in tasks)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      TrackArtwork(track: task.track, size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              task.track.displayArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _label(task),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            if (task.phase == DownloadPhase.downloading ||
                                task.phase == DownloadPhase.resolving)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: LinearProgressIndicator(
                                  value: task.progress,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (task.phase == DownloadPhase.completed)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_done_rounded,
                              color: scheme.primary,
                            ),
                            IconButton(
                              tooltip: 'Eliminar descarga',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Eliminar descarga'),
                                    content: Text(
                                      '¿Borrar el archivo local de «${task.track.title}»? '
                                      'La canción seguirá en tus playlists.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true)
                                  await manager.removeDownloaded(task.track.id);
                              },
                            ),
                          ],
                        )
                      else if (task.phase == DownloadPhase.failed ||
                          task.phase == DownloadPhase.cancelled)
                        IconButton(
                          tooltip: 'Reintentar',
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () => manager.retry(task.track.id),
                        )
                      else
                        IconButton(
                          tooltip: 'Cancelar descarga',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => manager.cancel(task.track.id),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Descargas')),
      body: content,
    );
  }

  String _label(LyraDownloadTask task) => switch (task.phase) {
    DownloadPhase.queued => 'En espera',
    DownloadPhase.resolving => 'Preparando audio…',
    DownloadPhase.downloading =>
      task.progress == null
          ? 'Descargando…'
          : 'Descargando ${(task.progress! * 100).round()} %',
    DownloadPhase.completed => 'Guardada en Lyra',
    DownloadPhase.cancelled => 'Cancelada',
    DownloadPhase.failed => task.message ?? 'Error al descargar',
  };
}
