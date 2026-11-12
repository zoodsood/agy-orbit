import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/core/config/app_config.dart';
import 'package:antigravity_flutter/features/manifest/data/manifest_parser.dart';
import 'package:antigravity_flutter/features/manifest/data/mcp_config_generator.dart';

void main() {
  group('Manifest Parser & MCP Generator Tests', () {
    const sampleAgentsMd = '''---
name: Fullstack Refactor Agent
model: gemini-4-argon
skills:
  - skills/test_runner.md
mcp_servers:
  - name: github-mcp
    command: npx
    args:
      - "-y"
      - "@modelcontextprotocol/server-github"
    env:
      GITHUB_KEY: "secret://github"
    transport: stdio
    autoApprovedTools:
      - get_repo
      - create_pr
sandbox:
  workspaceOutputDir: /workspace/output
  networkAllowlist:
    - "*"
---

# Instructions
Perform clean refactors and run headless tests.
''';

    const sampleSkillsMd = '''---
skills:
  - id: playwright_qa
    name: Headless QA
    description: Runs headless browser tests.
    tools:
      - playwright
---
# Skills Catalog
## Code Analyzer
Runs static analysis across codebase.
''';

    test('Parses AGENTS.md with dynamic model and MCP servers', () {
      final manifest = ManifestParser.parseAgentManifest(sampleAgentsMd);

      expect(manifest.name, equals('Fullstack Refactor Agent'));
      expect(manifest.model, equals('gemini-4-argon'));
      expect(manifest.instructions, contains('Perform clean refactors'));
      expect(manifest.skillReferences, contains('skills/test_runner.md'));

      expect(manifest.mcpServers.length, equals(1));
      final mcp = manifest.mcpServers.first;
      expect(mcp.name, equals('github-mcp'));
      expect(mcp.command, equals('npx'));
      expect(mcp.args, equals(['-y', '@modelcontextprotocol/server-github']));
      expect(mcp.autoApprovedTools, contains('create_pr'));
      expect(manifest.sandboxConfig['networkAllowlist'], equals(['*']));
    });

    test('Parses SKILLS.md into SkillDefinitions', () {
      final skills = ManifestParser.parseSkillsManifest(sampleSkillsMd);

      expect(skills.length, greaterThanOrEqualTo(1));
      final qaSkill = skills.firstWhere((s) => s.id == 'playwright_qa');
      expect(qaSkill.name, equals('Headless QA'));
      expect(qaSkill.requiredTools, contains('playwright'));
    });

    test('Generates Control Plane payload with MCP tools and sandbox rules', () {
      final manifest = ManifestParser.parseAgentManifest(sampleAgentsMd);
      final appConfig = AppConfig(networkAllowlist: ['*']);

      final payload = McpConfigGenerator.generateControlPlanePayload(
        manifest: manifest,
        appConfig: appConfig,
      );

      final agentData = payload['agent'] as Map<String, dynamic>;
      expect(agentData['displayName'], equals('Fullstack Refactor Agent'));
      expect(agentData['model'], equals('gemini-4-argon'));

      final tools = agentData['tools'] as List<dynamic>;
      expect(tools.any((t) => (t as Map).containsKey('googleSearch')), isTrue);
      expect(tools.any((t) => (t as Map).containsKey('urlContext')), isTrue);
      expect(tools.any((t) => (t as Map).containsKey('filesystem')), isTrue);
      expect(tools.any((t) => (t as Map).containsKey('codeExecution')), isTrue);
      expect(tools.any((t) => (t as Map).containsKey('headlessBrowser')), isTrue);
      expect(tools.any((t) => (t as Map).containsKey('mcpServer')), isTrue);

      final fsTool = tools.firstWhere((t) => (t as Map).containsKey('filesystem'))['filesystem'] as Map<String, dynamic>;
      expect(fsTool['baseDirectory'], equals('/workspace'));
      expect(fsTool['supportedOperations'], containsAll(['view_file', 'write_to_file', 'replace_file_content', 'list_dir', 'find_by_name']));

      final sandboxPolicy = agentData['sandboxPolicy'] as Map<String, dynamic>;
      expect(sandboxPolicy['outputPath'], equals('/workspace/output'));
      expect(sandboxPolicy['networkEgress']['allowlist'], contains('*'));
    });

    test('Parses custom tools from manifest YAML if declared', () {
      const customToolsMd = '''---
name: Search Only Agent
model: gemini-3.8-flash
tools:
  - google_search
  - url_context
---
Search the web for latest Flutter documentation.
''';

      final manifest = ManifestParser.parseAgentManifest(customToolsMd);
      expect(manifest.tools.length, equals(2));
      expect(manifest.tools[0].id, equals('google_search'));
      expect(manifest.tools[1].id, equals('url_context'));

      final payload = McpConfigGenerator.generateControlPlanePayload(
        manifest: manifest,
        appConfig: AppConfig(),
      );

      final tools = (payload['agent'] as Map)['tools'] as List;
      expect(tools.length, equals(2));
      expect(tools.any((t) => (t as Map).containsKey('googleSearch')), isTrue);
      expect(tools.any((t) => (t as Map).containsKey('urlContext')), isTrue);
      expect(tools.any((t) => (t as Map).containsKey('filesystem')), isFalse);
    });

    test('Parses remote SSE MCP server with URL (e.g. appwrite-docs-mcp)', () {
      const sseMcpMd = '''---
name: Appwrite Integration Agent
model: gemini-4-argon
mcp_servers:
  - name: appwrite-docs-mcp
    transport: sse
    url: "https://mcp-for-docs.appwrite.io"
    autoApprovedTools:
      - search_documentation
      - get_api_reference
sandbox:
  networkAllowlist:
    - "*"
---
Help developer integrate Appwrite SDK.
''';

      final manifest = ManifestParser.parseAgentManifest(sseMcpMd);
      expect(manifest.mcpServers.length, equals(1));
      final sseMcp = manifest.mcpServers.first;
      expect(sseMcp.name, equals('appwrite-docs-mcp'));
      expect(sseMcp.transport, equals('sse'));
      expect(sseMcp.url, equals('https://mcp-for-docs.appwrite.io'));
      expect(sseMcp.autoApprovedTools, contains('search_documentation'));

      final payload = McpConfigGenerator.generateControlPlanePayload(
        manifest: manifest,
        appConfig: AppConfig(networkAllowlist: ['*']),
      );

      final tools = (payload['agent'] as Map)['tools'] as List;
      final mcpEntry = tools.firstWhere((t) => (t as Map).containsKey('mcpServer'))['mcpServer'] as Map<String, dynamic>;
      expect(mcpEntry['name'], equals('appwrite-docs-mcp'));
      expect(mcpEntry['transport'], equals('sse'));
      expect(mcpEntry['url'], equals('https://mcp-for-docs.appwrite.io'));
    });
  });
}
