import 'communication.dart';
import 'server_actions.dart';

class Player {
  final String _name;
  String get name => _name;
  String _displayName;
  String get displayName => _displayName;

  Player(String name, String displayName)
      : _name = name,
        _displayName = displayName;

  static Future<LocalPlayer> create(String name, String password) async {
    var response = await request(PLAYER_CREATE, params: {
      'name': name,
      'password': password,
    });
    if (response != false) {
      return LocalPlayer._(name, response);
    }
    return null;
  }

  static Future<Player> get(String name) async {
    print('GET');
    var response = await request(PLAYER_GET, params: {'name': name});
    if (response != null) {
      return Player(name, response['displayName']);
    }
    return null;
  }
}

class LocalPlayer extends Player {
  LocalPlayer._(String name, Map<String, dynamic> json)
      : super(name, json['displayName']);

  static Future<LocalPlayer> login(String name, String password) async {
    var response = await request(PLAYER_GET, params: {
      'name': name,
      'password': password,
    });
    if (response != null) {
      return LocalPlayer._(name, response);
    }
    return null;
  }

  Future<bool> changeDisplayName(String s, String password) async {
    if (s == displayName) {
      return false;
    }
    var response = await request(PLAYER_CHANGE_DISPLAY_NAME, params: {
      'name': name,
      'password': password,
      'displayName': s,
    });
    if (response) _displayName = s;
    return response;
  }
}
