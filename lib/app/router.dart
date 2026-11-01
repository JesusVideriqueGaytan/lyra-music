/// Enrutamiento de Lyra con GoRouter (Fase 2).
///
/// Rutas:
///  - `/`          -> redirige a la biblioteca.
///  - `/library`   -> Biblioteca.
///  - `/player`    -> Pantalla "Suena ahora".
///  - `/settings`  -> Configuración de rendimiento (heredada de Fase 1).
///
/// El `builder` de ShellRoute envuelve TODAS las rutas con un Stack que superpone el
/// MiniPlayer: así la barra del reproductor es persistente tanto en la
/// biblioteca como en ajustes, sin duplicarla en cada pantalla.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/core/performance/performance_controller.dart';
import 'package:lyra_music/features/library/presentation/screens/library_screen.dart';
import 'package:lyra_music/features/player/presentation/screens/now_playing_screen.dart';
import 'package:lyra_music/features/player/presentation/widgets/mini_player.dart';
import 'package:lyra_music/features/settings/presentation/performance_settings_screen.dart';

/// Provider del router: instancia única mientras viva el ProviderScope.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/library',
    debugLogDiagnostics: false,
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) => _MiniPlayerScaffold(
          showMiniPlayer: state.uri.path != '/player', child: child),
        routes: <RouteBase>[
          GoRoute(path: '/', redirect: (context, state) => '/library'),
          GoRoute(
            path: '/library',
            name: 'library',
            builder: (context, state) => const LibraryScreen(),
          ),
          GoRoute(
            path: '/player',
            name: 'now-playing',
            // Transición adaptativa: fade simple en tier low, slide+fade en el
            // resto. Leemos las características desde el contenedor de Riverpod
            // porque el builder del router no tiene WidgetRef.
            pageBuilder: (context, state) {
              final features = ref.read(adaptiveFeaturesProvider);
              final duration = features.canUseAnimations
                  ? Duration(milliseconds: features.animationDurationMs)
                  : Duration.zero;
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: const NowPlayingScreen(),
                transitionDuration: duration,
                reverseTransitionDuration: duration,
                transitionsBuilder: (context, animation, secondary, child) {
                  // Tier low: fundido directo sin desplazamiento (más barato).
                  if (!features.canUseAnimations) {
                    return FadeTransition(opacity: animation, child: child);
                  }
                  // Tier medium+: slide vertical (sensación de "expandir" el
                  // mini-player) combinado con fade.
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  );
                },
              );
            },
          ),
          GoRoute(
            path: '/settings',
            name: 'performance-settings',
            builder: (context, state) => const PerformanceSettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Envoltorio global que pinta el MiniPlayer anclado al fondo sobre el
/// contenido de la ruta activa. En la propia pantalla /player se omite para
/// no duplicar controles.
class _MiniPlayerScaffold extends StatelessWidget {
  const _MiniPlayerScaffold({required this.child, required this.showMiniPlayer});

  final bool showMiniPlayer;

  final Widget? child;

  @override
  Widget build(BuildContext context) {

    return Stack(
      children: <Widget>[
        if (child != null) child!,
        if (showMiniPlayer)
          const PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: SafeArea(top: false, child: MiniPlayer()),
          ),
      ],
    );
  }
}
