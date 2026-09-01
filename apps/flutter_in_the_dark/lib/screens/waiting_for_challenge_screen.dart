import 'package:flutter/material.dart';

class WaitingForChallengeScreen extends StatelessWidget {
  static const path = "/home";

  const WaitingForChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: Text(
          'No challenge ongoing right now.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
