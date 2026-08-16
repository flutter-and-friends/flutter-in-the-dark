import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:fitd26/dart_pad/dart_pad_widget.dart';
import 'package:fitd26/data/challenger.dart';
import 'package:fitd26/generation/generation_client.dart';
import 'package:fitd26/helpers/map_extensions.dart';
import 'package:fitd26/mixins/current_challenge_mixin.dart';
import 'package:fitd26/mixins/current_challenger_mixin.dart';
import 'package:fitd26/screens/home_screen.dart';
import 'package:fitd26/screens/player_selection_screen.dart';
import 'package:fitd26/screens/waiting_for_challenge.dart';
import 'package:fitd26/widgets/prompt_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    hide setDefaultLocale, setLocaleMessages;
import 'package:web/web.dart' as web;

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen>
    with
        CurrentChallengeMixin,
        CurrentChallengerMixin,
        SingleTickerProviderStateMixin {
  final confettiController = ConfettiController(
    duration: const Duration(seconds: 5),
  );

  final _editorKey = GlobalKey<PromptEditorState>();
  final _generationClient = DartServicesClient();

  /// null = still on the prompt editor.
  String? _generatedCode;
  bool _isGenerating = false;
  String? _generationError;
  int _padReloadToken = 0;

  Future<void> _onGenerate(String prompt) async {
    setState(() {
      _generatedCode = '';
      _isGenerating = true;
      _generationError = null;
    });

    try {
      final code = await _generationClient.generateCode(
        prompt: prompt,
        onChunk: (chunk) {
          setState(() {
            _generatedCode = (_generatedCode ?? '') + chunk;
          });
        },
      );
      // Persist the full result (partial write of just this field).
      if (challenger case final challenger?) {
        await FirebaseFirestore.instance
            .collection('fitd')
            .doc('state')
            .collection('challengers')
            .doc(challenger.id)
            .update({'generatedCode': code});
      }
      setState(() {
        _generatedCode = code;
        _isGenerating = false;
        _padReloadToken++;
      });
    } on GenerationException catch (e) {
      setState(() {
        _isGenerating = false;
        _generationError = e.toString();
        _generatedCode = null;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _generationError = 'Unexpected error: $e';
        _generatedCode = null;
      });
    }
  }

  late final AnimationController _animationController;
  late final Tween<Offset> _tween;
  late Animation<Offset> _animation;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _animationController.reverse();
          }
        });
    _tween = Tween<Offset>(begin: Offset.zero, end: Offset.zero);
    _animation = _tween.animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticIn),
    );
  }

  @override
  bool onFailedToFetchChallenger() {
    // If the challenger document doesn't exist, we can redirect to the selection screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PlayerSelectionScreen()),
      );
    }
    return true;
  }

  @override
  void onChallengeStart() {
    setState(() {});
  }

  void _shake() {
    _tween.end = Offset(
      (_random.nextDouble() - 0.5) * 0.2,
      (_random.nextDouble() - 0.5) * 0.2,
    );
    _animationController.forward(from: 0);
  }

  @override
  void onChallengeEnd() {
    for (var i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: i * 200), _shake);
    }

    confettiController.play();

    if (challenger case final challenger?) {
      updateChallenger(challenger.withStatus(PlayerStatus.blocked));
    }

    if (web.document.activeElement case final web.HTMLElement activeElement) {
      // Blur the active element to remove focus from any input fields
      // This is necessary to prevent the keyboard from showing up on
      // mobile when the challenge is finished, and to ensure the user
      // can't interact with the challenge anymore on any platform.
      activeElement.blur();
    }
  }

  @override
  void dispose() {
    confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenger = this.challenger;

    if (challenger == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final challenge = this.challenge;
    if (challenge == null) {
      return const HomeScreen();
    }
    if (challenge.isInTheFuture) {
      return WaitingForChallenge(challenge: challenge);
    }

    return Material(
      child: SlideTransition(
        position: _animation,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    Text('Challenger: ${challenger.name}'),
                    const Spacer(),
                    switch (challenge.endTime) {
                      final endTime when DateTime.now().isAfter(endTime) =>
                        const Text('Time over!'),
                      final endTime => Timeago(
                        refreshRate: const Duration(seconds: 1),
                        date: endTime,
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
              floatingActionButton: kDebugMode
                  ? FloatingActionButton(
                      onPressed: _shake,
                      child: const Icon(Icons.animation),
                    )
                  : null,
                body: SplitPane(
                  axis: Axis.horizontal,
                  initialFractions: const [0.35, 0.45, 0.2],
                  children: [
                    challenge.jsonWidgetData.build(context: context),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final generatedCode = _generatedCode;
                        if (generatedCode == null) {
                          return PromptEditor(
                            key: _editorKey,
                            player: challenger,
                            enabled:
                                challenger.status != PlayerStatus.blocked,
                            onGenerate: _onGenerate,
                          );
                        }
                        return _buildOutcome(constraints, generatedCode);
                      },
                    ),
                  Column(
                    children: [
                      Text(
                        'Assets for challenge',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (challenge.assets.isEmpty)
                        const Center(
                          child: Text('No assets for this challenge'),
                        )
                      else
                        Expanded(
                          child: ListView(
                            children: [
                              for (final (name, assetContent)
                                  in challenge.assets.records)
                                Tooltip(
                                  message: assetContent,
                                  child: ListTile(
                                    trailing: const Icon(Icons.copy),
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: assetContent),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Copied asset "$name" to clipboard',
                                          ),
                                        ),
                                      );
                                    },
                                    title: Text(name),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            ConfettiWidget(
              confettiController: confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              strokeWidth: 2,
            ),
            if (challenger.status == PlayerStatus.blocked)
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

  /// The "outcome" pane shown once generation has started: DartPad embed fed
  /// via postMessage, plus an honest fallback read-only code view (the
  /// postMessage channel is best-effort — if dartpad.dev does not accept the
  /// message the code is still visible and selectable here).
  Widget _buildOutcome(BoxConstraints constraints, String code) {
    final theme = Theme.of(context);
    return Container(
      color: const Color(0xFF0D1117),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  _isGenerating ? Icons.hourglass_top : Icons.auto_awesome,
                  color: const Color(0xFF58A6FF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isGenerating
                        ? 'Generating your app…'
                        : 'Your generated app',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Back to prompt',
                  icon: const Icon(Icons.edit_note, color: Colors.white54),
                  onPressed: () {
                    setState(() => _generatedCode = null);
                  },
                ),
              ],
            ),
          ),
          if (_generationError case final error?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                error,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                // The DartPad embed. Keyed by the reload token so a
                // re-generate mounts a fresh iframe that receives the new
                // code via postMessage on load.
                Expanded(
                  flex: 3,
                  child: DartPad(
                    key: Key('gen-pad-$_padReloadToken'),
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    runImmediately: true,
                    initialCode: code,
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF30363D)),
                // Read-only code view (also the fallback if the embed does
                // not accept the postMessage).
                Expanded(
                  flex: 2,
                  child: Container(
                    color: const Color(0xFF161B22),
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        code.isEmpty && _isGenerating
                            ? 'Waiting for first chunk…'
                            : code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFFE6EDF3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
