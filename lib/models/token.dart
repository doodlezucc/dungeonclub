import 'dart:math';

import '../point_json.dart';
import 'entity_base.dart';

mixin TokenModel on EntityBase {
  final Set<int> conds = {};
  int get id;
  String get prefabId;

  late Point<double> position;
  late double angle;
  String label = '';
  double auraRadius = 0;
  bool invisible = false;

  @override
  int get jsonFallbackSize => 0;

  void handleSnapEvent(Map json) {
    position = parsePoint<double>(json)!;

    num? angleValue = json['angle'];
    angle = angleValue?.toDouble() ?? 0;
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    handleSnapEvent(json);
    super.fromJson(json);
    label = json['label'] ?? '';

    num? auraRadiusValue = json['aura'];
    auraRadius = auraRadiusValue?.toDouble() ?? 0;

    invisible = json['invisible'] ?? false;
    conds.clear();
    conds.addAll(List.from(json['conds'] ?? []));
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        ...toJsonExcludeID(),
      };

  Map<String, dynamic> toJsonExcludeID() => {
        ...writePoint(position),
        ...super.toJson(), // shared properties of tokens and prefabs (size)
        'angle': angle,
        'label': label,
        'conds': conds.toList(),
        'aura': auraRadius,
        'invisible': invisible,
      };
}
