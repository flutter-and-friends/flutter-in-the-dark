import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:fitd25/dart_pad/dart_pad_widget.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:fitd25/screens/home_screen.dart';
import 'package:fitd25/screens/waiting_for_challenge.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    hide setLocaleMessages, setDefaultLocale;

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key, required this.challenger});

  final Challenger challenger;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late final StreamSubscription _subscription;
  Challenge? challenge;

  Timer? _finishTimer;
  final confettiController = ConfettiController(
    duration: const Duration(seconds: 5),
  );

  @override
  void initState() {
    _subscription = FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data != null) {
            setState(() {
              final challenge = this.challenge = Challenge.fromFirestore(data);
              countFinish(challenge.endTime);
            });
          } else {
            setState(() {
              challenge = null;
            });
          }
        });

    super.initState();
  }

  void countFinish(DateTime endTime) {
    _finishTimer?.cancel();
    _finishTimer = null;

    // If the end time is in the past, we don't need to set a timer
    if (DateTime.now().isAfter(endTime)) return;

    _finishTimer = Timer(endTime.difference(DateTime.now()), () {
      setState(() {
        _finishTimer?.cancel();
        _finishTimer = null;
        // TODO: Move this to the challenge screen
        confettiController.play();
      });
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _subscription.cancel();
    confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = this.challenge;

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
                Text('Challenger: ${widget.challenger.name}'),
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
      ],
    );
  }
}
