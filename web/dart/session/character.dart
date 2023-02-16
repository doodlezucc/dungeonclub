import 'dart:html';

import 'package:dungeonclub/actions.dart';
import 'package:meta/meta.dart';

import '../communication.dart';
import '../font_awesome.dart';
import 'prefab.dart';
import 'session.dart';

class Character {
  final int id;
  final CharacterPrefab prefab;

  final _onlineIndicator = SpanElement();
  final _onlineIndicatorName = DivElement();
  final _onlineIndicatorTooltip = SpanElement();

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

  String get name => prefab.name;
  String get img => getGameFile('$IMAGE_TYPE_PC$id', cacheBreak: false);

  Character(
    this.id,
    Session session, {
    @required String color,
    @required String name,
    Map prefabJson,
    bool joined = false,
  }) : prefab = CharacterPrefab(name) {
    _onlineIndicator
      ..append(icon('circle')..style.color = color)
      ..append(_onlineIndicatorName);

    if (session.isDM) {
      _onlineIndicator
        ..className = 'with-tooltip'
        ..append(_onlineIndicatorTooltip)
        ..onClick.listen((_) {
          socket.sendAction(GAME_KICK, {'pc': id});
        });
    }

    hasJoined = joined;
    prefab
      ..fromJson(prefabJson ?? {})
      ..character = this;

    applyNameToOnlineIndicator();
  }

  Character.fromJson(
      int id, String color, Session session, Map<String, dynamic> json)
      : this(
          id,
          session,
          color: color,
          name: json['name'],
          joined: json['connected'] ?? false,
          prefabJson: json['prefab'],
        );

  void applyNameToOnlineIndicator() {
    _onlineIndicatorTooltip.text = 'Kick $name';
    _onlineIndicatorName.text = name;
  }
}
