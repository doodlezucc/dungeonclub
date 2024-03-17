import 'dart:async';
import 'dart:io';

import '../../server.dart';

abstract class ScheduledFileProcessor {
  static const Duration pauseBetweenProcessing = Duration(seconds: 3);

  final Server server;
  final File _file;

  ScheduledFileProcessor(this.server, String filePath) : _file = File(filePath);

  Future<bool> doesFileExist() => _file.exists();

  Future<void> autoCheckForFile() async {
    while (true) {
      try {
        if (await doesFileExist()) {
          await processFile(_file);
        }
      } catch (err) {
        stderr.writeln('Error while processing file (${_file.path})');
        stderr.writeln(err);
      }

      await Future.delayed(pauseBetweenProcessing);
    }
  }

  Future<void> processFile(File file);
}
