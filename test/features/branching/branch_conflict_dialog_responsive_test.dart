import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/features/branching/domain/entities/conversation_tree.dart';
import 'package:antigravity_flutter/features/branching/presentation/widgets/branch_conflict_dialog.dart';

void main() {
  group('BranchConflictDialog Responsive Tests', () {
    final sampleConflicts = [
      BranchFileConflict(
        relativePath: 'lib/auth/auth_service.dart',
        baseContent: 'Future<bool> authenticate();',
        currentBranchContent: 'Future<AuthResult> authenticate(); // Ours',
        incomingBranchContent: 'Future<SessionToken> authenticate(); // Theirs',
      ),
    ];

    testWidgets('Renders 3 side-by-side panes on wide desktop resolution (>=720px)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BranchConflictDialog(
              conflicts: sampleConflicts,
              onResolved: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // In wide view, all 3 pane titles should be visible simultaneously
      expect(find.text('Current Branch (Ours)'), findsOneWidget);
      expect(find.text('Common Ancestor (Base)'), findsOneWidget);
      expect(find.text('Incoming Branch (Theirs)'), findsOneWidget);
      expect(find.text('Keep Ours'), findsOneWidget);
      expect(find.text('Accept Theirs'), findsOneWidget);
      expect(find.text('Combine Both'), findsOneWidget);
    });

    testWidgets('Renders segmented button and single pane on narrow mobile resolution (<720px)', (tester) async {
      tester.view.physicalSize = const Size(480, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BranchConflictDialog(
              conflicts: sampleConflicts,
              onResolved: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // In narrow view, segmented selector with Ours / Base / Theirs buttons should be present
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
      // Initially, "Current Branch (Ours)" should be active
      expect(find.text('Current Branch (Ours)'), findsOneWidget);

      // Tap "Theirs" segmented tab (index 2)
      await tester.tap(find.text('Theirs'));
      await tester.pumpAndSettle();

      // Now "Incoming Branch (Theirs)" is rendered
      expect(find.text('Incoming Branch (Theirs)'), findsOneWidget);
    });
  });
}
