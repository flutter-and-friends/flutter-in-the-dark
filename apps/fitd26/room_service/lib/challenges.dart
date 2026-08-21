/// Challenge catalog for the admin's challenge picker.
///
/// A registry of pre-authored challenges (name + full Dart source + assets)
/// that the admin can browse via `GET /api/admin/challenges` and compile on
/// demand via `POST /api/admin/challenges/compile`. Compiled widget URLs are
/// cached in memory (name → `/compiled/<id>`) so a re-pick of an already
/// compiled challenge is instant; the cache is lost on restart (the backend's
/// own compiled artifacts expire after 2 h anyway, so persisting URLs would
/// be wrong). Cached URLs are probed for liveness before being served (the
/// backend's store is in-memory + TTL'd) and transparently re-compiled from
/// [ChallengeEntry.source] when dead — the source is the truth, the cache is
/// disposable.
///
/// Challenge assets come from two places, merged at registry construction:
///
/// 1. The hardcoded [ChallengeEntry.assets] on each seed entry — the base.
/// 2. Disk: `<challengesRoot>/<slug>/assets/<file>` relative to the server's
///    CWD (launched from `apps/fitd26/room_service/`, so the default root
///    resolves to `apps/fitd26/room_service/challenges/<slug>/assets/`).
///    Every non-dotfile regular file under `assets/` becomes one asset:
///    filename WITHOUT extension → file contents (text assets only:
///    snippets, data, prompts). Disk assets OVERRIDE the base on key
///    collision — an operator dropping a file expects it to take effect.
///    A disk dir whose slug matches no catalog entry is ignored: the
///    catalog is source-authored, never invented from the filesystem.
///
/// The slug maps a challenge name to a directory name: lowercase, every run
/// of non-alphanumeric characters collapsed to a single `-`, leading/trailing
/// `-` trimmed. `'Hello, Dark!'` ↔ `hello-dark`. Exact directory matching is
/// deliberately not by raw name — spaces/punctuation in directory names are
/// brittle across shells and OSes.
///
/// Pure Dart — no shelf imports; routes live in `bin/server.dart`.
library;

import 'dart:io';

/// One catalog entry: the picker shows [name] + [assets]; [source] is the
/// full self-contained Dart source sent to the backend on compile.
class ChallengeEntry {
  const ChallengeEntry({
    required this.name,
    required this.source,
    this.assets = const {},
  });

  final String name;
  final String source;

  /// Base assets, hardcoded in source. Disk assets (same slug's
  /// `assets/` dir) override these on key collision at registry
  /// construction; the picker only ever sees the merged map.
  final Map<String, String> assets;

  /// A copy of this entry with [assets] replaced by [mergedAssets]. Used by
  /// [ChallengeRegistry] to fold disk assets in without mutating the const
  /// seed (the seed must stay const-constructible).
  ChallengeEntry withAssets(Map<String, String> mergedAssets) {
    return ChallengeEntry(
      name: name,
      source: source,
      assets: mergedAssets,
    );
  }

  /// The picker-facing shape. `widgetUrl` is intentionally NOT here — it is a
  /// compile-product, injected by [ChallengeRegistry.list] from the cache.
  Map<String, dynamic> toJson() => {'name': name, 'assets': assets};
}

class ChallengeRegistry {
  ChallengeRegistry({String challengesRoot = 'challenges'}) {
    for (final entry in seed) {
      final diskAssets = _loadDiskAssets(challengesRoot, slugFor(entry.name));
      if (diskAssets.isEmpty) {
        _entries.add(entry);
        continue;
      }
      // Base first, disk second: disk wins on key collision.
      _entries.add(entry.withAssets({...entry.assets, ...diskAssets}));
      stdout.writeln(
        'challenge "${entry.name}": ${diskAssets.length} assets '
        'loaded from disk',
      );
    }
  }

  /// Seeded catalog. Entries must be self-contained single-file Flutter apps
  /// that compile under dart_services' flutter_web project template: pure
  /// `package:flutter/material.dart`, no packages, no assets.
  static const List<ChallengeEntry> seed = [
    ChallengeEntry(
      name: 'Hello, Dark!',
      source: '''
import 'package:flutter/material.dart';

void main() {
  runApp(const HelloDarkApp());
}

class HelloDarkApp extends StatelessWidget {
  const HelloDarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HelloDarkScreen(),
    );
  }
}

class HelloDarkScreen extends StatelessWidget {
  const HelloDarkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nightlight_round, color: accent, size: 40),
            const SizedBox(height: 16),
            Text(
              'Hello, Dark!',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 120,
              height: 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
''',
    ),
  ];

  /// Catalog entries with disk assets merged in (same order as [seed]).
  final List<ChallengeEntry> _entries = [];

  /// name → widgetUrl (`/compiled/<id>`) cache for already-compiled entries.
  final Map<String, String> _compiled = {};

  /// The slug for a challenge name: lowercase, non-alphanumeric runs → `-`,
  /// leading/trailing `-` trimmed. `'Hello, Dark!'` → `'hello-dark'`.
  static String slugFor(String name) {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    // Trim leading/trailing '-' left over from collapsed runs.
    return slug.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Reads `<root>/<slug>/assets/` and returns every regular non-dotfile as
  /// `filename-without-extension → contents`. Missing directory → empty.
  /// Sync read on purpose: this runs once at startup, files are small.
  static Map<String, String> _loadDiskAssets(String root, String slug) {
    final dir = Directory('$root${Platform.pathSeparator}$slug'
        '${Platform.pathSeparator}assets');
    if (!dir.existsSync()) return const {};
    final assets = <String, String>{};
    for (final entity in dir.listSync()) {
      if (entity is! File) continue; // skip subdirectories
      final filename = entity.uri.pathSegments.last;
      if (filename.startsWith('.')) continue; // skip dotfiles
      final dot = filename.lastIndexOf('.');
      final key = dot > 0 ? filename.substring(0, dot) : filename;
      assets[key] = entity.readAsStringSync();
    }
    return assets;
  }

  /// All catalog entries as picker JSON, each with `widgetUrl` set from the
  /// compile cache (null when not yet compiled this process lifetime).
  List<Map<String, dynamic>> list() => [
    for (final entry in _entries)
      {...entry.toJson(), 'widgetUrl': compiledUrlFor(entry.name)},
  ];

  ChallengeEntry? byName(String name) {
    for (final entry in _entries) {
      if (entry.name == name) return entry;
    }
    return null;
  }

  void cacheCompiled(String name, String widgetUrl) {
    _compiled[name] = widgetUrl;
  }

  /// Drops the cached widgetUrl for [name] (used when a probe finds the
  /// backend no longer serves it — a dead URL must never be handed out).
  void evictCompiled(String name) {
    _compiled.remove(name);
  }

  String? compiledUrlFor(String name) => _compiled[name];

  /// Names with a cached widgetUrl (the only ones a freshness probe cares
  /// about — uncached entries compile on demand via the compile route).
  Iterable<String> get cachedNames => _compiled.keys.toList();
}
