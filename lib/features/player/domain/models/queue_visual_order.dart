/// Presenta la pista activa arriba sin alterar el orden original de la cola.
///
/// Orden: [actual, próximas..., anteriores en orden inverso].
/// Las anteriores se consultan desplazándose al final de la lista.
/// Solo las próximas pueden reordenarse mediante arrastre.
class QueueVisualOrder {
  const QueueVisualOrder(this.length, this.currentIndex);

  final int length;
  final int currentIndex;

  int get activeIndex =>
      length == 0 || currentIndex < 0 || currentIndex >= length
      ? 0
      : currentIndex;

  int get nextCount => length - activeIndex;

  bool isHistory(int visualIndex) => visualIndex >= nextCount;

  int sourceIndex(int visualIndex) {
    if (visualIndex < 0 || visualIndex >= length) {
      throw RangeError.range(visualIndex, 0, length - 1, 'visualIndex');
    }
    if (visualIndex < nextCount) return activeIndex + visualIndex;
    return activeIndex - 1 - (visualIndex - nextCount);
  }

  /// Traduce los índices de Flutter ReorderableListView a la cola real.
  /// Flutter comunica el destino antes de descontar la pista arrastrada.
  /// Devuelve null al intentar reordenar pista activa o historial.
  (int, int)? reorderIndices(int oldVisual, int newVisual) {
    if (oldVisual <= 0 || oldVisual >= nextCount) return null;
    if (newVisual > oldVisual) newVisual -= 1;
    if (newVisual < 1) newVisual = 1;
    if (newVisual >= nextCount) newVisual = nextCount - 1;
    if (newVisual == oldVisual) return null;
    return (activeIndex + oldVisual, activeIndex + newVisual);
  }
}
