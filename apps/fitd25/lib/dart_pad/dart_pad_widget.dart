// Copyright (c) 2020, Tim Whiting. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// A DartPad widget
class DartPad extends StatefulWidget {
  const DartPad({
    required Key key,
    this.width = 600,
    this.height = 600,
    this.darkMode = true,
    this.runImmediately = false,
    required this.gistId,
    this.split,
  }) : assert(split == null || (split <= 100 && split >= 0)),
       super(key: key);

  /// The ID of the DartPad gist to display.
  final String gistId;

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
    Uri uri = Uri.https('dartpad.dev', '', <String, String>{
      'id': gistId,
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

  @override
  void didUpdateWidget(DartPad oldWidget) {
    super.didUpdateWidget(oldWidget);

    iframe.style.width = widget.width.toInt().toString();
    iframe.style.height = widget.height.toInt().toString();
    iframe.setAttribute('style', widget.iframeStyle);
  }

  @override
  void initState() {
    super.initState();

    iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src = widget.iframeSrc
      ..style.border = 'none'
      ..style.width = '${widget.width}px'
      ..style.height = '${widget.height}px';

    iframe.style.width = widget.width.toInt().toString();
    iframe.style.height = widget.height.toInt().toString();

    // Register the iframe with Flutter's view registry
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'dartpad${widget.key}',
      (int viewId) => iframe,
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
