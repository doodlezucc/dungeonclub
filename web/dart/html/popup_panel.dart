import 'component.dart';

class PopupPanel extends Component {
  bool _visible = false;
  bool get visible => _visible;
  set visible(bool visible) {
    _visible = visible;
    htmlRoot.classes.toggle('show', visible);

    if (visible) {
      htmlRoot.onMouseLeave.first.then((_) => this.visible = false);
    }
  }

  PopupPanel(String rootSelector) : super(rootSelector) {
    visible = false;
  }
}
