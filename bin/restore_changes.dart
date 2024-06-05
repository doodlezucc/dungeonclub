import 'dart:convert';

import 'package:crypt/crypt.dart';
import 'package:dungeonclub/iterable_extension.dart';

import 'data.dart';
import 'restore_orphan_campaigns.dart';
import 'server.dart';

void main(List<String> args) async {
  final operationJson = await analysisFile.readAsString();
  final memoryGap = MemoryGapOperation.fromJson(jsonDecode(operationJson));

  final server = Server();
  final serverData = server.data;
  await serverData.init();

  final restorer = Restorer(memoryGap, serverData);
  await restorer.run();

  await server.shutdown();
}

class Restorer {
  final MemoryGapOperation memoryGap;
  final ServerData serverData;

  late final _placeholderAccount = PlaceholderAccount(serverData);

  Restorer(this.memoryGap, this.serverData);

  Future<void> run() async {
    // await unlinkDeletedOldGames();
    // await applyRenamesToExistentGames();

    await createLostGameMetas();
  }

  Future<void> unlinkDeletedOldGames() async {
    for (var gameID in memoryGap.deletedGameIDs) {
      final game = serverData.gameMeta.find((e) => e.id == gameID);
      if (game != null) {
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

  Future<void> createLostGameMetas() async {
    for (var entry in memoryGap.createdGameIDNames.entries) {
      final gameID = entry.key;
      final gameName = entry.value;

      if (gameName != null) {
        print('Creating orphan campaign $gameID with name "$gameName"');

        final ownerHash = memoryGap.singleSuspectOwners[gameID];
        Account owner;

        if (ownerHash != null) {
          final accountInDatabase = _findAccountFromHash(ownerHash);

          if (accountInDatabase != null) {
            owner = accountInDatabase;
            print('Relinking game with existing account');
          } else {
            owner = _placeholderAccount;
            print('Game belongs to account which has been lost'
                ' (user must recreate their account)');
          }
        } else {
          owner = _placeholderAccount;
        }

        serverData.gameMeta.add(GameMeta.create(serverData, owner));
      } else {
        print('Unable to create orphan campaign $gameID (no name given)');
      }
    }
  }
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
