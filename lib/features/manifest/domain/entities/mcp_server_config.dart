/// Configuration for a Model Context Protocol (MCP) server attached to an agent.
class McpServerConfig {
  final String name;
  final String command;
  final List<String> args;
  final Map<String, String> env;
  final String transport; // stdio, sse, http, etc.
  final String? url;
  final List<String> autoApprovedTools;

  const McpServerConfig({
    required this.name,
    this.command = '',
    this.args = const [],
    this.env = const {},
    this.transport = 'stdio',
    this.url,
    this.autoApprovedTools = const [],
  });

  factory McpServerConfig.fromMap(Map<dynamic, dynamic> map) {
    final rawUrl = map['url']?.toString();
    final rawTransport = map['transport']?.toString() ?? (rawUrl != null ? 'sse' : 'stdio');
    return McpServerConfig(
      name: map['name']?.toString() ?? 'unnamed-mcp',
      command: map['command']?.toString() ?? '',
      args: (map['args'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      env: (map['env'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
      transport: rawTransport,
      url: rawUrl,
      autoApprovedTools:
          (map['autoApprovedTools'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (command.isNotEmpty) 'command': command,
      if (args.isNotEmpty) 'args': args,
      if (env.isNotEmpty) 'env': env,
      'transport': transport,
      if (url != null) 'url': url,
      'autoApprovedTools': autoApprovedTools,
    };
  }

  /// Transforms into Managed Agents API control-plane payload schema.
  Map<String, dynamic> toControlPlanePayload() {
    return {
      'mcpServer': {
        'identifier': name,
        'launchConfiguration': {
          if (command.isNotEmpty) 'command': command,
          if (args.isNotEmpty) 'arguments': args,
          if (env.isNotEmpty) 'environmentVariables': env,
          if (url != null) 'url': url,
        },
        'protocolTransport': transport,
        'securityPolicy': {
          'allowUnrestrictedEgress': true,
          'autoApprovedCapabilities': autoApprovedTools,
        },
      },
    };
  }
}
