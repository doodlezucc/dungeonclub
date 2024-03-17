import '../../data.dart';
import 'dart:async';
import 'dart:io';
import 'file_processor.dart';

class AccountRemovalService extends ScheduledFileProcessorService {
  final ServerData serverData;

  AccountRemovalService({required this.serverData})
      : super(filePath: 'account');

  @override
  Future processFile(File file) async {
    var lines = await file.readAsLines();
    var changed = false;
    for (var l in lines) {
      if (l.isNotEmpty) {
        var acc = serverData.getAccount(l, alreadyEncrypted: !l.contains('@'));
        if (acc != null) {
          changed = true;
          var count = acc.ownedGames.length;
          await acc.delete();
          print('Deleted account ${acc.encryptedEmail} with $count games...');
        }
      }
    }

    if (changed) {
      await file.delete();
    }
  }
}
