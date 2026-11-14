import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:antigravity_flutter/core/config/app_config.dart';
import 'package:antigravity_flutter/core/network/gemini_batch_service.dart';
import 'package:antigravity_flutter/core/network/gemini_decisions_service.dart';
import 'package:antigravity_flutter/core/network/gemini_transcribe_service.dart';
import 'package:antigravity_flutter/features/environment/data/container_telemetry_service.dart';
import 'package:antigravity_flutter/features/interaction/data/data_plane_service.dart';
import 'package:antigravity_flutter/features/manifest/data/mcp_config_generator.dart';
import 'package:antigravity_flutter/features/manifest/domain/entities/agent_manifest.dart';
import 'package:antigravity_flutter/features/manifest/domain/entities/mcp_server_config.dart';

void main() {
  group('Gemini API Compliance & Services Tests', () {
    test('DataPlaneService sends official Interactions API payload & x-goog-api-key and updates rate limits', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': 'int_123',
            'status': 'in_progress',
            'outputs': [],
            'usage': {
              'input_tokens': 1200,
              'output_tokens': 0,
              'total_cached_tokens': 900,
            },
          }),
          200,
          headers: {
            'x-ratelimit-limit-requests': '15',
            'x-ratelimit-remaining-requests': '14',
          },
        );
      });

      final telemetry = ContainerTelemetryService();
      final service = DataPlaneService(
        httpClient: client,
        appConfig: AppConfig(),
        telemetryService: telemetry,
      );

      final result = await service.createInteraction(
        sessionId: 'sess-1',
        input: 'Refactor auth module',
        apiKey: 'AIzaTestKey',
        previousInteractionId: 'int_prev',
        background: true,
        enableGoogleSearch: true,
      );

      expect(captured.url.path, equals('/v1beta/interactions'));
      expect(captured.url.queryParameters.containsKey('key'), isFalse);
      expect(captured.headers['x-goog-api-key'], equals('AIzaTestKey'));

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['previous_interaction_id'], equals('int_prev'));
      expect(body['background'], isTrue);
      expect((body['tools'] as List).first['type'], equals('google_search'));

      expect(result.id, equals('int_123'));
      expect(result.cachedTokens, equals(900));
      expect(telemetry.latestRateLimits?.rpmRemaining, equals(14));
      expect(telemetry.latestRateLimits?.cachedTokens, equals(900));
    });

    test('GeminiDecisionsService evaluates triage questions via POST /v1beta/decisions', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'answers': [
              {'id': 'isolation_mode', 'value': 'gitWorktree', 'probability': 0.91, 'confidence': 0.88},
              {'id': 'high_risk_mutation', 'value': true, 'probability': 0.85, 'confidence': 0.82},
              {'id': 'complexity', 'value': 4, 'probability': 0.80, 'confidence': 0.79},
            ],
          }),
          200,
        );
      });

      final service = GeminiDecisionsService(httpClient: client, appConfig: AppConfig());
      final triage = await service.triageNewThread(
        prompt: 'Migrate OAuth2 PKCE tokens and update database schema',
        apiKey: 'AIzaTestKey',
      );

      expect(captured.url.path, equals('/v1beta/decisions'));
      expect(captured.headers['x-goog-api-key'], equals('AIzaTestKey'));
      expect(triage['isolation_mode']?.value, equals('gitWorktree'));
      expect(triage['high_risk_mutation']?.isYes, isTrue);
    });

    test('GeminiBatchService submits inline batch jobs via :batchGenerateContent', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'name': 'batches/batch_abc',
            'metadata': {
              'state': 'JOB_STATE_PENDING',
              'batchStats': {'requestCount': 2},
            },
          }),
          200,
        );
      });

      final service = GeminiBatchService(httpClient: client, appConfig: AppConfig());
      final status = await service.submitInlineBatch(
        displayName: 'trace-audit',
        model: 'gemini-2.5-flash',
        requests: [
          {'contents': [{'parts': [{'text': 'Summarize trace 1'}]}]},
          {'contents': [{'parts': [{'text': 'Summarize trace 2'}]}]},
        ],
        apiKey: 'AIzaTestKey',
      );

      expect(captured.url.path, equals('/v1beta/models/gemini-2.5-flash:batchGenerateContent'));
      expect(captured.headers['x-goog-api-key'], equals('AIzaTestKey'));
      expect(status.name, equals('batches/batch_abc'));
      expect(status.totalRequests, equals(2));
    });

    test('GeminiTranscribeService enforces opt-in enableVoiceDictation setting', () async {
      final config = AppConfig(enableVoiceDictation: false);
      final client = MockClient((request) async => http.Response('{}', 200));
      final service = GeminiTranscribeService(httpClient: client, appConfig: config);

      expect(
        () => service.transcribeSteeringAudio(
          audioBytes: [1, 2, 3],
          mimeType: 'audio/wav',
          apiKey: 'AIzaTestKey',
        ),
        throwsStateError,
      );

      config.updateVariables(enableVoiceDictation: true);
      final enabledClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [{'text': 'Focus on unit tests next'}]
                }
              }
            ]
          }),
          200,
        );
      });
      final enabledService = GeminiTranscribeService(httpClient: enabledClient, appConfig: config);
      final text = await enabledService.transcribeSteeringAudio(
        audioBytes: [1, 2, 3],
        mimeType: 'audio/wav',
        apiKey: 'AIzaTestKey',
      );
      expect(text, equals('Focus on unit tests next'));
    });

    test('ContainerTelemetryService uses server-side snapshots instead of local machine probing', () async {
      final telemetry = ContainerTelemetryService();
      final initial = await telemetry.sampleTelemetry();
      expect(initial.source, equals('awaiting_server'));

      telemetry.recordServerTelemetry({
        'cpuUsagePercent': 42.5,
        'memoryUsageMb': 3072.0,
        'diskUsageMb': 1024.0,
      });

      final serverSnap = await telemetry.sampleTelemetry();
      expect(serverSnap.source, equals('server'));
      expect(serverSnap.cpuUsagePercent, equals(42.5));
      expect(serverSnap.memoryUsageMb, equals(3072.0));
      expect(serverSnap.hasViolation, isFalse);
    });

    test('McpConfigGenerator emits native Interactions API remote mcp_server tools', () {
      const manifest = AgentManifest(
        name: 'Remote MCP Agent',
        model: 'gemini-2.5-flash',
        description: 'Test',
        instructions: 'Test instructions',
        mcpServers: [
          McpServerConfig(
            name: 'remote-github',
            command: '',
            url: 'https://mcp.example.com/sse',
            transport: 'sse',
            autoApprovedTools: ['list_issues'],
          ),
          McpServerConfig(
            name: 'local-stdio',
            command: 'npx',
            transport: 'stdio',
          ),
        ],
      );

      final tools = McpConfigGenerator.generateInteractionsTools(manifest);
      expect(tools.length, equals(1));
      expect(tools.first['type'], equals('mcp_server'));
      expect(tools.first['name'], equals('remote-github'));
      expect(tools.first['url'], equals('https://mcp.example.com/sse'));
      expect(tools.first['allowed_tools'], equals(['list_issues']));
    });
  });
}
