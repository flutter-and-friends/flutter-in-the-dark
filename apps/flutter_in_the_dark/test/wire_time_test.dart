import 'package:flutter_in_the_dark/helpers/wire_time.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasZoneDesignator', () {
    test('Z suffix', () {
      expect(hasZoneDesignator('2026-08-21T10:00:00.000Z'), isTrue);
      expect(hasZoneDesignator('2026-08-21T10:00:00z'), isTrue);
    });

    test('explicit offsets', () {
      expect(hasZoneDesignator('2026-08-21T12:00:00+02:00'), isTrue);
      expect(hasZoneDesignator('2026-08-21T12:00:00+0200'), isTrue);
      expect(hasZoneDesignator('2026-08-21T12:00:00-05:00'), isTrue);
    });

    test('naive strings (date dashes are not zone designators)', () {
      expect(hasZoneDesignator('2026-08-21T10:00:00.000'), isFalse);
      expect(hasZoneDesignator('2026-08-21T10:00:00'), isFalse);
      expect(hasZoneDesignator('2026-08-21 10:00:00'), isFalse);
    });
  });

  group('parseWireTime', () {
    test('Z-suffixed string parses to the correct instant', () {
      final parsed = parseWireTime('2026-08-21T10:00:00.000Z');
      expect(parsed.isUtc, isTrue);
      expect(
        parsed.millisecondsSinceEpoch,
        DateTime.utc(2026, 8, 21, 10).millisecondsSinceEpoch,
      );
    });

    test('explicit offset parses to the correct instant', () {
      final parsed = parseWireTime('2026-08-21T12:00:00+02:00');
      expect(
        parsed.millisecondsSinceEpoch,
        DateTime.utc(2026, 8, 21, 10).millisecondsSinceEpoch,
      );
    });

    test(
      'legacy naive string is treated as UTC, NOT shifted by client offset',
      () {
        final parsed = parseWireTime('2026-08-21T10:00:00.000');
        expect(parsed.isUtc, isTrue);
        expect(
          parsed.millisecondsSinceEpoch,
          DateTime.utc(2026, 8, 21, 10).millisecondsSinceEpoch,
        );
        // The bug this guards against: DateTime.parse without a designator
        // interprets the string as LOCAL time, shifting the instant by the
        // client's offset. Only vacuous when the test runs on a UTC machine.
        final naiveAsLocal = DateTime.parse(
          '2026-08-21T10:00:00.000',
        ).millisecondsSinceEpoch;
        final offset = DateTime.now().timeZoneOffset;
        if (offset != Duration.zero) {
          expect(parsed.millisecondsSinceEpoch, isNot(naiveAsLocal));
        }
      },
    );

    test('naive and Z-suffixed forms of the same instant agree', () {
      expect(
        parseWireTime('2026-08-21T10:00:00.000').millisecondsSinceEpoch,
        parseWireTime('2026-08-21T10:00:00.000Z').millisecondsSinceEpoch,
      );
    });
  });

  group('Challenge.fromJson timezone correctness', () {
    Map<String, dynamic> challengeJson({
      required String startTime,
      required String endTime,
    }) => {
      'id': 'c1',
      'name': 'Five minutes',
      'startTime': startTime,
      'endTime': endTime,
      'widgetUrl': '/compiled/c1',
    };

    test(
      'Z-suffixed wire: challenge starting now is live and not finished',
      () {
        final now = DateTime.now().toUtc();
        final challenge = Challenge.fromJson(
          challengeJson(
            startTime: _isoZ(now),
            endTime: _isoZ(now.add(const Duration(minutes: 5))),
          ),
        );
        expect(challenge.isInTheFuture, isFalse);
        expect(challenge.isFinished, isFalse);
        final remaining = challenge.endTime.difference(DateTime.now());
        expect(remaining.isNegative, isFalse);
        expect(remaining.inMinutes, inInclusiveRange(3, 5));
      },
    );

    test(
      'legacy naive wire (UTC instant, no Z): challenge starting now is '
      'NOT immediately finished',
      () {
        // Regression test for the reported symptom: a +2 client saw
        // "Time over!" immediately because the naive UTC string was parsed
        // as local time, landing the endTime ~2h in the past.
        final now = DateTime.now().toUtc();
        final challenge = Challenge.fromJson(
          challengeJson(
            startTime: _isoNaive(now),
            endTime: _isoNaive(now.add(const Duration(minutes: 5))),
          ),
        );
        expect(challenge.startTime.isUtc, isTrue);
        expect(challenge.isFinished, isFalse);
        expect(challenge.isInTheFuture, isFalse);
      },
    );

    test('comparison is instant-based regardless of client zone', () {
      // An endTime one minute in the past is finished on every client.
      final past = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      final challenge = Challenge.fromJson(
        challengeJson(
          startTime: _isoZ(past.subtract(const Duration(minutes: 6))),
          endTime: _isoZ(past),
        ),
      );
      expect(challenge.isFinished, isTrue);
    });
  });
}

/// UTC ISO-8601 with explicit Z designator (the fixed wire format).
String _isoZ(DateTime utc) => utc.toIso8601String();

/// UTC ISO-8601 without a designator (the legacy wire format).
String _isoNaive(DateTime utc) {
  final s = utc.toIso8601String();
  return s.endsWith('Z') ? s.substring(0, s.length - 1) : s;
}
