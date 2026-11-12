/// Exception thrown when attempting to reconnect or launch a new conversation turn
/// inside an environment where 144 hours has passed since the last active message.
class EnvironmentRetentionExpiredException implements Exception {
  final String environmentId;
  final Duration elapsedSinceActive;

  const EnvironmentRetentionExpiredException({
    required this.environmentId,
    required this.elapsedSinceActive,
  });

  @override
  String toString() =>
      'EnvironmentRetentionExpiredException: Google Managed Sandbox "$environmentId" '
      'has exceeded the 144-hour technical retention limit (${elapsedSinceActive.inHours}h elapsed). '
      'Remote containers are purged by Google after 144 hours of inactivity. Please provision a fresh environment.';
}

/// Represents a remote Google Managed Agent Linux Sandbox environment.
/// Subject to Google's 144-Hour (6-day) lifecycle limit from the last recorded message,
/// and gVisor container constraints: CPU < 80%, RAM < 12GB, Disk < 6GB.
class ManagedEnvironment {
  final String id;
  final String displayName;
  final DateTime createdAt;
  DateTime lastActiveAt;
  final List<String> linkedSessionIds;
  double cpuUsagePercent; // Hard limit: 80%
  double memoryUsageMb; // Hard limit: 12GB = 12288 MB
  double diskUsageMb; // Hard limit: 6GB = 6144 MB
  final Map<String, dynamic> metadata;

  static const int retentionLimitHours = 144;
  static const double cpuMaxSafePercent = 80.0;
  static const double memoryMaxSafeMb = 12288.0;
  static const double diskMaxSafeMb = 6144.0;

  ManagedEnvironment({
    required this.id,
    required this.displayName,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    List<String>? linkedSessionIds,
    this.cpuUsagePercent = 25.0,
    this.memoryUsageMb = 2048.0,
    this.diskUsageMb = 1024.0,
    Map<String, dynamic>? metadata,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now(),
        linkedSessionIds = linkedSessionIds ?? [],
        metadata = metadata ?? {};

  /// Time elapsed since the last message linked to this environment.
  Duration get elapsedSinceActive => DateTime.now().difference(lastActiveAt);

  /// Time remaining before Google's 144-hour retention threshold expires.
  Duration get timeRemaining {
    final remaining = const Duration(hours: retentionLimitHours) - elapsedSinceActive;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether the environment is within the 144-hour window and safely reusable.
  bool get isReusable => timeRemaining > Duration.zero;

  /// Whether the environment has less than 24 hours remaining before purge.
  bool get isExpiringSoon => isReusable && timeRemaining.inHours < 24;

  /// Whether the environment has expired past 144 hours.
  bool get isExpired => !isReusable;

  /// Human-readable retention status label.
  String get statusLabel {
    if (isExpired) return 'Expired (Purged)';
    if (isExpiringSoon) return 'Expiring Soon';
    return 'Active & Reusable';
  }

  /// Resource safety checks
  bool get isCpuSafe => cpuUsagePercent <= cpuMaxSafePercent;
  bool get isMemorySafe => memoryUsageMb <= memoryMaxSafeMb;
  bool get isDiskSafe => diskUsageMb <= diskMaxSafeMb;
  bool get isResourceSafe => isCpuSafe && isMemorySafe && isDiskSafe;

  /// Validates reusability before starting a conversation.
  /// Throws [EnvironmentRetentionExpiredException] if retention expired.
  void assertCanStartConversation() {
    if (isExpired) {
      throw EnvironmentRetentionExpiredException(
        environmentId: id,
        elapsedSinceActive: elapsedSinceActive,
      );
    }
  }

  /// Updates the last active timestamp when a message is sent.
  void recordActivity() {
    lastActiveAt = DateTime.now();
  }

  ManagedEnvironment copyWith({
    String? displayName,
    DateTime? lastActiveAt,
    List<String>? linkedSessionIds,
    double? cpuUsagePercent,
    double? memoryUsageMb,
    double? diskUsageMb,
    Map<String, dynamic>? metadata,
  }) {
    return ManagedEnvironment(
      id: id,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      linkedSessionIds: linkedSessionIds ?? List.from(this.linkedSessionIds),
      cpuUsagePercent: cpuUsagePercent ?? this.cpuUsagePercent,
      memoryUsageMb: memoryUsageMb ?? this.memoryUsageMb,
      diskUsageMb: diskUsageMb ?? this.diskUsageMb,
      metadata: metadata ?? Map.from(this.metadata),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'linkedSessionIds': linkedSessionIds,
      'cpuUsagePercent': cpuUsagePercent,
      'memoryUsageMb': memoryUsageMb,
      'diskUsageMb': diskUsageMb,
      'timeRemainingSeconds': timeRemaining.inSeconds,
      'isReusable': isReusable,
      'status': statusLabel,
    };
  }

  factory ManagedEnvironment.fromJson(Map<String, dynamic> json) {
    return ManagedEnvironment(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? 'Sandbox Environment',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      lastActiveAt: json['lastActiveAt'] != null ? DateTime.parse(json['lastActiveAt'] as String) : null,
      linkedSessionIds: (json['linkedSessionIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      cpuUsagePercent: (json['cpuUsagePercent'] as num?)?.toDouble() ?? 25.0,
      memoryUsageMb: (json['memoryUsageMb'] as num?)?.toDouble() ?? 2048.0,
      diskUsageMb: (json['diskUsageMb'] as num?)?.toDouble() ?? 1024.0,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}
