/// Route-level round-trip for the live provider override
/// (POST/GET /api/admin/provider). Boots the real server binary twice — once
/// without GEMINI_API_KEY (forced-gemini must 409) and once with a dummy key
/// (all three modes selectable) — and verifies the mode actually changes the
/// provider the pipeline would use (the chain's mode, reported by GET).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Boots bin/server.dart on a free port. [geminiKey] null → env var absent.
Future<({Process process, int port})> bootServer({String? geminiKey}) async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final freePort = probe.port;
  await probe.close();
  final process = await Process.start(
    Platform.resolvedExecutable,
    ['bin/server.dart', '--port', '$freePort', '--state-file', ''],
    workingDirectory: Directory.current.path,
    // Start from a scrubbed copy of the parent env (minus GEMINI_API_KEY) so
    // the no-key case is deterministic even on a shell where the operator has
    // it set. Platform.environment is unmodifiable — copy before removing.
    environment: {
      ...Map<String, String>.from(Platform.environment)
        ..remove('GEMINI_API_KEY'),
      if (geminiKey != null) 'GEMINI_API_KEY': geminiKey,
    },
  );
  final ready = Completer<int>();
  process.stdout.transform(utf8.decoder).listen((line) {
    stdout.writeln('[server] $line');
    final match = RegExp(r'listening on 0\.0\.0\.0:(\d+)').firstMatch(line);
    if (match != null && !ready.isCompleted) {
      ready.complete(int.parse(match.group(1)!));
    }
  });
  process.stderr.transform(utf8.decoder).listen(stderr.writeln);
  final port = await ready.future.timeout(const Duration(seconds: 30));
  return (process: process, port: port);
}

void main() {
  final client = http.Client();

  Future<http.Response> postRaw(int port, Map<String, dynamic> body) {
    return client.post(
      Uri.parse('http://127.0.0.1:$port/api/admin/provider'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  Future<Map<String, dynamic>> getMode(int port) async {
    final response = await client.get(
      Uri.parse('http://127.0.0.1:$port/api/admin/provider'),
    );
    expect(response.statusCode, 200);
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  group('with GEMINI_API_KEY', () {
    late Process server;
    late int port;

    setUpAll(() async {
      final boot = await bootServer(geminiKey: 'dummy-test-key');
      server = boot.process;
      port = boot.port;
    });

    tearDownAll(() async {
      server.kill();
      await server.exitCode;
    });

    test('GET reports auto + gemini available at boot', () async {
      final state = await getMode(port);
      expect(state['provider'], 'auto');
      expect(state['available'], {'berget': true, 'gemini': true});
    });

    test('POST switches mode and GET reflects it', () async {
      for (final mode in ['gemini', 'berget', 'auto']) {
        final response = await postRaw(port, {'provider': mode});
        expect(response.statusCode, 200,
            reason: 'mode $mode should be accepted');
        final body = (jsonDecode(response.body) as Map).cast<String, dynamic>();
        expect(body, {'ok': true, 'provider': mode});
        expect((await getMode(port))['provider'], mode);
      }
    });

    test('POST rejects an unknown provider with 400', () async {
      final response = await postRaw(port, {'provider': 'openai'});
      expect(response.statusCode, 400);
      final body = (jsonDecode(response.body) as Map).cast<String, dynamic>();
      expect(body['error'], contains('auto|berget|gemini'));
      // Mode unchanged by the rejected call.
      expect((await getMode(port))['provider'], 'auto');
    });

    test('POST with missing provider field → 400', () async {
      final response = await postRaw(port, {});
      expect(response.statusCode, 400);
    });
  });

  group('without GEMINI_API_KEY', () {
    late Process server;
    late int port;

    setUpAll(() async {
      final boot = await bootServer();
      server = boot.process;
      port = boot.port;
    });

    tearDownAll(() async {
      server.kill();
      await server.exitCode;
    });

    test('GET reports gemini unavailable', () async {
      final state = await getMode(port);
      expect(state['provider'], 'auto');
      expect(state['available'], {'berget': true, 'gemini': false});
    });

    test('forced gemini is rejected with 409 and a clear message', () async {
      final response = await postRaw(port, {'provider': 'gemini'});
      expect(response.statusCode, 409);
      final body = (jsonDecode(response.body) as Map).cast<String, dynamic>();
      expect(body['error'], contains('GEMINI_API_KEY not set'));
      // The failed selection must not stick.
      expect((await getMode(port))['provider'], 'auto');
    });

    test('berget and auto remain selectable without a key', () async {
      for (final mode in ['berget', 'auto']) {
        final response = await postRaw(port, {'provider': mode});
        expect(response.statusCode, 200);
        expect((await getMode(port))['provider'], mode);
      }
    });
  });

  tearDownAll(() => client.close());
}
