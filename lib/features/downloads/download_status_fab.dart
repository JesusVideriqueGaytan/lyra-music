/// Indicador flotante: solo está presente cuando hay trabajo pendiente.
/// El progreso completo se abre de forma descartable, no tapa toda la app.
library;

import 'package:flutter/material.dart';
import 'package:lyra_music/features/downloads/download_manager.dart';
import 'package:lyra_music/features/downloads/downloads_screen.dart';

class DownloadStatusFab extends StatelessWidget {
  const DownloadStatusFab({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = LyraDownloadManager.instance;
    return AnimatedBuilder(animation: manager, builder: (context, _) {
      final pending = manager.activeCount;
      if (pending == 0) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Material(
        color: theme.colorScheme.primaryContainer,
        elevation: 5,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => showModalBottomSheet<void>(
            context: context, isScrollControlled: true, showDragHandle: true,
            builder: (ctx) => SafeArea(child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.7,
              child: const DownloadsScreen(embedded: true),
            )),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('Descargando · $pending',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer)),
            ]),
          ),
        ),
      );
    });
  }
}
