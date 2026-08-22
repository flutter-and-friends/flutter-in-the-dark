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
/// Where the catalog comes from
/// ----------------------------
///
/// The catalog is loaded ONCE at registry construction (sync, small files)
/// from two sources:
///
/// 1. **Disk** — `<challengesRoot>/<slug>/source.dart`, relative to the
///    server's CWD (launched from `apps/flutter_in_the_dark/room_service/`, so
///    the default root resolves to
///    `apps/flutter_in_the_dark/room_service/challenges/<slug>/`). Every
///    directory directly under the root that contains a `source.dart` becomes
///    a catalog entry — this deliberately extends the previous "catalog is
///    never invented from the filesystem" rule: disk `source.dart` dirs now
///    ARE the catalog when any exist. The entry's name comes from a `// name:
///    Name` directive on the FIRST line of `source.dart` when present
///    (e.g. `// name: Hello, Dark!`), else from humanizing the slug
///    (`hello-dark` → `Hello Dark`). The served source is the file content
///    MINUS the directive line: stripping keeps the compile input
///    byte-identical to what the equivalent seed entry would have carried
///    (the directive is authoring metadata, not app source; a leading comment
///    would be harmless to compilation, but stripping keeps the file the
///    single source of truth for BOTH name and source with zero compile-path
///    delta).
/// 2. **Seed fallback** — the hardcoded [seed] list (kept with 'Hello,
///    Dark!'). Used ONLY when NO disk `source.dart` dirs exist at all. When
///    disk entries exist, disk is the whole catalog and the seed is ignored
///    entirely (not merged — an operator dropping challenge files expects
///    exactly those files to be the picker list).
///
/// Challenge assets are merged onto each entry at construction:
///
/// 1. The hardcoded [ChallengeEntry.assets] on the entry (seed entries only)
///    — the base.
/// 2. Disk: `<challengesRoot>/<slug>/assets/<file>`. Every non-dotfile
///    regular file under `assets/` becomes one asset: filename WITHOUT
///    extension → file contents (text assets only: snippets, data, prompts).
///    Disk assets OVERRIDE the base on key collision — an operator dropping a
///    file expects it to take effect.
///
/// A disk dir WITHOUT `source.dart` but WITH `assets/` keeps the historical
/// behavior ONLY if its slug matches another entry (a seed-fallback entry, or
/// another disk entry whose source.dart carries a `// name:` directive that
/// slugifies to that slug); otherwise the dir is ignored.
///
/// The slug maps a challenge name to a directory name: lowercase, every run
/// of non-alphanumeric characters collapsed to a single `-`, leading/trailing
/// `-` trimmed. `'Hello, Dark!'` ↔ `hello-dark`. Exact directory matching is
/// deliberately not by raw name — spaces/punctuation in directory names are
/// brittle across shells and OSes. A `// name:` directive whose human name
/// slugifies DIFFERENTLY than its own directory still resolves its assets
/// from its own directory (the directory is the entry's home; the directive
/// only renames it for the picker).
///
/// Restart semantics: files are read once at construction. Adding or editing
/// a challenge (`source.dart`, the `// name:` line, or anything under
/// `assets/`) requires a server restart to take effect — same as the
/// historical disk-asset behavior.
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
  /// Builds the catalog per the rules in the library doc comment: disk
  /// `source.dart` dirs when any exist, else the [seed] fallback; disk assets
  /// merged onto every entry. [challengesRoot] is relative to the server's
  /// CWD (default: `challenges` → `apps/flutter_in_the_dark/room_service/challenges/`).
  ChallengeRegistry({String challengesRoot = 'challenges'}) {
    final diskEntries = _loadDiskEntries(challengesRoot);
    final base = diskEntries.isNotEmpty ? diskEntries : seed;
    for (final entry in base) {
      // The entry's assets dir is keyed by the slug of its NAME. For a disk
      // entry with no directive the name IS the humanized slug, so this
      // resolves back to the same directory; a directive-renamed entry whose
      // name slugifies differently is re-pointed at its own directory below
      // (its assets live with its source.dart, not under the renamed slug).
      var assetSlug = slugFor(entry.name);
      final diskHome = _diskHomeByName[entry.name];
      if (diskHome != null) assetSlug = diskHome;
      final diskAssets = _loadDiskAssets(challengesRoot, assetSlug);
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

  /// Seeded catalog — the FALLBACK used only when no disk `source.dart`
  /// entries exist (see the library doc comment). Entries must be
  /// self-contained single-file Flutter apps that compile under
  /// dart_services' flutter_web project template: pure
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

  /// Catalog entries with disk assets merged in (same order as the source
  /// list: disk entries sorted by slug, or [seed] order on fallback).
  final List<ChallengeEntry> _entries = [];

  /// name → the slug of the disk directory the entry was loaded from. Lets a
  /// directive-renamed disk entry find the assets that live next to its own
  /// source.dart even when its display name slugifies differently. Empty for
  /// seed-fallback entries (their assets resolve by name slug, as before).
  final Map<String, String> _diskHomeByName = {};

  /// name → widgetUrl (`/compiled/<id>`) cache for already-compiled entries.
  final Map<String, String> _compiled = {};

  /// The slug for a challenge name: lowercase, non-alphanumeric runs → `-`,
  /// leading/trailing `-` trimmed. `'Hello, Dark!'` → `'hello-dark'`.
  static String slugFor(String name) {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    // Trim leading/trailing '-' left over from collapsed runs.
    return slug.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// The inverse of [slugFor] for display when a `source.dart` carries no
  /// `// name:` directive: split on `-`, capitalize each word.
  /// `'hello-dark'` → `'Hello Dark'`.
  static String _humanize(String slug) {
    final words = slug.split('-').where((w) => w.isNotEmpty);
    return [
      for (final w in words) w[0].toUpperCase() + w.substring(1),
    ].join(' ');
  }

  /// Scans [root] for `<slug>/source.dart` dirs and returns one catalog entry
  /// per dir, sorted by slug for a stable picker order. Populates
  /// [_diskHomeByName] for directive-renamed entries. Name resolution: a
  /// `// name: <Name>` directive on the first line wins; else the humanized
  /// slug. The served source is the file content minus the directive line
  /// (see the library doc comment for why it is stripped). Sync on purpose:
  /// runs once at startup, files are small.
  List<ChallengeEntry> _loadDiskEntries(String root) {
    final dir = Directory(root);
    if (!dir.existsSync()) return const [];
    final entries = <ChallengeEntry>[];
    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;
      final slug = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      final sourceFile = File(
        '${entity.path}${Platform.pathSeparator}source.dart',
      );
      if (!sourceFile.existsSync()) continue;
      var source = sourceFile.readAsStringSync();
      var name = _humanize(slug);
      final firstBreak = source.indexOf('\n');
      final firstLine =
          firstBreak == -1 ? source : source.substring(0, firstBreak);
      final directive = RegExp(r'^//\s*name:\s*(.*?)\s*$').firstMatch(firstLine);
      if (directive != null && directive.group(1)!.isNotEmpty) {
        name = directive.group(1)!;
        // Strip the directive line: the compile input must stay byte-identical
        // to the equivalent seed-authored source.
        source = firstBreak == -1 ? '' : source.substring(firstBreak + 1);
      }
      if (slugFor(name) != slug) _diskHomeByName[name] = slug;
      entries.add(ChallengeEntry(name: name, source: source));
    }
    entries.sort((a, b) => slugFor(a.name).compareTo(slugFor(b.name)));
    if (entries.isNotEmpty) {
      stdout.writeln(
        'challenges: ${entries.length} entr'
        '${entries.length == 1 ? 'y' : 'ies'} loaded from disk '
        '(${entries.map((e) => e.name).join(', ')})',
      );
    }
    return entries;
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

  /// Every catalog entry (disk-loaded or seed-fallback), in catalog order.
  /// Used by the server's startup log and warm-all loop — the seed constant
  /// must never be consulted directly now that the catalog can come from disk.
  List<ChallengeEntry> get entries => List.unmodifiable(_entries);

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
