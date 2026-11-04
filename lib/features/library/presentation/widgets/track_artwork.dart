/// Portadas compartidas en biblioteca y reproductor.
/// Usa carátulas locales si el escáner las detectó; si no, un placeholder.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/downloads/download_manager.dart';

class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.track,
    this.size = 52,
    this.radius = 12,
  });
  final Track track;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track.coverPath;
    Widget placeholder() => DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.42,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
    final manager = LyraDownloadManager.instance;
    return AnimatedBuilder(
      animation: manager.libraryRevision,
      builder: (context, _) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              track.artworkUrl != null &&
                      track.artworkUrl!.startsWith('https://')
                  ? Image.network(
                      track.artworkUrl!,
                      fit: BoxFit.cover,
                      cacheWidth:
                          (size * MediaQuery.devicePixelRatioOf(context))
                              .round()
                              .clamp(32, 900),
                      errorBuilder: (context, error, stackTrace) =>
                          placeholder(),
                    )
                  : coverPath == null || coverPath.isEmpty
                  ? placeholder()
                  : Image.file(
                      File(coverPath),
                      fit: BoxFit.cover,
                      cacheWidth:
                          (size * MediaQuery.devicePixelRatioOf(context))
                              .round()
                              .clamp(32, 900),
                      errorBuilder: (context, error, stackTrace) =>
                          placeholder(),
                    ),
              if (manager.isDownloaded(track.id))
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      Icons.download_done_rounded,
                      size: size < 42 ? 12 : 16,
                      color: scheme.onPrimary,
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
