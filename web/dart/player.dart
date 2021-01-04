import 'dart:convert';

import 'communication.dart';
import 'server_actions.dart';

class Player {
  String _name;
  String get name => _name;
  String _displayName;
  String get displayName => _displayName;

  Player(String name, String displayName)
      : _name = name,
        _displayName = displayName;

  static Future<Player> create(String name, String password) async {
    var response = await request(PLAYER_CREATE, params: {
      'name': name,
      'password': password,
    });
    if (response) {
      return Player(name, name);
    }
    return null;
  }

  static Future<Player> get(String name) async {
    print('get');
    var response = await request(PLAYER_GET, params: {'name': name});
    print('RESPONSE');
    print(response);
    if (response != null) {
      return Player(name, response['displayName']);
    }
    return null;
  }

  Future<bool> changeDisplayName(String s, String password) async {
    if (s == displayName) {
      return false;
    }
    await request(PLAYER_CHANGE_DISPLAY_NAME, params: {
      'name': name,
      'password': password,
      'displayName': s,
    });
    _displayName = s;
  }
}
