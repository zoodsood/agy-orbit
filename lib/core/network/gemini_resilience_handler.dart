import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Base exception for all Google Gemini API communication errors.
class GeminiApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;

  const GeminiApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'GeminiApiException (HTTP ${statusCode ?? "N/A"}): $message';
}

/// Thrown when Google Gemini API returns HTTP 403 Permission Denied or PERMISSION_DENIED status.
/// Tailored for individual developers using Google AI Studio API keys (no Google Cloud / Vertex AI overhead).
class GeminiPermissionDeniedException extends GeminiApiException {
  final List<String> possibleCauses;
  final List<String> resolutionSteps;

  const GeminiPermissionDeniedException({
    required String message,
    int statusCode = 403,
    String? details,
    this.possibleCauses = const [
      'The Gemini API key is invalid, expired, or revoked.',
      'The API key was copied incorrectly or contains extraneous whitespace.',
      'The Google AI Studio account associated with the key has been restricted or rate-blocked.',
      'Network egress proxy blocked the connection to generativelanguage.googleapis.com.',
    ],
    this.resolutionSteps = const [
      'Get a fresh Gemini API key directly from Google AI Studio: https://aistudio.google.com/app/apikey',
      'Paste your key in Orbit Settings -> GEMINI_API_KEY (BYOK).',
      'Ensure the active network allowlist includes "*" or "generativelanguage.googleapis.com".',
    ],
  }) : super(message, statusCode: statusCode, details: details);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('GeminiPermissionDeniedException (HTTP $statusCode): $message');
    if (details != null && details!.isNotEmpty) {
      buffer.writeln('Details: $details');
    }
    buffer.writeln('Possible Causes:');
    for (final cause in possibleCauses) {
      buffer.writeln('  • $cause');
    }
    buffer.writeln('Actionable Resolution:');
    for (final step in resolutionSteps) {
      buffer.writeln('  -> $step');
    }
    return buffer.toString();
  }
}

/// Thrown when Google Gemini API returns HTTP 429 Quota Exceeded / Rate Limited.
class GeminiQuotaExceededException extends GeminiApiException {
  final Duration? retryAfter;

  const GeminiQuotaExceededException({
    required String message,
    int statusCode = 429,
    this.retryAfter,
  }) : super(message, statusCode: statusCode);
}

/// Thrown when network drops, DNS fails, or connection times out.
class GeminiNetworkException extends GeminiApiException {
  final bool isTimeout;
  final bool isSocketError;

  const GeminiNetworkException({
    required String message,
    this.isTimeout = false,
    this.isSocketError = false,
  }) : super(message);
}

/// Robust resilience handler for Gemini API requests.
/// Implements exponential backoff with jitter for transient errors,
/// while providing immediate diagnostics on fatal permission failures.
class GeminiResilienceHandler {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffFactor;

  const GeminiResilienceHandler({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffFactor = 2.0,
  });

  /// Executes an HTTP call with automatic retry on transient network errors
  /// and intelligent diagnosis on Permission Denied (HTTP 403).
  Future<http.Response> executeWithRetry(
    Future<http.Response> Function() requestFn, {
    int? customMaxRetries,
  }) async {
    final effectiveRetries = customMaxRetries ?? maxRetries;
    int attempt = 0;
    Duration currentDelay = initialDelay;
    final random = Random();

    while (true) {
      attempt++;
      try {
        final response = await requestFn();

        // Check HTTP status codes
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        // Fatal Permission Denied (HTTP 403 / 401) - Do not retry
        if (response.statusCode == 403 || response.statusCode == 401) {
          final extracted = _extractErrorMessage(response.body);
          throw GeminiPermissionDeniedException(
            message: extracted.message,
            statusCode: response.statusCode,
            details: extracted.details,
          );
        }

        // Rate limiting (HTTP 429) or transient server errors (HTTP 500, 502, 503, 504)
        if (response.statusCode == 429 || response.statusCode >= 500) {
          if (attempt >= effectiveRetries) {
            if (response.statusCode == 429) {
              throw GeminiQuotaExceededException(
                message: 'Gemini API rate limit or quota exceeded after $attempt attempts.',
                statusCode: response.statusCode,
              );
            }
            throw GeminiApiException(
              'Gemini API server error (HTTP ${response.statusCode}) after $attempt attempts.',
              statusCode: response.statusCode,
              details: response.body,
            );
          }
          // Backoff with jitter
          final jitterMs = random.nextInt(200);
          await Future.delayed(currentDelay + Duration(milliseconds: jitterMs));
          currentDelay = Duration(milliseconds: (currentDelay.inMilliseconds * backoffFactor).round());
          continue;
        }

        // Other client errors (4xx) - throw without retry
        throw GeminiApiException(
          'Gemini API client error: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          details: response.body,
        );
      } on GeminiApiException {
        rethrow;
      } on SocketException catch (e) {
        if (attempt >= effectiveRetries) {
          throw GeminiNetworkException(
            message: 'Network socket connection failed after $attempt attempts: ${e.message}',
            isSocketError: true,
          );
        }
        await Future.delayed(currentDelay);
        currentDelay = Duration(milliseconds: (currentDelay.inMilliseconds * backoffFactor).round());
      } on TimeoutException catch (e) {
        if (attempt >= effectiveRetries) {
          throw GeminiNetworkException(
            message: 'Gemini API request timed out after $attempt attempts: ${e.message}',
            isTimeout: true,
          );
        }
        await Future.delayed(currentDelay);
        currentDelay = Duration(milliseconds: (currentDelay.inMilliseconds * backoffFactor).round());
      } catch (e) {
        if (attempt >= effectiveRetries) {
          throw GeminiNetworkException(
            message: 'Unexpected network exception communicating with Gemini API: $e',
          );
        }
        await Future.delayed(currentDelay);
        currentDelay = Duration(milliseconds: (currentDelay.inMilliseconds * backoffFactor).round());
      }
    }
  }

  /// Parses error payloads from Google Gemini JSON responses.
  ({String message, String? details}) _extractErrorMessage(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      if (json.containsKey('error')) {
        final errorObj = json['error'] as Map<String, dynamic>;
        final msg = errorObj['message'] as String? ?? 'Access Denied';
        final status = errorObj['status'] as String? ?? '';
        return (message: msg, details: 'Gemini API Status: $status');
      }
    } catch (_) {}
    return (message: 'Permission denied connecting to Google Gemini API.', details: responseBody);
  }
}
