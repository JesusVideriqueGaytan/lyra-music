/// Contrato de publicación para teclas multimedia y MPRIS.
library;

import 'package:audio_service/audio_service.dart' as service;
import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';

void main() {
  // Estos tests son puros: no necesitan D-Bus, audio nativo ni Flutter Linux.
  test('Sin pista, el servicio no expone reproducción activa', () {
    final result = systemPlaybackState(const PlaybackState());
    expect(result.playing, false);
    expect(result.processingState, service.AudioProcessingState.idle);
    expect(result.controls, isEmpty);
  });

  test('Pista cargada: anterior, reproducir, siguiente y detener', () {
    const track = Track(
      id: 'track-1',
      filePath: '/tmp/track.mp3',
      title: 'Canción',
      artist: 'Artista',
      album: 'Álbum',
    );
    final result = systemPlaybackState(
      const PlaybackState(
        queue: [track],
        currentIndex: 0,
        position: Duration(seconds: 42),
      ),
    );
    expect(result.queueIndex, 0);
    expect(result.updatePosition, const Duration(seconds: 42));
    expect(result.controls.map((control) => control.action), [
      service.MediaAction.skipToPrevious,
      service.MediaAction.play,
      service.MediaAction.skipToNext,
      service.MediaAction.stop,
    ]);
  });

  test('Reproduciendo: MPRIS debe ofrecer pausa', () {
    const track = Track(
      id: 'track-2',
      filePath: '/tmp/track2.mp3',
      title: 'Otra canción',
      artist: 'Artista',
      album: 'Álbum',
    );
    final result = systemPlaybackState(
      const PlaybackState(queue: [track], currentIndex: 0, playing: true),
    );
    expect(result.controls[1].action, service.MediaAction.pause);
  });
}
