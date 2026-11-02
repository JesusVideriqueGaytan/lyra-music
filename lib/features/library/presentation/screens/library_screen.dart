/// Biblioteca local adaptable. Conserva búsqueda, escaneo, orden y carpetas.
library;

import 'dart:io' show Platform;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:lyra_music/shared/widgets/lyra_section_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/features/library/presentation/controllers/library_controller.dart';
import 'package:lyra_music/features/library/presentation/screens/my_music_screen.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/collection_actions.dart';
import 'package:lyra_music/features/player/data/repositories/local_audio_repository.dart'
    show audioRepositoryProvider;

enum _LibraryTab { songs, artists, albums, folders }

extension on _LibraryTab {
  String get label => switch (this) {
    _LibraryTab.songs => 'Canciones',
    _LibraryTab.artists => 'Artistas',
    _LibraryTab.albums => 'Álbumes',
    _LibraryTab.folders => 'Carpetas',
  };
  IconData get icon => switch (this) {
    _LibraryTab.songs => Icons.music_note_rounded,
    _LibraryTab.artists => Icons.person_outline_rounded,
    _LibraryTab.albums => Icons.album_outlined,
    _LibraryTab.folders => Icons.folder_outlined,
  };
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.showCollectionInitially = true});
  final bool showCollectionInitially;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  _LibraryTab _tab = _LibraryTab.songs;
  String? _groupTitle;
  late bool _collectionTab;

  @override
  void initState() {
    super.initState();
    _collectionTab = widget.showCollectionInitially;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(libraryControllerProvider.notifier)
      ..setSearchQuery('')
      ..setFolderFilter(null);
    setState(() {
      _groupTitle = null;
      _tab = _LibraryTab.songs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);
    final visible = ref.watch(visibleTracksProvider);
    final notifier = ref.read(libraryControllerProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final counts = {
      _LibraryTab.songs: state.totalTracks,
      _LibraryTab.artists: state.tracks.map((e) => e.artist).toSet().length,
      _LibraryTab.albums: state.tracks.map((e) => e.album).toSet().length,
      _LibraryTab.folders: state.folders.length,
    };

    List<Track> filtered = visible;
    if (_groupTitle != null) {
      filtered = visible
          .where(
            (track) => switch (_tab) {
              _LibraryTab.artists => track.artist == _groupTitle,
              _LibraryTab.albums => track.album == _groupTitle,
              _LibraryTab.folders => track.directoryPath == _groupTitle,
              _ => true,
            },
          )
          .toList(growable: false);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Biblioteca',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Estadísticas',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => context.go('/statistics'),
          ),
          IconButton(
            tooltip: 'Actualizar biblioteca',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: state.isScanning ? null : notifier.rescan,
          ),
          PopupMenuButton<LibrarySort>(
            tooltip: 'Ordenar canciones',
            icon: const Icon(Icons.sort_rounded),
            initialValue: state.sort,
            onSelected: notifier.setSort,
            itemBuilder: (context) => [
              for (final sort in LibrarySort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.go('/preferences'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Mi colección'),
                  icon: Icon(Icons.favorite_border_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Archivos locales'),
                  icon: Icon(Icons.folder_outlined),
                ),
              ],
              selected: {_collectionTab},
              onSelectionChanged: (values) =>
                  setState(() => _collectionTab = values.first),
            ),
          ),
          Expanded(
            child: _collectionTab
                ? const MyMusicScreen(embedded: true)
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            width >= 700 ? 24 : 16,
                            16,
                            width >= 700 ? 24 : 16,
                            12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const LyraSectionBanner(
                                icon: Icons.folder_copy_rounded,
                                eyebrow: 'ARCHIVOS LOCALES',
                                title: 'Tu colección, a tu ritmo',
                                subtitle:
                                    'Música del dispositivo, siempre disponible sin conexión.',
                              ),
                              const SizedBox(height: 18),
                              _LibrarySummary(
                                total: state.totalTracks,
                                folders: state.folders.length,
                                onAdd: () => _showAddFolderSheet(context, ref),
                                onPlay: state.tracks.isEmpty
                                    ? null
                                    : () => ref
                                          .read(
                                            audioPlayerControllerProvider
                                                .notifier,
                                          )
                                          .playQueue(
                                            visible.isEmpty
                                                ? state.tracks
                                                : visible,
                                          ),
                              ),
                              const SizedBox(height: 20),
                              SearchBar(
                                controller: _searchController,
                                hintText:
                                    'Buscar canciones, artistas o álbumes',
                                leading: const Icon(Icons.search_rounded),
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                elevation: const WidgetStatePropertyAll<double>(
                                  0,
                                ),
                                onChanged: notifier.setSearchQuery,
                                trailing: [
                                  if (state.searchQuery.isNotEmpty)
                                    IconButton(
                                      tooltip: 'Borrar búsqueda',
                                      onPressed: () {
                                        _searchController.clear();
                                        notifier.setSearchQuery('');
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                ],
                              ),
                              if (state.error != null) ...[
                                const SizedBox(height: 10),
                                Card(
                                  color: scheme.errorContainer,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          color: scheme.onErrorContainer,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            state.error!,
                                            style: TextStyle(
                                              color: scheme.onErrorContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final tab in _LibraryTab.values)
                                    ChoiceChip(
                                      avatar: Icon(tab.icon, size: 17),
                                      label: Text(
                                        '${tab.label}  ${counts[tab]}',
                                      ),
                                      selected: _tab == tab,
                                      onSelected: (_) => setState(() {
                                        _tab = tab;
                                        _groupTitle = null;
                                      }),
                                    ),
                                ],
                              ),
                              if (_groupTitle != null) ...[
                                const SizedBox(height: 12),
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Todas las ${_tab.label.toLowerCase()}  /  '
                                    '${_tab == _LibraryTab.folders ? _folderName(_groupTitle!) : _groupTitle!}',
                                  ),
                                  onPressed: () =>
                                      setState(() => _groupTitle = null),
                                ),
                              ],
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _groupTitle == null
                                          ? _tab.label
                                          : (_tab == _LibraryTab.folders
                                                ? _folderName(_groupTitle!)
                                                : _groupTitle!),
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  if (state.searchQuery.isNotEmpty ||
                                      state.folderFilter != null)
                                    TextButton(
                                      onPressed: _clearFilters,
                                      child: const Text('Limpiar filtros'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      if (state.isScanning)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (state.folders.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyLibrary(
                            title: 'Tu biblioteca comienza aquí',
                            description:
                                'Elige una carpeta con tus canciones para empezar. '
                                'Lyra funcionará sin depender de Internet.',
                            actionLabel: 'Añadir carpeta',
                            onAction: () => _showAddFolderSheet(context, ref),
                          ),
                        )
                      else if (visible.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyLibrary(
                            title: 'No encontramos canciones',
                            description:
                                'Prueba otra búsqueda o vuelve a escanear tus carpetas.',
                            actionLabel: 'Limpiar búsqueda',
                            onAction: _clearFilters,
                          ),
                        )
                      else if (_tab == _LibraryTab.songs || _groupTitle != null)
                        SliverList.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => _SongRow(
                            track: filtered[index],
                            queue: filtered,
                            index: index,
                          ),
                        )
                      else
                        _buildGroups(context, visible, width),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroups(BuildContext context, List<Track> tracks, double width) {
    final groups = <String, int>{};
    for (final track in tracks) {
      final key = switch (_tab) {
        _LibraryTab.artists => track.artist,
        _LibraryTab.albums => track.album,
        _LibraryTab.folders => track.directoryPath,
        _LibraryTab.songs => track.title,
      };
      groups.update(key, (n) => n + 1, ifAbsent: () => 1);
    }
    final sorted = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    // Dependemos del ancho real del contenido, no de la pantalla física.
    final availableWidth = width > 850 ? width - 216 : width;
    final columns = availableWidth >= 1000
        ? 4
        : availableWidth >= 680
        ? 3
        : 2;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: availableWidth < 520 ? 1.15 : 1.5,
        ),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final key = sorted[index];
          final title = _tab == _LibraryTab.folders ? _folderName(key) : key;
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          return Card(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _groupTitle = key),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_tab.icon, color: scheme.primary, size: 32),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${groups[key]} canciones',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _folderName(String path) {
  final segments = path
      .split(RegExp(r'[/\\]'))
      .where((s) => s.isNotEmpty)
      .toList();
  return segments.isEmpty ? path : segments.last;
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({
    required this.total,
    required this.folders,
    required this.onAdd,
    required this.onPlay,
  });
  final int total;
  final int folders;
  final VoidCallback onAdd;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.82),
            scheme.surfaceContainerHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.library_music_rounded, size: 29),
            const SizedBox(height: 10),
            Text(
              'Biblioteca local',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '$total canciones  ·  $folders carpetas',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(compact ? 'Reproducir' : 'Reproducir colección'),
                ),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Añadir carpeta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SongRow extends ConsumerWidget {
  const _SongRow({
    required this.track,
    required this.queue,
    required this.index,
  });
  final Track track;
  final List<Track> queue;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent =
        ref.watch(
          audioPlayerControllerProvider.select((s) => s.currentTrack?.id),
        ) ==
        track.id;
    final subtitle = '${track.artist}  ·  ${track.folderName}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isCurrent
            ? scheme.primaryContainer.withValues(alpha: 0.40)
            : scheme.surfaceContainerLow,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 5,
          ),
          onTap: () => ref
              .read(audioPlayerControllerProvider.notifier)
              .playQueue(queue, startIndex: index),
          leading: TrackArtwork(track: track, size: 48),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Favorito',
                icon: Icon(
                  ref.watch(musicCollectionProvider).isFavorite(track)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                onPressed: () => ref
                    .read(musicCollectionProvider.notifier)
                    .toggleFavorite(track),
              ),
              IconButton(
                tooltip: 'Más opciones',
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () =>
                    showTrackCollectionActions(context, ref, track),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 60,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}

/// Diálogo simple para escribir la ruta de una carpeta de música.
///
/// En desktop escribimos la ruta directamente; en móvil se sustituirá por
/// un selector nativo con permission_handler en Fase 2.x. Validamos que la
/// carpeta exista antes de añadirla al repositorio.
Future<void> _showAddFolderSheet(BuildContext context, WidgetRef ref) async {
  // En escritorio se usa la ruta devuelta por el selector del sistema.
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    final notifier = ref.read(libraryControllerProvider.notifier);
    if (ref.read(libraryControllerProvider).isScanning) return;
    try {
      final path = await getDirectoryPath(
        confirmButtonText: 'Seleccionar carpeta',
      );
      if (path == null || !context.mounted) return;
      await notifier.waitUntilReady();
      await notifier.addFolder(path);
      if (!context.mounted) return;
      final result = ref.read(libraryControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Carpeta añadida: $path')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la carpeta: $error')),
      );
    }
    return;
  }
  final controller = TextEditingController();
  final repository = ref.read(audioRepositoryProvider);
  // Pre-sugerimos las carpetas candidatas del sistema (Music, Home…).
  final candidates = await repository.defaultCandidateFolders();

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit(String path) async {
              final trimmed = path.trim();
              if (trimmed.isEmpty) return;
              final navigator = Navigator.of(sheetContext);
              await ref
                  .read(libraryControllerProvider.notifier)
                  .addFolder(trimmed);
              if (navigator.mounted) navigator.pop();
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Añadir carpeta de música',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onSubmitted: submit,
                  decoration: InputDecoration(
                    labelText: 'Ruta absoluta',
                    hintText: '/home/usuario/Música',
                    prefixIcon: const Icon(Icons.folder_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_rounded),
                      onPressed: () => submit(controller.text),
                    ),
                  ),
                ),
                if (candidates.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Carpetas sugeridas:',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      for (final candidate in candidates)
                        ActionChip(
                          label: Text(
                            candidate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            controller.text = candidate;
                            setSheetState(() {});
                          },
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      );
    },
  );
}
