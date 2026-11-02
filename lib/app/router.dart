/// Enrutamiento de Lyra con GoRouter (Fase 2).
///
/// Rutas:
///  - `/`          -> redirige a la biblioteca.
///  - `/library`   -> Biblioteca.
///  - `/player`    -> Pantalla "Suena ahora".
///  - `/settings`  -> Configuración de rendimiento (heredada de Fase 1).
///
/// ShellRoute conserva el mini reproductor en el flujo del layout.
/// No cubre el contenido ni los controles de las pantallas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/core/performance/performance_controller.dart';
import 'package:lyra_music/features/library/presentation/screens/library_screen.dart';
import 'package:lyra_music/features/player/presentation/screens/now_playing_screen.dart';
import 'package:lyra_music/features/player/presentation/widgets/mini_player.dart';
import 'package:lyra_music/features/settings/presentation/performance_settings_screen.dart';
import 'package:lyra_music/features/settings/presentation/general_settings_screen.dart';
import 'package:lyra_music/features/extensions/presentation/extensions_screen.dart';
import 'package:lyra_music/features/online/presentation/online_screen.dart';
import 'package:lyra_music/features/home/presentation/home_screen.dart';
import 'package:lyra_music/features/accounts/presentation/accounts_screen.dart';
import 'package:lyra_music/features/library/presentation/screens/my_music_screen.dart';
import 'package:lyra_music/features/library/presentation/screens/listening_statistics_screen.dart';

/// Provider del router: instancia única mientras viva el ProviderScope.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: false,
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) => _MiniPlayerScaffold(
          showMiniPlayer: state.uri.path != '/player',
          child: child,
        ),
        routes: <RouteBase>[
          GoRoute(path: '/', redirect: (context, state) => '/home'),
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/explore',
            name: 'explore',
            builder: (context, state) => const OnlineScreen(),
          ),
          GoRoute(
            path: '/accounts',
            name: 'accounts',
            builder: (context, state) => const AccountsScreen(),
          ),
          GoRoute(
            path: '/my-music',
            name: 'my-music',
            builder: (context, state) => const MyMusicScreen(),
          ),
          GoRoute(
            path: '/statistics',
            name: 'statistics',
            builder: (context, state) => const ListeningStatisticsScreen(),
          ),
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

          GoRoute(
            path: '/extensions',
            name: 'extensions',
            builder: (context, state) => const ExtensionsScreen(),
          ),
          GoRoute(
            path: '/preferences',
            name: 'preferences',
            builder: (context, state) => const GeneralSettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Estructura adaptable: navegación lateral en desktop e inferior en móvil.
/// El mini reproductor ocupa su propio espacio; no cubre contenido.
class _MiniPlayerScaffold extends StatelessWidget {
  const _MiniPlayerScaffold({
    required this.child,
    required this.showMiniPlayer,
  });

  final bool showMiniPlayer;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final currentPath = GoRouterState.of(context).uri.path;
    final scheme = Theme.of(context).colorScheme;
    // El mini reproductor forma parte del layout, sin cubrir contenido ni FAB.
    // Cuando no hay pista, MiniPlayer ocupa cero espacio.
    final content = Column(
      children: <Widget>[
        Expanded(child: child ?? const SizedBox.shrink()),
        if (showMiniPlayer) const SafeArea(top: false, child: MiniPlayer()),
      ],
    );
    if (!wide) {
      final destination = switch (currentPath) {
        '/home' || '/player' => 0,
        '/explore' => 1,
        '/library' || '/my-music' || '/statistics' => 2,
        _ => 3,
      };
      return Material(
        color: scheme.surface,
        child: Column(
          children: [
            Expanded(child: content),
            NavigationBar(
              height: 66,
              selectedIndex: destination,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  label: 'Buscar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  label: 'Biblioteca',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Ajustes',
                ),
              ],
              onDestinationSelected: (value) => context.go(switch (value) {
                0 => '/home',
                1 => '/explore',
                2 => '/library',
                _ => '/preferences',
              }),
            ),
          ],
        ),
      );
    }
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
                    child: Row(
                      children: [
                        Icon(
                          Icons.graphic_eq_rounded,
                          color: scheme.primary,
                          size: 27,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Lyra',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  _NavItem(
                    icon: Icons.home_rounded,
                    title: 'Inicio',
                    selected: currentPath == '/home',
                    onTap: () => context.go('/home'),
                  ),
                  const SizedBox(height: 6),
                  _NavItem(
                    icon: Icons.search_rounded,
                    title: 'Buscar',
                    selected: currentPath == '/explore',
                    onTap: () => context.go('/explore'),
                  ),
                  const SizedBox(height: 6),
                  _NavItem(
                    icon: Icons.library_music_rounded,
                    title: 'Biblioteca',
                    selected: currentPath == '/library',
                    onTap: () => context.go('/library'),
                  ),
                  const SizedBox(height: 6),
                  _NavItem(
                    icon: Icons.favorite_border_rounded,
                    title: 'Mi música',
                    selected: currentPath == '/my-music',
                    onTap: () => context.go('/my-music'),
                  ),
                  const SizedBox(height: 6),
                  _NavItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'Estadísticas',
                    selected: currentPath == '/statistics',
                    onTap: () => context.go('/statistics'),
                  ),
                  const SizedBox(height: 6),
                  _NavItem(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Reproductor',
                    selected: currentPath == '/player',
                    onTap: () => context.go('/player'),
                  ),
                  const Spacer(),
                  const Divider(),
                  _NavItem(
                    icon: Icons.settings_rounded,
                    title: 'Ajustes',
                    selected:
                        currentPath == '/preferences' ||
                        currentPath == '/accounts',
                    onTap: () => context.go('/preferences'),
                  ),
                  const SizedBox(height: 6),
                  _NavItem(
                    icon: Icons.extension_outlined,
                    title: 'Extensiones',
                    selected: currentPath == '/extensions',
                    onTap: () => context.go('/extensions'),
                  ),
                  const SizedBox(height: 6),
                  _NavItem(
                    icon: Icons.tune_rounded,
                    title: 'Rendimiento',
                    selected: currentPath == '/settings',
                    onTap: () => context.go('/settings'),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Libre · Ligero · Adaptable',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
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
  const _NavItem({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });
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
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
