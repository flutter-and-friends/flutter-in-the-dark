import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fitd25/challenge_screen.dart';
import 'package:fitd25/firebase_options.dart';
import 'package:fitd25/screens/home_screen.dart';
import 'package:fitd25/screens/waiting_for_challenge.dart';
import 'package:flutter/material.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    hide setLocaleMessages, setDefaultLocale;
import 'package:timeago_flutter/timeago_flutter.dart'
    as timeago
    show setLocaleMessages, setDefaultLocale;

import 'data/challenge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  timeago.setLocaleMessages('en', OverrideEnTimeAgo());
  timeago.setDefaultLocale('en');
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(),
      home: const AutoToggle(child: HomeScreen()),
    );
  }
}

class AutoToggle extends StatefulWidget {
  final Widget child;

  const AutoToggle({super.key, required this.child});

  @override
  State<AutoToggle> createState() => _AutoToggleState();
}

class _AutoToggleState extends State<AutoToggle> {
  late final StreamSubscription _subscription;
  Challenge? challenge;
  Timer? startTime;
  Timer? _finishTimer;
  final confettiController = ConfettiController(
    duration: const Duration(seconds: 5),
  );

  @override
  void initState() {
    _subscription = FirebaseFirestore.instance
        .collection('fitd25')
        .doc('state')
        .snapshots()
        .listen((value) {
          final data = value.data();
          switch (data) {
            case {
              'name': final String name,
              'startTime': final Timestamp startTime,
              'endTime': final Timestamp endTime,
              'dartPadId': final String dartPadId,
              'challengeId': final String challengeId,
            }:
              setState(() {
                challenge = Challenge(
                  name: name,
                  dartPadId: dartPadId,
                  challengeId: challengeId,
                  startTime: startTime.toDate(),
                  endTime: endTime.toDate(),
                );
                countDown(startTime.toDate());
                countFinish(endTime.toDate());
              });
              break;
            default:
              debugPrint('The challenge data is not in the expected format.');
          }
        });
    super.initState();
  }

  void countDown(DateTime startTime) {
    this.startTime?.cancel();
    this.startTime = null;

    // If the start time is in the past, we don't need to set a timer
    if (DateTime.now().isAfter(startTime)) return;

    this.startTime = Timer(startTime.difference(DateTime.now()), () {
      setState(() {
        this.startTime?.cancel();
        this.startTime = null;
      });
    });
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
      });
      confettiController.play();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    confettiController.dispose();
    startTime?.cancel();
    _finishTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = this.challenge;

    // If no challenge is ongoing, show the home screen
    if (challenge == null) {
      return const HomeScreen();
    }

    // Waiting for challenge to start
    if (challenge.startTime.isAfter(DateTime.now())) {
      return WaitingForChallenge(challenge: challenge);
    }

    return ChallengeScreen(
      challenge: challenge,
      confettiController: confettiController,
    );
  }
}

class OverrideEnTimeAgo extends EnMessages {
  @override
  String suffixFromNow() => '';

  @override
  String suffixAgo() => '';

  @override
  String lessThanOneMinute(int seconds) => '$seconds seconds';
}
