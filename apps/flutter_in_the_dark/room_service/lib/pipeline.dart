/// Server-side client for the dart_services fork: generateCode, compileAndServe
/// and suggestFix. Drives one challenger's `queued → generating → compiling →
/// ready | failed` pipeline with the measured auto-rerun policy
/// (suggestFix → recompile; full regenerate after 2 failed fixes).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_providers.dart';
import 'models.dart';

class PipelineException implements Exception {
  PipelineException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Drives one challenger's generate/compile/fix pipeline.
///
/// Compile stays a plain HTTP call to the dart_services fork (Gemini cannot
/// compile Dart — dart_services is the compile backend no matter what). The
/// LLM generation half goes through a [CodeGenerator]: dart_services (Berget)
/// primary, Gemini fallback when `GEMINI_API_KEY` is set. See
/// llm_providers.dart for the provider contract and env gating.
class Pipeline {
  /// [generator] is injectable for tests; when omitted it is built from the
  /// environment (Berget primary, Gemini fallback iff `GEMINI_API_KEY`).
  Pipeline(
      {required this.backendBase,
      String? initialModel,
      CodeGenerator? generator})
      : model = initialModel ?? defaultModel,
        generator = generator ??
            buildGeneratorFromEnv(backendBase: backendBase).generator;

  /// The LLM behind generation/fix. Berget-via-dart_services is the primary;
  /// Gemini (when configured) catches primary failures.
  final CodeGenerator generator;

  /// e.g. `http://127.0.0.1:8300`
  final String backendBase;

  /// The generation model used when the operator hasn't picked one. Matches
  /// the dart_services boot-time default so behaviour is unchanged when the
  /// picker is never touched.
  ///
  /// Kimi-K3 is the event default (user decision 2026-08-19): served at
  /// `reasoning_effort=low` (see [preferredEffort]) it is the speed/quality
  /// sweet spot — at low effort the reasoning bloat collapses (49 vs 295
  /// tokens) yielding fast, stable, compilable code (~9s), versus the
  /// intermittent throughput collapse it shows at default effort (WI-098).
  static const defaultModel = 'moonshotai/Kimi-K3';

  /// The generation model currently selected for new work. Owned here (not in
  /// dart_services) so the admin can fail over live without a backend restart
  /// — the value is passed to dart_services as a per-request `model` override
  /// on every generateCode/suggestFix call. Mutated by [RoomState.setModel].
  String model;

  static const maxFixAttempts = 2;

  /// Per-model preferred `reasoning_effort`, sent alongside the per-request
  /// `model` override. Data-driven so a future model carries its own setting.
  /// Kimi-K3/K2.6 MUST be served at `low`: at their default effort they are
  /// slow reasoning models prone to intermittent throughput collapse (the
  /// WI-098 "hang" — 7645 reasoning tokens), whereas `low` collapses the
  /// reasoning bloat (measured: 49 vs 295 tokens) and yields fast, stable,
  /// compilable code (~9s). Models absent from this map send NO effort param
  /// and use the provider's own default (the right choice for gpt-oss/gemma/
  /// GLM/Mistral — overriding only adds risk).
  static const Map<String, String> preferredEffort = {
    'moonshotai/Kimi-K3': 'low',
    'moonshotai/Kimi-K2.6': 'low',
  };

  /// The preferred `reasoning_effort` for [model], or null to send none.
  static String? effortFor(String model) => preferredEffort[model];

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
          for (final p in (body['problems'] as List? ?? const [])) p.toString(),
        ];
      }
    }
    throw PipelineException(
      'compileAndServe HTTP ${response.statusCode}: ${response.body}',
    );
  }

  /// Generation goes through the provider chain: Berget-via-dart_services
  /// first, Gemini fallback on failure (see llm_providers.dart). The [client]
  /// param is retained for signature compatibility but generation now owns its
  /// own clients inside the providers.
  Future<String> _generate(String prompt, http.Client client) async {
    final effort = effortFor(model);
    print('[pipeline] generate START (${prompt.length} chars, model=$model'
        '${effort != null ? ', effort=$effort' : ''})');
    final result = await generator.generateCode(
      prompt: prompt,
      model: model,
      reasoningEffort: effort,
    );
    print('[pipeline] generate DONE (${result.length} chars)');
    return result;
  }

  Future<String> _suggestFix(
      String source, List<String> problems, http.Client client) async {
    return generator.suggestFix(
      source: source,
      errorMessage: problems.join('\n'),
      model: model,
    );
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
