import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Contract (expected, pending hive-infra confirmation — THE CONTRACT WINS):
///   POST {baseUrl}/api/v3/generateCode
///   body: {"appType":"flutter","prompt":<prompt>,"attachments":[]}
///   → 200 text/plain chunked stream of incremental code text
///     (fence already stripped; client appends chunks).
///   Errors: pre-stream HTTP 4xx/5xx (GenerationException is thrown here);
///   a mid-stream failure is silent truncation (stream just ends).
class GenerationException implements Exception {
  GenerationException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'Generation failed (HTTP $statusCode): $body';
}

/// Self-hosted dart_services generation client.
///
/// Streaming: `package:http` collapses streamed bodies on Flutter web, so
/// this uses browser-native fetch (`package:web`) + ReadableStream reader
/// via dart:js_interop, appending decoded chunks to [onChunk] live.
class DartServicesClient {
  /// Address of the self-hosted dart_services fork (WI-091).
  ///
  /// Compile-time override via `--dart-define=DART_SERVICES_URL=...`.
  /// Otherwise the default depends on how the app is being served:
  ///  - when the app itself is opened on loopback (127.0.0.1/localhost, i.e.
  ///    an agent driving it in-container), the backend is reached on
  ///    `http://127.0.0.1:8300`;
  ///  - when opened from another device (the user's phone/laptop), loopback
  ///    would point at *that* device, so we target the dev host over
  ///    Tailscale/LAN on its published port `4501`.
  static const String _envBaseUrl = String.fromEnvironment('DART_SERVICES_URL');

  static String get defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    final host = web.window.location.hostname;
    if (host == '127.0.0.1' || host == 'localhost') {
      return 'http://127.0.0.1:8300';
    }
    // Same host the page was served from, on the backend's published port.
    return 'http://$host:4501';
  }

  final String baseUrl;

  DartServicesClient({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  /// Streams generated code for [prompt]; invokes [onChunk] with each
  /// decoded text chunk as it arrives. Returns the full accumulated code.
  Future<String> generateCode({
    required String prompt,
    required void Function(String chunk) onChunk,
  }) async {
    final requestInit = web.RequestInit(
      method: 'POST',
      headers: {'Content-Type': 'application/json'}.jsify()! as JSObject,
      body:
          jsonEncode({
            'appType': 'flutter',
            'prompt': prompt,
            'attachments': <String>[],
          }).toJS,
    );

    final web.Response response;
    try {
      response = await web.window
          .fetch('$baseUrl/api/v3/generateCode'.toJS, requestInit)
          .toDart;
    } catch (e) {
      throw GenerationException(-1, 'network error: $e');
    }

    if (!response.ok) {
      final body = await response.text().toDart;
      throw GenerationException(response.status, body.toDart);
    }

    final body = response.body;
    if (body == null) {
      // No stream — nothing to read.
      return '';
    }

    final reader = body.getReader() as web.ReadableStreamDefaultReader;
    final decoder = web.TextDecoder();
    final buffer = StringBuffer();

    while (true) {
      final chunk = await reader.read().toDart;
      if (chunk.done) break;
      final value = chunk.value;
      if (value.isA<JSUint8Array>()) {
        final text = decoder.decode(
          value as JSUint8Array,
          web.TextDecodeOptions(stream: true),
        );
        buffer.write(text);
        onChunk(text);
      }
    }
    // Flush any trailing bytes held by the streaming decoder.
    final tail = decoder.decode();
    if (tail.isNotEmpty) {
      buffer.write(tail);
      onChunk(tail);
    }

    return buffer.toString();
  }
}
