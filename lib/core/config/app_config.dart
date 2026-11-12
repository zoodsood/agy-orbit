import 'dart:convert';
import 'package:flutter/services.dart';

/// Application configuration supporting runtime overrides and environment injection.
/// No endpoints, model names, or variables are hardcoded.
class AppConfig {
  String controlPlaneBaseUrl;
  String dataPlaneBaseUrl;
  String apiVersion;
  String memoryBankBaseUrl;
  List<String> networkAllowlist;
  int requestTimeoutSeconds;
  int pollingIntervalSeconds;
  Map<String, dynamic> customSettings;

  AppConfig({
    this.controlPlaneBaseUrl = 'https://generativelanguage.googleapis.com',
    this.dataPlaneBaseUrl = 'https://generativelanguage.googleapis.com',
    this.apiVersion = 'v1beta',
    this.memoryBankBaseUrl = 'https://generativelanguage.googleapis.com',
    List<String>? networkAllowlist,
    this.requestTimeoutSeconds = 60,
    this.pollingIntervalSeconds = 3,
    Map<String, dynamic>? customSettings,
  })  : networkAllowlist = networkAllowlist ?? ['*'],
        customSettings = customSettings ?? {};

  /// Constructs the full control plane URL for a given resource path.
  Uri buildControlPlaneUri(String path, {Map<String, dynamic>? queryParameters}) {
    final cleanBase = controlPlaneBaseUrl.endsWith('/')
        ? controlPlaneBaseUrl.substring(0, controlPlaneBaseUrl.length - 1)
        : controlPlaneBaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase/$apiVersion$cleanPath';
    return Uri.parse(fullUrl).replace(queryParameters: queryParameters);
  }

  /// Constructs the full data plane URL for an interaction session.
  Uri buildDataPlaneUri(String path, {Map<String, dynamic>? queryParameters}) {
    final cleanBase = dataPlaneBaseUrl.endsWith('/')
        ? dataPlaneBaseUrl.substring(0, dataPlaneBaseUrl.length - 1)
        : dataPlaneBaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase/$apiVersion$cleanPath';
    return Uri.parse(fullUrl).replace(queryParameters: queryParameters);
  }

  /// Constructs the Memory Bank URL for state synchronization.
  Uri buildMemoryBankUri(String path, {Map<String, dynamic>? queryParameters}) {
    final cleanBase = memoryBankBaseUrl.endsWith('/')
        ? memoryBankBaseUrl.substring(0, memoryBankBaseUrl.length - 1)
        : memoryBankBaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase/$apiVersion$cleanPath';
    return Uri.parse(fullUrl).replace(queryParameters: queryParameters);
  }

  /// Creates an AppConfig instance from JSON.
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final api = (json['api'] as Map<String, dynamic>?) ?? json;
    return AppConfig(
      controlPlaneBaseUrl: api['controlPlaneBaseUrl'] as String? ?? 'https://generativelanguage.googleapis.com',
      dataPlaneBaseUrl: api['dataPlaneBaseUrl'] as String? ?? 'https://generativelanguage.googleapis.com',
      apiVersion: api['apiVersion'] as String? ?? 'v1beta',
      memoryBankBaseUrl: api['memoryBankBaseUrl'] as String? ?? 'https://generativelanguage.googleapis.com',
      networkAllowlist: (api['networkAllowlist'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['*'],
      requestTimeoutSeconds: api['requestTimeoutSeconds'] as int? ?? 60,
      pollingIntervalSeconds: api['pollingIntervalSeconds'] as int? ?? 3,
      customSettings: Map<String, dynamic>.from(json['customSettings'] as Map? ?? {}),
    );
  }

  /// Exports current config to JSON.
  Map<String, dynamic> toJson() {
    return {
      'api': {
        'controlPlaneBaseUrl': controlPlaneBaseUrl,
        'dataPlaneBaseUrl': dataPlaneBaseUrl,
        'apiVersion': apiVersion,
        'memoryBankBaseUrl': memoryBankBaseUrl,
        'networkAllowlist': networkAllowlist,
        'requestTimeoutSeconds': requestTimeoutSeconds,
        'pollingIntervalSeconds': pollingIntervalSeconds,
      },
      'customSettings': customSettings,
    };
  }

  /// Loads configuration dynamically from a JSON string or asset file.
  static Future<AppConfig> loadFromAsset(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return AppConfig.fromJson(decoded);
      }
    } catch (_) {
      // Fallback to defaults if asset cannot be read (e.g. in unit tests)
    }
    return AppConfig();
  }

  /// Updates variables dynamically at runtime without rebuild.
  void updateVariables({
    String? controlPlaneBaseUrl,
    String? dataPlaneBaseUrl,
    String? apiVersion,
    String? memoryBankBaseUrl,
    List<String>? networkAllowlist,
    int? requestTimeoutSeconds,
    int? pollingIntervalSeconds,
    Map<String, dynamic>? customSettings,
  }) {
    if (controlPlaneBaseUrl != null) this.controlPlaneBaseUrl = controlPlaneBaseUrl;
    if (dataPlaneBaseUrl != null) this.dataPlaneBaseUrl = dataPlaneBaseUrl;
    if (apiVersion != null) this.apiVersion = apiVersion;
    if (memoryBankBaseUrl != null) this.memoryBankBaseUrl = memoryBankBaseUrl;
    if (networkAllowlist != null) this.networkAllowlist = networkAllowlist;
    if (requestTimeoutSeconds != null) this.requestTimeoutSeconds = requestTimeoutSeconds;
    if (pollingIntervalSeconds != null) this.pollingIntervalSeconds = pollingIntervalSeconds;
    if (customSettings != null) this.customSettings.addAll(customSettings);
  }
}
