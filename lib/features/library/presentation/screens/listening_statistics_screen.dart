/// Estadísticas locales: tiempo realmente escuchado y reproducciones.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';

String formatListeningTime(int milliseconds) {
  final d = Duration(milliseconds: milliseconds);
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes.remainder(60)} min';
  return '${d.inMinutes} min ${d.inSeconds.remainder(60)} s';
}

class ListeningStatisticsScreen extends ConsumerWidget {
  const ListeningStatisticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(musicCollectionProvider);
    final records = library.records.values.toList()
      ..sort((a, b) => b.ms.compareTo(a.ms));
    final byArtist = <String, int>{};
    for (final r in records) {
      byArtist[r.track.artist] = (byArtist[r.track.artist] ?? 0) + r.ms;
    }
    final artists = byArtist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            tooltip: 'Volver a Mi música',
            icon: const Icon(Icons.library_music_rounded),
            onPressed: () => context.go('/my-music'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Tu música en números',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Los datos se calculan en este dispositivo. No se envían a servidores.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                title: 'Tiempo escuchado',
                value: formatListeningTime(library.totalListeningMs),
                icon: Icons.schedule,
              ),
              _Metric(
                title: 'Reproducciones',
                value: '${library.totalPlays}',
                icon: Icons.play_arrow_rounded,
              ),
              _Metric(
                title: 'Canciones distintas',
                value: '${records.length}',
                icon: Icons.music_note_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Artistas más escuchados',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (artists.isEmpty)
            const ListTile(title: Text('Todavía no hay estadísticas')),
          for (final a in artists.take(10))
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(a.key),
              trailing: Text(formatListeningTime(a.value)),
            ),
          const SizedBox(height: 20),
          Text(
            'Canciones más escuchadas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final r in records.take(30))
            ListTile(
              leading: TrackArtwork(track: r.track, size: 48),
              title: Text(r.track.title),
              subtitle: Text('${r.track.artist} · ${r.plays} reproducciones'),
              trailing: Text(formatListeningTime(r.ms)),
              onTap: () => ref
                  .read(audioPlayerControllerProvider.notifier)
                  .playQueue([r.track]),
            ),
          const SizedBox(height: 20),
          if (records.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Borrar estadísticas locales'),
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Borrar estadísticas'),
                      content: const Text(
                        'Esta acción no afecta a favoritos ni playlists.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Borrar'),
                        ),
                      ],
                    ),
                  );
                  if (result == true) {
                    ref
                        .read(musicCollectionProvider.notifier)
                        .clearStatistics();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 195,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}
