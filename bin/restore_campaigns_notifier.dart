import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypt/crypt.dart';
import 'package:dungeonclub/iterable_extension.dart';

import 'restore_in_parallel.dart';
import 'restore_orphan_campaigns.dart';
import 'server.dart';

void main(List<String> args) async {
  final operationJson = await analysisFile.readAsString();
  final memoryGap = MemoryGapOperation.fromJson(jsonDecode(operationJson));

  await identifyEmailsOutsideOfMemoryGap(memoryGap.relevantAccounts.toSet());

  // final emailLookupJson =
  //     await File('../TMP_CONFIDENTIAL/recovered-emails.json').readAsString();
  // final hashToEmailLookup =
  //     Map<String, String?>.from(jsonDecode(emailLookupJson));
}

Future<void> identifyEmailsOutsideOfMemoryGap(
    Set<String> relevantAccountsInGap) async {
  final server = Server();
  final serverData = server.data;
  await serverData.init();

  final allStoredEmailCrypts = serverData.accounts.map((e) => e.encryptedEmail);
  final relevantCrypts = allStoredEmailCrypts.where((emailCrypt) {
    return relevantAccountsInGap.contains(emailCrypt.hash);
  }).toSet();

  final hashToEmailLookup = await loadEmailAddressLookup(relevantCrypts);

  await File('../TMP_CONFIDENTIAL/recovered-emails.json')
      .writeAsString(jsonEncode(hashToEmailLookup));

  print('Done');
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

  await parallelize<UnhasherParams, String?>(
    findUnhashedEmailIsolate,
    encryptedEmails.map((encryptedEmail) => UnhasherParams(
          encryptedEmail: encryptedEmail,
          dictionary: allAddresses,
        )),
    onComputed: (params, result) {
      map[params.encryptedEmail.hash] = result;
      counter++;
      print('$counter/$max ${params.encryptedEmail.hash} -> $result');
    },
  );

  return map;
}

class UnhasherParams {
  final Crypt encryptedEmail;
  final Set<String> dictionary;

  UnhasherParams({
    required this.encryptedEmail,
    required this.dictionary,
  });
}

String? findUnhashedEmailIsolate(UnhasherParams params) {
  return findUnhashedEmail(params.encryptedEmail, params.dictionary);
}

String? findUnhashedEmail(Crypt encryptedEmail, Set<String> dictionary) {
  return dictionary.firstWhereOrNull(encryptedEmail.match);
}
