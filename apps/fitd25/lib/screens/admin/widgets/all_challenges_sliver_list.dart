import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/providers/all_challenges_provider.dart';
import 'package:fitd25/screens/admin/edit_challenge_screen.dart';
import 'package:fitd25/screens/admin/set_challenge_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

class AllChallengesSliverList extends ConsumerWidget {
  const AllChallengesSliverList({super.key});

  Future<void> _showSetChallengeDialog(
    BuildContext context,
    WidgetRef ref,
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

    await setCurrentChallenge(ref, timedChallenge);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(allChallengesProvider);

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: Center(child: Text('Challenges:'))),
        const SliverGap(10),
        challengesAsync.when(
          data: (challenges) {
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
                              _showSetChallengeDialog(context, ref, challenge),
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
          loading: () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => SliverToBoxAdapter(
            child: Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }
}
