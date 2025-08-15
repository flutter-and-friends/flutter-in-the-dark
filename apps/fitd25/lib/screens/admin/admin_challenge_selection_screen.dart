import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/screens/admin/widgets/all_challenges_sliver_list.dart';
import 'package:fitd25/screens/admin/widgets/all_players_sliver_list.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class AdminChallengeSelectionScreen extends StatelessWidget {
  const AdminChallengeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Center(child: Text('Welcome, ${user.displayName}!')),
              ),
              SliverToBoxAdapter(child: Center(child: Text(user.email!))),
              const SliverGap(20),
              const AllPlayersSliverList(),
              const SliverGap(20),
              const AllChallengesSliverList(),
            ],
          ),
        ),
      ],
    );
  }
}
