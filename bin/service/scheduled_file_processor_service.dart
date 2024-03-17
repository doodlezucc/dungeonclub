import 'dart:io';

import 'service.dart';

abstract class ScheduledFileProcessorService extends ScheduledService {
  static const Duration pauseBetweenProcessing = Duration(seconds: 3);

  final File _file;

  ScheduledFileProcessorService({
    required String filePath,
    super.interval = pauseBetweenProcessing,
  }) : _file = File(filePath);

  Future<bool> doesFileExist() => _file.exists();

  @override
  Future<void> onSchedule() async {
    if (await doesFileExist()) {
      await processFile(_file);
    }
  }

  Future<void> processFile(File file);
}
