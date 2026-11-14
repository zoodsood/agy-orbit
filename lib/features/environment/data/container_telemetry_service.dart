import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/platform/platform_io_stub.dart' if (dart.library.io) 'dart:io';

/// Gemini API rate-limit and token usage snapshot extracted from server response
/// headers (`x-ratelimit-*`, `retry-after`) and `usage` metadata.
class ApiRateLimitSnapshot {
  final int? rpmLimit;
  final int? rpmRemaining;
  final int? tpmLimit;
  final int? tpmRemaining;
  final int? retryAfterSeconds;
  final int inputTokens;
  final int outputTokens;
  final int cachedTokens;
  final DateTime updatedAt;

  const ApiRateLimitSnapshot({
    this.rpmLimit,
    this.rpmRemaining,
    this.tpmLimit,
    this.tpmRemaining,
    this.retryAfterSeconds,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedTokens = 0,
    required this.updatedAt,
  });

  bool get isRateLimited => (retryAfterSeconds ?? 0) > 0 || (rpmRemaining == 0) || (tpmRemaining == 0);

  Map<String, dynamic> toJson() => {
        'rpmLimit': rpmLimit,
        'rpmRemaining': rpmRemaining,
        'tpmLimit': tpmLimit,
        'tpmRemaining': tpmRemaining,
        'retryAfterSeconds': retryAfterSeconds,
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'cachedTokens': cachedTokens,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

/// Real-time container resource snapshot from the remote Google Managed gVisor sandbox,
/// paired with Gemini API rate-limit and token-usage telemetry.
class ContainerTelemetrySnapshot {
  final DateTime timestamp;
  final double cpuUsagePercent;
  final double memoryUsageMb;
  final double diskUsageMb;
  final bool isCpuWarning;
  final bool isMemoryWarning;
  final bool isDiskWarning;
  final String source;
  final ApiRateLimitSnapshot? rateLimits;
  final Map<String, dynamic> rawMetrics;

  const ContainerTelemetrySnapshot({
    required this.timestamp,
    required this.cpuUsagePercent,
    required this.memoryUsageMb,
    required this.diskUsageMb,
    required this.isCpuWarning,
    required this.isMemoryWarning,
    required this.isDiskWarning,
    this.source = 'server',
    this.rateLimits,
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
        'source': source,
        if (rateLimits != null) 'rateLimits': rateLimits!.toJson(),
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
        source: json['source'] as String? ?? 'server',
        rawMetrics: Map<String, dynamic>.from(json['rawMetrics'] as Map? ?? {}),
      );
}

/// Server-side telemetry & rate-limit monitor for the remote Google Managed Linux
/// gVisor sandbox. Never probes the user's local client machine; instead ingests
/// remote sandbox telemetry payloads and Gemini API response rate-limit/usage metadata.
/// Strictly enforces the 80% CPU, 12GB RAM, and 6GB Disk ceilings.
class ContainerTelemetryService {
  static const double cpuCeilingPercent = 80.0;
  static const double memoryCeilingMb = 12288.0; // 12 GB
  static const double diskCeilingMb = 6144.0; // 6 GB

  final String workspacePath;
  final File? _procLoadAvgFile;
  final File? _procMemInfoFile;
  final http.Client? _httpClient;
  final AppConfig? _appConfig;
  final String? Function()? _environmentIdProvider;
  final String? Function()? _apiKeyProvider;

  ContainerTelemetrySnapshot? _latestServerSnapshot;
  ApiRateLimitSnapshot? _latestRateLimits;
  int _cumulativeInputTokens = 0;
  int _cumulativeOutputTokens = 0;
  int _cumulativeCachedTokens = 0;

  ContainerTelemetryService({
    this.workspacePath = '/workspace',
    File? procLoadAvgFile,
    File? procMemInfoFile,
    http.Client? httpClient,
    AppConfig? appConfig,
    String? Function()? environmentIdProvider,
    String? Function()? apiKeyProvider,
  })  : _procLoadAvgFile = procLoadAvgFile,
        _procMemInfoFile = procMemInfoFile,
        _httpClient = httpClient,
        _appConfig = appConfig,
        _environmentIdProvider = environmentIdProvider,
        _apiKeyProvider = apiKeyProvider;

  ApiRateLimitSnapshot? get latestRateLimits => _latestRateLimits;

  /// Records server-side sandbox resource metrics delivered via Managed Agents
  /// telemetry events, heartbeats, or control-plane polling.
  ContainerTelemetrySnapshot recordServerTelemetry(Map<String, dynamic> payload) {
    final cpu = ((payload['cpuUsagePercent'] ?? payload['cpu_percent'] ?? 0) as num).toDouble().clamp(0.0, 100.0);
    final mem = ((payload['memoryUsageMb'] ?? payload['memory_mb'] ?? 0) as num).toDouble();
    final disk = ((payload['diskUsageMb'] ?? payload['disk_mb'] ?? 0) as num).toDouble();

    final snapshot = ContainerTelemetrySnapshot(
      timestamp: DateTime.now(),
      cpuUsagePercent: double.parse(cpu.toStringAsFixed(1)),
      memoryUsageMb: double.parse(mem.toStringAsFixed(1)),
      diskUsageMb: double.parse(disk.toStringAsFixed(1)),
      isCpuWarning: cpu > cpuCeilingPercent,
      isMemoryWarning: mem > memoryCeilingMb,
      isDiskWarning: disk > diskCeilingMb,
      source: 'server',
      rateLimits: _latestRateLimits,
      rawMetrics: Map<String, dynamic>.from(payload),
    );
    _latestServerSnapshot = snapshot;
    return snapshot;
  }

  /// Extracts Gemini API rate-limit headers and token usage (`total_cached_tokens`,
  /// `input_tokens`, `output_tokens`) from any API response.
  ApiRateLimitSnapshot recordApiResponseMetadata(
    Map<String, String> headers, {
    Map<String, dynamic>? usage,
  }) {
    final normalized = <String, String>{
      for (final entry in headers.entries) entry.key.toLowerCase(): entry.value,
    };

    if (usage != null) {
      _cumulativeInputTokens += ((usage['input_tokens'] ?? usage['promptTokenCount'] ?? 0) as num).toInt();
      _cumulativeOutputTokens += ((usage['output_tokens'] ?? usage['candidatesTokenCount'] ?? 0) as num).toInt();
      _cumulativeCachedTokens += ((usage['total_cached_tokens'] ?? usage['cachedContentTokenCount'] ?? 0) as num).toInt();
    }

    final snapshot = ApiRateLimitSnapshot(
      rpmLimit: int.tryParse(normalized['x-ratelimit-limit-requests'] ?? ''),
      rpmRemaining: int.tryParse(normalized['x-ratelimit-remaining-requests'] ?? ''),
      tpmLimit: int.tryParse(normalized['x-ratelimit-limit-tokens'] ?? ''),
      tpmRemaining: int.tryParse(normalized['x-ratelimit-remaining-tokens'] ?? ''),
      retryAfterSeconds: int.tryParse(normalized['retry-after'] ?? ''),
      inputTokens: _cumulativeInputTokens,
      outputTokens: _cumulativeOutputTokens,
      cachedTokens: _cumulativeCachedTokens,
      updatedAt: DateTime.now(),
    );
    _latestRateLimits = snapshot;
    return snapshot;
  }

  Future<ContainerTelemetrySnapshot> _fetchRemoteOnce({
    required http.Client httpClient,
    required AppConfig appConfig,
    required String environmentId,
    required String apiKey,
  }) async {
    final uri = appConfig.buildControlPlaneUri('environments/$environmentId/telemetry');
    final response = await httpClient.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'x-goog-api-key': apiKey,
      },
    ).timeout(Duration(seconds: appConfig.requestTimeoutSeconds));

    recordApiResponseMetadata(response.headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return recordServerTelemetry(json);
    }
    throw Exception('Remote telemetry returned HTTP ${response.statusCode}');
  }

  /// Polls remote Managed Environment telemetry from the server-side Control Plane.
  Future<ContainerTelemetrySnapshot> fetchRemoteEnvironmentTelemetry({
    required http.Client httpClient,
    required AppConfig appConfig,
    required String environmentId,
    required String apiKey,
  }) async {
    try {
      return await _fetchRemoteOnce(
        httpClient: httpClient,
        appConfig: appConfig,
        environmentId: environmentId,
        apiKey: apiKey,
      );
    } catch (_) {
      return _latestServerSnapshot ??
          ContainerTelemetrySnapshot(
            timestamp: DateTime.now(),
            cpuUsagePercent: 0.0,
            memoryUsageMb: 0.0,
            diskUsageMb: 0.0,
            isCpuWarning: false,
            isMemoryWarning: false,
            isDiskWarning: false,
            source: 'awaiting_server',
            rateLimits: _latestRateLimits,
            rawMetrics: const {'status': 'awaiting_server_telemetry'},
          );
    }
  }

  /// Returns the latest server-side telemetry snapshot (or parses injected
  /// `/proc` fixtures during unit tests). Never inspects local client hardware.
  Future<ContainerTelemetrySnapshot> sampleTelemetry() async {
    if (_procLoadAvgFile != null || _procMemInfoFile != null) {
      return _sampleInjectedProcFixtures();
    }

    final envId = _environmentIdProvider?.call();
    final apiKey = _apiKeyProvider?.call();
    if (_httpClient != null &&
        _appConfig != null &&
        envId != null &&
        envId.isNotEmpty &&
        apiKey != null &&
        apiKey.isNotEmpty) {
      try {
        return await _fetchRemoteOnce(
          httpClient: _httpClient,
          appConfig: _appConfig,
          environmentId: envId,
          apiKey: apiKey,
        );
      } catch (_) {
        // Fall through to cached server snapshot or awaiting_server
      }
    }

    if (_latestServerSnapshot != null) {
      return ContainerTelemetrySnapshot(
        timestamp: _latestServerSnapshot!.timestamp,
        cpuUsagePercent: _latestServerSnapshot!.cpuUsagePercent,
        memoryUsageMb: _latestServerSnapshot!.memoryUsageMb,
        diskUsageMb: _latestServerSnapshot!.diskUsageMb,
        isCpuWarning: _latestServerSnapshot!.isCpuWarning,
        isMemoryWarning: _latestServerSnapshot!.isMemoryWarning,
        isDiskWarning: _latestServerSnapshot!.isDiskWarning,
        source: 'server',
        rateLimits: _latestRateLimits,
        rawMetrics: _latestServerSnapshot!.rawMetrics,
      );
    }

    return ContainerTelemetrySnapshot(
      timestamp: DateTime.now(),
      cpuUsagePercent: 0.0,
      memoryUsageMb: 0.0,
      diskUsageMb: 0.0,
      isCpuWarning: false,
      isMemoryWarning: false,
      isDiskWarning: false,
      source: 'awaiting_server',
      rateLimits: _latestRateLimits,
      rawMetrics: const {'status': 'awaiting_server_telemetry'},
    );
  }

  Future<ContainerTelemetrySnapshot> _sampleInjectedProcFixtures() async {
    final now = DateTime.now();
    double cpuUsage = 0.0;
    double memoryUsageMb = 0.0;
    final Map<String, dynamic> raw = {};

    if (_procLoadAvgFile != null) {
      try {
        if (await _procLoadAvgFile.exists()) {
          final content = await _procLoadAvgFile.readAsString();
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
    }

    if (_procMemInfoFile != null) {
      try {
        if (await _procMemInfoFile.exists()) {
          final lines = await _procMemInfoFile.readAsLines();
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
    }

    return ContainerTelemetrySnapshot(
      timestamp: now,
      cpuUsagePercent: double.parse(cpuUsage.toStringAsFixed(1)),
      memoryUsageMb: double.parse(memoryUsageMb.toStringAsFixed(1)),
      diskUsageMb: 0.0,
      isCpuWarning: cpuUsage > cpuCeilingPercent,
      isMemoryWarning: memoryUsageMb > memoryCeilingMb,
      isDiskWarning: false,
      source: 'server_proc_fixture',
      rateLimits: _latestRateLimits,
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

  /// Creates a periodic stream of server-side telemetry snapshots.
  Stream<ContainerTelemetrySnapshot> streamTelemetry({
    Duration interval = const Duration(seconds: 5),
  }) async* {
    while (true) {
      yield await sampleTelemetry();
      await Future.delayed(interval);
    }
  }
}
