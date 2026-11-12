import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/features/heartbeat/data/heartbeat_scheduler.dart';

void main() {
  group('OpenClaw-Style Heartbeat Scheduler Tests', () {
    test('Initializes with 2h Keepalive Ping and 5m gVisor Watchdog', () {
      final scheduler = HeartbeatScheduler();
      expect(scheduler.isRunning, isFalse);
      expect(scheduler.tasks.length, equals(2));

      final keepalive = scheduler.tasks.firstWhere((t) => t.id == 'task-keepalive');
      expect(keepalive.name, contains('Keepalive Ping'));
      expect(keepalive.interval, equals(const Duration(hours: 2)));

      final watchdog = scheduler.tasks.firstWhere((t) => t.id == 'task-resource-guard');
      expect(watchdog.name, contains('Watchdog'));
      expect(watchdog.interval, equals(const Duration(minutes: 5)));
      expect(watchdog.isEnabled, isTrue);

      // Verify boilerplate tasks (Playwright/Static Analysis) were eliminated
      expect(scheduler.tasks.any((t) => t.id == 'task-analysis'), isFalse);
      expect(scheduler.tasks.any((t) => t.id == 'task-test-sweep'), isFalse);
    });

    test('Starts and stops heartbeat engine cleanly', () {
      final scheduler = HeartbeatScheduler();
      scheduler.start();
      expect(scheduler.isRunning, isTrue);
      expect(scheduler.pulseLogs.isNotEmpty, isTrue);
      expect(scheduler.pulseLogs.first.message, contains('started'));

      scheduler.stop();
      expect(scheduler.isRunning, isFalse);
      expect(scheduler.pulseLogs.first.message, contains('paused'));
    });

    test('Executes scheduled keepalive ping and records telemetry pulse', () async {
      final scheduler = HeartbeatScheduler();
      await scheduler.runTaskNow('task-keepalive');

      final task = scheduler.tasks.firstWhere((t) => t.id == 'task-keepalive');
      expect(task.status, equals('Passed'));
      expect(task.lastRun, isNotNull);

      expect(scheduler.pulseLogs.any((l) => l.taskId == 'task-keepalive'), isTrue);
      final log = scheduler.pulseLogs.firstWhere((l) => l.taskId == 'task-keepalive');
      expect(log.success, isTrue);
      expect(log.message, contains('exit code 0'));
    });

    test('Toggles scheduled watchdog task state', () {
      final scheduler = HeartbeatScheduler();
      final task = scheduler.tasks.firstWhere((t) => t.id == 'task-resource-guard');
      expect(task.isEnabled, isTrue);

      scheduler.toggleTask('task-resource-guard', false);
      expect(task.isEnabled, isFalse);
    });
  });
}
