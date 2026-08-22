import 'package:flutter_in_the_dark/helpers/challenge_window.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_in_the_dark/room/room_sync.dart';
import 'package:flutter_in_the_dark/widgets/challenge_picker.dart';
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
                _ModelPickerCard(roomSync: widget.roomSync, state: state),
                const SizedBox(height: 16),
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

/// Live generation-model failover. Shows every candidate model with its
/// realistic-prompt reliability numbers (success %, latency, prose-leak,
/// quality) and switches the active model without a restart (WI-098).
class _ModelPickerCard extends StatelessWidget {
  const _ModelPickerCard({required this.roomSync, required this.state});

  final RoomSync roomSync;
  final RoomState state;

  @override
  Widget build(BuildContext context) {
    final gen = state.generation;
    // Best-first by the CONCURRENT (4-way load) success rate — the real event
    // condition — falling back to serial, so "the next best one" under load is
    // always at the top. Non-chat models (embeddings/whisper) are hidden.
    double scoreFor(ModelCandidate c) =>
        c.concurrentSuccessPct ?? c.successPct ?? -1;
    final sorted = [...gen.candidates.where((c) => c.isChat)]
      ..sort((a, b) {
        final sa = scoreFor(a);
        final sb = scoreFor(b);
        if (sa != sb) return sb.compareTo(sa);
        // Tiebreak: faster under load wins.
        final la = a.concurrentLatencyS ?? a.meanLatencyS ?? 1e9;
        final lb = b.concurrentLatencyS ?? b.meanLatencyS ?? 1e9;
        return la.compareTo(lb);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Generation model',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                const Text(
                  'applies live — no restart',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Headline numbers are measured under 4-way CONCURRENT load (4 '
              'contestants at the buzzer) — hit% + avg time. Pick the next '
              'best one to fail over.',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final c in sorted) _modelRow(context, c),
          ],
        ),
      ),
    );
  }

  Widget _modelRow(BuildContext context, ModelCandidate c) {
    // Headline = concurrent (4-way load) numbers when present; else serial.
    final hasConcurrent = c.concurrentSuccessPct != null;
    final hasSerial = c.successPct != null;
    final hasNumbers = hasConcurrent || hasSerial;
    final headlinePct = c.concurrentSuccessPct ?? c.successPct;
    final successColor = !hasNumbers
        ? Colors.white38
        : headlinePct! >= 90
        ? Colors.greenAccent
        : headlinePct >= 60
        ? Colors.orangeAccent
        : Colors.redAccent;

    return InkWell(
      onTap: c.active ? null : () => roomSync.client.setModel(model: c.id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: c.active ? Colors.greenAccent : Colors.white12,
            width: c.active ? 1.5 : 1,
          ),
          color: c.active
              ? Colors.greenAccent.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              c.active ? Icons.radio_button_checked : Icons.radio_button_off,
              color: c.active ? Colors.greenAccent : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          c.shortName,
                          style: TextStyle(
                            fontWeight:
                                c.active ? FontWeight.bold : FontWeight.normal,
                            color: c.active ? Colors.greenAccent : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (c.effort != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: Colors.blueAccent.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${c.effort} effort',
                            style: const TextStyle(
                                color: Colors.blueAccent, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    c.id,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: hasNumbers
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Headline: concurrent (4-way load) hit% + avg time.
                        Wrap(
                          spacing: 12,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _stat(
                              '${headlinePct!.toStringAsFixed(0)}%',
                              hasConcurrent ? 'ok ×4' : 'ok',
                              successColor,
                            ),
                            if ((c.concurrentLatencyS ?? c.meanLatencyS) !=
                                null)
                              _stat(
                                '${(c.concurrentLatencyS ?? c.meanLatencyS)!.toStringAsFixed(0)}s',
                                'avg',
                                Colors.white70,
                              ),
                            if (c.concurrentWallS != null)
                              _stat(
                                '${c.concurrentWallS!.toStringAsFixed(0)}s',
                                'worst',
                                c.concurrentWallS! > 60
                                    ? Colors.orangeAccent
                                    : Colors.white70,
                              ),
                            Text(
                              hasConcurrent
                                  ? '(${c.concurrentRuns}×4-way)'
                                  : '(${c.runs} serial)',
                              style: const TextStyle(
                                color: Colors.white24,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        // Secondary: serial baseline (when both are measured).
                        if (hasConcurrent && hasSerial)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'serial: ${c.successPct!.toStringAsFixed(0)}% ok · '
                              '${(c.meanLatencyS ?? 0).toStringAsFixed(0)}s',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    )
                  : const Text(
                      'not benchmarked yet',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
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
            LayoutBuilder(
              builder: (context, constraints) {
                void onSelected(Set<ViewMode> selection) {
                  final mode = selection.first;
                  roomSync.client.setShowView(
                    viewMode: mode,
                    focusedPlayerId: mode.isSinglePlayerScoped
                        ? state.show.focusedPlayerId
                        : null,
                  );
                }

                final rows = viewModeRows(constraints.maxWidth);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      SegmentedButton<ViewMode>(
                        segments: [
                          for (final mode in rows[i])
                            ButtonSegment(value: mode, label: Text(mode.label)),
                        ],
                        selected: {state.show.viewMode},
                        onSelectionChanged: onSelected,
                        // A row may not contain the current selection.
                        emptySelectionAllowed: true,
                      ),
                    ],
                  ],
                );
              },
            ),
            if (state.show.viewMode.isSinglePlayerScoped) ...[
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
                          viewMode: state.show.viewMode,
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
    final single = state.show.viewMode.isSinglePlayerScoped;
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
  final _startAfterController = TextEditingController(text: '10');

  /// Assets attached to the last catalog pick. Cleared by the TextFields'
  /// `onChanged` below, so hand-editing the name/URL never silently carries
  /// a stale pick's assets into `setChallenge`.
  Map<String, String> _pickedAssets = const {};

  @override
  void dispose() {
    _nameController.dispose();
    _widgetUrlController.dispose();
    _minutesController.dispose();
    _startAfterController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCatalog() async {
    final pick = await showChallengePicker(context, widget.roomSync.client);
    if (pick == null || !mounted) return;
    setState(() {
      // Assigning .text fires onChanged (which clears _pickedAssets), so
      // set _pickedAssets AFTER the controllers.
      _nameController.text = pick.name;
      _widgetUrlController.text = pick.widgetUrl;
      _pickedAssets = pick.assets;
    });
  }

  Future<void> _setChallenge() async {
    final window = computeChallengeWindow(
      now: DateTime.now(),
      startAfterSeconds: parseNonNegativeInt(_startAfterController.text, 10),
      durationMinutes: parseNonNegativeInt(_minutesController.text, 5),
    );
    await widget.roomSync.client.setChallenge(
      name: _nameController.text.trim(),
      widgetUrl: _widgetUrlController.text.trim(),
      startTime: window.start,
      endTime: window.end,
      assets: _pickedAssets,
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
              onChanged: (_) => setState(() => _pickedAssets = const {}),
              decoration: const InputDecoration(
                labelText: 'Challenge name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _widgetUrlController,
              onChanged: (_) => setState(() => _pickedAssets = const {}),
              decoration: const InputDecoration(
                labelText: 'Pre-compiled widget URL (/compiled/<id>)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickFromCatalog,
              icon: const Icon(Icons.list_alt),
              label: Text(
                _pickedAssets.isEmpty
                    ? 'Pick from catalog'
                    : 'Pick from catalog · ${_pickedAssets.length} assets '
                          'attached',
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
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _startAfterController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Start after (s)',
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
