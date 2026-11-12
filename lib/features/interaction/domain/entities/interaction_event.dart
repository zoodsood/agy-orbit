import '../../../session/domain/entities/agent_state.dart';

enum InteractionEventType {
  stateChange,
  thoughtDelta,
  textDelta,
  toolExecution,
  toolOutput,
  diffGenerated,
  browserQaTrace,
  turnComplete,
  error,
}

/// Event streamed from the Interactions API or retrieved from Managed Agents Memory Bank.
/// Includes monotonically increasing sequence ID (seqId) for idempotent deduplication.
class InteractionEvent {
  final String id;
  final int seqId;
  final String sessionId;
  final String turnId;
  final InteractionEventType type;
  final DateTime timestamp;
  final String content;
  final AgentState? targetState;
  final Map<String, dynamic> payload;

  const InteractionEvent({
    required this.id,
    this.seqId = 0,
    required this.sessionId,
    required this.turnId,
    required this.type,
    required this.timestamp,
    required this.content,
    this.targetState,
    this.payload = const {},
  });

  factory InteractionEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'textDelta';
    final type = InteractionEventType.values.firstWhere(
      (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
      orElse: () => InteractionEventType.textDelta,
    );

    return InteractionEvent(
      id: json['id'] as String? ?? 'evt-${DateTime.now().millisecondsSinceEpoch}',
      seqId: json['seqId'] as int? ?? 0,
      sessionId: json['sessionId'] as String? ?? '',
      turnId: json['turnId'] as String? ?? '',
      type: type,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      content: json['content'] as String? ?? '',
      targetState: json['targetState'] != null
          ? AgentState.fromString(json['targetState'] as String)
          : null,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seqId': seqId,
      'sessionId': sessionId,
      'turnId': turnId,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'content': content,
      'targetState': targetState?.name,
      'payload': payload,
    };
  }
}
