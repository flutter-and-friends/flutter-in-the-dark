/// Pure jagged burn-edge geometry — deliberately kept free of Flutter
/// imports so it is unit-testable on the Dart VM (same W-012 discipline as
/// `burn_phase.dart`: the widgets that consume this import
/// `compiled_widget.dart` → `dart:js_interop` and cannot be widget-tested).
/// Used by `lib/widgets/burn_effects.dart`.
///
/// The burn's hole/char/flame radii were perfect circles (radial
/// `ui.Gradient`s). A real paper burn has an irregular edge: the radius
/// varies with ANGLE. [BurnEdge] is a smooth, periodic angular noise —
/// `radiusScaleAt(theta)` ∈ roughly [1 − variation, 1 + variation] —
/// seeded per burn so every run's silhouette differs but stays STABLE for
/// the burn's duration (the shape scales outward with progress; it never
/// shimmers frame-to-frame).
library;

import 'dart:math' as math;

/// A point on the jagged burn contour at polar angle [theta]: [radius] is
/// the perturbed radius in the caller's units (typically logical pixels),
/// [x]/[y] its offset from the burn center.
typedef BurnEdgePoint = ({double theta, double radius, double x, double y});

/// Seeded angular noise for the burn edge.
///
/// Mechanism: a sum of sinusoids with INTEGER frequencies (3, 5, 8 — low
/// enough to read as wavy paper, not static), each with a seed-derived
/// phase and amplitude. Integer frequencies make the sum exactly periodic
/// at 2π, so the contour closes with no seam or spike at theta = 0.
/// Amplitudes are normalized so their sum is 1 and then scaled by
/// [variation]; the result is clamped to [minScale]..[maxScale] as a hard
/// guarantee (the sinusoids cannot actually exceed the bounds, but the
/// clamp pins the contract for tests and future tweaks).
class BurnEdge {
  BurnEdge({required this.seed, this.variation = kDefaultVariation}) {
    final random = math.Random(seed);
    for (var i = 0; i < _frequencies.length; i++) {
      _phases.add(random.nextDouble() * 2 * math.pi);
      _amplitudes.add(1.0 - i * 0.25); // lower frequencies dominate
    }
    final total = _amplitudes.fold<double>(0, (a, b) => a + b);
    for (var i = 0; i < _amplitudes.length; i++) {
      _amplitudes[i] /= total;
    }
  }

  /// Per-run seed: every value produces a distinct, deterministic shape.
  final int seed;

  /// Peak radial deviation as a fraction of the base radius (0.28 = the
  /// perturbed radius wanders within roughly ±28 % of the base radius).
  final double variation;

  /// Default edge roughness.
  static const double kDefaultVariation = 0.28;

  /// Hard bounds for [radiusScaleAt].
  static const double minScale = 0.65;
  static const double maxScale = 1.35;

  /// Number of sample points [contour]/[contourPoints] produce.
  static const int kContourSamples = 96;

  static const List<int> _frequencies = [3, 5, 8];

  final List<double> _phases = [];
  final List<double> _amplitudes = [];

  /// The radial multiplier at polar angle [theta] (radians). Smooth,
  /// periodic (`radiusScaleAt(0) == radiusScaleAt(2π)` exactly), bounded to
  /// [minScale]..[maxScale], and identical for identical (seed, theta).
  double radiusScaleAt(double theta) {
    var sum = 0.0;
    for (var i = 0; i < _frequencies.length; i++) {
      sum += _amplitudes[i] * math.sin(_frequencies[i] * theta + _phases[i]);
    }
    return (1.0 + variation * sum).clamp(minScale, maxScale);
  }

  /// The perturbed radius at [theta] for a base radius of [baseRadius].
  double radiusAt(double theta, double baseRadius) =>
      baseRadius * radiusScaleAt(theta);

  /// Samples the jagged contour of the hole at burn progress [p] (clamped
  /// to [0, 1]) — [samples] points around the full circle, offsets
  /// relative to the burn center. Connecting them (and closing) gives the
  /// hole boundary. Kept free of a `burn_phase.dart` import so the edge
  /// noise is testable in isolation; the phase math is just the clamped
  /// cubic hole curve, duplicated here intentionally.
  List<BurnEdgePoint> contour(
    double p, {
    required double halfDiagonal,
    int samples = kContourSamples,
  }) {
    final t = p.clamp(0.0, 1.0);
    return contourPoints(t * t * t * halfDiagonal, samples: samples);
  }

  /// Samples the jagged contour of a circle of [baseRadius] (caller's
  /// units) — the shared primitive behind [contour], also used directly by
  /// the renderer for the char and flame bands (same shape, larger base).
  List<BurnEdgePoint> contourPoints(
    double baseRadius, {
    int samples = kContourSamples,
  }) {
    return List.generate(samples, (i) {
      final theta = 2 * math.pi * i / samples;
      final radius = radiusAt(theta, baseRadius);
      return (
        theta: theta,
        radius: radius,
        x: radius * math.cos(theta),
        y: radius * math.sin(theta),
      );
    });
  }
}
