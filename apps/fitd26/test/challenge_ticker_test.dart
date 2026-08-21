import 'package:fitd26/helpers/challenge_ticker.dart';
import 'package:fitd26/room/room_models.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _challenge({required DateTime start, required DateTime end}) =>
    Challenge(
      id: 'c1',
      name: 'Test Challenge',
      startTime: start,
      endTime: end,
      widgetUrl: '',
    );

void main() {
  group('shouldTickForChallenge', () {
    test('false when there is no challenge', () {
      expect(shouldTickForChallenge(null), isFalse);
    });

    test('true while the challenge is in the future (waiting for start)', () {
      final now = DateTime.now();
      final c = _challenge(
        start: now.add(const Duration(seconds: 30)),
        end: now.add(const Duration(minutes: 5)),
      );
      expect(shouldTickForChallenge(c), isTrue);
    });

    test('true while the challenge is live (waiting for finish)', () {
      final now = DateTime.now();
      final c = _challenge(
        start: now.subtract(const Duration(minutes: 1)),
        end: now.add(const Duration(minutes: 4)),
      );
      expect(shouldTickForChallenge(c), isTrue);
    });

    test('false once the challenge is finished', () {
      final now = DateTime.now();
      final c = _challenge(
        start: now.subtract(const Duration(minutes: 6)),
        end: now.subtract(const Duration(minutes: 1)),
      );
      expect(shouldTickForChallenge(c), isFalse);
    });

    test(
      'flips false exactly at endTime — the last tick that re-evaluates the '
      'done gate also stops the ticker',
      () {
        final now = DateTime.now();
        // End time in the past by a hair: isFinished is true, so no ticking.
        final justEnded = _challenge(
          start: now.subtract(const Duration(minutes: 5)),
          end: now.subtract(const Duration(milliseconds: 1)),
        );
        expect(justEnded.isFinished, isTrue);
        expect(shouldTickForChallenge(justEnded), isFalse);

        // End time a hair in the future: still live, ticker must run so the
        // done/buzzer edge fires on time.
        final aboutToEnd = _challenge(
          start: now.subtract(const Duration(minutes: 5)),
          end: now.add(const Duration(seconds: 1)),
        );
        expect(aboutToEnd.isFinished, isFalse);
        expect(shouldTickForChallenge(aboutToEnd), isTrue);
      },
    );

    test(
      'true exactly at the waiting boundary — the tick that crosses '
      'startTime re-evaluates the isInTheFuture gate',
      () {
        final now = DateTime.now();
        // Start time a hair in the future: gate is still true, ticker runs.
        final aboutToStart = _challenge(
          start: now.add(const Duration(seconds: 1)),
          end: now.add(const Duration(minutes: 5)),
        );
        expect(aboutToStart.isInTheFuture, isTrue);
        expect(shouldTickForChallenge(aboutToStart), isTrue);
      },
    );
  });
}
