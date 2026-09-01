import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/session_identity.dart';
import 'package:flutter_in_the_dark/room/room_sync.dart';
import 'package:flutter_in_the_dark/room/session_store.dart';
import 'package:flutter_in_the_dark/screens/challenge_screen.dart';
import 'package:flutter_in_the_dark/widgets/glitch_title.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop glow: the same midnight palette as the /show player
          // cards (#0D1117/#161B22), so a joining player's first frame
          // already feels like the game rather than a bare form.
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.35),
                radius: 1.3,
                colors: [Color(0xFF17202E), Color(0xFF0B0E14)],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlitchTitle(
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Colors.white,
                        shadows: const [
                          Shadow(blurRadius: 24, color: Color(0xFF58A6FF)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'One prompt. One widget. Beat the clock.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Join the challenge',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            autofocus: true,
                            textInputAction: TextInputAction.go,
                            onSubmitted: (_) => _startChallenge(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Your name',
                              hintText: 'The name the audience will see',
                              prefixIcon: const Icon(Icons.bolt),
                              filled: true,
                              fillColor: const Color(0xFF161B22),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF30363D),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF58A6FF),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : FilledButton.icon(
                                    onPressed: _startChallenge,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text(
                                      'Start Challenge',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
