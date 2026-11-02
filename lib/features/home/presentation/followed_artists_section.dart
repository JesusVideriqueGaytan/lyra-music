/// Perfiles recomendados desde escuchas reales. No convierte títulos o carátulas
/// de canciones en perfiles de artistas; se comprueba identidad con el catálogo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/library/presentation/controllers/favorite_artists_controller.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';

class FollowedArtistsSection extends ConsumerStatefulWidget {
  const FollowedArtistsSection({super.key});
  @override
  ConsumerState<FollowedArtistsSection> createState() =>
      _FollowedArtistsSectionState();
}

class _FollowedArtistsSectionState
    extends ConsumerState<FollowedArtistsSection> {
  String? _signature;
  Future<List<YtMusicArtist>>? _future;
  final _client = const YtMusicClient();

  Future<List<YtMusicArtist>> _profiles(
    List<Track> tracks,
    List<YtMusicArtist> followed,
  ) async {
    final confirmed = <String, YtMusicArtist>{};
    for (final artist in followed) {
      if (artist.id.startsWith('UC')) confirmed[artist.id] = artist;
    }
    for (final track in tracks.take(8)) {
      final name = track.artist.trim();
      if (name.isEmpty ||
          [
            'canción',
            'vídeo',
            'video',
            'artista desconocido',
          ].contains(name.toLowerCase()))
        continue;
      try {
        if (track.artistId != null && track.artistId!.startsWith('UC')) {
          final id = track.artistId!;
          if (!confirmed.containsKey(id)) {
            final profile = await _client.getArtistCatalog(id);
            final canonical = profile.name.trim();
            if (canonical.isNotEmpty) {
              confirmed[id] = YtMusicArtist(
                id: id,
                name: canonical,
                thumbnail: profile.thumbnail,
              );
            }
          }
          continue;
        }
        // Una coincidencia textual no basta: comprobar perfil oficial e ID.
        final catalog = await _client.searchCatalog(name);
        for (final artist in catalog.artists) {
          if (artist.name.trim().toLowerCase() == name.toLowerCase() &&
              artist.id.startsWith('UC')) {
            confirmed.putIfAbsent(artist.id, () => artist);
            break;
          }
        }
      } catch (_) {
        // Si no podemos verificar el artista, no mostrar un título equivocado.
      }
    }
    return confirmed.values.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(musicCollectionProvider);
    final following = ref.watch(favoriteArtistsProvider).values.toList();
    final records = collection.records.values.toList()
      ..sort((a, b) => b.ms.compareTo(a.ms));
    final candidates = <Track>[
      ...records.map((record) => record.track),
      ...collection.favorites.values,
    ];
    final signature = [
      for (final item in following) item.id,
      for (final item in candidates.take(8)) '${item.artistId}:${item.artist}',
    ].join('|');
    if (_future == null || signature != _signature) {
      _signature = signature;
      _future = _profiles(candidates, following);
    }
    return FutureBuilder<List<YtMusicArtist>>(
      future: _future,
      builder: (context, snapshot) {
        final profiles = snapshot.data ?? [];
        if (profiles.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Artistas para ti',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Perfiles de artistas verificados según tu biblioteca.',
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: profiles.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final artist = profiles[index];
                    return SizedBox(
                      width: 128,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push(
                          '/artist',
                          extra: Track(
                            id: 'artist:${artist.id}',
                            title: artist.name,
                            artist: artist.name,
                            artistId: artist.id,
                            album: '',
                            filePath: '',
                            artworkUrl: artist.thumbnail,
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundImage: artist.thumbnail == null
                                  ? null
                                  : NetworkImage(artist.thumbnail!),
                              child: artist.thumbnail == null
                                  ? const Icon(Icons.person_rounded, size: 38)
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              artist.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
