import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../../features/environment/data/container_telemetry_service.dart';
import 'gemini_resilience_handler.dart';

class BatchJobStatus {
  final String name;
  final String state;
  final int totalRequests;
  final int succeededRequests;
  final int failedRequests;
  final List<Map<String, dynamic>> responses;

  const BatchJobStatus({
    required this.name,
    required this.state,
    this.totalRequests = 0,
    this.succeededRequests = 0,
    this.failedRequests = 0,
    this.responses = const [],
  });

  bool get isDone => state == 'JOB_STATE_SUCCEEDED' || state == 'SUCCEEDED' || state == 'completed';
  bool get isFailed => state == 'JOB_STATE_FAILED' || state == 'FAILED' || state == 'failed';

  factory BatchJobStatus.fromJson(Map<String, dynamic> json) {
    final metadata = Map<String, dynamic>.from(json['metadata'] as Map? ?? const {});
    final stats = Map<String, dynamic>.from(metadata['batchStats'] as Map? ?? const {});
    final dest = Map<String, dynamic>.from(json['response'] as Map? ?? const {});
    final inlined = (dest['inlinedResponses']?['inlinedResponses'] as List<dynamic>?) ?? const [];

    return BatchJobStatus(
      name: json['name'] as String? ?? '',
      state: metadata['state'] as String? ?? json['state'] as String? ?? 'JOB_STATE_PENDING',
      totalRequests: (stats['requestCount'] as num?)?.toInt() ?? 0,
      succeededRequests: (stats['successfulRequestCount'] as num?)?.toInt() ?? 0,
      failedRequests: (stats['failedRequestCount'] as num?)?.toInt() ?? 0,
      responses: inlined.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
}

/// Client for the Gemini Batch API (`/v1beta/models/{model}:batchGenerateContent`),
/// providing 50%-cheaper asynchronous execution for non-urgent AFK tasks such as
/// `.orbit.trace` post-mortem summarization and overnight test-suite audits.
class GeminiBatchService {
  final http.Client httpClient;
  final AppConfig appConfig;
  final GeminiResilienceHandler resilienceHandler;
  final ContainerTelemetryService? telemetryService;

  GeminiBatchService({
    required this.httpClient,
    required this.appConfig,
    this.resilienceHandler = const GeminiResilienceHandler(),
    this.telemetryService,
  });

  /// Submits an inline batch of `generateContent` requests under a single batch job.
  Future<BatchJobStatus> submitInlineBatch({
    required String displayName,
    required String model,
    required List<Map<String, dynamic>> requests,
    required String apiKey,
  }) async {
    final cleanModel = model.startsWith('models/') ? model.substring(7) : model;
    final uri = appConfig.buildControlPlaneUri('models/$cleanModel:batchGenerateContent');

    final body = {
      'batch': {
        'display_name': displayName,
        'input_config': {
          'requests': {
            'requests': requests,
          },
        },
      },
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

    telemetryService?.recordApiResponseMetadata(response.headers);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return BatchJobStatus.fromJson(json);
  }

  /// Polls the status of a submitted batch job by its resource name (`batches/...`).
  Future<BatchJobStatus> getBatchStatus({
    required String batchName,
    required String apiKey,
  }) async {
    final cleanName = batchName.startsWith('/') ? batchName.substring(1) : batchName;
    final uri = appConfig.buildControlPlaneUri(cleanName);

    final response = await resilienceHandler.executeWithRetry(() => httpClient
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'x-goog-api-key': apiKey,
          },
        )
        .timeout(Duration(seconds: appConfig.requestTimeoutSeconds)));

    telemetryService?.recordApiResponseMetadata(response.headers);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return BatchJobStatus.fromJson(json);
  }
}
