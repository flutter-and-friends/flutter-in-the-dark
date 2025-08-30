import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/screens/admin/edit_challenge_screen.dart';
import 'package:fitd25/screens/admin/set_challenge_dialog.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class AllChallengesSliverList extends StatefulWidget {
  const AllChallengesSliverList({super.key});

  @override
  State<AllChallengesSliverList> createState() =>
      _AllChallengesSliverListState();
}

class _AllChallengesSliverListState extends State<AllChallengesSliverList> {
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
      builder: (context) => const SetChallengeDialog(),
    );

    if (result == null) return;

    final timedChallenge = Challenge(
      name: challenge.name,
      dartPadId: challenge.dartPadId,
      challengeId: challenge.challengeId,
      assets: challenge.assets,
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
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: Center(child: Text('Challenges:'))),
        const SliverGap(10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _challengesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SliverToBoxAdapter(
                child: Text('Error: ${snapshot.error}'),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final challenges = snapshot.data!.docs
                .map((doc) => ChallengeBase.fromJson(doc.data()))
                .toList(growable: false);
            return SliverList.list(
              children: [
                for (final challenge in challenges)
                  ListTile(
                    title: Text(challenge.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () =>
                              _showSetChallengeDialog(context, challenge),
                          child: const Text('Set as current'),
                        ),
                        IconButton(
                          tooltip: 'Edit challenge',
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditChallengeScreen(challenge: challenge),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
