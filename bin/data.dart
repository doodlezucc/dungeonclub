import 'dart:async';
import 'dart:convert';

import 'dart:io';

class ServerData {
  static final _manualSaveWatch = Stopwatch();

  final accounts = <Account>[];

  ServerData() {
    _manualSaveWatch.start();
    //initAutoSave();
  }

  void initAutoSave() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      save();
    });
  }

  Account getAccount(String email) {
    if (email == null) return null;
    var encrypted = Account.encrypt(email);
    return accounts.singleWhere((p) => p.encryptedEmail == encrypted,
        orElse: () => null);
  }

  Map<String, dynamic> toJson() => {
        'accounts': accounts.map((e) => e.toJson(withPassword: true)).toList(),
      };

  Future<void> save() async {
    var json = JsonEncoder.withIndent(' ').convert(toJson());
    print(json);
    await File('database/data.json').writeAsString(json);
    print('Saved!');
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
  final String encryptedEmail;
  String encryptedPassword;

  static String encrypt(String s) => s;

  Account(this.encryptedEmail, this.encryptedPassword);

  Map<String, dynamic> toJson({withPassword = false}) => {
        'email': encryptedEmail,
        if (withPassword) 'password': encryptedPassword,
      };
}
