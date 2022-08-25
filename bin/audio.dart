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
      } else if (track.artist == 'Adrian von Ziegler') {
        track.title = title.substring(hyphen + 3);
      } else if (title.contains('Scott Buckley')) {
        var regex = RegExp(r"(?<=').+(?=')");
        var match = regex.firstMatch(title);
        if (match != null) {
          track.title = match[0];
        }
      }
    }
  }

  collection.saveMeta();
}

class AmbienceState {
  String playlistName;
  Tracklist list;
  int weather = -1;
  num inside = 0;
  int crowd = -1;

  Map<String, dynamic> toJson({bool includeTracklist = true}) => {
        'playlist': playlistName,
        'weather': weather,
        'inside': inside,
        'crowd': crowd,
        if (includeTracklist && list != null) ...list.toJson(),
      };

  void fromJson(Map<String, dynamic> json) {
    playlistName = json['playlist'];
    ambienceFromJson(json);
    var pl = collection.playlists.firstWhere(
      (pl) => pl.title == json['playlist'],
      orElse: () => null,
    );

    list = pl?.toTracklist(shuffle: true);
  }

  void ambienceFromJson(json) {
    weather = json['weather'];
    inside = json['inside'];
    crowd = json['crowd'];
  }
}
