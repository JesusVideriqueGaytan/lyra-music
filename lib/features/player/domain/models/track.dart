/// Modelo de dominio que representa una pista de audio local.
///
/// Capa DOMINIO: no depende de Flutter ni de plugins. Es inmutable,
/// serializable a Map (para persistirla en Isar/Hive en fases futuras) y
/// compara por [id] para que la UI pueda resaltar la canción activa.
library;

import 'dart:io';

/// Formatos de audio soportados por Lyra en reproducción local.
const List<String> kSupportedAudioExtensions = <String>[
  '.mp3',
  '.flac',
  '.ogg',
  '.oga',
  '.wav',
  '.m4a',
  '.aac',
];

/// Una canción del dispositivo del usuario.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    this.duration,
    this.coverPath,
    this.genre,
    this.trackNumber,
    this.year,
    this.artworkUrl,
  });

  /// Identificador estable: usamos la ruta absoluta porque es única en el
  /// dispositivo y sobrevive entre sesiones sin necesidad de base de datos.
  final String id;

  /// Título de la canción (metadato o nombre del archivo como fallback).
  final String title;

  /// Artista conocido o "Artista desconocido".
  final String artist;

  /// Álbum conocido o "Álbum desconocido".
  final String album;

  /// Ruta absoluta del archivo en el disco.
  final String filePath;

  /// Duración conocida si el escáner pudo determinarla; null si es desconocida.
  final Duration? duration;

  /// Ruta de una carátula embebida/exportada (Fase 2 usa archivos .cue/.jpg
  /// adyacentes; más adelante se extraerán metadatos reales).
  final String? coverPath;

  /// Género (opcional, para filtros futuros).
  final String? genre;

  /// Número de pista dentro del álbum (opcional).
  final int? trackNumber;

  /// Año de publicación (opcional).
  final int? year;

  /// URL pública de la portada cuando la pista proviene de un catálogo permitido.
  final String? artworkUrl;

  /// Fuente remota permitida; los archivos descargados vuelven a ser locales.
  bool get isRemote => Uri.tryParse(filePath)?.scheme == 'https';

  /// Nombre del archivo con extensión (útil para mostrar cuando el título
  /// coincide con el nombre crudo del fichero).
  String get fileName => filePath.split(Platform.pathSeparator).last;

  /// Carpeta contenedora del archivo: permite agrupar por directorio.
  String get directoryPath {
    final separatorIndex = filePath.lastIndexOf(Platform.pathSeparator);
    if (separatorIndex <= 0) return '.';
    return filePath.substring(0, separatorIndex);
  }

  /// Nombre de la carpeta contenedora (mostrado como subtítulo en listas).
  String get folderName {
    final directory = directoryPath.split(Platform.pathSeparator).last;
    return directory.isEmpty ? '/' : directory;
  }

  /// Crea un Track a partir de la ruta de un archivo de audio, derivando el
  /// título del nombre del fichero (sin extensión). En Fase 3 se enriquecerá
  /// con extracción real de metadatos.
  factory Track.fromFilePath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');
    final cleanTitle = dotIndex > 0
        ? fileName.substring(0, dotIndex)
        : fileName;

    // Convención habitual "Artist - Title.mp3": si el nombre contiene " - "
    // lo interpretamos como artista + título para mejorar la UI sin leer
    // metadatos binarios.
    final dashIndex = cleanTitle.indexOf(' - ');
    final String derivedArtist;
    final String derivedTitle;
    if (dashIndex > 0) {
      derivedArtist = cleanTitle.substring(0, dashIndex).trim();
      derivedTitle = cleanTitle.substring(dashIndex + 3).trim();
    } else {
      derivedArtist = 'Artista desconocido';
      derivedTitle = cleanTitle.trim();
    }

    return Track(
      id: path,
      title: derivedTitle.isEmpty ? cleanTitle : derivedTitle,
      artist: derivedArtist,
      album: 'Álbum desconocido',
      filePath: path,
    );
  }

  /// Serialización a Map (para caché persistente en fases posteriores).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'filePath': filePath,
      'durationMs': duration?.inMilliseconds,
      'coverPath': coverPath,
      'genre': genre,
      'trackNumber': trackNumber,
      'year': year,
      'artworkUrl': artworkUrl,
    };
  }

  /// Deserialización segura desde Map.
  factory Track.fromMap(Map<String, dynamic> map) {
    final durationMs = map['durationMs'];
    return Track(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      filePath: map['filePath'] as String,
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
      coverPath: map['coverPath'] as String?,
      genre: map['genre'] as String?,
      trackNumber: map['trackNumber'] as int?,
      year: map['year'] as int?,
      artworkUrl: map['artworkUrl'] as String?,
    );
  }

  /// Copia con campos opcionales sobrescritos (ej: añadir duración tras
  /// cargar el archivo en el reproductor).
  Track copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? coverPath,
    String? genre,
    int? trackNumber,
    int? year,
    String? artworkUrl,
  }) {
    return Track(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      filePath: filePath,
      duration: duration ?? this.duration,
      coverPath: coverPath ?? this.coverPath,
      genre: genre ?? this.genre,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
      artworkUrl: artworkUrl ?? this.artworkUrl,
    );
  }

  // Dos pistas son iguales si apuntan al mismo archivo: necesario para
  // `indexWhere` en la cola y para evitar duplicados al escanear.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Track && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Track($title - $artist)';
}
