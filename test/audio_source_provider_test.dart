import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/online/data/audio_source_provider.dart';

void main() {
  const provider = DirectAudioSourceProvider();

  test('Admite un enlace directo HTTPS y crea una pista remota', () {
    final track = provider.createTrack(
      url: 'https://cdn.example.org/audio/song.mp3?access=public',
      title: 'Canción de prueba',
      artist: 'Artista',
    );
    expect(track.isRemote, isTrue);
    expect(track.title, 'Canción de prueba');
    expect(track.artist, 'Artista');
    expect(
      track.filePath,
      'https://cdn.example.org/audio/song.mp3?access=public',
    );
  });

  test('El adaptador no acepta páginas de video o Spotify', () {
    expect(
      () => provider.validate('https://www.youtube.com/watch?v=abc'),
      throwsFormatException,
    );
    expect(
      () => provider.validate('https://music.youtube.com/watch?v=abc'),
      throwsFormatException,
    );
    expect(
      () => provider.validate('https://open.spotify.com/track/abc'),
      throwsFormatException,
    );
  });

  test('Exige HTTPS e impide URLs con credenciales incrustadas', () {
    expect(
      () => provider.validate('http://example.org/a.mp3'),
      throwsFormatException,
    );
    expect(
      () => provider.validate('https://user:pass@example.org/a.mp3'),
      throwsFormatException,
    );
    expect(() => provider.validate('not an url'), throwsFormatException);
  });

  test('Metadatos opcionales no impiden reproducir una fuente', () {
    final track = provider.createTrack(
      url: 'https://audio.example.com/stream',
      title: '',
      artist: '',
    );
    expect(track.title, 'Audio en línea');
    expect(track.isRemote, isTrue);
  });
}
