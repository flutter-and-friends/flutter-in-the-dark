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
/// Pointer-blocking is gated separately from visibility: the overlay BLOCKS
/// input in the waiting phase (the pre-warmed iframe underneath must not be
/// interactable before the challenge starts) and again from the burn window
/// onward (the challenge is over by then) — but NOT while the 10→1
/// countdown is merely visible, when the challenge underneath is still live
/// (the player must be able to keep typing). See
/// [BurnRevealController.isBlocking].
///
/// The host screen still owns its wall-clock ticker; it feeds every tick to
/// [BurnRevealController.tick], which starts/stops the burn
/// [AnimationController] — a Listenable, so the handoff repaints even when
/// no SSE event arrives at the boundary (I-008).
///
/// Rendering: the overlay is drawn by [BurnShaderOverlay]
/// (`widgets/burn_shader.dart`) — a single `CustomPaint` + `FragmentProgram`
/// that computes the hole/char/flame per-pixel. It replaced the
/// `ShaderMask`+`BlendMode.dstOut` mask (`widgets/burn_effects.dart`, kept
/// as the `/burn_test` A/B baseline), which re-rasterized the full-screen
/// hole via `PictureRecorder.toImageSync` on every frame AND forced a
/// full-screen dstOut saveLayer — the measured source of the 20–90 ms burn
/// frames (now ~10 ms p50).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/burn_edge.dart';
import 'package:flutter_in_the_dark/helpers/burn_knobs.dart';
import 'package:flutter_in_the_dark/helpers/burn_phase.dart';
import 'package:flutter_in_the_dark/widgets/burn_shader.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:web/web.dart' as web;

/// Debug-only knobs, read once from the page's query string:
///  - `?burnDebug=1` adds a replay button on top of the overlay,
///  - `?burnSlow=<x>` multiplies the burn duration (e.g. `burnSlow=5`),
///  - `?burnHold=<0..1>` freezes the burn animation at an exact fraction
///    (the wall-clock handoff is suspended; the overlay stays up burning at
///    that progress forever) — for steering/screenshotting the look,
///  - `?burnSeconds=<x>` moves the burn window (and the pointer-block gate)
///    off the wall-clock end (e.g. `burnSeconds=15` burns 15→14 s), so the
///    non-blocking countdown can be verified on a live challenge.
///
/// These exist so the ~1 s animation can be captured/screenshot; they are
/// inert without the query params and must never be wired to real UI. The
/// parsing itself is the shared [BurnKnobs] (SHADOW-005: one parser, used
/// by both this overlay and `/burn_test`).
class BurnDebug {
  BurnDebug._();

  static final BurnKnobs _knobs =
      BurnKnobs.parse(web.window.location.search);

  static bool get enabled => _knobs.debug;

  static double get slowFactor => _knobs.slowFactor;

  /// When non-null the burn is held at exactly this progress (0–1) and the
  /// countdown → reveal handoff is suspended. Debug-only.
  static double? get holdAt => _knobs.holdAt;

  /// Debug-only: the burn window's position on the countdown. Defaults to
  /// [kBurnSeconds] — anchored at the wall-clock end, as production.
  static double get burnSeconds => _knobs.burnSeconds ?? kBurnSeconds;
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

  /// Whether the countdown overlay currently BLOCKS pointer/keyboard input
  /// to what is beneath it. True from the burn window onward (which spans
  /// the zero crossing — see [tick]): the challenge is over by the time the
  /// player could react to the burn, so nothing of theirs is lost. False
  /// during the visible 10→1 countdown: the challenge is still live there
  /// and the player must be able to keep typing underneath the countdown.
  bool get isBlocking => _countingDown && _blocking;

  bool _blocking = false;

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
      _setBlocking(true); // a held burn is by definition the blocking window
      return;
    }

    if (seconds > kCountdownSeconds) return; // still waiting

    // The burn window on the countdown (normally the last kBurnSeconds
    // before zero; the debug burnSeconds knob can move it earlier). The
    // window's tail crosses the wall-clock end, so the overlay turns
    // BLOCKING from its start: the player could not meaningfully finish an
    // edit in the sub-second left, and the server has already closed the
    // round by the time the burn reads as started (W-017).
    final burnStart = BurnDebug.burnSeconds;
    final burnEnd = burnStart - kBurnSeconds;

    _enterCountdown(seconds);
    _setBlocking(seconds <= burnStart);

    // Countdown over: snap to done even if the animation never ran (a fully
    // backgrounded tab — or a debug-steered `?burnSeconds=` burn that
    // already played early — can jump straight past the window; W-017).
    if (seconds <= 0) {
      _burn!.value = 1;
      _completeBurn();
      return;
    }

    // Burning window: drive the controller toward the wall-clock progress.
    // The controller gives smooth 60 fps motion in the foreground; the
    // direct value assignment keeps the END STATE exact when frames are
    // dropped (backgrounded-tab throttling — W-017).
    if (seconds <= burnStart && seconds > burnEnd) {
      final target =
          1.0 - ((seconds - burnEnd) / kBurnSeconds).clamp(0.0, 1.0);
      final burn = _burn!;
      if (!burn.isAnimating) {
        burn.forward();
      }
      if (target > burn.value) {
        burn.value = target;
      }
    }
  }

  void _setBlocking(bool value) {
    if (_blocking == value) return;
    _blocking = value;
    notifyListeners();
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
    _blocking = true; // a replayed burn is the blocking window
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
        // Pointer-blocking is gated separately from visibility: while the
        // 10→1 countdown is merely VISIBLE the challenge is still live, so
        // the layer beneath (on the player's screen, the live PromptEditor)
        // must keep focus and accept input — the overlay ignores pointers
        // and hit-tests transparent so it neither swallows clicks nor keeps
        // pointer_interceptor's invisible platform view alive (that view
        // would blur the text field on web). Only from the burn window
        // onward (which spans the zero crossing) does the overlay block —
        // the challenge is over by then.
        final blocking = controller.isBlocking;
        final overlay = Stack(
          fit: StackFit.expand,
          children: [
            // The shader overlay IS the "paper" that burns: it draws the
            // opaque background + the jagged hole + char + flame in ONE
            // fragment-shader pass (no dstOut saveLayer, no per-frame
            // rasterization). The countdown display is stacked ABOVE it
            // inside BurnShaderOverlay and faded out as ignition starts
            // (a shader can't draw widget text — see that class). The
            // layer blocks pointer input only once the burn window is up —
            // before that the countdown underneath is still live.
            AbsorbPointer(
              absorbing: blocking,
              child: BurnShaderOverlay(
                progress: progress,
                edge: edge,
                countdownBuilder: countdownBuilder,
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
        );
        return IgnorePointer(
          ignoring: !blocking,
          child: blocking
              ? PointerInterceptor(child: overlay)
              : overlay,
        );
      },
    );
  }
}
