import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// A curve that is very steep in the middle, like a heartbeat pulse.
class HeartbeatCurve extends Curve {
  const HeartbeatCurve();

  @override
  double transformInternal(double t) {
    // A curve that is very steep in the middle, like a heartbeat pulse.
    // This is a modified sigmoid function.
    const k = 20.0; // Steepness factor
    final val = 1 / (1 + math.exp(-k * (t - 0.5)));
    // Normalize to 0-1 range
    final min = 1 / (1 + math.exp(k * 0.5));
    final max = 1 / (1 + math.exp(-k * 0.5));
    return (val - min) / (max - min);
  }
}
