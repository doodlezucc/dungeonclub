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
  FilterableAudioClipTrack _weather;
  FilterableAudioClipTrack _crowd;
  ClipPlaylist<AudioClipTrack> _playlist;
  Tracklist tracklist;

  num get volumeSfx => _crowd.volume;
  set volumeSfx(num volume) {
    _weather.volume = volume;
    _crowd.volume = volume;
  }

  num get volumeMusic => _playlist.track.volume;
  set volumeMusic(num volume) => _playlist.track.volume = volume;

  AudioPlayer() {
    _weather = FilterableAudioClipTrack(ambience)
      ..addAll(['wind', 'rain', 'heavy-rain'].map((s) => _toUrl('weather-$s')));

    _crowd = FilterableAudioClipTrack(ambience)
      ..addAll(['pub', 'market'].map((s) => _toUrl('crowd-$s')));

    _playlist = ClipPlaylist(AudioClipTrack(ambience));
    _playlist.onClipChange.listen((clip) {
      displayTrack(tracklist.tracks[clip.id]);
    });
  }

  String _toUrl(String s) => getFile('ambience/sounds/$s.mp3');

  void init(Session session, json) {
    window.navigator.mediaSession
      ..setActionHandler('play', () {})
      ..setActionHandler('pause', () {})
      ..setActionHandler('stop', () {})
      ..setActionHandler('seekbackward', () {})
      ..setActionHandler('seekforward', () {})
      ..setActionHandler('seekto', () {});

    _input('vMusic', 0.6, (v) => volumeMusic = v);
    _input('vAmbience', 0.4, (v) => volumeSfx = v);
    _input('weather', -1, (v) => _weather.cueClip(v >= 0 ? v.toInt() : null));

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

  InputElement _input(String id, num init, void Function(num value) onChange) {
    var stored = window.localStorage[id] ?? '$init';
    var initial = num.tryParse(stored);

    InputElement input = _root.querySelector('#$id');
    input.valueAsNumber = initial;
    onChange(initial);

    return input
      ..onInput.listen((_) {
        window.localStorage[id] = input.value;
        onChange(input.valueAsNumber);
      });
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
