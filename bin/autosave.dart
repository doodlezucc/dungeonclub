import 'dart:async';
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
  static final int weeklySaveDay = DateTime.monday;
  final ServerData data;
  int _lastSavedWeekday = -1;

  AutoSaver(this.data);

  void init() async {
    await _backupDaily.create(recursive: true);
    await _backupWeeks.create(recursive: true);

    while (true) {
      await Future.delayed(Duration(minutes: 3));

      try {
        await _tryZipAndSave();
      } catch (err, stackTrace) {
        stderr.writeln('Autosave failed:');
        stderr.writeln(err);
        stderr.writeln(stackTrace.toString());
      }
    }
  }

  Future<void> _tryZipAndSave() async {
    final now = DateTime.now();
    final weekday = now.weekday;

    if (weekday != _lastSavedWeekday) {
      if (weekday == weeklySaveDay) {
        final yyyy = now.year;
        final mm = now.month.toString().padLeft(2, '0');
        final dd = now.day.toString().padLeft(2, '0');

        await _zipTo(p.join(_backupWeeks.path, '$yyyy-$mm-$dd.zip'));
      } else {
        await _zipTo(p.join(_backupDaily.path, 'weekday$weekday.zip'),
            force: true, includeImages: true);
      }

      _lastSavedWeekday = weekday;
    }
  }

  Future<void> _zipTo(String path,
      {bool force = false, bool includeImages = false}) async {
    if (!force && await File(path).exists()) return;

    print('Starting backup...');
    await data.save();
    print('Zipping backup... ($path)');

    final completer = Completer<double>();

    final dataReceivePort = ReceivePort();
    final errorReceivePort = ReceivePort();

    dataReceivePort.listen((size) => completer.complete(size as double));
    errorReceivePort.listen((payload) {
      // Isolates send back errors as two-element lists [error, stack trace],
      // where both have been converted to strings.
      final String error = payload[0];
      final String? stackTraceString = payload[1];

      final stackTrace = stackTraceString != null
          ? StackTrace.fromString(stackTraceString)
          : null;

      completer.completeError(error, stackTrace);
    });

    final isolate = await Isolate.spawn(
      _isolateZip,
      [dataReceivePort.sendPort, path, includeImages],
      errorsAreFatal: false,
      onError: errorReceivePort.sendPort,
    );

    try {
      final double sizeInMBs = await completer.future;
      print('Zipped backup size: ${sizeInMBs.toStringAsFixed(2)} MB');
    } finally {
      dataReceivePort.close();
      errorReceivePort.close();
      isolate.kill();
    }
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
