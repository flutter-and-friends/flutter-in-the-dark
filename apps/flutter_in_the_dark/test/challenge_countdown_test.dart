import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/challenge_countdown.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_in_the_dark/widgets/challenge_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _challenge({required DateTime start, required DateTime end}) =>
    Challenge(
      id: 'c1',
      name: 'Test Challenge',
      startTime: start,
      endTime: end,
      widgetUrl: '',
    );

Widget _wrap(Challenge challenge, {double? width}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ChallengeCountdown(challenge: challenge),
          ),
        ),
      ),
    );

/// The countdown readout's Text widget (the only Text the widget builds).
Text _readout(WidgetTester tester, Pattern pattern) =>
    tester.widget<Text>(find.textContaining(pattern));

void main() {
  group('formatChallengeCountdown', () {
    test('clamps a negative remaining to 0:00 (endTime just crossed)', () {
      expect(
        formatChallengeCountdown(const Duration(seconds: -3)),
        '0:00',
      );
    });

    test('zero reads 0:00', () {
      expect(formatChallengeCountdown(Duration.zero), '0:00');
    });

    test('pads single-digit seconds', () {
      expect(formatChallengeCountdown(const Duration(seconds: 5)), '0:05');
    });

    test('minutes and seconds', () {
      expect(formatChallengeCountdown(const Duration(seconds: 65)), '1:05');
    });

    test('floors sub-second precision', () {
      expect(
        formatChallengeCountdown(const Duration(milliseconds: 59999)),
        '0:59',
      );
    });

    test('just under an hour stays m:ss', () {
      expect(
        formatChallengeCountdown(const Duration(seconds: 3599)),
        '59:59',
      );
    });

    test('an hour switches to h:mm:ss', () {
      expect(
        formatChallengeCountdown(const Duration(seconds: 3600)),
        '1:00:00',
      );
    });

    test('multi-digit hours keep zero-padded minutes and seconds', () {
      expect(
        formatChallengeCountdown(const Duration(seconds: 36610)),
        '10:10:10',
      );
    });
  });

  group('challengeCountdownPhase', () {
    final start = DateTime.utc(2026, 9, 1, 12);
    final end = start.add(const Duration(minutes: 5));

    test('upcoming while startTime is in the future', () {
      final now = start.subtract(const Duration(seconds: 10));
      expect(
        challengeCountdownPhase(now: now, startTime: start, endTime: end),
        ChallengeCountdownPhase.upcoming,
      );
    });

    test('live from the exact start instant (mirrors isInTheFuture)', () {
      expect(
        challengeCountdownPhase(now: start, startTime: start, endTime: end),
        ChallengeCountdownPhase.live,
      );
    });

    test('live while more than a minute remains', () {
      final now = start.add(const Duration(minutes: 2));
      expect(
        challengeCountdownPhase(now: now, startTime: start, endTime: end),
        ChallengeCountdownPhase.live,
      );
    });

    test('lastMinute at exactly the threshold', () {
      final now = end.subtract(kLastMinuteThreshold);
      expect(
        challengeCountdownPhase(now: now, startTime: start, endTime: end),
        ChallengeCountdownPhase.lastMinute,
      );
    });

    test('lastMinute one second before the end', () {
      final now = end.subtract(const Duration(seconds: 1));
      expect(
        challengeCountdownPhase(now: now, startTime: start, endTime: end),
        ChallengeCountdownPhase.lastMinute,
      );
    });

    test(
      'still not over at the exact end instant (mirrors isFinished: '
      'strictly-after) — the readout shows 0:00 for one final second',
      () {
        expect(
          challengeCountdownPhase(now: end, startTime: start, endTime: end),
          ChallengeCountdownPhase.lastMinute,
        );
      },
    );

    test('over one millisecond after endTime', () {
      final now = end.add(const Duration(milliseconds: 1));
      expect(
        challengeCountdownPhase(now: now, startTime: start, endTime: end),
        ChallengeCountdownPhase.over,
      );
    });
  });

  group('ChallengeCountdown widget', () {
    // I-017: under flutter_test's fake async, DateTime.now() does NOT
    // advance with tester.pump — so the ticking assertions below are
    // limited to initial-build phase checks (robust to a few seconds of
    // real-time drift), plus one runAsync test that lets real wall-clock
    // time pass.

    testWidgets('live challenge: green ends-in readout', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _wrap(
          _challenge(
            start: now.subtract(const Duration(minutes: 1)),
            end: now.add(const Duration(minutes: 5)),
          ),
        ),
      );
      // ~5:00 minus construction time — anything in 4:5x proves the phase.
      final text = _readout(tester, RegExp(r'ends in 4:5\d'));
      expect(text.style?.color, Colors.greenAccent);
      expect(text.maxLines, 1);
      expect(
        find.byIcon(Icons.timer_outlined),
        findsOneWidget,
      );
    });

    testWidgets('upcoming challenge: blue starts-in readout', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _wrap(
          _challenge(
            start: now.add(const Duration(seconds: 30)),
            end: now.add(const Duration(minutes: 5)),
          ),
        ),
      );
      final text = _readout(tester, RegExp(r'starts in 0:(2|3)\d'));
      expect(text.style?.color, Colors.blueAccent);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('last minute: orange urgency readout', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _wrap(
          _challenge(
            start: now.subtract(const Duration(minutes: 4)),
            end: now.add(const Duration(seconds: 45)),
          ),
        ),
      );
      final text = _readout(tester, RegExp(r'ends in 0:(3|4)\d'));
      expect(text.style?.color, Colors.orangeAccent);
    });

    testWidgets(
      "finished challenge: red 'Time over', and NO ticker is started "
      "(a pending Timer would fail this test's teardown)",
      (tester) async {
        final now = DateTime.now();
        await tester.pumpWidget(
          _wrap(
            _challenge(
              start: now.subtract(const Duration(minutes: 6)),
              end: now.subtract(const Duration(minutes: 1)),
            ),
          ),
        );
        final text = _readout(tester, 'Time over');
        expect(text.style?.color, Colors.redAccent);
        expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'fits a phone-width (320 px) slot without overflow — including the '
      'h:mm:ss form',
      (tester) async {
        final now = DateTime.now();
        await tester.pumpWidget(
          _wrap(
            _challenge(
              start: now.subtract(const Duration(minutes: 1)),
              // Ten hours left: the longest label the formatter produces.
              end: now.add(const Duration(seconds: 36610)),
            ),
            width: 320,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining(RegExp(r'ends in 10:1\d:\d\d')), findsOne);
      },
    );

    testWidgets('dispose cancels the ticker', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _wrap(
          _challenge(
            start: now.subtract(const Duration(minutes: 1)),
            end: now.add(const Duration(minutes: 5)),
          ),
        ),
      );
      // Unmount, then advance fake time well past several tick intervals: a
      // leaked Timer would fire setState on a disposed State and throw.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the 1 Hz ticker advances the readout from wall-clock time (real '
      'async — fake async never advances DateTime.now(), I-017)',
      (tester) async {
        await tester.runAsync(() async {
          final now = DateTime.now();
          await tester.pumpWidget(
            _wrap(
              _challenge(
                start: now.subtract(const Duration(minutes: 1)),
                end: now.add(const Duration(seconds: 90)),
              ),
            ),
          );
          int readoutSeconds() {
            final text = _readout(tester, RegExp(r'ends in \d+:\d{2}'));
            final match = RegExp(
              r'ends in (\d+):(\d{2})',
            ).firstMatch(text.data!)!;
            return int.parse(match.group(1)!) * 60 +
                int.parse(match.group(2)!);
          }

          final before = readoutSeconds();
          // Let real time pass so the periodic Timer fires and rebuilds.
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          await tester.pump();
          final after = readoutSeconds();

          expect(after, lessThan(before));
          // Generous slack for scheduling jitter on a loaded machine.
          expect(after, greaterThanOrEqualTo(before - 5));
        });
      },
    );
  });
}
