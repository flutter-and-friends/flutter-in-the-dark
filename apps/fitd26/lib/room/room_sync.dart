import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'room_client.dart';
import 'room_models.dart';

/// Keeps a live [RoomState] in sync for the whole app.
///
/// Reconnect policy (I-054 iOS lifecycle): wire `visibilitychange` +
/// `pageshow`/`pagehide`; resume is idempotent; on resume we do a catch-up
/// refetch THEN reopen the SSE stream. EventSource's own retry covers brief
/// drops; the lifecycle handlers cover the OS suspending the socket entirely.
class RoomSync extends ChangeNotifier {
  RoomSync({RoomClient? client}) : client = client ?? RoomClient();

  final RoomClient client;

  RoomState? _state;
  RoomState? get state => _state;

  StreamSubscription<RoomState>? _subscription;
  bool _connecting = false;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  JSFunction? _visibilityHandler;
  JSFunction? _pageShowHandler;
  JSFunction? _pageHideHandler;

  void start() {
    _connect();
    _visibilityHandler = ((web.Event _) {
      if (web.document.visibilityState == 'visible') resume();
    }.toJS);
    _pageShowHandler = ((web.Event _) {
      resume();
    }).toJS;
    _pageHideHandler = ((web.Event _) => _closeStream()).toJS;
    web.document.addEventListener('visibilitychange', _visibilityHandler!);
    web.window.addEventListener('pageshow', _pageShowHandler!);
    web.window.addEventListener('pagehide', _pageHideHandler!);
  }

  /// Idempotent resume: catch-up refetch THEN reopen the stream.
  Future<void> resume() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    // 1. Catch-up refetch: apply the authoritative snapshot immediately.
    try {
      final fresh = await client.fetchState();
      _apply(fresh);
    } catch (_) {
      // Offline or service down — the SSE retry loop will surface it.
    }
    // 2. Reopen the stream (idempotent — _connect closes any stale one).
    _connect();
  }

  Future<void> _connect() async {
    if (_disposed || _connecting) return;
    _connecting = true;
    _closeStream();
    try {
      _subscription = client
          .events(lastEventId: _state?.revision)
          .listen(
            _apply,
            onError: (_) => _scheduleReconnect(),
            cancelOnError: false,
          );
      _reconnectAttempts = 0;
    } finally {
      _connecting = false;
    }
  }

  void _closeStream() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectAttempts++;
    final delay = Duration(
      milliseconds: 500 * (_reconnectAttempts.clamp(1, 10)),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, resume);
  }

  void _apply(RoomState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _closeStream();
    if (_visibilityHandler != null) {
      web.document.removeEventListener('visibilitychange', _visibilityHandler!);
    }
    if (_pageShowHandler != null) {
      web.window.removeEventListener('pageshow', _pageShowHandler!);
    }
    if (_pageHideHandler != null) {
      web.window.removeEventListener('pagehide', _pageHideHandler!);
    }
    super.dispose();
  }
}
