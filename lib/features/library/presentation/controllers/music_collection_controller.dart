/// Biblioteca personal de Lyra: favoritos, playlists, historial y estadísticas.
/// Los datos son locales, sin cuenta y sin enviar telemetría.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/core/metadata/artist_name.dart';

const _storageKey = 'lyra_music_collection_v1';
/// Playlist de favoritos virtual. No se serializa como playlist normal y
/// nunca se puede borrar ni renombrar por accidente.
const likedPlaylistId = 'lyra:liked';

/// Convierte una pista remota en una referencia estable. Nunca guardamos
/// enlaces googlevideo temporales o firmados dentro de la biblioteca.
Track persistentTrack(Track track) {
  if (track.id.startsWith('ytmusic:')) {
    final id = track.id.substring('ytmusic:'.length);
    return Track(
      id: track.id, title: track.title, artist: track.artist,
      album: track.album, filePath: 'https://music.youtube.com/watch?v=$id',
      duration: track.duration, artworkUrl: track.artworkUrl,
      coverPath: track.coverPath, artistId: track.artistId,
    );
  }
  return track;
}

/// Conserva metadatos válidos previos y repara solo valores incompletos.
/// El ID estable permite actualizar historial, playlists y favoritos juntos.
bool hasKnownArtist(String text) => isUsableArtistName(text);

Track mergeTrackMetadata(Track original, Track fresh) {
  if (original.id != fresh.id) return original;
  return original.copyWith(
    artist: !hasKnownArtist(original.artist) && hasKnownArtist(fresh.artist)
        ? fresh.artist : null,
    artistId: original.artistId == null ? fresh.artistId : null,
    duration: original.duration ?? fresh.duration,
    artworkUrl: (original.artworkUrl?.isEmpty ?? true) ? fresh.artworkUrl : null,
    album: (original.album.trim().isEmpty || original.album == 'Álbum desconocido') &&
        fresh.album.trim().isNotEmpty ? fresh.album : null,
  );
}

class LyraPlaylist {
  const LyraPlaylist({required this.id, required this.name, required this.tracks});
  final String id;
  final String name;
  final List<Track> tracks;
  Map<String, dynamic> toMap() => {
    'id': id, 'name': name,
    'tracks': tracks.map((t) => persistentTrack(t).toMap()).toList(),
  };
  factory LyraPlaylist.fromMap(Map<String, dynamic> map) => LyraPlaylist(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? 'Sin título',
    tracks: ((map['tracks'] as List?) ?? const [])
        .whereType<Map>().map((m) => Track.fromMap(Map<String, dynamic>.from(m))).toList(),
  );
}

class ListeningRecord {
  const ListeningRecord({required this.track, required this.plays, required this.ms});
  final Track track;
  final int plays;
  final int ms;
  Map<String, dynamic> toMap() => {
    'track': persistentTrack(track).toMap(), 'plays': plays, 'ms': ms,
  };
  factory ListeningRecord.fromMap(Map<String, dynamic> map) => ListeningRecord(
    track: Track.fromMap(Map<String, dynamic>.from(map['track'] as Map)),
    plays: (map['plays'] as num?)?.toInt() ?? 0,
    ms: (map['ms'] as num?)?.toInt() ?? 0,
  );
  ListeningRecord withPlay(Track t) => ListeningRecord(track: persistentTrack(t), plays: plays + 1, ms: ms);
  ListeningRecord withListen(Track t, int delta) => ListeningRecord(track: persistentTrack(t), plays: plays, ms: ms + delta);
}

class MusicCollectionState {
  const MusicCollectionState({
    this.favorites = const {},
    this.playlists = const [],
    this.history = const [],
    this.records = const {},
    this.ready = false,
  });
  final Map<String, Track> favorites;
  final List<LyraPlaylist> playlists;
  final List<Track> history;
  final Map<String, ListeningRecord> records;
  final bool ready;
  int get totalListeningMs => records.values.fold(0, (a, b) => a + b.ms);
  int get totalPlays => records.values.fold(0, (a, b) => a + b.plays);
  bool isFavorite(Track track) => favorites.containsKey(track.id);
  LyraPlaylist get likedPlaylist => LyraPlaylist(
    id: likedPlaylistId, name: 'Me gusta', tracks: favorites.values.toList());
}

class MusicCollectionController extends Notifier<MusicCollectionState> {
  SharedPreferences? _prefs;
  bool _changedWhileLoading = false;
  Future<void>? _writeFuture;
  int _writeGeneration = 0;

  @override
  MusicCollectionState build() {
    unawaited(_load());
    return const MusicCollectionState();
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_storageKey);
      if (_changedWhileLoading || raw == null || raw.isEmpty) {
        state = MusicCollectionState(
          favorites: state.favorites, playlists: state.playlists,
          history: state.history, records: state.records, ready: true,
        );
        if (_changedWhileLoading) _save();
        return;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final favs = <String, Track>{};
      for (final entry in (map['favorites'] as List? ?? const [])) {
        final t = Track.fromMap(Map<String, dynamic>.from(entry as Map));
        favs[t.id] = t;
      }
      final records = <String, ListeningRecord>{};
      for (final entry in (map['records'] as List? ?? const [])) {
        final r = ListeningRecord.fromMap(Map<String, dynamic>.from(entry as Map));
        records[r.track.id] = r;
      }
      state = MusicCollectionState(
        favorites: favs,
        playlists: (map['playlists'] as List? ?? const [])
          .map((p) => LyraPlaylist.fromMap(Map<String, dynamic>.from(p as Map))).toList(),
        history: (map['history'] as List? ?? const [])
          .map((t) => Track.fromMap(Map<String, dynamic>.from(t as Map))).take(30).toList(),
        records: records, ready: true,
      );
    } catch (_) {
      // Un archivo corrupto o una falta de permisos nunca impide abrir Lyra.
      state = MusicCollectionState(
        favorites: state.favorites, playlists: state.playlists,
        history: state.history, records: state.records, ready: true,
      );
    }
  }

  void _update(MusicCollectionState newState) {
    if (!state.ready) _changedWhileLoading = true;
    state = newState;
    _save();
  }

  void _save() {
    if (_prefs == null) return;
    final generation = ++_writeGeneration;
    final snapshot = jsonEncode({
      'favorites': state.favorites.values.map((t) => persistentTrack(t).toMap()).toList(),
      'playlists': state.playlists.map((p) => p.toMap()).toList(),
      'history': state.history.map((t) => persistentTrack(t).toMap()).toList(),
      'records': state.records.values.map((r) => r.toMap()).toList(),
    });
    // Serializar escrituras para que un guardado antiguo no sobrescriba otro
    // más reciente. No persistir en cada frame del reproductor.
    _writeFuture = (_writeFuture ?? Future.value()).then((_) async {
      if (generation <= _writeGeneration) {
        await _prefs?.setString(_storageKey, snapshot);
      }
    }).catchError((Object _) {});
  }

  /// Cuando el catálogo devuelve metadatos más completos, reparar registros
  /// anteriores por videoId. No cambia la cola activa ni cifras de escuchas.
  void enrichTracks(Iterable<Track> results) {
    final byId = <String, Track>{
      for (final track in results) if (track.id.startsWith('ytmusic:'))
        track.id: track,
    };
    if (byId.isEmpty) return;
    var changed = false;
    Track update(Track current) {
      final fresh = byId[current.id];
      if (fresh == null) return current;
      final next = mergeTrackMetadata(current, fresh);
      if (next.artist != current.artist || next.artistId != current.artistId ||
          next.artworkUrl != current.artworkUrl || next.duration != current.duration ||
          next.album != current.album) changed = true;
      return next;
    }
    final favorites = <String, Track>{
      for (final entry in state.favorites.entries) entry.key: update(entry.value),
    };
    final playlists = [
      for (final playlist in state.playlists)
        LyraPlaylist(id: playlist.id, name: playlist.name,
          tracks: playlist.tracks.map(update).toList()),
    ];
    final history = state.history.map(update).toList();
    final records = <String, ListeningRecord>{
      for (final entry in state.records.entries)
        entry.key: ListeningRecord(track: update(entry.value.track),
            plays: entry.value.plays, ms: entry.value.ms),
    };
    if (changed) {
      _update(MusicCollectionState(favorites: favorites, playlists: playlists,
        history: history, records: records, ready: state.ready));
    }
  }

  void toggleFavorite(Track track) {
    final next = <String, Track>{...state.favorites};
    if (next.containsKey(track.id)) {
      next.remove(track.id);
    } else {
      next[track.id] = persistentTrack(track);
    }
    _update(MusicCollectionState(favorites: next, playlists: state.playlists,
        history: state.history, records: state.records, ready: state.ready));
  }

  String createPlaylist(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '';
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _update(MusicCollectionState(favorites: state.favorites,
      playlists: [...state.playlists, LyraPlaylist(id: id, name: clean, tracks: const [])],
      history: state.history, records: state.records, ready: state.ready));
    return id;
  }

  /// Añade un álbum o catálogo completo de forma atómica y sin duplicados.
  /// El orden original se mantiene y la portada proviene de la primera pista.
  int addTracksToPlaylist(String playlistId, Iterable<Track> tracks) {
    if (playlistId == likedPlaylistId) {
      final next = {...state.favorites};
      var added = 0;
      for (final track in tracks) {
        if (next.containsKey(track.id)) continue;
        next[track.id] = persistentTrack(track);
        added++;
      }
      if (added != 0) _update(MusicCollectionState(favorites: next,
        playlists: state.playlists, history: state.history,
        records: state.records, ready: state.ready));
      return added;
    }
    if (!state.playlists.any((p) => p.id == playlistId)) return 0;
    var added = 0;
    final next = <LyraPlaylist>[];
    for (final playlist in state.playlists) {
      if (playlist.id != playlistId) { next.add(playlist); continue; }
      final ids = playlist.tracks.map((t) => t.id).toSet();
      final merged = [...playlist.tracks];
      for (final track in tracks) {
        if (!ids.add(track.id)) continue;
        merged.add(persistentTrack(track));
        added++;
      }
      next.add(LyraPlaylist(id: playlist.id, name: playlist.name,
        tracks: merged));
    }
    if (added != 0) _update(MusicCollectionState(favorites: state.favorites,
      playlists: next, history: state.history, records: state.records,
      ready: state.ready));
    return added;
  }

  void removePlaylist(String id) {
    if (id == likedPlaylistId) return;
    _update(MusicCollectionState(
    favorites: state.favorites,
    playlists: state.playlists.where((p) => p.id != id).toList(),
    history: state.history, records: state.records, ready: state.ready));
  }

  void renamePlaylist(String id, String name) {
    if (id == likedPlaylistId) return;
    final clean = name.trim();
    if (clean.isEmpty) return;
    _update(MusicCollectionState(favorites: state.favorites,
      playlists: [for (final p in state.playlists)
        if (p.id == id) LyraPlaylist(id: p.id, name: clean, tracks: p.tracks) else p],
      history: state.history, records: state.records, ready: state.ready));
  }

  void addToPlaylist(String playlistId, Track track) {
    if (playlistId == likedPlaylistId) {
      if (!state.isFavorite(track)) toggleFavorite(track);
      return;
    }
    _update(MusicCollectionState(favorites: state.favorites,
      playlists: [for (final p in state.playlists)
        if (p.id == playlistId)
          LyraPlaylist(id: p.id, name: p.name, tracks: p.tracks.any((t) => t.id == track.id)
            ? p.tracks : [...p.tracks, persistentTrack(track)])
        else p],
      history: state.history, records: state.records, ready: state.ready));
  }

  void removeFromPlaylist(String playlistId, String trackId) {
    if (playlistId == likedPlaylistId) {
      if (state.favorites.containsKey(trackId)) toggleFavorite(state.favorites[trackId]!);
      return;
    }
    _update(MusicCollectionState(favorites: state.favorites,
      playlists: [for (final p in state.playlists)
        if (p.id == playlistId)
          LyraPlaylist(id: p.id, name: p.name,
            tracks: p.tracks.where((t) => t.id != trackId).toList())
        else p],
      history: state.history, records: state.records, ready: state.ready));
  }

  void recordStarted(Track track) {
    final t = persistentTrack(track);
    final previous = state.records[t.id] ?? ListeningRecord(track: t, plays: 0, ms: 0);
    _update(MusicCollectionState(favorites: state.favorites, playlists: state.playlists,
      history: [t, ...state.history.where((h) => h.id != t.id)].take(30).toList(),
      records: {...state.records, t.id: previous.withPlay(t)}, ready: state.ready));
  }

  void addListening(Track track, Duration duration) {
    if (duration.inMilliseconds <= 0) return;
    final t = persistentTrack(track);
    final previous = state.records[t.id] ?? ListeningRecord(track: t, plays: 0, ms: 0);
    _update(MusicCollectionState(favorites: state.favorites, playlists: state.playlists,
      history: state.history, records: {...state.records,
        t.id: previous.withListen(t, duration.inMilliseconds)}, ready: state.ready));
  }

  void clearHistory() => _update(MusicCollectionState(
    favorites: state.favorites, playlists: state.playlists,
    records: state.records, ready: state.ready));

  void clearStatistics() => _update(MusicCollectionState(
    favorites: state.favorites, playlists: state.playlists,
    history: state.history, ready: state.ready));
}

final musicCollectionProvider =
    NotifierProvider<MusicCollectionController, MusicCollectionState>(
  MusicCollectionController.new,
);
