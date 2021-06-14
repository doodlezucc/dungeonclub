import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;

import 'data.dart';

final _backupDaily = Directory('database_backup/daily');
final _backupWeeks = Directory('database_backup/weeks');

class AutoSaver {
  final int weeklySaveDay = DateTime.monday;
  final ServerData data;
  int bufferedWeekday = -1;

  AutoSaver(this.data);

  void init() async {
    await _backupDaily.create(recursive: true);
    await _backupWeeks.create(recursive: true);

    while (true) {
      await Future.delayed(Duration(minutes: 3));
      await tryZipAndSave();
    }
  }

  Future<void> tryZipAndSave() async {
    var date = DateTime.now();

    var weekday = date.weekday;

    if (weekday != bufferedWeekday) {
      bufferedWeekday = weekday;

      if (weekday == weeklySaveDay) {
        var yyyy = date.year;
        var mm = date.month.toString().padLeft(2, '0');
        var dd = date.day.toString().padLeft(2, '0');

        return zipTo(path.join(_backupWeeks.path, '$yyyy-$mm-$dd.zip'));
      } else {
        return zipTo(path.join(_backupDaily.path, 'weekday$weekday.zip'),
            force: true);
      }
    }
  }

  Future<void> zipTo(String path, {bool force = false}) async {
    var file = File(path);
    if (!force && await file.exists()) return;

    print('Saving backup... ($path)');
    await data.save();
    var encoder = ZipFileEncoder();
    encoder.zipDirectory(ServerData.directory, filename: path);

    var stat = await file.stat();
    var sizeInMBs = stat.size / 1024 / 1024;
    print('Zipped backup size: ${sizeInMBs.toStringAsFixed(2)} MB');
  }
}
