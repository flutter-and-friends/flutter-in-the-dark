import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/dart_pad/dart_pad_widget.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/data/challenger.dart';
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

class _ChallengeScreenState extends State<ChallengeScreen> {
  late final StreamSubscription _challengeSubscription;
  late final StreamSubscription _challengerSubscription;

  Challenge? challenge;
  Challenger? challenger;

  Timer? _finishTimer;
  final confettiController = ConfettiController(
    duration: const Duration(seconds: 5),
  );

  @override
  void initState() {
    _challengeSubscription = FirebaseFirestore.instance
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

    FirebaseAuth.instance.signInAnonymously().then((userCredential) async {
      final user = userCredential.user!;

      _challengerSubscription = FirebaseFirestore.instance
          .collection('fitd')
          .doc('state')
          .collection('challengers')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists) {
              final challenger = Challenger.fromFirestore(snapshot);
              if (mounted) {
                setState(() {
                  this.challenger = challenger;
                });
              }
            } else {
              // If the challenger document doesn't exist, we can redirect to the selection screen
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }
            }
          });
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

        if (challenger case final challenger?) {
          FirebaseFirestore.instance
              .collection('fitd')
              .doc('state')
              .collection('challengers')
              .doc(challenger.id)
              .set(
                challenger.withStatus(ChallengerStatus.blocked).toFirestore(),
                SetOptions(merge: true),
              );
          if (web.document.activeElement
              case final web.HTMLElement activeElement) {
            // Blur the active element to remove focus from any input fields
            // This is necessary to prevent the keyboard from showing up on
            // mobile when the challenge is finished, and to ensure the user
            // can't interact with the challenge anymore on any platform.
            activeElement.blur();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _challengeSubscription.cancel();
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
