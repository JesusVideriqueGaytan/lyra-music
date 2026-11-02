/// Centro de extensiones comunitarias. Solo catálogos aprobados.
/// La ejecución/instalación de código de terceros NO está habilitada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyra_music/features/extensions/data/approved_extension_catalog.dart';
import 'package:lyra_music/features/extensions/domain/extension_manifest.dart';

class ExtensionsScreen extends ConsumerWidget {
  const ExtensionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(approvedExtensionCatalogProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extensiones'),
        leading: IconButton(
          tooltip: 'Volver a Biblioteca',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/library'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.extension_rounded, color: scheme.primary, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Lyra crece con su comunidad',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este espacio mostrará complementos revisados antes de publicarse. '
                  'Por seguridad, la ejecución de código externo no está disponible en esta versión.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Catálogo aprobado',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Volver a cargar catálogo local',
                onPressed: () =>
                    ref.invalidate(approvedExtensionCatalogProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...catalog.when(
            loading: () => [const Center(child: CircularProgressIndicator())],
            error: (error, stack) => [
              _InformationCard(
                icon: Icons.error_outline_rounded,
                title: 'No se pudo leer el catálogo',
                description:
                    'Comprueba la versión y los archivos incluidos en Lyra.',
              ),
            ],
            data: (items) => items.isEmpty
                ? [
                    const _InformationCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Todavía no hay extensiones publicadas',
                      description:
                          'Las propuestas de la comunidad aparecerán aquí tras ser revisadas.',
                    ),
                  ]
                : items.map((e) => _ExtensionCard(extension: e)).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            '¿Quieres desarrollar una extensión?',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Publicaremos especificaciones, permisos y requisitos de revisión '
            'en el repositorio de Lyra. Cada propuesta necesitará revisión '
            'de código, pruebas y aprobación antes de distribuirse.',
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Proceso de publicación'),
                content: const Text(
                  '1. Preparar un manifiesto de la extensión.\n'
                  '2. Enviar un Pull Request al repositorio oficial de catálogo.\n'
                  '3. Pasar validaciones automáticas y revisión humana.\n'
                  '4. Incorporarse a una actualización de Lyra tras la aprobación.\n\n'
                  'La subida directa desde la aplicación y la ejecución de código externo '
                  'no están habilitadas todavía.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.code_rounded),
            label: const Text('Cómo proponer una extensión'),
          ),
        ],
      ),
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  const _ExtensionCard({required this.extension});
  final ExtensionManifest extension;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.extension_outlined),
      title: Text(extension.name),
      subtitle: Text(
        '${extension.summary}\nPor ${extension.author} · v${extension.version}',
      ),
      isThreeLine: true,
      trailing: const Tooltip(
        message:
            'Información disponible; la instalación se habilitará en otra fase',
        child: Icon(Icons.info_outline_rounded),
      ),
    ),
  );
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(description, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
