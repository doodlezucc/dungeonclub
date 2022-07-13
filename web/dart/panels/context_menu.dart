import 'dart:async';
import 'dart:html';

import '../../main.dart';
import '../font_awesome.dart';

final _e = querySelector('#contextMenu');

class ContextMenu {
  ContextMenu() {
    _e.children.clear();
  }

  int addButton(String label, String icon, [String className]) {
    _e.append(iconButton(icon, label: label, className: className));
    return _e.children.length - 1;
  }

  bool _prefer(EventTarget e) {
    return e is ButtonElement ||
        (e is Element && e.classes.contains('with-tooltip'));
  }

  Future<int> display(MouseEvent event, [Element hovered]) async {
    hovered ??= event.path.firstWhere(_prefer, orElse: () => event.target);
    var p = event.page;

    var normalPos = true;
    var bottom = window.innerHeight - p.y;
    if (bottom > 120) {
      _e.style
        ..top = '${p.y - 12}px'
        ..bottom = 'auto';
    } else {
      normalPos = false;
      _e.style
        ..bottom = '12px'
        ..top = 'auto';
    }

    var right = window.innerWidth - p.x;
    if (right > 180) {
      _e.style
        ..left = '${p.x}px'
        ..right = 'auto';
    } else {
      normalPos = false;
      _e.style
        ..right = '12px'
        ..left = 'auto';
    }

    _e.classes.add('show');
    hovered.classes.add('hovered');

    var ev = await Future.any(isMobile
        ? [window.onTouchStart.first]
        : [
            _e.onMouseLeave.first,
            _e.onMouseUp
                .where((event) => event.target != _e)
                .elementAt(normalPos ? 0 : 1),
          ]);

    _e.classes.remove('show');
    hovered.classes.remove('hovered');

    if (!isMobile && ev.type == 'mouseleave') return null;

    for (var i = 0; i < _e.children.length; i++) {
      if (ev.path.contains(_e.children[i])) {
        return i;
      }
    }

    return null;
  }
}
