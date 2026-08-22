/// Test harness: the exact widget tree under test, mirrored from
/// `lib/widgets/challenger_content.dart` (_CodePane) so the auto-scroll
/// driver can be exercised under `flutter test`.
///
/// The real _CodePane is private, and its library transitively imports
/// `room_client.dart` → `dart:js_interop` / `package:web`, which cannot
/// compile for the test VM — the whole app is web-only. Keep this copy
/// byte-identical to the lib version; drift is caught on review.
library;

import 'dart:async';

import 'package:flutter/material.dart';

class CodePane extends StatefulWidget {
  const CodePane({
    super.key,
    required this.code,
    required this.fontSize,
    this.autoScroll = false,
  });

  final String code;
  final double fontSize;
  final bool autoScroll;

  @override
  State<CodePane> createState() => _CodePaneState();
}

class _CodePaneState extends State<CodePane> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  int _direction = 1;
  int _dwellTicks = 0;

  static const _tick = Duration(milliseconds: 50);
  static const _startupDwellTicks = 90;
  static const _extremeDwellTicks = 120;
  static const _stepPx = 1.8;

  @override
  void initState() {
    super.initState();
    if (widget.autoScroll) _startAutoScroll();
  }

  @override
  void didUpdateWidget(CodePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoScroll && !oldWidget.autoScroll) {
      _startAutoScroll();
    } else if (!widget.autoScroll && oldWidget.autoScroll) {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    _scrollTimer ??= Timer.periodic(_tick, (_) => _scrollTick());
    _dwellTicks = _startupDwellTicks;
    _direction = 1;
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _dwellTicks = 0;
  }

  void _scrollTick() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;

    if (position.maxScrollExtent <= 0) return;

    if (_dwellTicks > 0) {
      _dwellTicks--;
      return;
    }

    var target = position.pixels + _direction * _stepPx;
    final down = _direction > 0;
    if ((down && target >= position.maxScrollExtent) ||
        (!down && target <= position.minScrollExtent)) {
      target = down ? position.maxScrollExtent : position.minScrollExtent;
      _direction = -_direction;
      _dwellTicks = _extremeDwellTicks;
    }
    position.jumpTo(target);
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.code.isEmpty) {
      return const Center(child: Text('Waiting for code…'));
    }
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        widget.code,
        style: TextStyle(
          fontFamily: 'monospace',
          color: const Color(0xFFE6EDF3),
          fontSize: widget.fontSize * 0.85,
          height: 1.45,
        ),
      ),
    );
  }
}
