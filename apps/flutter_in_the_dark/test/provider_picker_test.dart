import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProviderMode', () {
    test('wire names match the server contract exactly', () {
      // POST /api/admin/provider takes `.name` verbatim, and the server's
      // ProviderMode enum serializes the same way (auto|berget|gemini).
      expect(ProviderMode.values.map((m) => m.name), [
        'auto',
        'berget',
        'gemini',
      ]);
    });

    test('every mode has a label and description', () {
      for (final mode in ProviderMode.values) {
        expect(mode.label, isNotEmpty);
        expect(mode.description, isNotEmpty);
      }
    });
  });

  group('ProviderState.fromJson', () {
    test('parses the GET /api/admin/provider response shape', () {
      final state = ProviderState.fromJson({
        'provider': 'gemini',
        'available': {'berget': true, 'gemini': true},
      });
      expect(state.mode, ProviderMode.gemini);
      expect(state.geminiAvailable, isTrue);
    });

    test('geminiAvailable is false when the server has no API key', () {
      final state = ProviderState.fromJson({
        'provider': 'auto',
        'available': {'berget': true, 'gemini': false},
      });
      expect(state.mode, ProviderMode.auto);
      expect(state.geminiAvailable, isFalse);
    });

    test('defaults to auto when the provider field is missing', () {
      final state = ProviderState.fromJson({
        'available': {'gemini': true},
      });
      expect(state.mode, ProviderMode.auto);
    });

    test('missing available map means Gemini unavailable (safe default)', () {
      // Forcing Gemini without a key 409s; defaulting to unavailable keeps
      // the segment disabled rather than offering a choice that must fail.
      final state = ProviderState.fromJson({'provider': 'berget'});
      expect(state.mode, ProviderMode.berget);
      expect(state.geminiAvailable, isFalse);
    });
  });
}
