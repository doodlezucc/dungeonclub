import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../panels/upload.dart' as upload;
import 'prefab.dart';

final HtmlElement _palette = querySelector('#prefabPalette');
final HtmlElement _pcPrefs = _palette.querySelector('#pcPrefabs');
final HtmlElement _otherPrefs = _palette.querySelector('#otherPrefabs');
final HtmlElement _addPref = _palette.querySelector('#addPrefab');

final HtmlElement _prefabProperties = querySelector('#prefabProperties');
final HtmlElement _selectionProperties = querySelector('#selectionProperties');

final List<CharacterPrefab> pcPrefabs = [];
final List<CustomPrefab> prefabs = [];

Prefab _selectedPrefab;
Prefab get selectedPrefab => _selectedPrefab;
set selectedPrefab(Prefab p) {
  _selectedPrefab = p;
  _palette.querySelectorAll('.prefab.selected').classes.remove('selected');
  p.e.classes.add('selected');
  _prefabProperties.classes.toggle('disabled', p == null);
}

void initMovableManager(Iterable jList) {
  _initPrefabPalette();

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
