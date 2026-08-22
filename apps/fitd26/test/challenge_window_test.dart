import 'package:fitd26/helpers/challenge_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseNonNegativeInt', () {
    test('parses a plain integer', () {
      expect(parseNonNegativeInt('10', 5), 10);
      expect(parseNonNegativeInt('0', 5), 0);
    });

    test('trims surrounding whitespace', () {
      expect(parseNonNegativeInt('  15  ', 5), 15);
    });

    test('falls back on empty / non-numeric input', () {
      expect(parseNonNegativeInt('', 5), 5);
      expect(parseNonNegativeInt('abc', 5), 5);
      expect(parseNonNegativeInt('1.5', 5), 5);
    });

    test('falls back on negative input', () {
      expect(parseNonNegativeInt('-3', 5), 5);
    });
  });

  group('computeChallengeWindow', () {
    test('delay 0 starts at now; end is start + duration', () {
      final now = DateTime.now();
      final window = computeChallengeWindow(
        now: now,
        startAfterSeconds: 0,
        durationMinutes: 5,
      );
      expect(window.start.difference(now), Duration.zero);
      expect(window.end.difference(window.start), const Duration(minutes: 5));
    });

    test('delay 10 starts 10s out; end is start + duration', () {
      final now = DateTime.now();
      final window = computeChallengeWindow(
        now: now,
        startAfterSeconds: 10,
        durationMinutes: 5,
      );
      expect(window.start.difference(now), const Duration(seconds: 10));
      expect(window.end.difference(window.start), const Duration(minutes: 5));
      // Duration is measured from the actual start, not from the tap:
      // end is 5min10s after now, NOT 5min.
      expect(
        window.end.difference(now),
        const Duration(minutes: 5, seconds: 10),
      );
    });

    test('instant-correct across zones (UTC and local now agree)', () {
      // The same instant expressed as UTC and as local time must produce
      // the same window — the comparison is on the instant, not the zone.
      final utcNow = DateTime.now().toUtc();
      final localNow = utcNow.toLocal();
      final utcWindow = computeChallengeWindow(
        now: utcNow,
        startAfterSeconds: 10,
        durationMinutes: 5,
      );
      final localWindow = computeChallengeWindow(
        now: localNow,
        startAfterSeconds: 10,
        durationMinutes: 5,
      );
      expect(
        utcWindow.start.millisecondsSinceEpoch,
        localWindow.start.millisecondsSinceEpoch,
      );
      expect(
        utcWindow.end.millisecondsSinceEpoch,
        localWindow.end.millisecondsSinceEpoch,
      );
      // And the future start survives the wire round-trip: the client sends
      // millisecondsSinceEpoch (zone-independent), which reconstructs the
      // identical instant.
      final revived = DateTime.fromMillisecondsSinceEpoch(
        utcWindow.start.millisecondsSinceEpoch,
        isUtc: true,
      );
      expect(
        revived.millisecondsSinceEpoch,
        utcWindow.start.millisecondsSinceEpoch,
      );
      expect(revived.isAfter(DateTime.now()), isTrue);
    });
  });
}
