import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd26/data/challenger.dart';
import 'package:flutter/material.dart';

/// The contestant "Prompting in the Dark" editor: a comfortable multi-line
/// prompt writing surface that live-syncs (debounced) to the player's
/// Firestore `prompt` field.
class PromptEditor extends StatefulWidget {
  const PromptEditor({
    super.key,
    required this.player,
    required this.onGenerate,
    this.enabled = true,
  });

  final Player player;

  /// Invoked with the flushed prompt when the Generate action is pressed.
  final void Function(String prompt) onGenerate;

  final bool enabled;

  @override
  State<PromptEditor> createState() => PromptEditorState();
}

class PromptEditorState extends State<PromptEditor> {
  static const _debounce = Duration(milliseconds: 400);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  String _lastSyncedPrompt = '';

  bool get _canGenerate =>
      widget.enabled && _controller.text.trim().length >= 10;

  @override
  void initState() {
    super.initState();
    _restorePrompt(widget.player.prompt);
  }

  @override
  void didUpdateWidget(PromptEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restore from Firestore only when the change came from elsewhere
    // (e.g. first load after auth): the doc value moved away from both what
    // we last synced and what is currently in the field.
    if (widget.player.id != oldWidget.player.id ||
        (widget.player.prompt != oldWidget.player.prompt &&
            widget.player.prompt != _lastSyncedPrompt &&
            widget.player.prompt != _controller.text)) {
      _restorePrompt(widget.player.prompt);
    }
  }

  void _restorePrompt(String prompt) {
    if (prompt == _controller.text) return;
    _controller.value = TextEditingValue(
      text: prompt,
      selection: TextSelection.collapsed(offset: prompt.length),
    );
    _lastSyncedPrompt = prompt;
  }

  void _onChanged(String text) {
    setState(() {}); // refresh character count / Generate enablement
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => syncNow());
  }

  /// Flushes the current text to Firestore immediately (used by Generate and
  /// dispose). Writes ONLY the `prompt` field (partial write, I-015).
  Future<void> syncNow() async {
    _debounceTimer?.cancel();
    final text = _controller.text;
    if (text == _lastSyncedPrompt) return;
    _lastSyncedPrompt = text;
    await FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .doc(widget.player.id)
        .update({'prompt': text});
  }

  @override
  void dispose() {
    if (_controller.text != _lastSyncedPrompt) {
      // Best-effort final flush; Firestore's offline cache will deliver it.
      unawaited(
        FirebaseFirestore.instance
            .collection('fitd')
            .doc('state')
            .collection('challengers')
            .doc(widget.player.id)
            .update({'prompt': _controller.text}),
      );
    }
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final charCount = _controller.text.length;

    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your prompt',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Describe the app in one shot — the generator gets no '
            'follow-up questions.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? const Color(0xFF58A6FF)
                      : const Color(0xFF30363D),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                enabled: widget.enabled,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                cursorColor: const Color(0xFF58A6FF),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  height: 1.6,
                  color: Color(0xFFE6EDF3),
                ),
                decoration: const InputDecoration.collapsed(
                  hintText:
                      'A dark, neon-lit weather app for a rainy cyberpunk '
                      'city. The main screen shows…',
                  hintStyle: TextStyle(color: Color(0xFF484F58), height: 1.6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$charCount characters',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white38,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _canGenerate
                    ? () async {
                        await syncNow();
                        widget.onGenerate(_controller.text);
                      }
                    : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  disabledBackgroundColor: const Color(0xFF21262D),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
