import 'package:fitd26/room/room_client.dart';
import 'package:fitd26/room/room_models.dart';
import 'package:fitd26/widgets/compiled_widget.dart';
import 'package:fitd26/widgets/plasma_loader.dart';
import 'package:flutter/material.dart';

/// One challenger's content pane per the admin's tri-state selection
/// (Prompt | Code | Widget), with the loading state shown when the admin
/// flips to Code/Widget before generation+compile is `ready` (§6.C).
///
/// Used identically on `/show` and on the contestant's own done screen —
/// same render, same instant.
class ChallengerContent extends StatelessWidget {
  const ChallengerContent({
    super.key,
    required this.challenger,
    required this.content,
    this.expanded = false,
  });

  final Challenger challenger;
  final DisplayContent content;

  /// Bigger type for the single-player view.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final fontSize = expanded ? 24.0 : 14.0;
    return switch (content) {
      DisplayContent.prompt => _PromptPane(
        prompt: challenger.prompt,
        fontSize: fontSize,
      ),
      DisplayContent.code => _readyOrLoading(
        challenger,
        (code) => _CodePane(code: code, fontSize: fontSize),
      ),
      DisplayContent.widget => _readyOrLoading(
        challenger,
        (_) => _WidgetPane(challenger: challenger),
      ),
    };
  }

  Widget _readyOrLoading(
    Challenger challenger,
    Widget Function(String code) builder,
  ) {
    return switch (challenger.genState) {
      GenState.ready => builder(challenger.generatedCode ?? ''),
      GenState.failed => _FailedPane(error: challenger.error),
      _ => PlasmaLoader(
        label: switch (challenger.genState) {
          GenState.queued => 'Queued for generation…',
          GenState.generating => 'Generating code…',
          GenState.compiling => 'Compiling…',
          _ => 'Waiting…',
        },
      ),
    };
  }
}

class _PromptPane extends StatelessWidget {
  const _PromptPane({required this.prompt, required this.fontSize});

  final String prompt;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (prompt.isEmpty) {
      return Center(
        child: Text(
          'Thinking in the dark…',
          style: TextStyle(
            color: Colors.white24,
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      reverse: true,
      padding: const EdgeInsets.all(16),
      child: Text(
        prompt,
        style: TextStyle(
          fontFamily: 'monospace',
          color: const Color(0xFFE6EDF3),
          fontSize: fontSize,
          height: 1.5,
        ),
      ),
    );
  }
}

class _CodePane extends StatelessWidget {
  const _CodePane({required this.code, required this.fontSize});

  final String code;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (code.isEmpty) {
      return const PlasmaLoader(label: 'Waiting for code…');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          color: const Color(0xFFE6EDF3),
          fontSize: fontSize * 0.85,
          height: 1.45,
        ),
      ),
    );
  }
}

class _WidgetPane extends StatelessWidget {
  const _WidgetPane({required this.challenger});

  final Challenger challenger;

  @override
  Widget build(BuildContext context) {
    final url = challenger.compiledUrl;
    if (url == null) {
      return const PlasmaLoader(label: 'Waiting for compiled app…');
    }
    return CompiledWidget(url: '${RoomClient.compileBaseUrl}$url');
  }
}

class _FailedPane extends StatelessWidget {
  const _FailedPane({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Generation failed',
              style: TextStyle(color: Colors.redAccent, fontSize: 18),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
