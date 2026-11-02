import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

void main() {
  test('una duración guardada por error no aparece como artista', () {
    const track = Track(
      id: 'ytmusic:abcdefghijk',
      title: 'Ghost Avenue',
      artist: '2:54',
      album: 'YouTube Music',
      filePath: 'https://example.org/music',
    );
    expect(track.displayArtist, 'Artista desconocido');
  });
}
