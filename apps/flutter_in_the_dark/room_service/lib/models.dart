/// Data model for the Flutter in the Dark room. Pure Dart, JSON-round-trippable.
///
/// The whole room lives in one [Room] object owned by [RoomState]; every
/// mutation bumps `revision` and broadcasts a full `state` event to SSE
/// subscribers (the room is small — full snapshots keep clients trivially
/// in sync and make Last-Event-ID catch-up a single refetch).
library;

import 'package:uuid/uuid.dart';

enum ChallengerStatus { active, blocked }

enum GenState { idle, queued, generating, compiling, ready, failed }

enum ViewMode {
  allWithChallenge,
  allPlayers,
  singlePlayer,
  singleWithChallenge,
  challengeOnly,
}

enum DisplayContent { prompt, code, widget }

class Challenger {
  Challenger({
    required this.id,
    required this.name,
    required this.joinedAt,
    this.status = ChallengerStatus.active,
    this.prompt = '',
    this.genState = GenState.idle,
    this.generatedCode,
    this.compiledUrl,
    this.error,
    this.fixAttempts = 0,
  });

  final String id;
  String name;
  final DateTime joinedAt;
  ChallengerStatus status;
  String prompt;
  GenState genState;
  String? generatedCode;
  String? compiledUrl;
  String? error;
  int fixAttempts;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'joinedAt': joinedAt.toIso8601String(),
        'status': status.name,
        'prompt': prompt,
        'genState': genState.name,
        if (generatedCode != null) 'generatedCode': generatedCode,
        if (compiledUrl != null) 'compiledUrl': compiledUrl,
        if (error != null) 'error': error,
        'fixAttempts': fixAttempts,
      };

  static Challenger fromJson(Map<String, dynamic> json) => Challenger(
        id: json['id'] as String,
        name: json['name'] as String,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        status: ChallengerStatus.values.byName(
          json['status'] as String? ?? 'active',
        ),
        prompt: json['prompt'] as String? ?? '',
        genState: GenState.values.byName(json['genState'] as String? ?? 'idle'),
        generatedCode: json['generatedCode'] as String?,
        compiledUrl: json['compiledUrl'] as String?,
        error: json['error'] as String?,
        fixAttempts: json['fixAttempts'] as int? ?? 0,
      );
}

class Challenge {
  Challenge({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.widgetUrl,
    this.assets = const {},
  });

  final String id;
  String name;
  DateTime startTime;
  DateTime endTime;

  /// URL of the pre-compiled challenge widget (same compileAndServe path as
  /// contestant output). Path-absolute (`/compiled/<id>`) against the
  /// generation backend.
  String widgetUrl;
  Map<String, String> assets;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        // Always UTC ISO-8601 with an explicit 'Z': a naive no-suffix string is
        // parsed as LOCAL time by clients, shifting the instant by their offset.
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        'widgetUrl': widgetUrl,
        'assets': assets,
      };

  static Challenge fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        name: json['name'] as String,
        startTime: DateTime.parse(json['startTime'] as String).toUtc(),
        endTime: DateTime.parse(json['endTime'] as String).toUtc(),
        widgetUrl: json['widgetUrl'] as String,
        assets:
            (json['assets'] as Map<String, dynamic>?)?.cast<String, String>() ??
                const {},
      );
}

class ShowState {
  ViewMode viewMode = ViewMode.allWithChallenge;
  String? focusedPlayerId;

  Map<String, dynamic> toJson() => {
        'viewMode': viewMode.name,
        'focusedPlayerId': focusedPlayerId,
      };

  static ShowState fromJson(Map<String, dynamic> json) {
    final s = ShowState();
    if (json['viewMode'] case final String v) {
      s.viewMode = ViewMode.values.byName(v);
    }
    s.focusedPlayerId = json['focusedPlayerId'] as String?;
    return s;
  }
}

/// One selectable generation model + the realistic-prompt reliability numbers
/// the admin picker shows next to it. [active] marks the model new work uses.
class ModelCandidate {
  ModelCandidate({
    required this.id,
    this.active = false,
    this.successPct,
    this.meanLatencyS,
    this.proseLeakPct,
    this.quality,
    this.runs = 0,
    this.isChat = true,
    this.concurrentSuccessPct,
    this.concurrentLatencyS,
    this.concurrentWallS,
    this.concurrentRuns = 0,
    this.effort,
  });

  /// Full Berget model id, e.g. `moonshotai/Kimi-K3`.
  final String id;
  bool active;

  /// % of realistic-prompt runs that produced clean, compilable code.
  final double? successPct;
  final double? meanLatencyS;

  /// % of runs that leaked prose / left a ``` fence remnant.
  final double? proseLeakPct;

  /// Mean rubric quality (0-10) across scored runs.
  final double? quality;
  final int runs;

  /// Measured under 4-way CONCURRENT load (the real event condition — 4
  /// contestants firing at the buzzer). These are the headline numbers in the
  /// picker; the serial [successPct]/[meanLatencyS] are the secondary baseline.
  final double? concurrentSuccessPct;
  final double? concurrentLatencyS;

  /// Worst-case first-fire -> last-complete span across the concurrent waves —
  /// the "room waits this long for all 4" number.
  final double? concurrentWallS;
  final int concurrentRuns;

  /// The `reasoning_effort` this model is served at when selected (e.g. Kimi
  /// runs at "low" to avoid its reasoning-collapse). Null = provider default.
  /// Populated server-side from the pipeline's preferred-effort map so the
  /// picker can show "the picker's Kimi is the fast low variant".
  final String? effort;

  /// False for non-chat (e.g. embedding/whisper) models that can never serve
  /// generateCode. Filtered from the picker; kept in state only so a stale
  /// persisted entry doesn't reappear as selectable.
  final bool isChat;

  Map<String, dynamic> toJson() => {
        'id': id,
        'active': active,
        if (successPct != null) 'successPct': successPct,
        if (meanLatencyS != null) 'meanLatencyS': meanLatencyS,
        if (proseLeakPct != null) 'proseLeakPct': proseLeakPct,
        if (quality != null) 'quality': quality,
        'runs': runs,
        if (!isChat) 'isChat': isChat,
        if (concurrentSuccessPct != null)
          'concurrentSuccessPct': concurrentSuccessPct,
        if (concurrentLatencyS != null)
          'concurrentLatencyS': concurrentLatencyS,
        if (concurrentWallS != null) 'concurrentWallS': concurrentWallS,
        'concurrentRuns': concurrentRuns,
        if (effort != null) 'effort': effort,
      };

  static ModelCandidate fromJson(Map<String, dynamic> json) => ModelCandidate(
        id: json['id'] as String,
        active: json['active'] as bool? ?? false,
        successPct: (json['successPct'] as num?)?.toDouble(),
        meanLatencyS: (json['meanLatencyS'] as num?)?.toDouble(),
        proseLeakPct: (json['proseLeakPct'] as num?)?.toDouble(),
        quality: (json['quality'] as num?)?.toDouble(),
        runs: json['runs'] as int? ?? 0,
        isChat: json['isChat'] as bool? ?? true,
        concurrentSuccessPct:
            (json['concurrentSuccessPct'] as num?)?.toDouble(),
        concurrentLatencyS: (json['concurrentLatencyS'] as num?)?.toDouble(),
        concurrentWallS: (json['concurrentWallS'] as num?)?.toDouble(),
        concurrentRuns: json['concurrentRuns'] as int? ?? 0,
        effort: json['effort'] as String?,
      );
}

/// The admin model-picker state: which model is live + the candidate list with
/// benchmark numbers. Broadcast over the room `state` event so /admin renders
/// it without a separate fetch.
class GenerationState {
  String activeModel = '';
  List<ModelCandidate> candidates = [];

  Map<String, dynamic> toJson() => {
        'activeModel': activeModel,
        'candidates': [for (final c in candidates) c.toJson()],
      };

  static GenerationState fromJson(Map<String, dynamic> json) {
    final g = GenerationState();
    g.activeModel = json['activeModel'] as String? ?? '';
    g.candidates = [
      for (final c in (json['candidates'] as List? ?? const []))
        ModelCandidate.fromJson((c as Map).cast<String, dynamic>()),
    ];
    return g;
  }
}

class Room {
  int revision = 0;

  /// Identifies the current PLAYER-SET generation. Bumped (new uuid) ONLY by
  /// the admin's removeAllChallengers — the one action that invalidates every
  /// player identity at once. Challenge lifecycle (setChallenge /
  /// clearChallenge) does NOT bump it: players persist across challenges
  /// (join-and-wait before the first challenge is a supported flow), and a
  /// single-player kick is observable by the player's disappearance from
  /// [challengers]. Token validation is not round-bound.
  String roundId = const Uuid().v4();

  Challenge? challenge;
  final Map<String, Challenger> challengers = {};
  ShowState show = ShowState();
  GenerationState generation = GenerationState();

  /// Admin's tri-state selection applied to every challenger at once
  /// (allWithChallenge / allPlayers scope).
  DisplayContent globalContent = DisplayContent.prompt;

  /// Per-challenger overrides used by the singlePlayer scope.
  final Map<String, DisplayContent> playerContent = {};

  /// What the given challenger should render right now.
  DisplayContent contentFor(String challengerId) =>
      playerContent[challengerId] ?? globalContent;

  Map<String, dynamic> toJson() => {
        'revision': revision,
        'roundId': roundId,
        'challenge': challenge?.toJson(),
        'challengers': [
          for (final c in challengers.values) c.toJson(),
        ],
        'show': show.toJson(),
        'generation': generation.toJson(),
        'globalContent': globalContent.name,
        'playerContent': {
          for (final e in playerContent.entries) e.key: e.value.name
        },
      };

  static Room fromJson(Map<String, dynamic> json) {
    final room = Room();
    room.revision = json['revision'] as int? ?? 0;
    // A persisted round from before roundId existed (or a hand-written file)
    // gets a fresh id on load — tokens never survive a restart anyway.
    if (json['roundId'] case final String r) {
      room.roundId = r;
    }
    if (json['challenge'] case final Map<String, dynamic> c) {
      room.challenge = Challenge.fromJson(c);
    }
    for (final c in (json['challengers'] as List? ?? const [])) {
      final challenger =
          Challenger.fromJson((c as Map).cast<String, dynamic>());
      room.challengers[challenger.id] = challenger;
    }
    if (json['show'] case final Map<String, dynamic> s) {
      room.show = ShowState.fromJson(s);
    }
    if (json['generation'] case final Map<String, dynamic> g) {
      room.generation = GenerationState.fromJson(g);
    }
    if (json['globalContent'] case final String g) {
      room.globalContent = DisplayContent.values.byName(g);
    }
    if (json['playerContent'] case final Map<String, dynamic> pc) {
      for (final e in pc.entries) {
        room.playerContent[e.key] = DisplayContent.values.byName(
          e.value as String,
        );
      }
    }
    return room;
  }
}
