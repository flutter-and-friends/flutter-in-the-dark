/// Pure player-identity boot/session decision logic — deliberately kept free
/// of Flutter (and `dart:js_interop`) imports so it is unit-testable on the
/// Dart VM. Used by `lib/screens/player_selection_screen.dart` (boot routing)
/// and `lib/screens/challenge_screen.dart` (kick wiring).
///
/// Identity model (post kick-flow fix): a player joins ONCE and persists
/// across challenges. The server snapshot's challenger list is the source of
/// truth for who exists. A stored session resumes silently as long as the
/// server still knows the playerId; only an admin Remove / Remove-all (the
/// playerId disappearing from the snapshot) forces a return to name entry.
/// Starting or clearing a challenge never invalidates a session.
library;

import 'package:flutter_in_the_dark/room/room_models.dart';

/// What the player route should do on boot/resume, given the stored session
/// and the latest server snapshot.
enum BootDecision {
  /// No stored session — show name entry.
  register,

  /// Stored session exists and no snapshot has arrived yet — optimistically
  /// resume (the player screen shows a reconnecting state and self-evicts if
  /// the first snapshot says the server doesn't know this playerId).
  resumeUnverified,

  /// Stored session confirmed by the snapshot — resume without name entry.
  resume,

  /// Stored session rejected by the snapshot (the server doesn't have this
  /// playerId — admin removed them, or the room was reset) — clear the
  /// session and show name entry.
  evictToNameEntry,
}

/// The boot decision for a stored session against the latest snapshot.
///
/// [storedPlayerId] is `null` when there is no stored session at all.
/// A `null` [state] means no snapshot yet (still connecting): NOT evidence
/// of a kick — a reloading player must not be bounced spuriously, so the
/// decision is to resume optimistically and let the player screen's kick
/// wiring arbitrate once the first snapshot lands.
BootDecision decideBoot({
  required String? storedPlayerId,
  required RoomState? state,
}) {
  final id = storedPlayerId;
  if (id == null) return BootDecision.register;
  final current = state;
  if (current == null) return BootDecision.resumeUnverified;
  return current.challengerById(id) != null
      ? BootDecision.resume
      : BootDecision.evictToNameEntry;
}
