/// Validación conservadora de nombres de artistas provenientes de catálogos.
///
/// Es código Dart puro y no necesita Flutter: funciona con títulos en
/// japonés, coreano y otros idiomas sin transliterar ni adivinar intérpretes.
library;

/// True solamente para nombres plausibles, no para tiempo, año, tipo de
/// contenido o cifras de reproducción presentes en columnas secundarias.
bool isUsableArtistName(String value) {
  final name = value.trim().toLowerCase();
  if (name.isEmpty || name == '•' || name == '·') return false;

  if (RegExp(r'^\d{1,3}:\d{2}(?::\d{2})?$').hasMatch(name) ||
      RegExp(r'^\d{4}$').hasMatch(name)) {
    return false;
  }

  const invalid = <String>{
    'artista desconocido', 'unknown artist', 'video', 'vídeo', 'song',
    'canción', 'music video', 'official video', 'official audio', 'audio',
    'album', 'álbum', 'single', 'sencillo', 'ep', 'playlist',
    'lista de reproducción', 'reproduciendo', 'radio',
  };
  if (invalid.contains(name)) return false;

  // Las estadísticas no son nombres de artistas: "2,1 M reproducciones",
  // "20 M de visualizaciones", "3.4K views", "1800 listeners".
  if (RegExp(
    r'^\d[\d.,\s]*\s*(?:k|m|b|mil|millones)?\s*'
    r'(?:de\s+)?(?:visualizaciones|reproducciones|vistas|views?|plays?|'
    r'oyentes|listeners|suscriptores|subscribers)(?:\s+.*)?$',
  ).hasMatch(name)) {
    return false;
  }
  if (RegExp(r'^\d+\s*(?:segundos?|seconds?|minutos?|mins?)$')
      .hasMatch(name)) {
    return false;
  }
  if (name.startsWith('vídeo •') || name.startsWith('video •') ||
      name.startsWith('canción •')) {
    return false;
  }
  return true;
}

/// Primer fragmento plausible de una línea de metadatos. No deduce artistas
/// por coincidencia de títulos: devuelve null cuando no hay información.
String? extractArtistCandidate(String metadata) {
  for (final segment in metadata.split(RegExp(r'\s*[•·|]\s*'))) {
    final value = segment.trim();
    if (isUsableArtistName(value)) return value;
  }
  return null;
}
