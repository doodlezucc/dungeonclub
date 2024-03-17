import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import '../../config.dart';
import 'package:path/path.dart' as path;

import '../../data.dart';
import 'scheduled_service.dart';

final _backupRoot =
    path.join(DungeonClubConfig.databasePath, 'database_backup');

final _backupDaily = Directory(path.join(_backupRoot, 'daily'));
final _backupWeeks = Directory(path.join(_backupRoot, 'weeks'));

class AutoSaveService extends ScheduledService {
  static const int weeklySaveDay = DateTime.monday;
  final ServerData serverData;
  int bufferedWeekday = -1;

  AutoSaveService({required this.serverData})
      : super(
          interval: Duration(minutes: 3),
        );

  @override
  Future<void> start() async {
    _createBackupDirectories();
    super.start();
  }

  Future<void> _createBackupDirectories() async {
    await _backupDaily.create(recursive: true);
    await _backupWeeks.create(recursive: true);
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
            force: true, includeImages: true);
      }
    }
  }

  Future<void> zipTo(String path,
      {bool force = false, bool includeImages = false}) async {
    if (!force && await File(path).exists()) return;

    print('Saving backup... ($path)');
    await serverData.save();

    var receive = ReceivePort();
    var isolate = await Isolate.spawn(
        _isolateZip, [receive.sendPort, path, includeImages]);

    double sizeInMBs = await receive.first;
    print('Zipped backup size: ${sizeInMBs.toStringAsFixed(2)} MB');

    receive.close();
    isolate.kill();
  }

  @override
  Future<void> onSchedule() async {
    await tryZipAndSave();
  }
}

void _isolateZip(List<Object> args) async {
  final port = args[0] as SendPort;
  final zipPath = args[1] as String;
  final includeImages = args[2] as bool;

  var encoder = ZipFileEncoder();
  encoder.create(zipPath, level: Deflate.BEST_SPEED);

  var dir = ServerData.directory;
  var files = await dir.list(recursive: true).toList();
  for (var file in files) {
    if (file is! File) {
      continue;
    }

    var fp = file.path;

    if (!includeImages) {
      var ext = path.extension(fp);
      if (!(ext == '.json' || fp.endsWith('histogram'))) {
        continue;
      }
    }

    var relPath = path.relative(fp, from: dir.path);
    await encoder.addFile(file, relPath);
  }

  encoder.close();

  var stat = await File(zipPath).stat();
  port.send(stat.size / 1000 / 1000);
}
