/// Represents an autonomous scheduled task executed during periodic heartbeat pulses.
class HeartbeatTask {
  final String id;
  final String name;
  final String description;
  final Duration interval;
  DateTime? lastRun;
  DateTime nextRun;
  bool isEnabled;
  final String command;
  String status;

  HeartbeatTask({
    required this.id,
    required this.name,
    required this.description,
    required this.interval,
    this.lastRun,
    DateTime? nextRun,
    this.isEnabled = true,
    required this.command,
    this.status = 'Idle',
  }) : nextRun = nextRun ?? DateTime.now().add(interval);

  HeartbeatTask copyWith({
    String? name,
    String? description,
    Duration? interval,
    DateTime? lastRun,
    DateTime? nextRun,
    bool? isEnabled,
    String? command,
    String? status,
  }) {
    return HeartbeatTask(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      interval: interval ?? this.interval,
      lastRun: lastRun ?? this.lastRun,
      nextRun: nextRun ?? this.nextRun,
      isEnabled: isEnabled ?? this.isEnabled,
      command: command ?? this.command,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'intervalMinutes': interval.inMinutes,
      'lastRun': lastRun?.toIso8601String(),
      'nextRun': nextRun.toIso8601String(),
      'isEnabled': isEnabled,
      'command': command,
      'status': status,
    };
  }
}

/// A log entry recording the outcome of a heartbeat execution pulse.
class HeartbeatPulseLog {
  final DateTime timestamp;
  final String taskId;
  final String taskName;
  final String message;
  final bool success;

  const HeartbeatPulseLog({
    required this.timestamp,
    required this.taskId,
    required this.taskName,
    required this.message,
    required this.success,
  });
}
