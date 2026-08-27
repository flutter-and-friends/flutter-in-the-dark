import 'package:flutter_in_the_dark/helpers/session_identity.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_test/flutter_test.dart';

// Pure VM tests for the player boot/session identity decision. Same import
// discipline as session_kick_test.dart (W-012): no dart:js_interop
// transitively, so this compiles under `flutter test`'s VM.

RoomState _state({List<String> challengerIds = const []}) => RoomState(
  revision: 1,
  roundId: 'r1',
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
  group('decideBoot', () {
    test('no stored session → register (name entry)', () {
      expect(
        decideBoot(storedPlayerId: null, state: _state(challengerIds: ['p1'])),
        BootDecision.register,
      );
    });

    test('no stored session and no snapshot → register', () {
      expect(
        decideBoot(storedPlayerId: null, state: null),
        BootDecision.register,
      );
    });

    test('stored session, no snapshot yet → resume unverified', () {
      // A reloading player must not be bounced to name entry just because
      // the SSE snapshot hasn't landed; the player screen's kick wiring
      // arbitrates when it does.
      expect(
        decideBoot(storedPlayerId: 'p1', state: null),
        BootDecision.resumeUnverified,
      );
    });

    test('stored session known to the server → resume (no name entry)', () {
      expect(
        decideBoot(
          storedPlayerId: 'p1',
          state: _state(challengerIds: ['p1', 'p2']),
        ),
        BootDecision.resume,
      );
    });

    test('stored session unknown to the server → evict to name entry', () {
      // Admin Remove / Remove-all: the playerId is gone from the snapshot.
      expect(
        decideBoot(
          storedPlayerId: 'p1',
          state: _state(challengerIds: ['p2']),
        ),
        BootDecision.evictToNameEntry,
      );
    });

    test('stored session, empty room → evict to name entry', () {
      expect(
        decideBoot(storedPlayerId: 'p1', state: _state()),
        BootDecision.evictToNameEntry,
      );
    });
  });
}
