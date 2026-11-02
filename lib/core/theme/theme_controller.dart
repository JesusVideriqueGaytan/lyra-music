/// Controlador de tema de Lyra.
///
/// Notifier de Riverpod que gestiona la variante de tema seleccionada y la
/// persiste en SharedPreferences. La UI lo consume con
/// `ref.watch(themeControllerProvider)`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lyra_music/core/theme/adaptive_theme.dart';

/// Clave de persistencia del tema.
const String _kThemeKey = 'lyra_theme_variant';

/// Estado del sistema de temas.
class ThemeState {
  const ThemeState({required this.variant, required this.seedColor});

  /// Variante seleccionada por el usuario.
  final AppThemeVariant variant;

  /// Color semilla para los temas no dinámicos.
  final Color seedColor;

  ThemeState copyWith({AppThemeVariant? variant, Color? seedColor}) {
    return ThemeState(
      variant: variant ?? this.variant,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

/// Notifier que expone y persiste las preferencias de tema.
class ThemeController extends Notifier<ThemeState> {
  SharedPreferences? _prefs;

  @override
  ThemeState build() {
    // Carga síncrona inicial: se parte del valor por defecto y se corrige
    // en cuanto SharedPreferences responde (evita bloquear el primer frame).
    _loadSaved();
    return const ThemeState(
      variant: AppThemeVariant.dynamic,
      seedColor: AdaptiveTheme.defaultSeed,
    );
  }

  Future<void> _loadSaved() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final saved = appThemeVariantFromStorageKey(
        _prefs?.getString(_kThemeKey),
      );
      state = state.copyWith(variant: saved);
    } catch (_) {
      // Sin persistencia disponible: mantener valores por defecto.
      _prefs = null;
    }
  }

  /// Cambia la variante de tema y la persiste.
  Future<void> setVariant(AppThemeVariant variant) async {
    state = state.copyWith(variant: variant);
    await _prefs?.setString(_kThemeKey, variant.name);
  }

  /// Cambia el color semilla (para temas claro/oscuro/AMOLED).
  Future<void> setSeedColor(Color seed) async {
    state = state.copyWith(seedColor: seed);
  }
}

/// Provider principal del controlador de tema.
final themeControllerProvider = NotifierProvider<ThemeController, ThemeState>(
  ThemeController.new,
);

/// Atajo: resuelve el [ThemeData] efectivo desde el estado actual.
///
/// [dynamicScheme] permite inyectar el esquema generado por Material You
/// desde el widget raíz (paquete `dynamic_color`).
final resolvedThemeProvider = Provider.family<ThemeData, ColorScheme?>((
  ref,
  dynamicScheme,
) {
  final controllerState = ref.watch(themeControllerProvider);
  return AdaptiveTheme.build(
    controllerState.variant,
    seed: controllerState.seedColor,
    dynamicScheme: dynamicScheme,
  );
});
