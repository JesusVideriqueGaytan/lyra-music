/// Define los "tiers" (niveles) de rendimiento de Lyra y la matriz de
/// características asociada a cada uno.
///
/// Esta capa es **puro dominio**: no depende de Flutter ni de plugins, por lo
/// que puede testearse unitariamente sin mocks complejos.
library;

/// Modos de funcionamiento del sistema de adaptación.
enum PerformanceMode {
  /// Detección automática del hardware (comportamiento por defecto).
  auto,

  /// Fuerza el tier bajo (ahorro máximo de recursos).
  low,

  /// Fuerza el tier medio.
  medium,

  /// Fuerza el tier alto.
  high,

  /// Fuerza el tier ultra (máxima calidad visual).
  ultra,

  /// Configuración granular definida por el usuario.
  custom,
}

/// Nivel de capacidad del hardware detectado o forzado por el usuario.
enum PerformanceTier {
  /// < 3GB RAM, CPU antiguo, pantalla HD.
  low,

  /// 4-6GB RAM, CPU medio.
  medium,

  /// 8GB+ RAM, CPU moderno, pantalla 2K+.
  high,

  /// 12GB+ RAM, GPU potente, pantalla 4K/120Hz.
  ultra;

  /// Cadena legible en español para mostrar en la UI.
  String get label {
    switch (this) {
      case PerformanceTier.low:
        return 'Bajo';
      case PerformanceTier.medium:
        return 'Medio';
      case PerformanceTier.high:
        return 'Alto';
      case PerformanceTier.ultra:
        return 'Ultra';
    }
  }

  /// Serialización estable para persistencia (SharedPreferences/Hive).
  String get storageKey => name;

  /// Deserialización segura; devuelve null si la clave no es válida.
  static PerformanceTier? fromStorageKey(String? key) {
    for (final tier in PerformanceTier.values) {
      if (tier.name == key) return tier;
    }
    return null;
  }
}

/// Descripción cruda del hardware leída por [HardwareDetector].
///
/// Es una estructura inmutable que alimenta la lógica de clasificación.
class HardwareInfo {
  const HardwareInfo({
    required this.totalMemoryBytes,
    required this.processorCount,
    required this.screenWidth,
    required this.screenHeight,
    required this.refreshRateHz,
    this.batteryLevelPercent,
    this.isCharging = false,
    this.deviceModel = 'unknown',
  });

  /// Memoria RAM total en bytes (0 si no se pudo leer).
  final int totalMemoryBytes;

  /// Número de núcleos lógicos de CPU.
  final int processorCount;

  /// Ancho de pantalla en píxeles físicos.
  final int screenWidth;

  /// Alto de pantalla en píxeles físicos.
  final int screenHeight;

  /// Tasa de refresco nominal de la pantalla (Hz). 0 = desconocido.
  final double refreshRateHz;

  /// Nivel de batería en porcentaje (null en dispositivos con alimentación
  /// de red, como desktop).
  final int? batteryLevelPercent;

  /// ¿Está el dispositivo cargando?
  final bool isCharging;

  /// Modelo del dispositivo (informativo).
  final String deviceModel;

  /// RAM total expresada en gigabytes binarios (GiB).
  double get memoryGb => totalMemoryBytes / (1024 * 1024 * 1024);

  /// Píxeles totales de la pantalla.
  int get totalPixels => screenWidth * screenHeight;

  /// Construye una copia con los campos especificados sobrescritos.
  HardwareInfo copyWith({
    int? totalMemoryBytes,
    int? processorCount,
    int? screenWidth,
    int? screenHeight,
    double? refreshRateHz,
    int? batteryLevelPercent,
    bool? isCharging,
    String? deviceModel,
  }) {
    return HardwareInfo(
      totalMemoryBytes: totalMemoryBytes ?? this.totalMemoryBytes,
      processorCount: processorCount ?? this.processorCount,
      screenWidth: screenWidth ?? this.screenWidth,
      screenHeight: screenHeight ?? this.screenHeight,
      refreshRateHz: refreshRateHz ?? this.refreshRateHz,
      batteryLevelPercent: batteryLevelPercent ?? this.batteryLevelPercent,
      isCharging: isCharging ?? this.isCharging,
      deviceModel: deviceModel ?? this.deviceModel,
    );
  }
}

/// Estilos de letras sincronizadas soportados.
enum LyricsMode {
  /// Solo letra estática en texto plano.
  simpleText,

  /// Resaltado de línea sincronizado.
  synced,

  /// Karaoke animado palabra por palabra.
  animatedKaraoke,
}

/// Estilos de transición entre pantallas.
enum TransitionStyle {
  /// Fundido simple (el más barato).
  fade,

  /// Deslizamiento lateral.
  slide,

  /// Zoom + Hero animations compartidas.
  zoomHero,

  /// Morphing de formas (Material Motion).
  morphing,
}

/// Matriz de características: define qué permite cada tier.
///
/// Implementa la tabla de adaptación dinámica de Lyra. Cada getter devuelve
/// el valor correspondiente al tier consultado. Funciones 100% puras para
/// facilitar su testing.
class TierFeatureMatrix {
  const TierFeatureMatrix._();

  // --- Animaciones -----------------------------------------------------

  /// ¿Se permiten animaciones complejas (staggered, morphing...)?
  static bool allowComplexAnimations(PerformanceTier tier) =>
      tier != PerformanceTier.low;

  /// Duración base de las animaciones del tier (ms). 0 = sin animación.
  static int animationDurationMs(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.low:
        return 0;
      case PerformanceTier.medium:
        return 200;
      case PerformanceTier.high:
        return 300;
      case PerformanceTier.ultra:
        return 350;
    }
  }

  // --- Efectos visuales ------------------------------------------------

  /// ¿Se permite BackdropFilter / blur? Solo High y Ultra.
  static bool allowBlur(PerformanceTier tier) =>
      tier == PerformanceTier.high || tier == PerformanceTier.ultra;

  /// ¿Se muestra el visualizador de audio? Medium en adelante.
  static bool allowAudioVisualizer(PerformanceTier tier) =>
      tier != PerformanceTier.low;

  // --- Letras (lyrics) ---------------------------------------------------

  /// Estilo de letras sincronizadas según el tier.
  static LyricsMode lyricsMode(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.low:
        // En gama baja solo texto simple (sin sincronización animada).
        return LyricsMode.simpleText;
      case PerformanceTier.medium:
      case PerformanceTier.high:
        return LyricsMode.synced;
      case PerformanceTier.ultra:
        return LyricsMode.animatedKaraoke;
    }
  }

  // --- Ecualizador -------------------------------------------------------

  /// Número de bandas del ecualizador gráfico (0 = desactivado).
  static int equalizerBands(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.low:
        return 0;
      case PerformanceTier.medium:
        return 5;
      case PerformanceTier.high:
        return 10;
      case PerformanceTier.ultra:
        return 32;
    }
  }

  // --- Streaming -----------------------------------------------------------

  /// Calidad máxima de streaming en kbps.
  static int streamingBitrateKbps(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.low:
        return 128;
      case PerformanceTier.medium:
        return 192;
      case PerformanceTier.high:
        return 256;
      case PerformanceTier.ultra:
        return 320;
    }
  }

  /// ¿Se permite FLAC/calidad lossless? Solo Ultra.
  static bool allowLossless(PerformanceTier tier) =>
      tier == PerformanceTier.ultra;

  // --- Caché ---------------------------------------------------------------

  /// Límite de caché en megabytes ([double.infinity] = ilimitado en Ultra).
  static double cacheLimitMb(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.low:
        return 256;
      case PerformanceTier.medium:
        return 1024;
      case PerformanceTier.high:
        return 4096;
      case PerformanceTier.ultra:
        return double.infinity;
    }
  }

  /// Número de canciones precargadas en buffer.
  static int preloadSongs(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.low:
        return 1;
      case PerformanceTier.medium:
        return 3;
      case PerformanceTier.high:
        return 10;
      case PerformanceTier.ultra:
        return 20;
    }
  }

  // --- Imágenes --------------------------------------------------------------

  /// Tamaño máximo (lado mayor) de las miniaturas en píxeles.
  static int maxImageSizePx(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.low:
        return 300;
      case PerformanceTier.medium:
        return 600;
      case PerformanceTier.high:
        return 1000;
      case PerformanceTier.ultra:
        return 1500;
    }
  }

  // --- Transiciones ------------------------------------------------------------

  /// Tipo de transición entre pantallas.
  static TransitionStyle transitionStyle(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.low:
        return TransitionStyle.fade;
      case PerformanceTier.medium:
        return TransitionStyle.slide;
      case PerformanceTier.high:
        return TransitionStyle.zoomHero;
      case PerformanceTier.ultra:
        return TransitionStyle.morphing;
    }
  }

  // --- Pantalla --------------------------------------------------------------------

  /// ¿Se debe forzar la tasa de refresco máxima? Solo Ultra.
  static bool forceMaxRefreshRate(PerformanceTier tier) =>
      tier == PerformanceTier.ultra;

  // --- Clasificación -----------------------------------------------------------------

  /// Umbral mínimo de puntuación para el tier Ultra.
  static const int ultraThreshold = 85;

  /// Umbral mínimo de puntuación para el tier High.
  static const int highThreshold = 55;

  /// Umbral mínimo de puntuación para el tier Medium.
  static const int mediumThreshold = 30;

  /// Puntúa el hardware (0-100) combinando RAM, núcleos, resolución y Hz.
  ///
  /// Se expone como función pura para poder testearla directamente.
  static int scoreHardware(HardwareInfo hw) {
    var score = 0;

    // RAM: hasta 40 puntos.
    final ram = hw.memoryGb;
    if (ram >= 12) {
      score += 40;
    } else if (ram >= 8) {
      score += 30;
    } else if (ram >= 4) {
      score += 20;
    } else if (ram > 0) {
      score += 8;
    }

    // Núcleos de CPU: hasta 30 puntos.
    final cores = hw.processorCount;
    if (cores >= 12) {
      score += 30;
    } else if (cores >= 8) {
      score += 24;
    } else if (cores >= 6) {
      score += 16;
    } else if (cores >= 4) {
      score += 10;
    } else if (cores >= 2) {
      score += 5;
    }

    // Resolución: hasta 20 puntos.
    final pixels = hw.totalPixels;
    if (pixels >= 3840 * 2160) {
      score += 20;
    } else if (pixels >= 2560 * 1440) {
      score += 15;
    } else if (pixels >= 1920 * 1080) {
      score += 10;
    } else if (pixels > 0) {
      score += 5;
    }

    // Tasa de refresco: hasta 10 puntos.
    if (hw.refreshRateHz >= 120) {
      score += 10;
    } else if (hw.refreshRateHz >= 90) {
      score += 6;
    } else if (hw.refreshRateHz > 0) {
      score += 3;
    }

    return score.clamp(0, 100);
  }

  /// Mapea una puntuación 0-100 a su tier correspondiente.
  static PerformanceTier tierFromScore(int score) {
    if (score >= ultraThreshold) return PerformanceTier.ultra;
    if (score >= highThreshold) return PerformanceTier.high;
    if (score >= mediumThreshold) return PerformanceTier.medium;
    return PerformanceTier.low;
  }

  /// Devuelve el tier inmediatamente inferior (low es el suelo).
  static PerformanceTier downgrade(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.ultra:
        return PerformanceTier.high;
      case PerformanceTier.high:
        return PerformanceTier.medium;
      case PerformanceTier.medium:
      case PerformanceTier.low:
        return PerformanceTier.low;
    }
  }

  /// Clasifica automáticamente un [HardwareInfo] en un [PerformanceTier].
  ///
  /// Reglas adicionales:
  ///  - Sin datos de memoria (0 bytes) => tier bajo por seguridad
  ///    (degradación elegante ante fallos de detección).
  ///  - Batería crítica (< 20%) sin cargar => tier bajo en automático.
  static PerformanceTier classifyHardware(HardwareInfo hw) {
    if (hw.totalMemoryBytes <= 0) return PerformanceTier.low;

    var tier = tierFromScore(scoreHardware(hw));

    // Degradación por batería baja: nunca sube el tier, solo lo baja.
    final battery = hw.batteryLevelPercent;
    if (battery != null && !hw.isCharging && battery < 20) {
      tier = PerformanceTier.low;
    }

    return tier;
  }

  /// Resuelve el tier efectivo dado un [PerformanceMode] y la detección
  /// automática. Los modos manuales ignoran por completo el hardware.
  static PerformanceTier resolveTier({
    required PerformanceMode mode,
    required PerformanceTier detectedTier,
  }) {
    switch (mode) {
      case PerformanceMode.auto:
      case PerformanceMode.custom:
        // En modo custom la matriz base es la detectada; los ajustes
        // granulares se aplican encima en AdaptiveFeatures.
        return detectedTier;
      case PerformanceMode.low:
        return PerformanceTier.low;
      case PerformanceMode.medium:
        return PerformanceTier.medium;
      case PerformanceMode.high:
        return PerformanceTier.high;
      case PerformanceMode.ultra:
        return PerformanceTier.ultra;
    }
  }
}
