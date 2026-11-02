import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/extensions/data/approved_extension_catalog.dart';

void main() {
  test('catálogo vacío es válido', () {
    expect(
      parseApprovedCatalog('{"schemaVersion":1,"extensions":[]}'),
      isEmpty,
    );
  });
  test('rechaza entradas de versión inválida', () {
    expect(
      () => parseApprovedCatalog(
        '{"schemaVersion":1,"extensions":[{"id":"test.theme","name":"Tema","summary":"Tema local","author":"Autor","version":"latest","category":"appearance"}]}',
      ),
      throwsFormatException,
    );
  });
  test('rechaza versiones de esquema desconocidas', () {
    expect(
      () => parseApprovedCatalog('{"schemaVersion":4,"extensions":[]}'),
      throwsFormatException,
    );
  });
}
