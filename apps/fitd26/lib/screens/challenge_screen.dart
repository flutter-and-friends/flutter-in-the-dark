import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:fitd26/room/room_models.dart';
import 'package:fitd26/room/room_sync.dart';
import 'package:fitd26/room/session_store.dart';
import 'package:fitd26/screens/home_screen.dart';
import 'package:fitd26/screens/player_selection_screen.dart';
import 'package:fitd26/screens/waiting_for_challenge.dart';
import 'package:fitd26/widgets/challenger_content.dart';
import 'package:fitd26/widgets/compiled_widget.dart';
import 'package:fitd26/widgets/plasma_loader.dart';
import 'package:fitd26/widgets/prompt_editor.dart';
import 'package:fitd26/room/room_client.dart';
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

  ({String playerId, String token, String name})? _session;
  RoomState? _lastState;
  bool _endHandled = false;

  @override
  void initState() {
    super.initState();
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
    final state = widget.roomSync.state;
    final challenge = state?.challenge;
    final wasLive = _lastState?.challenge?.isFinished == false;
    _lastState = state;

    // Buzzer edge: fire the celebration + blur exactly once.
    if (!_endHandled &&
        challenge != null &&
        challenge.isFinished &&
        wasLive != false) {
      _endHandled = true;
      _onChallengeEnd();
    }
    if (challenge == null) _endHandled = false;

    if (mounted) setState(() {});
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
                    Text('Challenger: ${session.name}'),
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
    ({String playerId, String token, String name}) session,
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
