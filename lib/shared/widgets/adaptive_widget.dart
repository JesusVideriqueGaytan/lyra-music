/// Widgets adaptativos de Lyra.
///
/// [AdaptiveWidget] permite renderizar una versión "completa" o una versión
/// degradada del mismo widget según el tier de rendimiento efectivo, leyendo
/// el estado desde Riverpod. También se incluye [AdaptiveBlurContainer], que
/// aplica BackdropFilter solo cuando el tier lo permite.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lyra_music/core/performance/adaptive_features.dart';
import 'package:lyra_music/core/performance/performance_controller.dart';
import 'package:lyra_music/core/performance/performance_tier.dart';

/// Builder que recibe el tier y las características activas.
typedef AdaptiveWidgetBuilder =
    Widget Function(
      BuildContext context,
      PerformanceTier tier,
      AdaptiveFeatures features,
    );

/// Wrapper genérico que elige entre dos representaciones según el tier.
///
/// Uso típico:
/// ```dart
/// AdaptiveWidget(
///   low: (context, tier, features) => const FlatCard(),
///   high: (context, tier, features) => const AnimatedGlassCard(),
/// )
/// ```
/// Si solo se proporciona [builder], se renderiza siempre pero exponiendo
/// las características para decisiones internas (p. ej. duraciones).
class AdaptiveWidget extends ConsumerWidget {
  const AdaptiveWidget({
    super.key,
    this.low,
    this.medium,
    this.high,
    this.ultra,
    this.builder,
    this.tierOverride,
  }) : assert(
         low != null || builder != null,
         'AdaptiveWidget requiere al menos un builder (low o builder).',
       );

  /// Versión degradada máxima (tier low, o fallback de todos los tiers).
  final AdaptiveWidgetBuilder? low;

  /// Versión para tier medium. Si es null cae en [low].
  final AdaptiveWidgetBuilder? medium;

  /// Versión para tier high. Si es null cae en [medium] o [low].
  final AdaptiveWidgetBuilder? high;

  /// Versión para tier ultra. Si es null cae en [high], [medium] o [low].
  final AdaptiveWidgetBuilder? ultra;

  /// Builder único con acceso a las características (alternativa a los slots).
  final AdaptiveWidgetBuilder? builder;

  /// Permite forzar un tier (previews/tests). Null = leer del controller.
  final PerformanceTier? tierOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = tierOverride != null
        ? AdaptiveFeatures.fromTier(tierOverride!)
        : ref.watch(adaptiveFeaturesProvider);
    final tier = features.tier;

    // Cascada de degradación: ultra -> high -> medium -> low.
    final selected = switch (tier) {
      PerformanceTier.ultra => ultra ?? high ?? medium ?? low ?? builder,
      PerformanceTier.high => high ?? medium ?? low ?? builder,
      PerformanceTier.medium => medium ?? low ?? builder,
      PerformanceTier.low => low ?? builder,
    };

    // builder tiene prioridad si no hay slot específico definido.
    final effective = selected ?? builder;
    if (effective == null) {
      // Invariante protegido por el assert del constructor.
      return const SizedBox.shrink();
    }
    return effective(context, tier, features);
  }
}

/// Contenedor que aplica blur solo si el tier actual lo permite.
///
/// En tiers low/medium devuelve un [Container] plano equivalente, evitando
/// el coste de GPU de [ui.BackdropFilter].
class AdaptiveBlurContainer extends ConsumerWidget {
  const AdaptiveBlurContainer({
    super.key,
    required this.child,
    this.blurSigma = 12.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.backgroundOpacity = 0.65,
    this.borderColor,
  });

  final Widget child;
  final double blurSigma;
  final BorderRadius borderRadius;
  final double backgroundOpacity;
  final Color? borderColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(adaptiveFeaturesProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!features.canUseBlur) {
      // Degradación elegante: superficie sólida sin filtro de fondo.
      return Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor ?? scheme.outlineVariant),
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: backgroundOpacity),
            borderRadius: borderRadius,
            border: Border.all(color: borderColor ?? scheme.outlineVariant),
          ),
          child: child,
        ),
      ),
    );
  }
}
