import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ViewMode', () {
    test('has five values, singleWithChallenge adjacent to singlePlayer', () {
      // The wire name must match the server's ViewMode enum exactly
      // (serialization is `.name` / `byName` both directions).
      expect(ViewMode.values.map((m) => m.name), [
        'allWithChallenge',
        'allPlayers',
        'singlePlayer',
        'singleWithChallenge',
        'challengeOnly',
      ]);
    });

    test('singleWithChallenge round-trips through byName', () {
      expect(
        ViewMode.values.byName('singleWithChallenge'),
        ViewMode.singleWithChallenge,
      );
    });

    test('isSinglePlayerScoped is true for the two focused-player modes', () {
      expect(ViewMode.singlePlayer.isSinglePlayerScoped, isTrue);
      expect(ViewMode.singleWithChallenge.isSinglePlayerScoped, isTrue);
      expect(ViewMode.allWithChallenge.isSinglePlayerScoped, isFalse);
      expect(ViewMode.allPlayers.isSinglePlayerScoped, isFalse);
      expect(ViewMode.challengeOnly.isSinglePlayerScoped, isFalse);
    });

    test('labels are short enough for a crowded segmented button', () {
      for (final mode in ViewMode.values) {
        expect(mode.label.length, lessThanOrEqualTo(13));
      }
      expect(ViewMode.singleWithChallenge.label, 'Ch. + single');
    });
  });

  group('viewModeRows', () {
    test('wide width keeps all five modes on one row', () {
      expect(viewModeRows(560), [ViewMode.values]);
      expect(viewModeRows(1200), [ViewMode.values]);
    });

    test('narrow width splits into two rows preserving enum order', () {
      final rows = viewModeRows(360);
      expect(rows.length, 2);
      expect(rows[0].length, 3);
      expect(rows[1].length, 2);
      expect(rows.expand((r) => r), ViewMode.values);
    });

    test('boundary: just below the threshold splits', () {
      expect(viewModeRows(559).length, 2);
    });
  });
}
