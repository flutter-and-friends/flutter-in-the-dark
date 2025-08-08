import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:fitd25/screens/challenge_screen.dart';
import 'package:flutter/material.dart';

class ChallengerSelectionScreen extends StatefulWidget {
  const ChallengerSelectionScreen({super.key});

  @override
  State<ChallengerSelectionScreen> createState() =>
      _ChallengerSelectionScreenState();
}

class _ChallengerSelectionScreenState extends State<ChallengerSelectionScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _startChallenge() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      final user = userCredential.user;

      if (user != null) {
        final challenger = Challenger(id: user.uid, name: _nameController.text);

        await FirebaseFirestore.instance
            .collection('challengers')
            .doc(user.uid)
            .set(challenger.toFirestore());

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ChallengeScreen(challenger: challenger),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start challenge: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join the Challenge')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fitd')
            .doc('state')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: Text('No challenge active'));
          }

          final challenge = Challenge.fromFirestore(
            snapshot.data!.data()! as Map<String, dynamic>,
          );

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Current Challenge: ${challenge.name}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Enter your name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: () => _startChallenge(),
                      child: const Text('Start Challenge'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
