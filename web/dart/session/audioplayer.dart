import 'dart:html';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_track.dart';
import 'package:ambience/metadata.dart';
import 'package:dnd_interactive/actions.dart';

import '../communication.dart';
import 'session.dart';

final _root = querySelector('#ambience');

class AudioPlayer {
  final ambience = Ambience()..volume = 1;
  ClipPlaylist<AudioClipTrack> _playlist;
  Tracklist tracklist;

  AudioPlayer() {
    _playlist = ClipPlaylist(AudioClipTrack(ambience));
    _playlist.onClipChange.listen((clip) {
      displayTrack(tracklist.tracks[clip.id]);
    });
  }

  void init(Session session, json) {
    window.navigator.mediaSession
      ..setActionHandler('play', () {})
      ..setActionHandler('pause', () {})
      ..setActionHandler('stop', () {})
      ..setActionHandler('seekbackward', () {})
      ..setActionHandler('seekforward', () {})
      ..setActionHandler('seekto', () {});

    _input('vMusic', (value) => _playlist.track.volume = value);

    _root.querySelector('button').onClick.listen((_) {
      _root.classes.toggle('keep-open');
    });

    if (session.isDM) {
      _root.querySelector('#audioSkip').onClick.listen((_) => sendSkip());

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
    }

    onNewTracklist(json);
  }

  InputElement _input(String id, void Function(num value) onChange) {
    InputElement input = _root.querySelector('#$id');
    return input..onInput.listen((_) => onChange(input.valueAsNumber));
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
    tracklist = json == null ? null : Tracklist.fromJson(json);
    _playlist.fromTracklist(
        tracklist, (t) => getFile('ambience/tracks/${t.id}.mp3'));
  }

  void syncTracklist(json) {
    tracklist?.fromSyncJson(json);
    _playlist.syncToTracklist(tracklist);
  }

  void displayTrack(Track t) {
    var player = _root.querySelector('#player');

    var children = player.children;
    var title = children[0];
    title.attributes['href'] = 'https://www.youtube.com/watch?v=${t.id}';
    title.title = t.title;

    _changeText(title, t.title);
    _changeText(children[1], t.artist);
  }

  Future<void> _changeText(HtmlElement e, String content) async {
    if (e.innerHtml.trim() != content.trim()) {
      e.classes.add('transition');
      await Future.delayed(Duration(milliseconds: 200));
      e.innerHtml = content;
      e.classes.remove('transition');
    }
  }
}
