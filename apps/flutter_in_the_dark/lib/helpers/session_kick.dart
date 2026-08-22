/// Pure keep-vs-kick session logic for the challenge screens — deliberately
/// kept free of Flutter (and `dart:js_interop`) imports so it is
/// unit-testable on the Dart VM. Used by `lib/screens/challenge_screen.dart`.
///
/// WI-012: a player is KICKED (session cleared, routed back to the join
/// screen) when the room tells them their round-scoped session is gone —
/// either the round rolled, or their challenger record disappeared. The
/// show/audience screen never joins, so it never calls this and is exempt
/// by construction.
library;

import 'package:flutter_in_the_dark/room/room_models.dart';

/// Whether the stored session is kicked by [state].
///
/// A `null` [state] (still connecting / reconnecting, no snapshot yet) is
/// NOT a kick — there is no evidence yet, and kicking on a transient null
/// would bounce a reloading player back to the join screen spuriously.
///
/// A present [state] kicks when either:
///  - the round rolled: the snapshot's `roundId` differs from the stored
///    one (any round-close/reset bumps it server-side), or
///  - this player is gone from the snapshot's challenger list.
bool isKickedByState({
  required String playerId,
  required String roundId,
  required RoomState? state,
}) {
  if (state == null) return false;
  if (state.roundId != roundId) return true;
  return state.challengerById(playerId) == null;
}
