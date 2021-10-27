import 'dart:html';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_track.dart';
import 'package:ambience/metadata.dart';
import 'package:dnd_interactive/actions.dart';

import '../communication.dart';
import 'session.dart';

final _root = querySelector('#ambience');

class AudioPlayer {
  final ambience = Ambience();
  ClipPlaylist<AudioClipTrack> _playlist;
  Tracklist tracklist;

  AudioPlayer() {
    _playlist = ClipPlaylist(AudioClipTrack(ambience));
    _playlist.onClipChange.listen((clip) {
      displayTrack(tracklist.tracks[clip.id]);
    });
  }

  void init(Session session, json) {
    if (session.isDM) {
      _root.querySelector('#audioSkip').onClick.listen((_) => sendSkip());
    }

    for (var pl in _root.querySelector('#playlists').children) {
      var id = pl.attributes['value'];

      if (json != null && json['playlist'] == id) {
        pl.classes.add('active');
      }

      pl.onClick.listen((_) {
        var doSend = !pl.classes.contains('active');
        if (doSend) {
          _root
              .querySelectorAll('#playlists > .active')
              .classes
              .remove('active');
        }

        pl.classes.toggle('active', doSend);
        sendPlaylist(doSend ? id : null);
      });
    }

    onNewTracklist(json);
  }

  void sendSkip() {
    _playlist.skip();
    tracklist.setTrack(_playlist.index);
    socket.sendAction(GAME_MUSIC_SKIP, tracklist.toSyncJson());
  }

  void sendPlaylist(String id) async {
    var json = await socket.request(GAME_MUSIC_PLAYLIST, {'playlist': id});
    onNewTracklist(json);
  }

  void onNewTracklist(json) {
    print('TRACKLIST');
    print(json);
    tracklist = json == null ? null : Tracklist.fromJson(json);
    _playlist.fromTracklist(
        tracklist, (t) => getFile('ambience/tracks/${t.id}.mp3'));
  }

  void syncTracklist(json) {
    tracklist?.fromSyncJson(json);
    _playlist.syncToTracklist(tracklist);
  }

  void displayTrack(Track t) {
    var children = _root.querySelector('#player').children;
    children[0].innerHtml = '<b>${t.title}</b>';
    children[1].text = t.artist;
  }
}
