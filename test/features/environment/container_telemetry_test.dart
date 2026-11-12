import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/features/environment/data/container_telemetry_service.dart';

void main() {
  group('ContainerTelemetryService Tests', () {
    late Directory tempDir;
    late File mockLoadAvg;
    late File mockMemInfo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('telemetry_test_');
      mockLoadAvg = File('${tempDir.path}/loadavg');
      mockMemInfo = File('${tempDir.path}/meminfo');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Parses healthy /proc metrics safely within gVisor limits', () async {
      await mockLoadAvg.writeAsString('0.45 0.30 0.20 1/120 4021');
      await mockMemInfo.writeAsString('''
MemTotal:       16376668 kB
MemFree:        12000000 kB
MemAvailable:   12000000 kB
Buffers:               0 kB
Cached:          4000000 kB
''');

      final service = ContainerTelemetryService(
        procLoadAvgFile: mockLoadAvg,
        procMemInfoFile: mockMemInfo,
      );

      final snapshot = await service.sampleTelemetry();

      expect(snapshot.isCpuWarning, isFalse);
      expect(snapshot.isMemoryWarning, isFalse);
      expect(snapshot.hasViolation, isFalse);
      // Mem used: (16376668 - 12000000) / 1024 ~= 4274.0 MB
      expect(snapshot.memoryUsageMb, greaterThan(4000));
      expect(snapshot.memoryUsageMb, lessThan(12288));
    });

    test('Detects CPU and Memory ceiling violations in gVisor sandbox', () async {
      // 80 cores equivalent load or high single core load:
      await mockLoadAvg.writeAsString('128.00 110.00 95.00 5/500 9999');
      // High RAM usage exceeding 12GB:
      await mockMemInfo.writeAsString('''
MemTotal:       16376668 kB
MemFree:          100000 kB
MemAvailable:     200000 kB
''');

      final service = ContainerTelemetryService(
        procLoadAvgFile: mockLoadAvg,
        procMemInfoFile: mockMemInfo,
      );

      final snapshot = await service.sampleTelemetry();

      // CPU load should trigger warning (128 / cores * 100 > 80%)
      expect(snapshot.isCpuWarning, isTrue);
      // Memory usage (16376668 - 200000)/1024 ~= 15797 MB > 12288 MB limit
      expect(snapshot.isMemoryWarning, isTrue);
      expect(snapshot.hasViolation, isTrue);
    });

    test('Streams telemetry updates periodically', () async {
      await mockLoadAvg.writeAsString('0.10 0.10 0.10 1/50 1234');
      await mockMemInfo.writeAsString('MemTotal: 8000000 kB\nMemAvailable: 6000000 kB\n');

      final service = ContainerTelemetryService(
        procLoadAvgFile: mockLoadAvg,
        procMemInfoFile: mockMemInfo,
      );

      final stream = service.streamTelemetry(interval: const Duration(milliseconds: 10));
      final firstSnapshot = await stream.first;

      expect(firstSnapshot.timestamp, isNotNull);
      expect(firstSnapshot.memoryUsageMb, greaterThan(0));
    });
  });
}
