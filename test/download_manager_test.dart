import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/downloads/download_manager.dart';

void main() {
  group('Biblioteca de descargas', () {
    test('los nombres no contienen separadores ni caracteres de control', () {
      expect(LyraDownloadManager.safeComponent('../Eve\\Album:Demo'),
          isNot(contains('/')));
      expect(LyraDownloadManager.safeComponent('../Eve\\Album:Demo'),
          isNot(contains('\\')));
      expect(LyraDownloadManager.safeComponent('A\u0000B'), 'A_B');
    });
    test('nombre vacío y nombres reservados no crean rutas inválidas', () {
      expect(LyraDownloadManager.safeComponent('..'), 'Sin nombre');
      expect(LyraDownloadManager.safeComponent(' '), 'Sin nombre');
      expect(LyraDownloadManager.safeComponent('.'), 'Sin nombre');
    });
    test('limita la longitud de los nombres', () {
      expect(LyraDownloadManager.safeComponent(List.filled(200, 'a').join()).length, 90);
    });
  });
}
