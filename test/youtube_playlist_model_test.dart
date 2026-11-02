import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/accounts/youtube/youtube_playlist_controller.dart';

void main() {
  test('YouTubePlaylist parses basic YouTube Data API response', () {
    final playlist = YouTubePlaylist.fromJson({
      'id': 'PLtest123',
      'snippet': {
        'title': 'Mi lista',
        'thumbnails': {
          'medium': {'url': 'https://example.com/cover.jpg'},
        },
      },
      'contentDetails': {'itemCount': 12},
    });
    expect(playlist.id, 'PLtest123');
    expect(playlist.title, 'Mi lista');
    expect(playlist.videoCount, 12);
    expect(playlist.thumbnail, 'https://example.com/cover.jpg');
  });

  test('YouTubePlaylistVideo handles removed videos safely', () {
    final video = YouTubePlaylistVideo.fromJson({
      'snippet': {
        'title': 'Vídeo eliminado',
        'resourceId': {'kind': 'youtube#video'},
      },
    });
    expect(video.title, 'Vídeo eliminado');
    expect(video.videoId, isEmpty);
    expect(video.channel, 'YouTube');
  });
}
