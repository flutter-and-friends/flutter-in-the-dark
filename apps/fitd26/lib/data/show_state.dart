/// Host-controlled audience-view state.
///
/// Firestore location: a `show` MAP FIELD on the `fitd/state` document
/// (NOT a `fitd/state/show` document — the spec's literal path would nest
/// a document under a document, which Firestore forbids; `challengers` is
/// already a subcollection of `fitd/state`).
///
/// Shape: `fitd/state.show = {viewMode: String, focusedPlayerId: String?}`
/// Written by /admin, read live by every /show listener.
class ShowState {
  final ViewMode viewMode;
  final String? focusedPlayerId;

  const ShowState({this.viewMode = ViewMode.allWithChallenge, this.focusedPlayerId});

  static const ShowState initial = ShowState();

  static ShowState fromData(Map<String, dynamic>? stateDoc) {
    final show = stateDoc?['show'];
    if (show is! Map<String, dynamic>) return initial;
    return ShowState(
      viewMode: ViewMode.fromString(show['viewMode']),
      focusedPlayerId: switch (show['focusedPlayerId']) {
        final String id when id.isNotEmpty => id,
        _ => null,
      },
    );
  }
}

enum ViewMode {
  allWithChallenge,
  allPlayers,
  singlePlayer,
  challengeOnly;

  static ViewMode fromString(Object? value) {
    for (final mode in values) {
      if (mode.name == value) return mode;
    }
    return allWithChallenge;
  }

  String get label => switch (this) {
    allWithChallenge => 'Challenge + all',
    allPlayers => 'All players',
    singlePlayer => 'Single player',
    challengeOnly => 'Challenge only',
  };
}
