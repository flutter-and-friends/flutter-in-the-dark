import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'room_models.dart';

/// Client for the Flutter in the Dark room-state service (replaces Firestore).
///
/// Base URL resolution mirrors the generation client:
///  - page served from the tailnet alias (`*.ts.net:4443`) → SAME origin
///    (`web.window.location.origin`), always. The tailnet proxy fronts the
///    full app AND the full API (incl. `/api/admin/*`) on one origin; this
///    overrides even the release build's baked URL so the WI-099 admin
///    path keeps working with the single image.
///  - `--dart-define=ROOM_URL=<explicit-url>` → used verbatim. The
///    production release build sets this to
///    `https://backend.flutterinthedark.dev` (WI-100): the app SPA is
///    served from the APEX `flutterinthedark.dev` while the room API stays
///    on the `backend.*` subdomain — different origins, so same-origin
///    resolution would be wrong for the public app. Both services answer
///    CORS for the apex origin.
///  - `--dart-define=ROOM_URL=same-origin` → API on the SAME origin
///    (single-origin proxy deployments, e.g. the pre-WI-100 layout).
///  - loopback app → `http://127.0.0.1:8302`;
///  - any other device → same host, port 4501 (the published relay port;
///    the relay forwards `/api/(state|events|join|prompt)` to 8302, and
///    `/api/admin/*` ONLY on the Tailscale-facing listener).
///
/// NOTE: an EMPTY dart-define does NOT mean same-origin —
/// `String.fromEnvironment` cannot distinguish "set to empty" from "unset",
/// and both yield the empty string, which fails `isNotEmpty`. Use the
/// `same-origin` sentinel for the proxied single-origin build.
class RoomClient {
  RoomClient({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  final String baseUrl;

  static const String _envBaseUrl = String.fromEnvironment('ROOM_URL');

  /// Sentinel selecting same-origin API access behind the reverse proxy.
  static const String _sameOrigin = 'same-origin';

  /// The deployment's public API host (WI-100). The release build bakes
  /// this into ROOM_URL/DART_SERVICES_URL because the SPA itself is served
  /// from the apex — a different origin.
  static const String backendUrl = 'https://backend.flutterinthedark.dev';

  /// True when the page is being served from the tailnet admin listener
  /// (`https://<machine>.<tailnet>.ts.net:4443`). There the proxy fronts
  /// the app AND the full API — including `/api/admin/*` — on ONE origin,
  /// so same-origin resolution is required even in the WI-100 release
  /// build (which otherwise bakes [backendUrl] for the apex split).
  static bool get _onTailnetAlias =>
      web.window.location.hostname.endsWith('.ts.net');

  static String get defaultBaseUrl {
    if (_onTailnetAlias) return web.window.location.origin;
    if (_envBaseUrl == _sameOrigin) return web.window.location.origin;
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    final host = web.window.location.hostname;
    if (host == '127.0.0.1' || host == 'localhost') {
      return 'http://127.0.0.1:8302';
    }
    return 'http://$host:4501';
  }

  /// Generation backend (for compiled-widget iframe URLs). Same host mapping
  /// as [defaultBaseUrl] but to dart_services. The production build sets
  /// `DART_SERVICES_URL` to the backend host too — the iframes are
  /// dart_services URLs, and loading them cross-origin from the apex is
  /// allowed (no X-Frame-Options; ACAO `*` on the responses).
  static String get compileBaseUrl {
    const env = String.fromEnvironment('DART_SERVICES_URL');
    if (_onTailnetAlias) return web.window.location.origin;
    if (env == _sameOrigin) return web.window.location.origin;
    if (env.isNotEmpty) return env;
    final host = web.window.location.hostname;
    if (host == '127.0.0.1' || host == 'localhost') {
      return 'http://127.0.0.1:8300';
    }
    return 'http://$host:4501';
  }

  // ------------------------------------------------------------ catch-up GET

  Future<RoomState> fetchState() async {
    final response = await web.window.fetch('$baseUrl/api/state'.toJS).toDart;
    final text = (await response.text().toDart).toDart;
    return RoomState.fromJson(
      (jsonDecode(text) as Map).cast<String, dynamic>(),
    );
  }

  // ------------------------------------------------------------------- SSE

  /// Opens the SSE stream and emits every full snapshot.
  ///
  /// Reconnect policy (I-054): the caller ([RoomSync]) drives resume — this
  /// is a single connection attempt.
  Stream<RoomState> events({int? lastEventId}) {
    final controller = StreamController<RoomState>();
    final source = web.EventSource('$baseUrl/api/events');

    source.addEventListener(
      'state',
      (web.Event event) {
        final message = event as web.MessageEvent;
        final data = message.data;
        if (data.isA<JSString>()) {
          try {
            controller.add(
              RoomState.fromJson(
                jsonDecode((data as JSString).toDart) as Map<String, dynamic>,
              ),
            );
          } catch (_) {
            // A malformed frame is skipped; the next snapshot heals us.
          }
        }
      }.toJS,
    );
    source.onerror = ((web.Event _) {
      controller.addError(const RoomConnectionException());
    }).toJS;

    controller.onCancel = () => source.close();
    return controller.stream;
  }

  // ----------------------------------------------------------- catalog GET

  /// The server-side challenge catalog for the admin picker.
  Future<List<ChallengeInfo>> fetchChallenges() async {
    final response = await web.window
        .fetch('$baseUrl/api/admin/challenges'.toJS)
        .toDart;
    final text = (await response.text().toDart).toDart;
    if (!response.ok) {
      throw RoomPostException(response.status, text);
    }
    final json = (jsonDecode(text) as Map).cast<String, dynamic>();
    return [
      for (final c in (json['challenges'] as List? ?? const []))
        ChallengeInfo.fromJson((c as Map).cast<String, dynamic>()),
    ];
  }

  /// The live provider routing for the admin provider picker
  /// (`GET /api/admin/provider`). Throws [RoomPostException] on non-200.
  Future<ProviderState> fetchProvider() async {
    final response = await web.window
        .fetch('$baseUrl/api/admin/provider'.toJS)
        .toDart;
    final text = (await response.text().toDart).toDart;
    if (!response.ok) {
      throw RoomPostException(response.status, text);
    }
    return ProviderState.fromJson(
      (jsonDecode(text) as Map).cast<String, dynamic>(),
    );
  }

  // ------------------------------------------------------------------ POST

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await web.window
        .fetch(
          '$baseUrl$path'.toJS,
          web.RequestInit(
            method: 'POST',
            headers: {'Content-Type': 'application/json'}.jsify()! as JSObject,
            body: jsonEncode(body).toJS,
          ),
        )
        .toDart;
    final text = (await response.text().toDart).toDart;
    if (!response.ok) {
      throw RoomPostException(response.status, text);
    }
    return text.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(text) as Map<String, dynamic>;
  }

  // ------------------------------------------------------------- contestant

  /// "Here's my ID — do you know me, and what's my name?" The server's
  /// definitive answer for a client resuming a stored session on boot:
  /// `known` false means the identity was kicked, cleared, or never existed
  /// → the client re-enters a name. A read — never mutates, never
  /// re-registers. Throws [RoomPostException] on non-200.
  Future<({bool known, String? name})> fetchSession(String playerId) async {
    final response = await web.window
        .fetch('$baseUrl/api/session?playerId=$playerId'.toJS)
        .toDart;
    final text = (await response.text().toDart).toDart;
    if (!response.ok) {
      throw RoomPostException(response.status, text);
    }
    final json = (jsonDecode(text) as Map).cast<String, dynamic>();
    return (known: json['known'] as bool? ?? false, name: json['name'] as String?);
  }

  /// Joins the room. Request is `{name}` only — the server always mints a
  /// fresh (playerId, token, roundId); there is no playerId echo or
  /// server-side reattach (a client with a stored session resumes passively
  /// via [fetchSession], it never re-joins). The identity then persists
  /// across challenges; only an admin Remove / Remove-all ends it.
  Future<({String playerId, String token, String roundId})> join(
    String name,
  ) async {
    final result = await _post('/api/join', {'name': name});
    return (
      playerId: result['playerId'] as String,
      token: result['token'] as String,
      roundId: result['roundId'] as String,
    );
  }

  Future<void> updatePrompt({
    required String playerId,
    required String token,
    required String prompt,
  }) => _post('/api/prompt', {
    'playerId': playerId,
    'token': token,
    'prompt': prompt,
  });

  // ------------------------------------------------------------------ admin

  Future<void> setChallenge({
    required String name,
    required String widgetUrl,
    required DateTime startTime,
    required DateTime endTime,
    Map<String, String> assets = const {},
  }) => _post('/api/admin/challenge', {
    'name': name,
    'widgetUrl': widgetUrl,
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime.millisecondsSinceEpoch,
    'assets': assets,
  });

  Future<void> clearChallenge() => _post('/api/admin/clear', {});

  /// Compiles the catalog challenge [name] and returns its `/compiled/<id>`
  /// URL. Slow on first call (the service builds it on demand). Throws
  /// [RoomPostException] on non-200 (`{"error":"compile_failed","problems":
  /// [...]}`) — the caller surfaces `problems` to the admin.
  Future<String> compileChallenge(String name) async {
    final result = await _post('/api/admin/challenges/compile', {
      'name': name,
    });
    return result['url'] as String;
  }

  Future<void> adjustTime({required Duration delta}) =>
      _post('/api/admin/adjustTime', {'seconds': delta.inSeconds});

  Future<void> setShowView({ViewMode? viewMode, String? focusedPlayerId}) =>
      _post('/api/admin/showView', {
        if (viewMode != null) 'viewMode': viewMode.name,
        'focusedPlayerId': focusedPlayerId,
      });

  Future<void> setContentAll({required DisplayContent content}) =>
      _post('/api/admin/contentAll', {'content': content.name});

  Future<void> setContentFor({
    required String playerId,
    required DisplayContent content,
  }) => _post('/api/admin/contentFor', {
    'playerId': playerId,
    'content': content.name,
  });

  Future<void> regenerate({required String playerId}) =>
      _post('/api/admin/regenerate', {'playerId': playerId});

  Future<void> removeChallenger({required String playerId}) =>
      _post('/api/admin/removeChallenger', {'playerId': playerId});

  Future<void> removeAllChallengers() => _post('/api/admin/removeAll', {});

  /// Live generation-model failover. Applies to new generation immediately.
  Future<void> setModel({required String model}) =>
      _post('/api/admin/model', {'model': model});

  /// Live LLM-provider failover. Applies to new generation immediately.
  /// Throws [RoomPostException] on non-200 — notably 409 when [mode] is
  /// [ProviderMode.gemini] but the service has no GEMINI_API_KEY; the body
  /// carries `{"error": ...}` for the caller to surface.
  Future<void> setProvider({required ProviderMode mode}) =>
      _post('/api/admin/provider', {'provider': mode.name});
}

class RoomConnectionException implements Exception {
  const RoomConnectionException();
  @override
  String toString() => 'room SSE connection failed';
}

class RoomPostException implements Exception {
  RoomPostException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'room POST failed (HTTP $statusCode): $body';
}
