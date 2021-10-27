import 'dart:io';

import 'package:ambience/metadata.dart';
import 'package:ambience/server/playlists.dart';

final PlaylistCollection collection = PlaylistCollection(Directory('ambience'));

Future<void> loadAmbience() async {
  await collection.reload();
  await collection.sync();
  _customTrackMeta();
}

void _customTrackMeta() {
  for (var track in collection.allTracks) {
    var title = track.title;
    var hyphen = title.lastIndexOf(' - ');

    if (hyphen >= 0) {
      if (track.artist == 'D&D Breakfast Club') {
        track.title = title.substring(0, hyphen);
        track.artist = title.substring(hyphen + 3);
      } else if (track.artist == 'Vindsvept, fantasy music') {
        track.artist = 'Vindsvept';
        track.title = title.substring(hyphen + 3);
      }
    }
  }

  collection.saveMeta();
}

class AmbienceState {
  String playlistName;
  Tracklist list;

  Map<String, dynamic> toJson() =>
      list == null ? null : {'playlist': playlistName, ...list.toJson()};
}
