/// Controlador de rendimiento de Lyra (capa de presentación/dominio).
///
/// Gestiona el [PerformanceMode] (auto/manual), calcula el tier efectivo,
/// persiste la preferencia del usuario en SharedPreferences y expone un
/// [AdaptiveFeatures] listo para consumir por la UI vía Riverpod.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lyra_music/core/performance/adaptive_features.dart';
import 'package:lyra_music/core/performance/hardware_detector.dart';
import 'package:lyra_music/core/performance/performance_tier.dart';

/// Claves de persistencia estables.
const String _kModeKey = 'lyra_performance_mode';
const String _kTierKey = 'lyra_performance_tier';

/// Estado inmutable del sistema de rendimiento.
class PerformanceState {
  const PerformanceState({
    required this.mode,
    required this.detectedTier,
    required this.currentTier,
    required this.features,
    this.hardwareInfo,
    this.isLoading = false,
    this.error,
  });

  /// Estado inicial neutro antes de la primera detección.
  static final PerformanceState initial = PerformanceState(
    mode: PerformanceMode.auto,
    detectedTier: PerformanceTier.medium,
    currentTier: PerformanceTier.medium,
    features: AdaptiveFeatures.fromTier(PerformanceTier.medium),
    isLoading: true,
  );

  /// Modo actual (auto o forzado por el usuario).
  final PerformanceMode mode;

  /// Tier detectado automáticamente por el hardware (referencia en modo custom).
  final PerformanceTier detectedTier;

  /// Tier efectivo tras resolver modo + detección.
  final PerformanceTier currentTier;

  /// Características activas derivadas del tier efectivo.
  final AdaptiveFeatures features;

  /// Última lectura de hardware (null hasta completar la detección).
  final HardwareInfo? hardwareInfo;

  /// ¿Hay una detección/recálculo en curso?
  final bool isLoading;

  /// Mensaje de error legible si algo falló (nunca fatal: se degrada a low).
  final String? error;

  PerformanceState copyWith({
    PerformanceMode? mode,
    PerformanceTier? detectedTier,
    PerformanceTier? currentTier,
    AdaptiveFeatures? features,
    HardwareInfo? hardwareInfo,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PerformanceState(
      mode: mode ?? this.mode,
      detectedTier: detectedTier ?? this.detectedTier,
      currentTier: currentTier ?? this.currentTier,
      features: features ?? this.features,
      hardwareInfo: hardwareInfo ?? this.hardwareInfo,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier que orquesta la detección y el override manual del tier.
class PerformanceController extends Notifier<PerformanceState> {
  // El detector se resuelve desde [hardwareDetectorProvider] dentro de build()
  // (los Notifier de Riverpod 2.x no reciben dependencias por constructor).
  HardwareDetector? _detector;
  SharedPreferences? _prefs;

  @override
  PerformanceState build() {
    _detector = ref.read(hardwareDetectorProvider);
    // La carga es asincrónica pero no bloqueamos build(): arrancamos con
    // un estado "isLoading" y publicamos el resultado cuando llegue.
    // Guardamos la future para que main.dart pueda aguardarla antes del
    // primer frame (evita parpadeos con el tier equivocado).
    _initFuture = _initialize();
    return PerformanceState.initial;
  }

  /// Future de la inicialización en curso (o ya completada). Expuesta vía
  /// [waitUntilReady] para permitir un arranque determinista desde main().
  Future<void>? _initFuture;

  /// Permite al punto de entrada esperar a que termine la primera detección
  /// de hardware + carga de preferencias persistidas.
  Future<void> waitUntilReady() => _initFuture ?? Future.value();

  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Si SharedPreferences falla seguimos con valores por defecto.
      _prefs = null;
    }
    await _detectAndApply();
  }

  /// Lee el hardware, resuelve el tier efectivo y actualiza el estado.
  Future<void> _detectAndApply() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final hw = await _detector!.readHardwareInfo();
      final detected = TierFeatureMatrix.classifyHardware(hw);
      final mode = _readSavedMode();
      final effective = _resolveEffectiveTier(mode: mode, detected: detected);

      state = PerformanceState(
        mode: mode,
        detectedTier: detected,
        currentTier: effective,
        features: AdaptiveFeatures.fromTier(effective),
        hardwareInfo: hw,
        isLoading: false,
      );
    } catch (e) {
      // Degradación elegante: ante cualquier fallo, tier bajo.
      state = state.copyWith(
        currentTier: PerformanceTier.low,
        features: AdaptiveFeatures.fromTier(PerformanceTier.low),
        isLoading: false,
        error: 'No se pudo detectar el hardware ($e). '
            'Se aplicó el nivel Bajo por seguridad.',
      );
    }
  }

  PerformanceMode _readSavedMode() {
    final raw = _prefs?.getString(_kModeKey);
    return PerformanceMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => PerformanceMode.auto,
    );
  }

  /// Combina el modo guardado con la detección para obtener el tier real.
  PerformanceTier _resolveEffectiveTier({
    required PerformanceMode mode,
    required PerformanceTier detected,
  }) {
    if (mode == PerformanceMode.auto || mode == PerformanceMode.custom) {
      return TierFeatureMatrix.resolveTier(mode: mode, detectedTier: detected);
    }
    // Modo manual: priorizar el tier explícitamente guardado por el usuario;
    // si no hay uno guardado, usar el tier homónimo al modo seleccionado.
    final savedTier =
        PerformanceTier.fromStorageKey(_prefs?.getString(_kTierKey));
    return savedTier ?? _tierFromManualMode(mode) ?? detected;
  }

  /// Mapea un modo manual a su tier correspondiente (auto/custom => null).
  PerformanceTier? _tierFromManualMode(PerformanceMode mode) {
    switch (mode) {
      case PerformanceMode.low:
        return PerformanceTier.low;
      case PerformanceMode.medium:
        return PerformanceTier.medium;
      case PerformanceMode.high:
        return PerformanceTier.high;
      case PerformanceMode.ultra:
        return PerformanceTier.ultra;
      case PerformanceMode.auto:
      case PerformanceMode.custom:
        return null;
    }
  }

  /// Cambia el modo de rendimiento y persiste la preferencia.
  Future<void> setMode(PerformanceMode mode) async {
    await _prefs?.setString(_kModeKey, mode.name);
    final effective = _resolveEffectiveTier(
      mode: mode,
      detected: state.detectedTier,
    );
    state = state.copyWith(
      mode: mode,
      currentTier: effective,
      features: AdaptiveFeatures.fromTier(effective),
    );
  }

  /// Asigna un tier manual. Cambiar de tier implica salir de "auto":
  /// si venías de auto/custom se pasa al modo manual homónimo.
  Future<void> setTier(PerformanceTier tier) async {
    final newMode = state.mode == PerformanceMode.auto
        ? _manualModeFor(tier)
        : state.mode;
    await _prefs?.setString(_kTierKey, tier.name);
    await _prefs?.setString(_kModeKey, newMode.name);
    state = state.copyWith(
      mode: newMode,
      currentTier: tier,
      features: AdaptiveFeatures.fromTier(tier),
    );
  }

  PerformanceMode _manualModeFor(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.low:
        return PerformanceMode.low;
      case PerformanceTier.medium:
        return PerformanceMode.medium;
      case PerformanceTier.high:
        return PerformanceMode.high;
      case PerformanceTier.ultra:
        return PerformanceMode.ultra;
    }
  }

  /// Recalcula el tier desde cero (nueva lectura de hardware).
  Future<void> recalculate() => _detectAndApply();

  /// Fuerza el modo ahorro de batería: tier bajo + modo manual low.
  Future<void> enableBatterySaver() => setTier(PerformanceTier.low);

  /// Devuelve el control al modo automático.
  Future<void> resetToAuto() => setMode(PerformanceMode.auto);
}

// Provider del detector de hardware (separado para poder mockearlo).
// En tests se sobrescribe con `ProviderScope(overrides: [...])`.
final hardwareDetectorProvider = Provider<HardwareDetector>((ref) {
  return HardwareDetector();
});

// Provider principal del controlador de rendimiento. El notifier resuelve
// sus dependencias dentro de build() vía `ref`, por lo que la factory es
// simplemente el constructor por defecto. En tests se mockea el detector:
// `ProviderScope(overrides: [hardwareDetectorProvider.overrideWithValue(...)])`.
final performanceControllerProvider =
    NotifierProvider<PerformanceController, PerformanceState>(
  PerformanceController.new,
);

/// Atajo de lectura solo para las características adaptativas.
final adaptiveFeaturesProvider = Provider<AdaptiveFeatures>((ref) {
  return ref.watch(performanceControllerProvider).features;
});

/// Atajo de lectura solo para el tier efectivo.
final currentTierProvider = Provider<PerformanceTier>((ref) {
  return ref.watch(performanceControllerProvider).currentTier;
});
