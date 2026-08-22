/// Pure challenge-window computation for the admin challenge card —
/// deliberately kept free of Flutter imports so it is unit-testable on the
/// Dart VM. Used by `lib/screens/admin_screen.dart`.
library;

/// The (start, end) window for a challenge set from the admin card.
typedef ChallengeWindow = ({DateTime start, DateTime end});

/// Parses a non-negative integer from [text], falling back to [fallback]
/// when the field is empty, non-numeric, or negative. Used for the admin
/// card's duration/delay fields so a typo never silently zeroes a challenge.
int parseNonNegativeInt(String text, int fallback) {
  final parsed = int.tryParse(text.trim());
  if (parsed == null || parsed < 0) return fallback;
  return parsed;
}

/// Computes the challenge window: [start] is [now] plus [startAfterSeconds]
/// (0 = start immediately), and [end] is [start] plus [durationMinutes] —
/// the duration is measured from when the challenge actually STARTS, not
/// from when the admin taps the button.
///
/// A future [start] gives the room service a warm-up window: the server
/// warms (pre-compiles) the challenge's widget in the background when it is
/// set with a future startTime, so the widget is hot by the time the
/// client-side countdown (waiting_for_challenge.dart) reaches zero.
///
/// Instant arithmetic (`DateTime.add`) is timezone-safe regardless of [now]'s
/// zone: the room client sends `startTime.millisecondsSinceEpoch`
/// (zone-independent), and the server normalizes to UTC on ingest, so the
/// wire form is the correct instant whatever zone the admin's browser is in.
ChallengeWindow computeChallengeWindow({
  required DateTime now,
  required int startAfterSeconds,
  required int durationMinutes,
}) {
  final start = now.add(Duration(seconds: startAfterSeconds));
  return (start: start, end: start.add(Duration(minutes: durationMinutes)));
}
