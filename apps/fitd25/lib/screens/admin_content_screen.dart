import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/screens/admin/edit_challenge_screen.dart';
import 'package:flutter/material.dart';

import 'admin/set_challenge_dialog.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key, required this.user});

  final User user;

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _fitdStateStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _challengesStream;

  @override
  void initState() {
    super.initState();
    _fitdStateStream = FirebaseFirestore.instance
        .doc('/fitd/state')
        .snapshots();
    _challengesStream = FirebaseFirestore.instance
        .collection('/fitd/state/challenges')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
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
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Center(child: Text('Welcome, ${widget.user.displayName}!')),
          Center(child: Text(widget.user.email!)),
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
                  .map(
                    (doc) => ChallengeBase(
                      name: doc.data()['name'] ?? '',
                      dartPadId: doc.data()['dartPadId'] ?? '',
                      challengeId: doc.id,
                      imageUrls: List<String>.from(
                        doc.data()['imageUrls'] ?? [],
                      ),
                      widgetJson:
                          doc.data()['widgetJson'] as Map<String, dynamic>? ??
                              {},
                    ),
                  )
                  .toList();
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: challenges.length,
                itemBuilder: (context, index) {
                  final challenge = challenges[index];
                  return ListTile(
                    title: Text(challenge.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => _showSetChallengeDialog(challenge),
                          child: const Text('Set as current'),
                        ),
                        IconButton(
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
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _fitdStateStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!.data();
              if (data == null) {
                return const Text('No data');
              }
              return Text(
                'Firestore Data: ${const JsonEncoder.withIndent('  ').convert(_jsonEncodable(data))}',
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showSetChallengeDialog(ChallengeBase challenge) async {
    final now = DateTime.now();
    if (!mounted) return;

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

  Map<String, dynamic> _jsonEncodable(Map<String, dynamic> map) {
    final newMap = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.value is Timestamp) {
        newMap[entry.key] = (entry.value as Timestamp)
            .toDate()
            .toIso8601String();
      } else {
        newMap[entry.key] = entry.value;
      }
    }
    return newMap;
  }
}
