/// Client-side mirror of the room-service JSON model
/// (`apps/fitd26/room_service/lib/models.dart`). Field names must stay in
/// sync with the server; the SSE `state` event carries this whole shape.
library;

enum ChallengerStatus { active, blocked }

enum GenState { idle, queued, generating, compiling, ready, failed }

enum ViewMode {
  allWithChallenge,
  allPlayers,
  singlePlayer,
  challengeOnly;

  String get label => switch (this) {
    allWithChallenge => 'Challenge + all',
    allPlayers => 'All players',
    singlePlayer => 'Single player',
    challengeOnly => 'Challenge only',
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
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    widgetUrl: json['widgetUrl'] as String,
    assets:
        (json['assets'] as Map<String, dynamic>?)?.cast<String, String>() ??
        const {},
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

class RoomState {
  RoomState({
    required this.revision,
    required this.challenge,
    required this.challengers,
    required this.show,
    required this.globalContent,
    required this.playerContent,
  });

  final int revision;
  final Challenge? challenge;
  final List<Challenger> challengers;
  final ShowState show;
  final DisplayContent globalContent;
  final Map<String, DisplayContent> playerContent;

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
