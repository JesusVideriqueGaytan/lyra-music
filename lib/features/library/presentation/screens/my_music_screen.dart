/// Colección privada: playlists primero, artistas seguidos y 30 pistas recientes.
/// «Me gusta» es una playlist virtual que comparte el estado de favoritos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyra_music/shared/widgets/lyra_section_banner.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/library/presentation/controllers/favorite_artists_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/collection_actions.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/ytmusic/presentation/widgets/song_actions.dart';

class MyMusicScreen extends ConsumerWidget {
  const MyMusicScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(musicCollectionProvider);
    final controller = ref.read(musicCollectionProvider.notifier);
    final artists = ref.watch(favoriteArtistsProvider).values.toList();
    final theme = Theme.of(context);
    final playlists = [collection.likedPlaylist, ...collection.playlists];
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (!embedded) ...[
          const LyraSectionBanner(icon: Icons.library_music_rounded,
            eyebrow: 'TU BIBLIOTECA', title: 'Tu colección',
            subtitle: 'Listas, artistas e historial privados.'),
          const SizedBox(height: 22),
        ],
        Row(children: [
          Expanded(child: Text('Listas de reproducción',
            style: theme.textTheme.titleLarge)),
          IconButton(tooltip: 'Crear playlist',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () async {
              final name = await requestPlaylistName(context);
              if (name != null && name.trim().isNotEmpty) {
                controller.createPlaylist(name);
              }
            }),
        ]),
        const SizedBox(height: 6),
        for (final playlist in playlists)
          Card(clipBehavior: Clip.antiAlias, child: ListTile(
            leading: playlist.tracks.isNotEmpty
              ? TrackArtwork(track: playlist.tracks.first, size: 48)
              : SizedBox(width: 48, height: 48,
                  child: Icon(playlist.id == likedPlaylistId
                    ? Icons.favorite_rounded : Icons.queue_music_rounded)),
            title: Text(playlist.name),
            subtitle: Text('${playlist.tracks.length} canciones'),
            trailing: playlist.id == likedPlaylistId
              ? const Icon(Icons.chevron_right_rounded)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  PopupMenuButton<String>(tooltip: 'Administrar playlist',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (action) async {
                      if (action == 'rename') {
                        final name = await requestPlaylistName(context,
                          initial: playlist.name);
                        if (name != null) controller.renamePlaylist(playlist.id, name);
                      } else if (action == 'delete') {
                        final approved = await showDialog<bool>(context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Eliminar playlist'),
                            content: Text('¿Eliminar «${playlist.name}»? '
                              'Las canciones seguirán en tu dispositivo.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                                child: const Text('Cancelar')),
                              FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
                                child: const Text('Eliminar')),
                            ],
                          ));
                        if (approved == true) controller.removePlaylist(playlist.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Cambiar nombre')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar lista')),
                    ],
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ]),
            onTap: () => context.push('/playlist/${playlist.id}'),
          )),
        const SizedBox(height: 24),
        Card(clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            initiallyExpanded: false,
            leading: const Icon(Icons.person_rounded),
            title: const Text('Artistas favoritos'),
            subtitle: Text('${artists.length} artistas'),
            children: [
              if (artists.isEmpty)
                const _Hint('Entra al perfil de un artista y pulsa Seguir artista.'),
              if (artists.isNotEmpty) SizedBox(
                height: (artists.length * 66.0).clamp(66.0, 320.0),
                child: ListView.builder(itemCount: artists.length,
                  itemBuilder: (context, index) {
                    final artist = artists[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: artist.thumbnail == null
                          ? null : NetworkImage(artist.thumbnail!),
                        child: artist.thumbnail == null
                          ? const Icon(Icons.person_outline_rounded) : null,
                      ),
                      title: Text(artist.name),
                      onTap: () => context.push('/artist', extra: Track(
                        id: 'artist:${artist.id}', title: artist.name,
                        artist: artist.name, album: '', artistId: artist.id,
                        filePath: '', artworkUrl: artist.thumbnail,
                      )),
                      trailing: IconButton(tooltip: 'Dejar de seguir',
                        icon: const Icon(Icons.favorite_rounded),
                        onPressed: () => ref.read(favoriteArtistsProvider.notifier)
                            .toggle(artist)),
                    );
                  }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Row(children: [
          Expanded(child: Text('Escuchadas recientemente',
            style: theme.textTheme.titleLarge)),
          if (collection.history.isNotEmpty)
            TextButton(onPressed: controller.clearHistory,
              child: const Text('Limpiar')),
        ]),
        if (collection.history.isEmpty)
          const _Hint('Aquí aparecerán tus últimas canciones reproducidas.')
        else
          for (var i = 0; i < collection.history.length && i < 30; i++)
            ListTile(
              leading: TrackArtwork(track: collection.history[i], size: 46),
              title: Text(collection.history[i].title, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              subtitle: Text(collection.history[i].displayArtist, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              onTap: () => ref.read(audioPlayerControllerProvider.notifier)
                  .playQueue(collection.history.take(30).toList(),
                    startIndex: i, enableRadio: false),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(songDurationLabel(collection.history[i].duration),
                  style: theme.textTheme.labelSmall),
                TrackActionsMenu(track: collection.history[i]),
              ]),
            ),
      ],
    );
    if (embedded) return content;
    return Scaffold(appBar: AppBar(title: const Text('Mi música')),
      body: content);
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(label, style: Theme.of(context).textTheme.bodyMedium));
}
