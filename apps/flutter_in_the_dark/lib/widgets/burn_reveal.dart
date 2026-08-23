/// Pre-warm + burn-reveal scaffolding for the challenge iframe.
///
/// The challenge iframe (`/compiled/<id>`) used to be mounted only when the
/// countdown reached zero, so the audience and the contestants stared at a
/// loading frame for several seconds while dart_services' compiled app
/// booted. [BurnRevealOverlay] mounts the iframe EARLY — as soon as the challenge
/// (and thus its `widgetUrl`) is known — underneath a full-screen countdown
/// overlay. The iframe loads hidden while the countdown runs; when the
/// countdown completes, the overlay does not simply vanish: it burns away
/// from the center outward (~1 s, see [sampleBurn]) revealing the
/// already-loaded challenge instantly.
///
/// Phase machine (driven by an explicit ticker, never a bare
/// `DateTime.now()` in `build` — I-008):
///
/// ```text
/// waiting ──(remaining ≤ 10 s)──▶ countdown (overlay opaque, iframe hidden)
/// countdown ──(remaining ≤ 1 s)──▶ burning (overlay burns center-out)
/// burning ──(remaining ≤ 0 / controller done)──▶ revealed (overlay gone)
/// ```
///
/// The host screen still owns its wall-clock ticker; it feeds every tick to
/// [BurnRevealController.tick], which starts/stops the burn
/// [AnimationController] — a Listenable, so the handoff repaints even when
/// no SSE event arrives at the boundary (I-008).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/burn_edge.dart';
import 'package:flutter_in_the_dark/helpers/burn_phase.dart';
import 'package:flutter_in_the_dark/widgets/burn_effects.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:web/web.dart' as web;

/// Debug-only knobs, read once from the page's query string:
///  - `?burnDebug=1` adds a replay button on top of the overlay,
///  - `?burnSlow=<x>` multiplies the burn duration (e.g. `burnSlow=5`),
///  - `?burnHold=<0..1>` freezes the burn animation at an exact fraction
///    (the wall-clock handoff is suspended; the overlay stays up burning at
///    that progress forever) — for steering/screenshotting the look.
///
/// These exist so the ~1 s animation can be captured/screenshot; they are
/// inert without the query params and must never be wired to real UI.
class BurnDebug {
  BurnDebug._();

  static final bool enabled =
      web.window.location.search.contains('burnDebug=1');

  static final double slowFactor = _parseSlow();

  /// When non-null the burn is held at exactly this progress (0–1) and the
  /// countdown → reveal handoff is suspended. Debug-only.
  static final double? holdAt = _parseHold();

  static double _parseSlow() {
    final match = RegExp('[?&]burnSlow=([0-9.]+)').firstMatch(
      web.window.location.search,
    );
    final value = double.tryParse(match?.group(1) ?? '');
    if (value == null || value <= 0) return 1;
    return value;
  }

  static double? _parseHold() {
    final match = RegExp('[?&]burnHold=([0-9.]+)').firstMatch(
      web.window.location.search,
    );
    final value = double.tryParse(match?.group(1) ?? '');
    if (value == null) return null;
    return value.clamp(0.0, 1.0);
  }
}

/// The countdown → burn → revealed phase machine. Pure Listenable glue: the
/// host ticks it with the remaining time, it drives the burn animation.
class BurnRevealController extends ChangeNotifier {
  BurnRevealController({required TickerProvider vsync}) : _vsync = vsync;

  final TickerProvider _vsync;
  AnimationController? _burn;

  bool _countingDown = false;
  bool _revealed = false;

  /// The jagged burn edge for the CURRENT burn. Re-seeded every time a
  /// burn starts (`_enterCountdown`, `debugReplay`) so no two burns share
  /// a silhouette, and fixed for the burn's duration so the shape scales
  /// outward with progress without shimmering. Null before the first burn.
  BurnEdge? burnEdge;

  /// Whether the 10→0 countdown overlay is up (opaque or burning).
  bool get isCountingDown => _countingDown;

  /// Whether the burn animation is running.
  bool get isBurnAnimating => _burn?.isAnimating ?? false;

  /// Whether the overlay is gone for good.
  bool get isRevealed => _revealed;

  /// The burn animation (0→1). Null until the countdown phase is entered.
  Animation<double>? get burn => _burn?.view;

  /// Feed the latest remaining time. Idempotent — cheap to call on every
  /// wall-clock tick and every SSE-driven rebuild.
  void tick(Duration remaining) {
    if (_revealed) return;
    final seconds = remaining.inMilliseconds / 1000.0;

    // Debug-only hold: pretend the clock is parked at the held burn
    // fraction so the overlay stays up, burning at exactly that progress,
    // regardless of the real remaining time. The countdown phase must be
    // entered first (a hold implies the burn is visually active).
    final hold = BurnDebug.holdAt;
    if (hold != null) {
      _enterCountdown(seconds <= 0 ? kBurnSeconds : seconds);
      _burn!.value = hold;
      return;
    }

    if (seconds > kCountdownSeconds) return; // still waiting

    _enterCountdown(seconds);

    // Countdown over: snap to done even if the animation never ran (a fully
    // backgrounded tab can jump straight past the burn window — W-017).
    if (seconds <= 0) {
      _burn!.value = 1;
      _completeBurn();
      return;
    }

    // Burning window: drive the controller toward the wall-clock progress.
    // The controller gives smooth 60 fps motion in the foreground; the
    // direct value assignment keeps the END STATE exact when frames are
    // dropped (backgrounded-tab throttling — W-017).
    if (isBurning(seconds)) {
      final target = burnProgress(seconds);
      final burn = _burn!;
      if (!burn.isAnimating) {
        burn.forward();
      }
      if (target > burn.value) {
        burn.value = target;
      }
    }
  }

  /// Enter the countdown phase (idempotent): create the burn controller
  /// sized to the countdown we actually got (a < 1 s countdown gets a
  /// shortened burn, so the transition never outlasts the countdown
  /// itself).
  void _enterCountdown(double seconds) {
    if (_countingDown) return;
    _countingDown = true;
    // A fresh silhouette for this burn (also on the debug-hold path, which
    // enters through here): one seed for the burn's whole duration.
    burnEdge = BurnEdge(seed: math.Random().nextInt(1 << 31));
    _burn = AnimationController(
      vsync: _vsync,
      duration: burnWindowFor(seconds) * BurnDebug.slowFactor,
    )..addStatusListener(_onBurnStatus);
    notifyListeners();
  }

  void _onBurnStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _completeBurn();
  }

  void _completeBurn() {
    if (_revealed) return;
    _revealed = true;
    _countingDown = false;
    notifyListeners();
  }

  /// Debug-only ([BurnDebug.enabled]): reset to the pre-burn state and run
  /// the burn again. Never called from production UI.
  void debugReplay() {
    if (_burn == null) return;
    _revealed = false;
    _countingDown = true;
    // Re-seed so every replay burns a different silhouette.
    burnEdge = BurnEdge(seed: math.Random().nextInt(1 << 31));
    _burn!.forward(from: 0);
    notifyListeners();
  }

  @override
  void dispose() {
    _burn?.dispose();
    super.dispose();
  }
}

/// Full-screen overlay hosting the pre-countdown waiting display, the
/// countdown display, and the burn-away reveal. Stack this ON TOP of the
/// pre-mounted challenge iframe and tick the [controller] from the host's
/// wall-clock timer.
class BurnRevealOverlay extends StatelessWidget {
  const BurnRevealOverlay({
    super.key,
    required this.controller,
    required this.remaining,
    this.waitingBuilder,
    required this.countdownBuilder,
  });

  final BurnRevealController controller;

  /// Latest remaining time (for the countdown display).
  final Duration remaining;

  /// Builds the opaque pre-countdown display (e.g. "Starting in 3 minutes").
  /// Null when there is no waiting phase (the end-of-challenge gate on
  /// /show): the overlay is then transparent until the countdown starts.
  final WidgetBuilder? waitingBuilder;

  /// Builds the normal countdown display (big numbers etc.).
  final WidgetBuilder countdownBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isRevealed) return const SizedBox.shrink();
        if (!controller.isCountingDown) {
          // Pre-countdown (waiting) phase: opaque and pointer-blocking so
          // the pre-warmed iframe underneath is neither visible nor
          // interactable. PointerInterceptor is required because the layer
          // below is an HtmlElementView (iframe) — a plain GestureDetector
          // does not swallow pointer events that the browser delivers
          // straight to the iframe's document.
          final waiting = waitingBuilder?.call(context);
          if (waiting == null) return const SizedBox.shrink();
          return PointerInterceptor(
            child: AbsorbPointer(child: waiting),
          );
        }
        final burn = controller.burn;
        final progress = burn?.value ?? 0;
        // The jagged edge for this burn, seeded by the controller when the
        // countdown phase started (a burn implies a seed exists).
        final edge = controller.burnEdge ??
            BurnEdge(seed: math.Random().nextInt(1 << 31));
        return PointerInterceptor(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The countdown display is the "paper": the BurnHoleMask
              // erases the jagged burned hole through IT (numbers char and
              // ignite along with the background), and the painter draws
              // char + flame on top ALONG THE SAME contour. The layer
              // keeps blocking pointer input until it is gone — the
              // countdown is not over yet.
              AbsorbPointer(
                child: BurnHoleMask(
                  progress: progress,
                  edge: edge,
                  // Opaque base so the semi-transparent countdown display
                  // (CountdownOverlay is black54) still fully hides the
                  // pre-warmed iframe until the burn opens a hole.
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: countdownBuilder(context),
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: BurnPainter(progress: progress, edge: edge),
                  child: const SizedBox.expand(),
                ),
              ),
              if (BurnDebug.enabled)
                Positioned(
                  top: 8,
                  right: 8,
                  // Debug-only: outside the AbsorbPointer so the replay
                  // button stays clickable.
                  child: FloatingActionButton.small(
                    heroTag: 'burn-debug-replay',
                    onPressed: controller.debugReplay,
                    child: const Icon(Icons.replay),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
