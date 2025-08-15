import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/mixins/current_challenge_mixin.dart';
import 'package:fitd25/screens/admin/admin_challenge_selection_screen.dart';
import 'package:fitd25/screens/admin/current_challenge_admin_screen.dart';
import 'package:fitd25/screens/admin/edit_challenge_screen.dart';
import 'package:flutter/material.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key, required this.user});

  final User user;

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen>
    with CurrentChallengeMixin {
  @override
  Widget build(BuildContext context) {
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
                        FirebaseFirestore.instance.doc('/fitd/state').set({});
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
              key: ValueKey('AdminChallengeSelectionScreen${widget.user.uid}'),
            ),
          ),
          if (challenge != null)
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
