import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/screens/admin/set_challenge_dialog.dart';
import 'package:fitd25/screens/admin/widgets/all_challenges_sliver_list.dart';
import 'package:fitd25/screens/admin/widgets/all_players_sliver_list.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class AdminChallengeSelectionScreen extends StatefulWidget {
  const AdminChallengeSelectionScreen({super.key});

  @override
  State<AdminChallengeSelectionScreen> createState() =>
      _AdminChallengeSelectionScreenState();
}

class _AdminChallengeSelectionScreenState
    extends State<AdminChallengeSelectionScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _challengesStream;

  @override
  void initState() {
    super.initState();
    _challengesStream = FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .collection('challenges')
        .snapshots();
  }

  Future<void> _showSetChallengeDialog(
    BuildContext context,
    ChallengeBase challenge,
  ) async {
    final now = DateTime.now();

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => SetChallengeDialog(initialDate: now),
    );

    if (result == null) return;

    final timedChallenge = Challenge(
      name: challenge.name,
      dartPadId: challenge.dartPadId,
      challengeId: challenge.challengeId,
      imageUrls: challenge.imageUrls,
      widgetJson: challenge.widgetJson,
      startTime: result['startTime']!,
      endTime: result['endTime']!,
    );

    await FirebaseFirestore.instance
        .doc('/fitd/state')
        .set(timedChallenge.toJson());
  }

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
              // SliverToBoxAdapter(
              //   child: const Center(child: Text('Challenges:')),
              // ),
              // const SliverGap(10),
              // StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              //   stream: _challengesStream,
              //   builder: (context, snapshot) {
              //     if (snapshot.hasError) {
              //       return Text('Error: ${snapshot.error}');
              //     }
              //     if (snapshot.connectionState == ConnectionState.waiting) {
              //       print('Waiting for challenges...');
              //       return const Center(child: CircularProgressIndicator());
              //     }
              //     final challenges = snapshot.data!.docs
              //         .map((doc) => ChallengeBase.fromJson(doc.data()))
              //         .toList();
              //     return Column(
              //       children: [
              //         for (final challenge in challenges)
              //           ListTile(
              //             title: Text(challenge.name),
              //             trailing: Row(
              //               mainAxisSize: MainAxisSize.min,
              //               children: [
              //                 ElevatedButton(
              //                   onPressed: () =>
              //                       _showSetChallengeDialog(context, challenge),
              //                   child: const Text('Set as current'),
              //                 ),
              //                 IconButton(
              //                   tooltip: 'Edit challenge',
              //                   icon: const Icon(Icons.edit),
              //                   onPressed: () {
              //                     Navigator.of(context).push(
              //                       MaterialPageRoute(
              //                         builder: (context) => EditChallengeScreen(
              //                           challenge: challenge,
              //                         ),
              //                       ),
              //                     );
              //                   },
              //                 ),
              //               ],
              //             ),
              //           ),
              //       ],
              //     );
              //   },
              // ),
            ],
          ),
        ),
      ],
    );
  }
}
