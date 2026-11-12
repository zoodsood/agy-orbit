import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/features/system_instructions/data/system_instruction_repository.dart';
import 'package:antigravity_flutter/features/system_instructions/domain/entities/system_instruction_template.dart';

void main() {
  group('System Instructions Repository & Catalog Tests', () {
    test('Initializes with curated default prompt templates', () {
      final repo = SystemInstructionRepository();
      final templates = repo.getTemplates();

      expect(templates.length, greaterThanOrEqualTo(5));
      expect(templates.any((t) => t.id == 'arch-flutter-senior'), isTrue);
      expect(templates.any((t) => t.id == 'sec-auditor-owasp'), isTrue);
      expect(templates.any((t) => t.id == 'refactor-specialist'), isTrue);

      final archTemplate = repo.getById('arch-flutter-senior');
      expect(archTemplate, isNotNull);
      expect(archTemplate!.systemPrompt, contains('Principal Mobile Architect'));
    });

    test('Filters templates by category', () {
      final repo = SystemInstructionRepository();
      final secTemplates = repo.getTemplates(category: 'Security');

      expect(secTemplates.length, equals(1));
      expect(secTemplates.first.id, equals('sec-auditor-owasp'));
    });

    test('Allows registering and deleting custom instruction templates', () {
      final repo = SystemInstructionRepository();
      const custom = SystemInstructionTemplate(
        id: 'custom-widget-tester',
        title: 'Custom Widget Testing Specialist',
        category: 'Custom',
        description: 'Generates robust golden and pump tests.',
        systemPrompt: 'Always generate exhaustive pumpWidget and golden comparison tests.',
        isCustom: true,
      );

      repo.addCustomTemplate(custom);
      expect(repo.getById('custom-widget-tester'), isNotNull);

      final customList = repo.getTemplates(category: 'Custom');
      expect(customList.length, equals(1));
      expect(customList.first.title, equals('Custom Widget Testing Specialist'));

      repo.deleteCustomTemplate('custom-widget-tester');
      expect(repo.getById('custom-widget-tester'), isNull);
    });
  });
}
