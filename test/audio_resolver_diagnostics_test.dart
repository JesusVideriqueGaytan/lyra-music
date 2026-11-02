import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_audio_resolver.dart';

void main() {
  test('403 explica restricción sin exponer URL de proveedor', () {
    final message = audioHttpFailureMessage(403);
    expect(message, contains('403'));
    expect(message, isNot(contains('googlevideo')));
  });
  test('429 distingue límite de solicitudes', () {
    expect(audioHttpFailureMessage(429), contains('solicitudes'));
  });
  test('servidor 5xx se distingue de audio inexistente', () {
    expect(audioHttpFailureMessage(503), contains('servidor'));
    expect(audioHttpFailureMessage(404), contains('no está disponible'));
  });
}
