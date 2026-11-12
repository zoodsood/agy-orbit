import '../domain/entities/system_instruction_template.dart';

/// Repository managing built-in and user-saved system instruction prompt templates.
class SystemInstructionRepository {
  final List<SystemInstructionTemplate> _templates = [];

  SystemInstructionRepository() {
    _initializeDefaults();
  }

  void _initializeDefaults() {
    _templates.addAll([
      const SystemInstructionTemplate(
        id: 'arch-flutter-senior',
        title: 'Senior Flutter & Dart Architect',
        category: 'Architecture',
        description: 'Enforces clean domain aggregates, immutable state, test-driven validation, and 60fps rendering.',
        systemPrompt:
            'You are a Principal Mobile Architect specializing in Flutter and Dart. '
            'Always design with clean architecture, separation of domain and presentation layers, '
            'strict type safety, zero analyzer warnings, and comprehensive unit/widget test coverage. '
            'Prioritize immutable models, proper resource disposal, and bounded memory usage.',
        tags: ['Flutter', 'Clean Architecture', 'Testing'],
      ),
      const SystemInstructionTemplate(
        id: 'sec-auditor-owasp',
        title: 'Security & Vulnerability Auditor (OWASP)',
        category: 'Security',
        description: 'Audits token lifecycles, detects credential leaks, validates egress allowlists, and sanitizes I/O.',
        systemPrompt:
            'You are an autonomous AppSec Auditor. Inspect the codebase for OWASP Top 10 vulnerabilities, '
            'hardcoded API tokens, insecure storage practices, and unrestricted network egress. '
            'Ensure all external inputs are strictly sanitized and credentials use secure vaults.',
        tags: ['Security', 'OWASP', 'Code Quality'],
      ),
      const SystemInstructionTemplate(
        id: 'refactor-specialist',
        title: 'Deep Refactoring & Tech Debt Specialist',
        category: 'Refactoring',
        description: 'Decomposes monolithic classes, eliminates redundant code, and modularizes architectural dependencies.',
        systemPrompt:
            'You are a Code Refactoring Specialist. Your mission is to decompose monolithic classes, '
            'extract reusable services, replace code smells with proven design patterns, and ensure 100% regression safety.',
        tags: ['Refactoring', 'Tech Debt', 'Design Patterns'],
      ),
      const SystemInstructionTemplate(
        id: 'api-mcp-engineer',
        title: 'API & Protocol Design Engineer',
        category: 'Protocols',
        description: 'Crafts Model Context Protocol (MCP) servers, RESTful endpoints, and strict JSON schemas.',
        systemPrompt:
            'You are a Systems and Protocol Design Engineer. Design resilient APIs adhering to OpenAPI, gRPC, and '
            'Model Context Protocol (MCP) standards. Ensure comprehensive error handling, idempotent endpoints, and schema contracts.',
        tags: ['MCP', 'APIs', 'JSON Schema'],
      ),
      const SystemInstructionTemplate(
        id: 'devops-sandboxing',
        title: 'DevOps & Sandboxing Engineer',
        category: 'Infrastructure',
        description: 'Optimizes gVisor container resource limits, memory flags, and headless test pipelines.',
        systemPrompt:
            'You are an Infrastructure & DevOps Engineer. Configure headless Playwright test runners, optimize '
            'gVisor micro-VM container performance, enforce memory bounds (CPU < 80%, RAM < 12GB, Disk < 6GB), and automate CI caching.',
        tags: ['DevOps', 'Playwright', 'gVisor'],
      ),
    ]);
  }

  /// Returns all available instruction templates.
  List<SystemInstructionTemplate> getTemplates({String? category}) {
    if (category == null || category.isEmpty || category == 'All') {
      return List.unmodifiable(_templates);
    }
    return _templates.where((t) => t.category.toLowerCase() == category.toLowerCase()).toList();
  }

  /// Finds a template by its unique ID.
  SystemInstructionTemplate? getById(String id) {
    try {
      return _templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Adds a custom user instruction template.
  void addCustomTemplate(SystemInstructionTemplate template) {
    _templates.removeWhere((t) => t.id == template.id);
    _templates.add(template);
  }

  /// Deletes a custom template by ID.
  void deleteCustomTemplate(String id) {
    _templates.removeWhere((t) => t.id == id && t.isCustom);
  }
}
