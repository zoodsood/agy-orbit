import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../manifest/data/mcp_config_generator.dart';
import '../../manifest/domain/entities/agent_manifest.dart';

/// Control Plane Service interacting with Google Managed Agents API.
/// Configures remote sandboxes, agent manifests, and MCP server provisioning.
class ControlPlaneService {
  final http.Client httpClient;
  final AppConfig appConfig;

  ControlPlaneService({
    required this.httpClient,
    required this.appConfig,
  });

  /// Deploys an agent configuration manifest to the remote Managed Agents Control Plane.
  Future<Map<String, dynamic>> deployAgent({
    required AgentManifest manifest,
    required String apiKey,
  }) async {
    final payload = McpConfigGenerator.generateControlPlanePayload(
      manifest: manifest,
      appConfig: appConfig,
    );

    final uri = appConfig.buildControlPlaneUri('agents', queryParameters: {'key': apiKey});

    final response = await httpClient
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(Duration(seconds: appConfig.requestTimeoutSeconds));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Failed to deploy agent manifest to Control Plane: HTTP ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Fetches an agent's current configuration from the Control Plane.
  Future<Map<String, dynamic>> getAgent({
    required String agentId,
    required String apiKey,
  }) async {
    final uri = appConfig.buildControlPlaneUri('agents/$agentId', queryParameters: {'key': apiKey});

    final response = await httpClient.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(Duration(seconds: appConfig.requestTimeoutSeconds));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch agent $agentId: HTTP ${response.statusCode}');
    }
  }

  /// Deletes or terminates a remote agent.
  Future<void> terminateAgent({
    required String agentId,
    required String apiKey,
  }) async {
    final uri = appConfig.buildControlPlaneUri('agents/$agentId', queryParameters: {'key': apiKey});
    await httpClient.delete(uri);
  }
}
