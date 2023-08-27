import 'dart:html';

import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/iterable_extension.dart';
import 'package:dungeonclub/limits.dart';
import 'package:dungeonclub/models/entity_base.dart';
import 'package:dungeonclub/session_util.dart';

import '../../main.dart';
import '../communication.dart';
import '../edit_image.dart';
import '../html/instance_list.dart';
import '../html_helpers.dart';
import '../notif.dart';
import '../panels/upload.dart' as upload;
import '../resource.dart';
import 'character.dart';
import 'movable.dart';
import 'prefab.dart';

final HtmlElement _palette = queryDom('#prefabPalette');
final HtmlElement _pcPrefs = _palette.queryDom('#pcPrefabs');
final HtmlElement _otherPrefs = _palette.queryDom('#otherPrefabs');
final ButtonElement _addPref = _palette.queryDom('#addPrefab');

final HtmlElement _movableGhost = queryDom('#movableGhost');

final HtmlElement _prefabProperties = queryDom('#prefabProperties');

final HtmlElement _prefabImage = queryDom('#prefabImage');
final ImageElement _prefabImageImg = _prefabImage.queryDom('img');
final HtmlElement _prefabEmptyIcon = queryDom('#emptyIcon');
final InputElement _prefabName = queryDom('#prefabName');
final InputElement _prefabSize = queryDom('#prefabSize');
final UListElement _prefabAccess = queryDom('#prefabAccess');
final HtmlElement _prefabAccessSpan = queryDom('#prefabAccessSpan');
final ButtonElement _prefabRemove = queryDom('#prefabRemove');

final pcPrefabs = InstanceList<CharacterPrefab>(_pcPrefs);
final prefabs = InstanceList<CustomPrefab>(_otherPrefs);
final emptyPrefab = EmptyPrefab();

final Map<Character, LIElement> _accessEntries = {};

Prefab? _selectedPrefab;
Prefab? get selectedPrefab => _selectedPrefab;
set selectedPrefab(Prefab? p) {
  if (!(user.session!.isDM)) return;

  _selectedPrefab = p;
  _palette.querySelectorAll('.prefab.selected').classes.remove('selected');
  p?.htmlRoot.classes.add('selected');

  _prefabProperties.classes.toggle('disabled', p == null);

  var isCustom = p is CustomPrefab;
  var isEmpty = p is EmptyPrefab;

  _prefabAccess.classes.toggle('disabled', !isCustom);
  _updateAccessSpan();

  if (p != null) {
    _prefabImage.classes.toggle('disabled', isEmpty);
    _prefabName.disabled = isEmpty;
    _prefabRemove.disabled = !isCustom;
    _prefabSize.disabled = isEmpty;

    _prefabImage.style.display = isEmpty ? 'none' : '';
    _prefabEmptyIcon.style.display = isEmpty ? '' : 'none';
    if (isEmpty) {
      _prefabEmptyIcon.className = 'fas fa-${emptyPrefab.iconId}';
    }

    _prefabName.value = p.name;
    _prefabSize.valueAsNumber = p.size;

    final img = p.image?.url ?? '';
    _prefabImageImg.src = img;
    _movableGhost.classes.toggle('empty', isEmpty);
    _setMovableGhostImage(img);
    _movableGhost.style.setProperty('--size', '${p.size}');
    _movableGhost.style.setProperty('--angle', '0');

    if (isCustom) {
      var children = _prefabAccess.children;
      var ids = (selectedPrefab as CustomPrefab).accessIds;
      for (var i = 0; i < children.length; i++) {
        children[i].classes.toggle('active', ids.contains(i));
      }
    }
  }
  toggleMovableGhostVisible(false);
}

bool get collapsed => _palette.classes.contains('collapsed');
set collapsed(bool collapsed) {
  _palette.classes.toggle('collapsed', collapsed);
  queryDom('#paletteCollapse > i').className =
      'fas fa-chevron-' + (collapsed ? 'down' : 'up');
}

void toggleMovableGhostVisible(bool v, {bool translucent = false}) {
  if (v == _movableGhost.isConnected) return;
  if (v) {
    user.session!.board.grid.e
        .append(_movableGhost..classes.toggle('translucent', translucent));
  } else {
    _movableGhost.remove();
  }
}

void alignMovableGhost(Point point, EntityBase entity) {
  final grid = user.session!.board.grid;
  final p = grid.centeredWorldPoint(point, entity.size);

  _movableGhost.style.setProperty('--x', '${p.x}px');
  _movableGhost.style.setProperty('--y', '${p.y}px');
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
  _movableGhost.remove();
  _initPrefabPalette();
  _initPrefabProperties();

  for (var j in jList) {
    onPrefabCreate(j);
  }
}

void _initPrefabPalette() {
  for (var pc in user.session!.characters) {
    pcPrefabs.add(pc.prefab);
  }

  _otherPrefs.parent!.nodes.insert(1, emptyPrefab.htmlRoot);

  _addPref.onLMB.listen(createPrefab);
  _palette.queryDom('#paletteCollapse').onClick.listen((_) {
    collapsed = !collapsed;
  });
}

void imitateMovableGhost(Movable m) {
  final screenPosition = m.positionScreenSpace;
  _movableGhost.style
    ..setProperty('--x', '${screenPosition.x}px')
    ..setProperty('--y', '${screenPosition.y}px')
    ..setProperty('--size', '${m.displaySize}')
    ..setProperty('--angle', '${m.angle}');

  _movableGhost.classes.toggle('empty', m is EmptyMovable);

  final img = m.prefab.image?.url;
  _setMovableGhostImage(img);
}

void _setMovableGhostImage(String? img) {
  _movableGhost.queryDom('.img').style.backgroundImage =
      img == null ? '' : 'url($img)';
}

void applyCharacterNameToAccessEntry(Character character) {
  _accessEntries[character]?.text = character.name;
}

void _initPrefabProperties() {
  registerEditImage(
    _prefabImage,
    upload: (MouseEvent ev, [Blob? initialFile]) async {
      final uploadType = (selectedPrefab is CharacterPrefab)
          ? IMAGE_TYPE_PC
          : IMAGE_TYPE_ENTITY;

      final response = await upload.display(
          event: ev,
          action: GAME_PREFAB_UPDATE,
          type: uploadType,
          initialImg: initialFile,
          extras: {
            'prefab': selectedPrefab!.id,
          });

      return response == null ? null : response['image'];
    },
    onSuccess: (newImage) {
      selectedPrefab!.image!.path = newImage;
      selectedPrefab!.applyImage();

      final src = selectedPrefab!.image!.url;
      _prefabImageImg.src = src;
      _setMovableGhostImage(src);
      user.session!.board.onUpdatePrefabImage(selectedPrefab!);
    },
  );

  _listenLazyUpdate(_prefabName, onChange: (pref, input) {
    (pref as ChangeableName).name = input.value!;
  });
  _listenLazyUpdate(_prefabSize, onChange: (pref, input) {
    pref.size = input.valueAsNumber!.toInt();
    _movableGhost.style.setProperty('--size', '${pref.size}');
  });

  for (var ch in user.session!.characters) {
    final li = LIElement();
    li.text = ch.name;
    li.onClick.listen((_) {
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
    _accessEntries[ch] = li;
  }

  _prefabRemove.onClick.listen((_) async {
    final p = selectedPrefab;
    if (p != null && p is CustomPrefab) {
      // Select preceding prefab
      var index = prefabs.indexOf(p);
      if (index == 0) {
        selectedPrefab = null;
      } else {
        selectedPrefab = prefabs[index - 1];
      }

      onPrefabRemove(p);
      await socket.sendAction(GAME_PREFAB_REMOVE, {
        'prefab': p.id,
      });
    }
  });
}

void _listenLazyUpdate(
  InputElement input, {
  required void Function(Prefab prefab, InputElement self) onChange,
}) {
  var bufferedValue = input.value;

  void update() {
    if (bufferedValue != input.value) {
      bufferedValue = input.value;
      onChange(selectedPrefab!, input);
      _sendUpdate();
    }
  }

  input.onFocus.listen((_) => bufferedValue = input.value);
  input.onChange.listen((_) => update());
}

void _sendUpdate() {
  socket.sendAction(GAME_PREFAB_UPDATE, {
    'prefab': selectedPrefab!.id,
    ...selectedPrefab!.toJson(),
  });
}

void _updateAddButton() {
  var limitReached = prefabs.length >= prefabsPerCampaign;
  _addPref.disabled = limitReached;
  _addPref.queryDom('span').text = limitReached ? 'Limit Reached' : 'Add Token';
}

void _displayLimitMsg() {
  HtmlNotification('Limit of $prefabsPerCampaign custom tokens reached.')
      .display();
}

Future<void> createPrefab(MouseEvent ev) async {
  if (prefabs.length >= prefabsPerCampaign) return _displayLimitMsg();

  var fallbackID = prefabs.getNextAvailableID((e) => e.idNum);

  var result = await upload.display(
    event: ev,
    action: GAME_PREFAB_CREATE,
    type: IMAGE_TYPE_ENTITY,
  );

  if (result == null) return null;

  CustomPrefab prefab;
  if (user.isInDemo) {
    prefab = CustomPrefab(fallbackID, Resource(result['image']));
    _postPrefabCreate(prefab);
  } else {
    prefab = onPrefabCreate(result);
  }

  selectedPrefab = prefab..applyImage();
  _prefabName.focus();
}

CustomPrefab onPrefabCreate(Map<String, dynamic> json) {
  var p = CustomPrefab(json['id'], Resource(json['image']))..fromJson(json);
  _postPrefabCreate(p);
  return p;
}

void _postPrefabCreate(CustomPrefab p) {
  prefabs.add(p);
  _updateAddButton();
}

Prefab? getPrefab(String id) {
  var allPrefabs = <Prefab>[...prefabs, ...pcPrefabs];
  return allPrefabs.find((p) => p.id == id);
}

void onPrefabUpdate(Map<String, dynamic> json) {
  final prefab = getPrefab(json['prefab'])!;

  if (json['size'] == null) {
    prefab.image!.path = json['image'];
    user.session!.board.onUpdatePrefabImage(prefab);
  } else {
    prefab.fromJson(json);
    prefab.movables.forEach((m) => m.onPrefabUpdate());
  }
}

void onPrefabRemove(CustomPrefab prefab) {
  user.session!.board.clipboard.removeWhere((m) => m.prefab == prefab);
  user.session!.board.movables.toList().forEach((m) {
    if (m.prefab == prefab) {
      user.session!.board.movables.remove(m);
    }
  });
  prefabs.remove(prefab);
  _updateAddButton();
}
