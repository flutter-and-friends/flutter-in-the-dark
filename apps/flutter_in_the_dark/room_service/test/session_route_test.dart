/// Integration test for the kick-flow contract at the HTTP layer: boots the
/// real server binary on an ephemeral port and verifies that
///  - players (and their sessions) survive challenge transitions — no 403,
///  - admin removeAll invalidates every session (403 on /api/prompt,
///    roundId bump, /api/session reports unknown),
///  - admin Remove invalidates just that one session,
///  - GET /api/session answers "here's my ID — do you know me?".
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  late Process server;
  late int port;
  final client = http.Client();

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
      {int? expectStatus}) async {
    final response = await client.post(
      Uri.parse('http://127.0.0.1:$port$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (expectStatus != null) expect(response.statusCode, expectStatus);
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await client.get(Uri.parse('http://127.0.0.1:$port$path'));
    expect(response.statusCode, 200);
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> state() => get('/api/state');

  setUpAll(() async {
    // Pick a free port first: the server's startup log prints the REQUESTED
    // port, so passing 0 would leave us without the real bound port.
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final freePort = probe.port;
    await probe.close();
    server = await Process.start(
      Platform.resolvedExecutable,
      ['bin/server.dart', '--port', '$freePort', '--state-file', ''],
      workingDirectory: Directory.current.path,
    );
    final ready = Completer<int>();
    server.stdout.transform(utf8.decoder).listen((line) {
      stdout.writeln('[server] $line');
      final match = RegExp(r'listening on 0\.0\.0\.0:(\d+)').firstMatch(line);
      if (match != null && !ready.isCompleted) {
        ready.complete(int.parse(match.group(1)!));
      }
    });
    server.stderr.transform(utf8.decoder).listen(stderr.writeln);
    port = await ready.future.timeout(const Duration(seconds: 30));
  });

  tearDownAll(() async {
    client.close();
    server.kill();
    await server.exitCode;
  });

  test('challenge transitions do not kick players', () async {
    // Join before any challenge exists (join-and-wait).
    final join = await post('/api/join', {'name': 'ada'}, expectStatus: 200);
    expect(join.keys, containsAll(['playerId', 'token', 'roundId']));
    final sessionQuery = '/api/session?playerId=${join['playerId']}';

    // Known, with the server-side name.
    final before = await get(sessionQuery);
    expect(before['known'], isTrue);
    expect(before['name'], 'ada');

    // Start a challenge: roundId stays, the session keeps validating.
    await post(
        '/api/admin/challenge',
        {
          'name': 'hello-dark',
          'widgetUrl': '/compiled/x',
          'startTime': DateTime.now().toUtc().millisecondsSinceEpoch,
          'endTime': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 10))
              .millisecondsSinceEpoch,
        },
        expectStatus: 200);
    expect((await state())['roundId'], join['roundId']);
    await post(
        '/api/prompt',
        {
          'playerId': join['playerId'],
          'token': join['token'],
          'prompt': 'a red button',
        },
        expectStatus: 200);

    // Clear the challenge: still known, still writable.
    await post('/api/admin/clear', {}, expectStatus: 200);
    expect((await state())['roundId'], join['roundId']);
    expect((await get(sessionQuery))['known'], isTrue);
    await post(
        '/api/prompt',
        {
          'playerId': join['playerId'],
          'token': join['token'],
          'prompt': 'still here',
        },
        expectStatus: 200);
  });

  test('admin Remove kicks just that player; removeAll kicks everyone',
      () async {
    final a = await post('/api/join', {'name': 'ada'}, expectStatus: 200);
    final b = await post('/api/join', {'name': 'grace'}, expectStatus: 200);

    // Single remove: a is gone, b is untouched.
    await post('/api/admin/removeChallenger', {'playerId': a['playerId']},
        expectStatus: 200);
    expect((await get('/api/session?playerId=${a['playerId']}'))['known'],
        isFalse);
    expect(
        (await get('/api/session?playerId=${b['playerId']}'))['known'], isTrue);
    final kicked = await client.post(
      Uri.parse('http://127.0.0.1:$port/api/prompt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'playerId': a['playerId'],
        'token': a['token'],
        'prompt': 'am I still here?',
      }),
    );
    expect(kicked.statusCode, 403);

    // Clear all: roundId bumps, every remaining session is dead.
    final roundBefore = (await state())['roundId'];
    await post('/api/admin/removeAll', {}, expectStatus: 200);
    expect((await state())['roundId'], isNot(roundBefore));
    expect((await get('/api/session?playerId=${b['playerId']}'))['known'],
        isFalse);
    final cleared = await client.post(
      Uri.parse('http://127.0.0.1:$port/api/prompt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'playerId': b['playerId'],
        'token': b['token'],
        'prompt': 'too late',
      }),
    );
    expect(cleared.statusCode, 403);

    // A fresh join works and is known again.
    final rejoin = await post('/api/join', {'name': 'ada'}, expectStatus: 200);
    final session = await get('/api/session?playerId=${rejoin['playerId']}');
    expect(session['known'], isTrue);
    expect(session['name'], 'ada');
    await post(
        '/api/prompt',
        {
          'playerId': rejoin['playerId'],
          'token': rejoin['token'],
          'prompt': 'back in',
        },
        expectStatus: 200);
  });

  test('unknown / missing playerId on /api/session → known:false', () async {
    expect((await get('/api/session?playerId=nobody'))['known'], isFalse);
    expect((await get('/api/session'))['known'], isFalse);
  });
}
