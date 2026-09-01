import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/challenge_countdown.dart';
import 'package:flutter_in_the_dark/helpers/challenge_ticker.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';

/// Live remaining-time readout for the admin challenge card: `starts in
/// 0:09` while the warm-up window runs, `ends in 4:32` while live (orange
/// in the last minute), and `Time over` once wall-clock time crosses
/// endTime.
///
/// Self-ticking: a build()-time `DateTime.now()` gate is NOT self-updating
/// (I-008), and RoomSync only notifies on SSE events — never at the moment
/// the clock crosses startTime/endTime — so this widget drives its own 1 Hz
/// [Timer], gated by [shouldTickForChallenge], and stops it once the
/// challenge is over (nothing time-dependent left to wait for). Each tick
/// recomputes from the wall clock rather than counting down by ticks, so
/// the readout tracks the server's endTime and never accumulates drift.
///
/// Kept free of `room_client.dart`/`dart:js_interop` so it stays
/// widget-testable under `flutter test` (W-012) — same pattern as
/// `show_overlay.dart`. Behaviour is delegated to the pure helpers in
/// `helpers/challenge_countdown.dart`, which ARE unit-tested on the VM.
class ChallengeCountdown extends StatefulWidget {
  const ChallengeCountdown({super.key, required this.challenge});

  final Challenge challenge;

  @override
  State<ChallengeCountdown> createState() => _ChallengeCountdownState();
}

class _ChallengeCountdownState extends State<ChallengeCountdown> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _syncClockTimer();
  }

  @override
  void didUpdateWidget(ChallengeCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new window (restart / ±1 min adjust / clear-and-set) can start or
    // stop the countdown — re-evaluate the gate.
    _syncClockTimer();
  }

  /// Starts the wall-clock ticker while there is a pending time-dependent
  /// transition to wait for (challenge not yet started, or started but not
  /// yet finished); cancels it as soon as there is nothing to wait for.
  /// Mirrors `challenge_screen.dart`'s `_syncClockTimer`.
  void _syncClockTimer() {
    final waiting = shouldTickForChallenge(widget.challenge);
    if (waiting && _clockTimer == null) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (!waiting) {
      _clockTimer?.cancel();
      _clockTimer = null;
    }
  }

  void _tick() {
    // The tick that crosses endTime is the last one: re-evaluating the gate
    // here cancels the timer once nothing time-dependent remains.
    _syncClockTimer();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final now = DateTime.now();
    final phase = challengeCountdownPhase(
      now: now,
      startTime: challenge.startTime,
      endTime: challenge.endTime,
    );
    final (label, color, icon) = switch (phase) {
      ChallengeCountdownPhase.upcoming => (
          'starts in '
          '${formatChallengeCountdown(challenge.startTime.difference(now))}',
          Colors.blueAccent,
          Icons.schedule,
        ),
      ChallengeCountdownPhase.live => (
          'ends in '
          '${formatChallengeCountdown(challenge.endTime.difference(now))}',
          Colors.greenAccent,
          Icons.timer_outlined,
        ),
      ChallengeCountdownPhase.lastMinute => (
          'ends in '
          '${formatChallengeCountdown(challenge.endTime.difference(now))}',
          Colors.orangeAccent,
          Icons.timer_outlined,
        ),
      ChallengeCountdownPhase.over => (
          'Time over',
          Colors.redAccent,
          Icons.timer_off_outlined,
        ),
    };
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            // One line, ellipsized as a last resort: phone widths must never
            // splinter the readout across lines (I-056).
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              // Fixed-width digits: the readout must not jiggle sideways
              // every second as glyph widths change.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
