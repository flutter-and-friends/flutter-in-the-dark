import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// A curve that is very steep in the middle, like a heartbeat pulse,
/// with a slight overshoot, similar to [Curves.easeInOutBack].
class HeartbeatCurve extends Curve {
  const HeartbeatCurve();

  @override
  double transformInternal(double t) {
    // We want the "heartbeat" feel (fast in the middle) and an overshoot.
    // To achieve this while keeping the overshoot independent of the "speed",
    // we can compose the timing.

    // 1. Use an easeInOut curve to make the animation fast in the middle.
    // This transforms `t` so that it changes slowly at the beginning and end,
    // and quickly in the middle.
    final fastMiddleT = Curves.easeInOut.transform(t);

    // 2. Use the standard Curves.easeInOutBack logic on the transformed `t`.
    // This adds the overshoot effect without changing the timing.
    const c1 = 1.70158;
    const c2 = c1 * 1.525; // Standard multiplier for easeInOutBack

    return fastMiddleT < 0.5
        ? (math.pow(2 * fastMiddleT, 2) * ((c2 + 1) * 2 * fastMiddleT - c2)) / 2
        : (math.pow(2 * fastMiddleT - 2, 2) *
                      ((c2 + 1) * (fastMiddleT * 2 - 2) + c2) +
                  2) /
              2;
  }
}
