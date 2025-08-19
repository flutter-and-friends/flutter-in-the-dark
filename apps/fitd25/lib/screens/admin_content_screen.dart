import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/providers/current_challenge_provider.dart';
import 'package:fitd25/screens/admin/admin_challenge_selection_screen.dart';
import 'package:fitd25/screens/admin/current_challenge_admin_screen.dart';
import 'package:fitd25/screens/admin/edit_challenge_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminContentScreen extends ConsumerWidget {
  const AdminContentScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(currentChallengeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            tooltip: 'Create a new challenge',
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EditChallengeScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Clear the current state',
            icon: const Icon(Icons.clear),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear State'),
                  content: const Text(
                    'Are you sure you want to clear the current state?'
                    ' This will not delete the challenges, only the current state.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        clearCurrentChallenge(ref);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Navigator(
        onDidRemovePage: (_) {},
        pages: [
          MaterialPage(
            key: const ValueKey('AdminChallengeSelection'),
            child: AdminChallengeSelectionScreen(
              key: ValueKey('AdminChallengeSelectionScreen${user.uid}'),
            ),
          ),
          if (challengeAsync.value != null)
            const MaterialPage(
              key: ValueKey('CurrentChallengeAdminScreen'),
              child: CurrentChallengeAdminScreen(),
              fullscreenDialog: true,
            ),
        ],
      ),
    );
  }
}
