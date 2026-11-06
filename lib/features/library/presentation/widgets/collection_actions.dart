library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/downloads/desktop_download.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';

/// Acciones contextuales ancladas al botón; evitan una hoja enorme en escritorio.
class TrackActionsMenu extends ConsumerWidget {
  const TrackActionsMenu({super.key, required this.track, this.playlistId});
  final Track track;
  final String? playlistId;

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
        const PopupMenuItem(
          value: 'next',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.queue_play_next_rounded),
            title: Text('Reproducir a continuación'),
          ),
        ),
        if (playlistId != null)
          const PopupMenuItem(
            value: 'remove',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.remove_circle_outline_rounded),
              title: Text('Quitar de esta playlist'),
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
        } else if (action == 'next') {
          ref.read(audioPlayerControllerProvider.notifier).playNext(track);
        } else if (action == 'remove' && playlistId != null) {
          ref
              .read(musicCollectionProvider.notifier)
              .removeFromPlaylist(playlistId!, track.id);
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

/// La misma decisión de destino sirve para una canción, un álbum completo
/// o el catálogo accesible de un artista. Se mantiene privada y local.
Future<void> showSaveTracksToPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  List<Track> tracks, {
  required String suggestedName,
}) async {
  if (tracks.isEmpty) return;
  final collection = ref.read(musicCollectionProvider);
  final controller = ref.read(musicCollectionProvider.notifier);
  Future<void> save(String id) async {
    final added = controller.addTracksToPlaylist(id, tracks);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          added == 0
              ? 'Todas estas canciones ya estaban guardadas.'
              : '$added canciones añadidas a la lista.',
        ),
      ),
    );
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Guardar ${tracks.length} canciones'),
      content: SizedBox(
        width: 380,
        height: 320,
        child: ListView(
          children: [
            ListTile(
              leading: Icon(Icons.favorite_rounded),
              title: Text('Me gusta'),
              subtitle: Text('Playlist especial de canciones favoritas'),
              onTap: () {
                Navigator.pop(dialogContext);
                save(likedPlaylistId);
              },
            ),
            for (final playlist in collection.playlists)
              ListTile(
                leading: playlist.tracks.isNotEmpty
                    ? TrackArtwork(track: playlist.tracks.first, size: 42)
                    : const Icon(Icons.queue_music_rounded),
                title: Text(playlist.name),
                subtitle: Text('${playlist.tracks.length} canciones'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  save(playlist.id);
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
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nueva playlist'),
          onPressed: () async {
            Navigator.pop(dialogContext);
            final name = await requestPlaylistName(
              context,
              initial: suggestedName,
              createNew: true,
            );
            if (name == null || name.trim().isEmpty) return;
            final id = controller.createPlaylist(name);
            if (id.isNotEmpty) await save(id);
          },
        ),
      ],
    ),
  );
}

Future<String?> requestPlaylistName(
  BuildContext context, {
  String initial = '',
  bool createNew = false,
}) async {
  final textController = TextEditingController(text: initial);
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          initial.isEmpty || createNew ? 'Nueva playlist' : 'Cambiar nombre',
        ),
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
