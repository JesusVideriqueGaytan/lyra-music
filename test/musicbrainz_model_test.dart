import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/online/data/musicbrainz_service.dart';

void main() {
  test('MusicBrainz model parses public recording metadata', () {
    final song = MusicBrainzRecording.fromJson({
      'id': 'abc-123',
      'title': 'Ejemplo',
      'length': 180000,
      'artist-credit': [
        {'name': 'Artista Ejemplo'},
      ],
      'releases': [
        {'title': 'Disco Ejemplo'},
      ],
    });
    expect(song.title, 'Ejemplo');
    expect(song.artist, 'Artista Ejemplo');
    expect(song.album, 'Disco Ejemplo');
    expect(song.duration.inSeconds, 180);
    expect(song.website.host, 'musicbrainz.org');
  });

  test('MusicBrainz model handles incomplete metadata', () {
    final song = MusicBrainzRecording.fromJson({'id': 'test', 'title': 'Demo'});
    expect(song.artist, 'Artista desconocido');
    expect(song.album, 'Álbum no identificado');
    expect(song.duration, Duration.zero);
  });
}
