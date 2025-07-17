import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fitd25/challenges/first.dart';
import 'package:fitd25/dart_pad/dart_pad_widget.dart';
import 'package:fitd25/firebase_options.dart';
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
  Timer? _timer;
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
    _timer?.cancel();
    _timer = null;

    // If the start time is in the past, we don't need to set a timer
    if (DateTime.now().isAfter(startTime)) return;

    _timer = Timer(startTime.difference(DateTime.now()), () {
      setState(() {
        _timer?.cancel();
        _timer = null;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = this.challenge;

    // If no challenge is ongoing, show the home screen
    if (challenge == null) {
      return const HomeScreen();
    }

    final now = DateTime.now();

    // Waiting for challenge to start
    if (challenge case final challenge? when challenge.startTime.isAfter(now)) {
      return WaitingForChallenge(challenge: challenge);
    }

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scaffold(
          appBar: AppBar(
            title: switch (challenge.endTime) {
              final endTime when now.isAfter(endTime) => const Text(
                'Time over!',
              ),
              final endTime => Timeago(
                refreshRate: const Duration(seconds: 1),
                date: endTime,
                allowFromNow: true,
                builder: (context, time) {
                  // TODO: Figure out a nice way to shake screen and throw confetti
                  if (DateTime.now().isAfter(endTime)) {
                    return const Text('Time over!');
                  }
                  return Text(time);
                },
              ),
            },
          ),
          // body: switch (_currentPath) {
          //   'first' => const First(),
          //   'second' => const Second(),
          //   'third' => const Third(),
          //   'fourth' => const Fourth(),
          //   'finals' => const Final(),
          //   _ => const HomeScreen(),
          // },
          body: SplitPane(
            axis: Axis.horizontal,
            initialFractions: [0.5, 0.5],
            children: [
              First(),
              LayoutBuilder(
                builder: (context, constraints) {
                  return DartPad(
                    key: Key('Example1'),
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    split: 100,
                    gistId: challenge.dartPadId,
                  );
                },
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

class HomeScreen extends StatelessWidget {
  static const path = "/home";

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No challenge ongoing right now.'));
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

final counter = r'''
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
''';
