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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          currentTrack.album,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        leading: IconButton(
          tooltip: 'Contraer',
          // go-pop: si el usuario llegó desde el MiniPlayer, regresa a la
          // pantalla anterior; si abrió /player directo, va a la biblioteca.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/library'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cola de reproducción',
            onPressed: () => showQueueSheet(context, ref),
            icon: const Icon(Icons.queue_music_rounded),
          ),
        ],
      ),
      // Banner de error de reproducción: se muestra como SnackBar persistente
      // mientras exista (el controller lo limpia al reproducir otra pista).
      bottomNavigationBar: error != null
          ? MaterialBanner(
                content: Text(error),
                backgroundColor: scheme.errorContainer,
                actions: <Widget>[
                  TextButton(
                    onPressed: () => context.go('/library'),
                    child: const Text('Buscar otra canción'),
                  ),
                ],
              )
          : null,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _AdaptiveBackground(animate: animate),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // En pantallas anchas (desktop/landscape) limitamos
                        // la portada al menor de: alto disponible o el tope
                        // del tier convertido a px lógicos (~px * 0.66).
                        final tierCap = (features.maxImageSizePx * 0.66)
                            .roundToDouble();
                        final side = constraints.biggest.shortestSide.clamp(
                          180.0,
                          tierCap,
                        );
                        return Center(
                          child: _CoverArt(
                            size: side,
                            animate: animate,
                            trackTitle: currentTrack.title,
                          ),
                        );
                      },
                    ),
                  ),
                  // Título y artista con animación de cambio de pista solo
                  // si el hardware lo permite.
                  _TrackTitles(
                    title: currentTrack.title,
                    artist: currentTrack.artist,
                    animate: animate,
                  ),
                  const SizedBox(height: 16),
                  const ProgressBar(),
                  const SizedBox(height: 8),
                  const PlayerControls(),
                ],
              ),
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
    required this.trackTitle,
  });

  final double size;
  final bool animate;
  final String trackTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final art = Container(
      width: size,
      height: size,
      key: ValueKey(trackTitle),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(animate ? 20 : 8),
        boxShadow: animate
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.4,
        color: scheme.onPrimaryContainer,
      ),
    );

    if (!animate) return art;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      child: art,
    );
  }
}

/// Título + artista centrados, con AnimatedSwitcher opcional entre pistas.
class _TrackTitles extends StatelessWidget {
  const _TrackTitles({
    required this.title,
    required this.artist,
    required this.animate,
  });

  final String title;
  final String artist;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
        Text(
          artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
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
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => const _QueueSheet(),
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
    final notifier = ref.read(audioPlayerControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    if (queue.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'La cola está vacía',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: ListView.builder(
        itemCount: queue.length,
        itemBuilder: (context, index) {
          final track = queue[index];
          final isCurrent = index == currentIndex;
          return ListTile(
            selected: isCurrent,
            selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.35),
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: isCurrent
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  color: isCurrent ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: 'Subir',
                  visualDensity: VisualDensity.compact,
                  onPressed: index > 0
                      ? () => notifier.moveInQueue(index, index - 1)
                      : null,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Bajar',
                  visualDensity: VisualDensity.compact,
                  onPressed: index < queue.length - 1
                      ? () => notifier.moveInQueue(index, index + 1)
                      : null,
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Quitar de la cola',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => notifier.removeFromQueue(index),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
