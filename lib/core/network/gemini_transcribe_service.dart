import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../../features/environment/data/container_telemetry_service.dart';
import 'gemini_resilience_handler.dart';

/// Optional asynchronous audio transcription service (Gemini Transcribe)
/// for hands-free AFK steering nudges. Disabled by default; requires
/// `appConfig.enableVoiceDictation == true`.
class GeminiTranscribeService {
  final http.Client httpClient;
  final AppConfig appConfig;
  final GeminiResilienceHandler resilienceHandler;
  final ContainerTelemetryService? telemetryService;

  GeminiTranscribeService({
    required this.httpClient,
    required this.appConfig,
    this.resilienceHandler = const GeminiResilienceHandler(),
    this.telemetryService,
  });

  /// Transcribes an async audio clip (e.g. WAV/AAC/OGG) into a concise steering
  /// directive using Gemini multimodal `generateContent`.
  Future<String> transcribeSteeringAudio({
    required List<int> audioBytes,
    required String mimeType,
    required String apiKey,
    String model = 'gemini-2.5-flash',
  }) async {
    if (!appConfig.enableVoiceDictation) {
      throw StateError(
        'Voice dictation is disabled. Enable it in Settings -> Voice Dictation to transcribe audio.',
      );
    }

    final cleanModel = model.startsWith('models/') ? model.substring(7) : model;
    final uri = appConfig.buildControlPlaneUri('models/$cleanModel:generateContent');

    final body = {
      'contents': [
        {
          'parts': [
            {
              'text': 'Transcribe this developer voice note verbatim as a concise coding steering instruction. Output only the transcribed text.',
            },
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(audioBytes),
              },
            },
          ],
        },
      ],
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
    telemetryService?.recordApiResponseMetadata(
      response.headers,
      usage: json['usageMetadata'] as Map<String, dynamic>?,
    );

    final candidates = json['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) return '';
    final parts = (candidates.first['content']?['parts'] as List<dynamic>?) ?? const [];
    return parts.map((p) => p['text'] as String? ?? '').join().trim();
  }
}
