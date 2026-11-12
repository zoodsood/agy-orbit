import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/core/config/model_descriptor.dart';
import 'package:antigravity_flutter/core/config/model_registry.dart';
import 'package:antigravity_flutter/features/monitor/presentation/widgets/agent_monitor_view.dart';
import 'package:antigravity_flutter/features/monitor/presentation/widgets/syntax_diff_viewer.dart';
import 'package:antigravity_flutter/features/session/domain/entities/agent_state.dart';
import 'package:antigravity_flutter/features/session/presentation/widgets/model_selector_dropdown.dart';

void main() {
  group('Agent Monitor & UI Widgets Tests', () {
    testWidgets('AgentMonitorView renders pipeline stages and active status badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AgentMonitorView(
              currentState: AgentState.executingCode,
              modelName: 'gemini-4-argon',
              sessionId: 'test-sess-1',
              elapsed: Duration(seconds: 45),
            ),
          ),
        ),
      );

      expect(find.text('AGY: test-sess-1'), findsOneWidget);
      expect(find.text('gemini-4-argon'), findsOneWidget);
      expect(find.text('00:45'), findsOneWidget);
      expect(find.text('Planning'), findsOneWidget);
      expect(find.text('Executing Code'), findsOneWidget);
      expect(find.text('Reading Logs'), findsOneWidget);
      expect(find.text('Browser QA'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('SyntaxDiffViewer parses and renders additions and deletions', (tester) async {
      const unifiedDiff = '''
--- a/example.dart
+++ b/example.dart
@@ -1,2 +1,3 @@
-old line
+new line 1
+new line 2
''';

      final diff = FileDiff.fromUnifiedDiff(unifiedDiff);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyntaxDiffViewer(diffs: [diff]),
          ),
        ),
      );

      expect(find.text('example.dart'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('old line'), findsOneWidget);
      expect(find.text('new line 1'), findsOneWidget);
      expect(find.text('new line 2'), findsOneWidget);
    });

    testWidgets('ModelSelectorDropdown enforces lock when session is active', (tester) async {
      final registry = ModelRegistry(initialModels: [
        const ModelDescriptor(
          id: 'gemini-4-argon',
          displayName: 'Gemini 4 Argon',
          description: 'Reasoning model',
          supportsReasoning: true,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModelSelectorDropdown(
              registry: registry,
              selectedModelId: 'gemini-4-argon',
              isLocked: true, // Session active, model locked
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Gemini 4 Argon'), findsOneWidget);
      expect(find.text('Reasoning'), findsOneWidget);
    });
  });
}
