import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../communication.dart';
import '../font_awesome.dart';
import 'prefab.dart';

class Character {
  final String name;
  final int id;
  final CharacterPrefab prefab;
  int defaultModifier;

  final HtmlElement _onlineIndicator;
  bool _hasJoined = false;
  bool get hasJoined => _hasJoined;
  set hasJoined(bool hasJoined) {
    _hasJoined = hasJoined;

    if (hasJoined) {
      querySelector('#online').append(_onlineIndicator);
    } else {
      _onlineIndicator.remove();
    }
  }

  String get img => getGameFile('$IMAGE_TYPE_PC$id', cacheBreak: false);

  Character(this.id, String color, Map<String, dynamic> json)
      : name = json['name'],
        defaultModifier = json['mod'],
        prefab = CharacterPrefab(),
        _onlineIndicator = SpanElement() {
    _onlineIndicator
      ..append(icon('circle')..style.color = color)
      ..appendText(name);

    hasJoined = json['connected'] ?? false;
    prefab
      ..fromJson(json['prefab'] ?? {})
      ..character = this;
  }
}
