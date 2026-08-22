/// Integration test for the WI-012 wire contract at the HTTP layer: boots the
/// real server binary on an ephemeral port and verifies that /api/prompt
/// surfaces HTTP 403 (not a generic error) once the round closes under a
/// session, and that a fresh join under the new round validates again.
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

  test('stale session after round close → /api/prompt 403', () async {
    // Join under round R.
    final join = await post('/api/join', {'name': 'ada'}, expectStatus: 200);
    expect(join.keys, containsAll(['playerId', 'token', 'roundId']));

    // Snapshot exposes the same roundId.
    final state = await client
        .get(Uri.parse('http://127.0.0.1:$port/api/state'))
        .then((r) => (jsonDecode(r.body) as Map).cast<String, dynamic>());
    expect(state['roundId'], join['roundId']);

    // Token validates while R is current.
    await post('/api/prompt', {
      'playerId': join['playerId'],
      'token': join['token'],
      'prompt': 'a red button',
    }, expectStatus: 200);

    // Close the round.
    await post('/api/admin/clear', {}, expectStatus: 200);

    // Snapshot roundId bumped.
    final state2 = await client
        .get(Uri.parse('http://127.0.0.1:$port/api/state'))
        .then((r) => (jsonDecode(r.body) as Map).cast<String, dynamic>());
    expect(state2['roundId'], isNot(join['roundId']));

    // The old session is stale: /api/prompt surfaces HTTP 403.
    final stale = await client.post(
      Uri.parse('http://127.0.0.1:$port/api/prompt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'playerId': join['playerId'],
        'token': join['token'],
        'prompt': 'too late',
      }),
    );
    expect(stale.statusCode, 403);
    expect(
      (jsonDecode(stale.body) as Map).cast<String, dynamic>()['error'],
      isNotEmpty,
    );

    // A fresh join mints under the new round and validates.
    final rejoin = await post('/api/join', {'name': 'ada'}, expectStatus: 200);
    expect(rejoin['roundId'], state2['roundId']);
    await post('/api/prompt', {
      'playerId': rejoin['playerId'],
      'token': rejoin['token'],
      'prompt': 'back in',
    }, expectStatus: 200);
  });
}
