import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_track.dart';
import 'package:ambience/metadata.dart';
import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/environment.dart';

import '../../main.dart';
import '../communication.dart';
import '../html_helpers.dart';
import '../smooth_slider.dart';
import 'session.dart';

final _root = queryDom('#ambience');

class AudioPlayer {
  late Ambience _ambience;
  late FilterableAudioClipTrack _weather;
  late FilterableAudioClipTrack _crowd;
  late ClipPlaylist<AudioClipTrack> _playlist;
  Tracklist? tracklist;
  late SmoothSlider _sWeather;
  late SmoothSlider _sFilter;
  late SmoothSlider _sCrowd;

  ButtonElement get skipButton => _root.queryDom('#audioSkip');

  num _volumeSfx = 0;
  num get volumeSfx => _volumeSfx;
  set volumeSfx(num volume) {
    _volumeSfx = volume;
    _weather.volume = volume * 0.2;
    _crowd.volume = volume * 0.25;
  }

  num get volumeMusic => _playlist.track.volume;
  set volumeMusic(num volume) => _playlist.track.volume = volume;

  num get filter => _sFilter.goal;
  set filter(num v) {
    _sFilter.goal = v;
    _sFilter.input.parent!.queryDom('span').text = _getTooltip(1, v);
  }

  int get weatherIntensity => _sWeather.goal.toInt();
  set weatherIntensity(int v) {
    _sWeather.goal = v;
    _weather.cueClip(v >= 0 ? v.toInt() : null);
    _sWeather.input.parent!.queryDom('span').text =
        'Weather: ${_getTooltip(0, v)}';
  }

  int get crowdedness => _sCrowd.goal.toInt();
  set crowdedness(int v) {
    _sCrowd.goal = v;
    _crowd.cueClip(v >= 0 ? v.toInt() : null);
    _sCrowd.input.parent!.queryDom('span').text = 'Crowd: ${_getTooltip(2, v)}';
  }

  String _toUrl(String s) => getFile('ambience/sounds/$s.mp3');

  void _setupAmbience() {
    _ambience = Ambience()..volume = 0.5;
    _weather = FilterableAudioClipTrack(_ambience)
      ..addAll(['rain', 'heavy-rain'].map((s) => _toUrl('weather-$s')));

    _crowd = FilterableAudioClipTrack(_ambience)
      ..addAll(['pub', 'market'].map((s) => _toUrl('crowd-$s')));

    _playlist = ClipPlaylist(AudioClipTrack(_ambience));
    _playlist.onClipChange.listen((clip) {
      if (tracklist == null || clip == null) {
        displayTrack(null);
      } else {
        displayTrack(tracklist!.tracks[clip.id]);
      }
    });
  }

  void init(Session session, json) async {
    await requireFirstInteraction;
    _setupAmbience();

    window.navigator.mediaSession!
      ..setActionHandler('play', () {})
      ..setActionHandler('pause', () {})
      ..setActionHandler('stop', () {})
      ..setActionHandler('seekbackward', () {})
      ..setActionHandler('seekforward', () {})
      ..setActionHandler('seekto', () {});

    _input('vMusic', 0.5, (v) => volumeMusic = v);
    _input('vAmbience', 0.5, (v) => volumeSfx = v);

    _sWeather = SmoothSlider(_input(
        'weather', json['weather'], (v) => weatherIntensity = v.toInt(), true));
    _sCrowd = SmoothSlider(
        _input('crowd', json['crowd'], (v) => crowdedness = v.toInt(), true));
    _sFilter = SmoothSlider(
      _input('weatherFilter', json['inside'], (_) {}, true),
      onSmoothChange: (v) => _weather.filter = 20000 - 19800 * pow(v, 0.5),
    );

    var pin = window.localStorage['audioPin'];
    _root.classes.toggle(
        'keep-open', Environment.enableMusic ? pin != 'false' : pin == 'true');

    _root.queryDom('button').onClick.listen((_) {
      window.localStorage['audioPin'] = '${_root.classes.toggle('keep-open')}';
    });

    if (session.isDM) {
      skipButton.onClick.listen((_) => _sendSkip());

      for (var pl in _root.queryDom('#playlists').children) {
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

  InputElement _input(String id, num? init, void Function(num value) onChange,
      [bool sendAmbience = false]) {
    InputElement input = _root.queryDom('#$id');

    final stored = window.localStorage[id] ?? '$init';
    final initial = num.tryParse(stored) ?? input.valueAsNumber!;

    input.valueAsNumber = initial;
    scheduleMicrotask(() => onChange(initial));

    if (sendAmbience) {
      input.onChange.listen((_) => _sendAmbience());
    }

    return input
      ..onInput.listen((_) {
        if (!sendAmbience) {
          window.localStorage[id] = input.value!;
        }
        onChange(input.valueAsNumber!);
      });
  }

  void _sendAmbience() {
    if (user.session!.isDM) {
      socket.sendAction(GAME_MUSIC_AMBIENCE, ambienceToJson());
    }
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
    if (user.session!.isDM) {
      _playlist.skip();
      tracklist!.setTrack(_playlist.index);
      socket.sendAction(GAME_MUSIC_SKIP, tracklist!.toSyncJson());
    }
  }

  void _sendPlaylist(String? id) async {
    if (user.session!.isDM) {
      var json = await socket.request(GAME_MUSIC_PLAYLIST, {'playlist': id});
      onNewTracklist(json);

      if (id == 'Tavern') {
        crowdedness = 0;
        filter = 0.8;
      } else if (id == 'Dungeon') {
        crowdedness = -1;
        filter = 0.8;
      } else if (id != null) {
        crowdedness = -1;
        if (id == 'Overworld') filter = 0;
      }
      _sendAmbience();
    }
  }

  void onNewTracklist(json) {
    tracklist = (json == null || json['tracks'] == null)
        ? null
        : Tracklist.fromJson(json);
    _playlist.fromTracklist(
        tracklist, (t) => getFile('ambience/tracks/${t.id}.mp3'));

    skipButton.disabled = tracklist == null;
    if (tracklist == null) displayTrack(null);
  }

  void syncTracklist(json) {
    if (tracklist != null) {
      tracklist!.fromSyncJson(json);
      _playlist.syncToTracklist(tracklist!);
    }
  }

  void displayTrack(Track? t) {
    var player = _root.queryDom('#player');

    var children = player.children;
    var title = children[0];
    if (t != null) {
      player.classes.remove('hide');
      title.attributes['href'] = 'https://www.youtube.com/watch?v=${t.id}';
    } else {
      player.classes.add('hide');
      title.removeAttribute('href');
    }

    title.title = t?.title ?? '';

    _changeText(title, t?.title ?? '');
    _changeText(children[1], t?.artist ?? '');
  }

  Future<void> _changeText(Element e, String content) async {
    if (e.innerHtml!.trim() != content.trim()) {
      e.classes.add('transition');
      await Future.delayed(Duration(milliseconds: 200));
      if (content != '') {
        e.innerHtml = content;
        e.classes.remove('transition');
      }
    } else {
      e.classes.remove('transition');
    }
  }

  static String _getTooltip(int tool, num value) {
    switch (tool) {
      case 0:
        switch (value) {
          case -1:
            return 'Clear';
          case 0:
            return 'Light Rain';
          case 1:
            return 'Heavy Rain';
        }
        break;
      case 1:
        return 'Outside/Inside';
      case 2:
        switch (value) {
          case -1:
            return 'None';
          case 0:
            return 'Tavern';
          case 1:
            return 'Marketplace';
        }
    }
    throw RangeError('No tooltip for input value $value');
  }
}
