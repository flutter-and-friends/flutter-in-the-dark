import 'dart:math' as math;

import 'package:flutter_in_the_dark/helpers/burn_edge.dart';
import 'package:flutter_in_the_dark/helpers/burn_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isBurning / burnProgress', () {
    test('not burning before the burn window', () {
      expect(isBurning(10), isFalse);
      expect(isBurning(1.5), isFalse);
      expect(isBurning(kBurnSeconds + 0.001), isFalse);
    });

    test('burning inside the window', () {
      expect(isBurning(kBurnSeconds), isTrue);
      expect(isBurning(0.5), isTrue);
      expect(isBurning(0.001), isTrue);
    });

    test('not burning at/after zero — the overlay is simply gone', () {
      expect(isBurning(0), isFalse);
      expect(isBurning(-0.5), isFalse);
    });

    test('progress runs 0 → 1 across the window', () {
      expect(burnProgress(kBurnSeconds), 0.0);
      expect(burnProgress(kBurnSeconds / 2), closeTo(0.5, 1e-9));
      // At (and past) zero the caller drops the overlay entirely; progress
      // clamps at 1.
      expect(burnProgress(0), 1.0);
      expect(burnProgress(-1), 1.0);
    });

    test('progress clamps out-of-range inputs', () {
      expect(burnProgress(2 * kBurnSeconds), 0.0);
    });
  });

  group('burnWindowFor', () {
    test('a full 10 s countdown gets the full ~1 s burn', () {
      expect(burnWindowFor(10), const Duration(seconds: 1));
      expect(burnWindowFor(30), const Duration(seconds: 1));
    });

    test('a sub-second countdown shortens the burn to fit', () {
      // Admin started the challenge with < 1 s of delay, or the client first
      // painted mid-burn-window: the transition must never outlast the
      // countdown itself.
      expect(burnWindowFor(0.5), const Duration(milliseconds: 500));
      expect(burnWindowFor(0.1), const Duration(milliseconds: 100));
    });
  });

  group('sampleBurn', () {
    test('starts closed: no hole, no rim', () {
      final s = sampleBurn(0);
      expect(s.holeRadius, 0.0);
      expect(s.charRadius, greaterThanOrEqualTo(s.holeRadius));
      expect(s.rimAlpha, 0.0);
    });

    test('hole reaches the corner exactly at p = 1', () {
      // Radii are fractions of the center-to-corner distance, so 1.0 means
      // the burn has consumed the whole frame.
      expect(sampleBurn(1).holeRadius, 1.0);
    });

    test('monotonic hole growth', () {
      var previous = -1.0;
      for (var i = 0; i <= 20; i++) {
        final hole = sampleBurn(i / 20).holeRadius;
        expect(hole, greaterThan(previous));
        previous = hole;
      }
    });

    test('rim fades in fast then out by the end', () {
      expect(sampleBurn(0.15).rimAlpha, 1.0);
      expect(sampleBurn(0.5).rimAlpha, 1.0);
      expect(sampleBurn(0.75).rimAlpha, 1.0);
      expect(sampleBurn(1).rimAlpha, 0.0);
      // Ignition: the rim is visible almost immediately.
      expect(sampleBurn(0.075).rimAlpha, closeTo(0.5, 1e-9));
    });

    test('flame rides outside char, char outside hole', () {
      for (var i = 1; i < 20; i++) {
        final s = sampleBurn(i / 20);
        expect(s.charRadius, greaterThan(s.holeRadius));
        expect(s.flameRadius, greaterThan(s.charRadius));
      }
    });

    test('out-of-range progress clamps', () {
      expect(sampleBurn(-0.5).holeRadius, sampleBurn(0).holeRadius);
      expect(sampleBurn(1.5).holeRadius, sampleBurn(1).holeRadius);
    });
  });

  group('sampleBurnAt — the jagged, per-angle form', () {
    test('with a constant scale of 1 it reduces to sampleBurn', () {
      for (var i = 0; i <= 10; i++) {
        final p = i / 10;
        final base = sampleBurn(p);
        final at = sampleBurnAt(p, 1.23, (_) => 1.0);
        expect(at.holeRadius, closeTo(base.holeRadius, 1e-9));
        expect(at.charRadius, closeTo(base.charRadius, 1e-9));
        expect(at.flameRadius, closeTo(base.flameRadius, 1e-9));
        expect(at.rimAlpha, base.rimAlpha);
      }
    });

    test('theta is forwarded to the scale function', () {
      final at = sampleBurnAt(
          0.5, math.pi / 2, (theta) => theta == math.pi / 2 ? 1.2 : 1.0);
      expect(at.holeRadius, closeTo(sampleBurn(0.5).holeRadius * 1.2, 1e-9));
    });

    test('the char and flame bands keep their width at inward spikes', () {
      // Where the edge dips inward (scale 0.65) the bands must not
      // collapse: widths are ADDED after scaling, so hole < char < flame
      // holds at every angle and progress.
      final edge = BurnEdge(seed: 11);
      for (var i = 1; i < 20; i++) {
        final p = i / 20;
        for (var j = 0; j < 16; j++) {
          final at = sampleBurnAt(p, 2 * math.pi * j / 16, edge.radiusScaleAt);
          expect(at.charRadius, greaterThan(at.holeRadius));
          expect(at.flameRadius, greaterThan(at.charRadius));
        }
      }
    });

    test('the hole radius wobbles with angle — the edge is jagged', () {
      final edge = BurnEdge(seed: 2);
      var min = double.infinity;
      var max = double.negativeInfinity;
      for (var j = 0; j < 64; j++) {
        final r = sampleBurnAt(0.6, 2 * math.pi * j / 64, edge.radiusScaleAt)
            .holeRadius;
        min = math.min(min, r);
        max = math.max(max, r);
      }
      expect(max - min, greaterThan(0.05));
    });

    test('rimAlpha is angularly uniform', () {
      final edge = BurnEdge(seed: 4);
      for (var j = 0; j < 8; j++) {
        expect(
          sampleBurnAt(0.5, 2 * math.pi * j / 8, edge.radiusScaleAt).rimAlpha,
          sampleBurn(0.5).rimAlpha,
        );
      }
    });
  });

  group('normalizedCorner', () {
    test('is the identity — pins the radius normalization convention', () {
      expect(normalizedCorner(123.4), 123.4);
    });
  });
}
