/// Server-side client for the dart_services fork: generateCode, compileAndServe
/// and suggestFix. Drives one challenger's `queued → generating → compiling →
/// ready | failed` pipeline with the measured auto-rerun policy
/// (suggestFix → recompile; full regenerate after 2 failed fixes).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class PipelineException implements Exception {
  PipelineException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to the dart_services fork over plain HTTP (in-container, no CORS
/// concerns). Streaming endpoints are consumed as chunked byte streams.
class Pipeline {
  Pipeline({required this.backendBase, String? initialModel})
    : model = initialModel ?? defaultModel;

  /// e.g. `http://127.0.0.1:8300`
  final String backendBase;

  /// The generation model used when the operator hasn't picked one. Matches
  /// the dart_services boot-time default so behaviour is unchanged when the
  /// picker is never touched.
  static const defaultModel = 'google/gemma-4-31B-it';

  /// The generation model currently selected for new work. Owned here (not in
  /// dart_services) so the admin can fail over live without a backend restart
  /// — the value is passed to dart_services as a per-request `model` override
  /// on every generateCode/suggestFix call. Mutated by [RoomState.setModel].
  String model;

  static const maxFixAttempts = 2;

  /// A fresh client per pipeline run. A long-lived shared client wedges when
  /// a generation stream is abandoned mid-flight (the per-host connection
  /// pool exhausts and every subsequent send queues forever).
  http.Client _client() => http.Client();

  /// Runs the full pipeline for [challenger]. Mutates the challenger in place;
  /// [onChange] is invoked after every state change so the caller can persist
  /// + broadcast. Returns when the challenger reaches `ready` or `failed`
  /// (with `error` set).
  Future<void> run(
    Challenger challenger,
    FutureOr<void> Function() onChange,
  ) async {
    final client = _client();
    print('[pipeline] run() entered for ${challenger.name}');
    try {
      // 1. Generate (unless we already have code from a previous fix loop).
      if (challenger.generatedCode == null) {
        challenger.genState = GenState.generating;
        await onChange();
        print('[pipeline] calling _generate for ${challenger.name}');
        challenger.generatedCode = await _generate(challenger.prompt, client);
        print('[pipeline] _generate returned for ${challenger.name}');
      }
      challenger.genState = GenState.compiling;
      await onChange();

      // 2. Compile, with the suggestFix loop on failure.
      var source = challenger.generatedCode!;
      var fixes = 0;
      while (true) {
        final problems = await _compile(challenger, source, onChange, client);
        if (problems == null) return; // ready

        if (fixes >= maxFixAttempts) {
          // Fall back to one full regeneration, then give up if that fails.
          challenger.generatedCode = null;
          source = await _generate(challenger.prompt, client);
          challenger.generatedCode = source;
          challenger.genState = GenState.compiling;
          await onChange();
          final retry = await _compile(challenger, source, onChange, client);
          if (retry == null) return;
          throw PipelineException(
            'Generation did not produce compilable code: ${retry.join('\n')}',
          );
        }

        fixes++;
        challenger.fixAttempts = fixes;
        await onChange();
        source = await _suggestFix(source, problems, client);
        challenger.generatedCode = source;
      }
    } catch (e, st) {
      // A failed attempt must not leave partial code behind — the next run
      // regenerates from the prompt. (A truncated mid-stream body was
      // previously kept, permanently blocking regeneration.)
      challenger.generatedCode = null;
      challenger.genState = GenState.failed;
      challenger.error = e.toString();
      // Surface pipeline failures loudly in the service log — a silently
      // dropped future leaves the challenger stuck on `queued` forever.
      print('[pipeline] ${challenger.name} FAILED: $e\n$st');
      await onChange();
    } finally {
      client.close();
    }
  }

  /// Attempts to compile [source]; on success sets `compiledUrl` + `ready` and
  /// returns null; on failure returns the problems list (state stays
  /// `compiling`).
  Future<List<String>?> _compile(
    Challenger challenger,
    String source,
    FutureOr<void> Function() onChange,
    http.Client client,
  ) async {
    final response = await client
        .post(
          Uri.parse('$backendBase/api/v3/compileAndServe'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'source': source}),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      challenger.compiledUrl = body['url'] as String;
      challenger.genState = GenState.ready;
      challenger.error = null;
      await onChange();
      return null;
    }

    if (response.statusCode == 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['error'] == 'compile_failed') {
        return [
          for (final p in (body['problems'] as List? ?? const []))
            p.toString(),
        ];
      }
    }
    throw PipelineException(
      'compileAndServe HTTP ${response.statusCode}: ${response.body}',
    );
  }

  Future<String> _generate(String prompt, http.Client client) async {
    print('[pipeline] generate START (${prompt.length} chars)');
    final request = http.Request(
      'POST',
      Uri.parse('$backendBase/api/v3/generateCode'),
    )
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'appType': 'flutter',
        'prompt': prompt,
        'attachments': <String>[],
        'model': model,
      });
    final result = await _streamText(request, 'generateCode', client);
    print('[pipeline] generate DONE (${result.length} chars)');
    return result;
  }

  Future<String> _suggestFix(String source, List<String> problems, http.Client client) async {
    final request = http.Request(
      'POST',
      Uri.parse('$backendBase/api/v3/suggestFix'),
    )
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'appType': 'flutter',
        'errorMessage': problems.join('\n'),
        'line': 0,
        'column': 0,
        'source': source,
        'model': model,
      });
    return _streamText(request, 'suggestFix', client);
  }

  /// POSTs a streaming endpoint and accumulates the whole text body. A
  /// silently truncated stream is indistinguishable from success here, so the
  /// caller validates the result (compile) — that is the pipeline's contract.
  Future<String> _streamText(http.Request request, String label, http.Client client) async {
    print('[pipeline] $label send -> ${request.url}');
    final sw = Stopwatch()..start();
    final response = await client
        .send(request)
        .timeout(const Duration(minutes: 3));
    print('[pipeline] $label response ${response.statusCode} after ${sw.elapsedMilliseconds}ms');
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw PipelineException('$label HTTP ${response.statusCode}: $body');
    }
    final text = await response.stream.bytesToString();
    print('[pipeline] $label stream complete (${text.length} chars)');
    return text;
  }

  /// Minimal round-trip used by /api/probe-generate: generates for the given
  /// prompt and returns the produced length. Proves the outbound HTTP path.
  Future<int> probeGenerate([String prompt = 'a red button']) async {
    final client = _client();
    try {
      final text = await _generate(prompt, client);
      return text.length;
    } finally {
      client.close();
    }
  }

  void dispose() {}
}
