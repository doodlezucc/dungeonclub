import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';
import '../edit_image.dart';
import '../panels/upload.dart' as upload;
import 'prefab.dart';

final HtmlElement _palette = querySelector('#prefabPalette');
final HtmlElement _pcPrefs = _palette.querySelector('#pcPrefabs');
final HtmlElement _otherPrefs = _palette.querySelector('#otherPrefabs');
final HtmlElement _addPref = _palette.querySelector('#addPrefab');

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

  var isPC = p is CharacterPrefab;

  _prefabImage.classes.toggle('disabled', isPC);
  _prefabName.disabled = isPC;

  if (p != null) {
    _prefabName.value =
        isPC ? (p as CharacterPrefab).character.name : (p as CustomPrefab).name;
    _prefabSize.valueAsNumber = p.size;

    _prefabImageImg.src = p.img;
  } else {
    _prefabName.value = '';
    _prefabSize.value = '';
    _prefabImageImg.src = '';
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
    onSuccess: (src) {
      _prefabImageImg.src = selectedPrefab.updateImage();
    },
  );

  void sendUpdate() {
    socket.sendAction(GAME_PREFAB_UPDATE, {
      'prefab': selectedPrefab.id,
      'name': _prefabName.value,
      'size': _prefabSize.valueAsNumber,
    });
  }

  _prefabName.onChange.listen((_) {
    (selectedPrefab as CustomPrefab).name = _prefabName.value;
    sendUpdate();
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
  );
  prefabs.add(p);
  _otherPrefs.insertBefore(p.e, _addPref);
}

void onPrefabUpdate(Map<String, dynamic> json) {
  int id = json['prefab'];

  var prefab = prefabs.firstWhere((p) => p.id == id, orElse: () => null);

  if (json['size'] == null) {
    prefab.updateImage();
  } else {
    prefab.fromJson(json);
  }
}
