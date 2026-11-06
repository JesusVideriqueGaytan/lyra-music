import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/core/audio/mpv_cache_path.dart';
import 'package:lyra_music/features/player/data/playback_session_store.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';

void main() {
  const track = Track(id: 'ytmusic:abcdefghijk', title: 'Eve',
    artist: 'Eve', album: 'Bunka', filePath: 'https://music.youtube.com/watch?v=abcdefghijk',
    duration: Duration(minutes: 3));

  test('respeta XDG_CACHE_HOME y no inventa rutas sin HOME', () {
    expect(linuxMpvCacheDirectory({'HOME': '/home/lyra'}),
      '/home/lyra/.cache/mpv');
    expect(linuxMpvCacheDirectory({'HOME': '/home/lyra',
      'XDG_CACHE_HOME': '/tmp/cache'}), '/tmp/cache/mpv');
    expect(linuxMpvCacheDirectory({'MPV_HOME': '/tmp/custom-mpv',
      'XDG_CACHE_HOME': '/tmp/cache'}), '/tmp/custom-mpv');
    expect(linuxMpvCacheDirectory({'HOME': 'relative/home'}), isNull);
  });

  test('restaurar sesión no la deja al final de canción completada', () {
    final restored = SavedPlaybackSession.fromMap({
      'index': 0, 'queue': [track.toMap()], 'positionMs': 180000,
      'shuffle': false, 'repeat': 0, 'autoRadio': false,
    });
    expect(restored.queue.length, 1);
    expect(restored.position, Duration.zero);
  });

  test('omite pistas corruptas al recuperar sesión', () {
    final restored = SavedPlaybackSession.fromMap({
      'queue': [
        {'id':'', 'title':'Sin ID', 'artist':'X', 'album':'', 'filePath':''},
        track.toMap(),
        {'id':'malformed'},
      ],
      'index': 1, 'positionMs': 9000,
    });
    expect(restored.queue.map((t) => t.id).toList(), [track.id]);
    expect(restored.index, 0);
  });
}
