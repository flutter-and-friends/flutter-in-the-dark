/// Data model for the fitd26 room. Pure Dart, JSON-round-trippable.
///
/// The whole room lives in one [Room] object owned by [RoomState]; every
/// mutation bumps `revision` and broadcasts a full `state` event to SSE
/// subscribers (the room is small — full snapshots keep clients trivially
/// in sync and make Last-Event-ID catch-up a single refetch).
library;

enum ChallengerStatus { active, blocked }

enum GenState { idle, queued, generating, compiling, ready, failed }

enum ViewMode { allWithChallenge, allPlayers, singlePlayer, challengeOnly }

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
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'widgetUrl': widgetUrl,
    'assets': assets,
  };

  static Challenge fromJson(Map<String, dynamic> json) => Challenge(
    id: json['id'] as String,
    name: json['name'] as String,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
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

class Room {
  int revision = 0;
  Challenge? challenge;
  final Map<String, Challenger> challengers = {};
  ShowState show = ShowState();

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
    'challenge': challenge?.toJson(),
    'challengers': [
      for (final c in challengers.values) c.toJson(),
    ],
    'show': show.toJson(),
    'globalContent': globalContent.name,
    'playerContent': {for (final e in playerContent.entries) e.key: e.value.name},
  };

  static Room fromJson(Map<String, dynamic> json) {
    final room = Room();
    room.revision = json['revision'] as int? ?? 0;
    if (json['challenge'] case final Map<String, dynamic> c) {
      room.challenge = Challenge.fromJson(c);
    }
    for (final c in (json['challengers'] as List? ?? const [])) {
      final challenger = Challenger.fromJson((c as Map).cast<String, dynamic>());
      room.challengers[challenger.id] = challenger;
    }
    if (json['show'] case final Map<String, dynamic> s) {
      room.show = ShowState.fromJson(s);
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
