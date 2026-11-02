/// Objeto inmutable que encapsula las características activas del tier
/// actual. La UI y los servicios consumen esta clase en lugar de preguntar
/// directamente por el enum [PerformanceTier], lo que facilita añadir
/// overrides "custom" del usuario en el futuro sin tocar los widgets.
library;

import 'package:lyra_music/core/performance/performance_tier.dart';

/// Snapshot de capacidades disponibles en este momento.
class AdaptiveFeatures {
  const AdaptiveFeatures({
    required this.tier,
    required this.canUseAnimations,
    required this.animationDurationMs,
    required this.canUseBlur,
    required this.canUseVisualizer,
    required this.lyricsMode,
    required this.equalizerBands,
    required this.streamingBitrateKbps,
    required this.canUseLossless,
    required this.cacheLimitMb,
    required this.preloadSongs,
    required this.maxImageSizePx,
    required this.transitionStyle,
    required this.forceMaxRefreshRate,
  });

  /// Construye las características derivadas exclusivamente de la matriz
  /// del tier indicado (sin overrides del usuario).
  factory AdaptiveFeatures.fromTier(PerformanceTier tier) {
    return AdaptiveFeatures(
      tier: tier,
      canUseAnimations: TierFeatureMatrix.allowComplexAnimations(tier),
      animationDurationMs: TierFeatureMatrix.animationDurationMs(tier),
      canUseBlur: TierFeatureMatrix.allowBlur(tier),
      canUseVisualizer: TierFeatureMatrix.allowAudioVisualizer(tier),
      lyricsMode: TierFeatureMatrix.lyricsMode(tier),
      equalizerBands: TierFeatureMatrix.equalizerBands(tier),
      streamingBitrateKbps: TierFeatureMatrix.streamingBitrateKbps(tier),
      canUseLossless: TierFeatureMatrix.allowLossless(tier),
      cacheLimitMb: TierFeatureMatrix.cacheLimitMb(tier),
      preloadSongs: TierFeatureMatrix.preloadSongs(tier),
      maxImageSizePx: TierFeatureMatrix.maxImageSizePx(tier),
      transitionStyle: TierFeatureMatrix.transitionStyle(tier),
      forceMaxRefreshRate: TierFeatureMatrix.forceMaxRefreshRate(tier),
    );
  }

  /// Tier efectivo del que se derivan estas características.
  final PerformanceTier tier;

  /// Animaciones complejas habilitadas.
  final bool canUseAnimations;

  /// Duración base de animaciones en ms (0 = sin animación).
  final int animationDurationMs;

  /// BackdropFilter / blur habilitado.
  final bool canUseBlur;

  /// Visualizador de audio habilitado.
  final bool canUseVisualizer;

  /// Modo de renderizado de letras sincronizadas.
  final LyricsMode lyricsMode;

  /// Bandas del ecualizador gráfico (0 = desactivado).
  final int equalizerBands;

  /// Bitrate máximo de streaming en kbps.
  final int streamingBitrateKbps;

  /// Audio lossless (FLAC) permitido.
  final bool canUseLossless;

  /// Límite de caché en MB (double.infinity = sin límite).
  final double cacheLimitMb;

  /// Canciones precargadas en buffer.
  final int preloadSongs;

  /// Lado máximo de miniaturas en píxeles.
  final int maxImageSizePx;

  /// Estilo de transición entre rutas.
  final TransitionStyle transitionStyle;

  /// Forzar tasa de refresco máxima (solo Ultra + Android).
  final bool forceMaxRefreshRate;

  /// Duración tipográfica segura para usar en AnimationController/Duration.
  Duration get animationDuration =>
      Duration(milliseconds: animationDurationMs);

  /// Copia con overrides parciales (base del modo "custom").
  AdaptiveFeatures copyWith({
    bool? canUseAnimations,
    int? animationDurationMs,
    bool? canUseBlur,
    bool? canUseVisualizer,
    LyricsMode? lyricsMode,
    int? equalizerBands,
    int? streamingBitrateKbps,
    bool? canUseLossless,
    double? cacheLimitMb,
    int? preloadSongs,
    int? maxImageSizePx,
    TransitionStyle? transitionStyle,
    bool? forceMaxRefreshRate,
  }) {
    return AdaptiveFeatures(
      tier: tier,
      canUseAnimations: canUseAnimations ?? this.canUseAnimations,
      animationDurationMs: animationDurationMs ?? this.animationDurationMs,
      canUseBlur: canUseBlur ?? this.canUseBlur,
      canUseVisualizer: canUseVisualizer ?? this.canUseVisualizer,
      lyricsMode: lyricsMode ?? this.lyricsMode,
      equalizerBands: equalizerBands ?? this.equalizerBands,
      streamingBitrateKbps: streamingBitrateKbps ?? this.streamingBitrateKbps,
      canUseLossless: canUseLossless ?? this.canUseLossless,
      cacheLimitMb: cacheLimitMb ?? this.cacheLimitMb,
      preloadSongs: preloadSongs ?? this.preloadSongs,
      maxImageSizePx: maxImageSizePx ?? this.maxImageSizePx,
      transitionStyle: transitionStyle ?? this.transitionStyle,
      forceMaxRefreshRate: forceMaxRefreshRate ?? this.forceMaxRefreshRate,
    );
  }

  @override
  String toString() =>
      'AdaptiveFeatures(tier: ${tier.name}, blur: $canUseBlur, '
      'img: $maxImageSizePx px, cache: $cacheLimitMb MB)';
}
