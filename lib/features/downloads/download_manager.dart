/// Biblioteca interna y cola secuencial de descargas de Lyra (escritorio).
/// Las tareas siguen activas al navegar entre pantallas, mientras Lyra esté abierta.
/// No evade restricciones del proveedor y no inicia una descarga sin autorización.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_audio_resolver.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';

enum DownloadPhase {
  queued,
  resolving,
  downloading,
  completed,
  failed,
  cancelled,
}

class LyraDownloadTask {
  LyraDownloadTask(this.track, {this.phase = DownloadPhase.queued, this.path});
  final Track track;
  DownloadPhase phase;
  double? progress;
  String? path;
  String? message;
}

/// No es un servicio del sistema: la descarga continúa en otras pantallas,
/// pero se interrumpe al cerrar el proceso de Lyra.
class LyraDownloadManager extends ChangeNotifier {
  LyraDownloadManager._();
  static final LyraDownloadManager instance = LyraDownloadManager._();

  /// Notifica solamente los cambios de archivos guardados, no cada avance.
  final ValueNotifier<int> libraryRevision = ValueNotifier<int>(0);
  final Map<String, LyraDownloadTask> _tasks = {};
  final Map<String, String> _savedPaths = {};
  bool _running = false;
  String? _activeId;
  HttpClient? _activeClient;
  Directory? _root;
  Future<void>? _ready;

  List<LyraDownloadTask> get tasks =>
      _tasks.values.toList().reversed.toList(growable: false);
  int get activeCount => _tasks.values
      .where(
        (t) =>
            t.phase == DownloadPhase.queued ||
            t.phase == DownloadPhase.resolving ||
            t.phase == DownloadPhase.downloading,
      )
      .length;
  bool isDownloaded(String id) => _savedPaths.containsKey(id);
  bool isPending(String id) {
    final p = _tasks[id]?.phase;
    return p == DownloadPhase.queued ||
        p == DownloadPhase.resolving ||
        p == DownloadPhase.downloading;
  }

  Future<void> initialize() => _ready ??= _load();

  Future<Directory> _baseDir() async {
    if (_root != null) return _root!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      '${support.path}${Platform.pathSeparator}lyra-private-audio',
    );
    await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  Future<File> _manifest() async {
    final base = await _baseDir();
    return File('${base.path}${Platform.pathSeparator}index.json');
  }

  Future<void> _load() async {
    try {
      final file = await _manifest();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || decoded['downloads'] is! List) return;
      final root = await _baseDir();
      for (final item in decoded['downloads'] as List) {
        if (item is! Map || item['track'] is! Map || item['path'] is! String)
          continue;
        try {
          final track = Track.fromMap(
            Map<String, dynamic>.from(item['track'] as Map),
          );
          final path = item['path'] as String;
          // Nunca confiar en rutas externas provenientes del índice.
          if (!File(path).absolute.path.startsWith(
            '${root.absolute.path}${Platform.pathSeparator}',
          ))
            continue;
          if (!await File(path).exists()) continue;
          _savedPaths[track.id] = path;
          _tasks[track.id] = LyraDownloadTask(
            track,
            phase: DownloadPhase.completed,
            path: path,
          );
        } catch (_) {
          /* Entrada dañada: ignorar únicamente ese registro. */
        }
      }
      libraryRevision.value++;
      notifyListeners();
    } catch (e) {
      debugPrint('Lyra: no se pudo cargar el índice de descargas: $e');
    }
  }

  Future<void> _persist() async {
    final file = await _manifest();
    final temp = File('${file.path}.tmp');
    final items = <Map<String, Object?>>[];
    for (final task in _tasks.values) {
      final path = _savedPaths[task.track.id];
      if (path != null) items.add({'track': task.track.toMap(), 'path': path});
    }
    await temp.writeAsString(
      jsonEncode({'version': 1, 'downloads': items}),
      flush: true,
    );
    if (Platform.isWindows && await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  bool _compatible(Track track) =>
      track.id.startsWith('ytmusic:') &&
      RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(track.id.substring(8));

  /// Acepta solamente archivos permitidos. Se limita a una tarea por ID.
  Future<int> enqueue(Iterable<Track> songs) async {
    await initialize();
    var added = 0;
    for (final track in songs) {
      if (!_compatible(track) || isDownloaded(track.id) || isPending(track.id))
        continue;
      _tasks.remove(track.id); // permitir repetir intentos fallidos
      _tasks[track.id] = LyraDownloadTask(track);
      added++;
    }
    if (added != 0) {
      notifyListeners();
      unawaited(_pump());
    }
    return added;
  }

  Future<void> retry(String id) async {
    await initialize();
    final task = _tasks[id];
    if (task != null) await enqueue([task.track]);
  }

  /// Borrado explícito desde la aplicación; nunca toca otras carpetas.
  Future<void> removeDownloaded(String id) async {
    await initialize();
    final path = _savedPaths[id];
    if (path == null) return;
    final root = await _baseDir();
    final file = File(path);
    if (!file.absolute.path.startsWith(
      '${root.absolute.path}${Platform.pathSeparator}',
    ))
      return;
    if (await file.exists()) await file.delete();
    _savedPaths.remove(id);
    _tasks.remove(id);
    libraryRevision.value++;
    notifyListeners();
    await _persist();
  }

  void cancel(String id) {
    final task = _tasks[id];
    if (task == null || task.phase == DownloadPhase.completed) return;
    task.phase = DownloadPhase.cancelled;
    if (_activeId == id) _activeClient?.close(force: true);
    notifyListeners();
  }

  void cancelPending() {
    for (final task in _tasks.values) {
      if (task.phase == DownloadPhase.queued ||
          task.phase == DownloadPhase.resolving ||
          task.phase == DownloadPhase.downloading) {
        task.phase = DownloadPhase.cancelled;
      }
    }
    _activeClient?.close(force: true);
    notifyListeners();
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        LyraDownloadTask? task;
        for (final t in _tasks.values) {
          if (t.phase == DownloadPhase.queued) {
            task = t;
            break;
          }
        }
        if (task == null) break;
        _activeId = task.track.id;
        task.phase = DownloadPhase.resolving;
        notifyListeners();
        try {
          final path = await _download(task);
          if (task.phase != DownloadPhase.cancelled) {
            task.path = path;
            task.progress = 1;
            task.phase = DownloadPhase.completed;
            _savedPaths[task.track.id] = path;
            libraryRevision.value++;
            try {
              await _persist();
            } catch (e) {
              debugPrint(
                'Lyra: no se pudo actualizar el índice de descargas: $e',
              );
            }
          }
        } catch (e) {
          if (task.phase != DownloadPhase.cancelled) {
            task.phase = DownloadPhase.failed;
            task.message = e is HttpException
                ? 'El proveedor rechazó el audio o entregó un fragmento.'
                : 'No se pudo completar el guardado. Reintenta más tarde.';
          }
        } finally {
          _activeId = null;
          _activeClient = null;
          notifyListeners();
        }
      }
    } finally {
      _running = false;
    }
  }

  static String safeComponent(String text) {
    final value = text.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    if (value.isEmpty || value == '.' || value == '..') return 'Sin nombre';
    final clean = value.replaceAll(RegExp(r'^\.+|\.+$'), '_');
    return clean.length > 90 ? clean.substring(0, 90) : clean;
  }

  Future<String> _download(LyraDownloadTask task) async {
    final track = task.track;
    final id = track.id.substring(8);
    final stream = await const YtMusicAudioResolver().resolve(
      YtMusicSong(
        videoId: id,
        title: track.title,
        artist: track.displayArtist,
        album: track.album,
        thumbnail: track.artworkUrl,
      ),
    );
    if (task.phase == DownloadPhase.cancelled)
      throw const FileSystemException('Cancelada');
    final mime = stream.uri.queryParameters['mime'] ?? '';
    final ext = mime.contains('mp4')
        ? 'm4a'
        : mime.contains('mpeg')
        ? 'mp3'
        : 'webm';
    final root = await _baseDir();
    final folder = Directory(
      '${root.path}${Platform.pathSeparator}'
      '${safeComponent(track.displayArtist)}',
    );
    await folder.create(recursive: true);
    final output = File(
      '${folder.path}${Platform.pathSeparator}'
      '${safeComponent(track.title)} [$id].$ext',
    );
    if (await output.exists()) return output.path;
    final partial = File('${output.path}.lyra-part');
    if (await partial.exists()) await partial.delete();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    _activeClient = client;
    try {
      final request = await client
          .getUrl(stream.uri)
          .timeout(const Duration(seconds: 20));
      for (final header in stream.headers.entries) {
        if (!header.key.contains('\n') && !header.value.contains('\n')) {
          request.headers.set(header.key, header.value);
        }
      }
      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      if (response.statusCode == 206) {
        final range = response.headers.value('content-range');
        final match = range == null
            ? null
            : RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(range);
        if (match == null ||
            match.group(1) != '0' ||
            int.parse(match.group(2)!) + 1 != int.parse(match.group(3)!)) {
          throw const HttpException(
            'Respuesta parcial, no es el archivo completo',
          );
        }
      }
      task.phase = DownloadPhase.downloading;
      notifyListeners();
      final expected = response.contentLength;
      const maxBytes = 200 * 1024 * 1024;
      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response.timeout(
          const Duration(seconds: 40),
        )) {
          if (task.phase == DownloadPhase.cancelled) {
            throw const FileSystemException('Cancelada');
          }
          received += chunk.length;
          if (received > maxBytes) {
            throw const FileSystemException(
              'El archivo supera el límite de tamaño',
            );
          }
          sink.add(chunk);
          if (expected > 0) {
            final previous = task.progress ?? 0;
            final next = (received / expected).clamp(0.0, 1.0).toDouble();
            if (next - previous >= .015) {
              task.progress = next;
              notifyListeners();
            }
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (task.phase == DownloadPhase.cancelled ||
          received == 0 ||
          (expected > 0 && expected != received)) {
        throw const FileSystemException('Descarga interrumpida o incompleta');
      }
      // El archivo definitivo solo aparece tras terminar y validar el flujo.
      await partial.rename(output.path);
      return output.path;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }
}
