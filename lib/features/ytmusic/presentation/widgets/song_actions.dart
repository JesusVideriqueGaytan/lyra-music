/// Compact song row actions. No duplicate favorites/playlist menu entries.
library;

import 'package:flutter/material.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

String songDurationLabel(Duration? duration) {
  if (duration == null || duration <= Duration.zero) return '—';
  final seconds = duration.inSeconds;
  final minutes = (seconds ~/ 60) % 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (seconds >= 3600) return '${seconds ~/ 3600}:${minutes.toString().padLeft(2, '0')}:$rest';
  return '$minutes:$rest';
}

class SongActionBar extends StatelessWidget {
  const SongActionBar({super.key, required this.track, required this.favorite,
    required this.onFavorite, required this.onPlaylist, required this.onPlayNext,
    this.onDownload, this.onRemove});
  final Track track;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback? onPlaylist;
  final VoidCallback onPlayNext;
  final VoidCallback? onDownload;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(songDurationLabel(track.duration), style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(width: 6),
      IconButton(tooltip: favorite ? 'Quitar de favoritos' : 'Me gusta',
        visualDensity: VisualDensity.compact,
        icon: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
        onPressed: onFavorite),
      if (onPlaylist != null)
        IconButton(tooltip: 'Añadir a playlist', visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.playlist_add_rounded), onPressed: onPlaylist),
      if (onDownload != null)
        IconButton(tooltip: 'Guardar audio autorizado', visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.download_outlined), onPressed: onDownload),
      IconButton(
        tooltip: 'Reproducir a continuación',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.queue_play_next_rounded),
        onPressed: onPlayNext,
      ),
      if (onRemove != null)
        PopupMenuButton<String>(
          tooltip: 'Más opciones de la playlist',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (_) => onRemove!(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'remove', child: Text('Quitar de esta playlist')),
          ],
        ),
    ]);
  }
}
