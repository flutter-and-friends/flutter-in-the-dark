/// Pure keep-vs-kick session logic for the challenge screens — deliberately
/// kept free of Flutter (and `dart:js_interop`) imports so it is
/// unit-testable on the Dart VM. Used by `lib/screens/challenge_screen.dart`.
///
/// A player is KICKED (session cleared, routed back to name entry) when the
/// server snapshot no longer contains their playerId — i.e. the admin hit
/// Remove on them or cleared the player list. Players persist across
/// challenges: setChallenge / clearChallenge do NOT invalidate sessions, so
/// the round generation is no longer consulted here (W-024: match on stable
/// id only, never name). The show/audience screen never joins, so it never
/// calls this and is exempt by construction.
library;

import 'package:flutter_in_the_dark/room/room_models.dart';

/// Whether the stored session is kicked by [state].
///
/// A `null` [state] (still connecting / reconnecting, no snapshot yet) is
/// NOT a kick — there is no evidence yet, and kicking on a transient null
/// would bounce a reloading player back to name entry spuriously.
///
/// A present [state] kicks exactly when this player is gone from the
/// snapshot's challenger list (admin Remove / Remove-all).
bool isKickedByState({required String playerId, required RoomState? state}) {
  if (state == null) return false;
  return state.challengerById(playerId) == null;
}
