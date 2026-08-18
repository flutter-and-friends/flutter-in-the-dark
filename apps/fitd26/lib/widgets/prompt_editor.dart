import 'dart:async';

import 'package:fitd26/room/room_client.dart';
import 'package:flutter/material.dart';

/// The contestant "Prompting in the Dark" editor: a comfortable multi-line
/// prompt writing surface that live-syncs (debounced) to the room service.
///
/// NO Generate button (§6.D): the buzzer pushes every prompt server-side;
/// the contestant never triggers generation.
class PromptEditor extends StatefulWidget {
  const PromptEditor({
    super.key,
    required this.playerId,
    required this.token,
    required this.initialPrompt,
    required this.client,
    this.enabled = true,
  });

  final String playerId;
  final String token;
  final String initialPrompt;
  final RoomClient client;
  final bool enabled;

  @override
  State<PromptEditor> createState() => PromptEditorState();
}

class PromptEditorState extends State<PromptEditor> {
  static const _debounce = Duration(milliseconds: 400);

  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  String _lastSyncedPrompt = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPrompt);
    _lastSyncedPrompt = widget.initialPrompt;
    // Place the cursor at the end.
    _controller.selection = TextSelection.collapsed(
      offset: widget.initialPrompt.length,
    );
  }

  void _onChanged(String text) {
    setState(() {}); // refresh character count
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => syncNow());
  }

  /// Flushes the current text to the room service immediately.
  Future<void> syncNow() async {
    _debounceTimer?.cancel();
    final text = _controller.text;
    if (text == _lastSyncedPrompt) return;
    _lastSyncedPrompt = text;
    try {
      await widget.client.updatePrompt(
        playerId: widget.playerId,
        token: widget.token,
        prompt: text,
      );
    } catch (_) {
      // Best-effort: the debounce will retry on the next keystroke, and the
      // buzzer flushes whatever made it. A dropped update shows up as a stale
      // prompt on /show, which the admin sees.
      _lastSyncedPrompt = '';
    }
  }

  @override
  void dispose() {
    if (_controller.text != _lastSyncedPrompt) {
      // Best-effort final flush.
      unawaited(
        widget.client.updatePrompt(
          playerId: widget.playerId,
          token: widget.token,
          prompt: _controller.text,
        ),
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
              if (!widget.enabled)
                const Text(
                  "Time's up — your prompt is with the generator.",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
