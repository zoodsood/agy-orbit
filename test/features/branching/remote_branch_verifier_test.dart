import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/features/branching/data/remote_branch_verifier.dart';
import 'package:antigravity_flutter/features/branching/domain/entities/conversation_tree.dart';

void main() {
  group('RemoteBranchVerifier Tests', () {
    late Directory tempDir;
    late RemoteBranchVerifier verifier;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('branch_verifier_test_');
      verifier = RemoteBranchVerifier(baseWorkspacePath: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Verifies clean state for uninitialized target branch', () async {
      final result = await verifier.verifyBranchCheckout(
        workingDir: 'branches/new-feature',
        branchName: 'new-feature',
        mode: BranchIsolationMode.directoryIsolation,
      );

      expect(result.exists, isFalse);
      expect(result.isClean, isTrue);
      expect(result.canProceed, isFalse); // not yet created on disk, but clean
      expect(result.activeBranch, 'new-feature');
    });

    test('Identifies dirty backup files in directory isolation mode', () async {
      final targetDir = Directory('${tempDir.path}/main');
      await targetDir.create(recursive: true);

      // Create a clean file and a dirty collision backup file
      final normalFile = File('${targetDir.path}/lib.dart');
      await normalFile.writeAsString('void main() {}');

      final backupFile = File('${targetDir.path}/lib.dart.orbit.bak');
      await backupFile.writeAsString('backup copy');

      final result = await verifier.verifyBranchCheckout(
        workingDir: 'main',
        branchName: 'main',
        mode: BranchIsolationMode.directoryIsolation,
      );

      expect(result.exists, isTrue);
      expect(result.isClean, isFalse); // Dirty because of .orbit.bak file
      expect(result.dirtyFiles.length, 1);
      expect(result.dirtyFiles.first.contains('.orbit.bak'), isTrue);
    });

    test('Verifies clean directory isolation when no backup files exist', () async {
      final targetDir = Directory('${tempDir.path}/clean-branch');
      await targetDir.create(recursive: true);

      final normalFile = File('${targetDir.path}/service.dart');
      await normalFile.writeAsString('class Service {}');

      final result = await verifier.verifyBranchCheckout(
        workingDir: 'clean-branch',
        branchName: 'clean-branch',
        mode: BranchIsolationMode.directoryIsolation,
      );

      expect(result.exists, isTrue);
      expect(result.isClean, isTrue);
      expect(result.canProceed, isTrue);
      expect(result.dirtyFiles.isEmpty, isTrue);
    });
  });
}
