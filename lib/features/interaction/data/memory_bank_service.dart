import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../domain/entities/interaction_event.dart';

/// Service interfacing with Managed Agents Memory Bank for remote session continuity.
/// Eliminates local database reliance and enables seamless mobile/desktop cross-resumption.
/// Includes idempotent event deduplication and mobile lifecycle stream management.
class MemoryBankService {
  final http.Client httpClient;
  final AppConfig appConfig;
  final Set<String> _seenEventIds = <String>{};
  int _lastSeenSeqId = -1;
  String? _cachedLastTurnId;
  bool _isBackgrounded = false;

  MemoryBankService({
    required this.httpClient,
    required this.appConfig,
  });

  /// The highest observed sequence ID received by the client.
  int get lastSeenSeqId => _lastSeenSeqId;

  /// Whether the client is currently paused / backgrounded.
  bool get isBackgrounded => _isBackgrounded;

  /// Cached last turn ID saved before backgrounding.
  String? get cachedLastTurnId => _cachedLastTurnId;

  /// Clears local deduplication cache (e.g., when switching active sessions).
  void resetDeduplication() {
    _seenEventIds.clear();
    _lastSeenSeqId = -1;
    _cachedLastTurnId = null;
  }

  /// Filters an incoming list of interaction events through the idempotent deduplication set
  /// and sequence filter, returning only newly observed events in sequential order.
  List<InteractionEvent> deduplicateEvents(List<InteractionEvent> incoming) {
    final List<InteractionEvent> freshEvents = [];
    for (final event in incoming) {
      if (_seenEventIds.add(event.id)) {
        if (event.seqId > _lastSeenSeqId) {
          _lastSeenSeqId = event.seqId;
        }
        freshEvents.add(event);
      }
    }
    return freshEvents;
  }

  /// Invoked when the application transitions to background (`AppLifecycleState.paused`).
  /// Saves the last turn ID, stops active polling/socket connections, and marks backgrounded.
  void handleAppPaused(String? currentTurnId) {
    _cachedLastTurnId = currentTurnId;
    _isBackgrounded = true;
  }

  /// Invoked when the application resumes (`AppLifecycleState.resumed`).
  /// Hydrates all intermediate progress via [fetchDeltaSince] without battery drain.
  Future<List<InteractionEvent>> handleAppResumed({
    required String sessionId,
    required String apiKey,
    DateTime? sinceTimestamp,
  }) async {
    _isBackgrounded = false;
    if (_cachedLastTurnId == null) {
      return fetchSessionTimeline(sessionId: sessionId, apiKey: apiKey);
    }
    return fetchDeltaSince(
      sessionId: sessionId,
      lastTurnId: _cachedLastTurnId!,
      apiKey: apiKey,
      sinceTimestamp: sinceTimestamp,
    );
  }

  /// Fetches the full interaction history for a given session.
  Future<List<InteractionEvent>> fetchSessionTimeline({
    required String sessionId,
    required String apiKey,
  }) async {
    final uri = appConfig.buildMemoryBankUri(
      'memoryBanks/sessions/$sessionId/timeline',
      queryParameters: {'key': apiKey},
    );

    final response = await httpClient.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(Duration(seconds: appConfig.requestTimeoutSeconds));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final events = (json['events'] as List<dynamic>? ?? [])
          .map((e) => InteractionEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return deduplicateEvents(events);
    } else {
      throw Exception('Memory Bank error: HTTP ${response.statusCode} - ${response.body}');
    }
  }

  /// Fetches only the delta events that occurred since the client was last active.
  /// Crucial for mobile background recovery and reconnection after connection drops.
  Future<List<InteractionEvent>> fetchDeltaSince({
    required String sessionId,
    required String lastTurnId,
    required String apiKey,
    DateTime? sinceTimestamp,
  }) async {
    final queryParams = {
      'key': apiKey,
      'sinceTurnId': lastTurnId,
      if (sinceTimestamp != null) 'sinceTime': sinceTimestamp.toIso8601String(),
    };

    final uri = appConfig.buildMemoryBankUri(
      'memoryBanks/sessions/$sessionId/delta',
      queryParameters: queryParams,
    );

    final response = await httpClient.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(Duration(seconds: appConfig.requestTimeoutSeconds));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final events = (json['deltaEvents'] as List<dynamic>? ?? [])
          .map((e) => InteractionEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return deduplicateEvents(events);
    } else {
      throw Exception('Failed to fetch delta from Memory Bank: HTTP ${response.statusCode}');
    }
  }

  /// Commits a local client state checkpoint into the remote Memory Bank.
  Future<void> commitCheckpoint({
    required String sessionId,
    required String turnId,
    required String apiKey,
    required Map<String, dynamic> stateSummary,
  }) async {
    final uri = appConfig.buildMemoryBankUri(
      'memoryBanks/sessions/$sessionId/checkpoints',
      queryParameters: {'key': apiKey},
    );

    await httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'turnId': turnId,
        'timestamp': DateTime.now().toIso8601String(),
        'stateSummary': stateSummary,
      }),
    ).timeout(Duration(seconds: appConfig.requestTimeoutSeconds));
  }
}
