import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter_in_the_dark/helpers/challenge_ticker.dart';
import 'package:flutter_in_the_dark/room/room_client.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_in_the_dark/room/room_sync.dart';
import 'package:flutter_in_the_dark/screens/waiting_for_challenge_screen.dart';
import 'package:flutter_in_the_dark/screens/challenge_countdown_overlay.dart';
import 'package:flutter_in_the_dark/widgets/burn_reveal.dart';
import 'package:flutter_in_the_dark/widgets/challenger_content.dart';
import 'package:flutter_in_the_dark/widgets/compiled_widget.dart';
import 'package:flutter_in_the_dark/widgets/countdown_overlay.dart';
import 'package:flutter_in_the_dark/widgets/show_overlay.dart';
import 'package:flutter/material.dart';

/// The audience screen. Renders the challenge plus one box per challenger;
/// each box shows Prompt | Code | compiled Widget per the admin's tri-state
/// selection (§6.D). Same render as the contestant's own done screen.
class ShowScreen extends StatefulWidget {
  const ShowScreen({super.key, required this.roomSync});

  final RoomSync roomSync;

  @override
  State<ShowScreen> createState() => _ShowScreenState();
}

class _ShowScreenState extends State<ShowScreen>
    with SingleTickerProviderStateMixin {
  /// Wall-clock ticker so the isInTheFuture gate flips to the live show
  /// exactly when startTime is reached — RoomSync only notifies on SSE
  /// events, and no SSE event fires when wall-clock time crosses startTime.
  Timer? _clockTimer;

  /// Countdown → burn → reveal phase machine for the end-of-challenge gate.
  /// Fed from [_tick] (and SSE rebuilds) — never a bare DateTime.now()
  /// gate in build (I-008).
  late final BurnRevealController _burn;

  // End-of-challenge celebration (mirrors challenge_screen._onChallengeEnd):
  // 5 staggered elastic shakes + one explosive confetti burst. Fires once
  // per challenge via the [_endHandled] latch.
  final _confettiController = ConfettiController(
    duration: const Duration(seconds: 5),
  );
  late final AnimationController _shakeController;
  late final Tween<Offset> _shakeTween;
  late Animation<Offset> _shakeAnimation;
  final _random = Random();

  RoomState? _lastState;
  bool _endHandled = false;

  @override
  void initState() {
    super.initState();
    // WI-012 / I-022: the audience screen NEVER joins and holds NO session.
    // It only listens to the shared room state, so round rolls (roundId
    // bumps) do not affect it and it is exempt from the player kick by
    // construction. It deliberately never reads the player SessionStore.
    _burn = BurnRevealController(vsync: this);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });
    _shakeTween = Tween<Offset>(begin: Offset.zero, end: Offset.zero);
    _shakeAnimation = _shakeTween.animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    widget.roomSync.addListener(_onChanged);
    _lastState = widget.roomSync.state;
    _syncClockTimer();
  }

  void _onChanged() {
    _checkBuzzerEdge();
    _feedBurn();
    _syncClockTimer();
    if (mounted) setState(() {});
  }

  /// Buzzer edge: fire the celebration exactly once when the challenge
  /// transitions to finished, whether observed via an SSE event or via the
  /// wall-clock ticker crossing endTime (no SSE event fires at that
  /// moment). The [_endHandled] latch guards against re-firing on every
  /// tick; it resets when the challenge goes away.
  void _checkBuzzerEdge() {
    final state = widget.roomSync.state;
    final challenge = state?.challenge;
    final wasLive = _lastState?.challenge?.isFinished == false;
    _lastState = state;

    if (!_endHandled &&
        challenge != null &&
        challenge.isFinished &&
        wasLive != false) {
      _endHandled = true;
      _onChallengeEnd();
    }
    if (challenge == null) _endHandled = false;
  }

  void _onChallengeEnd() {
    for (var i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: i * 200), _shake);
    }
    _confettiController.play();
  }

  void _shake() {
    _shakeTween.end = Offset(
      (_random.nextDouble() - 0.5) * 0.2,
      (_random.nextDouble() - 0.5) * 0.2,
    );
    _shakeController.forward(from: 0);
  }

  /// Starts the wall-clock ticker while the challenge has a pending
  /// time-dependent transition (not yet started, or not yet finished);
  /// cancels it as soon as there is nothing to wait for.
  ///
  /// Fine-grained (100 ms, same as _TimerBadge and the old _CountdownGate)
  /// inside the end-of-challenge countdown/burn window: the
  /// BurnRevealController's countdown → burn → reveal handoff must not sit
  /// stale for up to a second at the 1 Hz coarse cadence. Coarse 1 s ticks
  /// are enough while the challenge is merely pending/live outside it.
  void _syncClockTimer() {
    final challenge = widget.roomSync.state?.challenge;
    final waiting = shouldTickForChallenge(challenge);
    final remainingMs =
        challenge?.endTime.difference(DateTime.now()).inMilliseconds;
    final fine =
        waiting && remainingMs != null && remainingMs <= _fineTickThresholdMs;
    final interval =
        fine ? const Duration(milliseconds: 100) : const Duration(seconds: 1);
    if (waiting) {
      if (_clockTimer == null || _clockInterval != interval) {
        _clockTimer?.cancel();
        _clockTimer = Timer.periodic(interval, (_) => _tick());
        _clockInterval = interval;
      }
    } else {
      _clockTimer?.cancel();
      _clockTimer = null;
      _clockInterval = null;
    }
  }

  /// Switch to the 100 ms cadence once the end-of-challenge countdown/burn
  /// window is near (the BurnRevealController's 10 s gate, plus a small
  /// hysteresis so the cadence doesn't flap at the boundary).
  static const int _fineTickThresholdMs = 12 * 1000;

  Duration? _clockInterval;

  void _tick() {
    _checkBuzzerEdge();
    _feedBurn();
    // Cadence is re-considered on SSE-driven _onChanged, not from the tick
    // itself, to avoid re-entrancy from the ticker.
    if (mounted) setState(() {});
  }

  void _feedBurn() {
    final challenge = widget.roomSync.state?.challenge;
    if (challenge != null) {
      _burn.tick(challenge.endTime.difference(DateTime.now()));
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _burn.dispose();
    _confettiController.dispose();
    _shakeController.dispose();
    widget.roomSync.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.roomSync.state;
    final challenge = state?.challenge;

    if (challenge == null) return const WaitingForChallengeScreen();
    if (challenge.isInTheFuture) {
      return ChallengeCountdownOverlay(challenge: challenge);
    }

    _feedBurn();

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          // The shake slides the whole content layer (panes + pill); the
          // overlays stay fixed so the celebration doesn't jolt the
          // countdown/burn/banner out from under the audience.
          SlideTransition(
            position: _shakeAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildBody(state!),
                // The remaining time rides the top edge as a small pill,
                // OUT of the content's way — the projector is read, not
                // touched, so the clock should never compete with the panes
                // underneath.
                Positioned(
                  top: 12,
                  child: ShowTimerPill(endTime: challenge.endTime),
                ),
              ],
            ),
          ),
          // Confetti burst at challenge end — visual-only, non-interactive.
          // Kept BELOW the burn/countdown overlay so that overlay stays on
          // top for input-blocking.
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              strokeWidth: 2,
            ),
          ),
          Positioned.fill(
            child: BurnRevealOverlay(
              controller: _burn,
              remaining: challenge.endTime.difference(DateTime.now()),
              countdownBuilder: (context) => CountdownOverlay(
                duration: challenge.endTime.difference(DateTime.now()),
              ),
            ),
          ),
          // "Time over!" pops big for a few seconds, then dismisses itself
          // (a ticker drives the window — never a build-time DateTime gate,
          // I-008) so the finished content underneath is readable again.
          Positioned.fill(child: TimeOverBanner(endTime: challenge.endTime)),
        ],
      ),
    );
  }

  Widget _buildBody(RoomState state) {
    final challenge = state.challenge!;
    final challengePane = challenge.widgetUrl.isEmpty
        ? const Center(
            child: Text(
              'Challenge widget coming soon…',
              style: TextStyle(color: Colors.white38, fontSize: 24),
            ),
          )
        : CompiledWidget(
            url: '${RoomClient.compileBaseUrl}${challenge.widgetUrl}',
          );

    return switch (state.show.viewMode) {
      ViewMode.challengeOnly => challengePane,
      ViewMode.allWithChallenge => Row(
          children: [
            Expanded(flex: 2, child: challengePane),
            Expanded(flex: 3, child: PlayerGrid(state: state)),
          ],
        ),
      ViewMode.allPlayers => PlayerGrid(state: state),
      ViewMode.singlePlayer => _buildSinglePlayer(state),
      ViewMode.singleWithChallenge => Row(
          children: [
            Expanded(flex: 2, child: challengePane),
            Expanded(flex: 3, child: _buildSinglePlayer(state)),
          ],
        ),
    };
  }

  Widget _buildSinglePlayer(RoomState state) {
    final focusedId = state.show.focusedPlayerId;
    final player = focusedId == null ? null : state.challengerById(focusedId);
    if (player == null) {
      return const Center(
        child: Text(
          'No player focused',
          style: TextStyle(color: Colors.white54, fontSize: 32),
        ),
      );
    }
    return PlayerCard(
      challenger: player,
      content: state.contentFor(player.id),
      expanded: true,
      autoScroll: true,
    );
  }
}

/// Responsive grid of per-challenger boxes.
class PlayerGrid extends StatelessWidget {
  const PlayerGrid({super.key, required this.state});

  final RoomState state;

  @override
  Widget build(BuildContext context) {
    final players = state.challengers;
    if (players.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for players…',
          style: TextStyle(color: Colors.white38, fontSize: 28),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (players.length) {
          1 => 1,
          2 => 2,
          <= 4 => 2,
          <= 9 => 3,
          _ => 4,
        };
        return GridView.count(
          crossAxisCount: columns,
          childAspectRatio: constraints.maxWidth / constraints.maxHeight,
          padding: const EdgeInsets.all(12),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final player in players)
              PlayerCard(
                key: ValueKey(player.id),
                challenger: player,
                content: state.contentFor(player.id),
                autoScroll: true,
              ),
          ],
        );
      },
    );
  }
}

/// One challenger's box on /show: name header (+ live gen state) over the
/// tri-state content pane.
class PlayerCard extends StatefulWidget {
  const PlayerCard({
    super.key,
    required this.challenger,
    required this.content,
    this.expanded = false,
    this.autoScroll = false,
  });

  final Challenger challenger;
  final DisplayContent content;
  final bool expanded;

  /// Passed through to [ChallengerContent] so the projector view's code
  /// panes scroll themselves — the presenter cannot touch the screen.
  final bool autoScroll;

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(PlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.challenger.prompt != oldWidget.challenger.prompt) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 1 - _pulseController.value;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF30363D),
                const Color(0xFF58A6FF),
                _pulseController.isAnimating ? pulse : 0,
              )!,
              width: 2,
            ),
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.challenger.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.expanded ? 36 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _GenStateBadge(challenger: widget.challenger),
              ],
            ),
          ),
          Expanded(
            child: ChallengerContent(
              challenger: widget.challenger,
              content: widget.content,
              expanded: widget.expanded,
              autoScroll: widget.autoScroll,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small live indicator of the generation pipeline state, so the audience
/// sees why a box is still loading.
class _GenStateBadge extends StatelessWidget {
  const _GenStateBadge({required this.challenger});

  final Challenger challenger;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (challenger.genState) {
      GenState.idle => (Colors.white24, 'writing'),
      GenState.queued => (Colors.orange, 'queued'),
      GenState.generating => (Colors.blue, 'generating'),
      GenState.compiling => (Colors.purple, 'compiling'),
      GenState.ready => (Colors.green, 'ready'),
      GenState.failed => (Colors.red, 'failed'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
