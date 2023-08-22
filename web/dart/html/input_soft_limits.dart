import 'dart:html';

extension InputLimiter on InputElement {
  void registerSoftLimits({
    required double Function() getMin,
    required double Function() getMax,
  }) {
    bool constrainRange = false;
    DateTime? lastInput;

    onMouseWheel.listen((event) {
      final value = valueAsNumber;

      if (value == null || (value >= getMin() && value <= getMax())) {
        constrainRange = true;

        if (lastInput != null) {
          final timeSinceInput = DateTime.now().difference(lastInput!);

          if (timeSinceInput.inMilliseconds > 500) {
            constrainRange = false;
          }
        }
      }
    });

    onInput.listen((event) {
      lastInput = DateTime.now();

      if (constrainRange) {
        final value = valueAsNumber;
        final min = getMin();
        final max = getMax();

        if (value != null) {
          if (value < min || value > max) {
            event.preventDefault();
            lastInput = DateTime.now();

            if (value < min) {
              valueAsNumber = min;
            } else if (value > max) {
              valueAsNumber = max;
            }
          }
        }

        constrainRange = false;
      }
    });
  }
}
