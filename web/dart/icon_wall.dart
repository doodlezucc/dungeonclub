import 'dart:html';
import 'dart:math';

import 'font_awesome.dart';

const icons = [
  'hat-wizard',
  'magic',
  'hand-sparkles',
  'dragon',
  'bong',
  'fire-alt',
  'atlas',
  'book',
  'book-medical',
  'hand-holding-medical',
  'hand-holding-heart',
  'drafting-compass',
  'gem',
  'feather-alt',
  'hamsa',
  'ghost',
  'dice-d20',
  'dungeon',
  'horse',
  'broom',
  'dove',
  'beer',
  'star',
  'map-marked-alt',
  'map-signs',
  'sun',
  'theater-masks',
  'cloud',
  'place-of-worship',
  'handshake',
  'cross',
  'bolt',
  'scroll',
  'ring',
  'shield-alt',
  'khanda',
  'fist-raised',
  'landmark',
  // 'Bd-and-d',
  // 'Bwizards-of-the-coast',
  // 'Bcritical-role',
];

class IconWall {
  final HtmlElement container;
  final Random random;
  bool _hasStopped = false;
  int _iconIndex = 0;

  IconWall(this.container) : random = Random();

  void stop() {
    _hasStopped = true;
  }

  void spawnParticles() async {
    var count = window.innerWidth / 30;
    for (var i = 0; i < count; i++) {
      createParticle();
      await Future.delayed(Duration(milliseconds: 50));
    }
  }

  void createParticle() async {
    var velocity =
        Point(cos(random.nextDouble() * pi), cos(random.nextDouble() * pi)) *
            300;

    var id = icons[_iconIndex];
    _iconIndex = (_iconIndex + 1) % icons.length;
    var isBrand = id.startsWith('B');

    var ico = DivElement()
      ..append(icon(isBrand ? id.substring(1) : id, isBrand: isBrand))
      ..style.left = '${random.nextDouble() * 140 - 20}%'
      ..style.top = '${random.nextDouble() * 140 - 20}%'
      ..style.fontSize = '${random.nextInt(20) + 30}px';

    if (random.nextDouble() <= 0.2) {
      ico.style.color = 'var(--color-not-intense)';
    }
    container.append(ico);

    await Future.delayed(Duration(milliseconds: 100));

    ico.style.transform = 'translate(${velocity.x}px, ${velocity.y}px)';

    await Future.delayed(Duration(
      milliseconds: 5000 + random.nextInt(8000),
    ));

    if (!_hasStopped) createParticle();

    ico.classes.add('remove');
    await Future.delayed(Duration(seconds: 10));
    ico.remove();
  }
}
