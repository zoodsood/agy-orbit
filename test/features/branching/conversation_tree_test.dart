import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/features/branching/domain/entities/conversation_tree.dart';

void main() {
  group('Grok-Style ConversationTree & Per-Conversation Isolation Tests', () {
    const environmentId = 'env-soc2-984a';

    test('Creates root node bound to shared environmentId with default wildcard egress (*)', () {
      final tree = ConversationTree.createWithRoot(
        environmentId: environmentId,
        initialPrompt: 'Modernize auth service to OAuth2 PKCE',
        branchName: 'main',
        isolationMode: BranchIsolationMode.directoryIsolation,
      );

      expect(tree.environmentId, equals(environmentId));
      expect(tree.networkAllowlist, equals(['*']));
      expect(tree.nodes.length, equals(1));
      final root = tree.nodes[tree.rootNodeId]!;
      expect(root.role, equals('user'));
      expect(root.workingDirectory, equals('main/'));
      expect(root.environmentId, equals(environmentId));
      expect(root.metadata['networkAllowlist'], equals(['*']));
    });

    test('Subthreads strictly inherit conversation-level isolation mode without switching on the fly', () {
      // 1. Directory-isolated conversation
      final dirTree = ConversationTree.createWithRoot(
        environmentId: environmentId,
        initialPrompt: 'Directory thread',
        isolationMode: BranchIsolationMode.directoryIsolation,
      );

      final dirChild = dirTree.addMessage(
        parentId: dirTree.rootNodeId!,
        role: 'agent',
        content: 'Directory child step',
        branchName: 'dir-step-1',
      );
      expect(dirChild.isolationMode, equals(BranchIsolationMode.directoryIsolation));
      expect(dirChild.workingDirectory, equals('branches/dir-step-1/'));

      // 2. Worktree-isolated conversation
      final worktreeTree = ConversationTree.createWithRoot(
        environmentId: environmentId,
        initialPrompt: 'Worktree thread',
        isolationMode: BranchIsolationMode.gitWorktree,
      );

      final worktreeChild = worktreeTree.addMessage(
        parentId: worktreeTree.rootNodeId!,
        role: 'agent',
        content: 'Worktree child step',
        branchName: 'worktree-step-1',
      );
      expect(worktreeChild.isolationMode, equals(BranchIsolationMode.gitWorktree));
      expect(worktreeChild.workingDirectory, equals('.worktrees/worktree-step-1/'));
      expect(worktreeChild.worktreeBranch, equals('orbit/worktree-step-1'));

      // Forked subthread also inherits parent tree isolation mode
      final forked = worktreeTree.forkBranch(
        fromNodeId: worktreeChild.id,
        newContent: 'Forked alternative',
        role: 'agent',
        newBranchName: 'worktree-step-1-alt',
      );
      expect(forked.isolationMode, equals(BranchIsolationMode.gitWorktree));
      expect(forked.workingDirectory, equals('.worktrees/worktree-step-1-alt/'));
    });

    test('Navigates between sibling branches dynamically and switches active path', () {
      final tree = ConversationTree.createWithRoot(
        environmentId: environmentId,
        initialPrompt: 'Build authentication service',
      );

      final rootId = tree.rootNodeId!;

      // Add 3 sibling turns to root
      final branch1 = tree.addMessage(parentId: rootId, role: 'agent', content: 'Turn 1', branchName: 'oauth2');
      final branch2 = tree.addMessage(parentId: rootId, role: 'agent', content: 'Turn 2', branchName: 'cookies');
      tree.addMessage(parentId: rootId, role: 'agent', content: 'Turn 3', branchName: 'jwt');

      final siblings = tree.getSiblingBranches(branch1.id);
      expect(siblings.length, equals(3));

      // Check sibling position (< 1 / 3 >)
      final pos1 = tree.getSiblingPosition(branch1.id);
      expect(pos1.index, equals(0));
      expect(pos1.total, equals(3));

      final pos2 = tree.getSiblingPosition(branch2.id);
      expect(pos2.index, equals(1));
      expect(pos2.total, equals(3));

      // Switch to branch 2 (cookies)
      tree.switchSiblingBranch(rootId, 1);
      final activePath = tree.getActivePath();
      expect(activePath.last.branchName, equals('cookies'));
      expect(activePath.last.id, equals(branch2.id));

      // Switch to branch 3 (jwt)
      tree.switchSiblingBranch(rootId, 2);
      expect(tree.getActivePath().last.branchName, equals('jwt'));
    });

    test('Forks inline alternative branch from intermediate node', () {
      final tree = ConversationTree.createWithRoot(
        environmentId: environmentId,
        initialPrompt: 'Base plan',
        isolationMode: BranchIsolationMode.gitWorktree,
      );

      final step1 = tree.addMessage(parentId: tree.rootNodeId!, role: 'agent', content: 'Step 1 Analysis');
      final step2 = tree.addMessage(parentId: step1.id, role: 'agent', content: 'Step 2 Original Implementation');

      // Fork from step 2
      final forkedNode = tree.forkBranch(
        fromNodeId: step2.id,
        newContent: 'Step 2 Alternative Implementation with Encryption',
        role: 'agent',
        newBranchName: 'encrypted-impl',
      );

      expect(forkedNode.branchName, equals('encrypted-impl'));
      expect(forkedNode.isolationMode, equals(BranchIsolationMode.gitWorktree));
      expect(forkedNode.parentId, equals(step1.id));

      final siblingsAtStep2 = tree.getSiblingBranches(step2.id);
      expect(siblingsAtStep2.length, equals(2));
      expect(siblingsAtStep2.any((n) => n.id == forkedNode.id), isTrue);
    });

    test('Detects 3-way merge conflicts across divergent branches', () {
      final tree = ConversationTree(environmentId: environmentId);

      final baseFiles = {
        'lib/auth.dart': 'void login() { print("legacy"); }',
        'lib/utils.dart': 'const timeout = 30;',
      };

      final branch1Files = {
        'lib/auth.dart': 'void login() { print("oauth2_pkce"); }', // Modified
        'lib/utils.dart': 'const timeout = 30;', // Unmodified
      };

      final branch2Files = {
        'lib/auth.dart': 'void login() { print("session_cookie"); }', // Modified differently -> Conflict!
        'lib/utils.dart': 'const timeout = 30;', // Unmodified
      };

      final conflicts = tree.detectBranchConflicts(
        baseFiles: baseFiles,
        currentBranchFiles: branch1Files,
        targetBranchFiles: branch2Files,
      );

      expect(conflicts.length, equals(1));
      expect(conflicts.first.relativePath, equals('lib/auth.dart'));
      expect(conflicts.first.currentBranchContent, contains('oauth2_pkce'));
      expect(conflicts.first.incomingBranchContent, contains('session_cookie'));
    });
  });
}
