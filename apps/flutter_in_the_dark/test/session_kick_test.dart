import 'package:flutter_in_the_dark/helpers/session_kick.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_test/flutter_test.dart';

// Pure VM tests for the WI-012 kick decision. This file deliberately imports
// ONLY session_kick.dart + room_models.dart — NOT challenge_screen.dart,
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
    test('keeps a valid session in the current round', () {
      expect(
        isKickedByState(
          playerId: 'p1',
          roundId: 'r1',
          state: _state(roundId: 'r1', challengerIds: ['p1', 'p2']),
        ),
        isFalse,
      );
    });

    test('does NOT kick while there is no snapshot yet (reconnecting)', () {
      // A null state is no evidence — kicking here would bounce a reloading
      // player back to join spuriously.
      expect(
        isKickedByState(playerId: 'p1', roundId: 'r1', state: null),
        isFalse,
      );
    });

    test('kicks when the round rolled (roundId differs)', () {
      // Even if the challenger record is still present, a new round means the
      // old round-scoped session is invalid.
      expect(
        isKickedByState(
          playerId: 'p1',
          roundId: 'r1',
          state: _state(roundId: 'r2', challengerIds: ['p1']),
        ),
        isTrue,
      );
    });

    test('kicks when the round rolled to null (challenge cleared)', () {
      expect(
        isKickedByState(
          playerId: 'p1',
          roundId: 'r1',
          state: _state(challengerIds: ['p1']),
        ),
        isTrue,
      );
    });

    test('kicks when the player is gone from the same round', () {
      expect(
        isKickedByState(
          playerId: 'p1',
          roundId: 'r1',
          state: _state(roundId: 'r1', challengerIds: ['p2']),
        ),
        isTrue,
      );
    });

    test('kicks when the player is gone AND the round rolled', () {
      expect(
        isKickedByState(
          playerId: 'p1',
          roundId: 'r1',
          state: _state(roundId: 'r2', challengerIds: ['p2']),
        ),
        isTrue,
      );
    });

    test(
      'round roll takes the kick even when the player id lingers in the '
      'new round (id reused)',
      () {
        // A reattached id in a new round is still a kick: the old session's
        // round is over.
        expect(
          isKickedByState(
            playerId: 'p1',
            roundId: 'r1',
            state: _state(roundId: 'r2', challengerIds: ['p1']),
          ),
          isTrue,
        );
      },
    );
  });

  group('kick decision over a snapshot sequence (round close)', () {
    bool kickedAfter({
      required String playerId,
      required String roundId,
      required List<RoomState?> snapshots,
    }) {
      // Mirrors how ChallengeScreen._onRoomChanged consults the decision on
      // every applied snapshot: the first kick ends the session.
      for (final s in snapshots) {
        if (isKickedByState(playerId: playerId, roundId: roundId, state: s)) {
          return true;
        }
      }
      return false;
    }

    test('survives reconnect nulls, kicked only when the round rolls', () {
      final snapshots = <RoomState?>[
        _state(roundId: 'r1', challengerIds: ['p1']), // live
        null, // reconnect window — no evidence
        _state(roundId: 'r1', challengerIds: ['p1']), // healed
        _state(roundId: 'r2'), // round closed
      ];
      expect(
        kickedAfter(playerId: 'p1', roundId: 'r1', snapshots: snapshots),
        isTrue,
      );
    });

    test('stays joined while the round is unchanged', () {
      final snapshots = <RoomState?>[
        _state(roundId: 'r1', challengerIds: ['p1']),
        null,
        _state(roundId: 'r1', challengerIds: ['p1', 'p2']),
      ];
      expect(
        kickedAfter(playerId: 'p1', roundId: 'r1', snapshots: snapshots),
        isFalse,
      );
    });

    test('kicked when removed mid-round (admin removeChallenger)', () {
      final snapshots = <RoomState?>[
        _state(roundId: 'r1', challengerIds: ['p1', 'p2']),
        _state(roundId: 'r1', challengerIds: ['p2']), // p1 removed, same round
      ];
      expect(
        kickedAfter(playerId: 'p1', roundId: 'r1', snapshots: snapshots),
        isTrue,
      );
    });
  });
}
