import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../session/domain/entities/agent_state.dart';
import '../domain/entities/interaction_event.dart';

/// Data Plane Service interacting with Google Interactions API.
/// Initiates turns and streams real-time execution events.
class DataPlaneService {
  final http.Client httpClient;
  final AppConfig appConfig;

  DataPlaneService({
    required this.httpClient,
    required this.appConfig,
  });

  /// Starts an asynchronous turn in the remote sandbox.
  Future<String> startInteraction({
    required String sessionId,
    required String prompt,
    required String apiKey,
    Map<String, dynamic>? extraContext,
  }) async {
    final uri = appConfig.buildDataPlaneUri('interactions', queryParameters: {'key': apiKey});

    final body = {
      'sessionId': sessionId,
      'input': {
        'prompt': prompt,
        'extraContext': extraContext ?? {},
      },
    };

    final response = await httpClient
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(Duration(seconds: appConfig.requestTimeoutSeconds));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['interactionId'] as String? ??
          json['turnId'] as String? ??
          'turn-${DateTime.now().millisecondsSinceEpoch}';
    } else {
      throw Exception('Interactions API error: HTTP ${response.statusCode} - ${response.body}');
    }
  }

  /// Parses raw SSE or JSON-L lines into a stream of InteractionEvents.
  Stream<InteractionEvent> parseEventStream(Stream<String> lines, String sessionId, String turnId) async* {
    await for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith(':')) continue;

      String jsonText = trimmed;
      if (trimmed.startsWith('data: ')) {
        jsonText = trimmed.substring(6).trim();
      }

      if (jsonText == '[DONE]') {
        yield InteractionEvent(
          id: 'evt-done-${DateTime.now().millisecondsSinceEpoch}',
          sessionId: sessionId,
          turnId: turnId,
          type: InteractionEventType.turnComplete,
          timestamp: DateTime.now(),
          content: 'Turn execution completed.',
          targetState: AgentState.done,
        );
        break;
      }

      try {
        final decoded = jsonDecode(jsonText);
        if (decoded is Map<String, dynamic>) {
          yield InteractionEvent.fromJson({
            ...decoded,
            'sessionId': sessionId,
            'turnId': turnId,
          });
        }
      } catch (_) {
        // Fallback for unstructured log chunks
        yield InteractionEvent(
          id: 'chunk-${DateTime.now().millisecondsSinceEpoch}',
          sessionId: sessionId,
          turnId: turnId,
          type: InteractionEventType.textDelta,
          timestamp: DateTime.now(),
          content: jsonText,
        );
      }
    }
  }
}
