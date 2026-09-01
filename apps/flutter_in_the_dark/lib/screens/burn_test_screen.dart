import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/burn_edge.dart';
import 'package:flutter_in_the_dark/helpers/burn_knobs.dart';
import 'package:flutter_in_the_dark/helpers/burn_phase.dart';
import 'package:flutter_in_the_dark/widgets/burn_effects.dart';
import 'package:flutter_in_the_dark/widgets/burn_shader.dart';
import 'package:flutter_in_the_dark/widgets/show_overlay.dart';

/// Debug knobs for [/burn_test], parsed from the route's query string by
/// [BurnTestPage.fromSettings]. This is a thin typed view over the SHARED
/// [BurnKnobs] parser (SHADOW-005: the production overlay and this page
/// used to parse the same knobs twice, which could drift).
///
///  - `?burnSlow=<x>` multiplies the burn duration (e.g. `burnSlow=5`),
///  - `?burnHold=<0..1>` freezes the burn at exactly that progress and
///    parks the loop there — for steering/screenshotting the look,
///  - `?burnMode=mask|shader` selects the implementation under test:
///    `shader` (default) = production `BurnShaderOverlay`;
///    `mask` = the old `BurnHoleMask`+`BurnPainter` A/B baseline,
///  - `?mockShow=<remainingSeconds>` renders the /show overlay widgets
///    ([ShowTimerPill], and [TimeOverBanner] when the value is negative)
///    over the dummy challenge so they can be screenshot without a
///    backend: `mockShow=272` = mid-challenge pill, `mockShow=-2` =
///    time-over banner.
class BurnTestKnobs {
  const BurnTestKnobs({
    this.slowFactor = 1,
    this.holdAt,
    this.mode = BurnMode.shader,
    this.mockShow,
  });

  /// Parses the knobs from a route name's query string
  /// (`/burn_test?burnSlow=5&burnHold=0.5&burnMode=mask`).
  factory BurnTestKnobs.parse(String? routeName) {
    final knobs = BurnKnobs.parse(routeName);
    return BurnTestKnobs(
      slowFactor: knobs.slowFactor,
      holdAt: knobs.holdAt,
      mode: knobs.mode,
      mockShow: double.tryParse(
        Uri.parse(routeName ?? '/').queryParameters['mockShow'] ?? '',
      ),
    );
  }

  final double slowFactor;

  /// When non-null the burn is held at exactly this progress (0–1).
  final double? holdAt;

  /// Which burn implementation to render.
  final BurnMode mode;

  /// When non-null, mock the /show overlay state: the pill/banner see an
  /// endTime exactly this many seconds from first build (negative = the
  /// challenge is already over → the time-over banner).
  final double? mockShow;
}

/// Looping burn-reveal demo phases: the "paper" (countdown display) burns
/// away center-out over [kBurnSeconds], the revealed challenge holds for
/// [holdDuration], then the loop resets. Pure Dart so the timing math is
/// unit-testable without Flutter bindings (see `test/burn_phase_test.dart`
/// pattern).
enum BurnLoopPhase { burning, holding, done }

const Duration holdDuration = Duration(seconds: 2);

/// Phase + burn progress at elapsed loop time [t] (burn starts at zero).
/// A full cycle is `burn + hold`; [t] is wrapped by the caller or here —
/// either way the result is cyclic.
BurnLoopPhase loopPhaseAt(Duration t, Duration burnDuration) {
  final cycle = burnDuration + holdDuration;
  final raw = t.inMicroseconds % cycle.inMicroseconds;
  final burn = burnDuration.inMicroseconds;
  if (raw < 0) return BurnLoopPhase.done;
  if (raw < burn) return BurnLoopPhase.burning;
  if (raw < cycle.inMicroseconds) return BurnLoopPhase.holding;
  return BurnLoopPhase.done;
}

/// Burn progress (0→1) at elapsed loop time [t]; 1.0 during the hold.
double loopProgressAt(Duration t, Duration burnDuration) {
  final cycle = burnDuration + holdDuration;
  final raw = t.inMicroseconds % cycle.inMicroseconds;
  final burn = burnDuration.inMicroseconds;
  if (burn <= 0) return 1.0;
  if (raw >= burn) return 1.0;
  if (raw <= 0) return 0.0;
  return raw / burn;
}

/// Standalone `/burn_test` route: the REAL production burn visuals looping
/// forever over a dummy stand-in challenge background. Default is the
/// production [BurnShaderOverlay] (`widgets/burn_shader.dart`); pass
/// `?burnMode=mask` for the old `BurnHoleMask`+`BurnPainter` baseline
/// (`widgets/burn_effects.dart`) as an A/B.
///
/// No room_service, no SSE, no RoomSync, no wall-clock gates (I-008): an
/// [AnimationController] drives the burn, its completion listener starts
/// the hold, and the hold timer restarts the loop. Each loop iteration
/// re-seeds the jagged edge so no two burns share a silhouette.
class BurnTestPage extends StatefulWidget {
  const BurnTestPage({
    super.key,
    this.slowFactor = 1,
    this.holdAt,
    this.mode = BurnMode.shader,
    this.mockShow,
  });

  /// Convenience constructor for `onGenerateRoute`: parses the knobs from
  /// the route's query string (`/burn_test?burnSlow=5&burnHold=0.5`).
  factory BurnTestPage.fromSettings(RouteSettings settings) {
    final knobs = BurnTestKnobs.parse(settings.name);
    return BurnTestPage(
      slowFactor: knobs.slowFactor,
      holdAt: knobs.holdAt,
      mode: knobs.mode,
      mockShow: knobs.mockShow,
    );
  }

  final double slowFactor;
  final double? holdAt;
  final BurnMode mode;

  /// Debug-only /show overlay mock (see [BurnTestKnobs.mockShow]).
  final double? mockShow;

  @override
  State<BurnTestPage> createState() => _BurnTestPageState();
}

class _BurnTestPageState extends State<BurnTestPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burn;
  bool _holding = false;

  /// The jagged edge for the CURRENT loop iteration — re-seeded every
  /// iteration so each burn's silhouette differs, fixed mid-burn so the
  /// shape scales outward with progress without shimmering.
  late BurnEdge _edge;

  Duration get _burnDuration => Duration(
        microseconds: (kBurnSeconds * 1000000 * widget.slowFactor).round(),
      );

  @override
  void initState() {
    super.initState();
    _edge = _newEdge();
    _burn = AnimationController(vsync: this, duration: _burnDuration)
      ..addStatusListener(_onBurnStatus);
    final hold = widget.holdAt;
    if (hold != null) {
      // Frozen for steering: park at the held fraction, never loop — the
      // single seed from initState stays, so the shape is STABLE.
      _burn.value = hold;
    } else {
      _burn.forward();
    }
  }

  BurnEdge _newEdge() => BurnEdge(seed: math.Random().nextInt(1 << 31));

  void _onBurnStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Burn finished → hold the revealed challenge, then reset and replay
    // with a FRESH jagged silhouette.
    setState(() => _holding = true);
    Future.delayed(holdDuration, () {
      if (!mounted) return;
      setState(() {
        _holding = false;
        _edge = _newEdge();
      });
      _burn.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _burn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _DummyChallenge(),
          // Debug-only /show overlay mock (?mockShow=<remainingSeconds>):
          // the REAL widgets moved out of show_screen.dart — ShowTimerPill
          // and TimeOverBanner from show_overlay.dart — pinned to a fake
          // endTime so the projector overlay states can be screenshot
          // without room_service.
          if (widget.mockShow case final mockShow?)
            _MockShowOverlay(remainingSeconds: mockShow),
          if (!_holding)
            AnimatedBuilder(
              animation: _burn,
              builder: (context, _) {
                final progress = _burn.value;
                if (widget.mode == BurnMode.shader) {
                  // PRODUCTION path: the same BurnShaderOverlay the real
                  // reveal uses (shader paper + hole, countdown text faded
                  // above it, warmup absorbed at mount).
                  return AbsorbPointer(
                    child: BurnShaderOverlay(
                      progress: progress,
                      edge: _edge,
                      countdownBuilder: (context) => const _CountdownPaper(),
                    ),
                  );
                }
                // A/B baseline: the old mask implementation — BurnHoleMask
                // erases the jagged burned hole through the paper and
                // BurnPainter draws char + flame along the same contour.
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    AbsorbPointer(
                      child: BurnHoleMask(
                        progress: progress,
                        edge: _edge,
                        child: ColoredBox(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: const _CountdownPaper(),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: BurnPainter(progress: progress, edge: _edge),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Debug-only mock of the /show overlay states (?mockShow=<seconds>): pins
/// the REAL [ShowTimerPill] / [TimeOverBanner] from
/// `widgets/show_overlay.dart` to an endTime offset from first build, so
/// the projector overlay (mid-challenge pill, end-of-challenge flash) can
/// be steered and screenshot without room_service. Positive values render
/// the pill; negative values the time-over banner. No production UI
/// references this.
class _MockShowOverlay extends StatefulWidget {
  const _MockShowOverlay({required this.remainingSeconds});

  final double remainingSeconds;

  @override
  State<_MockShowOverlay> createState() => _MockShowOverlayState();
}

class _MockShowOverlayState extends State<_MockShowOverlay> {
  late DateTime _endTime;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _endTime = _fresh();
    // 1 Hz ticker: drives the banner's visibility window (the banner
    // itself carries NO ticker — the host drives rebuilds, so the mock
    // supplies the cadence show_screen's _clockTimer would). For a
    // NEGATIVE mockShow (time-over) it also RE-ARMS the window each tick
    // so the banner stays catchable for a screenshot no matter when it
    // lands — production /show never re-arms, the 5 s window is real.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (widget.remainingSeconds < 0) _endTime = _fresh();
      });
    });
  }

  DateTime _fresh() => DateTime.now().add(
        Duration(milliseconds: (widget.remainingSeconds * 1000).round()),
      );

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(child: ShowTimerPill(endTime: _endTime)),
        ),
        Positioned.fill(child: TimeOverBanner(endTime: _endTime)),
      ],
    );
  }
}

/// A burn-FREE steering harness for the /show overlay widgets (no
/// ShaderMask, no looping burn): a static code-pane-like backdrop with the
/// REAL [ShowTimerPill] / [TimeOverBanner] pinned to a fake endTime. This
/// exists because the looping burn's dstOut ShaderMask is too heavy to
/// screenshot under headless SwiftShader, and freezing it at full progress
/// (burnHold=1.0) makes the erase layer wipe sibling overlays (I-033).
/// Route: `/show_mock?mockShow=<remainingSeconds>` (positive = pill,
/// negative = time-over banner).
class ShowMockPage extends StatelessWidget {
  const ShowMockPage({super.key, required this.remainingSeconds});

  factory ShowMockPage.fromSettings(RouteSettings settings) {
    final query = Uri.parse(settings.name ?? '/').queryParameters;
    final seconds = double.tryParse(query['mockShow'] ?? '') ?? 272;
    return ShowMockPage(remainingSeconds: seconds);
  }

  final double remainingSeconds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _CodePaneBackdrop(),
          _MockShowOverlay(remainingSeconds: remainingSeconds),
        ],
      ),
    );
  }
}

/// A static stand-in for the /show code pane: dark editor surface with
/// mono "code" lines, so the overlay's collision (or lack of it) with the
/// content underneath reads exactly like the projector complaint.
class _CodePaneBackdrop extends StatelessWidget {
  const _CodePaneBackdrop();

  @override
  Widget build(BuildContext context) {
    const lines = [
      'import \'package:flutter/material.dart\';',
      '',
      'class AuroraBorealis extends StatelessWidget {',
      '  const AuroraBorealis({super.key});',
      '',
      '  @override',
      '  Widget build(BuildContext context) {',
      '    return CustomPaint(',
      '      painter: _AuroraPainter(',
      '        colors: const [Color(0xFF00E5A0), Color(0xFF7C4DFF)],',
      '        bands: 5,',
      '      ),',
      '      child: const SizedBox.expand(),',
      '    );',
      '  }',
      '}',
      '',
      'class _AuroraPainter extends CustomPainter {',
      '  // …',
      '}',
    ];
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          lines.join('\n'),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 20,
            height: 1.5,
            color: Color(0xFFC9D1D9),
          ),
        ),
      ),
    );
  }
}

/// The "paper" that burns away: a big countdown-style display standing in
/// for the production `CountdownOverlay` (no wall clock here — I-008).
class _CountdownPaper extends StatelessWidget {
  const _CountdownPaper();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Get ready…',
              style: TextStyle(fontSize: 32, color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              '1',
              style: TextStyle(
                fontSize: 150,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dummy stand-in challenge the burn reveals: clearly patterned so the
/// hole opening is unmistakable on a phone screen.
class _DummyChallenge extends StatelessWidget {
  const _DummyChallenge();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF311B92)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.emoji_events,
          size: 180,
          color: Colors.amber.shade400,
        ),
      ),
    );
  }
}
