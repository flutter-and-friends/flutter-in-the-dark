/// The /show projector overlay widgets: the remaining-time pill and the
/// end-of-challenge "TIME OVER!" flash.
///
/// These live in `widgets/` (not privately in `show_screen.dart`) so the
/// standalone `/burn_test` page can render the REAL widgets for steering
/// and screenshot verification without standing up room_service — and so
/// this file stays free of `room_client.dart`/`dart:js_interop` (W-012:
/// `show_screen.dart` is inside the untestable import cone; this file is
/// not). Behaviour stays delegated to the pure helpers
/// (`helpers/time_over.dart`, `timeago`), which ARE unit-tested.
library;

import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/time_over.dart';
import 'package:timeago_flutter/timeago_flutter.dart';

/// The remaining time as a small pill on the top edge. Replaces the old
/// centered 48 pt "Time remaining: N minutes" band, which sat across the
/// middle of the screen and collided with the content (code panes)
/// underneath. It self-hides in the last 10 s, when the full-screen
/// countdown → burn takes over, and once the challenge is over.
class ShowTimerPill extends StatelessWidget {
  const ShowTimerPill({super.key, required this.endTime});

  final DateTime endTime;

  @override
  Widget build(BuildContext context) {
    return Timeago(
      refreshRate: const Duration(seconds: 1),
      date: endTime.toLocal(),
      allowFromNow: true,
      builder: (context, time) {
        final remainingTime = endTime.difference(DateTime.now());
        if (remainingTime.inSeconds <= 10) {
          return const SizedBox.shrink();
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The one-shot pop for the banner text. Extracted so the 10 Hz ticker in
/// [TimeOverBanner] only gates visibility; this widget plays its scale-up
/// exactly once when mounted and then holds steady.
class _TimeOverPop extends StatefulWidget {
  const _TimeOverPop({super.key});

  @override
  State<_TimeOverPop> createState() => _TimeOverPopState();
}

class _TimeOverPopState extends State<_TimeOverPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void initState() {
    super.initState();
    // Start the pop AFTER the first frame: an AnimationController that
    // begins forwarding during the widget's very first build can leave the
    // subtree un-painted on a headless/software renderer that has no live
    // vsync yet — the frame that would carry the text never commits. A
    // post-frame forward guarantees the text is laid out first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pop.forward();
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scale-to-fit: the 200 pt size is a CEILING, not a floor. On a
    // projector/desktop the text fills toward the full width at ~200 pt;
    // on a narrow phone it shrinks (never wraps/clips — the raw hardcoded
    // 200 pt overflowed a phone-width screen and splintered the letters
    // across lines). The cap box bounds the text to the viewport width
    // (with margin), FittedBox does the shrink-to-fit, and the single
    // 18 px glow shadow is kept as-is (a 48 px-blur stack crashes
    // SwiftShader's software rasterizer — that constraint stands).
    final maxWidth = MediaQuery.sizeOf(context).width - 32;
    return ScaleTransition(
      scale: CurvedAnimation(parent: _pop, curve: Curves.easeOutBack)
          .drive(Tween(begin: 0.55, end: 1.0)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'TIME OVER!',
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 200,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: Color(0xFFFF5252),
              shadows: [Shadow(blurRadius: 18, color: Color(0xBBFF1744))],
            ),
          ),
        ),
      ),
    );
  }
}

/// The end-of-challenge flash: "TIME OVER!" pops SHORT and LARGE (bigger
/// than the old persistent red line), then auto-dismisses after
/// [kTimeOverBannerDuration] so the finished content underneath is visible
/// again.
///
/// The dismiss is pushed by the HOST's wall-clock ticker (show_screen's
/// `_clockTimer` already rebuilds this subtree at 100 ms–1 s cadence), so
/// this widget carries NO `Timer` of its own — a build()-time
/// `DateTime.now()` gate is still only *evaluated* here, never *driven*
/// from here (I-008/I-017). The pop is a one-shot animation keyed to the
/// moment the banner mounts (see [_TimeOverPop]); the host's rebuilds only
/// flip the visibility gate, never restart the tween (a
/// TweenAnimationBuilder under a periodic setState would re-run its
/// builder every tick, which on SwiftShader/headless is fatal). The pop
/// settles and DWELLS (I-021: a projector spends its motion budget on
/// clear states, not on easing choreography).
class TimeOverBanner extends StatelessWidget {
  const TimeOverBanner({super.key, required this.endTime});

  final DateTime endTime;

  @override
  Widget build(BuildContext context) {
    final remaining = endTime.difference(DateTime.now());
    if (!shouldShowTimeOver(remaining)) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(child: _TimeOverPop(key: ValueKey(endTime))),
    );
  }
}
