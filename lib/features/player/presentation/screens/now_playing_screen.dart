/// Pantalla "Suena ahora" (Now Playing) de Lyra.
///
/// Composición adaptativa por tier:
///  - Portada cuadrada cuyo tamaño máximo depende de [AdaptiveFeatures] y del
///    ancho disponible (desktop vs móvil).
///  - Fondo degradado + blur solo en tiers high/ultra; en low/medium un color
///    de superficie plano.
///  - Transiciones de la cola: fade simple en low, slide en medium+, zoom en
///    high/ultra (estilo de transición leído de la matriz).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/core/performance/adaptive_features.dart';
import 'package:lyra_music/core/performance/performance_controller.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/player/presentation/widgets/player_controls.dart';
import 'package:lyra_music/features/player/presentation/widgets/progress_bar.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/player/domain/models/queue_visual_order.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/collection_actions.dart';
import 'package:lyra_music/features/downloads/desktop_download.dart';
import 'package:lyra_music/features/ytmusic/presentation/widgets/song_actions.dart';

/// Muestra la cola integrada a la derecha en escritorio; el usuario puede
/// plegarla sin abrir un diálogo que cubra la portada y los controles.
final queueDockVisibleProvider = StateProvider<bool>((ref) => true);

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(adaptiveFeaturesProvider);
    final currentTrack = ref.watch(
      audioPlayerControllerProvider.select((s) => s.currentTrack),
    );
    final error = ref.watch(
      audioPlayerControllerProvider.select((s) => s.error),
    );
    final scheme = Theme.of(context).colorScheme;
    final animate = features.canUseAnimations;

    // Sin pista cargada: pantalla vacía con acción de volver a la biblioteca.
    if (currentTrack == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reproductor')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.music_off_rounded,
                size: 64,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Ninguna canción cargada',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => context.go('/library'),
                icon: const Icon(Icons.library_music),
                label: const Text('Ir a la biblioteca'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Reproduciendo ahora'),
        leading: IconButton(
          tooltip: 'Contraer',
          // Contraer siempre lleva al Inicio, no a Biblioteca.
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
        ),
      ),
      // Banner de error de reproducción: se muestra como SnackBar persistente
      // mientras exista (el controller lo limpia al reproducir otra pista).
      bottomNavigationBar: error != null
          ? MaterialBanner(
              content: Text(error),
              backgroundColor: scheme.errorContainer,
              actions: <Widget>[
                TextButton(
                  onPressed: () => ref
                      .read(audioPlayerControllerProvider.notifier)
                      .playAt(
                        ref.read(audioPlayerControllerProvider).currentIndex,
                      ),
                  child: const Text('Reintentar'),
                ),
                TextButton(
                  onPressed: () => context.go('/library'),
                  child: const Text('Buscar otra canción'),
                ),
              ],
            )
          : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _AdaptiveBackground(animate: animate),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final wide = bounds.maxWidth >= 760;
                final hasDockSpace = bounds.maxWidth >= 1040;
                final dockVisible = ref.watch(queueDockVisibleProvider);
                final docked = hasDockSpace && dockVisible;
                final playerWidth = bounds.maxWidth - (docked ? 328.0 : 0.0);
                final side =
                    (wide ? bounds.maxHeight * 0.72 : bounds.maxHeight * 0.48)
                        .clamp(
                          140.0,
                          wide
                              ? (playerWidth * 0.45).clamp(140.0, 440.0)
                              : 340.0,
                        )
                        .toDouble();
                final artwork = _CoverArt(
                  size: side,
                  animate: animate,
                  track: currentTrack,
                );
                final details = ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'REPRODUCIENDO AHORA',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              letterSpacing: 1.8,
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 18),
                      _TrackTitles(
                        title: currentTrack.title,
                        artist: currentTrack.displayArtist,
                        animate: animate,
                        onArtistTap: () {
                          if (currentTrack.displayArtist !=
                              'Artista desconocido') {
                            context.push('/artist', extra: currentTrack);
                          }
                        },
                      ),
                      const SizedBox(height: 5),
                      Text(
                        currentTrack.album == 'YouTube Music'
                            ? 'Canción'
                            : currentTrack.album,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => ref
                                .read(musicCollectionProvider.notifier)
                                .toggleFavorite(currentTrack),
                            icon: Icon(
                              ref
                                      .watch(musicCollectionProvider)
                                      .isFavorite(currentTrack)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                            ),
                            label: Text(
                              ref
                                      .watch(musicCollectionProvider)
                                      .isFavorite(currentTrack)
                                  ? 'En favoritos'
                                  : 'Me gusta',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => showAddToPlaylistDialog(
                              context,
                              ref,
                              currentTrack,
                            ),
                            icon: const Icon(Icons.playlist_add_rounded),
                            label: const Text('Añadir a lista'),
                          ),
                          if (supportsDesktopDownloads &&
                              currentTrack.id.startsWith('ytmusic:'))
                            OutlinedButton.icon(
                              onPressed: () => showPermittedDownloadDialog(
                                context,
                                currentTrack,
                              ),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Descargar'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const ProgressBar(),
                      const SizedBox(height: 12),
                      const PlayerControls(),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          if (hasDockSpace) {
                            ref.read(queueDockVisibleProvider.notifier).state =
                                !dockVisible;
                          } else {
                            showQueueSheet(context, ref);
                          }
                        },
                        icon: Icon(
                          docked
                              ? Icons.chevron_right_rounded
                              : Icons.queue_music_rounded,
                        ),
                        label: Text(docked ? 'Ocultar cola' : 'Mostrar cola'),
                      ),
                    ],
                  ),
                );
                if (wide) {
                  return Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 16, 18, 24),
                          child: Row(
                            children: [
                              Expanded(child: Center(child: artwork)),
                              const SizedBox(width: 18),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Center(child: details),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Keep the dock mounted while its width animates, so
                      // opening AND closing visibly slide from the right.
                      AnimatedContainer(
                        duration: animate
                            ? const Duration(milliseconds: 300)
                            : Duration.zero,
                        curve: Curves.easeInOutCubic,
                        width: docked ? 328 : 0,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            minWidth: 328,
                            maxWidth: 328,
                            child: Row(
                              children: [
                                VerticalDivider(
                                  width: 1,
                                  color: scheme.outlineVariant,
                                ),
                                SizedBox(
                                  width: 327,
                                  child: Material(
                                    color: scheme.surfaceContainerLow,
                                    child: _QueueSheet(
                                      onClose: () {
                                        ref
                                                .read(
                                                  queueDockVisibleProvider
                                                      .notifier,
                                                )
                                                .state =
                                            false;
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [artwork, const SizedBox(height: 24), details],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo degradado (high/ultra con desenfoque simulado por gradientes suaves;
/// low/medium: superficie plana sin trabajo de GPU adicional).
class _AdaptiveBackground extends StatelessWidget {
  const _AdaptiveBackground({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.alphaBlend(
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.surface,
            ),
            scheme.surface,
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Portada: placeholder grande con nota musical. La extracción real de
/// carátulas ID3/MP4 llega en Fase 2.x; el widget ya reserva el espacio y
/// aplica Hero para transiciones fluidas en tiers altos.
class _CoverArt extends StatelessWidget {
  const _CoverArt({
    required this.size,
    required this.animate,
    required this.track,
  });

  final double size;
  final bool animate;
  final Track track;

  @override
  Widget build(BuildContext context) {
    final art = TrackArtwork(
      track: track,
      size: size,
      radius: animate ? 20 : 10,
    );
    if (!animate) return art;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Container(key: ValueKey(track.id), child: art),
    );
  }
}

/// Título + artista centrados, con AnimatedSwitcher opcional entre pistas.
class _TrackTitles extends StatelessWidget {
  const _TrackTitles({
    required this.title,
    required this.artist,
    required this.animate,
    required this.onArtistTap,
  });

  final String title;
  final String artist;
  final bool animate;
  final VoidCallback onArtistTap;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      key: ValueKey('$title|$artist'),
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: onArtistTap,
          icon: const Icon(Icons.person_search_rounded, size: 18),
          label: Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    if (!animate) return column;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: column,
    );
  }
}

/// Cola en un panel lateral/bottom sheet con reordenamiento por arrastre.
Future<void> showQueueSheet(BuildContext context, WidgetRef ref) {
  final desktop = MediaQuery.sizeOf(context).width >= 760;
  if (!desktop) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: const _QueueSheet(),
      ),
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar cola',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, _, _) => Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        child: Material(
          color: Theme.of(dialogContext).colorScheme.surfaceContainerLow,
          elevation: 18,
          child: SizedBox(
            width: 430,
            height: double.infinity,
            child: const _QueueSheet(),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

/// Panel de cola: pista actual primero, próximas después y anteriores al final.
/// Es solo una proyección visual; la cola real y sus índices no se alteran.
class _QueueSheet extends ConsumerStatefulWidget {
  const _QueueSheet({this.onClose});

  final VoidCallback? onClose;

  @override
  ConsumerState<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends ConsumerState<_QueueSheet> {
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  /// Deja la pista que acaba de comenzar en la parte superior de la cola.
  /// No se ejecuta al cambiar únicamente la duración o los metadatos.
  void _showCurrentFirst() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      audioPlayerControllerProvider.select((s) => s.currentTrack?.id),
      (previous, next) {
        if (previous != next) _showCurrentFirst();
      },
    );
    ref.listen<bool>(queueDockVisibleProvider, (previous, next) {
      if (next && previous != true) _showCurrentFirst();
    });

    final playback = ref.watch(audioPlayerControllerProvider);
    final queue = playback.queue;
    final currentIndex = playback.currentIndex;
    final autoRadio = playback.autoRadio;
    final visual = QueueVisualOrder(queue.length, currentIndex);
    final notifier = ref.read(audioPlayerControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
          child: Row(
            children: [
              Icon(Icons.queue_music_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cola de reproducción',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      autoRadio
                          ? '${queue.length} en pantalla · Radio continua'
                          : '${queue.length} canciones',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar cola',
                onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: queue.isEmpty
              ? const Center(child: Text('La cola está vacía'))
              : ReorderableListView.builder(
                  scrollController: _scrollController,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  itemCount: queue.length,
                  // La reordenación afecta solamente a las próximas pistas.
                  // La canción actual y el historial no se mueven sin reproducirlos.
                  onReorder: (oldVisual, newVisual) {
                    final target = visual.reorderIndices(oldVisual, newVisual);
                    if (target == null) return;
                    notifier.moveInQueue(target.$1, target.$2);
                  },
                  proxyDecorator: (child, index, animation) => Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    color: scheme.surfaceContainerHigh,
                    child: child,
                  ),
                  itemBuilder: (context, visualIndex) {
                    final sourceIndex = visual.sourceIndex(visualIndex);
                    final track = queue[sourceIndex];
                    final isCurrent = sourceIndex == currentIndex;
                    final isHistory = visual.isHistory(visualIndex);
                    final canReorder = visualIndex > 0 && !isHistory;
                    return Padding(
                      key: ValueKey('${track.id}#$sourceIndex'),
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (visualIndex == 1)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.skip_next_rounded,
                                    size: 16,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'A continuación',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          if (isHistory && visualIndex == visual.nextCount)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 16, 8, 9),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 16,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Escuchadas anteriormente',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          Material(
                            color: isCurrent
                                ? scheme.primaryContainer.withValues(
                                    alpha: 0.40,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: isCurrent
                                  ? null
                                  : () => notifier.playAt(sourceIndex),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(3, 7, 2, 7),
                                child: Row(
                                  children: [
                                    // Asa a la izquierda, antes de la portada.
                                    if (canReorder)
                                      ReorderableDragStartListener(
                                        index: visualIndex,
                                        child: const Tooltip(
                                          message: 'Arrastrar para reordenar',
                                          child: Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.drag_indicator_rounded,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          isCurrent
                                              ? Icons.graphic_eq_rounded
                                              : Icons.history_rounded,
                                          size: 20,
                                          color: isCurrent
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    const SizedBox(width: 3),
                                    TrackArtwork(track: track, size: 42),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isCurrent
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isCurrent
                                                  ? scheme.primary
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            track.displayArtist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      songDurationLabel(
                                        isCurrent
                                            ? (track.duration ??
                                                  playback.duration)
                                            : track.duration,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                    IconButton(
                                      tooltip: 'Quitar de la cola',
                                      visualDensity: VisualDensity.compact,
                                      iconSize: 17,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 36,
                                      ),
                                      onPressed: () =>
                                          notifier.removeFromQueue(sourceIndex),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
