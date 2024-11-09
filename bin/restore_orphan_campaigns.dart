import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'data.dart';
import 'server.dart';

final analysisFile = File('../TMP_CONFIDENTIAL/recovery-info.json');

class SuspiciousLogIn {
  final int secondBeforeOpeningGame;

  /// Value from 0 to 1 indicating how likely it is that THIS user is responsible for opening the game
  final double probability;

  SuspiciousLogIn({
    required this.secondBeforeOpeningGame,
    required this.probability,
  });
}

void main() async {
  final mockServer = Server();
  final serverData = mockServer.data;
  await serverData.init();

  final logFile = File('../TMP_CONFIDENTIAL/logs-out.log');
  final logContent = await logFile.readAsString();

  final emailsInOrder =
      await File('../TMP_CONFIDENTIAL/email-account-creation-order.txt')
          .readAsLines();

  final Map initialConnectionsJson = jsonDecode(
      await File('../TMP_CONFIDENTIAL/initial-connections.json')
          .readAsString());

  final initialConnections = initialConnectionsJson
      .map((key, value) => MapEntry('$key', Set<String>.from(value)));

  final humanResolvedOwners = Map<String, String>.from(jsonDecode(
      await File('../TMP_CONFIDENTIAL/resolved-game-owners.json')
          .readAsString()));

  final humanResolvedHashes = Map<String, String>.from(jsonDecode(
      await File('../TMP_CONFIDENTIAL/resolved-hash-map.json').readAsString()));

  final memoryGap = await simulateLogsWithServerData(
    logContent,
    emailsInOrder,
    initialConnections,
    humanResolvedOwners,
    humanResolvedHashes,
    serverData,
  );

  final encoder = JsonEncoder.withIndent('  ');
  await analysisFile.writeAsString(encoder.convert(memoryGap.toJson()));
  exit(0);
}

Future<MemoryGapOperation> simulateLogsWithServerData(
  String logContent,
  List<String> registeredEmailsDuringGap,
  Map<String, Set<String>> initialConnectedGamePCs,
  Map<String, String> humanResolvedOwners,
  Map<String, String> humanResolvedHashes,
  ServerData serverData,
) async {
  final gameOwnersBeforeCrash =
      Map.fromEntries(serverData.gameMeta.map((gameMeta) => MapEntry(
            gameMeta.id,
            gameMeta.owner.encryptedEmail.hash,
          )));

  final accountHashes =
      serverData.accounts.map((acc) => acc.encryptedEmail.hash).toSet();

  return await simulateLogsWithRecursiveKnowledge(
    logContent,
    registeredEmailsDuringGap,
    initialConnectedGamePCs,
    humanResolvedOwners,
    humanResolvedHashes,
    gameOwnersBeforeCrash,
    accountHashes,
  );
}

Future<MemoryGapOperation> simulateLogsWithRecursiveKnowledge(
  String logContent,
  List<String> registeredEmailsDuringGap,
  Map<String, Set<String>> initialConnectedGamePCs,
  Map<String, String> humanResolvedOwners,
  Map<String, String> humanResolvedHashes,
  Map<String, String> gameOwnersBeforeCrash,
  Set<String> accountHashesBeforeCrash,
) async {
  MemoryGapOperation previousResult = simulateLogs(
    logContent,
    registeredEmailsDuringGap: registeredEmailsDuringGap,
    initialConnectedGamePCs: initialConnectedGamePCs,
    humanResolvedOwners: humanResolvedOwners,
    humanResolvedHashes: humanResolvedHashes,
    gameOwnersBeforeCrash: gameOwnersBeforeCrash,
    accountHashesBeforeCrash: accountHashesBeforeCrash,
  );

  String previousResultJson = jsonEncode(previousResult.toJson());

  int iterationsLeft = 1000;

  while (iterationsLeft > 0) {
    final result = simulateLogs(
      logContent,
      registeredEmailsDuringGap: registeredEmailsDuringGap,
      initialConnectedGamePCs: initialConnectedGamePCs,
      humanResolvedOwners: humanResolvedOwners,
      humanResolvedHashes: humanResolvedHashes,
      gameOwnersBeforeCrash: gameOwnersBeforeCrash,
      accountHashesBeforeCrash: accountHashesBeforeCrash,
      lastIteration: previousResult,
    );

    iterationsLeft--;

    final differenceUnknown =
        previousResult.countUnknown() - result.countUnknown();
    final differenceKnown = result.countKnown() - previousResult.countKnown();

    print(
        '\n\Took out ${differenceUnknown} suspects with recursion, got ${differenceKnown} known owners');

    String resultJson = jsonEncode(result.toJson());

    if (resultJson != previousResultJson) {
      print('Computed different results -> Run next iteration');
      iterationsLeft = 2;
    }

    await Future.delayed(Duration(seconds: 3));

    previousResult = result;
    previousResultJson = resultJson;
  }

  return previousResult;
}

MemoryGapOperation simulateLogs(
  String logContent, {
  required List<String> registeredEmailsDuringGap,
  required Map<String, Set<String>> initialConnectedGamePCs,
  required Map<String, String> humanResolvedOwners,
  required Map<String, String> humanResolvedHashes,
  Map<String, String> gameOwnersBeforeCrash = const {},
  Set<String> accountHashesBeforeCrash = const {},
  MemoryGapOperation? lastIteration,
}) {
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

  // Group 11: Game left or joined by <pc>
  // Group 12: Game <id> left or joined
  // Group 13: Some game left by any or joined by non-GM
  final regex = RegExp(
    r'(?:"code":"(.{5})"}}[^{]+? New account activated!)|(?:Connection logged in with account (\S+))|(?:gameCreateNew.+?(?:"name":"(.*?[^\\]?)".+?)? (\S+) \(\-\))|(?: (\S+) \(-\) joined)|(?:gameDelete.*?"id":"(\S+)")|( New connection)|( Lost connection)|(?:"action":"gameEdit"[^\n]+"id":"(\S+)","data":{"name":"(.*?[^\\]?)")|(?: (\S+) \((\S)\) (joined|left))',
    dotAll: true,
  );
  final matches = regex.allMatches(logContent);

  final createdGames = <String>{};
  final deletedOldGames = <String>{};
  final gameNames = <String, String>{};

  final gameOwners = {
    ...lastIteration?.singleSuspectOwners ?? {},
    ...humanResolvedOwners,
    ...gameOwnersBeforeCrash,
  };
  final gameOwnerProbabilites = <String, Map<String, List<SuspiciousLogIn>>>{};

  final hashToEmailMap = {
    ...lastIteration?.synonymousAccounts ?? {},
    ...humanResolvedHashes,
  };
  int registrationCounter = 0;
  final hashToEmailSuspects = <String, Map<String, DateTime>>{};

  String resolveSynonym(String key) {
    return hashToEmailMap[key] ?? '$key';
  }

  Set<String> getUnresolvedEmailsUntilThisPoint() {
    return registeredEmailsDuringGap
        .take(registrationCounter)
        .where((email) => !hashToEmailMap.containsValue(email))
        .toSet();
  }

  final gameConnectedPCs = <String, Set<String>>{
    ...initialConnectedGamePCs
        .map((key, value) => MapEntry(key, Set.of(value))),
  };
  int connectionsInGames() =>
      gameConnectedPCs.values.fold<int>(0, (sum, game) => sum + game.length);

  final registrationDates = <String, TimeRange>{};
  final loginTimes = <String, DateTime>{};
  var activeConnections = 11;
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

    final gameJoinOrLeaveID = match[11];
    final gameJoinOrLeavePC = match[12];
    final gameJoinOrLeave = match[13];

    void joinLeaveEvent(bool add, String gameID, String pc) {
      final pcs = gameConnectedPCs.putIfAbsent(gameID, () => {});

      if (add) {
        if (!pcs.add(pc)) {
          print('already added');
        }
      } else {
        if (!pcs.remove(pc)) {
          print('already removed');
        }
      }
    }

    void gmEvent(String gameID) {
      if (suspects.length == 1) {
        final guessedOwner = gameOwners[gameID];
        final newOwner = suspects.first;

        if (guessedOwner != null &&
            guessedOwner != newOwner &&
            !newOwner.contains('@')) {
          print(
              '\nColliding game owners on game $gameID, already set to $guessedOwner\n');

          hashToEmailMap[newOwner] = guessedOwner;
          suspects.remove(newOwner);
        } else {
          gameOwners[gameID] = newOwner;
        }
      } else if (!gameOwners.containsKey(gameID)) {
        final probability = 1 / suspects.length;

        final gameSuspectMap =
            gameOwnerProbabilites.putIfAbsent(gameID, () => {});
        gameSuspectMap.removeWhere((key, value) =>
            accountHashesBeforeCrash.contains(key) && !suspects.contains(key));

        for (var suspect in suspects) {
          final secondsLoggedIn =
              time.difference(loginTimes[suspect]!).inSeconds;

          final gameSuspectDurationsUntilGameAction =
              gameSuspectMap.putIfAbsent(suspect, () => []);

          gameSuspectDurationsUntilGameAction.add(SuspiciousLogIn(
            secondBeforeOpeningGame: secondsLoggedIn,
            probability: probability,
          ));
        }
      }

      if (gameOwners.containsKey(gameID)) {
        suspects.remove(gameOwners[gameID]);
      }
    }

    void printLog(String msg) {
      print('$timeString - $msg');
    }

    if (newAccountActivationCode != null) {
      String emailAddress = registeredEmailsDuringGap[registrationCounter];
      registrationCounter++;

      printLog(
          'NEW ACCOUNT REGISTERED, Code: $newAccountActivationCode -> $emailAddress');

      suspects.add(emailAddress);
      registrationDates[emailAddress] = TimeRange(time);
      loginTimes[emailAddress] = time;
    } else if (loggedInAccount != null) {
      final loggedInEmailOrAccountHash = resolveSynonym(loggedInAccount);
      printLog(loggedInEmailOrAccountHash + ' logged in');
      suspects.add(loggedInEmailOrAccountHash);

      if (!accountHashesBeforeCrash.contains(loggedInAccount)) {
        // This might be a lost account
        if (!hashToEmailMap.containsKey(loggedInAccount)) {
          final unresolvedHashes = suspects
              .where((susHash) =>
                  !accountHashesBeforeCrash.contains(susHash) &&
                  !susHash.contains('@'))
              .toSet();

          final unresolvedEmails = getUnresolvedEmailsUntilThisPoint();

          if (unresolvedHashes.length == 1 && unresolvedEmails.length == 1) {
            hashToEmailMap[loggedInAccount] = unresolvedEmails.first;
          } else if (!loginTimes.containsKey(loggedInAccount)) {
            // FIRST LOGIN OF THIS ACCOUNT
            final emailLastSeenMap =
                hashToEmailSuspects.putIfAbsent(loggedInAccount, () => {});

            for (var email in unresolvedEmails) {
              emailLastSeenMap[email] = time;
            }
          }
        }
      }

      loginTimes[loggedInEmailOrAccountHash] = time;
    } else if (createdGameID != null) {
      if (createdGameName == null) {
        throw 'no game name on creation';
      }

      joinLeaveEvent(true, createdGameID, '-');
      print(extractWholeLine(logContent, match));
      printLog('Created game $createdGameID with name $createdGameName');
      createdGames.add(createdGameID);
      gameNames[createdGameID] = createdGameName;
      gmEvent(createdGameID);
    } else if (joinedGameID != null) {
      printLog('Joined game $joinedGameID');
      gmEvent(joinedGameID);
      joinLeaveEvent(true, joinedGameID, '-');
    } else if (deletedGameID != null) {
      printLog('Deleted game $deletedGameID');
      final wasNewlyCreated = createdGames.remove(deletedGameID);

      if (wasNewlyCreated) {
        gameOwners.remove(deletedGameID);
        gameOwnerProbabilites.remove(deletedGameID);
        gameNames.remove(deletedGameID);
        print('(ignore this one)');
      } else {
        deletedOldGames.add(deletedGameID);
      }
    } else if (isWsConnect) {
      activeConnections++;
    } else if (isWsDisconnect) {
      activeConnections--;
    } else if (gameJoinOrLeave != null) {
      if (gameJoinOrLeave == 'joined') {
        joinLeaveEvent(true, gameJoinOrLeaveID!, gameJoinOrLeavePC!);
      } else {
        joinLeaveEvent(false, gameJoinOrLeaveID!, gameJoinOrLeavePC!);
      }
    } else if (editedGameID != null && editedGameName != null) {
      gameNames[editedGameID] = editedGameName;
    } else {
      final srcString = logContent.substring(match.start, match.end);
      throw 'Unhandled match $srcString';
    }

    final connectionsWhichCouldDoSomething =
        activeConnections - connectionsInGames();

    if (connectionsWhichCouldDoSomething < -1) {
      throw 'huh';
    }

    if (connectionsWhichCouldDoSomething == 0) {
      printLog(' > checkpoint <');
      suspects.clear();

      for (var registrationTimeRange in registrationDates.values) {
        registrationTimeRange.maximum ??= time;
      }
    }
  }

  // REMOVE PREVIOUSLY KNOWN MAPPINGS

  gameOwners
      .removeWhere((key, value) => gameOwnersBeforeCrash.containsKey(key));
  gameOwnerProbabilites
      .removeWhere((key, value) => gameOwnersBeforeCrash.containsKey(key));

  //

  Map<String, Set<String>> getGameOwnerSuspects() => gameOwnerProbabilites
      .map((key, value) => MapEntry(key, value.keys.toSet()));

  final emailSynonyms = findEmailSynonyms(
    getGameOwnerSuspects().values.toSet(),
    registeredEmailsDuringGap.toSet(),
  );

  // Not interested in accounts which don't have a single game
  final emailToSingleHash = Map.fromEntries(emailSynonyms.entries
      .where((entry) => entry.value.length == 1)
      .map((e) => MapEntry(e.key, e.value.first))
      .where((entry) {
    final accountHash = entry.value;

    // only keep hashes (not raw emails) which have not existed before the gap
    return !accountHash.contains('@') &&
        !accountHashesBeforeCrash.contains(accountHash);
  }));

  for (var emailToHashEntry in emailToSingleHash.entries) {
    final email = emailToHashEntry.key;
    final hash = emailToHashEntry.value;

    if (hashToEmailMap.containsKey(hash)) {
      throw 'what do in duplicate situation';
    } else {
      hashToEmailMap[hash] = email;
    }
  }

  final interestingSuspects = <String, Map<String, List<SuspiciousLogIn>>>{};

  // Hash is not associated with any game and can be safely discarded
  hashToEmailSuspects.removeWhere((hash, _) => !gameOwners.containsValue(hash));

  // Remove 1-to-1 findings
  hashToEmailSuspects
      .removeWhere((hash, _) => hashToEmailMap.containsKey(hash));
  hashToEmailSuspects.values.forEach((possibleEmails) =>
      possibleEmails.removeWhere(
          (possibleEmail, _) => hashToEmailMap.containsValue(possibleEmail)));

  for (var entry in gameOwners.entries.toList()) {
    if (hashToEmailMap.containsKey(entry.value)) {
      gameOwners[entry.key] = hashToEmailMap[entry.value]!;
    }
  }

  void cleanUpSingleSuspects() {
    for (var entry in getGameOwnerSuspects().entries.toList()) {
      final gameID = entry.key;
      final possibleOwners = entry.value;

      if (possibleOwners.length == 1) {
        interestingSuspects[gameID] = gameOwnerProbabilites.remove(gameID)!;
        gameOwners[gameID] = resolveSynonym(possibleOwners.first);
      }
    }
  }

  cleanUpSingleSuspects();

  final gameOwnerScores = <String, Map<String, double>>{};
  for (var createdGame in createdGames) {
    if (gameOwnerProbabilites.containsKey(createdGame)) {
      final suspectLoginMap = gameOwnerProbabilites[createdGame]!;

      final medianDurationPerSuspect =
          suspectLoginMap.map((suspect, loginList) => MapEntry(
                suspect,
                median(
                    loginList.map((e) => e.secondBeforeOpeningGame).toList()),
              ));

      final ownerScores = <String, double>{};
      for (var entry in suspectLoginMap.entries.toList()) {
        final suspect = entry.key;
        final loginList = entry.value;

        final durationScore =
            (medianDurationPerSuspect[suspect]! / (60 * 60 * 6)).clamp(0, 1);

        final factor = pow(1 - durationScore, 2).toDouble();

        if (factor <= 0.1) {
          gameOwnerProbabilites[createdGame]!.remove(suspect);
          continue;
        }

        ownerScores[suspect] = factor * loginList.length;
      }

      if (ownerScores.length != 1) {
        gameOwnerScores[createdGame] = ownerScores;
      }
    }
  }

  cleanUpSingleSuspects();

  for (var uniqueGame in gameOwners.keys) {
    if (gameOwnerProbabilites.remove(uniqueGame) != null) {
      print('Cleaned up suspects for $uniqueGame, found a unique owner');
    }
  }

  print('\n${createdGames.length} CREATED GAMES: ' + createdGames.join(', '));

  for (var createdGame in createdGames) {
    if (gameOwners.containsKey(createdGame)) {
      print(' - $createdGame is owned by ${gameOwners[createdGame]}');
    }
  }

  for (var entry in gameOwnerScores.entries) {
    final createdGame = entry.key;
    final weightedDurationPerSuspect = entry.value;

    final sortedSuspects = weightedDurationPerSuspect.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    print(' - $createdGame is owned by one of the following');
    for (var probability in sortedSuspects) {
      print(
          '    - ${probability.value.toStringAsFixed(3).padLeft(5)} : ${probability.key}');
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
    synonymousAccounts: hashToEmailMap,
    createdGameIDNames: Map.fromEntries(
        createdGames.map((gameID) => MapEntry(gameID, gameNames[gameID]))),
    singleSuspectOwners: Map.fromEntries(createdGames
        .where((gameID) => gameOwners.containsKey(gameID))
        .map((gameID) => MapEntry(gameID, gameOwners[gameID]!))),
    multipleSuspectOwners: getGameOwnerSuspects()
        .map((key, value) => MapEntry(key, value.toList())),
  );
}

Map<String, Set<String>> findEmailSynonyms(
    Set<Set<String>> suspectGroups, Set<String> emails) {
  return {
    for (String email in emails) email: findSynonymsOf(email, suspectGroups)
  };
}

Set<String> findSynonymsOf(String target, Set<Set<String>> groups) {
  final relevantGroups =
      groups.where((group) => group.contains(target)).toSet();

  if (relevantGroups.isEmpty) return {};

  var itemsAlwaysInTheSameRoom = relevantGroups.first;

  // skip first because that's what we use for initialization
  for (var relevantGroup in relevantGroups.skip(1)) {
    itemsAlwaysInTheSameRoom =
        itemsAlwaysInTheSameRoom.intersection(relevantGroup);
  }

  itemsAlwaysInTheSameRoom.remove(target);
  return itemsAlwaysInTheSameRoom;
}

double median(List<int> a) {
  a.sort();

  final middle = a.length ~/ 2;
  if (a.length % 2 == 1) {
    return a[middle].toDouble();
  } else {
    return (a[middle - 1] + a[middle]) / 2.0;
  }
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

  int countUnknown() {
    return multipleSuspectOwners.values
        .expand((element) => element)
        .toSet()
        .length;
  }

  int countKnown() {
    return singleSuspectOwners.length;
  }
}

String extractWholeLine(String logContent, RegExpMatch match) {
  return logContent.substring(logContent.lastIndexOf("\n", match.start) + 1,
      logContent.indexOf("\n", match.end));
}

String extractTimestamp(String logContent, RegExpMatch match) {
  final lineStart = logContent.lastIndexOf("\n", match.start) + 1;
  return logContent.substring(lineStart, lineStart + 19);
}

class TimeRange {
  final DateTime minimum;
  DateTime? maximum;

  TimeRange(this.minimum);
}

class DurationRange {
  final Duration maximum;
  Duration? minimum;

  DurationRange(this.maximum);

  @override
  String toString() => '${format(minimum)} - ${format(maximum)}';

  static String format(Duration? d) {
    if (d == null) return 'N/A';

    String asString = '$d';

    // Strip milliseconds
    return asString.substring(0, asString.lastIndexOf('.'));
  }
}
