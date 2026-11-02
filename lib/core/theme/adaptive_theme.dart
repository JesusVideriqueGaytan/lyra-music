/// Configuración de temas adaptativos de Lyra (Material 3).
///
/// Soporta cuatro variantes: Claro, Oscuro, AMOLED puro (#000000) y Dynamic
/// Color (Material You, cuando el SO lo permite). El color semilla se puede
/// personalizar; en AMOLED se fuerza superficie negra absoluta.
library;

import 'package:flutter/material.dart';

/// Variantes de tema disponibles para el usuario.
enum AppThemeVariant {
  /// Tema claro basado en Material 3.
  light,

  /// Tema oscuro "estándar" (grises elevados).
  dark,

  /// Negro puro #000000: apagado real de píxeles en pantallas OLED.
  amoled,

  /// Dinámico: deriva del color de acento del sistema (Material You).
  dynamic,
}

/// Extensión con etiquetas legibles en español para la UI.
extension AppThemeVariantX on AppThemeVariant {
  String get label {
    switch (this) {
      case AppThemeVariant.light:
        return 'Claro';
      case AppThemeVariant.dark:
        return 'Oscuro';
      case AppThemeVariant.amoled:
        return 'AMOLED (negro puro)';
      case AppThemeVariant.dynamic:
        return 'Dinámico (Material You)';
    }
  }

  /// Serialización estable para persistencia.
  String get storageKey => name;
}

/// Deserialización segura de [AppThemeVariant] con fallback a oscuro.
/// (Función de top-level: los enums no pueden tener métodos estáticos.)
AppThemeVariant appThemeVariantFromStorageKey(String? key) {
  for (final variant in AppThemeVariant.values) {
    if (variant.name == key) return variant;
  }
  // Fallback seguro: oscuro estándar si la clave es desconocida.
  return AppThemeVariant.dark;
}

/// Fábrica de [ThemeData] de Lyra.
class AdaptiveTheme {
  const AdaptiveTheme._();

  /// Color semilla por defecto (índigo musical de la marca Lyra).
  static const Color defaultSeed = Color(0xFF6750A4);

  /// Negro absoluto para el modo AMOLED.
  static const Color pureBlack = Color(0xFF000000);

  /// Devuelve el [ThemeData] correspondiente a una variante.
  ///
  /// [useDynamic]: si es true y la variante es [AppThemeVariant.dynamic],
  /// se espera que el llamador (app.dart) envuelva con `dynamic_color` y
  /// pase aquí el esquema ya generado vía [fromScheme].
  static ThemeData build(
    AppThemeVariant variant, {
    Color seed = defaultSeed,
    ColorScheme? dynamicScheme,
  }) {
    switch (variant) {
      case AppThemeVariant.light:
        return _base(ColorScheme.fromSeed(seedColor: seed), Brightness.light);
      case AppThemeVariant.dark:
        return _base(
          ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
          Brightness.dark,
        );
      case AppThemeVariant.amoled:
        return _amoled(seed);
      case AppThemeVariant.dynamic:
        // Si no hay esquema dinámico real (SO sin Material You o plugin no
        // disponible), degradar elegantemente al tema oscuro por semilla.
        final scheme =
            dynamicScheme ??
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
        return _base(scheme, scheme.brightness);
    }
  }

  /// Construye un tema desde un esquema pregenerado (usado por Dynamic Color).
  static ThemeData fromScheme(ColorScheme scheme) =>
      _base(scheme, scheme.brightness);

  /// Tema base compartido: tipografía, formas y componentes M3.
  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        color: scheme.surfaceContainerLow,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? scheme.surfaceContainer : scheme.surface,
        elevation: 3,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Variante AMOLED: parte del esquema oscuro pero fuerza negros absolutos
  /// en superficies, scaffolds y diálogos para ahorrar batería en OLED.
  static ThemeData _amoled(Color seed) {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    final amoledScheme = darkScheme.copyWith(
      surface: pureBlack,
      surfaceContainerLowest: pureBlack,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF121212),
      surfaceContainerHigh: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFF222222),
      onSurface: const Color(0xFFE6E6E6),
    );
    final theme = _base(amoledScheme, Brightness.dark);
    return theme.copyWith(
      // Diálogos y menús también en negro puro.
      dialogTheme: DialogThemeData(backgroundColor: pureBlack),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: pureBlack),
      popupMenuTheme: PopupMenuThemeData(
        color: pureBlack,
        surfaceTintColor: pureBlack,
      ),
    );
  }
}
