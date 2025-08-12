import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd25/mixins/current_challenge_mixin.dart';
import 'package:fitd25/screens/admin/challenger_settings_modal.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:fitd25/screens/admin/mixins/all_challengers_mixin.dart';
import 'package:flutter/material.dart';

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
        Text(
          'Firestore Data: ${const JsonEncoder.withIndent('  ').convert(_jsonEncodable(challenge.toJson()))}',
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
}
