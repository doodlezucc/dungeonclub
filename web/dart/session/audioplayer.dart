import 'dart:html';
import 'dart:math';

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

  num _volumeSfx = 0;
  num get volumeSfx => _volumeSfx;
  set volumeSfx(num volume) {
    _volumeSfx = volume;
    _weather.volume = volume * 0.2;
    _crowd.volume = volume * 0.3;
  }

  num get volumeMusic => _playlist.track.volume;
  set volumeMusic(num volume) => _playlist.track.volume = volume;

  num _filter = 0;
  num get filter => _filter;
  set filter(num filter) {
    _filter = filter;
    _weather.filter = 20000 - 19950 * pow(filter, 0.5);
  }

  int get weatherIntensity => _weather.activeClip?.id ?? -1;
  set weatherIntensity(int v) {
    _weather.cueClip(v >= 0 ? v.toInt() : null);
  }

  int get crowdedness => _crowd.activeClip?.id ?? -1;
  set crowdedness(int v) {
    _crowd.cueClip(v >= 0 ? v.toInt() : null);
  }

  AudioPlayer() {
    _weather = FilterableAudioClipTrack(ambience)
      ..addAll(['rain', 'heavy-rain'].map((s) => _toUrl('weather-$s')));

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
    _input('vAmbience', 0.6, (v) => volumeSfx = v);
    _input('weather', json['weather'], (v) => weatherIntensity = v, true);
    _input('crowd', json['crowd'], (v) => crowdedness = v, true);
    _input('weatherFilter', json['inside'], (v) => filter = v, true);

    if (window.localStorage['audioPin'] == 'true') {
      _root.classes.add('keep-open');
    }

    _root.querySelector('button').onClick.listen((_) {
      window.localStorage['audioPin'] = '${_root.classes.toggle('keep-open')}';
    });

    if (session.isDM) {
      _root.querySelector('#audioSkip').onClick.listen((_) => _sendSkip());

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
          _sendPlaylist(doSend ? id : null);
        });
      }
    } else {
      ambienceFromJson(json);
    }

    onNewTracklist(json);
  }

  InputElement _input(String id, num init, void Function(num value) onChange,
      [bool sendAmbience = false]) {
    InputElement input = _root.querySelector('#$id');

    var stored = window.localStorage[id] ?? '$init';
    var initial = num.tryParse(stored) ?? input.valueAsNumber;

    input.valueAsNumber = initial;
    onChange(initial);

    if (sendAmbience) {
      input.onChange.listen((_) => _sendAmbience());
    }

    return input
      ..onInput.listen((_) {
        if (!sendAmbience) {
          window.localStorage[id] = input.value;
        }
        onChange(input.valueAsNumber);
      });
  }

  void _sendAmbience() {
    socket.sendAction(GAME_MUSIC_AMBIENCE, ambienceToJson());
  }

  Map<String, dynamic> ambienceToJson() => {
        'weather': weatherIntensity,
        'inside': filter,
        'crowd': crowdedness,
      };

  void ambienceFromJson(json) {
    weatherIntensity = json['weather'];
    filter = json['inside'];
    crowdedness = json['crowd'];
  }

  void _sendSkip() {
    _playlist.skip();
    tracklist.setTrack(_playlist.index);
    socket.sendAction(GAME_MUSIC_SKIP, tracklist.toSyncJson());
  }

  void _sendPlaylist(String id) async {
    var json = await socket.request(GAME_MUSIC_PLAYLIST, {'playlist': id});
    onNewTracklist(json);
  }

  void onNewTracklist(json) {
    tracklist = json['tracks'] == null ? null : Tracklist.fromJson(json);
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
