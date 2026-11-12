import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/features/environment/data/environment_resource_governor.dart';
import 'package:antigravity_flutter/features/environment/domain/entities/managed_environment.dart';

void main() {
  group('Google Managed Environment & 144-Hour Lifecycle Tests', () {
    test('Calculates 144-hour TTL accurately and marks active environment as reusable', () {
      final now = DateTime.now();
      final env = ManagedEnvironment(
        id: 'env-soc2-active',
        displayName: 'Active Sandbox',
        createdAt: now.subtract(const Duration(hours: 10)),
        lastActiveAt: now.subtract(const Duration(hours: 4)),
      );

      expect(env.isReusable, isTrue);
      expect(env.isExpired, isFalse);
      expect(env.timeRemaining.inHours, equals(139)); // 144 - 4 (with elapsed minutes)
      expect(env.statusLabel, equals('Active & Reusable'));
    });

    test('Identifies expiring soon state when less than 24 hours remain', () {
      final now = DateTime.now();
      final env = ManagedEnvironment(
        id: 'env-expiring',
        displayName: 'Expiring Sandbox',
        lastActiveAt: now.subtract(const Duration(hours: 130)),
      );

      expect(env.isReusable, isTrue);
      expect(env.isExpiringSoon, isTrue);
      expect(env.statusLabel, equals('Expiring Soon'));
      expect(env.timeRemaining.inHours, lessThan(24));
    });

    test('Rejects start conversation and throws EnvironmentRetentionExpiredException when > 144 hours', () {
      final now = DateTime.now();
      final expiredEnv = ManagedEnvironment(
        id: 'env-purged-99',
        displayName: 'Purged Sandbox',
        lastActiveAt: now.subtract(const Duration(hours: 150)), // Past 144 hours!
      );

      expect(expiredEnv.isExpired, isTrue);
      expect(expiredEnv.isReusable, isFalse);
      expect(expiredEnv.timeRemaining, equals(Duration.zero));
      expect(expiredEnv.statusLabel, equals('Expired (Purged)'));

      expect(
        () => expiredEnv.assertCanStartConversation(),
        throwsA(isA<EnvironmentRetentionExpiredException>()),
      );
    });
  });

  group('gVisor Environment Resource Governor Tests', () {
    final governor = EnvironmentResourceGovernor();

    test('Validates resource safety against 80% CPU, 12GB RAM, and 6GB Disk limits', () {
      final safeEnv = ManagedEnvironment(
        id: 'env-safe',
        displayName: 'Safe Sandbox',
        cpuUsagePercent: 35.0, // < 80%
        memoryUsageMb: 4096.0, // 4GB < 12GB
        diskUsageMb: 2048.0, // 2GB < 6GB
      );

      final report = governor.assessEnvironment(safeEnv);
      expect(report.isSafe, isTrue);
      expect(report.isCpuCritical, isFalse);
      expect(report.isMemoryCritical, isFalse);
      expect(report.isDiskCritical, isFalse);
      expect(report.warnings, isEmpty);
    });

    test('Flags critical violation when CPU exceeds 80% or Memory exceeds 12GB', () {
      final overloadedEnv = ManagedEnvironment(
        id: 'env-overloaded',
        displayName: 'High Load Sandbox',
        cpuUsagePercent: 88.5, // > 80%
        memoryUsageMb: 13000.0, // > 12GB
        diskUsageMb: 6500.0, // > 6GB
      );

      final report = governor.assessEnvironment(overloadedEnv);
      expect(report.isSafe, isFalse);
      expect(report.isCpuCritical, isTrue);
      expect(report.isMemoryCritical, isTrue);
      expect(report.isDiskCritical, isTrue);
      expect(report.warnings.length, equals(3));
      expect(report.recommendedMitigations.isNotEmpty, isTrue);
    });

    test('Provides memory-safe flags for Top 20 popular languages and runtimes', () {
      expect(EnvironmentResourceGovernor.supportedLanguages.length, equals(20));
      expect(EnvironmentResourceGovernor.supportedLanguages, contains('Rust'));
      expect(EnvironmentResourceGovernor.supportedLanguages, contains('Go'));
      expect(EnvironmentResourceGovernor.supportedLanguages, contains('Bun'));
      expect(EnvironmentResourceGovernor.supportedLanguages, contains('Elixir / Erlang'));
      expect(EnvironmentResourceGovernor.supportedLanguages, contains('C# / .NET'));

      final allFlags = governor.getSafeEnvironmentVariables();
      expect(allFlags['NODE_OPTIONS'], contains('--max-old-space-size=4096'));
      expect(allFlags['RUSTFLAGS'], contains('codegen-units=1'));
      expect(allFlags['CARGO_BUILD_JOBS'], equals('2'));
      expect(allFlags['GOMEMLIMIT'], contains('4GiB'));
      expect(allFlags['GOMAXPROCS'], equals('2'));
      expect(allFlags['DOTNET_GCHeapHardLimit'], equals('0x100000000'));
      expect(allFlags['ERL_FLAGS'], contains('+MBas aobf'));
      expect(allFlags['BUN_MAX_MEMORY'], equals('4096MB'));
      expect(allFlags['DART_VM_OPTIONS'], contains('--old_gen_heap_size=4096'));
      expect(allFlags['JAVA_TOOL_OPTIONS'], contains('-Xmx4g'));
    });

    test('Suggests task concurrency based on CPU pressure', () {
      expect(governor.suggestConcurrency(30.0), equals(4));
      expect(governor.suggestConcurrency(60.0), equals(2));
      expect(governor.suggestConcurrency(80.0), equals(1));
    });
  });
}
