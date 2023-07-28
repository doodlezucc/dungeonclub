import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

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

        return zipTo(p.join(_backupWeeks.path, '$yyyy-$mm-$dd.zip'));
      } else {
        return zipTo(p.join(_backupDaily.path, 'weekday$weekday.zip'),
            force: true, includeImages: true);
      }
    }
  }

  Future<void> zipTo(String path,
      {bool force = false, bool includeImages = false}) async {
    if (!force && await File(path).exists()) return;

    print('Saving backup... ($path)');
    await data.save();

    var receive = ReceivePort();
    var isolate = await Isolate.spawn(
        _isolateZip, [receive.sendPort, path, includeImages]);

    double sizeInMBs = await receive.first;
    print('Zipped backup size: ${sizeInMBs.toStringAsFixed(2)} MB');

    receive.close();
    isolate.kill();
  }
}

void _isolateZip(List<Object> args) async {
  final port = args[0] as SendPort;
  final path = args[1] as String;
  final includeImages = args[2] as bool;

  var encoder = ZipFileEncoder();
  encoder.create(path);

  var dir = ServerData.directory;
  var files = await dir.list(recursive: true).toList();
  for (var file in files) {
    if (file is! File) {
      continue;
    }

    var fp = file.path;

    if (!includeImages) {
      var ext = p.extension(fp);
      if (!(ext == '.json' || fp.endsWith('histogram'))) {
        continue;
      }
    }

    var relPath = p.relative(fp, from: dir.path);
    await encoder.addFile(file, relPath);
  }

  encoder.close();

  var stat = await File(path).stat();
  port.send(stat.size / 1024 / 1024);
}
