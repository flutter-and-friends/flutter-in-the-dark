import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:fitd25/dart_pad/dart_pad_widget.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:fitd25/helpers/map_extensions.dart';
import 'package:fitd25/mixins/current_challenge_mixin.dart';
import 'package:fitd25/mixins/current_challenger_mixin.dart';
import 'package:fitd25/screens/home_screen.dart';
import 'package:fitd25/screens/player_selection_screen.dart';
import 'package:fitd25/screens/waiting_for_challenge.dart';
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
                initialFractions: const [0.4, 0.4, 0.2],
                children: [
                  challenge.jsonWidgetData.build(context: context),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return DartPad(
                        key: Key(challenge.dartPadId),
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        split: 100,
                        gistId: challenge.dartPadId,
                      );
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
}
