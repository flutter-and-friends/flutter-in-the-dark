/// fitd26 room-state service entry point.
///
///   dart bin/server.dart --port 8302 --backend http://127.0.0.1:8300
///     [--admin-token <token>] [--state-file <path>]
///
/// Contract (full doc in ../../BACKEND.md):
///   GET  /api/state            → full room snapshot (catch-up refetch)
///   GET  /api/events           → SSE stream (event `state`, id = revision)
///   POST /api/join             {name} → {playerId, token}
///   POST /api/prompt           {playerId, token, prompt}
///   POST /api/admin/*          (no app-level auth — the network gate decides:
///                             admin routes are only exposed on the
///                             Tailscale-facing listener, never the public one)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:fitd26_room/models.dart';
import 'package:fitd26_room/pipeline.dart' as gen;
import 'package:fitd26_room/room.dart';

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
  final pipeline = gen.Pipeline(
    backendBase: results['backend'] as String,
    initialModel: (initialModel != null && initialModel.isNotEmpty)
        ? initialModel
        : null,
  );
  final room = RoomState(
    pipeline: pipeline,
    stateFile: stateFilePath.isEmpty ? null : File(stateFilePath),
  );
  room.load();
  room.resumePipelines();

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
    return _json({'playerId': result.playerId, 'token': result.token});
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

  router.post('/api/admin/challenge', (Request request) async {
    final body = await _readJson(request);
    try {
      final startMs = body['startTime'] as int;
      final endMs = body['endTime'] as int;
      room.setChallenge(
        name: body['name'] as String,
        widgetUrl: body['widgetUrl'] as String,
        startTime: DateTime.fromMillisecondsSinceEpoch(startMs),
        endTime: DateTime.fromMillisecondsSinceEpoch(endMs),
        assets:
            (body['assets'] as Map<String, dynamic>?)?.cast<String, String>() ??
            const {},
      );
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
    'fitd26-room listening on 0.0.0.0:$port '
    '(backend: ${results['backend']}, admin auth: none (Tailscale gate), '
    'state file: ${stateFilePath.isEmpty ? 'none' : stateFilePath})',
  );
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
