import 'dart:async';

import 'package:flutter_in_the_dark/helpers/challenge_ticker.dart';
import 'package:flutter_in_the_dark/room/room_client.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_in_the_dark/room/room_sync.dart';
import 'package:flutter_in_the_dark/screens/home_screen.dart';
import 'package:flutter_in_the_dark/screens/waiting_for_challenge.dart';
import 'package:flutter_in_the_dark/widgets/challenger_content.dart';
import 'package:flutter_in_the_dark/widgets/compiled_widget.dart';
import 'package:flutter_in_the_dark/widgets/countdown_overlay.dart';
import 'package:flutter/material.dart';
import 'package:timeago_flutter/timeago_flutter.dart';

/// The audience screen. Renders the challenge plus one box per challenger;
/// each box shows Prompt | Code | compiled Widget per the admin's tri-state
/// selection (§6.D). Same render as the contestant's own done screen.
class ShowScreen extends StatefulWidget {
  const ShowScreen({super.key, required this.roomSync});

  final RoomSync roomSync;

  @override
  State<ShowScreen> createState() => _ShowScreenState();
}

class _ShowScreenState extends State<ShowScreen> {
  /// Wall-clock ticker so the isInTheFuture gate flips to the live show
  /// exactly when startTime is reached — RoomSync only notifies on SSE
  /// events, and no SSE event fires when wall-clock time crosses startTime.
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    widget.roomSync.addListener(_onChanged);
    _syncClockTimer();
  }

  void _onChanged() {
    _syncClockTimer();
    if (mounted) setState(() {});
  }

  /// Starts the wall-clock ticker while the challenge has a pending
  /// time-dependent transition (not yet started, or not yet finished);
  /// cancels it as soon as there is nothing to wait for.
  void _syncClockTimer() {
    final waiting = shouldTickForChallenge(
      widget.roomSync.state?.challenge,
    );
    if (waiting && _clockTimer == null) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (!waiting) {
      _clockTimer?.cancel();
      _clockTimer = null;
    }
  }

  void _tick() {
    _syncClockTimer();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    widget.roomSync.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.roomSync.state;
    final challenge = state?.challenge;

    if (challenge == null) return const HomeScreen();
    if (challenge.isInTheFuture) {
      return WaitingForChallenge(challenge: challenge);
    }

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          _buildBody(state!),
          Positioned(top: 50, child: _TimerBadge(challenge: challenge)),
          _CountdownGate(challenge: challenge),
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
    final player = focusedId == null
        ? null
        : state.challengerById(focusedId);
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

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return Timeago(
      refreshRate: const Duration(milliseconds: 100),
      date: challenge.endTime.toLocal(),
      allowFromNow: true,
      builder: (context, time) {
        final remainingTime = challenge.endTime.difference(DateTime.now());
        if (remainingTime.isNegative) {
          return const Text(
            'Time over!',
            style: TextStyle(fontSize: 48, color: Colors.red),
          );
        }
        if (remainingTime.inSeconds > 10) {
          return Text(
            'Time remaining: $time',
            style: const TextStyle(
              fontSize: 48,
              backgroundColor: Colors.black54,
              color: Colors.white,
            ),
          );
        }
        return Container();
      },
    );
  }
}

class _CountdownGate extends StatelessWidget {
  const _CountdownGate({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return Timeago(
      refreshRate: const Duration(milliseconds: 100),
      date: challenge.endTime.toLocal(),
      allowFromNow: true,
      builder: (context, time) {
        final remainingTime = challenge.endTime.difference(DateTime.now());
        if (remainingTime.isNegative || remainingTime.inSeconds > 10) {
          return Container();
        }
        return CountdownOverlay(duration: remainingTime);
      },
    );
  }
}
