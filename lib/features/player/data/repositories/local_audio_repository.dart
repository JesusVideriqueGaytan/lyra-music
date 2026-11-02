/// Repositorio de audio local (capa DATOS).
///
/// Escanea directorios del dispositivo en busca de archivos de audio y los
/// convierte en modelos [Track]. Mantiene además las carpetas autorizadas por
/// el usuario persistidas en SharedPreferences, para que la biblioteca
/// sobreviva entre sesiones sin pedir permisos cada vez.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lyra_music/features/player/domain/models/track.dart';

/// Clave de SharedPreferences donde se guarda la lista de carpetas escaneadas.
const String kScannedFoldersKey = 'lyra_scanned_folders';

/// Límite duro de archivos devueltos por escaneo: protege dispositivos tier
/// `low` de congelarse con bibliotecas de miles de canciones.
const int kMaxTracksPerScan = 5000;

/// Resultado de un escaneo: pistas encontradas + errores ocurridos.
class ScanResult {
  const ScanResult({
    required this.tracks,
    this.errors = const <String>[],
    this.directoriesVisited = 0,
  });

  /// Pistas de audio encontradas (ordenadas alfabéticamente por título).
  final List<Track> tracks;

  /// Mensajes legibles de carpetas inaccesibles o fallas de lectura.
  final List<String> errors;

  /// Cantidad de directorios recorridos (para métricas/debug).
  final int directoriesVisited;

  bool get isEmpty => tracks.isEmpty;
}

/// Contrato del repositorio: facilita sustituirlo por un mock en tests.
abstract class AudioRepository {
  Future<ScanResult> scanFolder(String folderPath);
  Future<List<Track>> scanAll(List<String> folders);
  Future<List<String>> loadSavedFolders();
  Future<void> saveFolder(String folderPath);
  Future<void> removeFolder(String folderPath);
  Future<List<String>> defaultCandidateFolders();
}

/// Implementación real basada en `dart:io`.
class LocalAudioRepository implements AudioRepository {
  const LocalAudioRepository();

  @override
  Future<ScanResult> scanFolder(String folderPath) async {
    final directory = Directory(folderPath);
    final errors = <String>[];
    final tracks = <Track>[];
    var visited = 0;

    // Comprobación previa: carpeta inexistente o sin permisos => error claro
    // en la UI en lugar de una excepción cruda de dart:io.
    try {
      if (!await directory.exists()) {
        return ScanResult(
          tracks: const <Track>[],
          errors: <String>['La carpeta no existe: $folderPath'],
        );
      }
    } on FileSystemException catch (e) {
      return ScanResult(
        tracks: const <Track>[],
        errors: <String>['Sin acceso a la carpeta: ${e.message}'],
      );
    }

    // Recorrido recursivo NO bloqueante (listen + await for) para no
    // congelar la UI en bibliotecas grandes.
    try {
      await for (final entity
          in directory.list(recursive: true, followLinks: false)) {
        if (tracks.length >= kMaxTracksPerScan) {
          errors.add(
            'Se alcanzó el límite de $kMaxTracksPerScan canciones; '
            'la biblioteca podría estar incompleta.',
          );
          break;
        }
        if (entity is! File) continue;
        visited++;

        final path = entity.path.toLowerCase();
        final isAudio = kSupportedAudioExtensions
            .any((ext) => path.endsWith(ext));
        if (!isAudio) continue;

        // Ocultamos artefactos temporales (.tmp, archivos ocultos de
        // reproductores como .lrc no son audio real).
        final name = path.split(Platform.pathSeparator).last;
        if (name.startsWith('.')) continue;

        tracks.add(Track.fromFilePath(entity.path));
      }
    } on FileSystemException catch (e) {
      // Subcarpetas protegidas (ej. Android/sdcard restringida): registramos
      // el problema pero devolvemos lo ya encontrado (degradación elegante).
      errors.add('No se pudo leer una subcarpeta: ${e.message}');
    }

    // Orden estable por título para que la biblioteca no cambie de orden
    // entre escaneos.
    tracks.sort((a, b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return ScanResult(
      tracks: tracks,
      errors: errors,
      directoriesVisited: visited,
    );
  }

  @override
  Future<List<Track>> scanAll(List<String> folders) async {
    final seen = <String>{}; // Deduplicado por id (ruta absoluta).
    final allTracks = <Track>[];

    for (final folder in folders) {
      final result = await scanFolder(folder);
      for (final track in result.tracks) {
        if (seen.add(track.id)) {
          allTracks.add(track);
        }
      }
    }

    allTracks.sort((a, b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return allTracks;
  }

  @override
  Future<List<String>> loadSavedFolders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(kScannedFoldersKey) ?? <String>[];
  }

  @override
  Future<void> saveFolder(String folderPath) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(kScannedFoldersKey) ?? <String>[];
    if (!current.contains(folderPath)) {
      current.add(folderPath);
      await prefs.setStringList(kScannedFoldersKey, current);
    }
  }

  @override
  Future<void> removeFolder(String folderPath) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(kScannedFoldersKey) ?? <String>[];
    current.remove(folderPath);
    await prefs.setStringList(kScannedFoldersKey, current);
  }

  @override
  Future<List<String>> defaultCandidateFolders() async {
    // Sugerencias multiplataforma: en desktop usamos Music/Home reales;
    // en móvil la carpeta pública de música se intentará vía external
    // storage más adelante (Fase 2.x con permission_handler).
    final candidates = <String>[];

    try {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'];
      if (home != null) {
        candidates.add('$home${Platform.pathSeparator}Music');
        candidates.add(home);
      }
    } on UnsupportedError {
      // Algunos entornos (web/tests) no exponen variables de entorno.
    }

    try {
      final documents = await getApplicationDocumentsDirectory();
      candidates.add(documents.path);
    } catch (_) {
      // Plugin no disponible en este platform: ignoramos la sugerencia.
    }

    // Filtramos solo las que realmente existen como directorio.
    final existing = <String>[];
    for (final path in candidates.toSet()) {
      try {
        if (await Directory(path).exists()) existing.add(path);
      } on FileSystemException {
        continue;
      }
    }
    return existing;
  }
}

/// Provider del repositorio: se mantiene vivo mientras la app corra.
final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  return const LocalAudioRepository();
});
