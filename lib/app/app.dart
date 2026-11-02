/// Widget raíz de Lyra: integra Riverpod, GoRouter y el sistema de temas.
///
/// Si el SO expone colores dinámicos (Material You / Windows accent / macOS
/// accent), `dynamic_color` genera el esquema y se pasa al tema Dinámico.
library;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lyra_music/core/theme/adaptive_theme.dart';
import 'package:lyra_music/core/theme/theme_controller.dart';
import 'package:lyra_music/app/router.dart';

class LyraApp extends ConsumerWidget {
  const LyraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(themeControllerProvider);

    // Dynamic Color: solo relevante si el usuario eligió la variante dinámica.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // El esquema dinámico "real" lo decide adaptive_theme según variante.
        final dynamicScheme =
            (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                    Brightness.dark)
                ? darkDynamic
                : lightDynamic;

        final lightTheme = themeState.variant == AppThemeVariant.dynamic &&
                lightDynamic != null
            ? AdaptiveTheme.fromScheme(lightDynamic)
            : AdaptiveTheme.build(
                themeState.variant,
                seed: themeState.seedColor,
                dynamicScheme: dynamicScheme,
              );

        final darkTheme = themeState.variant == AppThemeVariant.dynamic &&
                darkDynamic != null
            ? AdaptiveTheme.fromScheme(darkDynamic)
            : AdaptiveTheme.build(
                AppThemeVariant.dark,
                seed: themeState.seedColor,
              );

        return MaterialApp.router(
          title: 'Lyra',
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: lightTheme,
          darkTheme: darkTheme,
          // La variante elegida por el usuario controla el brightness:
          // claro => luz; oscuro/AMOLED/dinámico => seguimos al sistema.
          themeMode: switch (themeState.variant) {
            AppThemeVariant.light => ThemeMode.light,
            AppThemeVariant.dark => ThemeMode.dark,
            AppThemeVariant.amoled => ThemeMode.dark,
            AppThemeVariant.dynamic => ThemeMode.system,
          },
        );
      },
    );
  }
}
