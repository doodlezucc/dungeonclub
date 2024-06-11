import 'dart:convert';
import 'dart:io';

import 'package:crypt/crypt.dart';
import 'package:dungeonclub/iterable_extension.dart';

import 'data.dart';
import 'restore_orphan_campaigns.dart';
import 'server.dart';

void main(List<String> args) async {
  final operationJson = await analysisFile.readAsString();
  final memoryGap = MemoryGapOperation.fromJson(jsonDecode(operationJson));

  final recreatedAccountHashes = Map<String, String>.from(jsonDecode(
    await File('../TMP_CONFIDENTIAL/recreated-account-hashes.json')
        .readAsString(),
  ));

  final server = Server();
  final serverData = server.data;
  await serverData.init();

  final restorer = Restorer(memoryGap, recreatedAccountHashes, serverData);
  final result = await restorer.run();

  await File('../TMP_CONFIDENTIAL/restorer-effects.json')
      .writeAsString(jsonEncode(result.toJson()));

  await serverData.save();
  exit(0);
}

class Restorer {
  final MemoryGapOperation memoryGap;
  final Map<String, String> recreatedAccountCrypts;
  final ServerData serverData;

  late RestorerResult _result;
  late final _placeholderAccount = PlaceholderAccount(serverData);

  Restorer(this.memoryGap, this.recreatedAccountCrypts, this.serverData);

  Future<RestorerResult> run() async {
    _result = RestorerResult();
    await unlinkDeletedOldGames();
    await applyRenamesToExistentGames();

    await createLostGameMetas();
    return _result;
  }

  Future<void> unlinkDeletedOldGames() async {
    for (var gameID in memoryGap.deletedGameIDs) {
      final game = serverData.gameMeta.find((e) => e.id == gameID);
      if (game != null) {
        _result.push(game.owner,
            StaleGameUnlinkEffect(gameID: game.id, gameName: game.name));

        print('Deleting $gameID');
        await game.delete();
      } else {
        print('Unable to delete $gameID');
      }
    }
  }

  Future<void> applyRenamesToExistentGames() async {
    for (var entry in memoryGap.oldGameRenames.entries) {
      final gameID = entry.key;
      final newName = entry.value;

      if (newName == null) continue;

      final game = serverData.gameMeta.find((e) => e.id == gameID);
      if (game != null) {
        print('Renaming $gameID from "${game.name}" to "$newName"');
        _result.push(
          game.owner,
          GameRenameEffect(gameID: gameID, gameName: newName),
        );
        game.name = newName;
      } else {
        print('Unable to rename $gameID');
      }
    }
  }

  Account? _findAccountFromHash(String emailHash) {
    return serverData.accounts
        .find((account) => account.encryptedEmail.hash == emailHash);
  }

  Account? _findRecreatedHashOfEmail(String email) {
    final encrypted = recreatedAccountCrypts[email];

    if (encrypted != null) {
      return _findAccountFromHash(Crypt(encrypted).hash);
    } else {
      return null;
    }
  }

  Future<void> createLostGameMetas() async {
    for (var entry in memoryGap.createdGameIDNames.entries) {
      final gameID = entry.key;
      final gameName = entry.value;

      if (gameName != null) {
        print('Creating orphan campaign $gameID with name "$gameName"');

        final ownerHashOrEmail = memoryGap.singleSuspectOwners[gameID];
        Account owner;

        if (ownerHashOrEmail != null) {
          final accountInDatabase = ownerHashOrEmail.contains('@')
              ? _findRecreatedHashOfEmail(ownerHashOrEmail)
              : _findAccountFromHash(ownerHashOrEmail);

          final gameRestoredEffect = GameRestoredEffect(
            gameID: gameID,
            gameName: gameName,
          );

          if (accountInDatabase != null) {
            owner = accountInDatabase;
            print('Relinking game with existing account');

            _result.push(owner, gameRestoredEffect);
          } else {
            owner = _placeholderAccount;
            print('Game belongs to account which has been lost'
                ' (user must recreate their account)');

            _result.pushLimboGame(ownerHashOrEmail, gameRestoredEffect);
          }
        } else {
          owner = _placeholderAccount;
        }

        final meta = OrphanGameMeta(serverData, owner, gameID);
        meta.name = gameName;

        serverData.gameMeta.add(meta);
      } else {
        print('Unable to create orphan campaign $gameID (no name given)');
      }
    }
  }
}

mixin RestorerEffect {
  Map<String, dynamic> toJson() => {
        'type': runtimeType.toString(),
      };
}

class GameEffect with RestorerEffect {
  final String gameID;
  final String gameName;

  GameEffect({required this.gameID, required this.gameName});

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'gameID': gameID,
        'gameName': gameName,
      };
}

class StaleGameUnlinkEffect extends GameEffect {
  StaleGameUnlinkEffect({required super.gameID, required super.gameName});
}

class GameRenameEffect extends GameEffect {
  GameRenameEffect({required super.gameID, required super.gameName});
}

class GameRestoredEffect extends GameEffect {
  GameRestoredEffect({required super.gameID, required super.gameName});
}

class RestorerResult {
  final Map<Account, List<RestorerEffect>> affectedAccounts = {};
  final Map<String, List<GameRestoredEffect>> lostEmailsWithRestoredGames = {};

  void push(Account acc, RestorerEffect effect) {
    final effects = affectedAccounts.putIfAbsent(acc, () => []);
    effects.add(effect);
  }

  void pushLimboGame(String ownerEmail, GameRestoredEffect effect) {
    final games = lostEmailsWithRestoredGames.putIfAbsent(ownerEmail, () => []);
    games.add(effect);
  }

  Map<String, dynamic> toJson() => {
        'affectedAccounts': affectedAccounts.map(
            (key, value) => MapEntry(key.encryptedEmail.toString(), value)),
        'lostEmailsWithRestoredGames': lostEmailsWithRestoredGames,
      };
}

class PlaceholderCrypt implements Crypt {
  static const HASH = 'PLACEHOLDER';

  @override
  String get hash => HASH;

  @override
  String toString() => HASH;

  @override
  bool match(String value) {
    return value == HASH;
  }

  @override
  int? get rounds => throw UnimplementedError();

  @override
  String get salt => throw UnimplementedError();

  @override
  String get type => throw UnimplementedError();
}

class OrphanGameMeta extends GameMeta {
  final String _id;

  @override
  String get id => _id;

  OrphanGameMeta(super.data, super.owner, this._id) : super.create();
}

class PlaceholderAccount extends Account {
  PlaceholderAccount(ServerData data)
      : super(data, 'INVALID_EMAIL', 'INVALID_PASSWORD');

  @override
  final Crypt encryptedEmail = PlaceholderCrypt();

  @override
  Crypt encryptedPassword = PlaceholderCrypt();

  @override
  Future<void> delete() {
    throw UnimplementedError();
  }

  @override
  void setPassword(String password) {
    throw UnimplementedError();
  }
}
