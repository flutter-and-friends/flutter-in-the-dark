/// The room: in-memory authoritative state, SSE broadcast, and all the
/// actions the HTTP layer exposes. Single-isolate, no locking needed.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'models.dart';
import 'pipeline.dart';

class RoomState {
  RoomState({required this.pipeline, this.stateFile});

  final Pipeline pipeline;

  /// Optional JSON persistence so an svcwatch restart doesn't wipe the room.
  final File? stateFile;

  final _uuid = const Uuid();
  Room _room = Room();

  /// SSE subscribers. Each is a StreamSink we write `data:` frames to.
  final Set<_SseSubscriber> _subscribers = {};

  /// In-flight generation pipelines, keyed by challenger id.
  final Map<String, Future<void>> _pipelines = {};

  Timer? _buzzerTimer;
  Timer? _persistDebouncer;

  Room get room => _room;

  // ---------------------------------------------------------------- state IO

  void load() {
    final file = stateFile;
    if (file == null || !file.existsSync()) {
      _initGeneration();
      return;
    }
    try {
      _room = Room.fromJson(
        (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>(),
      );
      // Nothing was running while we were down: re-queue unfinished work.
      for (final c in _room.challengers.values) {
        if (c.genState == GenState.generating ||
            c.genState == GenState.compiling ||
            c.genState == GenState.queued) {
          c.genState = GenState.queued;
        }
      }
    } catch (e) {
      stderr.writeln('room: failed to load ${file.path}: $e — starting fresh');
      _room = Room();
    }
    _initGeneration();
  }

  /// Seeds the generation block on boot and reconciles it with whatever was
  /// persisted: guarantees every known model appears as a candidate, the
  /// active flag matches the pipeline's model, and the pipeline reflects the
  /// persisted/active selection. Benchmark numbers survive restarts.
  void _initGeneration() {
    final gen = _room.generation;
    // One-time scrub: drop any persisted candidate that isn't a known chat
    // model (a bogus embedding model was persisted during WI-098 development).
    gen.candidates.removeWhere((c) => !isChatModel(c.id));
    if (gen.candidates.isEmpty) {
      gen.candidates = [for (final id in knownModels) ModelCandidate(id: id)];
    } else {
      final have = gen.candidates.map((c) => c.id).toSet();
      for (final id in knownModels) {
        if (!have.contains(id)) gen.candidates.add(ModelCandidate(id: id));
      }
    }
    // Resolve the effective model: a persisted active selection wins; else a
    // persisted activeModel string; else the pipeline's boot default. If the
    // persisted selection is somehow a non-chat model, fall back to default.
    var effective = gen.candidates
        .where((c) => c.active)
        .map((c) => c.id)
        .firstOrNull ??
        (gen.activeModel.isNotEmpty ? gen.activeModel : pipeline.model);
    if (!isChatModel(effective)) effective = pipeline.model;
    if (!isChatModel(effective)) effective = Pipeline.defaultModel;
    pipeline.model = effective;
    gen.activeModel = effective;
    for (final c in gen.candidates) {
      c.active = c.id == effective;
    }
  }

  /// Every Berget CHAT model the operator may pick, in the order shown.
  /// Benchmark numbers are attached as runs complete; unknown models still
  /// appear so the picker always offers the full failover set. Non-chat models
  /// (embeddings, whisper) are deliberately excluded — they can never serve
  /// generateCode.
  static const knownModels = [
    'google/gemma-4-31B-it',
    'moonshotai/Kimi-K2.6',
    'moonshotai/Kimi-K3',
    'zai-org/GLM-4.7-FP8',
    'openai/gpt-oss-120b',
    'meta-llama/Llama-3.3-70B-Instruct',
    'Qwen/Qwen3.8-27B-FP8',
    'mistralai/Mistral-Small-3.2-24B-Instruct-2506',
  ];

  /// Models that must never appear in the picker (embedding / transcription —
  /// they reject chat completions). Used to scrub stale persisted entries.
  static bool isChatModel(String id) => knownModels.contains(id);

  /// Live model failover (admin). Re-points the pipeline at [model] for all
  /// new generation and broadcasts the change. In-flight work keeps the model
  /// it started with; the next pipeline run uses the new one. No restart.
  void setModel(String model) {
    pipeline.model = model;
    final gen = _room.generation;
    gen.activeModel = model;
    var found = false;
    for (final c in gen.candidates) {
      c.active = c.id == model;
      if (c.active) found = true;
    }
    if (!found) {
      gen.candidates.add(
        ModelCandidate(id: model, active: true, isChat: isChatModel(model)),
      );
    }
    _changed();
  }

  /// Replaces the benchmark numbers shown for [model] in the picker (called by
  /// POST /api/admin/modelStats after a benchmark run). Creates the candidate
  /// if it isn't known yet. Nulls leave the corresponding number unset.
  void updateModelStats(
    String model, {
    double? successPct,
    double? meanLatencyS,
    double? proseLeakPct,
    double? quality,
    int? runs,
    double? concurrentSuccessPct,
    double? concurrentLatencyS,
    double? concurrentWallS,
    int? concurrentRuns,
  }) {
    final gen = _room.generation;
    var cand = gen.candidates.where((c) => c.id == model).firstOrNull;
    if (cand == null) {
      cand = ModelCandidate(
        id: model,
        active: gen.activeModel == model,
        isChat: isChatModel(model),
      );
      gen.candidates.add(cand);
      print('[room] modelStats: new candidate $model (chat=${cand.isChat})');
    }
    gen.candidates[gen.candidates.indexWhere((c) => c.id == model)] =
        ModelCandidate(
          id: model,
          active: cand.active,
          successPct: successPct ?? cand.successPct,
          meanLatencyS: meanLatencyS ?? cand.meanLatencyS,
          proseLeakPct: proseLeakPct ?? cand.proseLeakPct,
          quality: quality ?? cand.quality,
          runs: runs ?? cand.runs,
          concurrentSuccessPct:
              concurrentSuccessPct ?? cand.concurrentSuccessPct,
          concurrentLatencyS: concurrentLatencyS ?? cand.concurrentLatencyS,
          concurrentWallS: concurrentWallS ?? cand.concurrentWallS,
          concurrentRuns: concurrentRuns ?? cand.concurrentRuns,
        );
    print('[room] modelStats: $model -> ok=${successPct ?? cand.successPct} '
        'lat=${meanLatencyS ?? cand.meanLatencyS} runs=${runs ?? cand.runs} '
        'conc=${concurrentSuccessPct ?? cand.concurrentSuccessPct}@'
        '${concurrentLatencyS ?? cand.concurrentLatencyS}');
    _changed();
  }

  void _persist() {
    final file = stateFile;
    if (file == null) return;
    _persistDebouncer?.cancel();
    _persistDebouncer = Timer(const Duration(milliseconds: 500), () {
      file.writeAsStringSync(jsonEncode(_room.toJson()));
    });
  }

  // -------------------------------------------------------------- broadcast

  void _changed() {
    _room.revision++;
    _persist();
    final frame =
        'id: ${_room.revision}\nevent: state\n'
        'data: ${jsonEncode(_room.toJson())}\n\n';
    for (final sub in _subscribers.toList()) {
      sub.add(frame);
    }
  }

  // ------------------------------------------------------------------- SSE

  /// Attaches [sink] as an SSE subscriber. Sends a `hello` (room revision)
  /// immediately, then a full `state` snapshot if [lastEventId] is stale.
  ///
  /// Returns a future that completes when the connection closes.
  Future<void> subscribe(
    StreamSink<List<int>> sink, {
    int? lastEventId,
  }) async {
    final sub = _SseSubscriber(sink);
    _subscribers.add(sub);
    sub.add('retry: 3000\n\n');
    sub.add('id: ${_room.revision}\nevent: hello\ndata: {}\n\n');
    final current = _room.revision;
    if (lastEventId == null || lastEventId < current) {
      sub.add(
        'id: $current\nevent: state\n'
        'data: ${jsonEncode(_room.toJson())}\n\n',
      );
    }
    try {
      await sub.done;
    } finally {
      _subscribers.remove(sub);
    }
  }

  // ------------------------------------------------------------- actions

  /// POST /api/join → {playerId, token}
  ({String playerId, String token}) join(String name) {
    final id = _uuid.v4();
    final token = _uuid.v4();
    _tokens[id] = token;
    _room.challengers[id] = Challenger(
      id: id,
      name: name,
      joinedAt: DateTime.now(),
    );
    _changed();
    return (playerId: id, token: token);
  }

  final Map<String, String> _tokens = {};

  bool checkToken(String playerId, String? token) =>
      token != null && _tokens[playerId] == token;

  String? updatePrompt(String playerId, String prompt) {
    final c = _room.challengers[playerId];
    if (c == null) return 'no such challenger';
    if (c.status == ChallengerStatus.blocked) return 'challenge is over';
    c.prompt = prompt;
    _changed();
    return null;
  }

  // ------------------------------------------------------------- admin ops

  void setChallenge({
    required String name,
    required String widgetUrl,
    required DateTime startTime,
    required DateTime endTime,
    Map<String, String> assets = const {},
  }) {
    _buzzerTimer?.cancel();
    final id = _uuid.v4();
    _room.challenge = Challenge(
      id: id,
      name: name,
      startTime: startTime,
      endTime: endTime,
      widgetUrl: widgetUrl,
      assets: assets,
    );
    // Fresh challenge: reset every challenger's pipeline.
    for (final c in _room.challengers.values) {
      c
        ..status = ChallengerStatus.active
        ..genState = GenState.idle
        ..generatedCode = null
        ..compiledUrl = null
        ..error = null
        ..fixAttempts = 0;
    }
    _room.globalContent = DisplayContent.prompt;
    _room.playerContent.clear();
    _scheduleBuzzer();
    _changed();
  }

  void clearChallenge() {
    _buzzerTimer?.cancel();
    _room.challenge = null;
    for (final c in _room.challengers.values) {
      c
        ..status = ChallengerStatus.active
        ..genState = GenState.idle
        ..generatedCode = null
        ..compiledUrl = null
        ..error = null
        ..fixAttempts = 0;
    }
    _room.globalContent = DisplayContent.prompt;
    _room.playerContent.clear();
    _changed();
  }

  void adjustTime(Duration delta) {
    final challenge = _room.challenge;
    if (challenge == null) return;
    challenge.endTime = challenge.endTime.add(delta);
    _scheduleBuzzer();
    _changed();
  }

  void setShowView({ViewMode? viewMode, String? focusedPlayerId}) {
    if (viewMode != null) _room.show.viewMode = viewMode;
    _room.show.focusedPlayerId = focusedPlayerId;
    if (focusedPlayerId != null &&
        !_room.playerContent.containsKey(focusedPlayerId)) {
      _room.playerContent[focusedPlayerId] = _room.globalContent;
    }
    _changed();
  }

  void setContentAll(DisplayContent content) {
    _room.globalContent = content;
    _room.playerContent.clear();
    _changed();
  }

  void setContentFor(String playerId, DisplayContent content) {
    if (!_room.challengers.containsKey(playerId)) return;
    _room.playerContent[playerId] = content;
    _changed();
  }

  void removeChallenger(String playerId) {
    _room.challengers.remove(playerId);
    _room.playerContent.remove(playerId);
    _tokens.remove(playerId);
    _changed();
  }

  void removeAllChallengers() {
    _room.challengers.clear();
    _room.playerContent.clear();
    _tokens.clear();
    _changed();
  }

  // ------------------------------------------------------------- the buzzer

  void _scheduleBuzzer() {
    _buzzerTimer?.cancel();
    final challenge = _room.challenge;
    if (challenge == null) return;
    final remaining = challenge.endTime.difference(DateTime.now());
    if (remaining.isNegative) {
      buzzer();
      return;
    }
    _buzzerTimer = Timer(remaining, buzzer);
  }

  /// Challenge window end: block editing, push every prompt into the
  /// generate/compile pipeline immediately (§6.C step 4).
  void buzzer() {
    for (final c in _room.challengers.values) {
      c.status = ChallengerStatus.blocked;
      if (c.genState == GenState.idle || c.genState == GenState.failed) {
        c.genState = GenState.queued;
        _startPipeline(c);
      }
    }
    _changed();
  }

  /// Manual per-challenger regenerate (admin backstop).
  void regenerate(String playerId) {
    final c = _room.challengers[playerId];
    if (c == null) return;
    c
      ..genState = GenState.queued
      ..generatedCode = null
      ..compiledUrl = null
      ..error = null
      ..fixAttempts = 0;
    _startPipeline(c);
    _changed();
  }

  void _startPipeline(Challenger c) {
    if (_pipelines.containsKey(c.id)) return;
    // Overall watchdog: a pipeline that runs past this is force-settled so a
    // single hung generation can never wedge a challenger on `queued`
    // indefinitely. The state machine surfaces it as `failed` and the admin
    // can regenerate.
    final future = pipeline
        .run(c, _changed)
        .timeout(
          const Duration(minutes: 4),
          onTimeout: () {
            c
              ..generatedCode = null
              ..genState = GenState.failed
              ..error = 'generation timed out';
            _changed();
          },
        );
    _pipelines[c.id] = future;
    future
        .then((_) {
          _pipelines.remove(c.id);
          print('[room] pipeline settled for ${c.name} -> ${c.genState.name}');
        })
        .catchError((Object e) {
          _pipelines.remove(c.id);
          print('[room] pipeline error for ${c.name}: $e');
        });
  }

  /// Re-run every challenger whose pipeline is not already in flight and
  /// whose state implies unfinished work. Used on service restart and by the
  /// tests that reset the room mid-flight.
  void _startIdlePipelines() {
    for (final c in _room.challengers.values) {
      if (_pipelines.containsKey(c.id)) continue;
      if (c.genState == GenState.queued ||
          (c.genState == GenState.failed && c.status == ChallengerStatus.blocked)) {
        c.genState = GenState.queued;
        _startPipeline(c);
      }
    }
  }

  /// Restart queued pipelines after a service restart (state file reload).
  void resumePipelines() => _startIdlePipelines();

  Future<void> dispose() async {
    _buzzerTimer?.cancel();
    _persistDebouncer?.cancel();
    await Future.wait(_pipelines.values);
  }
}

class _SseSubscriber {
  _SseSubscriber(this.sink);

  final StreamSink<List<int>> sink;
  final Completer<void> _done = Completer<void>();
  Future<void> get done => _done.future;

  void add(String frame) {
    if (_done.isCompleted) return;
    try {
      sink.add(utf8.encode(frame));
    } catch (_) {
      _finish();
    }
  }

  void _finish() {
    if (!_done.isCompleted) _done.complete();
  }
}
