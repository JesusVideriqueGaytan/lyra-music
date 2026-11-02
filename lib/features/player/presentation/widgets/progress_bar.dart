/// Barra de progreso arrastrable del reproductor (widget compartido).
///
/// Se usa tanto en NowPlayingScreen (grande) como opcionalmente en vistas
/// compactas. Dos detalles de UX importantes:
///  - Mientras el usuario arrastra, mostramos la posición *local* del slider
///    (no la del stream) para que el pulgar no "luche" contra las actualiza-
///    ciones de `positionStream`.
///  - Al soltar, hacemos seek real una sola vez.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';

/// Formatea duraciones como `m:ss` o `h:mm:ss` según corresponda.
String formatPlaybackDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final twoDigitSeconds = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$twoDigitSeconds';
  }
  return '$minutes:$twoDigitSeconds';
}

class ProgressBar extends ConsumerStatefulWidget {
  const ProgressBar({super.key, this.compact = false});

  /// Versión compacta para el MiniPlayer: sin tiempos laterales y más fina.
  final bool compact;

  @override
  ConsumerState<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends ConsumerState<ProgressBar> {
  /// Posición temporal mientras se arrastra (null = seguir el stream).
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    // Escuchamos SOLO los campos necesarios: un rebuild por tick de posición
    // es inevitable, pero con select evitamos reconstruir cuando cambian
    // otros campos (cola, volumen, etc.).
    final playbackPosition = ref.watch(
      audioPlayerControllerProvider.select<Duration>((s) => s.position),
    );
    final Duration position = _dragPosition ?? playbackPosition;
    final duration = ref.watch(
      audioPlayerControllerProvider.select((s) => s.duration),
    );

    final totalMs = duration?.inMilliseconds ?? 0;
    // clamp devuelve num en SDK <3.x; forzamos int para el Slider.
    final currentMs = position.inMilliseconds.clamp(0, totalMs == 0 ? 0 : totalMs).toInt();
    final scheme = Theme.of(context).colorScheme;

    void handleDrag(double value) {
      setState(() => _dragPosition = Duration(milliseconds: value.round()));
    }

    Future<void> handleDragEnd(double value) async {
      final target = Duration(milliseconds: value.round());
      // Buscamos primero; limpiamos el estado local después para evitar el
      // parpadeo del pulgar volviendo a la posición vieja por un frame.
      await ref.read(audioPlayerControllerProvider.notifier).seek(target);
      if (mounted) setState(() => _dragPosition = null);
    }

    if (totalMs == 0) {
      // Sin duración conocida (archivo corrupto o aún cargando): barra
      // indeterminada para comunicar actividad sin mentir con un 0%.
      return LinearProgressIndicator(
        minHeight: widget.compact ? 2 : 4,
        borderRadius: BorderRadius.circular(2),
      );
    }

    if (widget.compact) {
      return SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
        ),
        child: Slider(
          value: currentMs.toDouble(),
          max: totalMs.toDouble(),
          onChanged: handleDrag,
          onChangeEnd: handleDragEnd,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Slider(
          value: currentMs.toDouble(),
          max: totalMs.toDouble(),
          activeColor: scheme.primary,
          onChanged: handleDrag,
          onChangeEnd: handleDragEnd,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Tiempo transcurrido.
              Text(
                formatPlaybackDuration(position),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              // Tiempo restante (formato negativo, estándar en música).
              Text(
                '-${formatPlaybackDuration(duration! - position)}',
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
