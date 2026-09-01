import 'package:flutter_in_the_dark/helpers/challenge_filter.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('challengeMatchScore', () {
    test('empty/blank query matches everything with score 0', () {
      expect(challengeMatchScore('', 'anything'), 0);
      expect(challengeMatchScore('   ', 'anything'), 0);
    });

    test('contains match, case-insensitive', () {
      expect(challengeMatchScore('quiz', 'Quiz Master'), 0);
      expect(challengeMatchScore('QUIZ', 'the quiz round'), isNotNull);
      expect(challengeMatchScore('master', 'Quiz Master'), isNotNull);
    });

    test('earlier contains match scores lower (better)', () {
      final early = challengeMatchScore('dark', 'Dark Room');
      final late = challengeMatchScore('dark', 'Room of Dark');
      expect(early, isNotNull);
      expect(late, isNotNull);
      expect(early!, lessThan(late!)); // ignore: unnecessary_null_checks
    });

    test('fuzzy fallback: subsequence but not contains', () {
      expect(challengeMatchScore('qz', 'Quiz'), isNotNull);
      expect(challengeMatchScore('dr', 'Dark Room'), isNotNull);
    });

    test('no match returns null', () {
      expect(challengeMatchScore('xyz', 'Quiz Master'), isNull);
      expect(challengeMatchScore('quizz', 'Quiz'), isNull);
    });

    test('contains always beats fuzzy regardless of fuzzy quality', () {
      // 'dr' is a tight fuzzy match at the start of 'Dark Room' (1000 + 0+2),
      // but a contains match anywhere still scores lower.
      final contains = challengeMatchScore('room', 'Room Service')!;
      final fuzzy = challengeMatchScore('rs', 'Room Service')!;
      expect(contains, lessThan(1000));
      expect(fuzzy, greaterThanOrEqualTo(1000));
    });
  });

  group('filterChallenges', () {
    ChallengeInfo info(String name, {String? widgetUrl}) => ChallengeInfo(
          name: name,
          assets: const {'a.png': 'asset:0'},
          widgetUrl: widgetUrl,
        );

    final catalog = [
      info('Emoji Quiz', widgetUrl: '/compiled/emoji-quiz'),
      info('Quiz Master'),
      info('Dark Room', widgetUrl: '/compiled/dark-room'),
      info('Blink and You Miss It'),
    ];

    test('empty query returns all, sorted by name (case-insensitive)', () {
      final result = filterChallenges('  ', catalog);
      expect(result, hasLength(4));
      expect(
        result.map((c) => c.name),
        [
          'Blink and You Miss It',
          'Dark Room',
          'Emoji Quiz',
          'Quiz Master',
        ],
      );
    });

    test('contains matches only; ranked by match position then name', () {
      final result = filterChallenges('quiz', catalog);
      expect(result, hasLength(2));
      // 'Emoji Quiz' matches at index 6, 'Quiz Master' at index 0.
      expect(result.map((c) => c.name), ['Quiz Master', 'Emoji Quiz']);
    });

    test('fuzzy fallback only when no contains matches', () {
      // 'dr' contains-matches nothing but is a subsequence of 'Dark Room'.
      final result = filterChallenges('dr', catalog);
      expect(result.map((c) => c.name), ['Dark Room']);
    });

    test('contains matches rank ahead of fuzzy matches', () {
      final mixed = [
        info('Abcd'), // fuzzy for 'ad' (1000 + 0+3)
        info('XXadXX'), // contains 'ad' at index 2
      ];
      final result = filterChallenges('ad', mixed);
      expect(result.map((c) => c.name), ['XXadXX', 'Abcd']);
    });

    test('case-insensitive filtering', () {
      final result = filterChallenges('DARK', catalog);
      expect(result.map((c) => c.name), ['Dark Room']);
    });

    test('no matches returns empty list', () {
      expect(filterChallenges('zzz', catalog), isEmpty);
    });

    test('stable, deterministic ranking for ties', () {
      // Equal-length names so 'x' matches at the same index for all three.
      final ties = [info('Beta x'), info('Zeta x'), info('Alph x')];
      final first = filterChallenges('x', ties).map((c) => c.name).toList();
      final second = filterChallenges('x', ties).map((c) => c.name).toList();
      expect(first, second);
      // Score ties break on name — first case-insensitively.
      expect(first, ['Alph x', 'Beta x', 'Zeta x']);
    });

    test(
        'deterministic full-tie (identical lowercase names) falls back to '
        'exact name order', () {
      final ties = [info('Beta'), info('beta'), info('BETA')];
      final first = filterChallenges('beta', ties).map((c) => c.name).toList();
      final second = filterChallenges('beta', ties).map((c) => c.name).toList();
      expect(first, second);
      expect(first, hasLength(3));
      expect(first.toSet(), {'Beta', 'beta', 'BETA'});
    });

    test('does not mutate the input list', () {
      final input = [info('B'), info('A')];
      filterChallenges('', input);
      expect(input.map((c) => c.name), ['B', 'A']);
    });
  });
}
