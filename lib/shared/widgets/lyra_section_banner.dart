/// Cabecera visual reutilizable y ligera para todas las secciones de Lyra.
library;

import 'package:flutter/material.dart';

class LyraSectionBanner extends StatelessWidget {
  const LyraSectionBanner({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String eyebrow, title, subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.surfaceContainerHigh],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            icon,
            size: 64,
            color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
          ),
        ],
      ),
    );
  }
}
