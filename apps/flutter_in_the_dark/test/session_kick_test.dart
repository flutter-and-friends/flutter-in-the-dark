import 'package:flutter_in_the_dark/helpers/session_kick.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_test/flutter_test.dart';

// Pure VM tests for the kick decision. This file deliberately imports ONLY
// session_kick.dart + room_models.dart — NOT challenge_screen.dart,
// session_store.dart, or room_client.dart (which pull in dart:js_interop and
// cannot compile under `flutter test`'s VM). See W-012 / SHADOW-003: the
// widget flow itself is verified e2e, not via a mirror-harness widget test.

RoomState _state({String roundId = '', List<String> challengerIds = const []}) =>
    RoomState(
      revision: 1,
      roundId: roundId,
      challenge: null,
      challengers: [
        for (final id in challengerIds)
          Challenger(
            id: id,
            name: 'Player $id',
            status: ChallengerStatus.active,
            prompt: '',
            genState: GenState.idle,
          ),
      ],
      show: ShowState(viewMode: ViewMode.allWithChallenge),
      globalContent: DisplayContent.prompt,
      playerContent: const {},
      generation: GenerationState(activeModel: 'm', candidates: const []),
    );

void main() {
  group('isKickedByState', () {
    test('keeps a session whose player is in the snapshot', () {
      expect(
        isKickedByState(
          playerId: 'p1',
          state: _state(roundId: 'r1', challengerIds: ['p1', 'p2']),
        ),
        isFalse,
      );
    });

    test('does NOT kick while there is no snapshot yet (reconnecting)', () {
      // A null state is no evidence — kicking here would bounce a reloading
      // player back to name entry spuriously.
      expect(isKickedByState(playerId: 'p1', state: null), isFalse);
    });

    test('kicks when the player is gone (admin Remove)', () {
      expect(
        isKickedByState(
          playerId: 'p1',
          state: _state(roundId: 'r1', challengerIds: ['p2']),
        ),
        isTrue,
      );
    });

    test('kicks when the player list was cleared (admin Remove-all)', () {
      expect(
        isKickedByState(playerId: 'p1', state: _state(roundId: 'r2')),
        isTrue,
      );
    });

    test('does NOT kick on a round roll alone (new challenge keeps players)',
        () {
      // The core fix: starting a new challenge bumps the round generation
      // server-side today, but players persist across challenges — a roundId
      // mismatch with the player still present is NOT a kick.
      expect(
        isKickedByState(
          playerId: 'p1',
          state: _state(roundId: 'r2', challengerIds: ['p1']),
        ),
        isFalse,
      );
    });

    test('does NOT kick when the round resets to empty (challenge cleared)',
        () {
      expect(
        isKickedByState(
          playerId: 'p1',
          state: _state(challengerIds: ['p1']),
        ),
        isFalse,
      );
    });
  });

  group('kick decision over a snapshot sequence', () {
    bool kickedAfter({
      required String playerId,
      required List<RoomState?> snapshots,
    }) {
      // Mirrors how ChallengeScreen._onRoomChanged consults the decision on
      // every applied snapshot: the first kick ends the session.
      for (final s in snapshots) {
        if (isKickedByState(playerId: playerId, state: s)) return true;
      }
      return false;
    }

    test('survives reconnect nulls and a new challenge, kicked only on '
        'removal', () {
      final snapshots = <RoomState?>[
        _state(roundId: 'r1', challengerIds: ['p1']), // live
        null, // reconnect window — no evidence
        _state(roundId: 'r1', challengerIds: ['p1']), // healed
        _state(roundId: 'r2', challengerIds: ['p1']), // new challenge — stays
        _state(roundId: 'r2', challengerIds: ['p2']), // admin Remove — gone
      ];
      expect(kickedAfter(playerId: 'p1', snapshots: snapshots), isTrue);
    });

    test('stays joined across challenge start and clear', () {
      final snapshots = <RoomState?>[
        _state(roundId: 'r1', challengerIds: ['p1']),
        _state(roundId: 'r2', challengerIds: ['p1']), // setChallenge
        _state(roundId: 'r3', challengerIds: ['p1']), // clearChallenge
      ];
      expect(kickedAfter(playerId: 'p1', snapshots: snapshots), isFalse);
    });
  });
}
