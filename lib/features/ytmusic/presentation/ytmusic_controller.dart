/// Estado independiente de YouTube Music; jamás guarda cookies en disco.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ytmusic_client.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

class YtMusicState {
  const YtMusicState({
    this.connected = false, this.loading = false,
    this.results = const [], this.artists = const [], this.playlists = const [],
    this.playlistSongs = const [], this.selectedPlaylistId,
    this.error, this.query = '',
  });
  final bool connected;
  final bool loading;
  final List<YtMusicSong> results;
  final List<YtMusicArtist> artists;
  final List<YtMusicPlaylist> playlists;
  final List<YtMusicSong> playlistSongs;
  final String? selectedPlaylistId;
  final String? error;
  final String query;
}

class YtMusicController extends Notifier<YtMusicState> {
  YtMusicBrowserSession? _session;
  int _generation = 0;
  @override
  YtMusicState build() {
    ref.onDispose(() { _session = null; });
    return const YtMusicState();
  }

  void clearSearch() {
    ++_generation;
    state = YtMusicState(connected: _session != null,
      playlists: state.playlists);
  }

  Future<void> search(String query) async {
    final token = ++_generation;
    if (query.trim().isEmpty) {
      state = YtMusicState(connected: _session != null, playlists: state.playlists);
      return;
    }
    state = YtMusicState(connected: _session != null, loading: true,
        query: query, playlists: state.playlists);
    try {
      final catalog = await const YtMusicClient().searchCatalog(query, session: _session);
      if (token != _generation) return;
      var artists = catalog.artists;
      final normalized = query.toLowerCase().trim();
      if (normalized.length >= 5 &&
          !artists.any((artist) => artist.name.toLowerCase() == normalized)) {
        // Una búsqueda de canciones no siempre incluye el perfil del artista.
        // Segunda consulta explícita, sin fabricar perfiles desde títulos.
        try {
          final expanded = await const YtMusicClient()
              .searchArtistProfiles(query, session: _session);
          if (token != _generation) return;
          artists = YtMusicClient.rankArtists(query,
            [...artists, ...expanded]);
        } catch (_) { /* Conservar la búsqueda original. */ }
      }
      final matched = artists.where((artist) {
        final name = artist.name.toLowerCase();
        return name.contains(normalized) ||
          normalized.split(RegExp(r'\s+')).every(name.contains);
      }).toList();
      if (ref.read(musicCollectionProvider).ready) {
        ref.read(musicCollectionProvider.notifier).enrichTracks([
        for (final song in catalog.songs)
          Track(id: 'ytmusic:${song.videoId}', title: song.title,
            artist: song.artist, album: song.album,
            filePath: 'https://music.youtube.com/watch?v=${song.videoId}',
            artistId: song.artistId, duration: song.duration,
            artworkUrl: song.thumbnail),
        ]);
      }
      state = YtMusicState(connected: _session != null, query: query,
          results: catalog.songs, artists: matched,
          playlists: state.playlists);
    } catch (e) {
      if (token != _generation) return;
      state = YtMusicState(connected: _session != null, query: query,
          error: e.toString(), playlists: state.playlists);
    }
  }

  Future<void> connectFromHeaders(String raw) async {
    try {
      final session = YtMusicBrowserSession.fromRequestHeaders(raw);
      state = const YtMusicState(loading: true);
      final playlists = await const YtMusicClient().getLibraryPlaylists(session);
      _session = session;
      state = YtMusicState(connected: true, playlists: playlists);
    } catch (e) {
      _session = null;
      state = YtMusicState(error: e.toString());
    }
  }

  Future<void> refreshLibrary() async {
    final session = _session;
    if (session == null) return;
    state = YtMusicState(connected: true, loading: true, playlists: state.playlists);
    try {
      final playlists = await const YtMusicClient().getLibraryPlaylists(session);
      state = YtMusicState(connected: true, playlists: playlists);
    } catch (e) {
      state = YtMusicState(connected: true, error: e.toString(), playlists: state.playlists);
    }
  }

  Future<void> loadPlaylist(String id) async {
    final session = _session;
    if (session == null) return;
    state = YtMusicState(connected: true, loading: true, playlists: state.playlists,
        selectedPlaylistId: id);
    try {
      final songs = await const YtMusicClient().getPlaylistSongs(id, session: session);
      state = YtMusicState(connected: true, playlists: state.playlists,
          playlistSongs: songs, selectedPlaylistId: id);
    } catch (e) {
      state = YtMusicState(connected: true, playlists: state.playlists,
          selectedPlaylistId: id, error: e.toString());
    }
  }

  void disconnect() {
    ++_generation;
    _session = null;
    state = const YtMusicState();
  }
}

final ytMusicControllerProvider = NotifierProvider<YtMusicController, YtMusicState>(
  YtMusicController.new,
);
