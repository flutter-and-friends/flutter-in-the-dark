import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd26/data/show_state.dart';
import 'package:fitd26/mixins/current_challenge_mixin.dart';
import 'package:fitd26/screens/admin/mixins/all_players_mixin.dart';
import 'package:fitd26/screens/admin/widgets/player_list_item.dart';
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
    with CurrentChallengeMixin, AllPlayersMixin {
  @override
  void onChallengeCleared() {
    super.onChallengeCleared();
    clearAllPlayers();
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
      padding: const EdgeInsets.all(16),
      children: [
        const ShowModeControl(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showClearAllConfirmationDialog,
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Remove All Players'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red.shade300,
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () =>
                  _updateChallengeTime(const Duration(minutes: -1)),
              child: const Text('-1 min'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => _updateChallengeTime(const Duration(minutes: 1)),
              child: const Text('+1 min'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final challenger in allPlayers)
          PlayerListItem(
            challenger: challenger,
            onDelete: deleteChallenger,
            onUpdate: updateChallenger,
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
          final Timestamp timestamp => timestamp.toDate().toIso8601String(),
          final DateTime dateTime => dateTime.toIso8601String(),
          final value => value,
        },
    };
    return newMap;
  }

  void _showClearAllConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove All Players?'),
        content: const Text(
          'This will remove all players from the competition. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              clearAllPlayers();
              Navigator.of(context).pop();
            },
            child: const Text('Remove All'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateChallengeTime(Duration duration) async {
    final challenge = this.challenge;
    if (challenge == null) return;

    final newEndTime = challenge.endTime.add(duration);
    await FirebaseFirestore.instance.doc('/fitd/state').update({
      'endTime': newEndTime,
    });
  }
}

/// Host control for the audience /show screen: picks the view mode and (for
/// singlePlayer) the focused player. Writes the `show` map field on
/// `fitd/state`; every /show listener follows live.
class ShowModeControl extends StatelessWidget {
  const ShowModeControl({super.key});

  void _write(Map<String, Object?> showField) {
    FirebaseFirestore.instance.doc('/fitd/state').set({
      'show': showField,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.doc('/fitd/state').snapshots(),
      builder: (context, stateSnapshot) {
        final showState = ShowState.fromData(stateSnapshot.data?.data());
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('fitd')
              .doc('state')
              .collection('challengers')
              .snapshots(),
          builder: (context, playersSnapshot) {
            final players =
                playersSnapshot.data?.docs
                    .map(
                      (doc) => (
                        id: doc.id,
                        name: switch (doc.data()['name']) {
                          final String name => name,
                          _ => doc.id,
                        },
                      ),
                    )
                    .toList() ??
                const <({String id, String name})>[];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audience view (/show)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ViewMode>(
                      segments: [
                        for (final mode in ViewMode.values)
                          ButtonSegment(value: mode, label: Text(mode.label)),
                      ],
                      selected: {showState.viewMode},
                      onSelectionChanged: (selection) {
                        final mode = selection.first;
                        _write({
                          'viewMode': mode.name,
                          if (mode != ViewMode.singlePlayer)
                            'focusedPlayerId': null,
                        });
                      },
                    ),
                    if (showState.viewMode == ViewMode.singlePlayer) ...[
                      const SizedBox(height: 12),
                      DropdownMenu<String>(
                        label: const Text('Focused player'),
                        initialSelection: showState.focusedPlayerId,
                        dropdownMenuEntries: [
                          for (final player in players)
                            DropdownMenuEntry(
                              value: player.id,
                              label: player.name,
                            ),
                        ],
                        onSelected: (id) {
                          if (id != null) _write({'focusedPlayerId': id});
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
