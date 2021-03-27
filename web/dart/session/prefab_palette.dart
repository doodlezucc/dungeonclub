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
final HtmlElement _selectionProperties = querySelector('#selectionProperties');

final HtmlElement _prefabImage = querySelector('#prefabImage');
final ImageElement _prefabImageImg = _prefabImage.querySelector('img');
final InputElement _prefabName = querySelector('#prefabName');
final InputElement _prefabSize = querySelector('#prefabSize');

final List<CharacterPrefab> pcPrefabs = [];
final List<CustomPrefab> prefabs = [];

Prefab _selectedPrefab;
Prefab get selectedPrefab => _selectedPrefab;
set selectedPrefab(Prefab p) {
  _selectedPrefab = p;
  _palette.querySelectorAll('.prefab.selected').classes.remove('selected');
  p?.e?.classes?.add('selected');

  _prefabProperties.classes.toggle('disabled', p == null);
  _board.classes.toggle('drag', p != null);

  var isCustom = p is CustomPrefab;

  _prefabImage.classes.toggle('disabled', !isCustom);
  _prefabName.disabled = !isCustom;

  if (p != null) {
    _prefabName.value = isCustom
        ? (p as CustomPrefab).name
        : (p as CharacterPrefab).character.name;
    _prefabSize.valueAsNumber = p.size;

    _prefabImageImg.src = p.img;
    movableGhost.style.backgroundImage = 'url(${p.img})';
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

  selectedPrefab = pcPrefabs.first;

  _addPref.onClick.listen((event) {
    createPrefab();
  });
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

  input.onFocus.listen((_) {
    bufferedValue = input.value;
  });
  input.onChange.listen((_) => update());
}

void _sendUpdate() {
  socket.sendAction(GAME_PREFAB_UPDATE, {
    'prefab': selectedPrefab.id,
    'size': selectedPrefab.size,
    if (selectedPrefab is CustomPrefab) 'name': _prefabName.value,
  });
}

Future<void> createPrefab() async {
  var result = await upload.display(
    action: GAME_PREFAB_CREATE,
    type: IMAGE_TYPE_ENTITY,
  );

  if (result == null) return null;

  onPrefabCreate(result);
}

void onPrefabCreate(Map<String, dynamic> json) {
  var p = CustomPrefab(
    id: json['id'],
    size: json['size'],
    name: json['name'],
  );
  prefabs.add(p);
  _otherPrefs.insertBefore(p.e, _addPref);
}

void onPrefabUpdate(Map<String, dynamic> json) {
  String id = json['prefab'];
  print(id);

  var prefab = prefabs.firstWhere((p) => p.id == id, orElse: () => null);
  print(prefab);

  if (json['size'] == null) {
    user.session.board.updatePrefabImage(prefab, prefab.updateImage());
  } else {
    prefab.fromJson(json);
  }
}
