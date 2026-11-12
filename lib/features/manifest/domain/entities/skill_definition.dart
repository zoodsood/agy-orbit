/// Definition of an agent skill extracted from SKILLS.md.
class SkillDefinition {
  final String id;
  final String name;
  final String description;
  final String instructions;
  final List<String> requiredTools;
  final Map<String, dynamic> parameters;

  const SkillDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    this.requiredTools = const [],
    this.parameters = const {},
  });

  factory SkillDefinition.fromMap(Map<dynamic, dynamic> map, {String instructions = ''}) {
    return SkillDefinition(
      id: map['id']?.toString() ?? map['name']?.toString().toLowerCase().replaceAll(' ', '_') ?? 'skill',
      name: map['name']?.toString() ?? 'Unnamed Skill',
      description: map['description']?.toString() ?? '',
      instructions: instructions.isNotEmpty ? instructions : (map['instructions']?.toString() ?? ''),
      requiredTools: (map['tools'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      parameters: Map<String, dynamic>.from(map['parameters'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'instructions': instructions,
      'requiredTools': requiredTools,
      'parameters': parameters,
    };
  }
}
