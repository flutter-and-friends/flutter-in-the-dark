import 'package:fitd26/room/room_models.dart';

/// Pure catalog search for the admin challenge picker — deliberately kept
/// free of Flutter and `package:web` imports so it is unit-testable on the
/// Dart VM. Re-exported from `lib/widgets/challenge_picker.dart`.

/// Scores how well [query] matches a challenge [name].
///
/// Returns `null` for no match. Non-null scores sort ASCENDING — a lower
/// score is a better match. Band layout:
///  * `0..999`   case-insensitive CONTAINS; the score is the match start
///    index, so earlier matches rank better.
///  * `1000..`   subsequence FUZZY (only reached when nothing contains);
///    `1000 + sum of matched positions`, so shorter/earlier spans win.
int? challengeMatchScore(String query, String name) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0;
  final n = name.toLowerCase();
  final idx = n.indexOf(q);
  if (idx >= 0) return idx;
  var qi = 0;
  var span = 0;
  for (var i = 0; i < n.length && qi < q.length; i++) {
    if (n[i] == q[qi]) {
      span += i;
      qi++;
    }
  }
  return qi == q.length ? 1000 + span : null;
}

/// Filters [challenges] by [query] and returns them ranked: contains matches
/// first, then fuzzy matches (ascending [challengeMatchScore]), then by name
/// (case-insensitive) inside each band. An empty/blank query returns every
/// challenge sorted by name.
List<ChallengeInfo> filterChallenges(
  String query,
  List<ChallengeInfo> challenges,
) {
  final scored = <(int, ChallengeInfo)>[];
  for (final c in challenges) {
    final score = challengeMatchScore(query, c.name);
    if (score != null) scored.add((score, c));
  }
  scored.sort((a, b) {
    final byScore = a.$1.compareTo(b.$1);
    if (byScore != 0) return byScore;
    final byName = a.$2.name.toLowerCase().compareTo(b.$2.name.toLowerCase());
    if (byName != 0) return byName;
    return a.$2.name.compareTo(b.$2.name);
  });
  return [for (final s in scored) s.$2];
}
