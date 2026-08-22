import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter_in_the_dark/helpers/challenge_ticker.dart';
import 'package:flutter_in_the_dark/helpers/session_kick.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_in_the_dark/room/room_sync.dart';
import 'package:flutter_in_the_dark/room/session_store.dart';
import 'package:flutter_in_the_dark/screens/home_screen.dart';
import 'package:flutter_in_the_dark/screens/player_selection_screen.dart';
import 'package:flutter_in_the_dark/screens/waiting_for_challenge.dart';
import 'package:flutter_in_the_dark/widgets/challenger_content.dart';
import 'package:flutter_in_the_dark/widgets/compiled_widget.dart';
import 'package:flutter_in_the_dark/widgets/plasma_loader.dart';
import 'package:flutter_in_the_dark/widgets/prompt_editor.dart';
import 'package:flutter_in_the_dark/room/room_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    hide setDefaultLocale, setLocaleMessages;
import 'package:web/web.dart' as web;

/// The contestant's screen. Two phases:
///  - LIVE: Challenge | Prompt | Optional assets. No Generate button — the
///    buzzer pushes prompts server-side (§6.C).
///  - DONE (buzzer fired): challenge (left) + prompt→result (right), where
///    the result pane is the SAME tri-state render as /show (§6.D).
class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key, required this.roomSync});

  final RoomSync roomSync;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen>
    with SingleTickerProviderStateMixin {
  final _confettiController = ConfettiController(
    duration: const Duration(seconds: 5),
  );

  late final AnimationController _shakeController;
  late final Tween<Offset> _shakeTween;
  late Animation<Offset> _shakeAnimation;
  final _random = Random();

  ({String playerId, String token, String roundId})? _session;
  RoomState? _lastState;
  bool _endHandled = false;

  /// Wall-clock ticker that re-evaluates the time-dependent gates
  /// ([Challenge.isInTheFuture] / [Challenge.isFinished]) exactly when
  /// startTime/endTime are crossed. RoomSync only notifies on SSE events,
  /// and the server never sends an event at the moment wall-clock time
  /// passes startTime/endTime — so without this the screen stays stuck on
  /// WaitingForChallenge (or the live screen) until the next SSE event.
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    // PLAYER-scoped identity: only constructed on the player route, so this
    // is the one screen that reads the player session store.
    _session = SessionStore.read();
    if (_session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToJoin());
    }
    _shakeController =
        AnimationController(
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
    widget.roomSync.addListener(_onRoomChanged);
    _lastState = widget.roomSync.state;
    _syncClockTimer();
  }

  /// Starts the wall-clock ticker while there is a pending time-dependent
  /// transition to wait for (challenge not yet started, or started but not
  /// yet finished); cancels it as soon as there is nothing to wait for.
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
    _checkBuzzerEdge();
    _syncClockTimer();
    if (mounted) setState(() {});
  }

  void _goToJoin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PlayerSelectionScreen(roomSync: widget.roomSync),
      ),
    );
  }

  void _shake() {
    _shakeTween.end = Offset(
      (_random.nextDouble() - 0.5) * 0.2,
      (_random.nextDouble() - 0.5) * 0.2,
    );
    _shakeController.forward(from: 0);
  }

  void _onRoomChanged() {
    if (_checkKick()) return;
    _checkBuzzerEdge();
    _syncClockTimer();
    if (mounted) setState(() {});
  }

  /// WI-012 kick path (a): the room snapshot says this session is gone —
  /// the round rolled (roundId differs) or this challenger disappeared.
  /// Clears the session and routes back to the join screen. Returns true if
  /// a kick was performed. The keep-vs-kick decision itself is the pure
  /// [isKickedByState] (unit-tested on the VM); this is only its wiring.
  bool _checkKick() {
    final session = _session;
    if (session == null) return false;
    if (!isKickedByState(
      playerId: session.playerId,
      roundId: session.roundId,
      state: widget.roomSync.state,
    )) {
      return false;
    }
    _kick();
    return true;
  }

  /// WI-012 kick path (b): /api/prompt rejected the session with a 403.
  void _onStaleSession() => _kick();

  void _kick() {
    SessionStore.clear();
    if (mounted) setState(() => _session = null);
    _goToJoin();
  }

  /// Buzzer edge: fire the celebration + blur exactly once, whether the
  /// finish is observed via an SSE event or via the wall-clock ticker
  /// crossing endTime (no SSE event fires at that moment).
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

    // Blur the active element so the on-screen keyboard drops and the prompt
    // field can't take further input.
    if (web.document.activeElement case final web.HTMLElement activeElement) {
      activeElement.blur();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    widget.roomSync.removeListener(_onRoomChanged);
    _confettiController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final state = widget.roomSync.state;
    final challenge = state?.challenge;
    final me = state?.challengerById(session.playerId);

    if (challenge == null) return const HomeScreen();
    if (challenge.isInTheFuture) {
      return WaitingForChallenge(challenge: challenge);
    }

    // The buzzer has fired (or the server has blocked me): the done screen.
    final done = challenge.isFinished ||
        me?.status == ChallengerStatus.blocked;

    return Material(
      child: SlideTransition(
        position: _shakeAnimation,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    // The display name is round-scoped server state — read
                    // from the room, never from localStorage (WI-012). `me`
                    // is null only during the reconnect window.
                    Text('Challenger: ${me?.name ?? '…'}'),
                    const Spacer(),
                    switch (challenge.endTime) {
                      final endTime when DateTime.now().isAfter(endTime) =>
                        const Text('Time over!'),
                      final endTime => Timeago(
                        refreshRate: const Duration(seconds: 1),
                        date: endTime.toLocal(),
                        allowFromNow: true,
                        builder: (context, time) {
                          if (DateTime.now().isAfter(endTime)) {
                            return const Text('Time over!');
                          }
                          return Text('"${challenge.name}" ends in $time');
                        },
                      ),
                    },
                  ],
                ),
              ),
              body: done
                  ? _buildDone(context, challenge, me, state)
                  : _buildLive(context, challenge, session),
            ),
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              strokeWidth: 2,
            ),
            if (done && !_endHandled)
              Positioned.fill(
                child: PointerInterceptor(
                  child: Material(
                    color: Colors.black38,
                    child: Center(
                      child: Text(
                        "Time's up!",
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// LIVE phase: Challenge | Prompt | Optional assets (assets hidden when the
  /// challenge has none, §6.D).
  Widget _buildLive(
    BuildContext context,
    Challenge challenge,
    ({String playerId, String token, String roundId}) session,
  ) {
    final panes = <Widget>[
      _ChallengePane(widgetUrl: challenge.widgetUrl),
      PromptEditor(
        key: ValueKey('editor-${session.playerId}'),
        playerId: session.playerId,
        token: session.token,
        initialPrompt:
            widget.roomSync.state
                ?.challengerById(session.playerId)
                ?.prompt ??
            '',
        client: widget.roomSync.client,
        onStaleSession: _onStaleSession,
      ),
      if (challenge.assets.isNotEmpty)
        _AssetsPane(assets: challenge.assets),
    ];

    return SplitPane(
      axis: Axis.horizontal,
      initialFractions: challenge.assets.isEmpty
          ? const [0.45, 0.55]
          : const [0.35, 0.45, 0.2],
      children: panes,
    );
  }

  /// DONE phase: challenge (left) + prompt→result (right), the result being
  /// the same tri-state render as /show (§6.D).
  Widget _buildDone(
    BuildContext context,
    Challenge challenge,
    Challenger? me,
    RoomState? state,
  ) {
    final content = me == null
        ? DisplayContent.prompt
        : (state?.contentFor(me.id) ?? DisplayContent.prompt);

    return SplitPane(
      axis: Axis.horizontal,
      initialFractions: const [0.5, 0.5],
      children: [
        _ChallengePane(widgetUrl: challenge.widgetUrl),
        Container(
          color: const Color(0xFF0D1117),
          child: me == null
              ? const PlasmaLoader(label: 'Reconnecting…')
              : ChallengerContent(
                  challenger: me,
                  content: content,
                  expanded: true,
                ),
        ),
      ],
    );
  }
}

/// The challenge widget: a pre-compiled Flutter app served via the same
/// compileAndServe iframe path as contestant output (§6.F).
class _ChallengePane extends StatelessWidget {
  const _ChallengePane({required this.widgetUrl});

  final String widgetUrl;

  @override
  Widget build(BuildContext context) {
    if (widgetUrl.isEmpty) {
      return const Center(
        child: Text(
          'Challenge widget coming soon…',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    return CompiledWidget(url: '${RoomClient.compileBaseUrl}$widgetUrl');
  }
}

class _AssetsPane extends StatelessWidget {
  const _AssetsPane({required this.assets});

  final Map<String, String> assets;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Assets for challenge',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Expanded(
          child: ListView(
            children: [
              for (final entry in assets.entries)
                Tooltip(
                  message: entry.value,
                  child: ListTile(
                    trailing: const Icon(Icons.copy),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: entry.value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Copied asset "${entry.key}" to clipboard',
                          ),
                        ),
                      );
                    },
                    title: Text(entry.key),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
