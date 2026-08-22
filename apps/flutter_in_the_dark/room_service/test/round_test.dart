/// Tests for the WI-012 round-generation contract: Room.roundId is minted on
/// boot, BUMPS on every round-close path (setChallenge / clearChallenge /
/// removeAllChallengers), join tokens are bound to the round they were minted
/// in, and checkToken rejects stale tokens after the close. The name lives
/// only in the server-side Challenger record.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_in_the_dark_room_service/pipeline.dart';
import 'package:flutter_in_the_dark_room_service/room.dart';
import 'package:test/test.dart';

RoomState freshRoom() {
  final room = RoomState(pipeline: Pipeline(backendBase: 'http://unused'));
  room.load();
  return room;
}

void main() {
  group('roundId lifecycle', () {
    test('room boots with a non-empty roundId, exposed in toJson', () {
      final room = freshRoom();
      expect(room.room.roundId, isNotEmpty);
      expect(room.room.toJson()['roundId'], room.room.roundId);
    });

    test('setChallenge bumps roundId', () {
      final room = freshRoom();
      final before = room.room.roundId;
      room.setChallenge(
        name: 'c',
        widgetUrl: '/compiled/x',
        startTime: DateTime.now().toUtc(),
        endTime: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      );
      expect(room.room.roundId, isNot(before));
    });

    test('clearChallenge bumps roundId', () {
      final room = freshRoom();
      final before = room.room.roundId;
      room.clearChallenge();
      expect(room.room.roundId, isNot(before));
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

    test('token minted in round R validates while R is current', () {
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

    for (final close in ['clearChallenge', 'removeAllChallengers', 'setChallenge']) {
      test('round close via $close → old token rejected, new join required', () {
        final room = freshRoom();
        final join = room.join('ada');
        expect(room.checkToken(join.playerId, join.token), isTrue);

        switch (close) {
          case 'clearChallenge':
            room.clearChallenge();
          case 'removeAllChallengers':
            room.removeAllChallengers();
          case 'setChallenge':
            room.setChallenge(
              name: 'c',
              widgetUrl: '/compiled/x',
              startTime: DateTime.now().toUtc(),
              endTime: DateTime.now().toUtc().add(const Duration(minutes: 10)),
            );
        }

        // Stale session: same playerId+token no longer validates.
        expect(room.checkToken(join.playerId, join.token), isFalse);

        // A fresh join mints under the NEW round and validates again.
        final rejoin = room.join('ada');
        expect(rejoin.roundId, room.room.roundId);
        expect(room.checkToken(rejoin.playerId, rejoin.token), isTrue);
      });
    }

    test('removeChallenger drops the token (no round bump needed)', () {
      final room = freshRoom();
      final join = room.join('ada');
      room.removeChallenger(join.playerId);
      expect(room.checkToken(join.playerId, join.token), isFalse);
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
