import 'dart:js_interop';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Chromeless iframe rendering a self-hosted compiled Flutter app
/// (`{compileBase}/compiled/<id>`), replacing the dartpad.dev embed.
///
/// Also used for pre-compiled challenge widgets (§6.F) — same serving path.
///
/// Runtime errors from the frame arrive as postMessage
/// `{sender:'fitd-frame', type:'jserr'|'stderr'|'stdout', message}` and are
/// surfaced through [onError].
class CompiledWidget extends StatefulWidget {
  const CompiledWidget({super.key, required this.url, this.onError});

  /// Full URL of the compiled app (path-absolute `url` from compileAndServe
  /// resolved against the generation backend).
  final String url;

  final void Function(String message)? onError;

  @override
  State<CompiledWidget> createState() => _CompiledWidgetState();
}

class _CompiledWidgetState extends State<CompiledWidget> {
  late final web.HTMLIFrameElement _iframe;
  late final String _viewType;
  JSFunction? _messageHandler;

  static int _instanceCounter = 0;

  @override
  void initState() {
    super.initState();
    _viewType = 'fitd-compiled-${_instanceCounter++}';
    _iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src = widget.url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'autoplay';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );

    _messageHandler = ((web.Event event) {
      final message = event as web.MessageEvent;
      final data = message.data;
      if (!data.isA<JSObject>()) return;
      final map = (data as JSObject).dartify();
      if (map is Map &&
          map['sender'] == 'fitd-frame' &&
          (map['type'] == 'jserr' || map['type'] == 'stderr')) {
        widget.onError?.call(map['message']?.toString() ?? 'unknown');
      }
    }).toJS;
    web.window.addEventListener('message', _messageHandler!);
  }

  @override
  void dispose() {
    if (_messageHandler != null) {
      web.window.removeEventListener('message', _messageHandler!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
