import 'dart:async';
import 'dart:io';

import 'data.dart';

class AutoSaver {
  final ServerData data;

  AutoSaver(this.data);

  void init() async {
    while (true) {
      await Future.delayed(Duration(hours: 1));

      try {
        await data.save();
      } catch (err, stackTrace) {
        stderr.writeln('Autosave failed:');
        stderr.writeln(err);
        stderr.writeln(stackTrace.toString());
      }
    }
  }
}
