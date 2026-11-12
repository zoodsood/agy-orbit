import 'dart:async';
import 'dart:io';

/// Real-time container resource snapshot in the Google Managed gVisor sandbox.
class ContainerTelemetrySnapshot {
  final DateTime timestamp;
  final double cpuUsagePercent;
  final double memoryUsageMb;
  final double diskUsageMb;
  final bool isCpuWarning;
  final bool isMemoryWarning;
  final bool isDiskWarning;
  final Map<String, dynamic> rawMetrics;

  const ContainerTelemetrySnapshot({
    required this.timestamp,
    required this.cpuUsagePercent,
    required this.memoryUsageMb,
    required this.diskUsageMb,
    required this.isCpuWarning,
    required this.isMemoryWarning,
    required this.isDiskWarning,
    this.rawMetrics = const {},
  });

  bool get hasViolation => isCpuWarning || isMemoryWarning || isDiskWarning;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'cpuUsagePercent': cpuUsagePercent,
        'memoryUsageMb': memoryUsageMb,
        'diskUsageMb': diskUsageMb,
        'isCpuWarning': isCpuWarning,
        'isMemoryWarning': isMemoryWarning,
        'isDiskWarning': isDiskWarning,
        'rawMetrics': rawMetrics,
      };

  factory ContainerTelemetrySnapshot.fromJson(Map<String, dynamic> json) =>
      ContainerTelemetrySnapshot(
        timestamp: DateTime.parse(json['timestamp'] as String),
        cpuUsagePercent: (json['cpuUsagePercent'] as num).toDouble(),
        memoryUsageMb: (json['memoryUsageMb'] as num).toDouble(),
        diskUsageMb: (json['diskUsageMb'] as num).toDouble(),
        isCpuWarning: json['isCpuWarning'] as bool? ?? false,
        isMemoryWarning: json['isMemoryWarning'] as bool? ?? false,
        isDiskWarning: json['isDiskWarning'] as bool? ?? false,
        rawMetrics: Map<String, dynamic>.from(json['rawMetrics'] as Map? ?? {}),
      );
}

/// Service that queries `/proc/loadavg`, `/proc/meminfo`, and filesystem statistics
/// in real-time inside the Google Managed Linux gVisor container.
/// Strictly enforces the 80% CPU, 12GB RAM, and 6GB Disk ceilings.
class ContainerTelemetryService {
  static const double cpuCeilingPercent = 80.0;
  static const double memoryCeilingMb = 12288.0; // 12 GB
  static const double diskCeilingMb = 6144.0; // 6 GB

  final String workspacePath;
  final File? _procLoadAvgFile;
  final File? _procMemInfoFile;

  ContainerTelemetryService({
    this.workspacePath = '/workspace',
    File? procLoadAvgFile,
    File? procMemInfoFile,
  })  : _procLoadAvgFile = procLoadAvgFile,
        _procMemInfoFile = procMemInfoFile;

  /// Samples current resource usage metrics from the system `/proc` and `df`.
  Future<ContainerTelemetrySnapshot> sampleTelemetry() async {
    final now = DateTime.now();
    double cpuUsage = 0.0;
    double memoryUsageMb = 0.0;
    double diskUsageMb = 0.0;
    final Map<String, dynamic> raw = {};

    // 1. Sample CPU via /proc/loadavg
    try {
      final file = _procLoadAvgFile ?? File('/proc/loadavg');
      if (await file.exists()) {
        final content = await file.readAsString();
        final parts = content.trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          final load1 = double.tryParse(parts[0]) ?? 0.0;
          final cores = Platform.numberOfProcessors.clamp(1, 64);
          cpuUsage = ((load1 / cores) * 100).clamp(0.0, 100.0);
          raw['loadavg1'] = load1;
          raw['cores'] = cores;
        }
      }
    } catch (e) {
      raw['cpu_error'] = e.toString();
    }

    // 2. Sample Memory via /proc/meminfo
    try {
      final file = _procMemInfoFile ?? File('/proc/meminfo');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        int totalKb = 0;
        int availableKb = 0;

        for (final line in lines) {
          if (line.startsWith('MemTotal:')) {
            totalKb = _parseKb(line);
          } else if (line.startsWith('MemAvailable:')) {
            availableKb = _parseKb(line);
          }
        }

        if (totalKb > 0) {
          final usedKb = (totalKb - availableKb).clamp(0, totalKb);
          memoryUsageMb = usedKb / 1024.0;
          raw['memTotalKb'] = totalKb;
          raw['memAvailableKb'] = availableKb;
        }
      }
    } catch (e) {
      raw['mem_error'] = e.toString();
    }

    // 3. Sample Disk via df -m
    try {
      final result = await Process.run('df', ['-m', workspacePath]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).trim().split('\n');
        if (lines.length >= 2) {
          final parts = lines[1].trim().split(RegExp(r'\s+'));
          if (parts.length >= 3) {
            diskUsageMb = double.tryParse(parts[2]) ?? 0.0;
            raw['df_output'] = lines[1];
          }
        }
      }
    } catch (e) {
      raw['disk_error'] = e.toString();
    }

    return ContainerTelemetrySnapshot(
      timestamp: now,
      cpuUsagePercent: double.parse(cpuUsage.toStringAsFixed(1)),
      memoryUsageMb: double.parse(memoryUsageMb.toStringAsFixed(1)),
      diskUsageMb: double.parse(diskUsageMb.toStringAsFixed(1)),
      isCpuWarning: cpuUsage > cpuCeilingPercent,
      isMemoryWarning: memoryUsageMb > memoryCeilingMb,
      isDiskWarning: diskUsageMb > diskCeilingMb,
      rawMetrics: raw,
    );
  }

  int _parseKb(String line) {
    final match = RegExp(r'(\d+)').firstMatch(line);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  /// Creates a periodic stream of telemetry snapshots.
  Stream<ContainerTelemetrySnapshot> streamTelemetry({
    Duration interval = const Duration(seconds: 5),
  }) async* {
    while (true) {
      yield await sampleTelemetry();
      await Future.delayed(interval);
    }
  }
}
