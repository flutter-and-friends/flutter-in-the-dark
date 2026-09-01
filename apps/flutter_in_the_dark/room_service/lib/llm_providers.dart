/// LLM provider abstraction for the generation pipeline.
///
/// The pipeline's LLM need is narrow: `system prompt + user prompt → code
/// text` (a ```dart fence is stripped before return, mirroring dart_services'
/// `cleanCode`). Two providers implement it:
///
///  * [DartServicesGenerator] — the PRIMARY: the local dart_services fork,
///    which fronts Berget.ai (OpenAI-compatible). Unchanged HTTP contract;
///    this is also the only path that can *compile*, so dart_services stays
///    the compile backend regardless of which provider generated the code.
///  * [GeminiGenerator] — the SAFETY NET: calls the Gemini `generateContent`
///    REST API directly, gated on `GEMINI_API_KEY` (same env-var boot pattern
///    as dart_services' `BERGET_REFRESH_TOKEN`).
///
/// [FallbackGenerator] composes them: try Berget-via-dart_services first,
/// fall back to Gemini on failure (timeout, 5xx, connection error), and log
/// which provider served each request.
///
/// Scope note: this is a competition backup, not a multi-LLM framework. The
/// abstraction is deliberately one method pair deep.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:http/http.dart' as http;

/// Thrown when a provider cannot serve a generation request. Carries the
/// provider name so the fallback log line names the failing layer.
class GenerationException implements Exception {
  GenerationException(this.provider, this.message);
  final String provider;
  final String message;
  @override
  String toString() => '[$provider] $message';
}

/// The pipeline's LLM contract: structured chat completion, code text out.
///
/// Both methods return the model's code with any ```dart fence stripped, so
/// the pipeline compiles the result unchanged no matter which provider
/// answered.
abstract class CodeGenerator {
  /// Human-readable provider name for logs (`berget`, `gemini`).
  String get name;

  /// Generate Flutter app source for [prompt]. [model] / [reasoningEffort]
  /// are the admin-picked overrides; a provider that doesn't understand them
  /// maps them onto its own model selection instead.
  Future<String> generateCode({
    required String prompt,
    required String model,
    String? reasoningEffort,
  });

  /// Propose a fixed version of [source] given the compiler's [errorMessage].
  Future<String> suggestFix({
    required String source,
    required String errorMessage,
    required String model,
  });
}

/// Strips a ```dart ... ``` fence from [text], mirroring dart_services'
/// `cleanCode` fallback: if no start marker is present the text is returned
/// as-is (some models omit the fence despite instruction), and a missing end
/// marker yields everything after the start marker.
String stripCodeFence(String text) {
  const startMarker = '```dart\n';
  const endMarker = '```';
  final startIndex = text.indexOf(startMarker);
  if (startIndex == -1) return text.trim();
  final after = text.substring(startIndex + startMarker.length);
  final endIndex = after.indexOf(endMarker);
  return (endIndex == -1 ? after : after.substring(0, endIndex)).trim();
}

/// System prompt for the Gemini fallback. dart_services builds its own from
/// an ALLOWED-PACKAGES list resolved against its pub cache; room_service has
/// no access to that list, so the fallback carries a compact equivalent with
/// the same core constraints (single main.dart, no fake packages, fenced
/// output). Kept deliberately short — the fallback only needs to produce
/// compilable code in the same shape, not reproduce the full DartPad prompt.
const String geminiGenerateSystem = '''
You are an expert Flutter developer. Generate a complete, compilable Flutter
application as a SINGLE main.dart file that satisfies the user's description.

Hard requirements:
- Complete, runnable code — no TODOs, placeholders, or explanations.
- Import only packages that exist: dart:*, package:flutter/*, and package:provider.
  Imports go at the top of the file. Never invent package names.
- Never use Image.asset or local assets. Use Image.network with
  https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg if an
  image is needed.
- No emojis. No "Flutter Demo" text.
- Output ONLY the Dart code, wrapped in a Markdown ```dart``` fence.
''';

const String geminiFixSystem = '''
You will be given an error message in the provided Flutter source code. Fix the
code and return it in its entirety — the same program with the error fixed.
Output ONLY the corrected Dart code, wrapped in a Markdown ```dart``` fence.
''';

/// PRIMARY provider: the local dart_services fork, which fronts Berget.ai.
///
/// The request/response contract is exactly what `Pipeline` already speaks
/// (`POST /api/v3/generateCode` / `suggestFix`, chunked text body with the
/// fence already stripped server-side). Extracted from `Pipeline` unchanged
/// so the fallback wrapper can sit in front of it.
class DartServicesGenerator implements CodeGenerator {
  DartServicesGenerator({required this.backendBase, http.Client? client})
      : _client = client ?? http.Client();

  final String backendBase;
  final http.Client _client;

  @override
  String get name => 'berget (dart_services)';

  @override
  Future<String> generateCode({
    required String prompt,
    required String model,
    String? reasoningEffort,
  }) {
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
        if (reasoningEffort != null) 'reasoning_effort': reasoningEffort,
      });
    return _streamText(request, 'generateCode');
  }

  @override
  Future<String> suggestFix({
    required String source,
    required String errorMessage,
    required String model,
  }) {
    final request = http.Request(
      'POST',
      Uri.parse('$backendBase/api/v3/suggestFix'),
    )
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'appType': 'flutter',
        'errorMessage': errorMessage,
        'line': 0,
        'column': 0,
        'source': source,
        'model': model,
      });
    return _streamText(request, 'suggestFix');
  }

  Future<String> _streamText(http.Request request, String label) async {
    final http.StreamedResponse response;
    try {
      response =
          await _client.send(request).timeout(const Duration(minutes: 3));
    } on TimeoutException {
      throw GenerationException(name, '$label: connect/stream timed out');
    } on io.SocketException catch (e) {
      throw GenerationException(name, '$label: connection failed: $e');
    }
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw GenerationException(
        name,
        '$label HTTP ${response.statusCode}: $body',
      );
    }
    // dart_services strips the fence server-side; the body is the code.
    return response.stream.bytesToString();
  }
}

/// SAFETY NET provider: Google Gemini, called directly with an API key.
///
/// Non-streaming `generateContent` — the pipeline accumulates the whole body
/// anyway, and one fewer moving part matters more than incremental display in
/// a fallback. The model is chosen by `GEMINI_MODEL` (default
/// `gemini-2.5-flash`: fast, cheap, good Flutter code); the Berget-style
/// `model` override from the admin picker does NOT cross providers (a Berget
/// model id like `moonshotai/Kimi-K3` is meaningless to Gemini).
class GeminiGenerator implements CodeGenerator {
  GeminiGenerator({
    required this.apiKey,
    String? model,
    String? apiBase,
    http.Client? client,
  })  : model = (model == null || model.isEmpty) ? defaultModel : model,
        apiBase = (apiBase == null || apiBase.isEmpty)
            ? 'https://generativelanguage.googleapis.com/v1beta'
            : apiBase,
        _client = client ?? http.Client();

  final String apiKey;
  final String model;

  /// Overridable for tests / local fakes; production uses the real API.
  final String apiBase;
  final http.Client _client;

  static const defaultModel = 'gemini-2.5-flash';

  @override
  String get name => 'gemini';

  @override
  Future<String> generateCode({
    required String prompt,
    required String model,
    String? reasoningEffort,
  }) =>
      _generate(system: geminiGenerateSystem, user: prompt);

  @override
  Future<String> suggestFix({
    required String source,
    required String errorMessage,
    required String model,
  }) =>
      _generate(
        system: geminiFixSystem,
        user: 'ERROR MESSAGE: $errorMessage\nSOURCE CODE:\n$source\n',
      );

  Future<String> _generate({
    required String system,
    required String user,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$apiBase/models/$model:generateContent'),
            headers: {
              'x-goog-api-key': apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': system},
                ],
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': user},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(minutes: 3));
    } on TimeoutException {
      throw GenerationException(name, 'generateContent timed out');
    } on io.SocketException catch (e) {
      throw GenerationException(name, 'connection failed: $e');
    }

    if (response.statusCode != 200) {
      throw GenerationException(
        name,
        'generateContent HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List?;
    final content = candidates == null || candidates.isEmpty
        ? null
        : candidates.first as Map<String, dynamic>?;
    final parts =
        (content?['content'] as Map<String, dynamic>?)?['parts'] as List?;
    final text = parts
        ?.map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join();
    if (text == null || text.trim().isEmpty) {
      throw GenerationException(
        name,
        'generateContent returned no text (body: ${response.body})',
      );
    }
    return stripCodeFence(text);
  }
}

/// Operator-selectable provider routing for [FallbackGenerator].
///
///  * [auto] — Berget primary, Gemini fallback on error (boot default; the
///    original competition-backup behaviour).
///  * [berget] — force Berget only; Gemini is never touched (e.g. a Gemini
///    quota incident, or an operator who wants to prove Berget is healthy).
///  * [gemini] — force Gemini only; Berget is never touched (e.g. a Berget
///    outage where even the failed-primary round-trip wastes contestant time).
enum ProviderMode { auto, berget, gemini }

/// Try-primary-then-fallback composition, with a mutable [ProviderMode] so
/// the competition operator can force a provider live without a restart.
///
/// In [ProviderMode.auto] a primary failure (any [GenerationException] —
/// timeout, 5xx, connection error) is logged and retried against the
/// fallback. The log line names the serving provider on every call, so the
/// operator can see which LLM answered.
///
/// [fallback] may be null (GEMINI_API_KEY unset): [ProviderMode.auto] then
/// behaves as primary-only, and selecting [ProviderMode.gemini] is rejected
/// at the route layer (it would only fail on the next generation anyway).
class FallbackGenerator implements CodeGenerator {
  FallbackGenerator({required this.primary, this.fallback});

  final CodeGenerator primary;
  final CodeGenerator? fallback;

  /// Live provider routing. Mutated by the admin route; boot default is
  /// [ProviderMode.auto]. In-memory only — a restart returns to auto, same
  /// lifecycle as the model picker.
  ProviderMode mode = ProviderMode.auto;

  /// Whether a Gemini fallback is configured (API key present). The route
  /// exposes this so the admin UI can disable the "gemini" option.
  bool get geminiAvailable => fallback != null;

  /// Sets [mode], logging the transition. Selecting [ProviderMode.gemini]
  /// with no fallback configured throws [StateError] — the route turns this
  /// into a 409; generation code never sees an impossible mode.
  void setMode(ProviderMode next) {
    if (next == ProviderMode.gemini && fallback == null) {
      throw StateError('gemini provider unavailable: GEMINI_API_KEY not set');
    }
    if (next == mode) return;
    print('[llm] provider mode: ${mode.name} -> ${next.name}');
    mode = next;
  }

  @override
  String get name => 'fallback(${primary.name} → ${fallback?.name ?? 'none'})';

  @override
  Future<String> generateCode({
    required String prompt,
    required String model,
    String? reasoningEffort,
  }) async {
    switch (mode) {
      case ProviderMode.gemini:
        final result = await fallback!.generateCode(
          prompt: prompt,
          model: model,
          reasoningEffort: reasoningEffort,
        );
        print('[llm] generateCode served by ${fallback!.name} (forced)');
        return result;
      case ProviderMode.berget:
        final result = await primary.generateCode(
          prompt: prompt,
          model: model,
          reasoningEffort: reasoningEffort,
        );
        print('[llm] generateCode served by ${primary.name} (forced)');
        return result;
      case ProviderMode.auto:
        return _autoGenerate(prompt, model, reasoningEffort);
    }
  }

  Future<String> _autoGenerate(
    String prompt,
    String model,
    String? reasoningEffort,
  ) async {
    final fb = fallback;
    try {
      final result = await primary.generateCode(
        prompt: prompt,
        model: model,
        reasoningEffort: reasoningEffort,
      );
      print('[llm] generateCode served by ${primary.name}');
      return result;
    } on GenerationException catch (e) {
      if (fb == null) rethrow;
      print('[llm] PRIMARY ${primary.name} FAILED: $e — '
          'falling back to ${fb.name}');
    }
    final result = await fb.generateCode(
      prompt: prompt,
      model: model,
      reasoningEffort: reasoningEffort,
    );
    print('[llm] generateCode served by ${fb.name} (fallback)');
    return result;
  }

  @override
  Future<String> suggestFix({
    required String source,
    required String errorMessage,
    required String model,
  }) async {
    switch (mode) {
      case ProviderMode.gemini:
        final result = await fallback!.suggestFix(
          source: source,
          errorMessage: errorMessage,
          model: model,
        );
        print('[llm] suggestFix served by ${fallback!.name} (forced)');
        return result;
      case ProviderMode.berget:
        final result = await primary.suggestFix(
          source: source,
          errorMessage: errorMessage,
          model: model,
        );
        print('[llm] suggestFix served by ${primary.name} (forced)');
        return result;
      case ProviderMode.auto:
        return _autoSuggestFix(source, errorMessage, model);
    }
  }

  Future<String> _autoSuggestFix(
    String source,
    String errorMessage,
    String model,
  ) async {
    final fb = fallback;
    try {
      final result = await primary.suggestFix(
        source: source,
        errorMessage: errorMessage,
        model: model,
      );
      print('[llm] suggestFix served by ${primary.name}');
      return result;
    } on GenerationException catch (e) {
      if (fb == null) rethrow;
      print('[llm] PRIMARY ${primary.name} FAILED: $e — '
          'falling back to ${fb.name}');
    }
    final result = await fb.suggestFix(
      source: source,
      errorMessage: errorMessage,
      model: model,
    );
    print('[llm] suggestFix served by ${fb.name} (fallback)');
    return result;
  }
}

/// Builds the effective generator from the environment, following the
/// existing env-var boot pattern (`BERGET_REFRESH_TOKEN` in dart_services):
///
///  * dart_services is ALWAYS the primary (it is the room's generation path
///    and the only compile backend; if it is down and no key is set, calls
///    fail exactly as they did before this change).
///  * `GEMINI_API_KEY` unset → chain with no fallback (auto mode degrades to
///    Berget-only, and the admin route rejects forced-gemini with 409).
///    Set → Gemini available as fallback / forcible provider.
///
/// A [FallbackGenerator] is returned in BOTH cases so the admin route can
/// uniformly read/set [FallbackGenerator.mode] without a type check.
///
/// Returns the generator plus a boot log line naming the active providers,
/// so a stale/missing key is visible at startup rather than hiding behind a
/// 'log and skip' branch (W-022).
({FallbackGenerator generator, String providersDescription})
    buildGeneratorFromEnv({
  required String backendBase,
  Map<String, String>? env,
}) {
  final environment = env ?? io.Platform.environment;
  final primary = DartServicesGenerator(backendBase: backendBase);
  final geminiKey = environment['GEMINI_API_KEY'] ?? '';
  if (geminiKey.isEmpty) {
    return (
      generator: FallbackGenerator(primary: primary),
      providersDescription:
          'berget via dart_services (GEMINI_API_KEY not set — no fallback)',
    );
  }
  final gemini = GeminiGenerator(
    apiKey: geminiKey,
    model: environment['GEMINI_MODEL'],
  );
  return (
    generator: FallbackGenerator(primary: primary, fallback: gemini),
    providersDescription:
        'berget via dart_services PRIMARY, gemini (${gemini.model}) FALLBACK',
  );
}
