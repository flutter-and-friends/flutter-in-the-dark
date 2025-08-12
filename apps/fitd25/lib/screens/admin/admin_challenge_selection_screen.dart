import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/mixins/current_challenge_mixin.dart';
import 'package:fitd25/screens/admin/edit_challenge_screen.dart';
import 'package:fitd25/screens/admin/mixins/all_challengers_mixin.dart';
import 'package:fitd25/screens/admin/set_challenge_dialog.dart';
import 'package:fitd25/screens/admin/widgets/challenger_list_item.dart';
import 'package:flutter/material.dart';

class AdminChallengeSelectionScreen extends StatefulWidget {
  const AdminChallengeSelectionScreen({super.key});

  @override
  State<AdminChallengeSelectionScreen> createState() =>
      _AdminChallengeSelectionScreenState();
}

class _AdminChallengeSelectionScreenState
    extends State<AdminChallengeSelectionScreen>
    with CurrentChallengeMixin, AllChallengersMixin {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _challengesStream;

  @override
  void initState() {
    super.initState();
    _challengesStream = FirebaseFirestore.instance
        .collection('/fitd/state/challenges')
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

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Center(child: Text('Welcome, ${user.displayName}!')),
        Center(child: Text(user.email!)),
        const SizedBox(height: 20),
        const Center(child: Text('Challengers:')),
        const SizedBox(height: 10),
        for (final challenger in allChallengers)
          ChallengerListItem(
            challenger: challenger,
            onDelete: deleteChallenger,
            onUpdate: updateChallenger,
          ),
        const SizedBox(height: 20),
        const Center(child: Text('Challenges:')),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _challengesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final challenges = snapshot.data!.docs
                .map((doc) => ChallengeBase.fromJson(doc.data()))
                .toList();
            return Column(
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
