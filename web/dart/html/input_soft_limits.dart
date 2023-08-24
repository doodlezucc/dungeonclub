import 'dart:html';

const _softLimitCooldownMs = 500;

extension InputLimiter on InputElement {
  void registerSoftLimits({
    required double Function() getMin,
    required double Function() getMax,
  }) {
    int lastInput = 0;
    num? previousValue = valueAsNumber;

    void onStepChange(Event event, num previous, num value, int now) {
      final min = getMin();
      final max = getMax();

      final crossingLowerBound = previous >= min && value < min;
      final crossingUpperBound = previous <= max && value > max;

      if (crossingLowerBound || crossingUpperBound) {
        final msSinceInput = now - lastInput;

        if (msSinceInput < _softLimitCooldownMs) {
          // Constrain range
          event.preventDefault();

          if (crossingLowerBound) {
            valueAsNumber = value = min;
          } else if (crossingUpperBound) {
            valueAsNumber = value = max;
          }
        }
      }
    }

    onInput.listen((event) {
      final value = valueAsNumber;
      final previous = previousValue;

      final now = DateTime.now().millisecondsSinceEpoch;

      if (value != null && previous != null) {
        final diff = (value - previous).abs();

        if (diff == 1.0) {
          onStepChange(event, previous, value, now);
        }
      }

      lastInput = now;
      previousValue = valueAsNumber;
    });
  }
}
