import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/burn_edge.dart';
import 'package:flutter_in_the_dark/helpers/burn_phase.dart';
import 'package:flutter_in_the_dark/widgets/burn_effects.dart';

/// Debug knobs for [/burn_test], parsed from the route's query string by
/// [BurnTestPage.fromSettings] (pure — no `dart:js_interop`, unlike
/// `BurnDebug` in `widgets/burn_reveal.dart`, so this file stays
/// testable per W-012):
///
///  - `?burnSlow=<x>` multiplies the burn duration (e.g. `burnSlow=5`),
///  - `?burnHold=<0..1>` freezes the burn at exactly that progress and
///    parks the loop there — for steering/screenshotting the look.
class BurnTestKnobs {
  const BurnTestKnobs({this.slowFactor = 1, this.holdAt});

  /// Parses the knobs from a route name's query string
  /// (`/burn_test?burnSlow=5&burnHold=0.5`).
  factory BurnTestKnobs.parse(String? routeName) {
    final query = Uri.parse(routeName ?? '/').queryParameters;
    return BurnTestKnobs(
      slowFactor: _slow(query),
      holdAt: _hold(query),
    );
  }

  final double slowFactor;

  /// When non-null the burn is held at exactly this progress (0–1).
  final double? holdAt;

  static double _slow(Map<String, String> query) {
    final value = double.tryParse(query['burnSlow'] ?? '');
    if (value == null || value <= 0) return 1;
    return value;
  }

  static double? _hold(Map<String, String> query) {
    final value = double.tryParse(query['burnHold'] ?? '');
    return value?.clamp(0.0, 1.0);
  }
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

/// Standalone `/burn_test` route: the REAL production burn visuals (the
/// shared `BurnHoleMask` + `BurnPainter` from `widgets/burn_effects.dart` —
/// the same widgets `BurnRevealOverlay` uses — no longer a private copy)
/// looping forever over a dummy stand-in challenge background.
///
/// No room_service, no SSE, no RoomSync, no wall-clock gates (I-008): an
/// [AnimationController] drives the burn, its completion listener starts
/// the hold, and the hold timer restarts the loop. Each loop iteration
/// re-seeds the jagged edge so no two burns share a silhouette.
class BurnTestPage extends StatefulWidget {
  const BurnTestPage({super.key, this.slowFactor = 1, this.holdAt});

  /// Convenience constructor for `onGenerateRoute`: parses the knobs from
  /// the route's query string (`/burn_test?burnSlow=5&burnHold=0.5`).
  factory BurnTestPage.fromSettings(RouteSettings settings) {
    final knobs = BurnTestKnobs.parse(settings.name);
    return BurnTestPage(slowFactor: knobs.slowFactor, holdAt: knobs.holdAt);
  }

  final double slowFactor;
  final double? holdAt;

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
          if (!_holding)
            AnimatedBuilder(
              animation: _burn,
              builder: (context, _) {
                final progress = _burn.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // The countdown display is the "paper": the BurnHoleMask
                    // erases the jagged burned hole through IT and the
                    // painter draws char + flame on top — the exact stack
                    // production uses in BurnRevealOverlay.
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
        gradient: RadialGradient(
          radius: 1.2,
          colors: [Color(0xFF283593), Color(0xFF101323)],
        ),
      ),
      child: CustomPaint(
        painter: _GridPainter(),
        child: const Center(
          child: Text(
            'THE CHALLENGE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 24, color: Colors.indigoAccent)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Faint crosshatch over the gradient so the reveal has texture to show
/// against — a hole in black paper over flat black is hard to read.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
