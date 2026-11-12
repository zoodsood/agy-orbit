enum ToolCategory {
  search,
  web,
  filesystem,
  codeExecution,
  browser,
  mcp,
}

/// Represents a declared or built-in tool available to the Antigravity Agent.
class ToolDefinition {
  final String id;
  final String displayName;
  final String description;
  final ToolCategory category;
  final bool isBuiltIn;
  final bool autoApproved;
  final Map<String, dynamic> parameters;

  const ToolDefinition({
    required this.id,
    required this.displayName,
    required this.description,
    required this.category,
    this.isBuiltIn = true,
    this.autoApproved = true,
    this.parameters = const {},
  });

  /// Factory for standard Google Search tool
  factory ToolDefinition.googleSearch() {
    return const ToolDefinition(
      id: 'google_search',
      displayName: 'Google Search',
      description: 'Grounded web search for real-time documentation, APIs, and error troubleshooting.',
      category: ToolCategory.search,
      isBuiltIn: true,
      autoApproved: true,
    );
  }

  /// Factory for standard URL Context tool
  factory ToolDefinition.urlContext() {
    return const ToolDefinition(
      id: 'url_context',
      displayName: 'URL Context / Browse',
      description: 'Extracts full content from web URLs and documentation pages into agent context.',
      category: ToolCategory.web,
      isBuiltIn: true,
      autoApproved: true,
    );
  }

  /// Factory for standard Sandbox Filesystem tool
  factory ToolDefinition.filesystem({
    String baseDirectory = '/workspace',
    List<String> operations = const [
      'view_file',
      'write_to_file',
      'replace_file_content',
      'list_dir',
      'find_by_name',
    ],
  }) {
    return ToolDefinition(
      id: 'filesystem',
      displayName: 'Sandbox Filesystem',
      description: 'Reads, writes, updates, and searches files inside the managed Linux sandbox.',
      category: ToolCategory.filesystem,
      isBuiltIn: true,
      autoApproved: true,
      parameters: {
        'baseDirectory': baseDirectory,
        'supportedOperations': operations,
      },
    );
  }

  /// Factory for standard Code Execution tool
  factory ToolDefinition.codeExecution({
    List<String> supportedLanguages = const [
      'bash',
      'python',
      'dart',
      'javascript',
      'typescript',
      'go',
      'rust',
      'elixir',
      'csharp',
    ],
  }) {
    return ToolDefinition(
      id: 'code_execution',
      displayName: 'Managed Code Execution',
      description: 'Executes non-interactive bash commands, compilers, and test runners in the gVisor container.',
      category: ToolCategory.codeExecution,
      isBuiltIn: true,
      autoApproved: true,
      parameters: {
        'supportedLanguages': supportedLanguages,
      },
    );
  }

  /// Factory for standard Headless Browser QA tool
  factory ToolDefinition.headlessBrowser({
    String framework = 'playwright',
    String traceOutputDir = '/workspace/output/traces',
    String screenshotOutputDir = '/workspace/output/screenshots',
  }) {
    return ToolDefinition(
      id: 'headless_browser',
      displayName: 'Playwright Browser QA',
      description: 'Executes headless Chrome browser verification with trace recording and DOM snapshots.',
      category: ToolCategory.browser,
      isBuiltIn: true,
      autoApproved: true,
      parameters: {
        'framework': framework,
        'traceOutputDirectory': traceOutputDir,
        'screenshotOutputDirectory': screenshotOutputDir,
      },
    );
  }

  /// Factory for MCP Tools
  factory ToolDefinition.fromMcp({
    required String serverName,
    required String toolName,
    String? description,
    bool autoApproved = false,
  }) {
    return ToolDefinition(
      id: '$serverName:$toolName',
      displayName: '$serverName / $toolName',
      description: description ?? 'MCP tool provided by $serverName server.',
      category: ToolCategory.mcp,
      isBuiltIn: false,
      autoApproved: autoApproved,
    );
  }

  /// Converts to standard Managed Agents Control-Plane tool schema representation
  Map<String, dynamic> toControlPlaneSchema() {
    switch (category) {
      case ToolCategory.search:
        return {'googleSearch': {}};
      case ToolCategory.web:
        return {'urlContext': {}};
      case ToolCategory.filesystem:
        return {
          'filesystem': {
            'baseDirectory': parameters['baseDirectory'] ?? '/workspace',
            'supportedOperations': parameters['supportedOperations'] ?? [
              'view_file',
              'write_to_file',
              'replace_file_content',
              'list_dir',
              'find_by_name',
            ],
          }
        };
      case ToolCategory.codeExecution:
        return {
          'codeExecution': {
            'supportedLanguages': parameters['supportedLanguages'] ?? ['bash', 'python', 'dart'],
          }
        };
      case ToolCategory.browser:
        return {
          'headlessBrowser': {
            'framework': parameters['framework'] ?? 'playwright',
            'traceOutputDirectory': parameters['traceOutputDirectory'] ?? '/workspace/output/traces',
            'screenshotOutputDirectory': parameters['screenshotOutputDirectory'] ?? '/workspace/output/screenshots',
          }
        };
      case ToolCategory.mcp:
        return {
          'mcpTool': {
            'id': id,
            'autoApproved': autoApproved,
          }
        };
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'description': description,
      'category': category.name,
      'isBuiltIn': isBuiltIn,
      'autoApproved': autoApproved,
      'parameters': parameters,
    };
  }
}
