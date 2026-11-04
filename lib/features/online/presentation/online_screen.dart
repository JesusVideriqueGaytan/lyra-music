/// Explorar música desde Lyra.
///
/// Una sola experiencia: los resultados de YouTube Music son acciones de
/// reproducción internas. MusicBrainz continúa disponible como fuente de
/// metadatos en la capa de datos, pero no se ofrece como reproductor ni como
/// enlace externo para evitar confundir al usuario.
///
/// Este adaptador usa interfaces de YouTube no oficiales y puede fallar
/// para ciertas canciones; no promete acceso universal ni descargas.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/core/performance/performance_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';
import 'package:lyra_music/features/ytmusic/presentation/ytmusic_controller.dart';
import 'package:lyra_music/features/library/presentation/controllers/favorite_artists_controller.dart';

class OnlineScreen extends ConsumerStatefulWidget {
  const OnlineScreen({super.key});

  @override
  ConsumerState<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends ConsumerState<OnlineScreen> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final List<String> _recentSearches = <String>[];
  final List<YtMusicSong> _recentlyPlayed = <YtMusicSong>[];
  String? _loadingVideoId;
  String? _playbackError;
  Timer? _suggestionTimer;
  int _suggestionGeneration = 0;
  List<String> _liveSuggestions = [];
  List<YtMusicArtist> _liveArtists = [];
  bool _suggestionsLoading = false;

  void _onTyped(String query) {
    _suggestionTimer?.cancel();
    final generation = ++_suggestionGeneration;
    if (query.trim().length < 2) {
      setState(() { _liveSuggestions = []; _liveArtists = [];
        _suggestionsLoading = false; });
      if (query.trim().isEmpty) {
        // Invalida una búsqueda pendiente y elimina resultados antiguos.
        ref.read(ytMusicControllerProvider.notifier).clearSearch();
      }
      return;
    }
    setState(() {
      _suggestionsLoading = true;
      _liveSuggestions = [];
      _liveArtists = [];
    });
    _suggestionTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final client = const YtMusicClient();
        List<String> suggestions = [];
        try {
          suggestions = await client.getSearchSuggestions(query);
        } catch (_) {
          // Un fallo de sugerencias no impide mostrar artistas.
        }
        if (!mounted || generation != _suggestionGeneration) return;
        setState(() { _liveSuggestions = suggestions; _suggestionsLoading = false; });
        if (query.trim().length >= 3) {
          try {
            final artists = await client.searchArtistProfiles(query);
            if (!mounted || generation != _suggestionGeneration) return;
            setState(() => _liveArtists = artists.take(4).toList());
          } catch (_) { /* No bloquear el buscador cuando falla el proveedor. */ }
        }
      } catch (_) {
        if (!mounted || generation != _suggestionGeneration) return;
        setState(() { _liveSuggestions = []; _suggestionsLoading = false; });
      }
    });
  }


  static const _suggestions = <(String, IconData)>[
    ('Pop', Icons.auto_awesome_rounded),
    ('Rock', Icons.bolt_rounded),
    ('Jazz', Icons.piano_rounded),
    ('Lo-fi', Icons.nightlight_round),
    ('Anime', Icons.headphones_rounded),
    ('Electrónica', Icons.graphic_eq_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _query.text = ref.read(ytMusicControllerProvider).query;
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _query.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _search({String? term}) {
    final query = (term ?? _query.text).trim();
    if (query.isEmpty) {
      _searchFocus.requestFocus();
      return;
    }
    if (term != null) _query.text = query;
    _searchFocus.unfocus();
    _suggestionTimer?.cancel();
    ++_suggestionGeneration;
    setState(() {
      _liveSuggestions = [];
      _liveArtists = [];
      _suggestionsLoading = false;
      _recentSearches.removeWhere((s) => s.toLowerCase() == query.toLowerCase());
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 6) _recentSearches.removeLast();
      _playbackError = null;
    });
    ref.read(ytMusicControllerProvider.notifier).search(query);
  }

  Track _songReference(YtMusicSong song) => Track(
    id: 'ytmusic:${song.videoId}', title: song.title, artist: song.artist,
    album: song.album, filePath: 'https://music.youtube.com/watch?v=${song.videoId}',
    artworkUrl: song.thumbnail, artistId: song.artistId,
    duration: song.duration,
  );

  Future<void> _play(YtMusicSong song) async {
    if (_loadingVideoId != null) return;
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    final current = ref.read(audioPlayerControllerProvider);
    if (current.currentTrack?.id == 'ytmusic:${song.videoId}') {
      if (!current.playing) await controller.play();
      return;
    }
    setState(() {
      _loadingVideoId = song.videoId;
      _playbackError = null;
    });
    try {
      // La URL del flujo es efímera: se obtiene justo al pulsar una canción.
      // Nunca se abre una web externa para una acción de reproducción.
      final track = _songReference(song);
      if (!mounted) return;
      await controller.playQueue([track]);
      if (!mounted) return;
      final error = ref.read(audioPlayerControllerProvider).error;
      if (error != null) {
        setState(() => _playbackError = error);
        return;
      }
      setState(() {
        _recentlyPlayed.removeWhere((s) => s.videoId == song.videoId);
        _recentlyPlayed.insert(0, song);
        if (_recentlyPlayed.length > 12) _recentlyPlayed.removeLast();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _playbackError = 'No se pudo reproducir esta canción dentro de Lyra. '
            'Puede estar restringida, requerir autenticación o haber cambiado '
            'el proveedor. Prueba otra canción.';
      });
    } finally {
      if (mounted) setState(() => _loadingVideoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ytMusicControllerProvider);
    final playback = ref.watch(audioPlayerControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final features = ref.watch(adaptiveFeaturesProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 660;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1230),
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          compact ? 16 : 26, 10, compact ? 16 : 26, 14),
                      sliver: SliverList.list(children: [
                        _DiscoverHeader(
                          compact: compact,
                          canAnimate: features.canUseAnimations,
                        ),
                        const SizedBox(height: 20),
                        _SearchField(
                          controller: _query,
                          focusNode: _searchFocus,
                          loading: state.loading,
                          onSearch: () => _search(),
                          onTyped: _onTyped,
                          onClear: () {
                            _query.clear();
                            _onTyped('');
                            _searchFocus.requestFocus();
                          },
                        ),
                        if (_liveArtists.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('Artistas sugeridos', style: Theme.of(context).textTheme.titleSmall),
                          for (final artist in _liveArtists)
                            ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundImage: artist.thumbnail == null
                                  ? null : NetworkImage(artist.thumbnail!),
                                child: artist.thumbnail == null
                                  ? const Icon(Icons.person_rounded) : null,
                              ),
                              title: Text(artist.name),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                _searchFocus.unfocus();
                                context.push('/artist', extra: Track(
                                  id: 'artist:${artist.id}', title: artist.name,
                                  artist: artist.name, artistId: artist.id,
                                  album: '', filePath: '', artworkUrl: artist.thumbnail,
                                ));
                              },
                            ),
                        ],
                        if (_suggestionsLoading)
                          const LinearProgressIndicator(minHeight: 2),
                        if (_liveSuggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Card(child: Column(children: [
                            for (final text in _liveSuggestions)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.search_rounded),
                                title: Text(text),
                                onTap: () => _search(term: text),
                              ),
                          ])),
                        ],
                        const SizedBox(height: 20),
                        if (state.query.isEmpty) ...[
                          _SectionHeading(
                            title: 'Encuentra tu ritmo',
                            subtitle: 'Empieza buscando un género o lo que quieras escuchar',
                          ),
                          const SizedBox(height: 12),
                          _SuggestionGrid(
                            compact: compact,
                            suggestions: _suggestions,
                            onTap: (term) => _search(term: term),
                          ),
                          if (_recentSearches.isNotEmpty) ...[
                            const SizedBox(height: 28),
                            _SectionHeading(title: 'Búsquedas recientes'),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 8,
                              children: [
                                for (final query in _recentSearches)
                                  ActionChip(
                                    avatar: const Icon(Icons.history_rounded, size: 18),
                                    label: Text(query),
                                    onPressed: () => _search(term: query),
                                  ),
                              ],
                            ),
                          ],
                          if (_recentlyPlayed.isNotEmpty) ...[
                            const SizedBox(height: 28),
                            _SectionHeading(title: 'Sigue escuchando',
                              subtitle: 'Canciones que abriste en esta sesión'),
                            const SizedBox(height: 10),
                            SizedBox(height: 168,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _recentlyPlayed.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 14),
                                itemBuilder: (context, index) {
                                  final song = _recentlyPlayed[index];
                                  return _RecentlyPlayedCard(
                                    song: song,
                                    onTap: () => _play(song),
                                  );
                                },
                              ),
                            ),
                          ],
                        ] else ...[
                          Row(children: [
                            Expanded(child: _SectionHeading(
                              title: 'Resultados',
                              subtitle: state.loading
                                  ? 'Buscando “${state.query}”'
                                  : '${state.results.length} canciones para “${state.query}”',
                            )),
                            IconButton(
                              tooltip: 'Nueva búsqueda',
                              icon: const Icon(Icons.search_rounded),
                              onPressed: () => _searchFocus.requestFocus(),
                            ),
                          ]),
                          const SizedBox(height: 8),
                        ],
                        if (_playbackError != null) ...[
                          const SizedBox(height: 8),
                          MaterialBanner(
                            padding: const EdgeInsets.all(12),
                            backgroundColor: scheme.errorContainer,
                            content: Text(_playbackError!),
                            actions: [
                              TextButton(onPressed: () => setState(
                                  () => _playbackError = null),
                                child: const Text('Cerrar')),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (state.error != null) ...[
                          _StatusMessage(
                            icon: Icons.wifi_off_rounded,
                            title: 'No se pudo completar la búsqueda',
                            message: state.error!,
                            action: TextButton.icon(
                              onPressed: () => _search(term: state.query),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reintentar'),
                            ),
                          ),
                        ] else if (state.loading) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 18),
                          const Center(child: Text('Buscando música…')),
                        ] else if (state.query.isNotEmpty && state.results.isEmpty && state.artists.isEmpty) ...[
                          const _StatusMessage(
                            icon: Icons.search_off_rounded,
                            title: 'No encontramos resultados',
                            message: 'Prueba otra canción, artista o álbum.',
                          ),
                        ],
                      ]),
                    ),
                    if (!state.loading && state.error == null && state.artists.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(compact ? 16 : 26, 4, compact ? 16 : 26, 12),
                        sliver: SliverToBoxAdapter(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeading(title: 'Artistas'),
                            const SizedBox(height: 10),
                            SizedBox(height: 150, child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: state.artists.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final artist = state.artists[index];
                                final isFollowed = ref.watch(favoriteArtistsProvider)
                                  .containsKey(artist.id);
                                return SizedBox(width: 130, child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => context.push('/artist', extra: Track(
                                    id: 'artist:${artist.id}', title: artist.name,
                                    artist: artist.name, artistId: artist.id,
                                    album: '', filePath: '', artworkUrl: artist.thumbnail,
                                  )),
                                  child: Column(children: [
                                    CircleAvatar(radius: 42,
                                      backgroundImage: artist.thumbnail == null
                                        ? null : NetworkImage(artist.thumbnail!),
                                      child: artist.thumbnail == null
                                        ? const Icon(Icons.person_rounded, size: 36) : null),
                                    const SizedBox(height: 5),
                                    Text(artist.name, maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                    if (isFollowed) const Icon(Icons.favorite_rounded, size: 15),
                                  ]),
                                ));
                              },
                            )),
                          ],
                        )),
                      ),
                    if (!state.loading && state.error == null && state.results.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(compact ? 8 : 18,
                            0, compact ? 8 : 18, 24),
                        sliver: SliverList.builder(
                          itemCount: state.results.length,
                          itemBuilder: (context, index) {
                            final song = state.results[index];
                            final current = playback.currentTrack?.id ==
                                'ytmusic:${song.videoId}';
                            return _SongRow(
                              song: song,
                              selected: current,
                              playing: current && playback.playing,
                              loading: _loadingVideoId == song.videoId,
                              onPlay: () => _play(song),
                              onPlayNext: () => ref.read(audioPlayerControllerProvider.notifier)
                                  .playNext(_songReference(song)),
                            );
                          },
                        ),
                      ),
                    if (screenWidth >= 850 && playback.currentTrack != null)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(26, 0, 26, 20),
                        sliver: SliverToBoxAdapter(
                          child: _NowPlayingLink(
                            playback: playback,
                            onTap: () => context.go('/player'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                child: Text(
                  'La disponibilidad de audio depende del proveedor.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({required this.compact, required this.canAnimate});
  final bool compact;
  final bool canAnimate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 20 : 26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            Color.alphaBlend(
              scheme.primary.withValues(alpha: canAnimate ? 0.13 : 0.05),
              scheme.surfaceContainerHigh,
            ),
          ],
        ),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DESCUBRE EN LYRA',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 2, color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              )),
            const SizedBox(height: 10),
            Text('Tu música, sin cambiar de aplicación',
              style: (compact
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.headlineMedium)?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  )),
            const SizedBox(height: 6),
            Text('Busca, elige y escucha desde el reproductor de Lyra.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              )),
          ],
        )),
        if (!compact) ...[
          const SizedBox(width: 18),
          Icon(Icons.graphic_eq_rounded,
            size: 82, color: scheme.onPrimaryContainer.withValues(alpha: 0.6)),
        ],
      ]),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode,
    required this.loading, required this.onSearch, required this.onClear,
    required this.onTyped});
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final ValueChanged<String> onTyped;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      onChanged: onTyped,
      decoration: InputDecoration(
        hintText: 'Busca canciones, artistas o álbumes',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              tooltip: 'Borrar texto',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: FilledButton(
              onPressed: loading ? null : onSearch,
              child: const Text('Buscar'),
            ),
          ),
        ]),
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
      )),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ],
  );
}

class _SuggestionGrid extends StatelessWidget {
  const _SuggestionGrid({required this.compact, required this.suggestions,
    required this.onTap});
  final bool compact;
  final List<(String, IconData)> suggestions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = <Color>[
      scheme.primaryContainer,
      scheme.tertiaryContainer,
      scheme.secondaryContainer,
      scheme.surfaceContainerHighest,
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth >= 950 ? 3 : 2;
      final ratio = compact ? 2.2 : 3.5;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: suggestions.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, crossAxisSpacing: 10,
          mainAxisSpacing: 10, childAspectRatio: ratio,
        ),
        itemBuilder: (context, index) {
          final (label, icon) = suggestions[index];
          final color = colors[index % colors.length];
          return Material(
            color: color,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onTap(label),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                child: Row(children: [
                  Icon(icon, color: scheme.onSurface, size: compact ? 22 : 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ))),
                ]),
              ),
            ),
          );
        },
      );
    });
  }
}

String _formatDuration(Duration d) {
  final total = d.inSeconds;
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.song, required this.selected,
    required this.playing, required this.loading, required this.onPlay,
    required this.onPlayNext});
  final YtMusicSong song;
  final bool selected;
  final bool playing;
  final bool loading;
  final VoidCallback onPlay;
  final VoidCallback onPlayNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: loading ? null : onPlay,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              _MusicArtwork(song: song, size: 54),
              const SizedBox(width: 13),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                    )),
                  const SizedBox(height: 5),
                  Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                    )),
                ],
              )),
              Text(song.duration == null ? '—' : _formatDuration(song.duration!),
                style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 8),
              if (playing)
                Icon(Icons.equalizer_rounded, color: scheme.primary, size: 23)
              else if (loading)
                const SizedBox(width: 23, height: 23,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              else
                Icon(Icons.play_arrow_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'Acciones de cola',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (_) => onPlayNext(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'next', child: Text('Reproducir a continuación')),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RecentlyPlayedCard extends StatelessWidget {
  const _RecentlyPlayedCard({required this.song, required this.onTap});
  final YtMusicSong song;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(width: 138, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MusicArtwork(song: song, size: 114),
        const SizedBox(height: 6),
        Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge),
      ],
    )),
  );
}

class _MusicArtwork extends StatelessWidget {
  const _MusicArtwork({required this.song, required this.size});
  final YtMusicSong song;
  final double size;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = song.thumbnail;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(dimension: size,
        child: url == null
          ? ColoredBox(color: scheme.primaryContainer,
              child: Icon(Icons.music_note_rounded,
                color: scheme.onPrimaryContainer))
          : Image.network(url, fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: scheme.primaryContainer,
                child: Icon(Icons.music_note_rounded,
                  color: scheme.onPrimaryContainer),
              )),
      ),
    );
  }
}

class _NowPlayingLink extends StatelessWidget {
  const _NowPlayingLink({required this.playback, required this.onTap});
  final PlaybackState playback;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final track = playback.currentTrack;
    if (track == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: TrackArtwork(track: track, size: 48),
        title: const Text('Reproduciendo ahora'),
        subtitle: Text('${track.title} · ${track.artist}', maxLines: 1,
          overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.open_in_full_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.icon, required this.title,
    required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    )),
  );
}
