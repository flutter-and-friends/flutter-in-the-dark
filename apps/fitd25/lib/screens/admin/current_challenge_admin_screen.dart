import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd25/providers/all_players_provider.dart';
import 'package:fitd25/providers/current_challenge_provider.dart';
import 'package:fitd25/screens/admin/widgets/player_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class CurrentChallengeAdminScreen extends ConsumerWidget {
  const CurrentChallengeAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(currentChallengeProvider);
    final allPlayersAsync = ref.watch(allPlayersProvider);

    ref.listen(currentChallengeProvider, (previous, next) {
      if (previous?.value != null && next.value == null) {
        ref.read(allPlayersProvider.notifier).clearAllPlayers();
      }
    });

    final challenge = challengeAsync.value;
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
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showClearAllConfirmationDialog(context, ref),
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
              onPressed: () => ref
                  .read(currentChallengeProvider.notifier)
                  .updateChallengeTime(const Duration(minutes: -1)),
              child: const Text('-1 min'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => ref
                  .read(currentChallengeProvider.notifier)
                  .updateChallengeTime(const Duration(minutes: 1)),
              child: const Text('+1 min'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        allPlayersAsync.when(
          data: (allPlayers) {
            return Column(
              children: [
                for (final challenger in allPlayers)
                  PlayerListItem(
                    challenger: challenger,
                    onDelete: (player) => ref
                        .read(allPlayersProvider.notifier)
                        .deletePlayer(player),
                    onUpdate: (player) => ref
                        .read(allPlayersProvider.notifier)
                        .updatePlayer(player),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('Error: $error')),
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

  void _showClearAllConfirmationDialog(BuildContext context, WidgetRef ref) {
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
              ref.read(allPlayersProvider.notifier).clearAllPlayers();
              Navigator.of(context).pop();
            },
            child: const Text('Remove All'),
          ),
        ],
      ),
    );
  }
}
