import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:crypt/crypt.dart';

class ServerData {
  static final _manualSaveWatch = Stopwatch();

  final accounts = <Account>[];
  final games = <Game>[];

  ServerData() {
    _manualSaveWatch.start();
    //initAutoSave();
  }

  void initAutoSave() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      save();
    });
  }

  Account getAccount(String email) {
    if (email == null) return null;
    return accounts.singleWhere((p) => p.encryptedEmail.match(email),
        orElse: () => null);
  }

  Map<String, dynamic> toJson() => {
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'games': games.map((e) => e.toJson()).toList(),
      };

  Future<void> save() async {
    var json = JsonEncoder.withIndent(' ').convert(toJson());
    print(json);
    await File('database/data.json').writeAsString(json);
    print('Saved!');
  }

  Future<void> manualSave() async {
    if (_manualSaveWatch.elapsedMilliseconds > 1000) {
      await save();
    } else {
      print('Manual saving has a cooldown.');
    }
    _manualSaveWatch.reset();
  }
}

class Account {
  final Crypt encryptedEmail;
  Crypt encryptedPassword;

  var enteredGames = <Game>[];

  Account(String email, String password)
      : encryptedEmail = Crypt.sha256(email),
        encryptedPassword = Crypt.sha256(password);

  Map<String, dynamic> toJson() => {
        'email': encryptedEmail.hash,
        'password': encryptedPassword.hash,
        'games': enteredGames.map((g) => g.id).toList(),
      };

  Map<String, dynamic> toSnippet() => {
        'email': encryptedEmail.hash,
        'games': enteredGames.map((g) => g.toJson()).toList(),
      };
}

class Game {
  final int id;
  String name;
  Account owner;

  Game(this.id, Account owner);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': owner.encryptedEmail.hash,
      };
}
