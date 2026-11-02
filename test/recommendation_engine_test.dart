import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/home/domain/recommendation_engine.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

void main() {
  const a = Track(
    id: 'a',
    title: 'A',
    artist: 'Björk',
    album: 'Álbum',
    filePath: '/tmp/a.mp3',
  );
  const b = Track(
    id: 'b',
    title: 'B',
    artist: 'Radiohead',
    album: 'Álbum',
    filePath: '/tmp/b.mp3',
  );

  test('sin historial no hay recomendaciones inventadas', () {
    expect(recommendationSeed(const MusicCollectionState()), isNull);
  });

  test('el historial real determina el artista sugerido', () {
    final state = MusicCollectionState(
      records: {
        'a': const ListeningRecord(track: a, plays: 5, ms: 600000),
        'b': const ListeningRecord(track: b, plays: 1, ms: 10000),
      },
    );
    expect(recommendationSeed(state)?.artist, 'Björk');
  });

  test('favoritos permiten sugerir sin estadísticas', () {
    const state = MusicCollectionState(favorites: {'b': b});
    expect(recommendationSeed(state)?.artist, 'Radiohead');
  });

  test('artista desconocido nunca se usa como recomendación', () {
    const unknown = Track(
      id: 'x',
      title: 'X',
      artist: 'Artista desconocido',
      album: '',
      filePath: '/tmp/x.mp3',
    );
    const state = MusicCollectionState(favorites: {'x': unknown});
    expect(recommendationSeed(state), isNull);
  });
}
