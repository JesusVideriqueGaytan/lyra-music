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

    final wide = MediaQuery.sizeOf(context).width >= 850;
    final currentPath = GoRouterState.of(context).uri.path;
    final scheme = Theme.of(context).colorScheme;
    final content = Stack(
      children: <Widget>[
        if (child != null) child!,
        if (showMiniPlayer)
          const PositionedDirectional(
            start: 0, end: 0, bottom: 0,
            child: SafeArea(top: false, child: MiniPlayer()),
          ),
      ],
    );
    if (!wide) return content;
    return Material(
      color: scheme.surface,
      child: Row(
        children: [
          SizedBox(
            width: 216,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 0, 26),
                    child: Row(children: [
                      Icon(Icons.graphic_eq_rounded, color: scheme.primary, size: 27),
                      const SizedBox(width: 10),
                      Text('Lyra', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  _NavItem(icon: Icons.library_music_rounded, title: 'Biblioteca',
                    selected: currentPath == '/library', onTap: () => context.go('/library')),
                  const SizedBox(height: 6),
                  _NavItem(icon: Icons.play_circle_outline_rounded, title: 'Reproductor',
                    selected: currentPath == '/player', onTap: () => context.go('/player')),
                  const Spacer(),
                  const Divider(),
                  _NavItem(icon: Icons.tune_rounded, title: 'Rendimiento',
                    selected: currentPath == '/settings', onTap: () => context.go('/settings')),
                  const SizedBox(height: 10),
                  Padding(padding: const EdgeInsets.only(left: 12),
                    child: Text('Libre · Ligero · Adaptable', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant))),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: scheme.outlineVariant),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.title, required this.selected, required this.onTap});
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20, color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500))),
          ]),
        ),
      ),
    );
  }
}
