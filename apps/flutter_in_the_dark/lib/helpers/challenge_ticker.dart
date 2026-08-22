/// Pure wall-clock ticker-gating logic for the challenge screens —
/// deliberately kept free of Flutter imports so it is unit-testable on the
/// Dart VM. Used by `lib/screens/challenge_screen.dart` and
/// `lib/screens/show_screen.dart`.
library;

import 'package:flutter_in_the_dark/room/room_models.dart';

/// Whether a wall-clock ticker should be running for [challenge].
///
/// The ticker drives re-evaluation of the time-dependent build gates
/// ([Challenge.isInTheFuture] / [Challenge.isFinished]) — RoomSync only
/// notifies on SSE events, and the server never sends an event at the
/// moment wall-clock time crosses startTime/endTime, so without a ticker
/// the screen would stay stuck on the waiting (or live) view until the
/// next unrelated SSE event arrived.
///
/// Returns true while there is a pending time-dependent transition to
/// wait for: the challenge exists and is either not yet started
/// ([Challenge.isInTheFuture]) or started but not yet finished
/// (![Challenge.isFinished]). Once the challenge is finished — or null —
/// there is nothing time-dependent left, so the ticker should stop.
bool shouldTickForChallenge(Challenge? challenge) =>
    challenge != null &&
    (challenge.isInTheFuture || !challenge.isFinished);
