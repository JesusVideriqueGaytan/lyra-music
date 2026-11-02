/// Recomendaciones basadas en escuchas y favoritos guardados localmente.
/// Nunca se fabrican pistas: esta capa solo decide una búsqueda de artista.
library;

import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';

class MusicRecommendationSeed {
  const MusicRecommendationSeed(this.artist, this.listens);
  final String artist;
  final int listens;
}

/// Devuelve null si no existe suficiente contexto real para recomendar.
MusicRecommendationSeed? recommendationSeed(MusicCollectionState state) {
  final scores = <String, int>{};
  final display = <String, String>{};
  void add(String artist, int score) {
    final clean = artist.trim();
    if (clean.isEmpty ||
        clean.toLowerCase() == 'artista desconocido' ||
        clean.toLowerCase() == 'canción') {
      return;
    }
    final key = clean.toLowerCase();
    scores[key] = (scores[key] ?? 0) + score;
    display[key] = clean;
  }

  for (final entry in state.records.values) {
    // Tiempo escuchado y reproducciones; evita que una pista pausada
    // determine por sí sola todos los resultados.
    add(entry.track.artist, entry.plays * 3 + entry.ms ~/ 120000);
  }
  for (final track in state.favorites.values) {
    add(track.artist, 5);
  }
  if (scores.isEmpty) return null;
  final ranked = scores.keys.toList()
    ..sort((a, b) {
      final scoreCompare = scores[b]!.compareTo(scores[a]!);
      return scoreCompare != 0 ? scoreCompare : a.compareTo(b);
    });
  final chosen = ranked.first;
  return MusicRecommendationSeed(display[chosen]!, scores[chosen]!);
}
