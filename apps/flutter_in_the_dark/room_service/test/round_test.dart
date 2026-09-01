/// Tests for the player-persistence contract: challenge lifecycle
/// (setChallenge / clearChallenge) preserves every registered player — only
/// admin Remove (single) and removeAll invalidate identities. roundId is the
/// PLAYER-SET generation: it bumps only on removeAll.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_in_the_dark_room_service/models.dart';
import 'package:flutter_in_the_dark_room_service/pipeline.dart';
import 'package:flutter_in_the_dark_room_service/room.dart';
import 'package:test/test.dart';

RoomState freshRoom() {
  final room = RoomState(pipeline: Pipeline(backendBase: 'http://unused'));
  room.load();
  return room;
}

void setSomeChallenge(RoomState room) => room.setChallenge(
      name: 'c',
      widgetUrl: '/compiled/x',
      startTime: DateTime.now().toUtc(),
      endTime: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    );

void main() {
  group('roundId is the player-set generation', () {
    test('room boots with a non-empty roundId, exposed in toJson', () {
      final room = freshRoom();
      expect(room.room.roundId, isNotEmpty);
      expect(room.room.toJson()['roundId'], room.room.roundId);
    });

    test('setChallenge does NOT bump roundId', () {
      final room = freshRoom();
      final before = room.room.roundId;
      setSomeChallenge(room);
      expect(room.room.roundId, before);
    });

    test('clearChallenge does NOT bump roundId', () {
      final room = freshRoom();
      setSomeChallenge(room);
      final before = room.room.roundId;
      room.clearChallenge();
      expect(room.room.roundId, before);
    });

    test('removeAllChallengers bumps roundId', () {
      final room = freshRoom();
      final before = room.room.roundId;
      room.removeAllChallengers();
      expect(room.room.roundId, isNot(before));
    });

    test('removeChallenger does NOT bump roundId', () {
      final room = freshRoom();
      final join = room.join('ada');
      final before = room.room.roundId;
      room.removeChallenger(join.playerId);
      expect(room.room.roundId, before);
    });

    test('roundId round-trips through the state file', () async {
      final tmp = Directory.systemTemp.createTempSync('round_test');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final file = File('${tmp.path}/state.json');

      final room = RoomState(
        pipeline: Pipeline(backendBase: 'http://unused'),
        stateFile: file,
      );
      room.load();
      room.join('ada'); // any mutation arms the persist debouncer
      // _persist debounces 500 ms; give it room to flush.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      final reloaded = RoomState(
        pipeline: Pipeline(backendBase: 'http://unused'),
        stateFile: file,
      );
      reloaded.load();
      expect(reloaded.room.roundId, room.room.roundId);
    });
  });

  group('join + token binding', () {
    test('join returns the current roundId alongside playerId and token', () {
      final room = freshRoom();
      final result = room.join('ada');
      expect(result.roundId, room.room.roundId);
      expect(result.playerId, isNotEmpty);
      expect(result.token, isNotEmpty);
    });

    test('token validates while its player is registered', () {
      final room = freshRoom();
      final join = room.join('ada');
      expect(room.checkToken(join.playerId, join.token), isTrue);
    });

    test('wrong token rejected', () {
      final room = freshRoom();
      final join = room.join('ada');
      expect(room.checkToken(join.playerId, 'bogus'), isFalse);
      expect(room.checkToken(join.playerId, null), isFalse);
    });

    for (final transition in ['clearChallenge', 'setChallenge']) {
      test('challenge transition via $transition keeps the session valid', () {
        final room = freshRoom();
        final join = room.join('ada');
        expect(room.checkToken(join.playerId, join.token), isTrue);

        switch (transition) {
          case 'clearChallenge':
            room.clearChallenge();
          case 'setChallenge':
            setSomeChallenge(room);
        }

        // Players persist across challenges: same session still validates,
        // the player is still registered, and no re-join is needed.
        expect(room.checkToken(join.playerId, join.token), isTrue);
        expect(room.room.challengers.containsKey(join.playerId), isTrue);
      });
    }

    test('removeAllChallengers invalidates every token', () {
      final room = freshRoom();
      final a = room.join('ada');
      final b = room.join('grace');
      room.removeAllChallengers();
      expect(room.checkToken(a.playerId, a.token), isFalse);
      expect(room.checkToken(b.playerId, b.token), isFalse);

      // A fresh join mints under the NEW generation and validates again.
      final rejoin = room.join('ada');
      expect(rejoin.roundId, room.room.roundId);
      expect(room.checkToken(rejoin.playerId, rejoin.token), isTrue);
    });

    test('removeChallenger drops just that token (no round bump needed)', () {
      final room = freshRoom();
      final a = room.join('ada');
      final b = room.join('grace');
      room.removeChallenger(a.playerId);
      expect(room.checkToken(a.playerId, a.token), isFalse);
      // Everyone else's session is untouched.
      expect(room.checkToken(b.playerId, b.token), isTrue);
    });
  });

  group('players persist across challenges', () {
    test('join before any challenge: the player waits, then plays', () {
      final room = freshRoom();
      final join = room.join('ada');
      expect(room.room.challenge, isNull);
      expect(room.updatePrompt(join.playerId, 'a red button'), isNull);

      setSomeChallenge(room);

      // Still the same player, same session, prompt intact.
      expect(room.room.challengers.keys, [join.playerId]);
      expect(room.room.challengers[join.playerId]!.prompt, 'a red button');
      expect(room.updatePrompt(join.playerId, 'a blue button'), isNull);
    });

    test('setChallenge resets pipeline state but keeps identity and prompt',
        () {
      final room = freshRoom();
      final join = room.join('ada');
      room.updatePrompt(join.playerId, 'my widget');
      final c = room.room.challengers[join.playerId]!
        ..genState = GenState.ready
        ..generatedCode = 'code'
        ..compiledUrl = '/compiled/1'
        ..fixAttempts = 1;

      setSomeChallenge(room);

      expect(c.genState, GenState.idle);
      expect(c.generatedCode, isNull);
      expect(c.compiledUrl, isNull);
      expect(c.fixAttempts, 0);
      expect(c.prompt, 'my widget');
      expect(c.name, 'ada');
    });

    test('a second challenger can join while a challenge is running', () {
      final room = freshRoom();
      final a = room.join('ada');
      setSomeChallenge(room);
      final b = room.join('grace');
      expect(room.room.challengers.keys,
          unorderedEquals([a.playerId, b.playerId]));
      expect(room.checkToken(b.playerId, b.token), isTrue);
    });
  });

  group('sessionFor — "here\'s my ID, do you know me?"', () {
    test('unknown playerId → known:false, no name', () {
      final room = freshRoom();
      final session = room.sessionFor('nobody');
      expect(session.known, isFalse);
      expect(session.name, isNull);
    });

    test('registered player → known:true with the server-side name', () {
      final room = freshRoom();
      final join = room.join('ada lovelace');
      final session = room.sessionFor(join.playerId);
      expect(session.known, isTrue);
      expect(session.name, 'ada lovelace');
    });

    test('still known after setChallenge and clearChallenge', () {
      final room = freshRoom();
      final join = room.join('ada');
      setSomeChallenge(room);
      expect(room.sessionFor(join.playerId).known, isTrue);
      room.clearChallenge();
      expect(room.sessionFor(join.playerId).known, isTrue);
    });

    test('unknown after admin Remove', () {
      final room = freshRoom();
      final join = room.join('ada');
      room.removeChallenger(join.playerId);
      expect(room.sessionFor(join.playerId).known, isFalse);
    });

    test('unknown after removeAll', () {
      final room = freshRoom();
      final join = room.join('ada');
      room.removeAllChallengers();
      expect(room.sessionFor(join.playerId).known, isFalse);
    });
  });

  group('name ownership', () {
    test('name is served from the server-side Challenger record in room state',
        () {
      final room = freshRoom();
      final join = room.join('ada lovelace');
      final json = room.room.toJson();
      final challengers = json['challengers'] as List;
      final me = challengers.single as Map<String, dynamic>;
      expect(me['id'], join.playerId);
      expect(me['name'], 'ada lovelace');
    });

    test('join response shape carries no name — only ids and token', () {
      // The wire contract: name goes IN the request, and is thereafter read
      // back from the room-state snapshot, never from a session channel.
      final room = freshRoom();
      final join = room.join('ada');
      final wireShape = jsonDecode(jsonEncode({
        'playerId': join.playerId,
        'token': join.token,
        'roundId': join.roundId,
      })) as Map<String, dynamic>;
      expect(wireShape.keys, unorderedEquals(['playerId', 'token', 'roundId']));
    });
  });
}
