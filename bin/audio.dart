import 'dart:io';

import 'package:ambience/metadata.dart';
import 'package:ambience/server/playlists.dart';
import 'package:web_whiteboard/util.dart';

final PlaylistCollection collection = PlaylistCollection(Directory('ambience'));

Future<void> loadAmbience() async {
  await collection.loadMeta();
  try {
    await collection.readSource();
    await collection.sync();
    _customTrackMeta();
  } on ProcessException catch (e) {
    print('Unable to refresh playlists because '
        '"${e.executable}" is not installed or outdated.');
  }
}

void _customTrackMeta() {
  for (var track in collection.allTracks) {
    var title = track.title;
    var hyphen = title.lastIndexOf(' - ');

    if (hyphen >= 0) {
      final preHyphen = title.substring(0, hyphen);
      final postHyphen = title.substring(hyphen + 3);

      if (track.artist == 'Samuel Oliveira') {
        track.title = preHyphen;
      } else if (track.artist == 'D&D Breakfast Club') {
        track.title = preHyphen;
        track.artist = postHyphen;
      } else if (track.artist == 'Vindsvept, fantasy music') {
        track.artist = 'Vindsvept';
        if (!preHyphen.contains('Music')) {
          track.title = preHyphen;
        } else {
          track.title = postHyphen;
        }
      } else if (track.artist == 'Adrian von Ziegler') {
        track.title = postHyphen;
      } else if (title.contains('Scott Buckley')) {
        var regex = RegExp(r"(?<=').+?(?='(?: |$))");
        var match = regex.firstMatch(title);
        if (match != null) {
          track.title = match[0]!;
        }
      }
    }
  }

  collection.saveMeta();
}

class AmbienceState {
  String? playlistName;
  Tracklist? list;
  int weather = -1;
  num inside = 0;
  int crowd = -1;

  Map<String, dynamic> toJson({bool includeTracklist = true}) => {
        'playlist': playlistName,
        'weather': weather,
        'inside': inside,
        'crowd': crowd,
        if (includeTracklist && list != null) ...list!.toJson(),
      };

  void fromJson(Map<String, dynamic> json) {
    playlistName = json['playlist'];
    ambienceFromJson(json);
    final pl = collection.playlists.firstWhereOrNull(
      (pl) => pl.title == json['playlist'],
    );

    list = pl?.toTracklist(shuffle: true);
  }

  void ambienceFromJson(json) {
    weather = json['weather'];
    inside = json['inside'];
    crowd = json['crowd'];
  }
}
