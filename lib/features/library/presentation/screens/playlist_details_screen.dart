/// Playlist personal en una pantalla propia. El estado continúa siendo
/// la única fuente de verdad de la colección (no se duplica ni sincroniza).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyra_music/features/downloads/desktop_download.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/collection_actions.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/ytmusic/presentation/widgets/song_actions.dart';

class PlaylistDetailsScreen extends ConsumerWidget {
  const PlaylistDetailsScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(musicCollectionProvider);
    LyraPlaylist? playlist;
    for (final candidate in collection.playlists) {
      if (candidate.id == playlistId) {
        playlist = candidate;
        break;
      }
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = playlist;
    if (current == null) {
      return Scaffold(appBar: AppBar(title: const Text('Playlist')),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min,
          children: [const Text('Esta lista ya no existe.'),
            TextButton(onPressed: () => context.go('/library'),
              child: const Text('Volver a Biblioteca'))])));
    }
    final songs = current.tracks;
    final durationSeconds = songs.where((t) => t.duration != null)
        .fold<int>(0, (total, t) => total + t.duration!.inSeconds);
    final knownCount = songs.where((t) => t.duration != null).length;
    final subtitle = '${songs.length} canciones'
        '${knownCount == 0 ? '' : ' · ${durationSeconds ~/ 60} min conocidos'}';

    Future<void> play({bool shuffle = false}) async {
      if (songs.isEmpty) return;
      final controller = ref.read(audioPlayerControllerProvider.notifier);
      if (shuffle) {
        final shuffled = [...songs]..shuffle();
        await controller.playQueue(shuffled);
      } else {
        await controller.playQueue(songs);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de reproducción'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Volver', onPressed: () => context.canPop()
              ? context.pop() : context.go('/library')),
      ),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(colors: [scheme.primaryContainer,
                scheme.surfaceContainerHigh])),
            child: Wrap(spacing: 20, runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
              ClipRRect(borderRadius: BorderRadius.circular(14),
                child: songs.isEmpty
                  ? Container(width: 106, height: 106,
                      color: scheme.surfaceContainerHigh,
                      child: const Icon(Icons.queue_music_rounded, size: 54))
                  : TrackArtwork(track: songs.first, size: 106)),
              SizedBox(width: (MediaQuery.sizeOf(context).width - 64)
                .clamp(180.0, 400.0).toDouble(), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TU PLAYLIST', style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.5, color: scheme.onPrimaryContainer)),
                const SizedBox(height: 8),
                Text(current.name, maxLines: 2,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer)),
                const SizedBox(height: 8),
                Text(subtitle, style: TextStyle(color: scheme.onPrimaryContainer)),
              ])),
            ]),
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(onPressed: songs.isEmpty ? null : () => play(),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Reproducir')),
            OutlinedButton.icon(onPressed: songs.isEmpty ? null : () => play(shuffle: true),
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Aleatorio')),
            OutlinedButton.icon(
              onPressed: songs.isEmpty || !supportsDesktopDownloads ? null
                  : () => showAuthorizedPlaylistDownloadDialog(context, songs,
                    playlistName: current.name),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Descargar todas')),
          ]),
          if (!supportsDesktopDownloads)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(
              'Las descargas por lotes están disponibles inicialmente en escritorio.',
              style: theme.textTheme.bodySmall)),
          const SizedBox(height: 20),
          Text('Canciones', style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (songs.isEmpty)
            const Padding(padding: EdgeInsets.all(24),
              child: Text('Esta lista todavía no tiene canciones.')),
          for (var index = 0; index < songs.length; index++)
            _PlaylistSongRow(
              track: songs[index], index: index, allTracks: songs,
              playlistId: current.id),
        ]),
      )),
    );
  }
}

class _PlaylistSongRow extends ConsumerWidget {
  const _PlaylistSongRow({required this.track, required this.index,
    required this.allTracks, required this.playlistId});
  final Track track;
  final int index;
  final List<Track> allTracks;
  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child:
      Material(color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13), child: ListTile(
          onTap: () => ref.read(audioPlayerControllerProvider.notifier)
            .playQueue(allTracks, startIndex: index),
          leading: TrackArtwork(track: track, size: 50),
          title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(track.displayArtist, maxLines: 1,
            overflow: TextOverflow.ellipsis),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(songDurationLabel(track.duration),
              style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 6),
            TrackActionsMenu(track: track, playlistId: playlistId),
          ]),
        ),
      ),
    );
  }
}
