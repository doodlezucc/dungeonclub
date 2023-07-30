import 'dart:async';
import 'dart:html';

class SmoothSlider {
  final InputElement input;
  final void Function(num value)? onSmoothChange;
  final num _min;
  final num _max;
  late Timer _timer;
  num _value = 0;

  num get goal => input.valueAsNumber!;
  set goal(num v) => input.valueAsNumber = v;

  SmoothSlider(
    this.input, {
    int stepMs = 20,
    num rangePerSecond = 0.2,
    this.onSmoothChange,
  })  : _min = num.tryParse(input.min ?? '') ?? 0,
        _max = num.tryParse(input.max ?? '') ?? 1 {
    input.classes.add('smooth-bg');
    _value = goal;
    _applyValue(_value);

    var range = stepMs * rangePerSecond / 1000;
    _timer = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
      var diff = goal - _value;

      if (diff != 0) {
        if (diff.abs() < range) {
          _applyValue(goal);
        } else {
          _applyValue(_value + range * diff.sign);
        }
      }
    });
  }

  void dispose() => _timer.cancel();

  void _applyValue(num v) {
    _value = v;
    if (onSmoothChange != null) onSmoothChange!(v);

    var clamped = (v - _min) / (_max - _min);
    input.style.setProperty('--v', '${100 * clamped}%');
  }
}
