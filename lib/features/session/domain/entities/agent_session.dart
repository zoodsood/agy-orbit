import 'agent_state.dart';

/// Exception thrown when attempting to mutate or invoke an agent session
/// with a model ID different from the locked session configuration.
class SessionModelLockException implements Exception {
  final String sessionId;
  final String lockedModelId;
  final String attemptedModelId;

  const SessionModelLockException({
    required this.sessionId,
    required this.lockedModelId,
    required this.attemptedModelId,
  });

  @override
  String toString() =>
      'SessionModelLockException: Session "$sessionId" is locked to model "$lockedModelId". '
      'Attempted execution with mismatched model "$attemptedModelId" is strictly rejected.';
}

/// Represents a persistent Agent session in Antigravity Orbit.
/// Model selection is strictly locked once a session instance is created.
class AgentSession {
  final String id;
  final String name;
  final String modelId; // Locked per session instance, dynamically chosen at setup
  AgentState state;
  final DateTime createdAt;
  DateTime lastActiveAt;
  String? activeTurnId;
  final List<String> activeMcpServers;
  final Map<String, dynamic> metadata;

  AgentSession({
    required this.id,
    required this.name,
    required this.modelId,
    this.state = AgentState.idle,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    this.activeTurnId,
    this.activeMcpServers = const [],
    this.metadata = const {},
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now();

  /// Standard Antigravity Orbit local workspace prefix
  String get localWorkspaceDirectoryName => 'orbit-$id-workspace';

  /// Validates that an attempted turn uses the locked model ID.
  /// Throws [SessionModelLockException] if mismatched.
  void validateModel(String attemptedModelId) {
    if (attemptedModelId != modelId) {
      throw SessionModelLockException(
        sessionId: id,
        lockedModelId: modelId,
        attemptedModelId: attemptedModelId,
      );
    }
  }

  AgentSession copyWith({
    String? name,
    AgentState? state,
    DateTime? lastActiveAt,
    String? activeTurnId,
    List<String>? activeMcpServers,
    Map<String, dynamic>? metadata,
  }) {
    return AgentSession(
      id: id,
      name: name ?? this.name,
      modelId: modelId, // Locked, cannot be mutated
      state: state ?? this.state,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      activeTurnId: activeTurnId ?? this.activeTurnId,
      activeMcpServers: activeMcpServers ?? this.activeMcpServers,
      metadata: metadata ?? this.metadata,
    );
  }

  factory AgentSession.fromJson(Map<String, dynamic> json) {
    return AgentSession(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Agent Session',
      modelId: json['modelId'] as String? ?? 'gemini-4-argon',
      state: AgentState.fromString(json['state'] as String?),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      lastActiveAt: json['lastActiveAt'] != null ? DateTime.parse(json['lastActiveAt'] as String) : null,
      activeTurnId: json['activeTurnId'] as String?,
      activeMcpServers: (json['activeMcpServers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'modelId': modelId,
      'state': state.name,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'activeTurnId': activeTurnId,
      'activeMcpServers': activeMcpServers,
      'metadata': metadata,
      'localWorkspace': localWorkspaceDirectoryName,
    };
  }
}
