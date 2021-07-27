import 'dart:io';

import 'package:web_whiteboard/binary.dart';

import 'connections.dart';

const entriesPerHour = 4;

class PlayingHistogram {
  final File file;
  final histogram = List<int>.generate(
      7 * Duration.hoursPerDay * entriesPerHour, (_) => 0,
      growable: false);

  PlayingHistogram(String filePath) : file = File(filePath);

  Future<void> save() async {
    var writer = BinaryWriter();
    for (var count in histogram) {
      writer.writeUInt32(count);
    }
    await file.writeAsBytes(writer.takeBytes());
  }

  Future<void> load() async {
    if (!await file.exists()) return;
    var reader = BinaryReader.fromList(await file.readAsBytes());
    for (var i = 0; i < histogram.length; i++) {
      histogram[i] = reader.readUInt32();
    }
  }

  void startTracking() async {
    while (true) {
      await Future.delayed(
          Duration(minutes: Duration.minutesPerHour ~/ entriesPerHour));
      _updateCell();
    }
  }

  void _updateCell() {
    var now = DateTime.now();
    var cellIndex = ((now.weekday - 1) * Duration.hoursPerDay + // Day
            now.hour + // Hour
            now.minute / Duration.minutesPerHour) * // Interval within hour
        entriesPerHour;

    histogram[cellIndex.floor()] = getOnlinePlayers();
  }

  int getOnlinePlayers() => connections.length;
}
