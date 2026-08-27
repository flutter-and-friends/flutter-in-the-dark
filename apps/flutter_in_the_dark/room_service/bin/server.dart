/// Flutter in the Dark room-state service entry point.
///
///   dart bin/server.dart --port 8302 --backend http://127.0.0.1:8300
///     [--admin-token <token>] [--state-file <path>]
///
/// Contract (full doc in ../../BACKEND.md):
///   GET  /api/state            → full room snapshot (catch-up refetch)
///   GET  /api/events           → SSE stream (event `state`, id = revision)
///   POST /api/join             {name} → {playerId, token, roundId}
///   POST /api/prompt           {playerId, token, prompt}
///   POST /api/admin/*          (no app-level auth — the network gate decides:
///                             admin routes are only exposed on the
///                             Tailscale-facing listener, never the public one)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:flutter_in_the_dark_room_service/challenges.dart';
import 'package:flutter_in_the_dark_room_service/llm_providers.dart';
import 'package:flutter_in_the_dark_room_service/models.dart';
import 'package:flutter_in_the_dark_room_service/pipeline.dart' as gen;
import 'package:flutter_in_the_dark_room_service/room.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8302')
    ..addOption('backend', defaultsTo: 'http://127.0.0.1:8300')
    ..addOption(
      'state-file',
      defaultsTo: '',
      help: 'Optional JSON file to persist room state across restarts.',
    );
  final results = parser.parse(args);

  final port = int.parse(results['port'] as String);
  final stateFilePath = results['state-file'] as String;

  // Seed the pipeline's model from the env (so the boot default matches
  // dart_services' BERGET_MODEL); the admin picker overrides it live after.
  final initialModel = Platform.environment['BERGET_MODEL'];
  // Build the provider chain here (rather than inside Pipeline's default) so
  // the boot log can name the active providers — a stale GEMINI_API_KEY must
  // be visible at startup, not hide behind a silent fallback (W-022).
  final providers = buildGeneratorFromEnv(
    backendBase: results['backend'] as String,
  );
  final pipeline = gen.Pipeline(
    backendBase: results['backend'] as String,
    initialModel: (initialModel != null && initialModel.isNotEmpty)
        ? initialModel
        : null,
    generator: providers.generator,
  );
  stdout.writeln('LLM providers: ${providers.providersDescription}');
  final room = RoomState(
    pipeline: pipeline,
    stateFile: stateFilePath.isEmpty ? null : File(stateFilePath),
  );
  room.load();
  room.resumePipelines();

  // Catalog feeding the admin's challenge picker; compiled widget URLs are
  // cached in memory (a restart just means one recompile on next pick).
  final challenges = ChallengeRegistry();

  final router = Router();

  // ------------------------------------------------------------- realtime

  router.get('/api/state', (Request request) {
    return Response.ok(
      jsonEncode(room.room.toJson()),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  });

  router.get('/api/events', (Request request) async {
    final lastEventId = int.tryParse(
      request.headers['last-event-id'] ?? '',
    );
    final controller = StreamController<List<int>>();
    unawaited(
      room
          .subscribe(controller.sink, lastEventId: lastEventId)
          .whenComplete(() => controller.close()),
    );
    return Response.ok(
      controller.stream,
      headers: {
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'X-Accel-Buffering': 'no',
      },
      context: {'shelf.io.buffer_output': false},
    );
  });

  // ------------------------------------------------------------ contestant

  // Debug probe: does an outbound HTTP call from inside the service work?
  // Uses the room's OWN pipeline so it exercises the currently-selected model
  // (a fresh Pipeline would silently drop the admin's live model override).
  router.get('/api/probe-generate', (Request request) async {
    final sw = Stopwatch()..start();
    try {
      final prompt = request.url.queryParameters['prompt'] ?? 'a red button';
      final text = await pipeline.probeGenerate(prompt);
      return _json({'ok': true, 'ms': sw.elapsedMilliseconds, 'len': text});
    } catch (e) {
      return _json({'ok': false, 'ms': sw.elapsedMilliseconds, 'error': '$e'});
    }
  });

  router.post('/api/join', (Request request) async {
    final body = await _readJson(request);
    final name = (body['name'] as String? ?? '').trim();
    if (name.isEmpty) {
      return _badRequest('name is required');
    }
    final result = room.join(name);
    return _json({
      'playerId': result.playerId,
      'token': result.token,
      'roundId': result.roundId,
    });
  });

  router.post('/api/prompt', (Request request) async {
    final body = await _readJson(request);
    final playerId = body['playerId'] as String? ?? '';
    if (!room.checkToken(playerId, body['token'] as String?)) {
      return Response.forbidden(
        jsonEncode({'error': 'invalid player token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    final error = room.updatePrompt(
      playerId,
      body['prompt'] as String? ?? '',
    );
    if (error != null) return _badRequest(error);
    return _json({'ok': true});
  });

  // ----------------------------------------------------------------- admin

  // Challenge picker catalog: every seeded entry, with `widgetUrl` filled in
  // for the ones already compiled (and cached) this process lifetime.
  //
  // Freshness: dart_services serves /compiled/<id> from an in-memory store
  // with a 2 h no-read TTL, and a backend restart wipes it. A cached URL can
  // therefore be dead. The picker trusts a non-null widgetUrl from THIS list
  // without calling compile, so cached URLs are probed here and re-compiled
  // on demand (registry source is the truth; the cache is disposable). On
  // recompile failure the entry is served with widgetUrl null — never a
  // known-dead URL.
  router.get('/api/admin/challenges', (Request request) async {
    // Only entries with a CACHED url need a liveness probe; uncached entries
    // stay null and compile on tap via the compile route, as before.
    for (final name in challenges.cachedNames) {
      await _ensureFresh(challenges, pipeline, name);
    }
    return _json({'challenges': challenges.list()});
  });

  // Compiles a catalog entry against the backend and caches the resulting
  // widgetUrl. The picker calls this when the admin picks a challenge whose
  // widgetUrl is still null; a LIVE cached one returns immediately (a dead
  // one is transparently recompiled — see the freshness note on the list
  // route).
  router.post('/api/admin/challenges/compile', (Request request) async {
    final body = await _readJson(request);
    final name = body['name'] as String? ?? '';
    final entry = challenges.byName(name);
    if (entry == null) {
      return Response.notFound(
        jsonEncode({'error': 'unknown challenge'}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
    if (await _ensureFresh(challenges, pipeline, name)) {
      return _json({'ok': true, 'url': challenges.compiledUrlFor(name)});
    }
    return Response.badRequest(
      body: jsonEncode({
        'error': 'compile_failed',
        'problems': ['recompile of cached-but-dead URL failed; see service log'],
      }),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  });

  router.post('/api/admin/challenge', (Request request) async {
    final body = await _readJson(request);
    try {
      final startMs = body['startTime'] as int;
      final endMs = body['endTime'] as int;
      final name = body['name'] as String;
      room.setChallenge(
        name: name,
        widgetUrl: body['widgetUrl'] as String,
        // Normalize to UTC at ingest: ms-since-epoch is instant-exact, and
        // keeping the DateTime UTC means toIso8601String() emits a 'Z' on
        // the wire (a local-zone DateTime would serialize naive).
        startTime: DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
        endTime: DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true),
        assets:
            (body['assets'] as Map<String, dynamic>?)?.cast<String, String>() ??
            const {},
      );
      // Fire-and-forget re-warm of the picked challenge's compiled URL — a
      // long countdown can outlive the backend's 2 h TTL, and a cache hit
      // makes this near-free. Never blocks the admin's response.
      unawaited(_warm(challenges, pipeline, name));
      return _json({'ok': true});
    } on TypeError {
      return _badRequest('required: name, widgetUrl, startTime, endTime (ms)');
    }
  });

  router.post('/api/admin/clear', (Request request) {
    room.clearChallenge();
    return _json({'ok': true});
  });

  router.post('/api/admin/adjustTime', (Request request) async {
    final body = await _readJson(request);
    room.adjustTime(Duration(seconds: body['seconds'] as int? ?? 0));
    return _json({'ok': true});
  });

  router.post('/api/admin/showView', (Request request) async {
    final body = await _readJson(request);
    room.setShowView(
      viewMode: switch (body['viewMode']) {
        final String v => ViewMode.values.byName(v),
        _ => null,
      },
      focusedPlayerId: body['focusedPlayerId'] as String?,
    );
    return _json({'ok': true});
  });

  router.post('/api/admin/contentAll', (Request request) async {
    final body = await _readJson(request);
    room.setContentAll(
      DisplayContent.values.byName(body['content'] as String),
    );
    return _json({'ok': true});
  });

  router.post('/api/admin/contentFor', (Request request) async {
    final body = await _readJson(request);
    room.setContentFor(
      body['playerId'] as String,
      DisplayContent.values.byName(body['content'] as String),
    );
    return _json({'ok': true});
  });

  router.post('/api/admin/regenerate', (Request request) async {
    final body = await _readJson(request);
    room.regenerate(body['playerId'] as String);
    return _json({'ok': true});
  });

  router.post('/api/admin/removeChallenger', (Request request) async {
    final body = await _readJson(request);
    room.removeChallenger(body['playerId'] as String);
    return _json({'ok': true});
  });

  router.post('/api/admin/removeAll', (Request request) {
    room.removeAllChallengers();
    return _json({'ok': true});
  });

  // Live generation-model failover. The picker is operator-only by the same
  // Tailscale gate as every other /api/admin/* route. Takes effect for new
  // generation immediately; no restart.
  router.post('/api/admin/model', (Request request) async {
    final body = await _readJson(request);
    final model = body['model'] as String? ?? '';
    if (model.isEmpty) return _badRequest('model is required');
    room.setModel(model);
    return _json({'ok': true, 'activeModel': model});
  });

  // Benchmark backfill: pushes realistic-prompt reliability numbers for a model
  // into the picker. Called by the bake-off harness after a run; also usable
  // ad hoc. All numeric fields optional — only provided ones update.
  router.post('/api/admin/modelStats', (Request request) async {
    final body = await _readJson(request);
    final model = body['model'] as String? ?? '';
    if (model.isEmpty) return _badRequest('model is required');
    double? dbl(String k) => (body[k] as num?)?.toDouble();
    room.updateModelStats(
      model,
      successPct: dbl('successPct'),
      meanLatencyS: dbl('meanLatencyS'),
      proseLeakPct: dbl('proseLeakPct'),
      quality: dbl('quality'),
      runs: (body['runs'] as num?)?.toInt(),
      concurrentSuccessPct: dbl('concurrentSuccessPct'),
      concurrentLatencyS: dbl('concurrentLatencyS'),
      concurrentWallS: dbl('concurrentWallS'),
      concurrentRuns: (body['concurrentRuns'] as num?)?.toInt(),
    );
    return _json({'ok': true});
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, '0.0.0.0', port);
  server.autoCompress = true;
  stdout.writeln(
    'flutter-in-the-dark-room listening on 0.0.0.0:$port '
    '(backend: ${results['backend']}, admin auth: none (Tailscale gate), '
    'state file: ${stateFilePath.isEmpty ? 'none' : stateFilePath}, '
    'challenges loaded: ${challenges.entries.length})',
  );

  // Startup warm-all: pre-compile every catalog challenge so first serve in
  // a live event never waits on a cold compile. Best-effort background pass —
  // a warm failure is logged, never thrown (probe-and-recompile on the list /
  // compile routes is the correctness floor; this is pure optimization).
  unawaited(_warmAll(challenges, pipeline));
}

/// Returns true when the backend still serves [url] (path-absolute
/// `/compiled/<id>` against the generation backend). Any error or non-200
/// counts as dead — a wrong "alive" verdict 404s every client iframe.
Future<bool> _compiledUrlAlive(String backendBase, String url) async {
  final client = http.Client();
  try {
    final response = await client
        .get(Uri.parse('$backendBase$url'))
        .timeout(const Duration(seconds: 10));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}

/// Ensures the registry's cached widgetUrl for [name] is live: a missing or
/// dead cache entry is (re)compiled from the registry source and re-cached.
/// Returns true when a live URL is cached on return. dart_services keeps
/// compiled artifacts in memory with a 2 h no-read TTL (and loses them on
/// restart), so the cache can never be trusted without a probe.
Future<bool> _ensureFresh(
  ChallengeRegistry challenges,
  gen.Pipeline pipeline,
  String name,
) async {
  final cached = challenges.compiledUrlFor(name);
  if (cached != null && await _compiledUrlAlive(pipeline.backendBase, cached)) {
    return true;
  }
  challenges.evictCompiled(name);
  final url = await _compile(pipeline, challenges.byName(name)!.source);
  if (url == null) return false;
  challenges.cacheCompiled(name, url);
  return true;
}

/// Best-effort warm of one challenge's compiled-URL cache: compiles [name]
/// from registry source via [_compile] and caches the result, so a later
/// pick/serve hits a warm cache. NEVER throws — any failure (unknown name,
/// backend down, compile error) is logged loudly and skipped; the liveness
/// probe + recompile in [_ensureFresh] remains the correctness floor.
///
/// Skips the compile entirely when a cached URL still probes alive — a warm
/// of an already-warm entry is near-free (one GET).
Future<void> _warm(
  ChallengeRegistry challenges,
  gen.Pipeline pipeline,
  String name,
) async {
  try {
    final entry = challenges.byName(name);
    if (entry == null) {
      stdout.writeln('warm "$name": not in registry — skipped');
      return;
    }
    final cached = challenges.compiledUrlFor(name);
    if (cached != null &&
        await _compiledUrlAlive(pipeline.backendBase, cached)) {
      stdout.writeln('warm "$name": cache already live ($cached)');
      return;
    }
    final sw = Stopwatch()..start();
    final url = await _compile(pipeline, entry.source);
    if (url == null) {
      stdout.writeln(
        'warm "$name": compile FAILED (${sw.elapsedMilliseconds} ms) — skipped',
      );
      return;
    }
    challenges.cacheCompiled(name, url);
    stdout.writeln('warm "$name": compiled → $url (${sw.elapsedMilliseconds} ms)');
  } catch (e) {
    // Paranoia: _compile already swallows, but a warm must NEVER propagate.
    stdout.writeln('warm "$name": unexpected error: $e — skipped');
  }
}

/// Startup warm-all: sequentially warms every catalog entry. Sequential on
/// purpose — dart_services has a single DDC worker pool, parallel compiles
/// would just queue behind it while hammering the backend. Best-effort: any
/// single failure is logged inside [_warm] and the loop continues.
Future<void> _warmAll(
  ChallengeRegistry challenges,
  gen.Pipeline pipeline,
) async {
  stdout.writeln(
    'warm-all: compiling ${challenges.entries.length} challenge(s)…',
  );
  for (final entry in challenges.entries) {
    await _warm(challenges, pipeline, entry.name);
  }
  stdout.writeln('warm-all: done');
}

/// POSTs [source] to the backend's compileAndServe and returns the served
/// `/compiled/<id>` path, or null on any failure (logged to stdout; the
/// caller decides the HTTP response). Fresh client per call (same reason as
/// Pipeline._client: a shared client wedges on an abandoned stream); 120 s
/// timeout mirrors Pipeline._compile.
Future<String?> _compile(gen.Pipeline pipeline, String source) async {
  final client = http.Client();
  try {
    final response = await client
        .post(
          Uri.parse('${pipeline.backendBase}/api/v3/compileAndServe'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'source': source}),
        )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode != 200) {
      stdout.writeln('challenge compile failed (${response.statusCode}): '
          '${response.body}');
      return null;
    }
    final url = (jsonDecode(response.body) as Map<String, dynamic>)['url'];
    if (url is String) return url;
    stdout.writeln('challenge compile: 200 body missing "url"');
    return null;
  } catch (e) {
    stdout.writeln('challenge compile error: $e');
    return null;
  } finally {
    client.close();
  }
}

Future<Map<String, dynamic>> _readJson(Request request) async {
  try {
    final body = await request.readAsString();
    if (body.isEmpty) return {};
    return (jsonDecode(body) as Map).cast<String, dynamic>();
  } on FormatException {
    return {};
  }
}

Response _json(Map<String, dynamic> body) => Response.ok(
  jsonEncode(body),
  headers: {'Content-Type': 'application/json; charset=utf-8'},
);

Response _badRequest(String message) => Response.badRequest(
  body: jsonEncode({'error': message}),
  headers: {'Content-Type': 'application/json; charset=utf-8'},
);

/// Permissive CORS (the app is served from a different origin). Also answers
/// preflights; admin bearer is the only protection.
Middleware _cors() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization, Last-Event-ID',
    'Access-Control-Max-Age': '86400',
  };
  return (innerHandler) {
    return (request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final response = await innerHandler(request);
      return response.change(headers: headers);
    };
  };
}
