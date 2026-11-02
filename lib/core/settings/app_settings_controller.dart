/// Ajustes generales de Lyra.
///
/// Expone preferencias de interfaz que no pertenecen al subsistema de tema
/// ni al de rendimiento: por ejemplo el tamaño global del texto.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kFontScaleKey = 'lyra_font_scale';
const String _kRecommendationsKey = 'lyra_recommendations_enabled';

class AppSettingsState {
  const AppSettingsState({
    required this.fontScale,
    required this.recommendationsEnabled,
  });

  final double fontScale;
  final bool recommendationsEnabled;

  AppSettingsState copyWith({double? fontScale, bool? recommendationsEnabled}) {
    return AppSettingsState(
      fontScale: fontScale ?? this.fontScale,
      recommendationsEnabled:
          recommendationsEnabled ?? this.recommendationsEnabled,
    );
  }
}

class AppSettingsController extends Notifier<AppSettingsState> {
  SharedPreferences? _prefs;

  @override
  AppSettingsState build() {
    _loadSaved();
    return const AppSettingsState(fontScale: 1.0, recommendationsEnabled: true);
  }

  Future<void> _loadSaved() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final saved = _prefs?.getDouble(_kFontScaleKey) ?? 1.0;
      state = state.copyWith(
        fontScale: saved.clamp(0.85, 1.35),
        recommendationsEnabled: _prefs?.getBool(_kRecommendationsKey) ?? true,
      );
    } catch (_) {
      _prefs = null;
    }
  }

  Future<void> setFontScale(double value) async {
    final clamped = value.clamp(0.85, 1.35);
    state = state.copyWith(fontScale: clamped);
    await _prefs?.setDouble(_kFontScaleKey, clamped);
  }

  Future<void> setRecommendationsEnabled(bool value) async {
    state = state.copyWith(recommendationsEnabled: value);
    await _prefs?.setBool(_kRecommendationsKey, value);
  }

  Future<void> resetFontScale() => setFontScale(1.0);
}

final appSettingsControllerProvider =
    NotifierProvider<AppSettingsController, AppSettingsState>(
      AppSettingsController.new,
    );
