import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/widgets/glitch_title.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  Random? random,
  List<String> texts = kGlitchTitleTexts,
  Duration baseDwell = const Duration(seconds: 5),
  Duration dwellJitter = Duration.zero,
  Duration glitchDuration = const Duration(milliseconds: 700),
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: Center(
        child: GlitchTitle(
          texts: texts,
          random: random,
          baseDwell: baseDwell,
          dwellJitter: dwellJitter,
          glitchDuration: glitchDuration,
        ),
      ),
    ),
  );
}

String _settledText(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).data!;

/// One full cycle: dwell in 1 s steps, then the 700 ms transition in 100 ms
/// steps. Small steps only (I-017) — one big pump would let the whole
/// transition complete inside a single frame, hiding the intermediate
/// glitch states the tests assert on.
Future<void> _pumpCycle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  for (var i = 0; i < 7; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('scrambleGlitchText (pure)', () {
    test('intensity 0 returns the base untouched', () {
      expect(
        scrambleGlitchText('FLUTTER IN THE DARK', intensity: 0, tick: 3),
        'FLUTTER IN THE DARK',
      );
    });

    test(
      'intensity 1 scrambles every non-space character, preserving length',
      () {
        const base = 'FLUTTER IN THE DARK';
        final out = scrambleGlitchText(base, intensity: 1, tick: 0);
        expect(out.length, base.length);
        for (var i = 0; i < base.length; i++) {
          if (base[i] == ' ') {
            expect(out[i], ' ');
          } else {
            expect(kGlitchGlyphs.contains(out[i]), isTrue);
          }
        }
      },
    );

    test('deterministic for the same tick, re-rolls on a new tick', () {
      const base = 'PROMPTING IN THE DARK';
      final a = scrambleGlitchText(base, intensity: 0.8, tick: 5);
      final b = scrambleGlitchText(base, intensity: 0.8, tick: 5);
      final c = scrambleGlitchText(base, intensity: 0.8, tick: 6);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('pickNextGlitchIndex (pure)', () {
    test('never returns the current index and stays in range', () {
      final random = Random(11);
      for (var current = 0; current < 3; current++) {
        for (var i = 0; i < 200; i++) {
          final next = pickNextGlitchIndex(current, 3, random);
          expect(next, isNot(current));
          expect(next, inInclusiveRange(0, 2));
        }
      }
    });

    test('covers every candidate eventually', () {
      final random = Random(3);
      final seen = <int>{};
      for (var i = 0; i < 100; i++) {
        seen.add(pickNextGlitchIndex(0, 3, random));
      }
      expect(seen, {1, 2});
    });

    test('single-text list always stays on index 0', () {
      expect(pickNextGlitchIndex(0, 1, Random(1)), 0);
    });
  });

  group('GlitchTitle', () {
    testWidgets('settles on the first text at build', (tester) async {
      await tester.pumpWidget(_harness(random: Random(1)));
      expect(find.text('FLUTTER IN THE DARK'), findsOneWidget);
      // At rest there are no RGB-split layers — just the one Text.
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('dwell + transition advance under fake-async', (tester) async {
      await tester.pumpWidget(_harness(random: Random(7)));

      // Before the dwell elapses: unchanged.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('FLUTTER IN THE DARK'), findsOneWidget);

      // The dwell fires at 5 s; walk the transition in 100 ms steps.
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final settled = _settledText(tester);
      expect(settled, isNot('FLUTTER IN THE DARK'));
      expect(kGlitchTitleTexts, contains(settled));
      // Settled again — back to a single Text layer.
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('mid-glitch shows scrambled text on split layers', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(random: Random(7)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      // Exactly the midpoint: full scramble intensity.
      await tester.pump(const Duration(milliseconds: 350));
      final layers = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(layers, hasLength(3)); // RGB split + primary
      for (final data in layers) {
        expect(kGlitchTitleTexts.contains(data), isFalse);
      }
      // Decode back down to a clean, settled text.
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(Text), findsOneWidget);
      expect(kGlitchTitleTexts, contains(_settledText(tester)));
    });

    testWidgets('cycles through all three texts with a seeded random', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(random: Random(3)));
      final seen = <String>{_settledText(tester)};
      for (var cycle = 0; cycle < 8; cycle++) {
        await _pumpCycle(tester);
        seen.add(_settledText(tester));
      }
      expect(seen, containsAll(kGlitchTitleTexts));
    });

    testWidgets('two different seeds produce different sequences', (
      tester,
    ) async {
      Future<List<String>> sequence(int seed) async {
        await tester.pumpWidget(_harness(random: Random(seed)));
        final seq = <String>[_settledText(tester)];
        for (var i = 0; i < 5; i++) {
          await _pumpCycle(tester);
          seq.add(_settledText(tester));
        }
        return seq;
      }

      final a = await sequence(1);
      // Unmount → dispose cancels the pending dwell timer.
      await tester.pumpWidget(const SizedBox());
      final b = await sequence(2);
      expect(a, isNot(equals(b)));
    });

    testWidgets('honours a custom texts list', (tester) async {
      await tester.pumpWidget(
        _harness(random: Random(5), texts: const ['ALPHA', 'BETA']),
      );
      expect(find.text('ALPHA'), findsOneWidget);
      await _pumpCycle(tester);
      expect(find.text('BETA'), findsOneWidget);
    });
  });
}
