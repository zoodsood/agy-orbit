import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../../features/environment/data/container_telemetry_service.dart';
import 'gemini_resilience_handler.dart';

enum DecisionQuestionType { noul, choice, score }

class DecisionQuestion {
  final String id;
  final DecisionQuestionType type;
  final String question;
  final List<String>? options;
  final Map<String, String>? rubric;

  const DecisionQuestion({
    required this.id,
    required this.type,
    required this.question,
    this.options,
    this.rubric,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'question': question,
        if (options != null) 'options': options,
        if (rubric != null) 'rubric': rubric,
      };
}

class DecisionAnswer {
  final String id;
  final dynamic value;
  final double probability;
  final double confidence;

  const DecisionAnswer({
    required this.id,
    required this.value,
    required this.probability,
    required this.confidence,
  });

  bool get isYes => value == true || value == 'yes' || (value is num && value >= 0.5);

  factory DecisionAnswer.fromJson(Map<String, dynamic> json) {
    return DecisionAnswer(
      id: json['id'] as String? ?? '',
      value: json['value'] ?? json['answer'],
      probability: (json['probability'] as num?)?.toDouble() ?? 0.5,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Client for the Gemini Decisions API (`POST /v1beta/decisions` with `gemini-decision-1`).
/// Evaluates independent yes/no, single-select, and rubric questions in a single
/// prefill pass with 0 output tokens—ideal for fast triage, routing, and safety gates.
class GeminiDecisionsService {
  static const String defaultModel = 'gemini-decision-1';

  final http.Client httpClient;
  final AppConfig appConfig;
  final GeminiResilienceHandler resilienceHandler;
  final ContainerTelemetryService? telemetryService;

  GeminiDecisionsService({
    required this.httpClient,
    required this.appConfig,
    this.resilienceHandler = const GeminiResilienceHandler(),
    this.telemetryService,
  });

  Future<List<DecisionAnswer>> evaluate({
    required String context,
    required List<DecisionQuestion> questions,
    required String apiKey,
    String model = defaultModel,
  }) async {
    final uri = appConfig.buildControlPlaneUri('decisions');
    final body = {
      'model': model,
      'context': context,
      'questions': questions.map((q) => q.toJson()).toList(),
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
      usage: json['usage'] as Map<String, dynamic>?,
    );

    final rawAnswers = (json['answers'] ?? json['decisions'] ?? const []) as List<dynamic>;
    return rawAnswers
        .map((e) => DecisionAnswer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Pre-flight triage for new threads: determines recommended isolation mode,
  /// complexity tier, and whether sensitive files (auth/secrets/migrations) are involved.
  Future<Map<String, DecisionAnswer>> triageNewThread({
    required String prompt,
    required String apiKey,
  }) async {
    final answers = await evaluate(
      context: prompt,
      apiKey: apiKey,
      questions: const [
        DecisionQuestion(
          id: 'isolation_mode',
          type: DecisionQuestionType.choice,
          question: 'Which branch isolation mode is safest for this task?',
          options: ['gitWorktree', 'directoryIsolation'],
        ),
        DecisionQuestion(
          id: 'high_risk_mutation',
          type: DecisionQuestionType.noul,
          question: 'Does this task modify auth, secrets, or database schemas?',
        ),
        DecisionQuestion(
          id: 'complexity',
          type: DecisionQuestionType.score,
          question: 'Rate task complexity from 1 (trivial edit) to 5 (multi-file architecture).',
          rubric: {
            '1': 'Single-file typo or config tweak',
            '3': 'Multi-file feature or test suite update',
            '5': 'Cross-cutting refactor or new subsystem',
          },
        ),
      ],
    );

    return {for (final a in answers) a.id: a};
  }
}
