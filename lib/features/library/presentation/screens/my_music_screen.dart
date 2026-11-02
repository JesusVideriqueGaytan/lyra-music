/// Colección personal: favoritos, playlists e historial sin cuentas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/collection_actions.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';

class MyMusicScreen extends ConsumerWidget {
  const MyMusicScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(musicCollectionProvider);
    final controller = ref.read(musicCollectionProvider.notifier);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi música'),
        actions: [
          IconButton(
            tooltip: 'Estadísticas',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => context.go('/statistics'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Tu colección', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Favoritos, listas e historial guardados en este dispositivo.',
          ),
          const SizedBox(height: 22),
          _Section(
            title: 'Me gusta',
            trailing: '${collection.favorites.length} canciones',
          ),
          if (collection.favorites.isEmpty)
            const _Hint('Marca con ♥ las canciones que quieras guardar.')
          else
            _TrackList(tracks: collection.favorites.values.toList()),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Listas de reproducción',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Crear playlist',
                icon: const Icon(Icons.playlist_add_rounded),
                onPressed: () async {
                  final name = await requestPlaylistName(context);
                  if (name != null) controller.createPlaylist(name);
                },
              ),
            ],
          ),
          if (collection.playlists.isEmpty)
            const _Hint(
              'Todavía no hay listas. Crea una y agrega tus canciones favoritas.',
            ),
          for (final playlist in collection.playlists)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(playlist.name),
                subtitle: Text('${playlist.tracks.length} canciones'),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Opciones de playlist',
                  onSelected: (action) async {
                    if (action == 'rename') {
                      final value = await requestPlaylistName(
                        context,
                        initial: playlist.name,
                      );
                      if (value != null) {
                        controller.renamePlaylist(playlist.id, value);
                      }
                    } else if (action == 'delete') {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Eliminar playlist'),
                          content: Text(
                            '¿Eliminar “${playlist.name}”? Las canciones no se borrarán.',
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
                      if (yes == true) controller.removePlaylist(playlist.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text('Cambiar nombre'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar lista'),
                    ),
                  ],
                ),
                children: [
                  if (playlist.tracks.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => ref
                            .read(audioPlayerControllerProvider.notifier)
                            .playQueue(playlist.tracks),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Reproducir lista'),
                      ),
                    ),
                  for (final track in playlist.tracks)
                    ListTile(
                      leading: TrackArtwork(track: track, size: 44),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(track.artist),
                      onTap: () => ref
                          .read(audioPlayerControllerProvider.notifier)
                          .playQueue(
                            playlist.tracks,
                            startIndex: playlist.tracks.indexOf(track),
                          ),
                      trailing: IconButton(
                        tooltip: 'Quitar de la playlist',
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        onPressed: () => controller.removeFromPlaylist(
                          playlist.id,
                          track.id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Escuchadas recientemente',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (collection.history.isNotEmpty)
                TextButton(
                  onPressed: controller.clearHistory,
                  child: const Text('Limpiar'),
                ),
            ],
          ),
          if (collection.history.isEmpty)
            const _Hint(
              'Aquí aparecerán tus canciones al comenzar la reproducción.',
            )
          else
            _TrackList(tracks: collection.history.take(25).toList()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.trailing});
  final String title;
  final String trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      Text(trailing, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _TrackList extends ConsumerWidget {
  const _TrackList({required this.tracks});
  final List<Track> tracks;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      for (var i = 0; i < tracks.length; i++)
        ListTile(
          leading: TrackArtwork(track: tracks[i], size: 46),
          title: Text(
            tracks[i].title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            tracks[i].artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => ref
              .read(audioPlayerControllerProvider.notifier)
              .playQueue(tracks, startIndex: i),
          trailing: IconButton(
            tooltip: 'Guardar en colección',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () =>
                showTrackCollectionActions(context, ref, tracks[i]),
          ),
        ),
    ],
  );
}
