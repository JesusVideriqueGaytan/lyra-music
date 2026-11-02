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
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/collection_actions.dart';
import 'package:lyra_music/features/downloads/desktop_download.dart';

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
          // go-pop: si el usuario llegó desde el MiniPlayer, regresa a la
          // pantalla anterior; si abrió /player directo, va a la biblioteca.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/library'),
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
                final side =
                    (wide
                            ? (bounds.maxHeight * 0.72)
                            : (bounds.maxHeight * 0.48))
                        .clamp(140.0, wide ? 440.0 : 340.0);
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
                        artist: currentTrack.artist,
                        animate: animate,
                        onArtistTap: () =>
                            context.push('/artist', extra: currentTrack),
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
                              tooltip:
                                  'Guardar audio autorizado en el dispositivo',
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
                        onPressed: () => showQueueSheet(context, ref),
                        icon: const Icon(Icons.queue_music_rounded),
                        label: const Text('Ver cola de reproducción'),
                      ),
                    ],
                  ),
                );
                if (wide) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                    child: Row(
                      children: [
                        Expanded(child: Center(child: artwork)),
                        const SizedBox(width: 26),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Center(child: details),
                          ),
                        ),
                      ],
                    ),
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

/// Bottom sheet con la cola: canción actual resaltada y botones básicos de
/// reordenar/subir-bajar y quitar (sin drag & drop complejo, según spec).
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

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(
      audioPlayerControllerProvider.select((s) => s.queue),
    );
    final currentIndex = ref.watch(
      audioPlayerControllerProvider.select((s) => s.currentIndex),
    );
    final autoRadio = ref.watch(
      audioPlayerControllerProvider.select((s) => s.autoRadio),
    );
    final notifier = ref.read(audioPlayerControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
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
                          ? '${queue.length} canciones · Radio automática'
                          : '${queue.length} canciones',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar cola',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: queue.isEmpty
              ? const Center(child: Text('La cola está vacía'))
              : ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    final isCurrent = index == currentIndex;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: ListTile(
                        selected: isCurrent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        selectedTileColor: scheme.primaryContainer.withValues(
                          alpha: 0.35,
                        ),
                        leading: TrackArtwork(track: track, size: 48),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: isCurrent
                              ? TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary,
                                )
                              : null,
                        ),
                        subtitle: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => notifier.playAt(index),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Opciones de la cola',
                          onSelected: (value) {
                            if (value == 'up') {
                              notifier.moveInQueue(index, index - 1);
                            } else if (value == 'down') {
                              notifier.moveInQueue(index, index + 1);
                            } else if (value == 'remove') {
                              notifier.removeFromQueue(index);
                            }
                          },
                          itemBuilder: (_) => [
                            if (index > 0)
                              const PopupMenuItem(
                                value: 'up',
                                child: Text('Subir'),
                              ),
                            if (index < queue.length - 1)
                              const PopupMenuItem(
                                value: 'down',
                                child: Text('Bajar'),
                              ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Quitar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
