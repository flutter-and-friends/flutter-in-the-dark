import 'dart:async';

import 'package:fitd26/room/room_client.dart';
import 'package:fitd26/room/room_models.dart';
import 'package:fitd26/widgets/compiled_widget.dart';
import 'package:fitd26/widgets/plasma_loader.dart';
import 'package:flutter/material.dart';

/// One challenger's content pane per the admin's tri-state selection
/// (Prompt | Code | Widget), with the loading state shown when the admin
/// flips to Code/Widget before generation+compile is `ready` (§6.C).
///
/// Used identically on `/show` and on the contestant's own done screen —
/// same render, same instant.
class ChallengerContent extends StatelessWidget {
  const ChallengerContent({
    super.key,
    required this.challenger,
    required this.content,
    this.expanded = false,
    this.autoScroll = false,
  });

  final Challenger challenger;
  final DisplayContent content;

  /// Bigger type for the single-player view.
  final bool expanded;

  /// Slow ping-pong auto-scroll for the code pane — used on the projector
  /// view (/show) where nobody can touch the screen. Off by default so
  /// interactive screens (the contestant's own view) keep manual control.
  final bool autoScroll;

  @override
  Widget build(BuildContext context) {
    final fontSize = expanded ? 24.0 : 14.0;
    return switch (content) {
      DisplayContent.prompt => _PromptPane(
        prompt: challenger.prompt,
        fontSize: fontSize,
      ),
      DisplayContent.code => _readyOrLoading(
        challenger,
        (code) => _CodePane(
          code: code,
          fontSize: fontSize,
          autoScroll: autoScroll,
        ),
      ),
      DisplayContent.widget => _readyOrLoading(
        challenger,
        (_) => _WidgetPane(challenger: challenger),
      ),
    };
  }

  Widget _readyOrLoading(
    Challenger challenger,
    Widget Function(String code) builder,
  ) {
    return switch (challenger.genState) {
      GenState.ready => builder(challenger.generatedCode ?? ''),
      GenState.failed => _FailedPane(error: challenger.error),
      _ => PlasmaLoader(
        label: switch (challenger.genState) {
          GenState.queued => 'Queued for generation…',
          GenState.generating => 'Generating code…',
          GenState.compiling => 'Compiling…',
          _ => 'Waiting…',
        },
      ),
    };
  }
}

class _PromptPane extends StatelessWidget {
  const _PromptPane({required this.prompt, required this.fontSize});

  final String prompt;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (prompt.isEmpty) {
      return Center(
        child: Text(
          'Thinking in the dark…',
          style: TextStyle(
            color: Colors.white24,
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      reverse: true,
      padding: const EdgeInsets.all(16),
      child: Text(
        prompt,
        style: TextStyle(
          fontFamily: 'monospace',
          color: const Color(0xFFE6EDF3),
          fontSize: fontSize,
          height: 1.5,
        ),
      ),
    );
  }
}

class _CodePane extends StatefulWidget {
  const _CodePane({
    required this.code,
    required this.fontSize,
    this.autoScroll = false,
  });

  final String code;
  final double fontSize;

  /// When true (the /show projector view), the pane drifts slowly down to
  /// the bottom, pauses, drifts back up, and repeats. When false (the
  /// contestant's interactive view), scrolling is left to the user.
  final bool autoScroll;

  @override
  State<_CodePane> createState() => _CodePaneState();
}

class _CodePaneState extends State<_CodePane> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  /// Direction of the current run: `1` drifts down, `-1` drifts back up.
  int _direction = 1;

  /// Ticks remaining in the dwell at the current extreme (plus a beat at
  /// startup before the first drift). Tracked in ticks rather than wall
  /// clock so the driver is frame-deterministic and testable.
  int _dwellTicks = 0;

  /// Timer period: one driver per pane (up to ~16 coexist on /show),
  /// following the same `_clockTimer` Timer.periodic pattern the screens
  /// use. 20 ticks/s keeps the drift smooth on a projector.
  static const _tick = Duration(milliseconds: 50);
  static const _startupDwellTicks = 90; // 4.5s at the top before first drift
  static const _extremeDwellTicks = 120; // 6s pause at each end before reversing

  /// Logical px per tick — 36px/s, projector-slow, tens of seconds for a
  /// full traverse of typical generated code.
  static const _stepPx = 1.8;

  /// Start or stop the driver when the autoScroll flag changes.
  @override
  void initState() {
    super.initState();
    if (widget.autoScroll) _startAutoScroll();
  }

  @override
  void didUpdateWidget(_CodePane oldWidget) {
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

    // Content shorter than the viewport: nothing to scroll.
    if (position.maxScrollExtent <= 0) return;

    // Dwelling at an extreme (or the startup beat).
    if (_dwellTicks > 0) {
      _dwellTicks--;
      return;
    }

    var target = position.pixels + _direction * _stepPx;
    final down = _direction > 0;
    if ((down && target >= position.maxScrollExtent) ||
        (!down && target <= position.minScrollExtent)) {
      // Clamp at the extreme and dwell there before reversing. Clamping a
      // shrunk extent also keeps stale targets safe when the code updates
      // mid-scroll (the controller clamps its own position too).
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
      return const PlasmaLoader(label: 'Waiting for code…');
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

class _WidgetPane extends StatelessWidget {
  const _WidgetPane({required this.challenger});

  final Challenger challenger;

  @override
  Widget build(BuildContext context) {
    final url = challenger.compiledUrl;
    if (url == null) {
      return const PlasmaLoader(label: 'Waiting for compiled app…');
    }
    return CompiledWidget(url: '${RoomClient.compileBaseUrl}$url');
  }
}

class _FailedPane extends StatelessWidget {
  const _FailedPane({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Generation failed',
              style: TextStyle(color: Colors.redAccent, fontSize: 18),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
