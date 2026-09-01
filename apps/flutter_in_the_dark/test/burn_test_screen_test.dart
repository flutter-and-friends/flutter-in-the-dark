import 'package:flutter_in_the_dark/helpers/burn_phase.dart';
import 'package:flutter_in_the_dark/screens/burn_test_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const burn = Duration(seconds: 1);

  group('BurnTestKnobs.parse', () {
    test('defaults: slow 1, no hold', () {
      final knobs = BurnTestKnobs.parse('/burn_test');
      expect(knobs.slowFactor, 1);
      expect(knobs.holdAt, isNull);
    });

    test('parses slow + hold from the query string', () {
      final knobs = BurnTestKnobs.parse('/burn_test?burnSlow=5&burnHold=0.42');
      expect(knobs.slowFactor, 5);
      expect(knobs.holdAt, closeTo(0.42, 1e-9));
    });

    test('invalid slow falls back to 1; hold clamps to 0..1', () {
      expect(BurnTestKnobs.parse('/burn_test?burnSlow=0').slowFactor, 1);
      expect(BurnTestKnobs.parse('/burn_test?burnSlow=-3').slowFactor, 1);
      expect(BurnTestKnobs.parse('/burn_test?burnSlow=abc').slowFactor, 1);
      expect(BurnTestKnobs.parse('/burn_test?burnHold=2').holdAt, 1.0);
      expect(BurnTestKnobs.parse('/burn_test?burnHold=-1').holdAt, 0.0);
    });

    test('mockShow: absent by default, parses signed seconds', () {
      expect(BurnTestKnobs.parse('/burn_test').mockShow, isNull);
      expect(
        BurnTestKnobs.parse('/burn_test?mockShow=272').mockShow,
        closeTo(272, 1e-9),
      );
      expect(
        BurnTestKnobs.parse('/burn_test?mockShow=-2').mockShow,
        closeTo(-2, 1e-9),
      );
      expect(BurnTestKnobs.parse('/burn_test?mockShow=abc').mockShow, isNull);
    });

    test('no query string is fine', () {
      expect(BurnTestKnobs.parse(null).slowFactor, 1);
    });
  });

  group('loopPhaseAt / loopProgressAt', () {
    test('burns during the burn window, holds for holdDuration, wraps', () {
      expect(loopPhaseAt(Duration.zero, burn), BurnLoopPhase.burning);
      expect(
        loopPhaseAt(const Duration(milliseconds: 999), burn),
        BurnLoopPhase.burning,
      );
      expect(loopPhaseAt(burn, burn), BurnLoopPhase.holding);
      expect(
        loopPhaseAt(
          burn + holdDuration - const Duration(milliseconds: 1),
          burn,
        ),
        BurnLoopPhase.holding,
      );
      // One full cycle wraps back to burning.
      expect(loopPhaseAt(burn + holdDuration, burn), BurnLoopPhase.burning);
    });

    test('progress runs 0 → 1 across the burn, then parks at 1', () {
      expect(loopProgressAt(Duration.zero, burn), 0.0);
      expect(
        loopProgressAt(const Duration(milliseconds: 500), burn),
        closeTo(0.5, 1e-9),
      );
      expect(loopProgressAt(burn, burn), 1.0);
      expect(loopProgressAt(burn + const Duration(seconds: 1), burn), 1.0);
      // Wrapped into the next cycle's burn.
      expect(
        loopProgressAt(
          burn + holdDuration + const Duration(milliseconds: 500),
          burn,
        ),
        closeTo(0.5, 1e-9),
      );
    });

    test('a slowed burn stretches the window but not the hold', () {
      final slowBurn = Duration(
        microseconds: (kBurnSeconds * 1000000 * 5).round(),
      );
      expect(
        loopProgressAt(const Duration(seconds: 2), slowBurn),
        closeTo(0.4, 1e-9),
      );
      expect(
        loopPhaseAt(slowBurn + holdDuration, slowBurn),
        BurnLoopPhase.burning,
      );
    });
  });
}
