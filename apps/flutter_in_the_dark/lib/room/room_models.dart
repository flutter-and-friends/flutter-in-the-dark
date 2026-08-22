/// Client-side mirror of the room-service JSON model
/// (`apps/flutter_in_the_dark/room_service/lib/models.dart`). Field names must stay in
/// sync with the server; the SSE `state` event carries this whole shape.
library;

import 'package:flutter_in_the_dark/helpers/wire_time.dart';

enum ChallengerStatus { active, blocked }

enum GenState { idle, queued, generating, compiling, ready, failed }

enum ViewMode {
  allWithChallenge,
  allPlayers,
  singlePlayer,
  singleWithChallenge,
  challengeOnly;

  /// Whether this mode shows one focused player (drives the admin focus
  /// picker and per-player tri-state scoping).
  bool get isSinglePlayerScoped =>
      this == singlePlayer || this == singleWithChallenge;

  /// Short labels — the admin audience-view selector packs all five into one
  /// row, including on narrow (mobile) widths.
  String get label => switch (this) {
    allWithChallenge => 'Ch. + all',
    allPlayers => 'All players',
    singlePlayer => 'Single',
    singleWithChallenge => 'Ch. + single',
    challengeOnly => 'Ch. only',
  };
}

enum DisplayContent {
  prompt,
  code,
  widget;

  String get label => switch (this) {
    prompt => 'Prompt',
    code => 'Code',
    widget => 'Widget',
  };
}

/// Splits [ViewMode.values] into rows for the admin audience-view selector:
/// one row when [width] fits all segments comfortably, two roughly-even rows
/// (chunked, preserving enum order) on narrow (mobile) widths. Pure layout
/// logic — unit-tested without Flutter bindings.
List<List<ViewMode>> viewModeRows(double width) {
  const values = ViewMode.values;
  // Below this the five short labels no longer fit on one row.
  if (width >= 560) return [values];
  final firstRowLen = (values.length + 1) ~/ 2;
  return [values.sublist(0, firstRowLen), values.sublist(firstRowLen)];
}

class Challenger {
  Challenger({
    required this.id,
    required this.name,
    required this.status,
    required this.prompt,
    required this.genState,
    this.generatedCode,
    this.compiledUrl,
    this.error,
    this.fixAttempts = 0,
  });

  final String id;
  final String name;
  final ChallengerStatus status;
  final String prompt;
  final GenState genState;
  final String? generatedCode;
  final String? compiledUrl;
  final String? error;
  final int fixAttempts;

  static Challenger fromJson(Map<String, dynamic> json) => Challenger(
    id: json['id'] as String,
    name: json['name'] as String,
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
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final String widgetUrl;
  final Map<String, String> assets;

  bool get isInTheFuture => startTime.isAfter(DateTime.now());
  bool get isFinished => DateTime.now().isAfter(endTime);

  static Challenge fromJson(Map<String, dynamic> json) => Challenge(
    id: json['id'] as String,
    name: json['name'] as String,
    startTime: parseWireTime(json['startTime'] as String),
    endTime: parseWireTime(json['endTime'] as String),
    widgetUrl: json['widgetUrl'] as String,
    assets:
        (json['assets'] as Map<String, dynamic>?)?.cast<String, String>() ??
        const {},
  );
}

/// One entry in the server-side challenge catalog
/// (`GET /api/admin/challenges`). [widgetUrl] is `null` when the challenge
/// has not been compiled yet — `RoomClient.compileChallenge` builds it on
/// demand (slow on first call) and returns the URL.
class ChallengeInfo {
  const ChallengeInfo({
    required this.name,
    this.assets = const {},
    this.widgetUrl,
  });

  final String name;
  final Map<String, String> assets;
  final String? widgetUrl;

  static ChallengeInfo fromJson(Map<String, dynamic> json) => ChallengeInfo(
    name: json['name'] as String,
    assets:
        (json['assets'] as Map<String, dynamic>?)?.cast<String, String>() ??
        const {},
    widgetUrl: json['widgetUrl'] as String?,
  );
}

class ShowState {
  ShowState({required this.viewMode, this.focusedPlayerId});

  final ViewMode viewMode;
  final String? focusedPlayerId;

  static ShowState fromJson(Map<String, dynamic> json) => ShowState(
    viewMode: ViewMode.values.byName(
      json['viewMode'] as String? ?? 'allWithChallenge',
    ),
    focusedPlayerId: json['focusedPlayerId'] as String?,
  );
}

/// One selectable generation model + its realistic-prompt reliability numbers,
/// mirrored from the room service. Shown in the /admin model picker.
class ModelCandidate {
  ModelCandidate({
    required this.id,
    required this.active,
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

  final String id;
  final bool active;
  final double? successPct;
  final double? meanLatencyS;
  final double? proseLeakPct;
  final double? quality;
  final int runs;

  /// Measured under 4-way concurrent load (the real event condition). These
  /// are the headline numbers; serial successPct/meanLatencyS are secondary.
  final double? concurrentSuccessPct;
  final double? concurrentLatencyS;
  final double? concurrentWallS;
  final int concurrentRuns;

  /// The `reasoning_effort` this model is served at when selected (e.g. Kimi
  /// runs at "low"). Null = provider default.
  final String? effort;

  /// False for non-chat (embedding/whisper) models — never selectable.
  final bool isChat;

  /// Short display name (the part after the `/`).
  String get shortName => id.contains('/') ? id.split('/').last : id;

  static ModelCandidate fromJson(Map<String, dynamic> json) => ModelCandidate(
    id: json['id'] as String,
    active: json['active'] as bool? ?? false,
    successPct: (json['successPct'] as num?)?.toDouble(),
    meanLatencyS: (json['meanLatencyS'] as num?)?.toDouble(),
    proseLeakPct: (json['proseLeakPct'] as num?)?.toDouble(),
    quality: (json['quality'] as num?)?.toDouble(),
    runs: json['runs'] as int? ?? 0,
    isChat: json['isChat'] as bool? ?? true,
    concurrentSuccessPct: (json['concurrentSuccessPct'] as num?)?.toDouble(),
    concurrentLatencyS: (json['concurrentLatencyS'] as num?)?.toDouble(),
    concurrentWallS: (json['concurrentWallS'] as num?)?.toDouble(),
    concurrentRuns: json['concurrentRuns'] as int? ?? 0,
    effort: json['effort'] as String?,
  );
}

/// The admin model-picker state: live model + candidates with benchmark data.
class GenerationState {
  GenerationState({required this.activeModel, required this.candidates});

  final String activeModel;
  final List<ModelCandidate> candidates;

  static GenerationState fromJson(Map<String, dynamic> json) =>
      GenerationState(
        activeModel: json['activeModel'] as String? ?? '',
        candidates: [
          for (final c in (json['candidates'] as List? ?? const []))
            ModelCandidate.fromJson((c as Map).cast<String, dynamic>()),
        ],
      );
}

class RoomState {
  RoomState({
    required this.revision,
    required this.roundId,
    required this.challenge,
    required this.challengers,
    required this.show,
    required this.globalContent,
    required this.playerContent,
    required this.generation,
  });

  final int revision;

  /// The server-minted round generation (WI-012) — non-nullable, always
  /// present (the room always has a round generation; there is no null
  /// state). Bumps whenever the round closes/resets (setChallenge,
  /// clearChallenge, removeAllChallengers), so a client whose stored roundId
  /// no longer matches has been kicked.
  final String roundId;
  final Challenge? challenge;
  final List<Challenger> challengers;
  final ShowState show;
  final DisplayContent globalContent;
  final Map<String, DisplayContent> playerContent;
  final GenerationState generation;

  DisplayContent contentFor(String challengerId) =>
      playerContent[challengerId] ?? globalContent;

  Challenger? challengerById(String id) {
    for (final c in challengers) {
      if (c.id == id) return c;
    }
    return null;
  }

  static RoomState fromJson(Map<String, dynamic> json) => RoomState(
    revision: json['revision'] as int? ?? 0,
    roundId: json['roundId'] as String? ?? '',
    challenge: switch (json['challenge']) {
      final Map<String, dynamic> c => Challenge.fromJson(c),
      _ => null,
    },
    challengers: [
      for (final c in (json['challengers'] as List? ?? const []))
        Challenger.fromJson((c as Map).cast<String, dynamic>()),
    ],
    show: ShowState.fromJson(
      (json['show'] as Map? ?? const {}).cast<String, dynamic>(),
    ),
    generation: GenerationState.fromJson(
      (json['generation'] as Map? ?? const {}).cast<String, dynamic>(),
    ),
    globalContent: DisplayContent.values.byName(
      json['globalContent'] as String? ?? 'prompt',
    ),
    playerContent: {
      for (final e
          in ((json['playerContent'] as Map? ?? const {})
              .cast<String, dynamic>()
              .entries))
        e.key: DisplayContent.values.byName(e.value as String),
    },
  );
}
