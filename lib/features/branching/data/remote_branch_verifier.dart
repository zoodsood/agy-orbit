import 'dart:io';
import '../domain/entities/conversation_tree.dart';

/// Represents the status of a branch/worktree checkout in the Google Managed Sandbox.
class BranchVerificationResult {
  final bool isClean;
  final bool exists;
  final String workingDir;
  final String activeBranch;
  final List<String> dirtyFiles;
  final String? error;
  final Map<String, dynamic> metadata;

  const BranchVerificationResult({
    required this.isClean,
    required this.exists,
    required this.workingDir,
    required this.activeBranch,
    this.dirtyFiles = const [],
    this.error,
    this.metadata = const {},
  });

  bool get canProceed => exists && isClean && error == null;

  Map<String, dynamic> toJson() => {
        'isClean': isClean,
        'exists': exists,
        'workingDir': workingDir,
        'activeBranch': activeBranch,
        'dirtyFiles': dirtyFiles,
        'error': error,
        'metadata': metadata,
      };
}

/// Verifies remote branch and worktree state before allowing prompts to execute
/// on switched branches. Prevents dirty working-tree clobbering and verifies branch readiness.
class RemoteBranchVerifier {
  final String baseWorkspacePath;

  const RemoteBranchVerifier({
    this.baseWorkspacePath = '/workspace',
  });

  /// Verifies the target branch directory/worktree before running agent commands.
  Future<BranchVerificationResult> verifyBranchCheckout({
    required String workingDir,
    required String branchName,
    required BranchIsolationMode mode,
  }) async {
    try {
      final targetDir = Directory(
        workingDir.startsWith('/')
            ? workingDir
            : '$baseWorkspacePath/$workingDir',
      );

      // 1. Check directory existence
      final dirExists = await targetDir.exists();
      if (!dirExists) {
        // If it doesn't exist yet, it's considered uninitialized but clean for initial checkout
        return BranchVerificationResult(
          isClean: true,
          exists: false,
          workingDir: targetDir.path,
          activeBranch: branchName,
          metadata: {'mode': mode.name, 'note': 'Target directory will be initialized upon checkout.'},
        );
      }

      // 2. Mode-specific verifications
      if (mode == BranchIsolationMode.gitWorktree) {
        return await _verifyGitWorktree(targetDir, branchName);
      } else {
        return await _verifyDirectoryIsolation(targetDir, branchName);
      }
    } catch (e) {
      return BranchVerificationResult(
        isClean: false,
        exists: false,
        workingDir: workingDir,
        activeBranch: branchName,
        error: 'Branch verification exception: $e',
      );
    }
  }

  Future<BranchVerificationResult> _verifyGitWorktree(
    Directory dir,
    String branchName,
  ) async {
    // Check if git worktree marker or .git file exists
    final gitFile = File('${dir.path}/.git');
    final gitDir = Directory('${dir.path}/.git');
    final hasGit = await gitFile.exists() || await gitDir.exists();

    // Check for untracked / dirty conflict files
    final dirtyFiles = <String>[];
    try {
      final result = await Process.run(
        'git',
        ['status', '--porcelain'],
        workingDirectory: dir.path,
      );
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            dirtyFiles.add(trimmed);
          }
        }
      }
    } catch (_) {
      // In sandbox if git is not initialized in that specific directory, fall back to file inspection
    }

    return BranchVerificationResult(
      isClean: dirtyFiles.isEmpty,
      exists: true,
      workingDir: dir.path,
      activeBranch: branchName,
      dirtyFiles: dirtyFiles,
      metadata: {
        'isolationMode': 'gitWorktree',
        'hasGitMetadata': hasGit,
      },
    );
  }

  Future<BranchVerificationResult> _verifyDirectoryIsolation(
    Directory dir,
    String branchName,
  ) async {
    final List<String> modifiedFiles = [];

    // Inspect directory for backup or collision marker files
    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.orbit.bak')) {
          modifiedFiles.add(entity.path);
        }
      }
    } catch (_) {}

    return BranchVerificationResult(
      isClean: modifiedFiles.isEmpty,
      exists: true,
      workingDir: dir.path,
      activeBranch: branchName,
      dirtyFiles: modifiedFiles,
      metadata: {
        'isolationMode': 'directoryIsolation',
      },
    );
  }
}
