/// Test de humo del widget raíz de Lyra.
///
/// Verifica que la app se construye sin excepciones bajo un ProviderScope,
/// con SharedPreferences simulado (el controller lo usa en build()).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/app/app.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/core/performance/hardware_detector.dart';
import 'package:lyra_music/core/performance/performance_controller.dart';
import 'package:lyra_music/core/performance/performance_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detección de hardware simulada para tests: device_info_plus y battery_plus
/// no funcionan en el entorno de flutter_test (sin plugins reales), así que
/// se inyecta este stub con valores deterministas.
class _StubHardwareDetector implements HardwareDetector {
  @override
  Future<HardwareInfo> readHardwareInfo() async => const HardwareInfo(
        totalMemoryBytes: 8 * 1024 * 1024 * 1024,
        processorCount: 8,
        screenWidth: 1920,
        screenHeight: 1080,
        refreshRateHz: 60,
        batteryLevelPercent: 85,
        isCharging: false,
        deviceModel: 'test-stub',
      );

  @override
  Future<PerformanceTier> detectTier() async => PerformanceTier.high;

  @override
  Future<double> runQuickBenchmark() async => 0.1;
}

class _StubAudioController extends AudioPlayerController {
  @override
  PlaybackState build() => const PlaybackState();
}

void main() {
  setUp(() {
    // Valores por defecto para que el controlador no falle al persistir.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lyra_performance_mode': 'auto',
    });
  });

  testWidgets('LyraApp renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerControllerProvider.overrideWith(_StubAudioController.new),
          hardwareDetectorProvider.overrideWithValue(_StubHardwareDetector()),
        ],
        child: const LyraApp(),
      ),
    );
    // Varios frames finitos: suficiente para resolver los futures de
    // SharedPreferences/detección sin depender de pumpAndSettle (la UI
    // muestra un CircularProgressIndicator infinito mientras carga).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // La app debe mostrar una MaterialApp y la biblioteca.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Biblioteca'), findsWidgets);
  });

  testWidgets('LyraApp shows the library screen initially',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerControllerProvider.overrideWith(_StubAudioController.new),
          hardwareDetectorProvider.overrideWithValue(_StubHardwareDetector()),
        ],
        child: const LyraApp(),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // El AppBar de la pantalla inicial debe ser visible.
    expect(find.byType(AppBar), findsOneWidget);
  });
}
