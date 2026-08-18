import 'dart:convert';

import 'package:web/web.dart' as web;

/// The contestant's join credentials, kept in localStorage so a reload /
/// background-foreground cycle (I-054) restores the same identity without a
/// re-join. No auth on the admin side — the network gate decides who reaches
/// /admin at all.
class SessionStore {
  static const _key = 'fitd26.player';

  static ({String playerId, String token, String name})? read() {
    final raw = web.window.localStorage.getItem(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        playerId: json['playerId'] as String,
        token: json['token'] as String,
        name: json['name'] as String,
      );
    } on FormatException {
      return null;
    }
  }

  static void write({
    required String playerId,
    required String token,
    required String name,
  }) {
    web.window.localStorage.setItem(
      _key,
      jsonEncode({'playerId': playerId, 'token': token, 'name': name}),
    );
  }

  static void clear() => web.window.localStorage.removeItem(_key);
}
