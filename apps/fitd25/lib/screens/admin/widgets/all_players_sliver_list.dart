import 'package:fitd25/screens/admin/mixins/all_players_mixin.dart';
import 'package:fitd25/screens/admin/widgets/player_list_item.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class AllPlayersSliverList extends StatefulWidget {
  const AllPlayersSliverList({super.key});

  @override
  State<AllPlayersSliverList> createState() =>
      _AllPlayersSliverListState();
}

class _AllPlayersSliverListState extends State<AllPlayersSliverList>
    with AllPlayersMixin {
  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: Center(child: Text('Challengers in the lobby:')),
        ),
        const SliverGap(10),
        for (final challenger in allChallengers)
          SliverToBoxAdapter(
            child: PlayerListItem(
              challenger: challenger,
              onDelete: deleteChallenger,
              onUpdate: updateChallenger,
            ),
          ),
      ],
    );
  }
}
