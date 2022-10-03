import 'dart:math';

final _regEndingInt = RegExp(r'(?<= |^)\d+$');

class MovableStruct {
  final String prefab;
  final String label;

  MovableStruct(this.prefab, this.label);
}

String generateNewLabel<T>(
  T tMovable,
  Iterable<T> tMovables,
  MovableStruct Function(T) toStruct,
) {
  final movables = tMovables.map(toStruct);
  final mov = toStruct(tMovable);

  // Part before last integer
  final pre = mov.label
      .substring(
          0, _regEndingInt.firstMatch(mov.label)?.start ?? mov.label.length)
      .trimRight();

  var maximum = 0;

  for (var m in movables) {
    if (m.prefab == mov.prefab) {
      final match = _regEndingInt.firstMatch(m.label);
      final preM = match == null ? m.label : m.label.substring(0, match.start);

      if (pre == preM.trimRight()) {
        if (match != null) {
          maximum = max(maximum, int.parse(match[0]));
        } else if (maximum == 0) {
          maximum = 1;
        }
      }
    }
  }

  if (maximum == 0) return mov.label;

  return '$pre ${maximum + 1}'.trimLeft();
}
