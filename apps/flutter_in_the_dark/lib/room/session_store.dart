import 'dart:convert';

import 'package:web/web.dart' as web;

/// The contestant's opaque join credentials, kept in localStorage so a
/// reload / background-foreground cycle (I-054) restores the same identity
/// without a re-join. No auth on the admin side — the network gate decides
/// who reaches /admin at all.
///
/// Stores ONLY opaque, round-scoped credentials: `(playerId, token,
/// roundId)`. The display name is deliberately NOT stored — it is
/// round-scoped server state (re-entered each round), read back from the
/// room state, never from localStorage (WI-012).
///
/// PLAYER-scoped key: the session identifies a joined contestant, so it
/// lives under a player-only key. Admin (/admin) and audience (/show) are
/// NOT joined contestants and must never consume a player session — they
/// simply never read this store (see the role-scoping note in main.dart).
class SessionStore {
  // Renamed from 'fitd26.player' during WI-011 de-yearing, then made
  // explicitly player-scoped ('.session') during WI-012: the app has one
  // shared localStorage across /admin, /show and the player route, and the
  // old path-independent key let an admin/show tab pick up a player
  // identity. Legacy shapes (and any entry missing a field) are treated as
  // absent — read() never throws.
  static const _key = 'fitd.player.session';

  static ({String playerId, String token, String roundId})? read() {
    final raw = web.window.localStorage.getItem(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final playerId = json['playerId'];
      final token = json['token'];
      final roundId = json['roundId'];
      if (playerId is! String || token is! String || roundId is! String) {
        // Legacy / stale shape (e.g. the pre-roundId `{playerId, token,
        // name}` entry): treat as absent rather than crash.
        return null;
      }
      return (playerId: playerId, token: token, roundId: roundId);
    } on FormatException {
      return null;
    }
  }

  static void write({
    required String playerId,
    required String token,
    required String roundId,
  }) {
    web.window.localStorage.setItem(
      _key,
      jsonEncode({
        'playerId': playerId,
        'token': token,
        'roundId': roundId,
      }),
    );
  }

  static void clear() => web.window.localStorage.removeItem(_key);
}
