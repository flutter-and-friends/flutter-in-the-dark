import 'package:flutter_in_the_dark/helpers/burn_knobs.dart';
import 'package:flutter_in_the_dark/widgets/burn_shader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BurnKnobs.parse', () {
    test('defaults: slow 1, no hold, no debug, shader mode', () {
      final knobs = BurnKnobs.parse('/burn_test');
      expect(knobs.slowFactor, 1);
      expect(knobs.holdAt, isNull);
      expect(knobs.debug, isFalse);
      expect(knobs.mode, BurnMode.shader);
    });

    test('parses slow + hold + debug + mode from a route query string', () {
      final knobs = BurnKnobs.parse(
        '/burn_test?burnSlow=5&burnHold=0.42&burnDebug=1&burnMode=mask',
      );
      expect(knobs.slowFactor, 5);
      expect(knobs.holdAt, closeTo(0.42, 1e-9));
      expect(knobs.debug, isTrue);
      expect(knobs.mode, BurnMode.mask);
    });

    test('accepts a bare ?query (window.location.search shape)', () {
      // Production passes window.location.search, which starts with '?'.
      final knobs = BurnKnobs.parse('?burnSlow=3&burnDebug=1');
      expect(knobs.slowFactor, 3);
      expect(knobs.debug, isTrue);
    });

    test('invalid slow falls back to 1; hold clamps to 0..1', () {
      expect(BurnKnobs.parse('/x?burnSlow=0').slowFactor, 1);
      expect(BurnKnobs.parse('/x?burnSlow=-3').slowFactor, 1);
      expect(BurnKnobs.parse('/x?burnSlow=abc').slowFactor, 1);
      expect(BurnKnobs.parse('/x?burnHold=2').holdAt, 1.0);
      expect(BurnKnobs.parse('/x?burnHold=-1').holdAt, 0.0);
    });

    test('burnDebug only on the exact "1" value', () {
      expect(BurnKnobs.parse('/x?burnDebug=0').debug, isFalse);
      expect(BurnKnobs.parse('/x?burnDebug=true').debug, isFalse);
      expect(BurnKnobs.parse('/x?burnDebug=1').debug, isTrue);
    });

    test('no query string is fine', () {
      expect(BurnKnobs.parse(null).slowFactor, 1);
      expect(BurnKnobs.parse('').slowFactor, 1);
    });

    test('burnSeconds defaults to null (anchored at the wall-clock end)', () {
      expect(BurnKnobs.parse('/x').burnSeconds, isNull);
    });

    test('burnSeconds parses a positive value; invalid values fall back', () {
      expect(BurnKnobs.parse('/x?burnSeconds=15').burnSeconds, 15);
      expect(BurnKnobs.parse('/x?burnSeconds=2.5').burnSeconds, 2.5);
      expect(BurnKnobs.parse('/x?burnSeconds=0').burnSeconds, isNull);
      expect(BurnKnobs.parse('/x?burnSeconds=-3').burnSeconds, isNull);
      expect(BurnKnobs.parse('/x?burnSeconds=abc').burnSeconds, isNull);
    });
  });

  group('burnTextOpacity', () {
    test('fully visible before the fade starts', () {
      expect(burnTextOpacity(0), 1);
      expect(
        burnTextOpacity(BurnShaderOverlay.textFadeStart),
        1,
      );
    });

    test('fully transparent by the fade end, and stays there', () {
      expect(burnTextOpacity(BurnShaderOverlay.textFadeEnd), 0);
      expect(burnTextOpacity(0.5), 0);
      expect(burnTextOpacity(1), 0);
    });

    test('linear in between', () {
      const start = BurnShaderOverlay.textFadeStart;
      const end = BurnShaderOverlay.textFadeEnd;
      const mid = (start + end) / 2;
      expect(burnTextOpacity(mid), closeTo(0.5, 1e-9));
    });
  });
}
