import 'package:flutter_in_the_dark/helpers/session_identity.dart';
import 'package:flutter_in_the_dark/room/room_sync.dart';
import 'package:flutter_in_the_dark/room/session_store.dart';
import 'package:flutter_in_the_dark/screens/challenge_screen.dart';
import 'package:flutter/material.dart';

/// Challenger entry point. Boot flow:
///  - A stored session the server still knows (or can't be checked yet)
///    resumes STRAIGHT to the player screen — no name entry. Players persist
///    across challenges; only an admin Remove / Remove-all (the playerId
///    vanishing from the snapshot) forces re-registration.
///  - No stored session (or one the snapshot rejects) → name entry → join.
class PlayerSelectionScreen extends StatefulWidget {
  const PlayerSelectionScreen({super.key, required this.roomSync});

  final RoomSync roomSync;

  @override
  State<PlayerSelectionScreen> createState() => _PlayerSelectionScreenState();
}

class _PlayerSelectionScreenState extends State<PlayerSelectionScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  /// True while the boot decision routes a resumable session to the player
  /// screen — the name field is never flashed for a known player.
  bool _resuming = false;

  @override
  void initState() {
    super.initState();
    _decideBoot();
  }

  /// Boot: present the stored playerId to the server (`GET /api/session`) —
  /// "here's my ID, do you know me?". Known → resume straight to the player
  /// screen without name entry. Unknown (kicked / cleared / never joined) →
  /// clear the stored session and show name entry. When the server can't be
  /// asked yet (no snapshot, fetch fails), resume optimistically — the
  /// player screen's kick wiring arbitrates on the first snapshot. The pure
  /// decision over a snapshot is [decideBoot] (unit-tested on the VM); this
  /// is the wiring around the explicit whoami call.
  Future<void> _decideBoot() async {
    final session = SessionStore.read();
    if (session == null) return; // name entry
    setState(() => _resuming = true);
    // Ask the server. On failure, fall back to the snapshot (if one has
    // landed) and otherwise resume optimistically — the player screen
    // self-evicts on the first snapshot if the identity is gone.
    var known = decideBoot(
          storedPlayerId: session.playerId,
          state: widget.roomSync.state,
        ) !=
        BootDecision.evictToNameEntry;
    try {
      final answer = await widget.roomSync.client.fetchSession(
        session.playerId,
      );
      known = answer.known;
    } catch (_) {
      // Server unreachable — keep the snapshot/optimistic fallback above.
    }
    if (!mounted) return;
    if (known) {
      _goToChallenge();
    } else {
      SessionStore.clear();
      setState(() => _resuming = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

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
      // Join is `{name}` only: the server mints a fresh (playerId, token)
      // for this player. The identity then persists across challenges — a
      // new challenge never asks for the name again; only an admin Remove /
      // Remove-all does (the playerId disappears from the snapshot and the
      // player screen self-evicts back here).
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
    if (_resuming) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
