import 'dart:math';

import '../point_json.dart';
import 'entity_base.dart';

mixin TokenModel on EntityBase {
  final Set<int> conds = {};
  int get id;
  String get prefabId;

  Point<double> position;
  double angle;
  String label = '';
  double auraRadius = 0;
  bool invisible = false;

  @override
  int get jsonFallbackSize => 0;

  void handleSnapEvent(Map json) {
    position = parsePoint<double>(json);
    angle = (json['angle'] as num ?? 0).toDouble();
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    handleSnapEvent(json);
    super.fromJson(json);
    label = json['label'] ?? '';
    auraRadius = (json['aura'] as num ?? 0).toDouble();
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
