import 'dart:convert';

import 'package:flutter_in_the_dark/helpers/challenge_filter.dart';
import 'package:flutter_in_the_dark/room/room_client.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter/material.dart';

// The scoring/filtering lives in lib/helpers/challenge_filter.dart (pure
// Dart, no Flutter/web imports) so it is unit-testable on the VM; re-export
// it so callers of the picker need only one import.
export 'package:flutter_in_the_dark/helpers/challenge_filter.dart';

/// What the admin picked: [name], the catalog entry's [assets], and a
/// resolved [widgetUrl] — either the pre-compiled URL the catalog already
/// had, or one produced by a compile the picker ran inline.
typedef ChallengePick = ({
  String name,
  String widgetUrl,
  Map<String, String> assets,
});

/// Opens the challenge-catalog picker as a modal bottom sheet and resolves
/// with the admin's [ChallengePick], or `null` if dismissed.
///
/// Uses the root navigator so the sheet is not clipped by a nested
/// [Scaffold]; it is safe to call from anywhere under the admin screen.
Future<ChallengePick?> showChallengePicker(
        BuildContext context, RoomClient client) =>
    showModalBottomSheet<ChallengePick>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => ChallengePickerSheet(client: client),
    );

// ---------------------------------------------------------------------------
// The sheet
// ---------------------------------------------------------------------------

/// Modal bottom sheet listing the server challenge catalog with live
/// contains-first / fuzzy-fallback filtering. Pre-compiled rows resolve
/// immediately; uncompiled rows compile inline (slow on first call — the row
/// shows a spinner) and resolve with the fresh URL. Compile failures show
/// the server's problems as a SnackBar and keep the sheet open.
class ChallengePickerSheet extends StatefulWidget {
  const ChallengePickerSheet({super.key, required this.client});

  final RoomClient client;

  @override
  State<ChallengePickerSheet> createState() => _ChallengePickerSheetState();
}

class _ChallengePickerSheetState extends State<ChallengePickerSheet> {
  final _searchController = TextEditingController();
  List<ChallengeInfo>? _challenges;
  Object? _error;
  bool _loading = true;

  /// Name of the challenge currently compiling, if any.
  String? _compilingName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final challenges = await widget.client.fetchChallenges();
      if (!mounted) return;
      setState(() {
        _challenges = challenges;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _onTap(ChallengeInfo info) async {
    final url = info.widgetUrl;
    if (url != null) {
      Navigator.of(
        context,
      ).pop((name: info.name, widgetUrl: url, assets: info.assets));
      return;
    }
    if (_compilingName != null) return; // one compile at a time
    setState(() => _compilingName = info.name);
    try {
      final compiled = await widget.client.compileChallenge(info.name);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop((name: info.name, widgetUrl: compiled, assets: info.assets));
    } catch (e) {
      if (!mounted) return;
      setState(() => _compilingName = null);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Compile failed for "${info.name}"${_problems(e)}',
            ),
            duration: const Duration(seconds: 8),
          ),
        );
    }
  }

  /// Extracts the server's `problems` list out of a [RoomPostException]
  /// body (`{"error":"compile_failed","problems":[...]}`).
  String _problems(Object error) {
    if (error is! RoomPostException) return ': $error';
    try {
      final problems =
          (jsonDecode(error.body) as Map)['problems'] as List? ?? const [];
      if (problems.isEmpty) return '';
      return ':\n${problems.map((p) => '• $p').join('\n')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenges = _challenges;
    final filtered = challenges == null
        ? const <ChallengeInfo>[]
        : filterChallenges(_searchController.text, challenges);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search challenges',
                hintText: 'contains first, then fuzzy',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(child: _body(scrollController, challenges, filtered)),
        ],
      ),
    );
  }

  Widget _body(
    ScrollController scrollController,
    List<ChallengeInfo>? challenges,
    List<ChallengeInfo> filtered,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Failed to load the challenge catalog.'),
            const SizedBox(height: 4),
            Text(
              '$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (challenges == null || challenges.isEmpty) {
      return const Center(
        child: Text('No challenges in the catalog yet.'),
      );
    }
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No challenges match "${_searchController.text.trim()}".',
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final info = filtered[index];
        final compiling = _compilingName == info.name;
        return ListTile(
          title: Text(info.name),
          subtitle: Text(
            '${info.assets.length} assets · '
            '${info.widgetUrl != null ? 'pre-compiled' : 'needs compile'}',
          ),
          trailing: compiling
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : info.widgetUrl == null
                  ? const Icon(Icons.build_outlined)
                  : null,
          onTap: _compilingName == null ? () => _onTap(info) : null,
        );
      },
    );
  }
}
