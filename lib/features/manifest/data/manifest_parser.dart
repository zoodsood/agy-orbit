import 'package:yaml/yaml.dart';
import '../domain/entities/agent_manifest.dart';
import '../domain/entities/mcp_server_config.dart';
import '../domain/entities/skill_definition.dart';
import '../domain/entities/tool_definition.dart';

/// Parses AGENTS.md and SKILLS.md files into AgentManifest entities.
class ManifestParser {
  /// Parses AGENTS.md content with optional YAML frontmatter.
  static AgentManifest parseAgentManifest(String markdownContent, {String defaultModel = 'gemini-4-argon'}) {
    final frontmatterData = _extractFrontmatter(markdownContent);
    final yaml = frontmatterData.frontmatter;
    final body = frontmatterData.body;

    final name = yaml['name']?.toString() ?? 'Managed Coding Agent';
    // Dynamic model: extracted from manifest, or falls back to passed default without hardcoding
    final model = yaml['model']?.toString() ?? defaultModel;
    final description = yaml['description']?.toString() ?? '';

    // Parse skill references
    final rawSkills = yaml['skills'];
    final skillRefs = <String>[];
    if (rawSkills is List) {
      for (final s in rawSkills) {
        skillRefs.add(s.toString());
      }
    }

    // Parse MCP servers
    final rawMcp = yaml['mcp_servers'] ?? yaml['mcpServers'];
    final mcpServers = <McpServerConfig>[];
    if (rawMcp is List) {
      for (final m in rawMcp) {
        if (m is Map) {
          mcpServers.add(McpServerConfig.fromMap(m));
        }
      }
    }

    // Parse sandbox configs
    final sandboxConfig = <String, dynamic>{
      'workspaceOutputDir': '/workspace/output',
      'networkAllowlist': ['*'],
    };
    if (yaml['sandbox'] is Map) {
      sandboxConfig.addAll(Map<String, dynamic>.from(yaml['sandbox'] as Map));
    }

    // Parse tools (defaults to complete Antigravity suite: google_search, url_context, filesystem, code_execution, headless_browser)
    final rawTools = yaml['tools'];
    final tools = <ToolDefinition>[];
    if (rawTools is List) {
      for (final t in rawTools) {
        final tStr = t.toString().toLowerCase().replaceAll('-', '_');
        if (tStr.contains('search')) {
          tools.add(ToolDefinition.googleSearch());
        } else if (tStr.contains('url') || tStr.contains('browse') || tStr.contains('context')) {
          tools.add(ToolDefinition.urlContext());
        } else if (tStr.contains('file') || tStr.contains('fs')) {
          tools.add(ToolDefinition.filesystem());
        } else if (tStr.contains('code') || tStr.contains('exec') || tStr.contains('bash')) {
          tools.add(ToolDefinition.codeExecution());
        } else if (tStr.contains('browser') || tStr.contains('playwright')) {
          tools.add(ToolDefinition.headlessBrowser());
        }
      }
    } else {
      tools.addAll([
        ToolDefinition.googleSearch(),
        ToolDefinition.urlContext(),
        ToolDefinition.filesystem(),
        ToolDefinition.codeExecution(),
        ToolDefinition.headlessBrowser(),
      ]);
    }

    return AgentManifest(
      name: name,
      model: model,
      description: description,
      instructions: body.trim(),
      skillReferences: skillRefs,
      mcpServers: mcpServers,
      sandboxConfig: sandboxConfig,
      tools: tools,
    );
  }

  /// Parses SKILLS.md content into a list of SkillDefinitions.
  static List<SkillDefinition> parseSkillsManifest(String markdownContent) {
    final results = <SkillDefinition>[];
    final frontmatterData = _extractFrontmatter(markdownContent);
    final yaml = frontmatterData.frontmatter;
    final body = frontmatterData.body;

    // Check if skills are defined in YAML frontmatter list
    if (yaml['skills'] is List) {
      for (final item in yaml['skills'] as List) {
        if (item is Map) {
          results.add(SkillDefinition.fromMap(item));
        }
      }
    }

    // If body contains markdown skill headers, parse them as skills
    if (results.isEmpty && body.isNotEmpty) {
      final skillSections = body.split(RegExp(r'\n(?=##\s+)'));
      for (final section in skillSections) {
        final match = RegExp(r'^##\s+(.+)$', multiLine: true).firstMatch(section);
        if (match != null) {
          final skillName = match.group(1)?.trim() ?? 'Skill';
          final sectionBody = section.replaceFirst(match.group(0)!, '').trim();
          results.add(SkillDefinition(
            id: skillName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
            name: skillName,
            description: sectionBody.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => ''),
            instructions: sectionBody,
          ));
        }
      }
    }

    return results;
  }

  /// Extracts YAML frontmatter delimited by `---` and returns remaining markdown body.
  static ({Map<dynamic, dynamic> frontmatter, String body}) _extractFrontmatter(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final match = RegExp(r'^---\n(.*?)\n---\n?', dotAll: true).firstMatch(normalized);

    if (match != null) {
      final frontmatterRaw = match.group(1)!;
      final body = normalized.substring(match.end);
      try {
        final dynamic loadedYaml = loadYaml(frontmatterRaw);
        if (loadedYaml is Map) {
          return (frontmatter: loadedYaml, body: body);
        }
      } catch (_) {
        // Fallback on invalid YAML
      }
      return (frontmatter: {}, body: body);
    }

    return (frontmatter: {}, body: normalized);
  }
}
