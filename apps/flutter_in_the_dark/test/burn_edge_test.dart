import 'dart:math' as math;

import 'package:flutter_in_the_dark/helpers/burn_edge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BurnEdge.radiusScaleAt', () {
    test('is periodic at 2π — the contour closes with no seam', () {
      for (final seed in [0, 1, 7, 12345, 1 << 30]) {
        final edge = BurnEdge(seed: seed);
        expect(
          edge.radiusScaleAt(0),
          closeTo(edge.radiusScaleAt(2 * math.pi), 1e-9),
          reason: 'seed $seed',
        );
        // And smoothly so: points straddling the wrap are close.
        expect(
          edge.radiusScaleAt(-0.01),
          closeTo(edge.radiusScaleAt(2 * math.pi - 0.01), 1e-9),
          reason: 'seed $seed wrap continuity',
        );
      }
    });

    test('is bounded to [minScale, maxScale] for any seed/angle', () {
      for (final seed in [0, 3, 42, 999, 1 << 31 - 1]) {
        final edge = BurnEdge(seed: seed);
        for (var i = 0; i < 720; i++) {
          final scale = edge.radiusScaleAt(2 * math.pi * i / 720);
          expect(scale, greaterThanOrEqualTo(BurnEdge.minScale));
          expect(scale, lessThanOrEqualTo(BurnEdge.maxScale));
        }
      }
    });

    test('actually varies — the edge is not a circle', () {
      final edge = BurnEdge(seed: 42);
      var min = double.infinity;
      var max = double.negativeInfinity;
      for (var i = 0; i < 360; i++) {
        final scale = edge.radiusScaleAt(2 * math.pi * i / 360);
        min = math.min(min, scale);
        max = math.max(max, scale);
      }
      // With variation 0.28 the wobble should visibly deviate from 1.
      expect(max - min, greaterThan(0.2));
    });

    test('is deterministic per seed — stable within a single burn', () {
      final a = BurnEdge(seed: 1234);
      final b = BurnEdge(seed: 1234);
      for (var i = 0; i < 64; i++) {
        final theta = 2 * math.pi * i / 64;
        expect(a.radiusScaleAt(theta), b.radiusScaleAt(theta));
      }
    });

    test('different seeds give different silhouettes', () {
      // A generous sample of seeds must not all agree at any angle.
      final edges = [
        for (var seed = 0; seed < 8; seed++) BurnEdge(seed: seed),
      ];
      var sawDifference = false;
      for (var i = 0; i < 64 && !sawDifference; i++) {
        final theta = 2 * math.pi * i / 64;
        final first = edges.first.radiusScaleAt(theta);
        if (edges.any((e) => (e.radiusScaleAt(theta) - first).abs() > 1e-6)) {
          sawDifference = true;
        }
      }
      expect(sawDifference, isTrue);
    });

    test('is smooth — no frame-to-frame spikes between adjacent angles', () {
      final edge = BurnEdge(seed: 7);
      var previous = edge.radiusScaleAt(0);
      for (var i = 1; i <= 720; i++) {
        final scale = edge.radiusScaleAt(2 * math.pi * i / 720);
        // Frequencies ≤ 8 with total amplitude ≤ variation: the per-degree
        // delta is bounded well under 0.05.
        expect((scale - previous).abs(), lessThan(0.05));
        previous = scale;
      }
    });

    test('honours a custom variation', () {
      final tame = BurnEdge(seed: 5, variation: 0.05);
      for (var i = 0; i < 360; i++) {
        final scale = tame.radiusScaleAt(2 * math.pi * i / 360);
        expect(scale, greaterThanOrEqualTo(0.95 - 1e-9));
        expect(scale, lessThanOrEqualTo(1.05 + 1e-9));
      }
    });
  });

  group('BurnEdge.contourPoints', () {
    test('returns the requested number of closed-contour samples', () {
      final edge = BurnEdge(seed: 1);
      final points = edge.contourPoints(100, samples: 32);
      expect(points, hasLength(32));
      // Spans the full circle (last sample is one step short of 2π; the
      // caller closes the path back to the first point).
      expect(points.first.theta, 0);
      expect(points.last.theta, closeTo(2 * math.pi * 31 / 32, 1e-9));
    });

    test('radii match radiusScaleAt, offsets match polar conversion', () {
      final edge = BurnEdge(seed: 9);
      const base = 250.0;
      for (final point in edge.contourPoints(base, samples: 16)) {
        expect(
          point.radius,
          closeTo(base * edge.radiusScaleAt(point.theta), 1e-9),
        );
        expect(
          point.x,
          closeTo(point.radius * math.cos(point.theta), 1e-9),
        );
        expect(
          point.y,
          closeTo(point.radius * math.sin(point.theta), 1e-9),
        );
      }
    });
  });

  group('BurnEdge.contour', () {
    test('at p = 1 the hole reaches every corner despite the wobble', () {
      // The overlay is dropped at p = 1, but the geometry contract is that
      // the perturbed hole radius (fractions of the half-diagonal) has
      // grown past the corner at every angle — minScale keeps dips shy of
      // the full corner, which is exactly why the caller cuts away at 1.
      final edge = BurnEdge(seed: 3);
      final points = edge.contour(0.999, halfDiagonal: 400);
      for (final point in points) {
        expect(point.radius, greaterThan(0.9 * 400 * BurnEdge.minScale));
      }
    });

    test('is stable for a fixed seed across calls (no shimmer)', () {
      final edge = BurnEdge(seed: 77);
      final a = edge.contour(0.5, halfDiagonal: 300);
      final b = edge.contour(0.5, halfDiagonal: 300);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].radius, b[i].radius);
      }
    });
  });
}
