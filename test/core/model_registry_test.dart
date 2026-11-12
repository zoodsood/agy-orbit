import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/core/config/model_descriptor.dart';
import 'package:antigravity_flutter/core/config/model_registry.dart';

void main() {
  group('Dynamic Model Registry Tests (No Hardcoded Models)', () {
    test('Can register and discover new models dynamically at runtime without rebuild', () {
      final registry = ModelRegistry();
      expect(registry.isEmpty, isTrue);

      // Register newly released models dynamically
      registry.registerModel(const ModelDescriptor(
        id: 'gemini-future-super-reasoning',
        displayName: 'Gemini Future Super Reasoning',
        description: 'Next gen reasoning model released without app update',
        supportsReasoning: true,
      ));

      registry.registerModel(const ModelDescriptor(
        id: 'gemini-hyper-fast-coder',
        displayName: 'Gemini Hyper Fast Coder',
        description: 'Ultra-low latency code generation',
        supportsFastCoding: true,
      ));

      expect(registry.models.length, equals(2));
      expect(registry.containsModel('gemini-future-super-reasoning'), isTrue);
      expect(registry.containsModel('gemini-hyper-fast-coder'), isTrue);

      final reasoningModels = registry.getReasoningModels();
      expect(reasoningModels.length, equals(1));
      expect(reasoningModels.first.id, equals('gemini-future-super-reasoning'));

      final fastModels = registry.getFastCodingModels();
      expect(fastModels.length, equals(1));
      expect(fastModels.first.id, equals('gemini-hyper-fast-coder'));
    });

    test('Parses models directly from Google Gemini Models API payload', () {
      final apiResponse = {
        'name': 'models/gemini-4-argon',
        'displayName': 'Gemini 4 Argon',
        'description': 'Advanced reasoning and multi-turn planning model',
        'inputTokenLimit': 2000000,
        'supportedGenerationMethods': ['generateContent', 'countTokens'],
      };

      final descriptor = ModelDescriptor.fromGoogleApiModel(apiResponse);
      expect(descriptor.id, equals('gemini-4-argon'));
      expect(descriptor.displayName, equals('Gemini 4 Argon'));
      expect(descriptor.supportsReasoning, isTrue);
      expect(descriptor.maxContextTokens, equals(2000000));
    });

    test('Loads dynamically from JSON array without recompilation', () {
      final registry = ModelRegistry();
      registry.loadFromJsonList([
        {
          'id': 'custom-fine-tuned-dart-v1',
          'displayName': 'Custom Dart Fine-Tune',
          'description': 'Trained specifically on Flutter widgets',
          'supportsFastCoding': true,
        }
      ]);

      expect(registry.containsModel('custom-fine-tuned-dart-v1'), isTrue);
      expect(registry.getModel('custom-fine-tuned-dart-v1')?.supportsFastCoding, isTrue);
    });
  });
}
