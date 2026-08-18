import 'package:fitd26/room/room_models.dart';
import 'package:fitd26/room/room_sync.dart';
import 'package:flutter/material.dart';

/// The host's control screen. Reached ONLY via the Tailscale-facing listener
/// — the public route never serves /admin at all, so there is no app-level
/// auth here (the network gate is the auth).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.roomSync});

  final RoomSync roomSync;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  void initState() {
    super.initState();
    widget.roomSync.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.roomSync.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.roomSync.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin — Prompting in the Dark')),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AudienceViewCard(roomSync: widget.roomSync, state: state),
                const SizedBox(height: 16),
                _TriStateCard(roomSync: widget.roomSync, state: state),
                const SizedBox(height: 16),
                _ChallengeCard(roomSync: widget.roomSync, state: state),
                const SizedBox(height: 16),
                _PlayersCard(roomSync: widget.roomSync, state: state),
              ],
            ),
    );
  }
}

/// Audience view mode + focused player (tappable chips, §6.D).
class _AudienceViewCard extends StatelessWidget {
  const _AudienceViewCard({required this.roomSync, required this.state});

  final RoomSync roomSync;
  final RoomState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audience view (/show)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<ViewMode>(
              segments: [
                for (final mode in ViewMode.values)
                  ButtonSegment(value: mode, label: Text(mode.label)),
              ],
              selected: {state.show.viewMode},
              onSelectionChanged: (selection) {
                final mode = selection.first;
                roomSync.client.setShowView(
                  viewMode: mode,
                  focusedPlayerId:
                      mode == ViewMode.singlePlayer
                          ? state.show.focusedPlayerId
                          : null,
                );
              },
            ),
            if (state.show.viewMode == ViewMode.singlePlayer) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final player in state.challengers)
                    ChoiceChip(
                      label: Text(player.name),
                      selected: state.show.focusedPlayerId == player.id,
                      onSelected: (_) {
                        roomSync.client.setShowView(
                          viewMode: ViewMode.singlePlayer,
                          focusedPlayerId: player.id,
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The tri-state reveal: Prompt | Code | Widget. Scope follows the view mode
/// — Challenge+all / All players flip every challenger at once; Single player
/// flips only the focused one (§6.C step 5).
class _TriStateCard extends StatelessWidget {
  const _TriStateCard({required this.roomSync, required this.state});

  final RoomSync roomSync;
  final RoomState state;

  @override
  Widget build(BuildContext context) {
    final single = state.show.viewMode == ViewMode.singlePlayer;
    final focusedId = state.show.focusedPlayerId;
    final current = single && focusedId != null
        ? state.contentFor(focusedId)
        : state.globalContent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Reveal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                Text(
                  single
                      ? 'applies to the focused player only'
                      : 'applies to ALL players at once',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<DisplayContent>(
              segments: [
                for (final content in DisplayContent.values)
                  ButtonSegment(value: content, label: Text(content.label)),
              ],
              selected: {current},
              onSelectionChanged: (selection) {
                final content = selection.first;
                if (single && focusedId != null) {
                  roomSync.client.setContentFor(
                    playerId: focusedId,
                    content: content,
                  );
                } else {
                  roomSync.client.setContentAll(content: content);
                }
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Switching to Code or Widget before a player is ready shows a '
              'loader on /show and on their own screen.',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Set / adjust / clear the current challenge (a pre-compiled widget URL).
class _ChallengeCard extends StatefulWidget {
  const _ChallengeCard({required this.roomSync, required this.state});

  final RoomSync roomSync;
  final RoomState state;

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  final _nameController = TextEditingController();
  final _widgetUrlController = TextEditingController();
  final _minutesController = TextEditingController(text: '5');

  @override
  void dispose() {
    _nameController.dispose();
    _widgetUrlController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _setChallenge() async {
    final minutes = int.tryParse(_minutesController.text) ?? 5;
    final now = DateTime.now();
    await widget.roomSync.client.setChallenge(
      name: _nameController.text.trim(),
      widgetUrl: _widgetUrlController.text.trim(),
      startTime: now,
      endTime: now.add(Duration(minutes: minutes)),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Challenge started')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.state.challenge;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Challenge', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (challenge != null) ...[
              Text(
                '"${challenge.name}" — ends '
                '${challenge.endTime.toLocal().toString().substring(11, 19)}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => widget.roomSync.client
                        .adjustTime(delta: const Duration(minutes: -1)),
                    child: const Text('-1 min'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => widget.roomSync.client
                        .adjustTime(delta: const Duration(minutes: 1)),
                    child: const Text('+1 min'),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: widget.roomSync.client.clearChallenge,
                    icon: const Icon(Icons.clear, color: Colors.redAccent),
                    label: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
            ],
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Challenge name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _widgetUrlController,
              decoration: const InputDecoration(
                labelText: 'Pre-compiled widget URL (/compiled/<id>)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _setChallenge,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    challenge == null ? 'Start challenge' : 'Restart challenge',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-challenger rows: live pipeline state + regenerate backstop + remove.
class _PlayersCard extends StatelessWidget {
  const _PlayersCard({required this.roomSync, required this.state});

  final RoomSync roomSync;
  final RoomState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Players (${state.challengers.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (state.challengers.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _confirmRemoveAll(context),
                    icon: const Icon(
                      Icons.delete_sweep,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'Remove all',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.challengers.isEmpty)
              const Text(
                'No players yet.',
                style: TextStyle(color: Colors.white38),
              )
            else
              for (final player in state.challengers)
                ListTile(
                  leading: _stateIcon(player.genState),
                  title: Text(player.name),
                  subtitle: Text(
                    '${player.genState.name}'
                    '${player.fixAttempts > 0 ? ' (${player.fixAttempts} fixes)' : ''}'
                    '${player.error != null ? ' — ${player.error}' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Regenerate (manual backstop)',
                        icon: const Icon(Icons.refresh),
                        onPressed: () =>
                            roomSync.client.regenerate(playerId: player.id),
                      ),
                      IconButton(
                        tooltip: 'Remove player',
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => roomSync.client
                            .removeChallenger(playerId: player.id),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _stateIcon(GenState state) => switch (state) {
    GenState.idle => const Icon(Icons.edit, color: Colors.white38),
    GenState.queued => const Icon(Icons.schedule, color: Colors.orange),
    GenState.generating => const Icon(Icons.auto_awesome, color: Colors.blue),
    GenState.compiling => const Icon(Icons.build, color: Colors.purple),
    GenState.ready => const Icon(Icons.check_circle, color: Colors.green),
    GenState.failed => const Icon(Icons.error, color: Colors.red),
  };

  void _confirmRemoveAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove all players?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              roomSync.client.removeAllChallengers();
              Navigator.of(context).pop();
            },
            child: const Text('Remove all'),
          ),
        ],
      ),
    );
  }
}
