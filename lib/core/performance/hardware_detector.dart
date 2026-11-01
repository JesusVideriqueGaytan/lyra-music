/// Detección de hardware multiplataforma para Lyra.
///
/// Versión simplificada y estable: usa `device_info_plus` (RAM, núcleos,
/// modelo), `battery_plus` (nivel de batería) y [dart:io] como fallback.
/// La lógica de clasificación vive en [TierFeatureMatrix] (capa de dominio,
/// en `performance_tier.dart`); aquí solo se lee hardware crudo.
library;

import 'dart:io' as io;

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:lyra_music/core/performance/performance_tier.dart';

/// Clase de servicio que lee el hardware y recomienda un tier.
///
/// Es deliberadamente una clase normal (no un Provider) para poder inyectarla
/// y mockearla en tests. El [PerformanceController] la consume vía Riverpod.
class HardwareDetector {
  HardwareDetector({
    DeviceInfoPlugin? deviceInfoPlugin,
    Battery? battery,
    HardwareInfo Function()? infoOverride,
  }) : _deviceInfo = deviceInfoPlugin ?? DeviceInfoPlugin(),
       _battery = battery ?? Battery(),
       _infoOverride = infoOverride;

  final DeviceInfoPlugin _deviceInfo;
  final Battery _battery;

  /// Permite inyectar una fuente de hardware falsa en tests o previews.
  final HardwareInfo Function()? _infoOverride;

  /// Lee toda la información de hardware disponible.
  ///
  /// Nunca lanza: cualquier fallo parcial degrada los valores a 0/null,
  /// lo que la matriz interpreta como "hardware desconocido" (tier bajo).
  Future<HardwareInfo> readHardwareInfo() async {
    if (_infoOverride != null) return _infoOverride();

    try {
      final base = await _deviceInfo.deviceInfo;
      var totalMemoryBytes = 0;
      var processorCount = 1;
      var deviceModel = 'unknown';

      if (base is AndroidDeviceInfo) {
        // El plugin no expone la RAM en Android; se usará /proc/meminfo.
        totalMemoryBytes = 0;
        processorCount = _fallbackProcessorCount();
        deviceModel = '${base.manufacturer} ${base.model}';
      } else if (base is IosDeviceInfo) {
        // physicalRamSize está en bytes (iOS 16+; 0 en versiones previas).
        totalMemoryBytes = base.physicalRamSize;
        processorCount = _fallbackProcessorCount();
        deviceModel = base.model;
      } else if (base is LinuxDeviceInfo) {
        // Linux no expone RAM vía plugin: fallback a /proc/meminfo abajo.
        totalMemoryBytes = 0;
        processorCount = _fallbackProcessorCount();
        deviceModel = base.prettyName;
      } else if (base is WindowsDeviceInfo) {
        // systemMemoryInMegabytes viene en MB: convertir a bytes.
        totalMemoryBytes = base.systemMemoryInMegabytes * 1024 * 1024;
        processorCount = base.numberOfCores > 0
            ? base.numberOfCores
            : _fallbackProcessorCount();
        deviceModel = base.computerName;
      } else if (base is MacOsDeviceInfo) {
        // memorySize en bytes, activeCPUs núcleos lógicos.
        totalMemoryBytes = base.memorySize;
        processorCount = base.activeCPUs > 0
            ? base.activeCPUs
            : _fallbackProcessorCount();
        deviceModel = base.modelName;
      }

      // Si Android u otros no expusieron RAM, intentar por /proc/meminfo.
      if (totalMemoryBytes <= 0) {
        totalMemoryBytes = _fallbackMemoryBytes();
      }

      final batteryLevel = await _getBatteryLevel();

      return HardwareInfo(
        totalMemoryBytes: totalMemoryBytes,
        processorCount: processorCount,
        screenWidth: 0,
        screenHeight: 0,
        refreshRateHz: 0,
        batteryLevelPercent: batteryLevel,
        isCharging: false,
        deviceModel: deviceModel,
      );
    } catch (_) {
      // Degradación elegante: hardware ilegible => datos mínimos.
      return const HardwareInfo(
        totalMemoryBytes: 0,
        processorCount: 1,
        screenWidth: 0,
        screenHeight: 0,
        refreshRateHz: 0,
      );
    }
  }

  /// Detecta el tier recomendado leyendo el hardware actual.
  Future<PerformanceTier> detectTier() async {
    final hw = await readHardwareInfo();
    return TierFeatureMatrix.classifyHardware(hw);
  }

  /// Obtiene el nivel de batería de forma segura (null si no hay batería).
  Future<int?> _getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      // Plataformas desktop sin batería o permisos denegados.
      return null;
    }
  }

  /// Fallback multiplataforma para leer la RAM total en bytes.
  ///
  /// En Linux/macOS lee `/proc/meminfo` o `sysctl`; si falla devuelve 0.
  int _fallbackMemoryBytes() {
    try {
      if (io.Platform.isLinux) {
        final meminfo = io.File('/proc/meminfo').readAsLinesSync();
        for (final line in meminfo) {
          if (line.startsWith('MemTotal:')) {
            final kb =
                int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return kb * 1024;
          }
        }
      } else if (io.Platform.isMacOS || io.Platform.isIOS) {
        final result = io.Process.runSync('sysctl', ['-n', 'hw.memsize']);
        if (result.exitCode == 0) {
          return int.tryParse(result.stdout.toString().trim()) ?? 0;
        }
      }
    } catch (_) {
      // Silencioso: devolveremos 0 y la matriz degradará a tier bajo.
    }
    return 0;
  }

  /// Número de núcleos lógicos disponibles en la plataforma actual.
  int _fallbackProcessorCount() {
    try {
      return io.Platform.numberOfProcessors;
    } catch (_) {
      return 1;
    }
  }

  /// Benchmark rápido (CPU-bound) para estimar capacidad de cómputo.
  ///
  /// Devuelve el tiempo en segundos que tarda una operación aritmética
  /// fija. Menor tiempo => hardware más rápido. Útil como criterio extra
  /// cuando la metadata del dispositivo es insuficiente.
  Future<double> runQuickBenchmark() async {
    final stopwatch = Stopwatch()..start();
    double result = 0;
    // Bucle determinista: se optimiza pero no se elimina (dependencia de data).
    for (var i = 0; i < 1000000; i++) {
      result += i * 1.0000001;
    }
    stopwatch.stop();
    // Evitar warning de variable no usada en modo debug.
    assert(result > 0);
    return stopwatch.elapsedMicroseconds / 1000000.0;
  }
}
