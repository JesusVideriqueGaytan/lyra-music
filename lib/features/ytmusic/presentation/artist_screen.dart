/// Perfil del artista: información del proveedor, lanzamientos y filtros.
/// La selección de música conserva una sola cola y el motor existente.
library;

import 'package:flutter/material.dart';
import 'package:lyra_music/shared/widgets/lyra_section_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/features/library/presentation/controllers/favorite_artists_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/downloads/desktop_download.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/collection_actions.dart';
import 'package:lyra_music/features/ytmusic/presentation/widgets/song_actions.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';

class ArtistAlbumArgs {
  const ArtistAlbumArgs({required this.release, required this.artistName});
  final YtMusicRelease release;
  final String artistName;
}

Track _trackForSong(YtMusicSong song) => Track(
  id: 'ytmusic:${song.videoId}',
  title: song.title,
  artist: song.artist,
  artistId: song.artistId,
  album: song.album,
  filePath: 'https://music.youtube.com/watch?v=${song.videoId}',
  duration: song.duration,
  artworkUrl: song.thumbnail,
);

class ArtistScreen extends ConsumerStatefulWidget {
  const ArtistScreen({super.key, required this.seed});
  final Track seed;
  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  late Future<YtMusicArtistCatalog> _catalog;
  final _filterController = TextEditingController();
  String _filter = '';
  String _sort = 'Destacadas';
  String? _resolvedArtistId;
  bool _showAllSongs = false;

  @override
  void initState() {
    super.initState();
    _catalog = _load();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<YtMusicArtistCatalog> _load() async {
    final client = const YtMusicClient();
    var artistId = widget.seed.artistId;
    final initial = widget.seed.artist.split(' • ').first.trim();
    if (artistId == null || !artistId.startsWith('UC')) {
      final search = await client.searchCatalog(initial);
      for (final artist in search.artists) {
        if (artist.name.toLowerCase() == initial.toLowerCase()) {
          artistId = artist.id;
          break;
        }
      }
    }
    if (artistId != null && artistId.startsWith('UC')) {
      _resolvedArtistId = artistId;
      final catalog = await client.getArtistCatalog(artistId);
      try {
        final extended = await client.getArtistSongs(artistId);
        if (extended.length > catalog.songs.length) {
          return YtMusicArtistCatalog(
            name: catalog.name,
            thumbnail: catalog.thumbnail,
            songs: extended,
            releases: catalog.releases,
          );
        }
      } catch (_) {
        // La ampliación puede no existir; conservar el catálogo principal.
      }
      return catalog;
    }
    // Si no hay perfil oficial, mostrar solo canciones verificadas por nombre.
    final results = await client.search(initial);
    return YtMusicArtistCatalog(
      name: initial,
      songs: results
          .where(
            (song) =>
                song.artist.split(' • ').first.trim().toLowerCase() ==
                initial.toLowerCase(),
          )
          .toList(),
      releases: [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artista'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Volver',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/explore'),
        ),
      ),
      body: FutureBuilder<YtMusicArtistCatalog>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo consultar al artista.'),
                  TextButton.icon(
                    onPressed: () => setState(() => _catalog = _load()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final catalog = snapshot.data!;
          final name = catalog.name.isNotEmpty
              ? catalog.name
              : widget.seed.artist;
          final id =
              _resolvedArtistId ??
              widget.seed.artistId ??
              'name:${name.toLowerCase()}';
          final artist = YtMusicArtist(
            id: id,
            name: name,
            thumbnail: catalog.thumbnail ?? widget.seed.artworkUrl,
          );
          final favorites = ref.watch(favoriteArtistsProvider);
          final followed = favorites.containsKey(id);
          final matches = catalog.songs.where((song) {
            final term = _filter.trim().toLowerCase();
            return term.isEmpty ||
                song.title.toLowerCase().contains(term) ||
                song.album.toLowerCase().contains(term);
          }).toList();
          if (_sort == 'A–Z') {
            matches.sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            );
          } else if (_sort == 'Z–A') {
            matches.sort(
              (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer,
                      scheme.surfaceContainerHigh,
                    ],
                  ),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 20,
                  runSpacing: 16,
                  children: [
                    ClipOval(
                      child: artist.thumbnail == null
                          ? CircleAvatar(
                              radius: 54,
                              child: const Icon(Icons.person_rounded, size: 52),
                            )
                          : Image.network(
                              artist.thumbnail!,
                              width: 108,
                              height: 108,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const CircleAvatar(
                                radius: 54,
                                child: Icon(Icons.person_rounded),
                              ),
                            ),
                    ),
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 72).clamp(
                        200.0,
                        340.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Canciones y lanzamientos disponibles',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => ref
                                    .read(favoriteArtistsProvider.notifier)
                                    .toggle(artist),
                                icon: Icon(
                                  followed
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                ),
                                label: Text(
                                  followed ? 'Siguiendo' : 'Seguir artista',
                                ),
                              ),
                              if (catalog.songs.isNotEmpty)
                                FilledButton.icon(
                                  onPressed: () => ref
                                      .read(
                                        audioPlayerControllerProvider.notifier,
                                      )
                                      .playQueue(
                                        catalog.songs
                                            .map(_trackForSong)
                                            .toList(),
                                      ),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Reproducir'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Canciones',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Orden destacado del catálogo; no son cifras verificadas de reproducciones.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _filterController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        isDense: true,
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Buscar entre sus canciones',
                        suffixIcon: _filter.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Borrar filtro',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _filterController.clear();
                                  setState(() => _filter = '');
                                },
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Ordenar canciones',
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (_) => [
                      for (final value in ['Destacadas', 'A–Z', 'Z–A'])
                        PopupMenuItem(value: value, child: Text(value)),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.sort_rounded, size: 18),
                      label: Text('Orden: $_sort'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (matches.isEmpty)
                const ListTile(title: Text('Sin canciones coincidentes')),
              for (
                var i = 0;
                i <
                    (_showAllSongs || _filter.isNotEmpty
                        ? matches.length
                        : matches.length.clamp(0, 6));
                i++
              )
                Builder(
                  builder: (context) {
                    final song = matches[i];
                    final track = _trackForSong(song);
                    final favorite = ref
                        .watch(musicCollectionProvider)
                        .isFavorite(track);
                    return ListTile(
                      leading: TrackArtwork(track: track, size: 52),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: SongActionBar(
                        track: track,
                        favorite: favorite,
                        onFavorite: () => ref
                            .read(musicCollectionProvider.notifier)
                            .toggleFavorite(track),
                        onPlaylist: () =>
                            showAddToPlaylistDialog(context, ref, track),
                        onPlayNext: () => ref
                            .read(audioPlayerControllerProvider.notifier)
                            .playNext(track),
                        onDownload: supportsDesktopDownloads
                            ? () => showPermittedDownloadDialog(context, track)
                            : null,
                      ),
                      onTap: () => ref
                          .read(audioPlayerControllerProvider.notifier)
                          .playQueue(
                            matches.map(_trackForSong).toList(),
                            startIndex: i,
                          ),
                    );
                  },
                ),
              if (matches.length > 6 && _filter.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _showAllSongs = !_showAllSongs),
                    icon: Icon(
                      _showAllSongs ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(
                      _showAllSongs
                          ? 'Mostrar menos'
                          : 'Ver todas (${matches.length})',
                    ),
                  ),
                ),
              const SizedBox(height: 26),
              Text(
                'Álbumes y sencillos',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (catalog.releases.isEmpty)
                const Text(
                  'El proveedor no facilitó lanzamientos de este artista.',
                ),
              if (catalog.releases.isNotEmpty)
                LayoutBuilder(
                  builder: (context, bounds) {
                    final cols = bounds.maxWidth >= 900
                        ? 5
                        : bounds.maxWidth >= 620
                        ? 3
                        : 2;
                    return GridView.builder(
                      itemCount: catalog.releases.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.88,
                      ),
                      itemBuilder: (context, i) {
                        final release = catalog.releases[i];
                        return InkWell(
                          onTap: () => context.push(
                            '/album',
                            extra: ArtistAlbumArgs(
                              release: release,
                              artistName: name,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: release.thumbnail == null
                                        ? const Center(
                                            child: Icon(
                                              Icons.album_rounded,
                                              size: 62,
                                            ),
                                          )
                                        : Image.network(
                                            release.thumbnail!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (_, _, _) =>
                                                const Center(
                                                  child: Icon(
                                                    Icons.album_rounded,
                                                    size: 62,
                                                  ),
                                                ),
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    release.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    release.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class ArtistAlbumScreen extends ConsumerStatefulWidget {
  const ArtistAlbumScreen({super.key, required this.args});
  final ArtistAlbumArgs args;
  @override
  ConsumerState<ArtistAlbumScreen> createState() => _ArtistAlbumScreenState();
}

class _ArtistAlbumScreenState extends ConsumerState<ArtistAlbumScreen> {
  late Future<List<YtMusicSong>> _songs;
  @override
  void initState() {
    super.initState();
    _songs = const YtMusicClient().getAlbumSongs(
      widget.args.release.id,
      fallbackArtist: widget.args.artistName,
      fallbackAlbum: widget.args.release.title,
      fallbackArtwork: widget.args.release.thumbnail,
    );
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.args.release;
    return Scaffold(
      appBar: AppBar(title: Text(release.title)),
      body: FutureBuilder<List<YtMusicSong>>(
        future: _songs,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final songs = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const LyraSectionBanner(
                icon: Icons.album_rounded,
                eyebrow: 'LANZAMIENTO',
                title: 'Música del álbum',
                subtitle: 'Pistas disponibles para reproducción.',
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: release.thumbnail == null
                        ? Container(
                            width: 128,
                            height: 128,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            child: const Icon(Icons.album_rounded, size: 64),
                          )
                        : Image.network(
                            release.thumbnail!,
                            width: 128,
                            height: 128,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 128,
                              height: 128,
                              child: Icon(Icons.album_rounded, size: 64),
                            ),
                          ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          release.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(widget.args.artistName),
                        Text(
                          release.subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (snapshot.hasError)
                const Text('No se pudo consultar este lanzamiento.'),
              if (!snapshot.hasError && songs.isEmpty)
                const Text('No hay pistas accesibles para este lanzamiento.'),
              for (var i = 0; i < songs.length; i++)
                Builder(
                  builder: (context) {
                    final track = _trackForSong(songs[i]);
                    final favorite = ref
                        .watch(musicCollectionProvider)
                        .isFavorite(track);
                    return ListTile(
                      leading: TrackArtwork(track: track, size: 48),
                      title: Text(songs[i].title),
                      subtitle: Text(songs[i].artist),
                      trailing: SongActionBar(
                        track: track,
                        favorite: favorite,
                        onFavorite: () => ref
                            .read(musicCollectionProvider.notifier)
                            .toggleFavorite(track),
                        onPlaylist: () =>
                            showAddToPlaylistDialog(context, ref, track),
                        onPlayNext: () => ref
                            .read(audioPlayerControllerProvider.notifier)
                            .playNext(track),
                        onDownload: supportsDesktopDownloads
                            ? () => showPermittedDownloadDialog(context, track)
                            : null,
                      ),
                      onTap: () => ref
                          .read(audioPlayerControllerProvider.notifier)
                          .playQueue(
                            songs.map(_trackForSong).toList(),
                            startIndex: i,
                          ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
