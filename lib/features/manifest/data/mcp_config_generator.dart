import '../../../core/config/app_config.dart';
import '../domain/entities/agent_manifest.dart';

/// Generates Managed Agents API Control-Plane payloads from an AgentManifest.
class McpConfigGenerator {
  /// Converts an AgentManifest and AppConfig into the payload for the Managed Agents API.
  static Map<String, dynamic> generateControlPlanePayload({
    required AgentManifest manifest,
    required AppConfig appConfig,
  }) {
    final mcpServersPayload = manifest.mcpServers.map((server) {
      return {
        'name': server.name,
        if (server.command.isNotEmpty) 'command': server.command,
        if (server.args.isNotEmpty) 'args': server.args,
        if (server.env.isNotEmpty) 'env': server.env,
        'transport': server.transport,
        if (server.url != null) 'url': server.url,
        'autoApprovedTools': server.autoApprovedTools,
      };
    }).toList();

    // Composite instructions combining root manifest + individual skills
    final buffer = StringBuffer(manifest.instructions);
    if (manifest.skills.isNotEmpty) {
      buffer.writeln('\n\n# Loaded Skills & Capabilities');
      for (final skill in manifest.skills) {
        buffer.writeln('\n## ${skill.name}');
        buffer.writeln(skill.instructions);
      }
    }

    final List<Map<String, dynamic>> toolsPayload = [];

    if (manifest.tools.isNotEmpty) {
      for (final tool in manifest.tools) {
        toolsPayload.add(tool.toControlPlaneSchema());
      }
    } else {
      toolsPayload.addAll([
        {'googleSearch': {}},
        {'urlContext': {}},
        {
          'filesystem': {
            'baseDirectory': '/workspace',
            'supportedOperations': [
              'view_file',
              'write_to_file',
              'replace_file_content',
              'list_dir',
              'find_by_name',
            ],
          }
        },
        {
          'codeExecution': {
            'supportedLanguages': ['bash', 'python', 'dart', 'javascript', 'typescript', 'go', 'rust']
          }
        },
        {
          'headlessBrowser': {
            'framework': 'playwright',
            'traceOutputDirectory': '/workspace/output/traces',
            'screenshotOutputDirectory': '/workspace/output/screenshots',
          }
        },
      ]);
    }

    // Append configured MCP servers
    toolsPayload.addAll(mcpServersPayload.map((m) => {'mcpServer': m}));

    return {
      'agent': {
        'displayName': manifest.name,
        'description': manifest.description,
        // Dynamic model string passed through without hardcoding
        'model': manifest.model,
        'systemInstruction': {
          'parts': [
            {'text': buffer.toString()}
          ]
        },
        'tools': toolsPayload,
        'sandboxPolicy': {
          'executionTier': 'managed_linux_soc2',
          'workspacePath': '/workspace',
          'outputPath': manifest.sandboxConfig['workspaceOutputDir'] ?? '/workspace/output',
          'networkEgress': {
            'allowlist': appConfig.networkAllowlist,
          },
        },
      }
    };
  }
}
