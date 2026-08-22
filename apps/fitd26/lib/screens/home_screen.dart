import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  static const path = "/home";

  const HomeScreen({super.key});

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
