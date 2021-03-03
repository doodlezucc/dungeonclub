import 'dart:async';
import 'dart:convert';

import 'dart:io';
import 'dart:math';

import 'package:crypt/crypt.dart';
import 'package:dnd_interactive/actions.dart' as a;
import 'package:path/path.dart' as path;
import 'package:random_string/random_string.dart';

import 'connections.dart';
import 'server.dart';

class ServerData {
  static final _manualSaveWatch = Stopwatch();
  static final directory = Directory('database');
  static final file = File(path.join(directory.path, 'data.json'));

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
    return accounts.firstWhere(
        (p) => alreadyEncrypted
            ? p.encryptedEmail.toString() == email
            : p.encryptedEmail.match(email),
        orElse: () => null);
  }

  Map<String, dynamic> toJson() => {
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'games': games.map((e) => e.toJson()).toList(),
      };

  void fromJson(Map<String, dynamic> json) {
    var owners = <Game, String>{};

    games.clear();
    games.addAll(List.from(json['games']).map((j) {
      var game = Game.fromJson(j);
      owners[game] = j['owner'];
      return game;
    }));
    print('Loaded ${games.length} games');

    accounts.clear();
    accounts
        .addAll(List.from(json['accounts']).map((j) => Account.fromJson(j)));
    print('Loaded ${accounts.length} accounts');

    owners.forEach((game, ownerEmail) {
      game.owner = data.getAccount(ownerEmail, alreadyEncrypted: true);
    });
    print('Set all game owners');
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
  Iterable<Game> get ownedGames => enteredGames.where((g) => g.owner == this);

  Account(String email, String password)
      : encryptedEmail = Crypt.sha256(email),
        encryptedPassword = Crypt.sha256(password);

  bool ownsGame(String gameId) {
    return enteredGames.any((g) => g.id == gameId && g.owner == this);
  }

  Account.fromJson(Map<String, dynamic> json)
      : encryptedEmail = Crypt(json['email']),
        encryptedPassword = Crypt(json['password']),
        enteredGames = List.from(json['games'])
            .map((id) => data.games.singleWhere((g) => g.id == id))
            .toList();

  Map<String, dynamic> toJson() => {
        'email': encryptedEmail.toString(),
        'password': encryptedPassword.toString(),
        'games': enteredGames.map((g) => g.id).toList(),
      };

  Map<String, dynamic> toSnippet() => {
        'games': enteredGames.map((g) => g.toSnippet()).toList(),
      };
}

class Game {
  final String id;
  Directory get resources =>
      Directory(path.join(ServerData.directory.path, 'games', id));
  String name;
  Account owner;

  Connection get gm =>
      _connections.firstWhere((c) => owner == c.account, orElse: () => null);
  bool get gmOnline => gm != null;
  int get online => _connections.length;

  final _connections = <Connection>[];
  final List<PlayerCharacter> _characters;
  final Board board;

  static String _generateId() {
    String id;
    do {
      id = randomAlphaNumeric(10);
    } while (data.games.any((g) => g.id == id));
    return id;
  }

  void notify(String action, Map<String, dynamic> params,
      {Connection exclude}) {
    for (var c in _connections) {
      if (exclude != c) {
        c.sendAction(action, params);
      }
    }
  }

  Future<File> getFile(String filePath) async {
    if (!await resources.exists()) {
      await resources.create(recursive: true);
    }
    return File(path.join(resources.path, filePath));
  }

  Game(this.owner, this.name)
      : id = _generateId(),
        board = Board(),
        _characters = [];

  void connect(Connection connection, bool join) {
    notify(a.GAME_CONNECTION, {
      'join': join,
      'pc': _characters.indexWhere((e) => e.connection == connection),
    });
    if (!join) {
      _connections.remove(connection);
      return;
    }
    _connections.add(connection);
  }

  void addPC(String name) {
    _characters.add(PlayerCharacter(name));
  }

  void removePC(int index) {
    _characters.removeAt(index);
  }

  PlayerCharacter assignPC(int index, Connection c) {
    return _characters[index]..connection = c;
  }

  Game.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        board = Board(json['board']),
        _characters = List.from(json['pcs'])
            .map((e) => PlayerCharacter(e['name']))
            .toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': owner.encryptedEmail.toString(),
        'board': board.toJson(),
        'pcs': _characters.map((e) => e.toJson()).toList()
      };

  Map<String, dynamic> toSnippet() => {
        'id': id,
        'name': name,
      };

  Map<String, dynamic> toSessionSnippet(Connection c, [int mine]) {
    return {
      'board': board.toJson(),
      'pcs': _characters.map((e) => e.toJson()).toList(),
      if (mine != null) 'mine': mine,
      if (owner == c.account) 'gm': {},
    };
  }

  bool applyChanges(Map<String, dynamic> data) {
    _characters.clear();
    name = data['name'];
    var pcs = List.from(data['pcs']);
    if (pcs.length >= 20) return false;
    _characters.addAll(pcs.map((e) => PlayerCharacter.fromJson(e)));
    return true;
  }
}

class PlayerCharacter {
  Connection connection;
  String name;

  PlayerCharacter(this.name);
  PlayerCharacter.fromJson(Map<String, dynamic> json) : name = json['name'];

  Map<String, dynamic> toJson() => {
        'name': name,
      };
}

class Board {
  final List<Movable> _movables;
  int _countMIDs = 0;

  Board([Map<String, dynamic> json])
      : _movables = json != null
            ? List.from(json['movables'])
                .map((j) => Movable(j['id'], j))
                .toList()
            : <Movable>[] {
    _countMIDs = _movables.fold(-1, (v, m) => max<int>(v, m.id)) + 1;
  }

  Movable addMovable(Map<String, dynamic> json) {
    var m = Movable(_countMIDs++, json);
    _movables.add(m);
    return m;
  }

  Movable getMovable(int id) {
    return _movables.singleWhere((m) => m.id == id, orElse: () => null);
  }

  Map<String, dynamic> toJson() => {
        'movables': _movables.map((e) => e.toJson()).toList(),
      };
}

class Movable {
  final int id;

  String img;
  num x;
  num y;

  Movable(this.id, Map<String, dynamic> json)
      : img = json['img'],
        x = json['x'],
        y = json['y'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'img': img,
        'x': x,
        'y': y,
      };
}
