/// MiniPlayer persistente en la parte inferior de la pantalla.
///
/// Ocupa espacio dentro de la estructura de navegación para que no tape
/// las pantallas ni los botones inferiores.
/// Reglas de adaptación por tier:
///  - Fondo con blur solo si [AdaptiveFeatures.canUseBlur] (high/ultra).
///  - Animación de entrada/expandir solo si [AdaptiveFeatures.canUseAnimations].
///  - Portada a resolución reducida según [AdaptiveFeatures.maxImageSizePx].
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/core/performance/adaptive_features.dart';
import 'package:lyra_music/core/performance/performance_controller.dart';
import 'package:lyra_music/core/performance/performance_tier.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/player/presentation/widgets/progress_bar.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solo escuchamos los campos que dibujan el mini-player; los ticks de
    // posición NO reconstruyen esta barra (la escucha ProgressBar internamente).
    final currentTrack = ref.watch(
      audioPlayerControllerProvider.select((s) => s.currentTrack),
    );
    final playing = ref.watch(
      audioPlayerControllerProvider.select((s) => s.playing),
    );
    final features = ref.watch(adaptiveFeaturesProvider);

    if (currentTrack == null) {
      // Sin canción cargada: no ocupamos espacio en pantalla.
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(audioPlayerControllerProvider.notifier);
    final animate = features.canUseAnimations;

    // Tamaño de portada derivado del tier: en gama baja reducimos 4px el
    // cuadro para ganar densidad en pantallas pequeñas.
    final coverDisplaySize = features.tier == PerformanceTier.low ? 44.0 : 48.0;

    // Tamaño estable: evita el conflicto de RenderAnimatedSize durante layout
    // cuando cambia el contenido mientras la barra de progreso actualiza.
    return Material(
      elevation: animate ? 6 : 0,
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: _MiniPlayerBackground(
          enabledBlur: features.canUseBlur,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Barra de progreso ultra-compacta en el borde superior.
              const ProgressBar(compact: true),
              InkWell(
                // Tap en el cuerpo -> abre la pantalla Now Playing.
                onTap: () => context.go('/player'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: <Widget>[
                      // Portada (placeholder con nota musical si no hay carátula).
                      TrackArtwork(
                        track: currentTrack,
                        size: coverDisplaySize,
                        radius: 9,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              currentTrack.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              currentTrack.displayArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 640)
                        IconButton(
                          tooltip: 'Agregar o quitar de favoritos',
                          icon: Icon(
                            ref
                                    .watch(musicCollectionProvider)
                                    .isFavorite(currentTrack)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                          onPressed: () => ref
                              .read(musicCollectionProvider.notifier)
                              .toggleFavorite(currentTrack),
                        ),
                      if (MediaQuery.sizeOf(context).width >= 540)
                        IconButton(
                          tooltip: 'Anterior',
                          onPressed: notifier.previous,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                      IconButton(
                        tooltip: playing ? 'Pausar' : 'Reproducir',
                        onPressed: notifier.togglePlayPause,
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Siguiente',
                        onPressed: notifier.next,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
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

/// Fondo del mini-player: blur real en tiers altos, superficie plana si no.
class _MiniPlayerBackground extends StatelessWidget {
  const _MiniPlayerBackground({required this.enabledBlur, required this.child});

  final bool enabledBlur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!enabledBlur) {
      return ColoredBox(color: scheme.surfaceContainerHigh, child: child);
    }
    // RepaintBoundary aislado: el BackdropFilter repintarse no arrastra al
    // resto de la jerarquía (clave en gama media con listas largas detrás).
    return RepaintBoundary(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: ColoredBox(
          color: scheme.surface.withValues(alpha: 0.72),
          child: child,
        ),
      ),
    );
  }
}
