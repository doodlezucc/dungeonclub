import 'dart:html';

import 'package:dnd_interactive/actions.dart';
import 'package:meta/meta.dart';

import '../../main.dart';
import '../communication.dart';
import '../edit_image.dart';
import '../panels/upload.dart' as upload;
import 'prefab.dart';

final HtmlElement _board = querySelector('#board');

final HtmlElement _palette = querySelector('#prefabPalette');
final HtmlElement _pcPrefs = _palette.querySelector('#pcPrefabs');
final HtmlElement _otherPrefs = _palette.querySelector('#otherPrefabs');
final HtmlElement _addPref = _palette.querySelector('#addPrefab');
final HtmlElement movableGhost = querySelector('#movableGhost');

final HtmlElement _prefabProperties = querySelector('#prefabProperties');

final HtmlElement _prefabImage = querySelector('#prefabImage');
final ImageElement _prefabImageImg = _prefabImage.querySelector('img');
final InputElement _prefabName = querySelector('#prefabName');
final InputElement _prefabSize = querySelector('#prefabSize');
final UListElement _prefabAccess = querySelector('#prefabAccess');
final HtmlElement _prefabAccessSpan = querySelector('#prefabAccessSpan');
final ButtonElement _prefabRemove = querySelector('#prefabRemove');

final List<CharacterPrefab> pcPrefabs = [];
final List<CustomPrefab> prefabs = [];
final emptyPrefab = EmptyPrefab();

Prefab _selectedPrefab;
Prefab get selectedPrefab => _selectedPrefab;
set selectedPrefab(Prefab p) {
  _selectedPrefab = p;
  _palette.querySelectorAll('.prefab.selected').classes.remove('selected');
  p?.e?.classes?.add('selected');

  _prefabProperties.classes.toggle('disabled', p == null);
  _board.classes.toggle('drag', p != null);

  var isCustom = p is CustomPrefab;
  var isEmpty = p is EmptyPrefab;

  _prefabImage.classes.toggle('disabled', !isCustom);
  _prefabName.disabled = !isCustom;
  _prefabRemove.disabled = !isCustom;
  _prefabSize.disabled = isEmpty;
  _prefabAccess.classes.toggle('disabled', !isCustom);
  _updateAccessSpan();

  if (p != null) {
    _prefabName.value = p.name;
    _prefabSize.valueAsNumber = p.size;

    var img = p.img;
    _prefabImageImg.src = img;
    movableGhost.classes.toggle('empty', isEmpty);
    movableGhost.style.backgroundImage = 'url(${img})';
    movableGhost.style.setProperty('--size', '${p.size}');

    if (isCustom) {
      var children = _prefabAccess.children;
      var ids = (selectedPrefab as CustomPrefab).accessIds;
      for (var i = 0; i < children.length; i++) {
        children[i].classes.toggle('active', ids.contains(i));
      }
    }
  }
}

void _updateAccessSpan() {
  if (selectedPrefab is CustomPrefab) {
    var count = (selectedPrefab as CustomPrefab).accessIds.length;
    _prefabAccessSpan.text = 'Access ($count selected)';
  } else {
    _prefabAccessSpan.text = '';
  }
}

void initMovableManager(Iterable jList) {
  _initPrefabPalette();
  _initPrefabProperties();

  for (var j in jList) {
    onPrefabCreate(j);
  }
}

void _initPrefabPalette() {
  for (var pc in user.session.characters) {
    pcPrefabs.add(pc.prefab);
    _pcPrefs.append(pc.prefab.e);
  }

  _otherPrefs.nodes.insert(0, emptyPrefab.e);

  _addPref.onClick.listen((_) => createPrefab());
}

void _initPrefabProperties() {
  registerEditImage(
    _prefabImage,
    upload: ([Blob initialFile]) async {
      return await upload.display(
          action: GAME_PREFAB_UPDATE,
          type: IMAGE_TYPE_ENTITY,
          initialImg: initialFile,
          extras: {
            'prefab': selectedPrefab.id,
          });
    },
    onSuccess: (_) {
      var src = selectedPrefab.updateImage();
      _prefabImageImg.src = src;
      movableGhost.style.backgroundImage = 'url($src)';
      user.session.board.updatePrefabImage(selectedPrefab, src);
    },
  );

  _listenLazyUpdate(_prefabName, onChange: (pref, input) {
    (pref as CustomPrefab).name = input.value;
  });
  _listenLazyUpdate(_prefabSize, onChange: (pref, input) {
    pref.size = input.valueAsNumber;
    movableGhost.style.setProperty('--size', '${pref.size}');
  });

  for (var ch in user.session.characters) {
    var li = LIElement();
    li
      ..text = ch.name
      ..onClick.listen((_) {
        var active = li.classes.toggle('active');
        var ids = (selectedPrefab as CustomPrefab).accessIds;
        if (active) {
          ids.add(ch.id);
        } else {
          ids.remove(ch.id);
        }
        _updateAccessSpan();
        _sendUpdate();
      });

    _prefabAccess.append(li);
  }

  _prefabRemove.onClick.listen((_) async {
    var p = selectedPrefab;
    if (p != null) {
      selectedPrefab = null;
      onPrefabRemove(p);
      await socket.sendAction(GAME_PREFAB_REMOVE, {
        'prefab': p.id,
      });
    }
  });
}

void _listenLazyUpdate(
  InputElement input, {
  @required void Function(Prefab prefab, InputElement self) onChange,
}) {
  var bufferedValue = input.value;

  void update() {
    if (bufferedValue != input.value) {
      bufferedValue = input.value;
      onChange(selectedPrefab, input);
      _sendUpdate();
    }
  }

  input.onFocus.listen((_) => bufferedValue = input.value);
  input.onChange.listen((_) => update());
}

void _sendUpdate() {
  socket.sendAction(GAME_PREFAB_UPDATE, {
    'prefab': selectedPrefab.id,
    ...selectedPrefab.toJson(),
  });
}

Future<void> createPrefab() async {
  var result = await upload.display(
    action: GAME_PREFAB_CREATE,
    type: IMAGE_TYPE_ENTITY,
  );

  if (result == null) return null;

  selectedPrefab = onPrefabCreate(result);
  _prefabName.focus();
}

CustomPrefab onPrefabCreate(Map<String, dynamic> json) {
  var p = CustomPrefab(
    id: json['id'],
    size: json['size'],
    name: json['name'],
  );
  prefabs.add(p);
  _otherPrefs.insertBefore(p.e, _addPref);
  return p;
}

Prefab getPrefab(String id) {
  var allPrefabs = <Prefab>[...prefabs, ...pcPrefabs];
  return allPrefabs.firstWhere((p) => p.id == id, orElse: () => null);
}

void onPrefabUpdate(Map<String, dynamic> json) {
  var prefab = getPrefab(json['prefab']);

  if (json['size'] == null) {
    user.session.board.updatePrefabImage(prefab, prefab.updateImage());
  } else {
    prefab.fromJson(json);
  }
}

void onPrefabRemove(Prefab prefab) {
  prefab?.e?.remove();
  user.session.board.movables.forEach((m) {
    if (m.prefab == prefab) {
      m.onRemove();
    }
  });
}
