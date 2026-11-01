/// Punto de entrada de Lyra.
///
/// Inicializa los bindings de Flutter, arranca el sistema de rendimiento
/// (detección de hardware) ANTES de pintar el primer frame para evitar
/// parpadeos con el tier equivocado, y envuelve toda la app en un
/// [ProviderScope] (Riverpod) que inyecta el router de GoRouter y el tema
/// adaptativo definidos en `lib/app/app.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lyra_music/app/app.dart';
import 'package:lyra_music/core/performance/performance_controller.dart';

Future<void> main() async {
  // Garantiza que los plugins (device_info_plus, battery_plus, etc.) estén
  // disponibles antes de cualquier lectura de hardware.
  WidgetsFlutterBinding.ensureInitialized();

  // Contenedor raíz de Riverpod: se crea aquí para poder esperar la
  // inicialización del controlador de rendimiento antes de runApp.
  final container = ProviderContainer();

  try {
    // Fuerza la construcción del PerformanceController y espera a que
    // termine la detección de hardware. Si falla, el propio controlador
    // degrada elegantemente al tier más bajo; nunca bloqueamos el arranque.
    await container
        .read(performanceControllerProvider.notifier)
        .waitUntilReady()
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  } catch (_) {
    // Silencioso a propósito: la app debe arrancar aunque la detección falle.
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const LyraApp()),
  );
}
