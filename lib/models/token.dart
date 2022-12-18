import 'dart:math';

import '../point_json.dart';
import 'entity_base.dart';

mixin TokenModel on EntityBase {
  final Set<int> conds = {};
  int get id;

  Point<double> position;
  String label = '';
  double auraRadius = 0;
  bool invisible = false;

  @override
  int get jsonFallbackSize => 0;

  @override
  void fromJson(Map<String, dynamic> json) {
    position = parsePoint<double>(json);
    label = json['label'] ?? '';
    size = json['size'] ?? 0;
    auraRadius = (json['aura'] as num ?? 0).toDouble();
    invisible = json['invisible'] ?? false;
    conds.clear();
    conds.addAll(List.from(json['conds'] ?? []));
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        ...writePoint(position),
        ...super.toJson(),
        'label': label,
        'conds': conds.toList(),
        'aura': auraRadius,
        'invisible': invisible,
      };
}
