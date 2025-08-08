import 'package:fitd25/data/challenger.dart';
import 'package:flutter/material.dart';

class ChallengerSettingsModal extends StatelessWidget {
  final Challenger challenger;

  const ChallengerSettingsModal({super.key, required this.challenger});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement the settings modal UI for the challenger.
    // This is a placeholder implementation.
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'Challenger: ${challenger.name}\n'
        'Status: ${challenger.status}\n'
        'ID: ${challenger.id}\n',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
