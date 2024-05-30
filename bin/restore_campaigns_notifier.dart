import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypt/crypt.dart';
import 'package:dungeonclub/iterable_extension.dart';

import 'restore_orphan_campaigns.dart';
import 'server.dart';

void main(List<String> args) async {
  final operationJson = await analysisFile.readAsString();
  final memoryGap = MemoryGapOperation.fromJson(jsonDecode(operationJson));

  final server = Server();
  final serverData = server.data;
  await serverData.init();

  final allStoredEmailCrypts = serverData.accounts.map((e) => e.encryptedEmail);
  final relevantCrypts = allStoredEmailCrypts.where((emailCrypt) {
    return memoryGap.relevantAccounts.contains(emailCrypt.hash);
  }).toSet();

  final hashToEmailLookup = await loadEmailAddressLookup(relevantCrypts);

  print(hashToEmailLookup);
}

Future<Map<String, String?>> loadEmailAddressLookup(
    Set<Crypt> encryptedEmails) async {
  final csv = File('../TMP_CONFIDENTIAL/contacts.csv');
  final csvLines = await csv.readAsLines();

  final allAddresses = <String>{};

  for (var line in csvLines) {
    if (line.contains('@')) {
      final emailAddress = line.substring(line.lastIndexOf(',') + 1);
      allAddresses.add(emailAddress);
    }
  }

  int max = encryptedEmails.length;
  int counter = 0;
  Map<String, String?> map = {};

  final completer = Completer();

  int startedThreads = 0;
  final threadFinishedEvent = StreamController<void>.broadcast();

  final collector = ReceivePort();
  collector.listen((message) {
    final result = message as UnhasherResult;

    map[result.hash] = result.decryptedEmail;

    counter++;
    print('$counter/$max ${result.hash} -> ${result.decryptedEmail}');
    startedThreads--;

    if (counter == max) {
      completer.complete();
    } else {
      threadFinishedEvent.add(null);
    }
  });

  for (var encryptedEmail in encryptedEmails) {
    Isolate.spawn(
      findUnhashedEmailIsolate,
      UnhasherParams(
        collectorSocket: collector.sendPort,
        encryptedEmail: encryptedEmail,
        dictionary: allAddresses,
      ),
    );

    startedThreads++;
    if (startedThreads >= 10) {
      await threadFinishedEvent.stream.first;
    }
  }

  await completer.future;

  return map;
}

class UnhasherParams {
  final SendPort collectorSocket;
  final Crypt encryptedEmail;
  final Set<String> dictionary;

  UnhasherParams({
    required this.collectorSocket,
    required this.encryptedEmail,
    required this.dictionary,
  });
}

class UnhasherResult {
  final String hash;
  final String? decryptedEmail;

  UnhasherResult({
    required this.hash,
    required this.decryptedEmail,
  });
}

void findUnhashedEmailIsolate(UnhasherParams params) {
  final result = findUnhashedEmail(params.encryptedEmail, params.dictionary);

  params.collectorSocket.send(UnhasherResult(
    hash: params.encryptedEmail.hash,
    decryptedEmail: result,
  ));
}

String? findUnhashedEmail(Crypt encryptedEmail, Set<String> dictionary) {
  return dictionary.firstWhereOrNull(encryptedEmail.match);
}
