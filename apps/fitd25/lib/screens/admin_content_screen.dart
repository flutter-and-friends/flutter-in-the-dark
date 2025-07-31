import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:flutter/material.dart';

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
    _fitdStateStream = FirebaseFirestore.instance.doc('/fitd/state').snapshots();
    _challengesStream =
        FirebaseFirestore.instance.collection('/fitd/state/challenges').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, ${widget.user.displayName}!'),
            Text(widget.user.email!),
            const SizedBox(height: 20),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _fitdStateStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
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
            const SizedBox(height: 20),
            const Text('Challenges:'),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _challengesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final challenges = snapshot.data!.docs
                    .map((doc) => ChallengeBase(
                          name: doc.data()['name'] ?? '',
                          dartPadId: doc.data()['dartPadId'] ?? '',
                          challengeId: doc.id,
                          imageUrls: List<String>.from(doc.data()['imageUrls'] ?? []),
                        ))
                    .toList();
                return Expanded(
                  child: ListView.builder(
                    itemCount: challenges.length,
                    itemBuilder: (context, index) {
                      final challenge = challenges[index];
                      return ListTile(
                        title: Text(challenge.name),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _jsonEncodable(Map<String, dynamic> map) {
    final newMap = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.value is Timestamp) {
        newMap[entry.key] = (entry.value as Timestamp).toDate().toIso8601String();
      } else {
        newMap[entry.key] = entry.value;
      }
    }
    return newMap;
  }
}