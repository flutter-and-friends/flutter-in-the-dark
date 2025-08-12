import 'package:fitd25/data/challenger.dart';
import 'package:flutter/material.dart';

class ChallengerSettingsModal extends StatelessWidget {
  final Challenger challenger;
  final Future<void> Function(Challenger) onDelete;

  const ChallengerSettingsModal({
    super.key,
    required this.challenger,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Challenger: ${challenger.name}\n'
            'Status: ${challenger.status}\n'
            'ID: ${challenger.id}\n',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              onDelete(challenger);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.delete),
            label: const Text('Remove Challenger'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red.shade300,
            ),
          ),
        ],
      ),
    );
  }
}
