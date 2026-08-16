// Copyright (c) 2020, Tim Whiting. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// A DartPad widget.
///
/// Two modes:
/// - gist mode (fitd25 behavior): [gistId] non-null loads that gist.
/// - gist-less mode (fitd26): [gistId] null loads plain dartpad.dev with
///   `run=true`; the generated code is then pushed into the iframe with
///   `postMessage({type:'sourceCode', sourceCode})` once the iframe reports
///   load. Parent→child only — nothing is readable back out of the
///   cross-origin frame (documented dead end, do not try to read state).
class DartPad extends StatefulWidget {
  const DartPad({
    required Key key,
    this.width = 600,
    this.height = 600,
    this.darkMode = true,
    this.runImmediately = false,
    this.gistId,
    this.initialCode,
    this.split,
  }) : assert(split == null || (split <= 100 && split >= 0)),
       super(key: key);

  /// The ID of the DartPad gist to display, or null for gist-less mode.
  final String? gistId;

  /// Code to push into the pad via postMessage (gist-less mode only).
  ///
  /// Pushed ONCE, when the iframe finishes loading. Updates to this value
  /// while mounted are deliberately NOT re-posted (that caused a recompile
  /// storm during streaming generation) — remount with a new [key] to push
  /// fresh code.
  final String? initialCode;

  /// The desired width of the dart pad widget.
  final double width;

  /// The desired height of the dart pad widget.
  final double height;

  /// Whether the widget should use dark mode styling.
  final bool darkMode;

  /// Whether the specified code should be run as soon as the widget is loaded.
  final bool runImmediately;

  /// The proportion of space (0-100) to give to code entry in the editor UI.
  ///
  /// For example, a value of 60 will fill the left 60% of the editor with code
  /// entry and the right 40% with console or UI output.
  final int? split;

  @override
  State<DartPad> createState() => _DartPadState();

  String get iframeSrc {
    final uri = Uri.https('dartpad.dev', '', <String, String>{
      if (gistId != null) 'id': gistId!,
      'theme': darkMode ? 'dark' : 'light',
      'run': runImmediately.toString(),
      if (split != null) 'split': split.toString(),
    });
    return uri.toString();
  }

  String get iframeStyle {
    return "width:${width}px;height:${height}px;";
  }
}

class _DartPadState extends State<DartPad> {
  late web.HTMLIFrameElement iframe;

  /// dartpad.dev origin — the only valid targetOrigin for the postMessage.
  static const String _dartPadOrigin = 'https://dartpad.dev';

  @override
  void didUpdateWidget(DartPad oldWidget) {
    super.didUpdateWidget(oldWidget);

    iframe.style.width = widget.width.toInt().toString();
    iframe.style.height = widget.height.toInt().toString();
    iframe.setAttribute('style', widget.iframeStyle);

    // NOTE: intentionally does NOT re-post on [initialCode] changes.
    // During generation the caller streams partial code into state and hands
    // it here; posting each fragment makes dartpad.dev recompile incomplete
    // code (a storm of 400s). Code is pushed ONCE, on iframe load, when the
    // caller mounts a fresh DartPad for the completed result (the screen bumps
    // a reload-token key at completion, remounting this widget). If the code
    // legitimately changes while mounted, the caller should remount with a new
    // key rather than rely on update-posting.
  }

  @override
  void initState() {
    super.initState();

    iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src = widget.iframeSrc
      ..style.border = 'none'
      ..style.width = '${widget.width}px'
      ..style.height = '${widget.height}px';

    iframe.addEventListener(
      'load',
      () {
        // The iframe document has loaded; give the embedded app a moment to
        // attach its message listener, then push the code ONCE.
        if (widget.initialCode != null) {
          Future.delayed(const Duration(seconds: 2), _postSourceCode);
        }
      }.toJS,
    );

    iframe.style.width = widget.width.toInt().toString();
    iframe.style.height = widget.height.toInt().toString();

    // Register the iframe with Flutter's view registry
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'dartpad${widget.key}',
      (int viewId) => iframe,
    );
  }

  /// Pushes the current source code into the DartPad iframe.
  ///
  /// Message shape follows dart_services' own embed API:
  /// `{type: 'sourceCode', sourceCode: <code>}` posted to the dartpad.dev
  /// origin. Best-effort: if the embed does not listen for this message the
  /// send silently no-ops — the caller should surface the raw code too.
  void _postSourceCode() {
    final code = widget.initialCode;
    if (code == null || code.isEmpty) return;
    iframe.contentWindow?.postMessage(
      {'type': 'sourceCode', 'sourceCode': code}.jsify(),
      _dartPadOrigin.toJS,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(viewType: 'dartpad${widget.key}'),
    );
  }
}
