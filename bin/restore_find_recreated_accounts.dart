import 'dart:convert';

import 'package:crypt/crypt.dart';
import 'package:dungeonclub/iterable_extension.dart';

import 'data.dart';
import 'restore_in_parallel.dart';
import 'restore_orphan_campaigns.dart';
import 'server.dart';

void main(List<String> args) async {
  final operationJson = await analysisFile.readAsString();
  final memoryGap = MemoryGapOperation.fromJson(jsonDecode(operationJson));

  final server = Server();
  final serverData = server.data;
  await serverData.init();

  findRecreatedAccountsNewCrypts(
      memoryGap.relevantAccounts.toSet(), serverData);
}

Future<Map<String, String>> findRecreatedAccountsNewCrypts(
    Set<String> relevantAccountsInGap, ServerData serverData) async {
  final allAccounts = serverData.accounts.map((e) => e.encryptedEmail).toSet();
  final emailAccounts =
      relevantAccountsInGap.where((hash) => hash.contains('@')).toSet();

  int max = emailAccounts.length;
  int counter = 0;
  final map = <String, String>{};

  await parallelize<FinderParams, Crypt?>(
    findRecreatedAccountCryptIsolate,
    emailAccounts
        .map((email) => FinderParams(email: email, accounts: allAccounts)),
    onComputed: (params, result) {
      if (result != null) {
        map[params.email] = result.toString();
      }

      counter++;
      print('$counter/$max ${params.email} -> $result');
    },
  );

  return map;
}

class FinderParams {
  final String email;
  final Set<Crypt> accounts;

  FinderParams({required this.email, required this.accounts});
}

Crypt? findRecreatedAccountCryptIsolate(FinderParams params) {
  return findRecreatedAccountCrypt(params.email, params.accounts);
}

Crypt? findRecreatedAccountCrypt(String email, Set<Crypt> accounts) {
  final recreatedLostAccount =
      accounts.firstWhereOrNull((acc) => acc.match(email));
  return recreatedLostAccount;
}
