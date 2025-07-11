// Copyright (c) 2020, Tim Whiting. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'constants.dart';

/// A DartPad widget
class DartPad extends StatefulWidget {
  const DartPad({
    required Key key,
    this.embeddingChoice = EmbeddingChoice.dart,
    this.width = 600,
    this.height = 600,
    this.darkMode = true,
    this.runImmediately = false,
    this.nullSafety = true,
    this.split,
    this.code = "void main() { print('Hello World');}",
    this.testCode,
    this.solutionCode,
    this.hintText,
  })  : assert(split == null || (split <= 100 && split >= 0)),
        super(key: key);

  /// The desired width of the dart pad widget.
  final double width;

  /// The desired height of the dart pad widget.
  final double height;

  /// The kind of dart pad widget to be generated.
  ///
  /// See: https://github.com/dart-lang/dart-pad/wiki/Embedding-Guide#embedding-choices
  final EmbeddingChoice embeddingChoice;

  /// Whether the widget should use dark mode styling.
  final bool darkMode;

  /// Whether the specified code should be run as soon as the widget is loaded.
  final bool runImmediately;

  /// Whether the editor should use null-safe dart.
  final bool nullSafety;

  /// The code to pre-load into the dart pad editor.
  ///
  /// To make [code] runnable, include a `main()` function in it. Note that
  /// [code] and the following optional [testCode] parameter will be run as if
  /// they were in the same file so should only define `main()` in one of the
  /// two.
  final String code;

  /// Optional test code that can be displayed in the editor and used to
  /// reference and test the behavior of [code].
  ///
  /// This will run as if it were in the same file as [code] so you can
  /// reference any content in [code] from here. To run the tests, include a
  /// `main()` function here that calls them and do not include a main function
  /// in [code].
  ///
  /// Code here will have access to a hidden method:
  ///   `void _result(bool didPass, [List<String> failureMessages])`
  /// Call result with true to indicate that the test passed. Call it with false
  /// and optional failure messages to indicate that the test failed and why it
  /// failed.
  ///
  /// To view tests, users have to tap on the triple dot button in the editor
  /// and toggle their visibility.
  final String? testCode;

  /// Optional solution code.
  ///
  /// This is intended for codelab content where you are testing a user and
  /// want to show them the correct answer if they wish to see it.
  ///
  /// The solution code should be code that will make [testCode] pass.
  final String? solutionCode;

  /// Text that can be displayed as a message in the editor.
  ///
  /// This is intended for codelab content where you are testing
  /// a user's knowledge and want to give them an optional hint to help them
  /// solve the challenge.
  final String? hintText;

  /// The proportion of space (0-100) to give to code entry in the editor UI.
  ///
  /// For example, a value of 60 will fill the left 60% of the editor with code
  /// entry and the right 40% with console or UI output.
  final int? split;

  @override
  _DartPadState createState() => _DartPadState();

  String get iframeSrc {
    Uri uri = Uri.https(
      kDartPadHost,
      _embeddingChoiceToString(embeddingChoice),
      <String, String>{
        kThemeKey: darkMode ? kDarkMode : kLightMode,
        kRunKey: runImmediately.toString(),
        if (split != null) kSplitKey: split.toString(),
        kNullSafetyKey: nullSafety.toString(),
        kAnalyticsKey: key.toString(),
      },
    );
    return uri.toString();
  }

  Map<String, String> get sourceCodeFileMap {
    return {
      'main.dart': code,
      if (testCode != null) 'test.dart': testCode!,
      if (solutionCode != null) 'solution.dart': solutionCode!,
      if (hintText != null) 'hint.txt': hintText!,
    };
  }
}

class _DartPadState extends State<DartPad> {
  late web.HTMLIFrameElement iframe;

  final String _targetOrigin = 'https://dartpad.dev';

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
    ui.platformViewRegistry
        .registerViewFactory('dartpad${widget.key}', (int viewId) => iframe);

    // **Listen for the 'ready' message from the iframe**
    web.window.addEventListener(
        'message',
        (web.MessageEvent event) {
          // Ensure the the origin is correct
          // if (event.origin == _targetOrigin) {
            final data = event.data.dartify() as Map;

            // DartPad sends a JS object with a 'type' property
            // When DartPad is ready, send the source code
            if (data['type'] == 'ready') {
              print('DartPad is ready. Sending source code...');
              final message = {
                'sourceCode': widget.sourceCodeFileMap,
                'type': 'sourceCode',
              };
              // iframe.contentWindow
              //     ?.postMessage(message.jsify(), _targetOrigin.toJS);
              iframe.contentWindow
                  ?.postMessage(message.jsify(), '*'.toJS);
            }
          // }
        }.toJS);

    // web.window.addEventListener(
    //     'message',
    //     (web.MessageEvent e) {
    //       final responseData = e.data.dartify() as Map;
    //
    //       if (responseData['type'] == 'ready') {
    //         var message = {
    //           'sourceCode': widget.sourceCodeFileMap,
    //           'type': 'sourceCode'
    //         };
    //         final contentWindow = iframe.contentWindow;
    //         contentWindow!.postMessage(message.jsify(), '*'.toJS);
    //       }
    //       // if (e is web.MessageEvent && e.data?['type'] == 'ready') {
    //       //   var m = {'sourceCode': widget.sourceCodeFileMap, 'type': 'sourceCode'};
    //       //   iframe.contentWindow!.postMessage(m, '*');
    //       // }
    //     }.toJS);

    // ui.platformViewRegistry
    //     .registerViewFactory('dartpad${widget.key}', (int viewId) => iframe);
    // html.window.addEventListener('message', (e) {
    //   if (e is html.MessageEvent && e.data['type'] == 'ready') {
    // var m = {'sourceCode': widget.sourceCodeFileMap, 'type': 'sourceCode'};
    // iframe.contentWindow!.postMessage(m, '*');
    // }
    // });
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

/// The embedding type to use with dart pad.
///
/// See: https://github.com/dart-lang/dart-pad/wiki/Embedding-Guide#embedding-choices
enum EmbeddingChoice {
  dart,
  inline,
  flutter,
  html,
}

String _embeddingChoiceToString(EmbeddingChoice embeddingChoice) {
  late String choiceText;
  switch (embeddingChoice) {
    case EmbeddingChoice.dart:
      choiceText = 'dart';
      break;
    case EmbeddingChoice.inline:
      choiceText = 'inline';
      break;
    case EmbeddingChoice.flutter:
      choiceText = 'flutter';
      break;
    case EmbeddingChoice.html:
      choiceText = 'html';
      break;
  }
  return 'embed-$choiceText.html';
}
