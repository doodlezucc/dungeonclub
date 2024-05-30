import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:prompts/prompts.dart' as prompts;

import 'data.dart';
import 'server.dart';

class Probability {
  String owner;
  double score;

  Probability(this.owner, this.score);
}

final analysisFile = File('../TMP_CONFIDENTIAL/recovery-info.json');

void main() async {
  final mockServer = Server();
  final serverData = mockServer.data;
  await serverData.init();

  final logFile = File('../TMP_CONFIDENTIAL/logs-out.log');
  final logContent = await logFile.readAsString();
  final memoryGap = iterateLogs(logContent, serverData);

  final encoder = JsonEncoder.withIndent('  ');
  await analysisFile.writeAsString(encoder.convert(memoryGap.toJson()));
  exit(0);
}

MemoryGapOperation iterateLogs(String logContent, ServerData serverData) {
  // BEFORE CRASH
  final accountsExistingBeforeCrash =
      serverData.accounts.map((e) => e.encryptedEmail.hash).toSet();
  final gameOwnersBeforeCrash =
      Map.fromEntries(serverData.gameMeta.map((gameMeta) => MapEntry(
            gameMeta.id,
            gameMeta.owner.encryptedEmail.hash,
          )));

  // Group  1: New account activated with <code>
  // Group  2: Log in with <account>
  // Group  3: Game creation with <name>
  // Group  4: Game creation with <id>
  // Group  5: Game <id> joined by GM
  // Group  6: Game <id> deleted
  // Group  7: Websocket connected
  // Group  8: Websocket disconnected
  // Group  9: Game <id> was renamed
  // Group 10: Game was renamed to <name>
  final regex = RegExp(
    r'(?:"code":"(.{5})"}}\n\S+ New account activated!)|(?:Connection logged in with account (\S+))|(?:gameCreateNew.+?(?:"name":"(.*?[^\\]?)".+?)? (\S+) \(\-\))|(?: (\S+) \(-\) joined)|(?:gameDelete.*?"id":"(\S+)")|( New connection)|( Lost connection)|(?:"action":"gameEdit"[^\n]+"id":"(\S+)","data":{"name":"(.*?[^\\]?)")',
    dotAll: true,
  );
  final matches = regex.allMatches(logContent);

  final createdGames = <String>{};
  final deletedOldGames = <String>{};
  final gameNames = <String, String>{};

  final gameOwners = Map.of(gameOwnersBeforeCrash);
  final gameOwnerSuspects = <String, List<Probability>>{};

  final synonymousAccounts = <String, String>{};

  final loginTimes = <String, DateTime>{};
  var activeConnections = 1;
  var loggedInUsersSinceCheckpoint = 0;
  final suspects = <String>{};

  for (var match in matches) {
    final timeString = extractTimestamp(logContent, match);
    final time = DateTime.parse(timeString);

    final newAccountActivationCode = match[1];

    final loggedInAccount = match[2];
    final createdGameName = match[3];
    final createdGameID = match[4];
    final joinedGameID = match[5];
    final deletedGameID = match[6];

    final isWsConnect = match[7] != null;
    final isWsDisconnect = match[8] != null;

    final editedGameID = match[9];
    final editedGameName = match[10];

    void gmEvent(String gameID) {
      if (suspects.length == 1) {
        final guessedOwner = gameOwners[gameID];
        final newOwner = suspects.first;

        if (guessedOwner != null && guessedOwner != newOwner) {
          print(
              '\nColliding game owners on game $gameID, already set to $guessedOwner\n');

          synonymousAccounts[newOwner] = guessedOwner;
        }

        gameOwners[gameID] = newOwner;
      } else {
        final probability = loggedInUsersSinceCheckpoint / suspects.length;

        final gameSuspectList = gameOwnerSuspects.putIfAbsent(gameID, () => []);
        gameSuspectList.addAll(suspects.map((owner) {
          final secondsLoggedIn = time.difference(loginTimes[owner]!).inSeconds;

          final multiplier =
              11 - 10 * (secondsLoggedIn / (60 * 60 * 6)).clamp(0, 1);

          return Probability(owner, multiplier * probability);
        }));
        // throw 'multiple possible gms';
      }

      if (gameOwners.containsKey(gameID)) {
        suspects.remove(gameOwners[gameID]);
      }
    }

    void printLog(String msg) {
      print('$timeString - $msg');
    }

    if (newAccountActivationCode != null) {
      printLog('NEW ACCOUNT REGISTERED, Code: $newAccountActivationCode');
      String emailAddress = prompts.get("Real email address");
      suspects.add(emailAddress);
      loginTimes[emailAddress] = time;

      loggedInUsersSinceCheckpoint =
          min(loggedInUsersSinceCheckpoint + 1, suspects.length);
    } else if (loggedInAccount != null) {
      printLog(loggedInAccount + ' logged in');
      suspects.add(loggedInAccount);
      loginTimes[loggedInAccount] = time;

      loggedInUsersSinceCheckpoint =
          min(loggedInUsersSinceCheckpoint + 1, suspects.length);
    } else if (createdGameID != null) {
      if (createdGameName == null) {
        throw 'no game name on creation';
      }

      print(extractWholeLine(logContent, match));
      printLog('Created game $createdGameID with name $createdGameName');
      createdGames.add(createdGameID);
      gameNames[createdGameID] = createdGameName;
      gmEvent(createdGameID);
    } else if (joinedGameID != null) {
      printLog('Joined game $joinedGameID');
      gmEvent(joinedGameID);
      loggedInUsersSinceCheckpoint--;
      if (loggedInUsersSinceCheckpoint == 0) {
        print('0 accounts could create or join anything right now');
        suspects.clear();
      }
      if (loggedInUsersSinceCheckpoint < 0) {
        throw 'what';
      }
    } else if (deletedGameID != null) {
      printLog('Deleted game $deletedGameID');
      final wasNewlyCreated = createdGames.remove(deletedGameID);

      if (wasNewlyCreated) {
        print('(ignore this one)');
      } else {
        deletedOldGames.add(deletedGameID);
      }
    } else if (isWsConnect) {
      activeConnections++;
    } else if (isWsDisconnect) {
      activeConnections--;

      if (activeConnections == 0) {
        printLog(' > checkpoint <');
        suspects.clear();
      } else if (activeConnections < 0) {
        throw 'somethings fishy';
      }
    } else if (editedGameID != null && editedGameName != null) {
      gameNames[editedGameID] = editedGameName;
    } else {
      final srcString = logContent.substring(match.start, match.end);
      throw 'Unhandled match $srcString';
    }
  }

  // REMOVE PREVIOUSLY KNOWN MAPPINGS

  gameOwners
      .removeWhere((key, value) => gameOwnersBeforeCrash.containsKey(key));
  gameOwnerSuspects
      .removeWhere((key, value) => gameOwnersBeforeCrash.containsKey(key));
  loginTimes
      .removeWhere((key, value) => accountsExistingBeforeCrash.contains(key));

  //

  for (var entry in gameOwnerSuspects.entries.toList()) {
    final gameID = entry.key;
    final probabilities = entry.value;

    final uniqueOwners = probabilities.fold<Set<String>>(
      {},
      (setOfOwners, probability) => setOfOwners..add(probability.owner),
    );

    if (uniqueOwners.length == 1) {
      gameOwnerSuspects.remove(gameID);
      gameOwners[gameID] = uniqueOwners.first;
    }
  }

  for (var uniqueGame in gameOwners.keys) {
    if (gameOwnerSuspects.remove(uniqueGame) != null) {
      print('Cleaned up suspects for $uniqueGame, found a unique owner');
    }
  }

  print('\n${createdGames.length} CREATED GAMES: ' + createdGames.join(', '));

  for (var createdGame in createdGames) {
    if (gameOwners.containsKey(createdGame)) {
      print(' - $createdGame is owned by ${gameOwners[createdGame]}');
    }
  }

  for (var createdGame in createdGames) {
    if (gameOwnerSuspects.containsKey(createdGame)) {
      final weightedSuspects = gameOwnerSuspects[createdGame]!
          .fold<Map<String, Probability>>({}, (map, probability) {
        map.putIfAbsent(
            probability.owner, () => Probability(probability.owner, 0))
          ..score += probability.score;
        return map;
      });

      final sortedSuspects = weightedSuspects.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      print(' - $createdGame is owned by one of the following');
      for (var probability in sortedSuspects) {
        print(
            '    - ${probability.score.toStringAsFixed(2)} : ${probability.owner}');
      }
    }
  }

  print('\n${deletedOldGames.length} DELETED GAMES: ' +
      deletedOldGames.join(', '));

  return MemoryGapOperation(
    deletedGameIDs: deletedOldGames.toList(),
    oldGameRenames: Map.fromEntries(gameNames.keys
        .where((gameID) => !createdGames.contains(gameID))
        .map((gameID) => MapEntry(gameID, gameNames[gameID]))),
    relevantAccounts: loginTimes.keys.toList(),
    synonymousAccounts: synonymousAccounts,
    createdGameIDNames: Map.fromEntries(
        createdGames.map((gameID) => MapEntry(gameID, gameNames[gameID]))),
    singleSuspectOwners: Map.fromEntries(createdGames
        .where((gameID) => gameOwners.containsKey(gameID))
        .map((gameID) => MapEntry(gameID, gameOwners[gameID]!))),
    multipleSuspectOwners: Map.fromEntries(createdGames
        .where((gameID) => gameOwnerSuspects.containsKey(gameID))
        .map((gameID) => MapEntry(
              gameID,
              gameOwnerSuspects[gameID]!
                  .map((probability) => probability.owner)
                  .toSet()
                  .toList(),
            ))),
  );
}

class MemoryGapOperation {
  final List<String> deletedGameIDs;
  final Map<String, String?> oldGameRenames;

  final List<String> relevantAccounts;
  final Map<String, String> synonymousAccounts;
  final Map<String, String?> createdGameIDNames;

  final Map<String, String> singleSuspectOwners;
  final Map<String, List<String>> multipleSuspectOwners;

  MemoryGapOperation({
    required this.deletedGameIDs,
    required this.oldGameRenames,
    required this.relevantAccounts,
    required this.synonymousAccounts,
    required this.createdGameIDNames,
    required this.singleSuspectOwners,
    required this.multipleSuspectOwners,
  });
  MemoryGapOperation.fromJson(json)
      : this(
          deletedGameIDs: List.from(json['deletedGameIDs']),
          oldGameRenames: Map.from(json['oldGameRenames']),
          relevantAccounts: List.from(json['relevantAccounts']),
          synonymousAccounts: Map.from(json['synonymousAccounts']),
          createdGameIDNames: Map.from(json['createdGameIDNames']),
          singleSuspectOwners: Map.from(json['singleSuspectOwners']),
          multipleSuspectOwners: (json['multipleSuspectOwners'] as Map)
              .map((key, value) => MapEntry(key, List<String>.from(value))),
        );

  toJson() => {
        'deletedGameIDs': deletedGameIDs,
        'oldGameRenames': oldGameRenames,
        'relevantAccounts': relevantAccounts,
        'synonymousAccounts': synonymousAccounts,
        'createdGameIDNames': createdGameIDNames,
        'singleSuspectOwners': singleSuspectOwners,
        'multipleSuspectOwners': multipleSuspectOwners,
      };
}

String extractWholeLine(String logContent, RegExpMatch match) {
  return logContent.substring(logContent.lastIndexOf("\n", match.start) + 1,
      logContent.indexOf("\n", match.end));
}

String extractTimestamp(String logContent, RegExpMatch match) {
  final lineStart = logContent.lastIndexOf("\n", match.start) + 1;
  return logContent.substring(lineStart, lineStart + 19);
}
