import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'data.dart';

final _backupDaily = Directory(
    p.join(DungeonClubConfig.databasePath, 'database_backup', 'daily'));
final _backupWeeks = Directory(
    p.join(DungeonClubConfig.databasePath, 'database_backup', 'weeks'));

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
      await _tryZipAndSave();
    }
  }

  Future<void> _tryZipAndSave() async {
    final now = DateTime.now();
    final weekday = now.weekday;

    if (weekday != bufferedWeekday) {
      bufferedWeekday = weekday;

      if (weekday == weeklySaveDay) {
        final yyyy = now.year;
        final mm = now.month.toString().padLeft(2, '0');
        final dd = now.day.toString().padLeft(2, '0');

        return _zipTo(p.join(_backupWeeks.path, '$yyyy-$mm-$dd.zip'));
      } else {
        return _zipTo(p.join(_backupDaily.path, 'weekday$weekday.zip'),
            force: true, includeImages: true);
      }
    }
  }

  Future<void> _zipTo(String path,
      {bool force = false, bool includeImages = false}) async {
    if (!force && await File(path).exists()) return;

    print('Saving backup... ($path)');
    await data.save();

    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
        _isolateZip, [receivePort.sendPort, path, includeImages]);

    final double sizeInMBs = await receivePort.first;
    print('Zipped backup size: ${sizeInMBs.toStringAsFixed(2)} MB');

    receivePort.close();
    isolate.kill();
  }
}

void _isolateZip(List<Object> args) async {
  final port = args[0] as SendPort;
  final path = args[1] as String;
  final includeImages = args[2] as bool;

  final zipEncoder = ZipFileEncoder();
  zipEncoder.create(path, level: Deflate.BEST_SPEED);

  final dataDirectory = ServerData.directory;
  final allDatabaseFiles = await dataDirectory.list(recursive: true).toList();

  for (final file in allDatabaseFiles) {
    if (file is! File) {
      continue;
    }

    final filePath = file.path;

    if (!includeImages) {
      final fileExtension = p.extension(filePath);

      // Images have been stored in the database without any file extension in
      // the past (they were all served as JPEG I think).
      // This is a very general check to account for these legacy images.
      final isImageFile =
          fileExtension != '.json' && !filePath.endsWith('histogram');

      if (isImageFile) {
        continue;
      }
    }

    final relativeFilePath = p.relative(filePath, from: dataDirectory.path);
    await zipEncoder.addFile(file, relativeFilePath, ZipFileEncoder.STORE);
  }

  await zipEncoder.close();

  final encodedZipStat = await File(path).stat();
  port.send(encodedZipStat.size / 1000 / 1000);
}
