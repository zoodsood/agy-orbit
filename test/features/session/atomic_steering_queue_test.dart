import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/features/session/domain/entities/atomic_steering_queue.dart';

void main() {
  group('AtomicSteeringQueue & PreemptionSignal Tests', () {
    late AtomicSteeringQueue queue;

    setUp(() {
      queue = AtomicSteeringQueue();
    });

    tearDown(() {
      queue.dispose();
    });

    test('Enqueues instruction and sorts by priority (immediate > toolBoundary > nextTurn)', () {
      queue.enqueueInstruction('Directive 1 - normal', priority: SteeringPriority.toolBoundary);
      queue.enqueueInstruction('Directive 2 - low', priority: SteeringPriority.nextTurn);
      queue.enqueueInstruction('Directive 3 - critical immediate', priority: SteeringPriority.immediate);

      expect(queue.pendingCount, 3);
      expect(queue.hasPendingPreemption, true);

      // Highest priority should be consumed first (immediate)
      final first = queue.consumeNext();
      expect(first, isNotNull);
      expect(first!.instruction, 'Directive 3 - critical immediate');
      expect(first.priority, SteeringPriority.immediate);
      expect(first.status, PreemptionStatus.preempting);

      // Second should be toolBoundary
      final second = queue.consumeNext();
      expect(second, isNotNull);
      expect(second!.instruction, 'Directive 1 - normal');
      expect(second.priority, SteeringPriority.toolBoundary);

      // Third should be nextTurn
      final third = queue.consumeNext();
      expect(third, isNotNull);
      expect(third!.instruction, 'Directive 2 - low');

      // Now all consumed into preempting
      expect(queue.consumeNext(), isNull);
    });

    test('Acknowledges and completes preemption signals', () {
      final signal = queue.enqueueInstruction('Refactor OAuth only');
      expect(queue.hasPendingPreemption, true);

      final next = queue.consumeNext();
      expect(next!.id, signal.id);

      final ackResult = queue.acknowledge(signal.id);
      expect(ackResult, isTrue);

      final found = queue.allSignals.firstWhere((s) => s.id == signal.id);
      expect(found.status, PreemptionStatus.acknowledged);

      queue.pruneCompleted();
      expect(queue.allSignals.isEmpty, isTrue);
    });

    test('Rejection records metadata reason', () {
      final signal = queue.enqueueInstruction('Impossible instruction');
      queue.reject(signal.id, reason: 'Files already written to disk');

      final found = queue.allSignals.firstWhere((s) => s.id == signal.id);
      expect(found.status, PreemptionStatus.rejected);
      expect(found.metadata['rejectionReason'], 'Files already written to disk');
    });

    test('PreemptionSignal serializes and deserializes accurately with JSON', () {
      final now = DateTime.now();
      final signal = PreemptionSignal(
        id: 'steer-100',
        instruction: 'Halt tool execution',
        priority: SteeringPriority.immediate,
        timestamp: now,
        status: PreemptionStatus.queued,
        metadata: {'tag': 'security'},
      );

      final json = signal.toJson();
      final restored = PreemptionSignal.fromJson(json);

      expect(restored.id, signal.id);
      expect(restored.instruction, signal.instruction);
      expect(restored.priority, SteeringPriority.immediate);
      expect(restored.status, PreemptionStatus.queued);
      expect(restored.metadata['tag'], 'security');
    });
  });
}
