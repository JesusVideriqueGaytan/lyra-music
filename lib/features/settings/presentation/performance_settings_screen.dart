/// Pantalla de configuración de rendimiento de Lyra (Fase 1).
///
/// Permite ver el tier detectado, cambiar entre modo automático y manual,
/// forzar un tier concreto y consultar la matriz de características activa.
library;

import 'package:flutter/material.dart';
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
        padding: const EdgeInsets.all(16),
        children: [
          // --- Tarjeta de estado actual -----------------------------------
          _StatusCard(state: state, scheme: scheme),

          const SizedBox(height: 16),

          // --- Selector de modo --------------------------------------------
          Text('Modo de selección', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in PerformanceMode.values)
                ChoiceChip(
                  label: Text(_modeLabel(mode)),
                  selected: state.mode == mode,
                  onSelected: (_) => controller.setMode(mode),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // --- Selector de tier manual --------------------------------------
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nivel de rendimiento',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (state.mode == PerformanceMode.auto)
                Icon(Icons.lock_outline, size: 18, color: scheme.outline),
            ],
          ),
          if (state.mode == PerformanceMode.auto)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'En modo Automático el nivel lo decide la detección de '
                'hardware. Elige un modo manual para forzarlo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
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

          const SizedBox(height: 24),

          // --- Matriz de características activas -----------------------------
          Text(
            'Características activas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _FeaturesTable(features: state.features),

          const SizedBox(height: 24),

          // --- Información de hardware detectada ------------------------------
          if (state.hardwareInfo != null) ...[
            Text(
              'Hardware detectado',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _HardwareInfoTile(info: state.hardwareInfo!),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => controller.enableBatterySaver(),
        icon: const Icon(Icons.battery_saver),
        label: const Text('Ahorro de batería'),
      ),
    );
  }

  String _modeLabel(PerformanceMode mode) {
    switch (mode) {
      case PerformanceMode.auto:
        return 'Automático';
      case PerformanceMode.low:
        return 'Manual · Bajo';
      case PerformanceMode.medium:
        return 'Manual · Medio';
      case PerformanceMode.high:
        return 'Manual · Alto';
      case PerformanceMode.ultra:
        return 'Manual · Ultra';
      case PerformanceMode.custom:
        return 'Personalizado';
    }
  }
}

/// Tarjeta superior con el tier efectivo y avisos de carga/error.
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
                  state.isLoading
                      ? Icons.hourglass_top
                      : Icons.speed,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Nivel actual: ${state.currentTier.label}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (state.isLoading) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
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
        return 'Optimizado para dispositivos antiguos o con pocos recursos.';
      case PerformanceTier.medium:
        return 'Equilibrio entre rendimiento y calidad visual.';
      case PerformanceTier.high:
        return 'Alta calidad visual manteniendo buen rendimiento.';
      case PerformanceTier.ultra:
        return 'Máxima calidad: blur, karaoke animado y lossless.';
    }
  }
}

/// Tabla resumen de las características del tier activo.
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
      ('Ecualizador', features.equalizerBands == 0
          ? 'Desactivado'
          : '${features.equalizerBands} bandas'),
      ('Streaming', '${features.streamingBitrateKbps} kbps'
          '${features.canUseLossless ? ' + FLAC' : ''}'),
      ('Caché máxima', features.cacheLimitMb.isInfinite
          ? 'Ilimitada'
          : '${features.cacheLimitMb.toInt()} MB'),
      ('Precarga', '${features.preloadSongs} canciones'),
      ('Transiciones', _transitionLabel(features.transitionStyle)),
      ('Calidad de imágenes', '${features.maxImageSizePx} px'),
    ];

    return Card(
      child: Column(
        children: [
          for (final row in rows)
            ListTile(
              dense: true,
              title: Text(row.$1),
              trailing: Text(
                row.$2,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _lyricsLabel(LyricsMode mode) {
    switch (mode) {
      case LyricsMode.simpleText:
        return 'Texto simple';
      case LyricsMode.synced:
        return 'Sincronizada';
      case LyricsMode.animatedKaraoke:
        return 'Karaoke animado';
    }
  }

  String _transitionLabel(TransitionStyle style) {
    switch (style) {
      case TransitionStyle.fade:
        return 'Fade simple';
      case TransitionStyle.slide:
        return 'Slide';
      case TransitionStyle.zoomHero:
        return 'Zoom + Hero';
      case TransitionStyle.morphing:
        return 'Morphing';
    }
  }
}

/// Detalle de la lectura cruda de hardware.
class _HardwareInfoTile extends StatelessWidget {
  const _HardwareInfoTile({required this.info});

  final HardwareInfo info;

  @override
  Widget build(BuildContext context) {
    final ram = info.memoryGb > 0
        ? '${info.memoryGb.toStringAsFixed(1)} GB'
        : 'Desconocida';
    final battery = info.batteryLevelPercent != null
        ? '${info.batteryLevelPercent}% ${info.isCharging ? '(cargando)' : ''}'
        : 'Sin batería (desktop)';

    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: const Text('Dispositivo'),
            trailing: Text(info.deviceModel),
          ),
          ListTile(
            dense: true,
            title: const Text('Memoria RAM'),
            trailing: Text(ram),
          ),
          ListTile(
            dense: true,
            title: const Text('Núcleos de CPU'),
            trailing: Text('${info.processorCount}'),
          ),
          ListTile(
            dense: true,
            title: const Text('Batería'),
            trailing: Text(battery),
          ),
        ],
      ),
    );
  }
}
