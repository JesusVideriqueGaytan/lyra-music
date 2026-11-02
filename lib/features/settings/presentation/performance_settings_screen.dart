/// Pantalla de configuración de rendimiento de Lyra.
///
/// Simplifica la interacción para que el usuario entienda mejor la diferencia
/// entre la lógica de selección (Automático / Manual / Personalizado) y el
/// nivel base de rendimiento.
library;

import 'package:flutter/material.dart';
import 'package:lyra_music/shared/widgets/lyra_section_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/core/performance/adaptive_features.dart';
import 'package:lyra_music/core/performance/performance_controller.dart';
import 'package:lyra_music/core/performance/performance_tier.dart';

class PerformanceSettingsScreen extends ConsumerWidget {
  const PerformanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceControllerProvider);
    final controller = ref.read(performanceControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final uiMode = _uiModeFor(state.mode);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rendimiento adaptativo'),
        leading: IconButton(
          tooltip: 'Volver a la biblioteca',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/library'),
        ),
        actions: [
          IconButton(
            tooltip: 'Recalcular detección',
            icon: const Icon(Icons.refresh),
            onPressed: state.isLoading ? null : controller.recalculate,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const LyraSectionBanner(
            icon: Icons.speed_rounded,
            eyebrow: 'RENDIMIENTO',
            title: 'Tu equipo, tu ritmo',
            subtitle: 'Ajusta recursos y efectos a tu dispositivo.',
          ),
          const SizedBox(height: 18),
          _StatusCard(state: state, scheme: scheme),
          const SizedBox(height: 16),
          Text('Modo de rendimiento', style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Automático detecta el hardware. Manual te deja elegir un nivel fijo. '
            'Personalizado servirá para desbloquear ajustes granulares.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Automático'),
                selected: uiMode == _UiMode.auto,
                onSelected: (_) => controller.resetToAuto(),
              ),
              ChoiceChip(
                label: const Text('Manual'),
                selected: uiMode == _UiMode.manual,
                onSelected: (_) => controller.setTier(state.currentTier),
              ),
              ChoiceChip(
                label: const Text('Personalizado'),
                selected: uiMode == _UiMode.custom,
                onSelected: (_) => controller.setMode(PerformanceMode.custom),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (uiMode == _UiMode.manual) ...[
            Text('Nivel de rendimiento', style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Elige la intensidad base de recursos que Lyra debe usar de forma fija.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tier in PerformanceTier.values)
                  FilterChip(
                    label: Text(tier.label),
                    selected: state.currentTier == tier,
                    onSelected: (_) => controller.setTier(tier),
                  ),
              ],
            ),
          ],
          if (uiMode == _UiMode.auto) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'En Automático, Lyra toma decisiones según tu hardware para conservar el principio de ser ligera y adaptable.',
                  style: textTheme.bodyMedium,
                ),
              ),
            ),
          ],
          if (uiMode == _UiMode.custom) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personalizado', style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Aquí conviene desbloquear controles por característica (animaciones, blur, visualizador, caché, etc.). Por ahora Lyra usa el nivel actual como base visible, pero la siguiente iteración debe convertir esta sección en un personalizador granular real.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tier in PerformanceTier.values)
                          FilterChip(
                            label: Text('Base ${tier.label}'),
                            selected: state.currentTier == tier,
                            onSelected: (_) => controller.setTier(tier),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Características activas', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          _FeaturesTable(features: state.features),
          const SizedBox(height: 24),
          if (state.hardwareInfo != null) ...[
            Text('Hardware detectado', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            _HardwareInfoTile(info: state.hardwareInfo!),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.enableBatterySaver,
        icon: const Icon(Icons.battery_saver),
        label: const Text('Ahorro de batería'),
      ),
    );
  }
}

enum _UiMode { auto, manual, custom }

_UiMode _uiModeFor(PerformanceMode mode) {
  switch (mode) {
    case PerformanceMode.auto:
      return _UiMode.auto;
    case PerformanceMode.custom:
      return _UiMode.custom;
    case PerformanceMode.low:
    case PerformanceMode.medium:
    case PerformanceMode.high:
    case PerformanceMode.ultra:
      return _UiMode.manual;
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state, required this.scheme});

  final PerformanceState state;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  state.isLoading ? Icons.hourglass_top : Icons.speed,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nivel actual: ${state.currentTier.label}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (state.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_tierDescription(state.currentTier)),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: scheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _tierDescription(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.low:
        return 'Optimizado para ahorrar recursos y batería.';
      case PerformanceTier.medium:
        return 'Equilibrio entre fluidez y consumo moderado.';
      case PerformanceTier.high:
        return 'Apuesta por mejor experiencia visual y animaciones.';
      case PerformanceTier.ultra:
        return 'Máxima calidad disponible para hardware potente.';
    }
  }
}

class _FeaturesTable extends StatelessWidget {
  const _FeaturesTable({required this.features});

  final AdaptiveFeatures features;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Animaciones complejas', features.canUseAnimations ? 'Sí' : 'No'),
      ('Blur / BackdropFilter', features.canUseBlur ? 'Sí' : 'No'),
      ('Visualizador de audio', features.canUseVisualizer ? 'Sí' : 'No'),
      ('Letras sincronizadas', _lyricsLabel(features.lyricsMode)),
      (
        'Ecualizador',
        features.equalizerBands == 0
            ? 'Desactivado'
            : '${features.equalizerBands} bandas',
      ),
      ('Streaming', '${features.streamingBitrateKbps} kbps'),
      (
        'Caché máxima',
        features.cacheLimitMb.isInfinite
            ? 'Ilimitada'
            : '${features.cacheLimitMb.toInt()} MB',
      ),
      ('Precarga', '${features.preloadSongs} canciones'),
      ('Transiciones', _transitionLabel(features.transitionStyle)),
      ('Calidad de imágenes', '${features.maxImageSizePx} px'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(row.$1)),
                    const SizedBox(width: 12),
                    Text(
                      row.$2,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _lyricsLabel(LyricsMode mode) {
    switch (mode) {
      case LyricsMode.simpleText:
        return 'Texto simple';
      case LyricsMode.synced:
        return 'Sincronizada';
      case LyricsMode.animatedKaraoke:
        return 'Karaoke animado';
    }
  }

  static String _transitionLabel(TransitionStyle style) {
    switch (style) {
      case TransitionStyle.fade:
        return 'Fundido';
      case TransitionStyle.slide:
        return 'Deslizamiento';
      case TransitionStyle.zoomHero:
        return 'Zoom + Hero';
      case TransitionStyle.morphing:
        return 'Morphing';
    }
  }
}

class _HardwareInfoTile extends StatelessWidget {
  const _HardwareInfoTile({required this.info});

  final HardwareInfo info;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Dispositivo', info.deviceModel),
      ('Memoria RAM', '${info.memoryGb.toStringAsFixed(1)} GB'),
      ('Núcleos de CPU', '${info.processorCount}'),
      ('Pantalla', '${info.screenWidth} × ${info.screenHeight}'),
      (
        'Frecuencia',
        info.refreshRateHz == 0
            ? 'Desconocida'
            : '${info.refreshRateHz.toStringAsFixed(0)} Hz',
      ),
      (
        'Batería',
        info.batteryLevelPercent == null
            ? 'No disponible'
            : '${info.batteryLevelPercent}%',
      ),
      ('Cargando', info.isCharging ? 'Sí' : 'No'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(row.$1)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
