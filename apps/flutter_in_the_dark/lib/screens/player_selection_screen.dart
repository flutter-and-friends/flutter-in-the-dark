import 'package:flutter_in_the_dark/room/room_sync.dart';
import 'package:flutter_in_the_dark/room/session_store.dart';
import 'package:flutter_in_the_dark/screens/challenge_screen.dart';
import 'package:flutter/material.dart';

/// Challenger join: name field → Start challenge → lobby/challenge screen
/// (unchanged from the POC flow).
class PlayerSelectionScreen extends StatefulWidget {
  const PlayerSelectionScreen({super.key, required this.roomSync});

  final RoomSync roomSync;

  @override
  State<PlayerSelectionScreen> createState() => _PlayerSelectionScreenState();
}

class _PlayerSelectionScreenState extends State<PlayerSelectionScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  void _goToChallenge() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ChallengeScreen(roomSync: widget.roomSync),
      ),
    );
  }

  Future<void> _startChallenge() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Join is `{name}` only: the server always mints a fresh (playerId,
      // token, roundId) for the current round — no reattach. The name is
      // always freshly entered; round-scoped server state, never
      // client-persisted (WI-012).
      final result = await widget.roomSync.client.join(name);
      SessionStore.write(
        playerId: result.playerId,
        token: result.token,
        roundId: result.roundId,
      );
      _goToChallenge();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join the Challenge')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _nameController,
                onSubmitted: (_) => _startChallenge(),
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
                  onPressed: _startChallenge,
                  child: const Text('Start Challenge'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
