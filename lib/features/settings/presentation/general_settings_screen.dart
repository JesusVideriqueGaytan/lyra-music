/// Ajustes generales de interfaz de Lyra.
library;

import 'package:flutter/material.dart';
import 'package:lyra_music/shared/widgets/lyra_section_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lyra_music/core/settings/app_settings_controller.dart';
import 'package:lyra_music/core/theme/adaptive_theme.dart';
import 'package:lyra_music/core/theme/theme_controller.dart';

class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final settingsController = ref.read(appSettingsControllerProvider.notifier);
    final themeState = ref.watch(themeControllerProvider);
    final themeController = ref.read(themeControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        leading: IconButton(
          tooltip: 'Volver a la biblioteca',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/library'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const LyraSectionBanner(
            icon: Icons.settings_rounded,
            eyebrow: 'AJUSTES',
            title: 'Haz Lyra tuya',
            subtitle: 'Apariencia, accesibilidad y preferencias.',
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Cuentas y servicios'),
              subtitle: const Text('Biblioteca local y cuentas opcionales'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.go('/accounts'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Interfaz', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tamaño de letra', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Ajusta la escala tipográfica global para mejorar la legibilidad.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('A', style: textTheme.bodySmall),
                      Expanded(
                        child: Slider(
                          min: 0.85,
                          max: 1.35,
                          divisions: 10,
                          label: '${(settings.fontScale * 100).round()}%',
                          value: settings.fontScale,
                          onChanged: settingsController.setFontScale,
                        ),
                      ),
                      Text(
                        'A',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: settings.fontScale == 1.0
                          ? null
                          : settingsController.resetFontScale,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Restablecer'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vista previa', style: textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Lyra prioriza una interfaz clara, ligera y fácil de leer.',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Privacidad y recomendaciones', style: textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: SwitchListTile.adaptive(
              value: settings.recommendationsEnabled,
              onChanged: settingsController.setRecommendationsEnabled,
              title: const Text('Sugerencias según lo que escuchas'),
              subtitle: const Text(
                'Lyra calcula tus preferencias en el dispositivo. '
                'Si activas sugerencias, buscará el nombre de un artista '
                'en el proveedor online; no sube tu historial ni estadísticas.',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Tema', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apariencia', style: textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final variant in AppThemeVariant.values)
                        ChoiceChip(
                          label: Text(variant.label),
                          selected: themeState.variant == variant,
                          onSelected: (_) =>
                              themeController.setVariant(variant),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
