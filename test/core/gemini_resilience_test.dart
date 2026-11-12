import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:antigravity_flutter/core/network/gemini_resilience_handler.dart';

void main() {
  group('Gemini Resilience & Error Diagnostics Tests', () {
    test('Throws GeminiPermissionDeniedException on HTTP 403 without retrying', () async {
      int callCount = 0;
      const handler = GeminiResilienceHandler(maxRetries: 3);

      expect(
        () => handler.executeWithRetry(() async {
          callCount++;
          return http.Response(
            '{"error": {"code": 403, "message": "Method not allowed for caller", "status": "PERMISSION_DENIED"}}',
            403,
          );
        }),
        throwsA(isA<GeminiPermissionDeniedException>()),
      );

      // Verify that 403 is not retried (callCount must remain 1)
      await Future.delayed(const Duration(milliseconds: 50));
      expect(callCount, equals(1));
    });

    test('GeminiPermissionDeniedException provides actionable Google AI Studio guidance', () {
      const ex = GeminiPermissionDeniedException(
        message: 'Invalid API key or unauthorized caller',
        statusCode: 403,
      );

      final errorStr = ex.toString();
      expect(errorStr, contains('aistudio.google.com/app/apikey'));
      expect(errorStr, contains('GEMINI_API_KEY (BYOK)'));
      expect(errorStr, contains('Actionable Resolution'));
      // Must NOT contain enterprise Vertex AI or IAM roles
      expect(errorStr.contains('roles/aiplatform.user'), isFalse);
    });

    test('Retries with exponential backoff on transient HTTP 429 rate limit', () async {
      int attempts = 0;
      const handler = GeminiResilienceHandler(
        maxRetries: 3,
        initialDelay: Duration(milliseconds: 10),
      );

      final response = await handler.executeWithRetry(() async {
        attempts++;
        if (attempts < 3) {
          return http.Response('Rate limit exceeded', 429);
        }
        return http.Response('{"models": []}', 200);
      });

      expect(attempts, equals(3));
      expect(response.statusCode, equals(200));
    });
  });
}
