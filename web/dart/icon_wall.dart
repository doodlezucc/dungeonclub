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
  'book-medical',
  'hand-holding-medical',
  'heart',
  'ghost',
  'dice-d20',
  'dungeon',
  'horse',
  'broom',
  'dove',
  'beer',
  'star',
  'map-marker-alt',
  'cross',
  'bolt',
  'scroll',
  'ring',
  'shield-alt',
  'khanda',
  'fist-raised',
  'landmark',
  'Bd-and-d',
  'Bwizards-of-the-coast',
  'Bcritical-role',
];

class IconWall {
  final HtmlElement container;
  final Random random;
  bool _hasStopped = false;

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

    var id = icons[random.nextInt(icons.length)];
    var isBrand = id.startsWith('B');

    var ico = icon(isBrand ? id.substring(1) : id, isBrand: isBrand)
      ..style.left = '${random.nextDouble() * 140 - 20}%'
      ..style.top = '${random.nextDouble() * 140 - 20}%';

    if (random.nextDouble() <= 0.2) {
      ico.style.color = 'var(--color-not-intense)';
    }
    container.append(ico);

    await Future.delayed(Duration(milliseconds: 100));

    ico
      ..style.left = 'calc(${ico.style.left} + ${velocity.x}px)'
      ..style.top = 'calc(${ico.style.top} + ${velocity.y}px)';

    await Future.delayed(Duration(
      milliseconds: 5000 + random.nextInt(8000),
    ));

    if (!_hasStopped) createParticle();

    ico.classes.add('remove');
    await Future.delayed(Duration(seconds: 10));
    ico.remove();
  }
}
