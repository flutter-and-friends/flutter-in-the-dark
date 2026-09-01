import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_in_the_dark/helpers/challenge_ticker.dart';
import 'package:flutter_in_the_dark/helpers/session_kick.dart';
import 'package:flutter_in_the_dark/room/room_client.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_in_the_dark/room/room_sync.dart';
import 'package:flutter_in_the_dark/room/session_store.dart';
import 'package:flutter_in_the_dark/screens/challenge_countdown_overlay.dart';
import 'package:flutter_in_the_dark/screens/player_selection_screen.dart';
import 'package:flutter_in_the_dark/screens/waiting_for_challenge_screen.dart';
import 'package:flutter_in_the_dark/widgets/challenger_content.dart';
import 'package:flutter_in_the_dark/widgets/compiled_widget.dart';
import 'package:flutter_in_the_dark/widgets/plasma_loader.dart';
import 'package:flutter_in_the_dark/widgets/prompt_editor.dart';
import 'package:flutter_in_the_dark/widgets/show_overlay.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    hide setDefaultLocale, setLocaleMessages;
import 'package:web/web.dart' as web;

/// The contestant's screen. Two phases:
///  - LIVE: Challenge | Prompt | Optional assets. No Generate button — the
///    buzzer pushes prompts server-side (§6.C).
///  - DONE (buzzer fired): challenge (left) + prompt→result (right), where
///    the result pane is the SAME tri-state render as /show (§6.D).
class ChallengeScreen extends StatefulHookWidget {
  const ChallengeScreen({super.key, required this.roomSync});

  final RoomSync roomSync;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen>
    with TickerProviderStateMixin {
  final _confettiController = ConfettiController(
    duration: const Duration(seconds: 5),
  );

  late final AnimationController _shakeController;
  late final Tween<Offset> _shakeTween;
  late Animation<Offset> _shakeAnimation;
  final _random = Random();

  ({String playerId, String token, String roundId})? _session;

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
    widget.roomSync.addListener(_onRoomChanged);
    _syncClockTimer();
  }

  /// Starts the wall-clock ticker while there is a pending time-dependent
  /// transition to wait for (challenge not yet started, or started but not
  /// yet finished); cancels it as soon as there is nothing to wait for.
  ///
  /// The cadence is fine-grained (100 ms, same as /show's TimerBadge and the
  /// old _CountdownGate) once the end-of-challenge countdown/burn window is
  /// live: the BurnRevealController's countdown→burn→reveal handoff must not
  /// sit stale for up to a second at the 1 Hz coarse cadence, and the burn
  /// itself needs more than 1–2 frames. Coarse 1 s ticks are enough while
  /// the challenge is merely pending/live outside the countdown window.
  void _syncClockTimer() {
    final challenge = widget.roomSync.state?.challenge;
    final waiting = shouldTickForChallenge(challenge);
    // Fine cadence inside the end-of-challenge countdown/burn window
    // (same threshold as the BurnRevealController's 10 s countdown gate,
    // plus a small hysteresis so the cadence doesn't flap at the edge);
    // coarse 1 s ticks while merely pending/live outside it.
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
  /// window is near: the burn phase machine needs finer updates than the
  /// coarse 1 s wall-clock cadence to hand off countdown → burn → reveal
  /// promptly and to give the burn more than 1–2 frames. The +2 s
  /// hysteresis keeps the cadence from flapping at the 10 s boundary.
  static const int _fineTickThresholdMs = 12 * 1000;

  Duration? _clockInterval;

  void _tick() {
    // Note: _syncClockTimer intentionally does NOT re-evaluate the cadence
    // here — calling _feedBurn above already refreshed the controller, and
    // the cadence is only re-considered on SSE/state changes (onRoomChanged)
    // to avoid re-entry from the ticker itself.
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
    _syncClockTimer();
    if (mounted) setState(() {});
  }

  /// Kick path (a): the room snapshot says this session is gone — this
  /// challenger disappeared from the server's player list (admin Remove /
  /// Remove-all). Players persist across challenges, so a new or cleared
  /// challenge never kicks. Clears the session and routes back to the join
  /// screen. Returns true if a kick was performed. The keep-vs-kick decision
  /// itself is the pure [isKickedByState] (unit-tested on the VM); this is
  /// only its wiring.
  bool _checkKick() {
    final session = _session;
    if (session == null) return false;
    if (!isKickedByState(
      playerId: session.playerId,
      state: widget.roomSync.state,
    )) {
      return false;
    }
    _kick();
    return true;
  }

  /// Kick path (b): /api/prompt rejected the session with a 403.
  void _onStaleSession() => _kick();

  void _kick() {
    SessionStore.clear();
    if (mounted) setState(() => _session = null);
    _goToJoin();
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

    if (challenge == null) return const WaitingForChallengeScreen();

    // The buzzer has fired the done screen.
    final done = challenge.isFinished;

    useEffect(
      () {
        /// Buzzer edge: fire the celebration + blur exactly once, whether the
        /// finish is observed via an SSE event or via the wall-clock ticker
        /// crossing endTime (no SSE event fires at that moment).
        if (done) {
          _onChallengeEnd();
        }
        return null;
      },
      [done],
    );

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
                    // The display name is server state — read from the room,
                    // never from localStorage (WI-012). `me` is null only
                    // during the reconnect window.
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
            if (challenge.isInTheFuture)
              ChallengeCountdownOverlay(challenge: challenge),
            // The same big auto-dismissing "TIME OVER!" flash as /show,
            // driven by the host's wall-clock ticker (_tick → setState) and
            // keyed to challenge.endTime — the player sees the pop + 5 s
            // dismiss, not just the small AppBar "Time over!".
            Positioned.fill(
              child: TimeOverBanner(endTime: challenge.endTime),
            ),
            if (done)
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
            widget.roomSync.state?.challengerById(session.playerId)?.prompt ??
                '',
        client: widget.roomSync.client,
        onStaleSession: _onStaleSession,
      ),
      if (challenge.assets.isNotEmpty) _AssetsPane(assets: challenge.assets),
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
        ColoredBox(
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
