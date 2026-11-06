/// Recuperación opcional de duración por ID, nunca por coincidencia de título.
/// El fallo de metadatos no bloquea ni modifica la reproducción de audio.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final youtubeDurationProvider = FutureProvider.family<Duration?, String>((
  ref,
  videoId,
) async {
  if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) return null;
  final youtube = YoutubeExplode();
  try {
    final info = await youtube.videos
        .get(videoId)
        .timeout(const Duration(seconds: 9));
    return info.duration;
  } catch (_) {
    return null;
  } finally {
    youtube.close();
  }
});
