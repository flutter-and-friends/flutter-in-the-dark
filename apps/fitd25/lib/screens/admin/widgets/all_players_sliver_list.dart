import 'package:fitd25/providers/all_players_provider.dart';
import 'package:fitd25/screens/admin/widgets/player_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

class AllPlayersSliverList extends ConsumerWidget {
  const AllPlayersSliverList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPlayersAsync = ref.watch(allPlayersProvider);

    return allPlayersAsync.when(
      data: (allPlayers) {
        return SliverMainAxisGroup(
          slivers: [
            const SliverToBoxAdapter(
              child: Center(child: Text('Players in the lobby:')),
            ),
            const SliverGap(10),
            SliverList.list(
              children: [
                for (final challenger in allPlayers)
                  PlayerListItem(
                    challenger: challenger,
                    onDelete: (player) => deletePlayer(ref, player),
                    onUpdate: (player) => updatePlayer(ref, player),
                  ),
              ],
            ),
          ],
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => SliverToBoxAdapter(
        child: Center(child: Text('Error: $error')),
      ),
    );
  }
}
