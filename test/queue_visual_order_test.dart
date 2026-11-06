import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/player/domain/models/queue_visual_order.dart';

void main() {
  test('la canción actual aparece primero y el historial al final', () {
    const visual = QueueVisualOrder(30, 9);
    expect(visual.nextCount, 21);
    expect(visual.sourceIndex(0), 9);
    expect(visual.sourceIndex(20), 29);
    expect(visual.sourceIndex(21), 8);
    expect(visual.sourceIndex(29), 0);
    expect(visual.isHistory(21), isTrue);
    expect(visual.isHistory(20), isFalse);
  });

  test('la cola de playlist mantiene todas sus pistas', () {
    const visual = QueueVisualOrder(100, 50);
    final indices = [for (var i = 0; i < 100; i++) visual.sourceIndex(i)];
    expect(indices.first, 50);
    expect(indices.toSet().length, 100);
    expect(indices.toSet(), {for (var i = 0; i < 100; i++) i});
  });

  test('arrastre solo cambia las próximas canciones', () {
    const visual = QueueVisualOrder(30, 9);
    expect(visual.reorderIndices(1, 5), (10, 13));
    expect(visual.reorderIndices(5, 1), (14, 10));
    expect(visual.reorderIndices(0, 2), isNull);
    expect(visual.reorderIndices(25, 3), isNull);
    expect(visual.reorderIndices(3, 0), (12, 10));
    expect(visual.reorderIndices(2, 21), (11, 29));
  });

  test('la cola sin reproducción resta estable', () {
    const visual = QueueVisualOrder(3, -1);
    expect([for (var i = 0; i < 3; i++) visual.sourceIndex(i)], [0, 1, 2]);
    expect(visual.reorderIndices(2, 1), (2, 1));
  });
}
