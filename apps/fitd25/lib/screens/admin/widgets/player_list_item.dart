import 'package:fitd25/data/challenger.dart';
import 'package:fitd25/screens/admin/player_settings_modal.dart';
import 'package:flutter/material.dart';

class PlayerListItem extends StatelessWidget {
  const PlayerListItem({
    super.key,
    required this.challenger,
    required this.onDelete,
    required this.onUpdate,
  });

  final Challenger challenger;
  final Future<void> Function(Challenger) onDelete;
  final Future<void> Function(Challenger) onUpdate;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return PlayerSettingsModal(
              challenger: challenger,
              onDelete: onDelete,
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
          onUpdate(challenger.withStatus(newStatus));
        },
      ),
    );
  }
}
