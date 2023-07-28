extension IterableExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool test(E element)) {
    try {
      return firstWhere(test);
    } on StateError {
      return null;
    }
  }

  E? find(bool Function(E e) condition) => firstWhereOrNull(condition);

  void forEachIndex(void Function(E e, int index) action) {
    var i = 0;
    for (var element in this) {
      action(element, i++);
    }
  }
}

extension NullIterableExtension<E> on Iterable<E?> {
  Iterable<E> get withoutNulls =>
      this.where((e) => e != null).map((e) => e as E);
}
