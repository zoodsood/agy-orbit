
/// Represents a dynamically discoverable Gemini or Managed Agent model.
/// No model names or capabilities are hardcoded in the codebase.
class ModelDescriptor {
  final String id;
  final String displayName;
  final String description;
  final bool supportsReasoning;
  final bool supportsFastCoding;
  final int maxContextTokens;
  final List<String> tags;
  final Map<String, dynamic> extraMetadata;

  const ModelDescriptor({
    required this.id,
    required this.displayName,
    required this.description,
    this.supportsReasoning = false,
    this.supportsFastCoding = false,
    this.maxContextTokens = 1000000,
    this.tags = const [],
    this.extraMetadata = const {},
  });

  factory ModelDescriptor.fromJson(Map<String, dynamic> json) {
    return ModelDescriptor(
      id: json['id'] as String? ?? json['name'] as String? ?? 'unknown-model',
      displayName: json['displayName'] as String? ?? json['name'] as String? ?? 'Unnamed Model',
      description: json['description'] as String? ?? '',
      supportsReasoning: json['supportsReasoning'] as bool? ??
          (json['tags'] as List?)?.contains('reasoning') ??
          (json['description'] as String? ?? '').toLowerCase().contains('reasoning'),
      supportsFastCoding: json['supportsFastCoding'] as bool? ??
          (json['tags'] as List?)?.contains('fast-loop') ??
          (json['description'] as String? ?? '').toLowerCase().contains('fast'),
      maxContextTokens: json['maxContextTokens'] as int? ??
          json['inputTokenLimit'] as int? ??
          1000000,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      extraMetadata: Map<String, dynamic>.from(json['extraMetadata'] as Map? ?? {}),
    );
  }

  /// Parses from standard Google Gemini Models API (`/v1beta/models`) format.
  factory ModelDescriptor.fromGoogleApiModel(Map<String, dynamic> apiModel) {
    // API returns name like "models/gemini-1.5-pro" or "models/gemini-4-argon"
    final rawName = apiModel['name'] as String? ?? '';
    final id = rawName.startsWith('models/') ? rawName.substring(7) : rawName;
    final displayName = apiModel['displayName'] as String? ?? id;
    final description = apiModel['description'] as String? ?? '';
    final inputTokenLimit = apiModel['inputTokenLimit'] as int? ?? 1000000;
    final supportedGenerationMethods = (apiModel['supportedGenerationMethods'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final isReasoning = id.toLowerCase().contains('argon') ||
        id.toLowerCase().contains('pro') ||
        description.toLowerCase().contains('reasoning') ||
        description.toLowerCase().contains('complex');

    final isFast = id.toLowerCase().contains('flash') ||
        id.toLowerCase().contains('fast') ||
        description.toLowerCase().contains('fast');

    return ModelDescriptor(
      id: id,
      displayName: displayName,
      description: description,
      supportsReasoning: isReasoning,
      supportsFastCoding: isFast,
      maxContextTokens: inputTokenLimit,
      tags: [
        if (isReasoning) 'reasoning',
        if (isFast) 'fast-coding',
        ...supportedGenerationMethods,
      ],
      extraMetadata: apiModel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'description': description,
      'supportsReasoning': supportsReasoning,
      'supportsFastCoding': supportsFastCoding,
      'maxContextTokens': maxContextTokens,
      'tags': tags,
      'extraMetadata': extraMetadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelDescriptor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ModelDescriptor($id, displayName: $displayName)';
}
