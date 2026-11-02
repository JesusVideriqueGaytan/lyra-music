/// Tests unitarios de la lógica pura de clasificación de hardware y de la
/// matriz de características por tier (sin plugins, sin UI).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/core/performance/adaptive_features.dart';
import 'package:lyra_music/core/performance/performance_tier.dart';

void main() {
  group('TierFeatureMatrix.classifyHardware', () {
    test('Gama baja: poca RAM y pocos núcleos => low', () {
      const hw = HardwareInfo(
        totalMemoryBytes: 2 * 1024 * 1024 * 1024, // 2 GB
        processorCount: 2,
        screenWidth: 1280,
        screenHeight: 720,
        refreshRateHz: 60,
      );
      expect(TierFeatureMatrix.classifyHardware(hw), PerformanceTier.low);
    });

    test('Gama media típica => medium', () {
      const hw = HardwareInfo(
        totalMemoryBytes: 4 * 1024 * 1024 * 1024, // 4 GB
        processorCount: 6,
        screenWidth: 1920,
        screenHeight: 1080,
        refreshRateHz: 60,
      );
      expect(TierFeatureMatrix.classifyHardware(hw), PerformanceTier.medium);
    });

    test('Gama alta: 8+ GB, muchos núcleos, FHD+ => high', () {
      const hw = HardwareInfo(
        totalMemoryBytes: 8 * 1024 * 1024 * 1024,
        processorCount: 8,
        screenWidth: 2560,
        screenHeight: 1440,
        refreshRateHz: 90,
      );
      expect(TierFeatureMatrix.classifyHardware(hw), PerformanceTier.high);
    });

    test('Ultra: 12+ GB, 120 Hz, 4K => ultra', () {
      const hw = HardwareInfo(
        totalMemoryBytes: 16 * 1024 * 1024 * 1024,
        processorCount: 12,
        screenWidth: 3840,
        screenHeight: 2160,
        refreshRateHz: 120,
      );
      expect(TierFeatureMatrix.classifyHardware(hw), PerformanceTier.ultra);
    });

    test('Batería crítica (<20%) sin cargar degrada a low', () {
      const hw = HardwareInfo(
        totalMemoryBytes: 16 * 1024 * 1024 * 1024,
        processorCount: 12,
        screenWidth: 3840,
        screenHeight: 2160,
        refreshRateHz: 120,
        batteryLevelPercent: 15,
        isCharging: false,
      );
      expect(TierFeatureMatrix.classifyHardware(hw), PerformanceTier.low);
    });

    test(
      'Hardware desconocido (ceros) no revienta: devuelve un tier válido',
      () {
        const hw = HardwareInfo(
          totalMemoryBytes: 0,
          processorCount: 0,
          screenWidth: 0,
          screenHeight: 0,
          refreshRateHz: 0,
        );
        final tier = TierFeatureMatrix.classifyHardware(hw);
        expect(PerformanceTier.values, contains(tier));
      },
    );
  });

  test('Batería: 20% conserva tier; 19% limita salvo al cargar', () {
    const hw = HardwareInfo(
      totalMemoryBytes: 16 * 1024 * 1024 * 1024,
      processorCount: 12,
      screenWidth: 3840,
      screenHeight: 2160,
      refreshRateHz: 120,
      batteryLevelPercent: 20,
    );
    expect(TierFeatureMatrix.classifyHardware(hw), PerformanceTier.ultra);
    expect(
      TierFeatureMatrix.classifyHardware(hw.copyWith(batteryLevelPercent: 19)),
      PerformanceTier.low,
    );
    expect(
      TierFeatureMatrix.classifyHardware(
        hw.copyWith(batteryLevelPercent: 19, isCharging: true),
      ),
      PerformanceTier.ultra,
    );
    expect(
      TierFeatureMatrix.resolveTier(
        mode: PerformanceMode.high,
        detectedTier: PerformanceTier.low,
      ),
      PerformanceTier.high,
    );
  });

  group('AdaptiveFeatures.fromTier (matriz de características)', () {
    test('low: sin blur, sin animaciones, imágenes 300px, caché 256MB', () {
      final f = AdaptiveFeatures.fromTier(PerformanceTier.low);
      expect(f.canUseBlur, isFalse);
      expect(f.canUseAnimations, isFalse);
      expect(f.canUseVisualizer, isFalse);
      expect(f.maxImageSizePx, 300);
      expect(f.cacheLimitMb, 256);
      expect(f.preloadSongs, 1);
      expect(f.equalizerBands, 0);
      expect(f.streamingBitrateKbps, 128);
      expect(f.canUseLossless, isFalse);
    });

    test('medium: animaciones sí, blur no, EQ 5 bandas, 192kbps', () {
      final f = AdaptiveFeatures.fromTier(PerformanceTier.medium);
      expect(f.canUseAnimations, isTrue);
      expect(f.canUseBlur, isFalse);
      expect(f.canUseVisualizer, isTrue);
      expect(f.equalizerBands, 5);
      expect(f.streamingBitrateKbps, 192);
      expect(f.preloadSongs, 3);
    });

    test('high: blur activado, imágenes 1000px, EQ 10 bandas', () {
      final f = AdaptiveFeatures.fromTier(PerformanceTier.high);
      expect(f.canUseBlur, isTrue);
      expect(f.maxImageSizePx, 1000);
      expect(f.equalizerBands, 10);
    });

    test('ultra: todo activado, lossless, 32 bandas, refresco forzado', () {
      final f = AdaptiveFeatures.fromTier(PerformanceTier.ultra);
      expect(f.canUseBlur, isTrue);
      expect(f.canUseAnimations, isTrue);
      expect(f.canUseLossless, isTrue);
      expect(f.equalizerBands, 32);
      expect(f.forceMaxRefreshRate, isTrue);
      expect(f.preloadSongs, 20);
    });

    test('La matriz es monótona: calidad de imagen crece con el tier', () {
      final low = AdaptiveFeatures.fromTier(PerformanceTier.low);
      final medium = AdaptiveFeatures.fromTier(PerformanceTier.medium);
      final high = AdaptiveFeatures.fromTier(PerformanceTier.high);
      final ultra = AdaptiveFeatures.fromTier(PerformanceTier.ultra);
      expect(low.maxImageSizePx, lessThan(medium.maxImageSizePx));
      expect(medium.maxImageSizePx, lessThan(high.maxImageSizePx));
      expect(high.maxImageSizePx, lessThan(ultra.maxImageSizePx));
    });

    test('El tier queda registrado en las features', () {
      for (final tier in PerformanceTier.values) {
        expect(AdaptiveFeatures.fromTier(tier).tier, tier);
      }
    });
  });

  group('Presentación legible en español', () {
    test('Todos los tiers tienen etiqueta no vacía y clave de storage', () {
      for (final tier in PerformanceTier.values) {
        expect(tier.label, isNotEmpty);
        expect(tier.storageKey, tier.name);
      }
    });

    test('fromStorageKey round-trip y tolerancia a claves inválidas', () {
      for (final tier in PerformanceTier.values) {
        expect(PerformanceTier.fromStorageKey(tier.storageKey), tier);
      }
      expect(PerformanceTier.fromStorageKey('no-existe'), isNull);
      expect(PerformanceTier.fromStorageKey(null), isNull);
    });
  });
}
