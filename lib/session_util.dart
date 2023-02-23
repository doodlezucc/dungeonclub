import 'dart:math';

import 'models/token.dart';

final _regEndingInt = RegExp(r'(?<= |^)\d+$');

String generateNewLabel<T extends TokenModel>(T token, Iterable<T> tokens) {
  // Part before last integer
  final pre = token.label
      .substring(
          0, _regEndingInt.firstMatch(token.label)?.start ?? token.label.length)
      .trimRight();

  var maximum = 0;

  for (var t in tokens) {
    if (t.prefabId == token.prefabId) {
      final match = _regEndingInt.firstMatch(t.label);
      final preT = match == null ? t.label : t.label.substring(0, match.start);

      if (pre == preT.trimRight()) {
        if (match != null) {
          maximum = max(maximum, int.parse(match[0]));
        } else if (maximum == 0) {
          maximum = 1;
        }
      }
    }
  }

  if (maximum == 0) return token.label;

  return '$pre ${maximum + 1}'.trimLeft();
}

extension IterableHelperExtension<T> on Iterable<T> {
  int getNextAvailableID(int Function(T e) getElementID) {
    return fold<int>(-1, (v, e) => max(v, getElementID(e))) + 1;
  }

  T find(bool Function(T e) condition) =>
      firstWhere(condition, orElse: () => null);

  void forEachIndex(void Function(T e, int index) action) {
    var i = 0;
    for (var element in this) {
      action(element, i++);
    }
  }
}

extension JsonListExtension<T> on List<T> {
  void fromJson(Iterable jsonList, T Function(dynamic json) constructor) {
    addAll(jsonList.map((jElem) => constructor(jElem)));
  }
}
