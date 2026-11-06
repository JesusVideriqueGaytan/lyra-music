import 'package:flutter_test/flutter_test.dart';
import 'package:lyra_music/features/player/domain/models/queue_visual_order.dart';

void main() {
  test('orden visual es historial, actual y siguientes', () {
    const visual = QueueVisualOrder(31, 10);
    expect(visual.activeIndex, 10);
    expect(visual.nextCount, 20);
    expect(visual.sourceIndex(0), 0);
    expect(visual.sourceIndex(10), 10);
    expect(visual.sourceIndex(30), 30);
    expect(visual.isHistory(9), isTrue);
    expect(visual.isHistory(10), isFalse);
    expect(visual.initialOffset(72), 728);
  });

  test('drag de pista pasada programa una COPIA, no mueve el historial', () {
    const visual = QueueVisualOrder(6, 2);
    final action = visual.dragIntent(0, 2); // tras la actual
    expect(action?.kind, QueueDragKind.replayHistory);
    expect(action?.sourceIndex, 0);
    expect(action?.targetIndex, 3);
    final farther = visual.dragIntent(1, 4);
    expect(farther?.kind, QueueDragKind.replayHistory);
    expect(farther?.targetIndex, 5);
    // No permitir alterar la cronología del historial.
    expect(visual.dragIntent(0, 1), isNull);
  });

  test('las próximas se reordenan sin mover la canción actual', () {
    const visual = QueueVisualOrder(31, 10);
    final forward = visual.dragIntent(11, 15);
    expect(forward?.kind, QueueDragKind.moveUpcoming);
    expect(forward?.sourceIndex, 11);
    expect(forward?.targetIndex, 15);
    final backward = visual.dragIntent(15, 11);
    expect(backward?.targetIndex, 11);
    expect(visual.dragIntent(11, 0), isNull);
    expect(visual.dragIntent(10, 15), isNull);
    expect(visual.dragIntent(11, 11), isNull);
  });

  test('lista corta, reproducción al final y cola vacía', () {
    const last = QueueVisualOrder(3, 2);
    expect(last.dragIntent(0, 2)?.targetIndex, 3);
    expect(last.dragIntent(2, 1), isNull);
    const empty = QueueVisualOrder(0, -1);
    expect(empty.initialOffset(72), 0);
    expect(empty.dragIntent(0, 0), isNull);
    expect(() => empty.sourceIndex(0), throwsRangeError);
  });
}
