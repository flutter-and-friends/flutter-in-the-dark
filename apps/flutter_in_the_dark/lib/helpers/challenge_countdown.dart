/// Pure countdown math for the admin challenge card's remaining-time
/// readout — deliberately kept free of Flutter imports so it is unit-testable
/// on the Dart VM (the consuming `admin_screen.dart` transitively imports
/// `room_client.dart` → `dart:js_interop` and cannot be widget-tested,
/// W-012). Used by `lib/widgets/challenge_countdown.dart`.
library;

/// Which phase of a challenge's lifetime the countdown is displaying.
enum ChallengeCountdownPhase {
  /// startTime is still in the future — counting down to the START (the
  /// server warms the challenge's widget during this window).
  upcoming,

  /// Live, with more than [kLastMinuteThreshold] left.
  live,

  /// Live, with [kLastMinuteThreshold] or less left — urgency colouring.
  lastMinute,

  /// endTime has passed. The round close itself is PASSIVE (W-017): the
  /// server emits no lifecycle event at endTime and clients notice on the
  /// next SSE snapshot — the countdown still flips here on wall-clock time.
  over,
}

/// At or below this much remaining the countdown is in its last minute.
const Duration kLastMinuteThreshold = Duration(minutes: 1);

/// The countdown phase at instant [now] for a challenge window
/// [[startTime], [endTime]].
///
/// The boundary comparisons mirror `Challenge.isInTheFuture` /
/// `Challenge.isFinished` exactly (strictly-after on both edges), so the
/// phase flips on the same wall-clock instant as every other gate in the
/// app: at precisely endTime the challenge is NOT yet finished and the
/// countdown reads `0:00` for one final second.
ChallengeCountdownPhase challengeCountdownPhase({
  required DateTime now,
  required DateTime startTime,
  required DateTime endTime,
}) {
  if (now.isAfter(endTime)) return ChallengeCountdownPhase.over;
  if (startTime.isAfter(now)) return ChallengeCountdownPhase.upcoming;
  if (endTime.difference(now) <= kLastMinuteThreshold) {
    return ChallengeCountdownPhase.lastMinute;
  }
  return ChallengeCountdownPhase.live;
}

/// Formats a remaining duration as `m:ss` (or `h:mm:ss` at an hour and
/// beyond), clamped at zero — a negative remaining (endTime just crossed)
/// reads `0:00`, never a negative string. Sub-second precision floors:
/// `4:59.4` left reads `4:59`.
String formatChallengeCountdown(Duration remaining) {
  var totalSeconds = remaining.inSeconds;
  if (totalSeconds < 0) totalSeconds = 0;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '$minutes:${two(seconds)}';
}
