/// Tests for the LLM provider fallback chain (llm_providers.dart):
/// FallbackGenerator tries the primary first, falls back on
/// GenerationException, logs the serving provider, and does NOT swallow
/// non-generation errors. Also covers stripCodeFence and the env gating in
/// buildGeneratorFromEnv.
library;

import 'package:flutter_in_the_dark_room_service/llm_providers.dart';
import 'package:test/test.dart';

/// A scripted provider: each entry in [outcomes] is either a string (return
/// it) or an exception (throw it). Records every call so tests can assert
/// which provider was exercised.
class FakeGenerator implements CodeGenerator {
  FakeGenerator(this._name, this.outcomes);

  final String _name;
  final List<Object> outcomes;
  final List<String> calls = [];

  @override
  String get name => _name;

  Object _next(String label) {
    calls.add(label);
    if (outcomes.isEmpty) {
      throw StateError('$_name: no scripted outcome for $label');
    }
    return outcomes.removeAt(0);
  }

  @override
  Future<String> generateCode({
    required String prompt,
    required String model,
    String? reasoningEffort,
  }) async {
    switch (_next('generateCode:$prompt')) {
      case final String s:
        return s;
      case final Exception e:
        throw e;
      default:
        throw StateError('bad scripted outcome');
    }
  }

  @override
  Future<String> suggestFix({
    required String source,
    required String errorMessage,
    required String model,
  }) async {
    switch (_next('suggestFix')) {
      case final String s:
        return s;
      case final Exception e:
        throw e;
      default:
        throw StateError('bad scripted outcome');
    }
  }
}

void main() {
  group('FallbackGenerator', () {
    test('serves from primary when primary succeeds; fallback untouched', () async {
      final primary = FakeGenerator('primary', ['code-from-primary']);
      final fallback = FakeGenerator('fallback', ['code-from-fallback']);
      final chain = FallbackGenerator(primary: primary, fallback: fallback);

      final result = await chain.generateCode(prompt: 'p', model: 'm');

      expect(result, 'code-from-primary');
      expect(primary.calls, ['generateCode:p']);
      expect(fallback.calls, isEmpty);
    });

    test('falls back when primary throws GenerationException', () async {
      final primary = FakeGenerator('primary', [
        GenerationException('primary', 'HTTP 502: bad gateway'),
      ]);
      final fallback = FakeGenerator('fallback', ['code-from-fallback']);
      final chain = FallbackGenerator(primary: primary, fallback: fallback);

      final result = await chain.generateCode(prompt: 'p', model: 'm');

      expect(result, 'code-from-fallback');
      expect(primary.calls, ['generateCode:p']);
      expect(fallback.calls, ['generateCode:p']);
    });

    test('suggestFix falls back the same way', () async {
      final primary = FakeGenerator('primary', [
        GenerationException('primary', 'connect timed out'),
      ]);
      final fallback = FakeGenerator('fallback', ['fixed-code']);
      final chain = FallbackGenerator(primary: primary, fallback: fallback);

      final result = await chain.suggestFix(
        source: 'broken',
        errorMessage: 'err',
        model: 'm',
      );

      expect(result, 'fixed-code');
      expect(fallback.calls, ['suggestFix']);
    });

    test('propagates the fallback failure when both providers fail', () async {
      final primary = FakeGenerator('primary', [
        GenerationException('primary', 'HTTP 503'),
      ]);
      final fallback = FakeGenerator('fallback', [
        GenerationException('fallback', 'HTTP 429 quota'),
      ]);
      final chain = FallbackGenerator(primary: primary, fallback: fallback);

      expect(
        () => chain.generateCode(prompt: 'p', model: 'm'),
        throwsA(
          isA<GenerationException>()
              .having((e) => e.provider, 'provider', 'fallback')
              .having((e) => e.message, 'message', contains('429')),
        ),
      );
    });
  });

  group('stripCodeFence', () {
    test('strips a standard fence', () {
      expect(
        stripCodeFence('Here you go:\n```dart\nvoid main() {}\n```\nDone.'),
        'void main() {}',
      );
    });

    test('returns text unchanged when no start marker', () {
      expect(stripCodeFence('  void main() {}  '), 'void main() {}');
    });

    test('tolerates a missing end marker', () {
      expect(stripCodeFence('```dart\nvoid main() {}'), 'void main() {}');
    });
  });

  group('buildGeneratorFromEnv gating', () {
    test('GEMINI_API_KEY unset → primary only', () {
      final result = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {},
      );
      expect(result.generator, isA<DartServicesGenerator>());
      expect(result.providersDescription, contains('no fallback'));
    });

    test('GEMINI_API_KEY empty → primary only', () {
      final result = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {'GEMINI_API_KEY': ''},
      );
      expect(result.generator, isA<DartServicesGenerator>());
    });

    test('GEMINI_API_KEY set → fallback chain with Gemini', () {
      final result = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {'GEMINI_API_KEY': 'test-key'},
      );
      expect(result.generator, isA<FallbackGenerator>());
      final chain = result.generator as FallbackGenerator;
      expect(chain.primary, isA<DartServicesGenerator>());
      expect(chain.fallback, isA<GeminiGenerator>());
      expect(result.providersDescription, contains('FALLBACK'));
    });

    test('GEMINI_MODEL overrides the fallback model', () {
      final result = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {
          'GEMINI_API_KEY': 'test-key',
          'GEMINI_MODEL': 'gemini-3.6-flash',
        },
      );
      final chain = result.generator as FallbackGenerator;
      expect((chain.fallback as GeminiGenerator).model, 'gemini-3.6-flash');
    });
  });
}
