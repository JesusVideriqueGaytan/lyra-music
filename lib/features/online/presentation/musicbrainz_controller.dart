/// Búsqueda de metadatos sin necesidad de una cuenta.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyra_music/features/online/data/musicbrainz_service.dart';

class MusicBrainzSearchState {
  const MusicBrainzSearchState({
    this.loading = false,
    this.query = '',
    this.results = const [],
    this.error,
  });
  final bool loading;
  final String query;
  final List<MusicBrainzRecording> results;
  final String? error;
}

class MusicBrainzController extends Notifier<MusicBrainzSearchState> {
  int _generation = 0;
  @override
  MusicBrainzSearchState build() => const MusicBrainzSearchState();

  Future<void> search(String query) async {
    final generation = ++_generation;
    if (query.trim().isEmpty) {
      state = const MusicBrainzSearchState();
      return;
    }
    state = MusicBrainzSearchState(loading: true, query: query);
    try {
      final recordings = await const MusicBrainzService().search(query);
      if (generation != _generation) return;
      state = MusicBrainzSearchState(query: query, results: recordings);
    } catch (error) {
      if (generation != _generation) return;
      state = MusicBrainzSearchState(query: query, error: '$error');
    }
  }
}

final musicBrainzControllerProvider =
    NotifierProvider<MusicBrainzController, MusicBrainzSearchState>(
      MusicBrainzController.new,
    );
