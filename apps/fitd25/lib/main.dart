import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fitd25/firebase_options.dart';
import 'package:fitd25/screens/admin_screen.dart';
import 'package:fitd25/screens/challenge_screen.dart';
import 'package:fitd25/screens/home_screen.dart';
import 'package:fitd25/screens/show_screen.dart';
import 'package:fitd25/screens/waiting_for_challenge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    show setLocaleMessages, setDefaultLocale;

import 'data/challenge.dart';
import 'override_en_timeago.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  setLocaleMessages('en', OverrideEnTimeAgo());
  setDefaultLocale('en');
  await initializeDateFormatting('sv_SE');
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('sv', 'SE')],
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/admin':
            return MaterialPageRoute(builder: (context) => const AdminScreen());
          case '/show':
            return MaterialPageRoute(
              builder: (context) => AutoToggle(
                routeName: settings.name,
                child: const HomeScreen(),
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const AutoToggle(child: HomeScreen()),
            );
        }
      },
    );
  }
}

class AutoToggle extends StatefulWidget {
  final Widget child;
  final String? routeName;

  const AutoToggle({super.key, required this.child, this.routeName});

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
        .collection('fitd')
        .doc('state')
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data != null) {
            setState(() {
              challenge = Challenge.fromFirestore(data);
              countDown(challenge!.startTime);
              countFinish(challenge!.endTime);
            });
          } else {
            setState(() {
              challenge = null;
            });
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
        // TODO: Move this to the challenge screen
        confettiController.play();
      });
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

    if (widget.routeName == '/show') {
      return ShowScreen(
        key: ValueKey(challenge),
        challenge: challenge,
      );
    }

    // Waiting for challenge to start
    if (challenge.startTime.isAfter(DateTime.now())) {
      return WaitingForChallenge(challenge: challenge);
    }

    // return ExportExamplePage();

    return ChallengeScreen(
      key: ValueKey(challenge),
      challenge: challenge,
      confettiController: confettiController,
    );
  }
}