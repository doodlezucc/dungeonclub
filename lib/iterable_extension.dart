extension IterableExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool test(E element)) {
    try {
      return firstWhere(test);
    } on StateError {
      return null;
    }
  }
}
