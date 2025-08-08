import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:fitd25/dart_pad/dart_pad_widget.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:fitd25/mixins/current_challenge_mixin.dart';
import 'package:fitd25/mixins/current_challenger_mixin.dart';
import 'package:fitd25/screens/challenger_selection_screen.dart';
import 'package:fitd25/screens/home_screen.dart';
import 'package:fitd25/screens/waiting_for_challenge.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    hide setLocaleMessages, setDefaultLocale;
import 'package:web/web.dart' as web;

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen>
    with CurrentChallengeMixin, CurrentChallengerMixin {
  final confettiController = ConfettiController(
    duration: const Duration(seconds: 5),
  );

  @override
  bool onFailedToFetchChallenger() {
    // If the challenger document doesn't exist, we can redirect to the selection screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ChallengerSelectionScreen(),
        ),
      );
    }
    return true;
  }

  @override
  void onChallengeEnd() {
    confettiController.play();

    if (challenger case final challenger?) {
      updateChallenger(challenger.withStatus(ChallengerStatus.blocked));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = this.challenge;
    final challenger = this.challenger;

    if (challenger == null) {
      return Center(child: const CircularProgressIndicator());
    }
    if (challenge == null) {
      return const HomeScreen();
    }

    if (challenge.isInTheFuture) {
      return WaitingForChallenge(challenge: challenge);
    }

    return Stack(
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
          body: SplitPane(
            axis: Axis.horizontal,
            initialFractions: [0.4, 0.4, 0.2],
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
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (challenge.imageUrls.isEmpty)
                    const Center(child: Text('No images for this challenge'))
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
        if (challenger.status == ChallengerStatus.blocked)
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
    );
  }
}
