import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:fitd25/dart_pad/dart_pad_widget.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:fitd25/providers/challenger_provider.dart';
import 'package:fitd25/providers/current_challenge_provider.dart';
import 'package:fitd25/screens/home_screen.dart';
import 'package:fitd25/screens/player_selection_screen.dart';
import 'package:fitd25/screens/waiting_for_challenge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    hide setDefaultLocale, setLocaleMessages;
import 'package:web/web.dart' as web;

class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key});

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen>
    with SingleTickerProviderStateMixin {
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
    _animationController = AnimationController(
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

  void _onChallengeEnd(Player challenger) {
    for (var i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: i * 200), _shake);
    }

    confettiController.play();

    updateChallenger(ref, challenger.withStatus(PlayerStatus.blocked));

    if (web.document.activeElement case final web.HTMLElement activeElement) {
      activeElement.blur();
    }
  }

  void _shake() {
    _tween.end = Offset(
      (_random.nextDouble() - 0.5) * 0.2,
      (_random.nextDouble() - 0.5) * 0.2,
    );
    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challengerAsync = ref.watch(challengerProvider);
    final challengeAsync = ref.watch(currentChallengeProvider);

    ref.listen(currentChallengeProvider, (previous, next) {
      if (previous?.value?.endTime != next.value?.endTime) {
        final challenger = challengerAsync.value;
        if (challenger != null) {
          _onChallengeEnd(challenger);
        }
      }
    });

    return challengerAsync.when(
      data: (challenger) {
        if (challenger == null) {
          return const PlayerSelectionScreen();
        }

        return challengeAsync.when(
          data: (challenge) {
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
                              final endTime
                                  when DateTime.now().isAfter(endTime) =>
                                const Text('Time over!'),
                              final endTime => Timeago(
                                  refreshRate: const Duration(seconds: 1),
                                  date: endTime,
                                  allowFromNow: true,
                                  builder: (context, time) {
                                    if (DateTime.now().isAfter(endTime)) {
                                      return const Text('Time over!');
                                    }
                                    return Text(
                                        '"${challenge.name}" ends in $time',);
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
                                'Images for challenge',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              if (challenge.imageUrls.isEmpty)
                                const Center(
                                  child: Text('No images for this challenge'),
                                )
                              else
                                Expanded(
                                  child: ListView(
                                    children: [
                                      for (final url in challenge.imageUrls)
                                        ListTile(
                                          title: Text(url),
                                          subtitle: Image.network(url),
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
                                style:
                                    Theme.of(context).textTheme.headlineLarge,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('Error: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Error: $error')),
    );
  }
}
