import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';
import 'package:lyra_music/features/ytmusic/presentation/widgets/song_actions.dart';

void main() {
  test('una playlist mantiene los mismos IDs, duración y orden', () {
    const songs = [
      Track(id: 'ytmusic:abcdefghijk', title: 'Pista A', artist: 'Artista',
        album: 'Álbum', filePath: 'https://music.youtube.com/watch?v=abcdefghijk',
        duration: Duration(seconds: 174)),
      Track(id: 'ytmusic:lmnopqrstuv', title: 'Pista B', artist: 'Artista',
        album: 'Álbum', filePath: 'https://music.youtube.com/watch?v=lmnopqrstuv'),
    ];
    final restored = LyraPlaylist.fromMap(
      const LyraPlaylist(id: 'playlist-1', name: 'Favoritas', tracks: songs).toMap());
    expect(restored.tracks.map((song) => song.id), songs.map((song) => song.id));
    expect(songDurationLabel(restored.tracks.first.duration), '2:54');
    expect(songDurationLabel(restored.tracks.last.duration), '—');
  });

  test('actualiza canciones antiguas solo con el mismo ID', () {
    const saved = Track(id: 'ytmusic:abcdefghijk', title: 'Canción',
      artist: 'Artista desconocido', album: '',
      filePath: 'https://music.youtube.com/watch?v=abcdefghijk');
    const fresh = Track(id: 'ytmusic:abcdefghijk', title: 'Canción',
      artist: 'Eve', album: 'Album',
      filePath: 'https://music.youtube.com/watch?v=abcdefghijk',
      duration: Duration(minutes: 3));
    final merged = mergeTrackMetadata(saved, fresh);
    expect(merged.artist, 'Eve');
    expect(merged.duration, const Duration(minutes: 3));
    expect(mergeTrackMetadata(saved, const Track(id: 'otro', title: 'Canción',
      artist: 'Incorrecto', album: '', filePath: '')).artist,
      'Artista desconocido');
    expect(mergeTrackMetadata(fresh, saved).artist, 'Eve');
  });

  test('parser da prioridad a autor enlazado en una tercera columna', () {
    final songs = YtMusicClient.parseSongs({
      'musicResponsiveListItemRenderer': {
        'playlistItemData': {'videoId': 'abcdefghijk'},
        'flexColumns': [
          {'musicResponsiveListItemFlexColumnRenderer': {'text': {
            'runs': [{'text': 'Nombre real'}]}}},
          {'musicResponsiveListItemFlexColumnRenderer': {'text': {
            'runs': [{'text': 'Vídeo'}, {'text': ' • '}, {'text': '2:54'}]}}},
          {'musicResponsiveListItemFlexColumnRenderer': {'text': {
            'runs': [{'text': 'Eve', 'navigationEndpoint': {
              'browseEndpoint': {'browseId': 'UCtestArtist'}}}]}}},
        ],
      },
    });
    expect(songs.single.artist, 'Eve');
    expect(songs.single.artistId, 'UCtestArtist');
  });

  test('perfiles de artista MPLA se reconocen y se ordenan', () {
    final artists = YtMusicClient.parseArtists({
      'items': [
        {'musicResponsiveListItemRenderer': {
          'navigationEndpoint': {'browseEndpoint': {'browseId': 'MPLAartist1'}},
          'flexColumns': [
            {'musicResponsiveListItemFlexColumnRenderer': {'text': {
              'runs': [{'text': 'Kenshi Yonezu'}]}}}
          ]
        }},
        {'musicResponsiveListItemRenderer': {
          'navigationEndpoint': {'browseEndpoint': {'browseId': 'UCartist2'}},
          'flexColumns': [
            {'musicResponsiveListItemFlexColumnRenderer': {'text': {
              'runs': [{'text': 'Kenshi Yonezu Fan'}]}}}
          ]
        }}
      ]
    });
    expect(artists, hasLength(2));
    expect(YtMusicClient.rankArtists('Kenshi Yonezu', artists).first.id,
      'MPLAartist1');
  });
}
