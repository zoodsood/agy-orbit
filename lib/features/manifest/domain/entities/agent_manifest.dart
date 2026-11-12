import 'mcp_server_config.dart';
import 'skill_definition.dart';
import 'tool_definition.dart';

/// Complete configuration manifest parsed from AGENTS.md and SKILLS.md.
class AgentManifest {
  final String name;
  final String model; // Dynamic model identifier (not hardcoded)
  final String description;
  final String instructions;
  final List<String> skillReferences;
  final List<SkillDefinition> skills;
  final List<McpServerConfig> mcpServers;
  final Map<String, dynamic> sandboxConfig;
  final List<ToolDefinition> tools;

  const AgentManifest({
    required this.name,
    required this.model,
    required this.description,
    required this.instructions,
    this.skillReferences = const [],
    this.skills = const [],
    this.mcpServers = const [],
    this.sandboxConfig = const {},
    this.tools = const [],
  });

  AgentManifest copyWith({
    String? name,
    String? model,
    String? description,
    String? instructions,
    List<String>? skillReferences,
    List<SkillDefinition>? skills,
    List<McpServerConfig>? mcpServers,
    Map<String, dynamic>? sandboxConfig,
    List<ToolDefinition>? tools,
  }) {
    return AgentManifest(
      name: name ?? this.name,
      model: model ?? this.model,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      skillReferences: skillReferences ?? this.skillReferences,
      skills: skills ?? this.skills,
      mcpServers: mcpServers ?? this.mcpServers,
      sandboxConfig: sandboxConfig ?? this.sandboxConfig,
      tools: tools ?? this.tools,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'model': model,
      'description': description,
      'instructions': instructions,
      'skillReferences': skillReferences,
      'skills': skills.map((s) => s.toJson()).toList(),
      'mcpServers': mcpServers.map((m) => m.toJson()).toList(),
      'sandboxConfig': sandboxConfig,
      'tools': tools.map((t) => t.toJson()).toList(),
    };
  }
}
