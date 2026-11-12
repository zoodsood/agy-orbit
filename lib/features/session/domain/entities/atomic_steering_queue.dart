import 'dart:async';

/// Priority of an in-flight agent steering or preemption directive.
enum SteeringPriority {
  /// Interrupt immediately before any further action or execution.
  immediate,

  /// Preempt cleanly at the next tool/command boundary before file mutation.
  toolBoundary,

  /// Queue to be applied as directive context for the next autonomous turn.
  nextTurn,
}

/// Status of a steering preemption signal.
enum PreemptionStatus {
  queued,
  preempting,
  acknowledged,
  rejected,
}

/// An atomic steering or preemption signal sent to an in-flight autonomous agent.
class PreemptionSignal {
  final String id;
  final String instruction;
  final SteeringPriority priority;
  final DateTime timestamp;
  PreemptionStatus status;
  final Map<String, dynamic> metadata;

  PreemptionSignal({
    required this.id,
    required this.instruction,
    this.priority = SteeringPriority.toolBoundary,
    DateTime? timestamp,
    this.status = PreemptionStatus.queued,
    Map<String, dynamic>? metadata,
  })  : timestamp = timestamp ?? DateTime.now(),
        metadata = metadata ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'instruction': instruction,
        'priority': priority.name,
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'metadata': metadata,
      };

  factory PreemptionSignal.fromJson(Map<String, dynamic> json) => PreemptionSignal(
        id: json['id'] as String,
        instruction: json['instruction'] as String,
        priority: SteeringPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => SteeringPriority.toolBoundary,
        ),
        timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : null,
        status: PreemptionStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => PreemptionStatus.queued,
        ),
        metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      );
}

/// Atomic steering queue that coordinates runtime preemption and in-flight nudges.
/// Guarantees that agent loops check for pending directives at safe tool boundaries
/// before mutating filesystem or remote sandbox state.
class AtomicSteeringQueue {
  final List<PreemptionSignal> _queue = [];
  final StreamController<PreemptionSignal> _signalStreamController =
      StreamController<PreemptionSignal>.broadcast();

  /// Stream of all newly enqueued preemption signals.
  Stream<PreemptionSignal> get onSignalEnqueued => _signalStreamController.stream;

  /// Returns total pending signals waiting to be consumed.
  int get pendingCount => _queue.where((s) => s.status == PreemptionStatus.queued).length;

  /// Whether there is any pending preemption signal.
  bool get hasPendingPreemption => _queue.any((s) => s.status == PreemptionStatus.queued);

  /// Enqueues a new steering signal. Sorts by priority (immediate first, then toolBoundary, then nextTurn).
  void enqueue(PreemptionSignal signal) {
    _queue.add(signal);
    _queue.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    _signalStreamController.add(signal);
  }

  /// Convenience helper to enqueue from raw text instruction.
  PreemptionSignal enqueueInstruction(
    String instruction, {
    SteeringPriority priority = SteeringPriority.toolBoundary,
    Map<String, dynamic>? metadata,
  }) {
    final signal = PreemptionSignal(
      id: 'steer-${DateTime.now().millisecondsSinceEpoch}-${_queue.length}',
      instruction: instruction,
      priority: priority,
      metadata: metadata,
    );
    enqueue(signal);
    return signal;
  }

  /// Peeks at the next pending preemption signal without consuming or changing status.
  PreemptionSignal? peek() {
    for (final signal in _queue) {
      if (signal.status == PreemptionStatus.queued) {
        return signal;
      }
    }
    return null;
  }

  /// Consumes and transitions the highest-priority pending signal to `preempting`.
  PreemptionSignal? consumeNext() {
    for (final signal in _queue) {
      if (signal.status == PreemptionStatus.queued) {
        signal.status = PreemptionStatus.preempting;
        return signal;
      }
    }
    return null;
  }

  /// Acknowledges a signal as having been applied by the agent runtime.
  bool acknowledge(String signalId) {
    for (final signal in _queue) {
      if (signal.id == signalId) {
        signal.status = PreemptionStatus.acknowledged;
        return true;
      }
    }
    return false;
  }

  /// Rejects a signal (e.g. if the action is already committed or un-steerable).
  bool reject(String signalId, {String? reason}) {
    for (final signal in _queue) {
      if (signal.id == signalId) {
        signal.status = PreemptionStatus.rejected;
        if (reason != null) {
          signal.metadata['rejectionReason'] = reason;
        }
        return true;
      }
    }
    return false;
  }

  /// Returns all historical signals in the queue.
  List<PreemptionSignal> get allSignals => List.unmodifiable(_queue);

  /// Clears acknowledged and rejected signals, retaining pending ones.
  void pruneCompleted() {
    _queue.removeWhere((s) =>
        s.status == PreemptionStatus.acknowledged ||
        s.status == PreemptionStatus.rejected);
  }

  /// Clears all signals.
  void clear() {
    _queue.clear();
  }

  void dispose() {
    _signalStreamController.close();
  }
}
