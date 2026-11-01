/// Controles principales del reproductor: shuffle, prev, play/pause, next,
/// repeat + deslizador de volumen.
///
/// Adaptación por tier:
///  - La duración del "pulse" del botón play se toma de [AdaptiveFeatures]
///    (0 ms en tier low = sin animación).
///  - En tiers sin animaciones usamos iconos Material planos; en tiers altos
///    el cambio play->pause se anima con [AnimatedSwitcher].
library;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lyra_music/core/performance/adaptive_features.dart';
import 'package:lyra_music/core/performance/performance_controller.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key, this.compact = false});

  /// Modo compacto para paneles estrechos (diálogos, modo landscape).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(adaptiveFeaturesProvider);
    final playing = ref.watch(
      audioPlayerControllerProvider.select((s) => s.playing),
    );
    final buffering = ref.watch(
      audioPlayerControllerProvider.select((s) => s.buffering),
    );
    final shuffle = ref.watch(
      audioPlayerControllerProvider.select((s) => s.shuffleEnabled),
    );
    final repeat = ref.watch(
      audioPlayerControllerProvider.select((s) => s.repeatMode),
    );
    final volume = ref.watch(
      audioPlayerControllerProvider.select((s) => s.volume),
    );
    final hasQueue = ref.watch(
      audioPlayerControllerProvider.select((s) => s.queue.isNotEmpty),
    );

    final notifier = ref.read(audioPlayerControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    // Duración de transiciones según hardware; 0 en tier low.
    final durationMs = features.animationDurationMs;
    final animate = features.canUseAnimations && durationMs > 0;

    Widget maybeAnimate(Widget child) {
      if (!animate) return child;
      return AnimatedSwitcher(
        duration: Duration(milliseconds: durationMs ~/ 2),
        child: child,
      );
    }

    final iconSize = compact ? 24.0 : 30.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Shuffle.
            IconButton(
              tooltip: shuffle
                  ? 'Aleatorio: activado'
                  : 'Aleatorio: desactivado',
              onPressed: hasQueue ? notifier.toggleShuffle : null,
              icon: Icon(Icons.shuffle_rounded),
              color: shuffle ? scheme.primary : null,
              iconSize: iconSize * 0.8,
            ),

            // Anterior.
            IconButton(
              tooltip: 'Anterior',
              onPressed: hasQueue ? () => notifier.previous() : null,
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: iconSize * 1.2,
            ),

            // Play/Pause grande.
            maybeAnimate(
              _PlayButton(
                playing: playing,
                buffering: buffering,
                animate: animate,
                durationMs: durationMs,
                onPressed: notifier.togglePlayPause,
              ),
            ),

            // Siguiente.
            IconButton(
              tooltip: 'Siguiente',
              onPressed: hasQueue ? () => notifier.next() : null,
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: iconSize * 1.2,
            ),

            // Repeat (ciclo off -> all -> one).
            IconButton(
              tooltip: repeat.label,
              onPressed: hasQueue ? notifier.toggleRepeat : null,
              icon: Icon(switch (repeat) {
                RepeatMode.one => Icons.repeat_one_on_rounded,
                RepeatMode.all => Icons.repeat_on_rounded,
                RepeatMode.off => Icons.repeat_rounded,
              }),
              color: repeat != RepeatMode.off ? scheme.primary : null,
              iconSize: iconSize * 0.8,
            ),
          ],
        ),

        // Control de volumen: solo en la versión completa del panel.
        if (!compact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              children: <Widget>[
                Icon(
                  volume == 0
                      ? Icons.volume_off_rounded
                      : volume < 0.5
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Slider(
                    value: volume,
                    onChanged: (v) => notifier.setVolume(v),
                    activeColor: scheme.primary,
                  ),
                ),
                Text(
                  '${(volume * 100).round()}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Botón principal de reproducción: círculo grande con estado de carga.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.buffering,
    required this.animate,
    required this.durationMs,
    required this.onPressed,
  });

  final bool playing;
  final bool buffering;
  final bool animate;
  final int durationMs;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Durante el buffering mostramos un spinner pequeño en lugar del icono,
    // señal visual de que just_audio está preparando el archivo.
    final IconData icon = playing
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;

    final core = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: animate
            ? RadialGradient(
                colors: <Color>[
                  scheme.primary,
                  Color.alphaBlend(
                    Colors.black26,
                    scheme.primary,
                  ), // Variante "oscurecida" del primario, sin APIs experimentales.
                ],
              )
            : null,
        color: animate ? null : scheme.primary,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          // Sin ripple en tier low: menos trabajo de composición por frame.
          splashColor: animate ? null : Colors.transparent,
          highlightColor: animate ? null : Colors.transparent,
          child: Center(
            child: buffering
                ? SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.onPrimary,
                    ),
                  )
                : Icon(icon, size: 40, color: scheme.onPrimary),
          ),
        ),
      ),
    );

    if (!animate) return core;
    return AnimatedScale(
      duration: Duration(milliseconds: durationMs),
      scale: playing ? 1.0 : 0.94,
      curve: Curves.easeOutBack,
      child: core,
    );
  }
}
