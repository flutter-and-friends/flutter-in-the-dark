/// Test harness: the BurnRevealController phase machine, mirrored from
/// `lib/widgets/burn_reveal.dart` so the blocking gate can be exercised
/// under `flutter test`.
///
/// The real controller's library imports `pointer_interceptor` +
/// `package:web` (via the BurnDebug knobs), which cannot compile for the
/// test VM — the whole app is web-only (W-012). The BurnDebug statics are
/// replaced by settable fields. Keep this copy in lockstep with the lib
/// version; drift is caught on review (SHADOW-003).
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_in_the_dark/helpers/burn_edge.dart';
import 'package:flutter_in_the_dark/helpers/burn_phase.dart';

class BurnDebug {
  BurnDebug._();

  static bool enabled = false;
  static double slowFactor = 1;
  static double? holdAt;
  static double burnSeconds = kBurnSeconds;

  static void reset() {
    enabled = false;
    slowFactor = 1;
    holdAt = null;
    burnSeconds = kBurnSeconds;
  }
}

class BurnRevealController extends ChangeNotifier {
  BurnRevealController({required TickerProvider vsync}) : _vsync = vsync;

  final TickerProvider _vsync;
  AnimationController? _burn;

  bool _countingDown = false;
  bool _revealed = false;

  BurnEdge? burnEdge;

  bool get isCountingDown => _countingDown;

  bool get isBurnAnimating => _burn?.isAnimating ?? false;

  bool get isRevealed => _revealed;

  Animation<double>? get burn => _burn?.view;

  bool get isBlocking => _countingDown && _blocking;

  bool _blocking = false;

  void tick(Duration remaining) {
    if (_revealed) return;
    final seconds = remaining.inMilliseconds / 1000.0;

    final hold = BurnDebug.holdAt;
    if (hold != null) {
      _enterCountdown(seconds <= 0 ? kBurnSeconds : seconds);
      _burn!.value = hold;
      _setBlocking(true);
      return;
    }

    if (seconds > kCountdownSeconds) return; // still waiting

    final burnStart = BurnDebug.burnSeconds;
    final burnEnd = burnStart - kBurnSeconds;

    _enterCountdown(seconds);
    _setBlocking(seconds <= burnStart);

    if (seconds <= 0) {
      _burn!.value = 1;
      _completeBurn();
      return;
    }

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

  void _enterCountdown(double seconds) {
    if (_countingDown) return;
    _countingDown = true;
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

  void debugReplay() {
    if (_burn == null) return;
    _revealed = false;
    _countingDown = true;
    _blocking = true;
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
