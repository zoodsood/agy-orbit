import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/network/gemini_resilience_handler.dart';
import '../../environment/data/container_telemetry_service.dart';
import '../../manifest/data/mcp_config_generator.dart';
import '../../manifest/domain/entities/agent_manifest.dart';
import '../../session/domain/entities/agent_state.dart';
import '../domain/entities/interaction_event.dart';

/// Parsed result from `POST /v1beta/interactions` or `GET /v1beta/interactions/{id}`.
class InteractionResult {
  final String id;
  final String status;
  final List<Map<String, dynamic>> outputs;
  final Map<String, dynamic> usage;

  const InteractionResult({
    required this.id,
    required this.status,
    this.outputs = const [],
    this.usage = const {},
  });

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get requiresAction => status == 'requires_action';
  bool get isFailed => status == 'failed' || status == 'cancelled';

  int get cachedTokens => (usage['total_cached_tokens'] as num?)?.toInt() ?? 0;

  String get textOutput {
    final buffer = StringBuffer();
    for (final out in outputs) {
      final type = out['type'] as String?;
      if (type == 'text' || type == 'model_output') {
        final text = out['text'] as String? ?? out['content'] as String? ?? '';
        if (text.isNotEmpty) buffer.writeln(text);
      }
    }
    return buffer.toString().trim();
  }

  factory InteractionResult.fromJson(Map<String, dynamic> json) {
    final rawOutputs = json['outputs'] as List<dynamic>? ?? const [];
    return InteractionResult(
      id: json['id'] as String? ??
          json['interactionId'] as String? ??
          json['turnId'] as String? ??
          'turn-${DateTime.now().millisecondsSinceEpoch}',
      status: json['status'] as String? ?? 'in_progress',
      outputs: rawOutputs.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      usage: Map<String, dynamic>.from(json['usage'] as Map? ?? const {}),
    );
  }
}

/// Data Plane Service interacting with Google Gemini Interactions API (`/v1beta/interactions`).
/// Supports stateful branching (`previous_interaction_id`), async AFK background runs
/// (`background=true`), built-in grounding tools, and rate-limit/cache telemetry.
class DataPlaneService {
  final http.Client httpClient;
  final AppConfig appConfig;
  final GeminiResilienceHandler resilienceHandler;
  final ContainerTelemetryService? telemetryService;

  DataPlaneService({
    required this.httpClient,
    required this.appConfig,
    this.resilienceHandler = const GeminiResilienceHandler(),
    this.telemetryService,
  });

  /// Starts a turn via `POST /v1beta/interactions` and returns its server-assigned ID.
  Future<String> startInteraction({
    required String sessionId,
    required dynamic input,
    required String apiKey,
    String? model,
    String? agent,
    String? previousInteractionId,
    String? systemInstruction,
    bool background = false,
    bool enableGoogleSearch = false,
    bool enableUrlContext = false,
    AgentManifest? manifest,
    List<Map<String, dynamic>>? extraTools,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? generationConfig,
    String? prompt,
  }) async {
    final result = await createInteraction(
      sessionId: sessionId,
      input: input ?? prompt ?? '',
      apiKey: apiKey,
      model: model,
      agent: agent,
      previousInteractionId: previousInteractionId,
      systemInstruction: systemInstruction,
      background: background,
      enableGoogleSearch: enableGoogleSearch,
      enableUrlContext: enableUrlContext,
      manifest: manifest,
      extraTools: extraTools,
      responseFormat: responseFormat,
      generationConfig: generationConfig,
    );
    return result.id;
  }

  /// Creates an interaction via `POST /v1beta/interactions` and returns the full
  /// [InteractionResult] including `status`, `outputs`, and `usage`.
  Future<InteractionResult> createInteraction({
    required String sessionId,
    required dynamic input,
    required String apiKey,
    String? model,
    String? agent,
    String? previousInteractionId,
    String? systemInstruction,
    bool background = false,
    bool enableGoogleSearch = false,
    bool enableUrlContext = false,
    AgentManifest? manifest,
    List<Map<String, dynamic>>? extraTools,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? generationConfig,
  }) async {
    final uri = appConfig.buildDataPlaneUri('interactions');

    final tools = <Map<String, dynamic>>[
      if (enableGoogleSearch) const {'type': 'google_search'},
      if (enableUrlContext) const {'type': 'url_context'},
      if (manifest != null) ...McpConfigGenerator.generateInteractionsTools(manifest),
      ...?extraTools,
    ];

    final body = <String, dynamic>{
      if (agent != null) 'agent': agent else 'model': model ?? 'gemini-2.5-flash',
      'input': input,
      if (previousInteractionId != null) 'previous_interaction_id': previousInteractionId,
      if (systemInstruction != null && systemInstruction.isNotEmpty)
        'system_instruction': systemInstruction,
      if (background) 'background': true,
      if (tools.isNotEmpty) 'tools': tools,
      if (responseFormat != null) 'response_format': responseFormat,
      if (generationConfig != null) 'generation_config': generationConfig,
    };

    final response = await resilienceHandler.executeWithRetry(() => httpClient
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode(body),
        )
        .timeout(Duration(seconds: appConfig.requestTimeoutSeconds)));

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final result = InteractionResult.fromJson(json);
    telemetryService?.recordApiResponseMetadata(response.headers, usage: result.usage);
    return result;
  }

  /// Polls an asynchronous background interaction via `GET /v1beta/interactions/{id}`.
  Future<InteractionResult> getInteraction({
    required String interactionId,
    required String apiKey,
  }) async {
    final uri = appConfig.buildDataPlaneUri('interactions/$interactionId');
    final response = await resilienceHandler.executeWithRetry(() => httpClient
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'x-goog-api-key': apiKey,
          },
        )
        .timeout(Duration(seconds: appConfig.requestTimeoutSeconds)));

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final result = InteractionResult.fromJson(json);
    telemetryService?.recordApiResponseMetadata(response.headers, usage: result.usage);
    return result;
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
