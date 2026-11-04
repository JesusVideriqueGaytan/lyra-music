/// Inicio de Lyra: experiencia musical unificada sin contenido simulado.
///
/// No genera recomendaciones falsas: los géneros son búsquedas reales y
/// «Continuar escuchando» solo aparece cuando hay una pista cargada.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/core/performance/performance_controller.dart';
import 'package:lyra_music/features/library/presentation/widgets/track_artwork.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/ytmusic/presentation/ytmusic_controller.dart';
import 'recommendations_section.dart';
import 'followed_artists_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final current = ref.watch(audioPlayerControllerProvider).currentTrack;
    if (ref.watch(musicCollectionProvider).ready) {
      ref.watch(historyMetadataRepairProvider);
    }
    final canAnimate = ref.watch(adaptiveFeaturesProvider).canUseAnimations;
    final wide = MediaQuery.sizeOf(context).width >= 760;
    void explore(String query) {
      unawaited(ref.read(ytMusicControllerProvider.notifier).search(query));
      context.go('/explore');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: ListView(
            padding: EdgeInsets.fromLTRB(wide ? 26 : 16, 12,
                wide ? 26 : 16, 28),
            children: [
              Container(
                padding: EdgeInsets.all(wide ? 26 : 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer,
                      Color.alphaBlend(
                        scheme.secondary.withValues(
                          alpha: canAnimate ? 0.15 : 0.04,
                        ),
                        scheme.surfaceContainerHigh,
                      ),
                    ],
                  ),
                ),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TU UNIVERSO MUSICAL',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            letterSpacing: 1.7,
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimaryContainer,
                          )),
                      const SizedBox(height: 12),
                      Text('Escucha lo que quieras, a tu manera.',
                          style: (wide
                                  ? Theme.of(context).textTheme.headlineMedium
                                  : Theme.of(context).textTheme.titleLarge)
                              ?.copyWith(fontWeight: FontWeight.w800,
                                color: scheme.onPrimaryContainer)),
                      const SizedBox(height: 12),
                      Text('Música de tu dispositivo y búsqueda en línea, '
                          'desde el mismo reproductor.',
                          style: TextStyle(color: scheme.onPrimaryContainer)),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => context.go('/explore'),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Buscar música'),
                      ),
                    ],
                  )),
                  if (wide) ...[
                    const SizedBox(width: 20),
                    Icon(Icons.graphic_eq_rounded, size: 94,
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.72)),
                  ],
                ]),
              ),
              const SizedBox(height: 30),
              if (current != null) ...[
                Text('Continúa escuchando',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: TrackArtwork(track: current, size: 64),
                    title: Text(current.title, maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(current.displayArtist, maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.play_circle_fill_rounded, size: 34),
                    onTap: () => context.go('/player'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const RecommendationsSection(),
              const FollowedArtistsSection(),
              Text('Explora por estilo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 5),
              Text('Accesos directos a búsquedas, no recomendaciones inventadas.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 9, children: [
                for (final (label, icon) in <(String, IconData)>[
                  ('Pop', Icons.auto_awesome_rounded),
                  ('Electrónica', Icons.graphic_eq_rounded),
                  ('Rock', Icons.bolt_rounded),
                  ('Lo-fi', Icons.nightlight_round),
                  ('Jazz', Icons.piano_rounded),
                  ('Anime', Icons.headphones_rounded),
                ])
                  ActionChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    onPressed: () => explore(label),
                  ),
              ]),
              const SizedBox(height: 28),
              Text('Tu espacio',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, bounds) {
                final columns = bounds.maxWidth >= 820 ? 3 :
                    bounds.maxWidth >= 500 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: columns == 1 ? 5.0 : 2.5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _QuickLink(
                      icon: Icons.library_music_rounded,
                      title: 'Tu biblioteca',
                      detail: 'Archivos locales, álbumes y carpetas',
                      onTap: () => context.go('/library'),
                    ),
                    _QuickLink(
                      icon: Icons.queue_music_rounded,
                      title: 'Biblioteca unificada',
                      detail: 'Colecciones e historial locales',
                      onTap: () => context.go('/my-music'),
                    ),
                    _QuickLink(
                      icon: Icons.extension_rounded,
                      title: 'Estadísticas',
                      detail: 'Tiempo escuchado y canciones favoritas',
                      onTap: () => context.go('/statistics'),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.icon, required this.title,
      required this.detail, required this.onTap});
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(icon, size: 27, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          )),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    ),
  );
}
