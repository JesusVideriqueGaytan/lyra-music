/// Recomendaciones verificables: artistas elegidos localmente y resultados
/// musicales devueltos por el catálogo remoto. Nunca crea canciones ficticias.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/core/settings/app_settings_controller.dart';
import 'package:lyra_music/features/home/domain/recommendation_engine.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';

final recommendationsProvider = FutureProvider.family<List<YtMusicSong>, String>((ref, artist) async {
  // Solo una búsqueda por artista, cacheada por Riverpod. No enviamos al
  // proveedor datos del historial ni reproducciones individuales.
  final songs = await const YtMusicClient().search(artist);
  return songs.where((song) => hasKnownArtist(song.artist)).take(18).toList();
});

/// Repara hasta cuatro entradas antiguas del historial por ID de vídeo.
/// Nunca asigna un artista por simple coincidencia de título: exige el
/// mismo videoId devuelto por el catálogo. Solo se ejecuta una vez por sesión.
final historyMetadataRepairProvider = FutureProvider<void>((ref) async {
  final collection = ref.read(musicCollectionProvider);
  final incomplete = collection.history.where((t) =>
    t.id.startsWith('ytmusic:') && !hasKnownArtist(t.artist)).take(4);
  final client = const YtMusicClient();
  for (final track in incomplete) {
    try {
      final search = await client.search(track.title);
      final expectedId = track.id.substring('ytmusic:'.length);
      for (final match in search) {
        if (match.videoId != expectedId || !hasKnownArtist(match.artist)) continue;
        ref.read(musicCollectionProvider.notifier).enrichTracks([Track(
          id: track.id, title: track.title, artist: match.artist,
          album: match.album, duration: match.duration,
          artistId: match.artistId, artworkUrl: match.thumbnail,
          filePath: 'https://music.youtube.com/watch?v=$expectedId',
        )]);
        break;
      }
    } catch (_) { /* Sin conexión: mantener historial previo. */ }
  }
});

class RecommendationsSection extends ConsumerWidget {
  const RecommendationsSection({super.key});

  Track _track(YtMusicSong song) => Track(
    id: 'ytmusic:${song.videoId}', title: song.title,
    artist: song.artist, album: song.album,
    filePath: 'https://music.youtube.com/watch?v=${song.videoId}',
    artworkUrl: song.thumbnail, artistId: song.artistId,
    duration: song.duration,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(appSettingsControllerProvider).recommendationsEnabled;
    final collection = ref.watch(musicCollectionProvider);
    final seed = recommendationSeed(collection);
    if (!enabled || seed == null) return const SizedBox.shrink();
    final results = ref.watch(recommendationsProvider(seed.artist));
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Te puede gustar',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Inspirado en lo que escuchas de ${seed.artist}',
            style: theme.textTheme.bodySmall),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading,
        const SizedBox(height: 12),
        results.when(
          loading: () => const SizedBox(
            height: 98, child: Center(child: LinearProgressIndicator())),
          error: (error, stack) => Card(child: ListTile(
            leading: const Icon(Icons.wifi_off_rounded),
            title: const Text('No se pudieron cargar sugerencias'),
            subtitle: const Text('Tu historial sigue guardado solo en este dispositivo.'),
            trailing: IconButton(
              tooltip: 'Reintentar', icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(recommendationsProvider(seed.artist)),
            ),
          )),
          data: (items) {
            final history = collection.records.keys.toSet();
            final unseen = items.where((s) => !history.contains('ytmusic:${s.videoId}'))
                .take(9).toList();
            if (unseen.isEmpty) return const Text('Todavía no hay sugerencias nuevas para este artista.');
            return SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: unseen.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final song = unseen[index];
                  final track = _track(song);
                  return SizedBox(
                    width: 152,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await ref.read(audioPlayerControllerProvider.notifier)
                            .playQueue([track]);
                        if (context.mounted) context.go('/player');
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrackArtwork(track: track, size: 140),
                          const SizedBox(height: 5),
                          Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge),
                          Text(track.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ]),
    );
  }
}
