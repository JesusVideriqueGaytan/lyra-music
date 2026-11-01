/// Pantalla de la biblioteca musical local.
///
/// Muestra las canciones encontradas al escanear las carpetas autorizadas,
/// con búsqueda, filtro por carpeta, ordenación y acciones para añadir
/// carpetas / re-escanear. Al tocar una canción inicia la cola completa
/// (todas las pistas visibles) comenzando en la seleccionada.
library;

import 'dart:io' show Platform;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/core/performance/performance_controller.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/library/presentation/controllers/library_controller.dart';

/// Import selectivo del repositorio para la acción "añadir carpeta": evita
/// colisión de nombres y hace explícita la dependencia de capa data.
import 'package:lyra_music/features/player/data/repositories/local_audio_repository.dart'
    show audioRepositoryProvider;

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryControllerProvider);
    final visibleTracks = ref.watch(visibleTracksProvider);
    final features = ref.watch(adaptiveFeaturesProvider);
    final notifier = ref.read(libraryControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        actions: <Widget>[
          // Reescanear: icono girando mientras isScanning (solo si hay animaciones).
          IconButton(
            tooltip: 'Volver a escanear',
            onPressed: libraryState.isScanning ? null : () => notifier.rescan(),
            icon: AnimatedRotation(
              turns: libraryState.isScanning ? 1 : 0,
              duration: features.canUseAnimations
                  ? const Duration(seconds: 1)
                  : Duration.zero,
              child: const Icon(Icons.refresh_rounded),
            ),
          ),
          // Menú de ordenación.
          PopupMenuButton<LibrarySort>(
            tooltip: 'Ordenar por',
            icon: const Icon(Icons.sort_rounded),
            initialValue: libraryState.sort,
            onSelected: notifier.setSort,
            itemBuilder: (context) => <PopupMenuEntry<LibrarySort>>[
              for (final sort in LibrarySort.values)
                PopupMenuItem<LibrarySort>(
                  value: sort,
                  child: Text(sort.label),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Ajustes de rendimiento',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFolderSheet(context, ref),
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('Añadir carpeta'),
      ),
      body: Column(
        children: <Widget>[
          // Banner de error del escaneo (carpetas sin permisos, etc.).
          if (libraryState.error != null)
            MaterialBanner(
              content: Text(libraryState.error!),
              backgroundColor: scheme.errorContainer,
              actions: <Widget>[
                TextButton(
                  onPressed: () => notifier.setSearchQuery(
                    libraryState.searchQuery,
                  ), // no-op: solo cerrar banner
                  child: const SizedBox.shrink(),
                ),
              ],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),

          // Campo de búsqueda.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              hintText: 'Buscar título, artista o álbum…',
              leading: const Icon(Icons.search_rounded),
              elevation: const WidgetStatePropertyAll<double>(0),
              onChanged: notifier.setSearchQuery,
            ),
          ),

          // Chips de filtro por carpeta (solo si hay más de una).
          if (notifier.uniqueFolders().length > 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: const Text('Todas'),
                      selected: libraryState.folderFilter == null,
                      onSelected: (_) => notifier.setFolderFilter(null),
                    ),
                  ),
                  for (final folder in notifier.uniqueFolders())
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: FilterChip(
                          label: Text(
                            folder
                                .split(RegExp(r'[/\\]'))
                                .where((s) => s.isNotEmpty)
                                .last,
                          ),
                          selected: libraryState.folderFilter == folder,
                          onSelected: (selected) => notifier.setFolderFilter(
                            selected ? folder : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Cuerpo de la lista con estados vacíos específicos.
          Expanded(
            child: _buildBody(context, ref, libraryState, visibleTracks),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    LibraryState state,
    List<Track> tracks,
  ) {
    final scheme = Theme.of(context).colorScheme;

    // Escaneando: spinner + mensaje.
    if (state.isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Escaneando música…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    // Sin carpetas configuradas: onboarding claro.
    if (state.folders.isEmpty) {
      return _EmptyState(
        icon: Icons.folder_off_rounded,
        title: 'Aún no has añadido música',
        message:
            'Lyra reproduce archivos MP3, FLAC, OGG, WAV y M4A que estén en '
            'tu dispositivo. Añade una carpeta para construirla.',
        actionLabel: 'Añadir primera carpeta',
        onAction: () => _showAddFolderSheet(context, ref),
      );
    }

    // Carpetas configuradas pero sin resultados (o filtrado vacío).
    if (tracks.isEmpty) {
      final filteredOut = state.tracks.isNotEmpty;
      return _EmptyState(
        icon: filteredOut
            ? Icons.filter_alt_off_rounded
            : Icons.music_off_rounded,
        title: filteredOut ? 'Ningún resultado' : 'No se encontró audio',
        message: filteredOut
            ? 'Prueba con otro texto de búsqueda o quita el filtro de carpeta.'
            : 'Las carpetas añadidas no contienen archivos de audio compatibles.',
        actionLabel: filteredOut ? 'Limpiar filtros' : 'Reescanear',
        onAction: () {
          if (filteredOut) {
            ref.read(libraryControllerProvider.notifier)
              ..setSearchQuery('')
              ..setFolderFilter(null);
          } else {
            ref.read(libraryControllerProvider.notifier).rescan();
          }
        },
      );
    }

    return ListView.builder(
      // Padding inferior para que el MiniPlayer flotante no tape la última fila.
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: tracks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${tracks.length} canción${tracks.length == 1 ? '' : 'es'}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        final track = tracks[index - 1];
        return _TrackTile(track: track, allVisibleTracks: tracks);
      },
    );
  }
}

/// Fila individual de canción en la biblioteca.
class _TrackTile extends ConsumerWidget {
  const _TrackTile({required this.track, required this.allVisibleTracks});

  final Track track;
  final List<Track> allVisibleTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(adaptiveFeaturesProvider);
    final currentId = ref.watch(
      audioPlayerControllerProvider.select((s) => s.currentTrack?.id),
    );
    final isCurrent = currentId == track.id;
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () {
        // Reproducimos TODA la lista visible comenzando por esta pista:
        // así next/previous recorren la biblioteca filtrada actual.
        final startIndex = allVisibleTracks.indexOf(track);
        ref
            .read(audioPlayerControllerProvider.notifier)
            .playQueue(allVisibleTracks, startIndex: startIndex);
      },
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          // Radio menor en tier low: menos anti-aliasing de esquinas.
          borderRadius: BorderRadius.circular(
            features.canUseAnimations ? 8 : 4,
          ),
          color: isCurrent
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: Icon(
          isCurrent ? Icons.equalizer_rounded : Icons.music_note_rounded,
          size: 22,
          color: isCurrent ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent
            ? TextStyle(fontWeight: FontWeight.bold, color: scheme.primary)
            : null,
      ),
      subtitle: Text(
        '${track.artist} • ${track.folderName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: track.duration != null
          ? Text(
              _formatShortDuration(track.duration!),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            )
          : null,
    );
  }

  String _formatShortDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Estado vacío genérico con icono, mensaje y acción.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
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
