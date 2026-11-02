library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/downloads/desktop_download.dart';

/// Menú reutilizable para favoritos y listas. La sesión de usuario no es
/// necesaria para ninguna de estas funciones locales.
Future<void> showTrackCollectionActions(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final collection = ref.watch(musicCollectionProvider);
        final controller = ref.read(musicCollectionProvider.notifier);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(track.artist),
                ),
                ListTile(
                  leading: Icon(
                    collection.isFavorite(track)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                  title: Text(
                    collection.isFavorite(track)
                        ? 'Quitar de favoritos'
                        : 'Agregar a favoritos',
                  ),
                  onTap: () {
                    controller.toggleFavorite(track);
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: const Text('Guardar en playlist'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await showAddToPlaylistDialog(context, ref, track);
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Acciones contextuales ancladas al botón; evitan una hoja enorme en escritorio.
class TrackActionsMenu extends ConsumerWidget {
  const TrackActionsMenu({super.key, required this.track});
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(musicCollectionProvider).isFavorite(track);
    return PopupMenuButton<String>(
      tooltip: 'Opciones de la canción',
      icon: const Icon(Icons.more_horiz_rounded),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'favorite',
          child: ListTile(
            dense: true,
            leading: Icon(
              favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            ),
            title: Text(
              favorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'playlist',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.playlist_add_rounded),
            title: Text('Añadir a una lista'),
          ),
        ),
        if (supportsDesktopDownloads && track.id.startsWith('ytmusic:'))
          const PopupMenuItem(
            value: 'download',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.download_rounded),
              title: Text('Guardar audio autorizado'),
            ),
          ),
      ],
      onSelected: (action) {
        if (action == 'favorite') {
          ref.read(musicCollectionProvider.notifier).toggleFavorite(track);
        } else if (action == 'playlist') {
          showAddToPlaylistDialog(context, ref, track);
        } else if (action == 'download') {
          showPermittedDownloadDialog(context, track);
        }
      },
    );
  }
}

Future<void> showAddToPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final collection = ref.read(musicCollectionProvider);
  final controller = ref.read(musicCollectionProvider.notifier);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Guardar en una playlist'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (collection.playlists.isEmpty)
              const Text('Crea una playlist para guardar esta canción.'),
            for (final playlist in collection.playlists)
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(playlist.name),
                onTap: () {
                  controller.addToPlaylist(playlist.id, track);
                  Navigator.pop(dialogContext);
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.pop(dialogContext);
            final name = await requestPlaylistName(context);
            if (name == null) return;
            final id = controller.createPlaylist(name);
            if (id.isNotEmpty) controller.addToPlaylist(id, track);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nueva playlist'),
        ),
      ],
    ),
  );
}

Future<String?> requestPlaylistName(
  BuildContext context, {
  String initial = '',
}) async {
  final textController = TextEditingController(text: initial);
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(initial.isEmpty ? 'Nueva playlist' : 'Cambiar nombre'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Nombre de la playlist',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, textController.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  } finally {
    textController.dispose();
  }
}
