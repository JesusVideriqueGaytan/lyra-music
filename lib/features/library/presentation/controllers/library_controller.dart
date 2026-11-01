/// Controlador de la biblioteca local (capa PRESENTACIÓN).
///
/// Orquesta el escaneo de carpetas vía [AudioRepository] y expone un estado
/// derivado (búsqueda, filtro por carpeta, ordenación) para LibraryScreen.
library;

import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lyra_music/features/player/data/repositories/local_audio_repository.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

/// Criterios de ordenación disponibles en la biblioteca.
enum LibrarySort { title, artist, folder, duration }

extension LibrarySortUi on LibrarySort {
  String get label => switch (this) {
    LibrarySort.title => 'Título',
    LibrarySort.artist => 'Artista',
    LibrarySort.folder => 'Carpeta',
    LibrarySort.duration => 'Duración',
  };
}

/// Estado inmutable de la biblioteca.
class LibraryState {
  const LibraryState({
    this.tracks = const <Track>[],
    this.folders = const <String>[],
    this.isScanning = false,
    this.searchQuery = '',
    this.folderFilter,
    this.sort = LibrarySort.title,
    this.error,
  });

  /// Todas las pistas encontradas (sin filtrar).
  final List<Track> tracks;

  /// Carpetas autorizadas/persistidas.
  final List<String> folders;

  final bool isScanning;

  /// Texto del campo de búsqueda.
  final String searchQuery;

  /// Si no es null, solo se muestran pistas de esa carpeta exacta.
  final String? folderFilter;

  final LibrarySort sort;
  final String? error;

  /// Número total de canciones (para cabeceras/estadísticas).
  int get totalTracks => tracks.length;

  /// Lista ya filtrada + ordenada que consume la UI directamente.
  List<Track> get visibleTracks {
    var result = tracks;

    // Filtro por carpeta exacta (opcional, según requerimiento "filtrar por
    // carpeta").
    if (folderFilter != null) {
      result = result
          .where((t) => t.directoryPath == folderFilter)
          .toList(growable: false);
    }

    // Búsqueda difusa simple por título/artista/álbum (case-insensitive).
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      result = result
          .where(
            (t) =>
                t.title.toLowerCase().contains(query) ||
                t.artist.toLowerCase().contains(query) ||
                t.album.toLowerCase().contains(query),
          )
          .toList(growable: false);
    }

    // Ordenación estable.
    final sorted = <Track>[...result];
    sorted.sort((a, b) {
      switch (sort) {
        case LibrarySort.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case LibrarySort.artist:
          final byArtist = a.artist.toLowerCase().compareTo(
            b.artist.toLowerCase(),
          );
          return byArtist != 0
              ? byArtist
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case LibrarySort.folder:
          final byFolder = a.folderName.toLowerCase().compareTo(
            b.folderName.toLowerCase(),
          );
          return byFolder != 0
              ? byFolder
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case LibrarySort.duration:
          // Las pistas sin duración conocida van al final.
          final da = a.duration?.inMilliseconds ?? -1;
          final db = b.duration?.inMilliseconds ?? -1;
          return db.compareTo(da);
      }
    });
    return sorted;
  }

  LibraryState copyWith({
    List<Track>? tracks,
    List<String>? folders,
    bool? isScanning,
    String? searchQuery,
    String? folderFilter,
    bool clearFolderFilter = false,
    LibrarySort? sort,
    String? error,
    bool clearError = false,
  }) {
    return LibraryState(
      tracks: tracks ?? this.tracks,
      folders: folders ?? this.folders,
      isScanning: isScanning ?? this.isScanning,
      searchQuery: searchQuery ?? this.searchQuery,
      folderFilter: clearFolderFilter
          ? null
          : (folderFilter ?? this.folderFilter),
      sort: sort ?? this.sort,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier de la biblioteca.
class LibraryController extends Notifier<LibraryState> {
  AudioRepository get _repository => ref.read(audioRepositoryProvider);

  @override
  LibraryState build() {
    // Al construir, cargamos las carpetas guardadas y lanzamos un escaneo
    // automático si el usuario ya había autorizado alguna sesión previa.
    unawaited(_loadSavedFoldersAndScan());
    return const LibraryState();
  }

  Future<void>? _readyFuture;

  /// Espera inicialización completa (usado en tests/main).
  Future<void> waitUntilReady() => _readyFuture ??= _initialize();

  Future<void> _initialize() async {
    await _loadSavedFoldersAndScan();
  }

  Future<void> _loadSavedFoldersAndScan() async {
    try {
      final folders = await _repository.loadSavedFolders();
      state = state.copyWith(folders: folders);
      if (folders.isNotEmpty) {
        await rescan();
      }
    } catch (e) {
      state = state.copyWith(error: 'No se pudieron cargar las carpetas: $e');
    }
  }

  /// Vuelve a escanear todas las carpetas conocidas.
  Future<void> rescan() async {
    if (state.isScanning) return;
    state = state.copyWith(isScanning: true, clearError: true);

    try {
      final tracks = await _repository.scanAll(state.folders);
      state = state.copyWith(tracks: tracks, isScanning: false);
    } catch (e) {
      state = state.copyWith(isScanning: false, error: 'El escaneo falló: $e');
    }
  }

  /// Añade una carpeta y escanea solo su contenido (se fusiona con lo existente).
  Future<void> addFolder(String path) async {
    try {
      await _repository.saveFolder(path);
      state = state.copyWith(
        folders: <String>{...state.folders, path}.toList(),
      );
      final result = await _repository.scanFolder(path);
      final merged = <String, Track>{
        for (final t in state.tracks) t.id: t,
        for (final t in result.tracks) t.id: t,
      };
      state = state.copyWith(
        tracks: merged.values.toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          ),
      );
      if (result.errors.isNotEmpty) {
        state = state.copyWith(error: result.errors.first);
      }
    } catch (e) {
      state = state.copyWith(error: 'No se pudo añadir la carpeta: $e');
    }
  }

  /// Quita una carpeta y descarta sus pistas de la biblioteca.
  Future<void> removeFolder(String path) async {
    try {
      await _repository.removeFolder(path);
      state = state.copyWith(
        folders: state.folders.where((f) => f != path).toList(),
        tracks: state.tracks.where((t) => t.directoryPath != path).toList(),
      );
      if (state.folderFilter == path) {
        state = state.copyWith(clearFolderFilter: true);
      }
    } catch (e) {
      state = state.copyWith(error: 'No se pudo quitar la carpeta: $e');
    }
  }

  /// Actualiza el texto de búsqueda (llamado desde el TextField con debounce
  /// implícito por el propio widget de búsqueda de Material).
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Filtra la vista por una carpeta concreta (null = todas).
  void setFolderFilter(String? folderPath) {
    if (folderPath == null) {
      state = state.copyWith(clearFolderFilter: true);
    } else {
      state = state.copyWith(folderFilter: folderPath);
    }
  }

  void setSort(LibrarySort sort) {
    state = state.copyWith(sort: sort);
  }

  /// Carpetas únicas presentes en la biblioteca (para chips de filtro).
  List<String> uniqueFolders() {
    final set = <String>{};
    for (final track in state.tracks) {
      set.add(track.directoryPath);
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}

/// Provider de la biblioteca. No usamos autoDispose porque la lista debe
/// sobrevivir a la navegación entre pantallas.
final libraryControllerProvider =
    NotifierProvider<LibraryController, LibraryState>(LibraryController.new);

/// Provider derivado: lista visible (barato de recalcular gracias a que
/// LibraryState.visibleTracks es puro).
final visibleTracksProvider = Provider<List<Track>>((ref) {
  return ref.watch(libraryControllerProvider).visibleTracks;
});
