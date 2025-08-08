import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd25/mixins/current_challenge_mixin.dart';
import 'package:flutter/material.dart';

class CurrentChallengeAdminScreen extends StatefulWidget {
  const CurrentChallengeAdminScreen({super.key});

  @override
  State<CurrentChallengeAdminScreen> createState() =>
      _CurrentChallengeAdminScreenState();
}

class _CurrentChallengeAdminScreenState
    extends State<CurrentChallengeAdminScreen>
    with CurrentChallengeMixin {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        if (challenge case final challenge?)
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
