/// Orden de la cola: anteriores → actual → siguientes.
///
/// El arrastre de una pista escuchada NO elimina su entrada histórica:
/// programa una segunda reproducción en la sección de siguientes.
enum QueueDragKind { moveUpcoming, replayHistory }

class QueueDragIntent {
  const QueueDragIntent(this.kind, this.sourceIndex, this.targetIndex);
  final QueueDragKind kind;
  final int sourceIndex;

  /// moveUpcoming: índice de destino de onReorderItem ya ajustado.
  /// replayHistory: índice de INSERCIÓN (puede ser igual a length).
  final int targetIndex;
}

class QueueVisualOrder {
  const QueueVisualOrder(this.length, this.currentIndex);

  final int length;
  final int currentIndex;

  int get activeIndex =>
      length == 0 || currentIndex < 0 || currentIndex >= length
      ? 0
      : currentIndex;

  int get nextCount => length == 0 ? 0 : length - activeIndex - 1;

  bool isHistory(int visualIndex) => visualIndex < activeIndex;

  int sourceIndex(int visualIndex) {
    if (visualIndex < 0 || visualIndex >= length) {
      throw RangeError.range(visualIndex, 0, length - 1, 'visualIndex');
    }
    return visualIndex;
  }

  /// Al abrir, posicionar la canción activa al inicio del área visible.
  double initialOffset(double itemExtent, {double topPadding = 8}) =>
      length == 0 ? 0 : activeIndex * itemExtent + topPadding;

  /// Traduce un arrastre del widget a una acción sin alterar el historial.
  /// Flutter `onReorderItem` entrega `newVisual` con el índice YA ajustado
  /// después de retirar la entrada original.
  QueueDragIntent? dragIntent(int oldVisual, int newVisual) {
    if (length < 2 ||
        oldVisual < 0 ||
        oldVisual >= length ||
        oldVisual == activeIndex)
      return null;

    if (oldVisual < activeIndex) {
      // Arrastrar dentro del historial no cambia su cronología.
      // Al llevarla debajo de la actual, crear una copia futura.
      if (newVisual < activeIndex) return null;
      final insertAt = (newVisual + 1).clamp(activeIndex + 1, length);
      return QueueDragIntent(QueueDragKind.replayHistory, oldVisual, insertAt);
    }

    // Las pistas siguientes se reordenan entre sí, no se mezclan con el
    // historial ni desplazan la canción activa.
    if (newVisual <= activeIndex) return null;
    final target = newVisual.clamp(activeIndex + 1, length - 1);
    if (oldVisual == target) return null;
    return QueueDragIntent(QueueDragKind.moveUpcoming, oldVisual, target);
  }
}
