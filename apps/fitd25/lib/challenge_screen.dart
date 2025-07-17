import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:fitd25/challenges/first.dart';
import 'package:fitd25/dart_pad/dart_pad_widget.dart';
import 'package:flutter/material.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    hide setLocaleMessages, setDefaultLocale;

import 'data/challenge.dart';

class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({
    super.key,
    required this.challenge,
    required this.confettiController,
  });

  final Challenge challenge;
  final ConfettiController confettiController;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scaffold(
          appBar: AppBar(
            title: switch (challenge.endTime) {
              final endTime when DateTime.now().isAfter(endTime) => const Text(
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
                  return Text('${challenge.name} ends in $time');
                },
              ),
            },
          ),
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
