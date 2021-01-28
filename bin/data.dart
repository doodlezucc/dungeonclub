import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:crypt/crypt.dart';

import 'server.dart';

class ServerData {
  static final _manualSaveWatch = Stopwatch();
  static final file = File('database/data.json');

  final accounts = <Account>[];
  final games = <Game>[];

  void init() {
    load().then((_) {
      _manualSaveWatch.start();
      //initAutoSave();
    });
  }

  void initAutoSave() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      save();
    });
  }

  Account getAccount(String email, {bool alreadyEncrypted = false}) {
    if (email == null) return null;
    return accounts.singleWhere(
        (p) => alreadyEncrypted
            ? p.encryptedEmail.hash == email
            : p.encryptedEmail.match(email),
        orElse: () => null);
  }

  Map<String, dynamic> toJson() => {
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'games': games.map((e) => e.toJson()).toList(),
      };

  void fromJson(Map<String, dynamic> json) {
    accounts.clear();
    accounts
        .addAll(List.from(json['accounts']).map((j) => Account.fromJson(j)));
    print('Loaded ${accounts.length} accounts!');

    games.clear();
    games.addAll(List.from(json['games']).map((j) => Game.fromJson(j)));
    print('Loaded ${games.length} games!');
  }

  Future<void> save() async {
    var json = JsonEncoder.withIndent(' ').convert(toJson());
    print(json);
    await file.writeAsString(json);
    print('Saved!');
  }

  Future<void> load() async {
    if (!await file.exists()) return;

    var s = await file.readAsString();
    var json = jsonDecode(s);
    fromJson(json);
    print('Loaded!');
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

  Account.fromJson(Map<String, dynamic> json)
      : encryptedEmail = Crypt(json['email']),
        encryptedPassword = Crypt(json['password']);

  Map<String, dynamic> toJson() => {
        'email': encryptedEmail.toString(),
        'password': encryptedPassword.toString(),
        'games': enteredGames.map((g) => g.id).toList(),
      };

  Map<String, dynamic> toSnippet() => {
        'email': encryptedEmail.toString(),
        'games': enteredGames.map((g) => g.toJson()).toList(),
      };
}

class Game {
  final int id;
  String name;
  Account owner;

  Game(this.id, Account owner);

  Game.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        owner = data.getAccount(json['email']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': owner.encryptedEmail.toString(),
      };
}
