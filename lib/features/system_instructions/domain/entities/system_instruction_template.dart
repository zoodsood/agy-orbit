/// Template representing a pre-configured or user-defined system instruction.
class SystemInstructionTemplate {
  final String id;
  final String title;
  final String category;
  final String description;
  final String systemPrompt;
  final bool isCustom;
  final List<String> tags;

  const SystemInstructionTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.systemPrompt,
    this.isCustom = false,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'systemPrompt': systemPrompt,
      'isCustom': isCustom,
      'tags': tags,
    };
  }

  factory SystemInstructionTemplate.fromJson(Map<String, dynamic> json) {
    return SystemInstructionTemplate(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Instruction',
      category: json['category'] as String? ?? 'General',
      description: json['description'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      isCustom: json['isCustom'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
