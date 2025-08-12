import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:fitd25/mixins/current_challenge_mixin.dart';
import 'package:fitd25/screens/admin/challenger_settings_modal.dart';
import 'package:fitd25/screens/admin/mixins/all_challengers_mixin.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CurrentChallengeAdminScreen extends StatefulWidget {
  const CurrentChallengeAdminScreen({super.key});

  @override
  State<CurrentChallengeAdminScreen> createState() =>
      _CurrentChallengeAdminScreenState();
}

class _CurrentChallengeAdminScreenState
    extends State<CurrentChallengeAdminScreen>
    with CurrentChallengeMixin, AllChallengersMixin {
  @override
  void onChallengeChanged() {
    super.onChallengeChanged();
    clearAllChallengers();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = this.challenge;
    if (challenge == null) {
      return Center(
        child: Text(
          'Hang on, challenge data is loading...',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: () => _showClearAllConfirmationDialog(),
          icon: const Icon(Icons.delete_sweep),
          label: const Text('Remove All Challengers'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.red.shade300,
          ),
        ),
        const SizedBox(height: 16),
        for (final challenger in allChallengers)
          ListTile(
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return ChallengerSettingsModal(
                    challenger: challenger,
                    onDelete: deleteChallenger,
                  );
                },
              );
            },
            title: Text(challenger.name),
            subtitle: Text(
              'Status: ${challenger.status}',
              style: TextStyle(
                color: challenger.status == ChallengerStatus.blocked
                    ? Colors.red.shade300
                    : Colors.green.shade300,
              ),
            ),
            trailing: IconButton(
              tooltip: challenger.status == ChallengerStatus.blocked
                  ? 'Unblock challenger'
                  : 'Block challenger',
              icon: Icon(
                challenger.status == ChallengerStatus.blocked
                    ? Icons.block
                    : Icons.check_circle,
                color: challenger.status == ChallengerStatus.blocked
                    ? Colors.red.shade300
                    : Colors.green.shade300,
              ),
              onPressed: () {
                final newStatus = challenger.status == ChallengerStatus.blocked
                    ? ChallengerStatus.inProgress
                    : ChallengerStatus.blocked;
                updateChallenger(challenger.withStatus(newStatus));
              },
            ),
          ),
        const Divider(),
        ExpansionTile(
          title: Text(challenge.name),
          subtitle: Text(
            'Starts: ${DateFormat('yyyy-MM-dd HH:mm', 'sv_SE').format(challenge.startTime)}\n'
            'Ends: ${DateFormat('yyyy-MM-dd HH:mm', 'sv_SE').format(challenge.endTime)}',
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('DartPad ID'),
              subtitle: Text(challenge.dartPadId),
            ),
            ListTile(
              title: const Text('Challenge ID'),
              subtitle: Text(challenge.challengeId),
            ),
            ListTile(
              title: const Text('Widget JSON'),
              subtitle: Text(
                const JsonEncoder.withIndent(
                  '  ',
                ).convert(_jsonEncodable(challenge.widgetJson)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Map<String, dynamic> _jsonEncodable(Map<String, dynamic> map) {
    final newMap = <String, dynamic>{
      for (final entry in map.entries)
        entry.key: switch (entry.value) {
          Timestamp timestamp => timestamp.toDate().toIso8601String(),
          DateTime dateTime => dateTime.toIso8601String(),
          final value => value,
        },
    };
    return newMap;
  }

  void _showClearAllConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove All Challengers?'),
        content: const Text(
          'This will remove all challengers from the competition. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              clearAllChallengers();
              Navigator.of(context).pop();
            },
            child: const Text('Remove All'),
          ),
        ],
      ),
    );
  }
}
