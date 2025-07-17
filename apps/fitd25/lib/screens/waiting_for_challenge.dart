import 'package:fitd25/data/challenge.dart';
import 'package:flutter/material.dart';
import 'package:timeago_flutter/timeago_flutter.dart';

class WaitingForChallenge extends StatelessWidget {
  final Challenge challenge;

  const WaitingForChallenge({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Timeago(
        refreshRate: const Duration(seconds: 1),
        date: challenge.startTime,
        allowFromNow: true,
        builder: (context, time) {
          return Center(
            child: Text(
              'Starting ${challenge.name} in $time',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          );
        },
      ),
    );
  }
}
