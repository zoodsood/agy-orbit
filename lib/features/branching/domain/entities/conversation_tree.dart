/// Strategy used to isolate agent code modifications across concurrent branches
/// within the same remote Google Managed Environment.
enum BranchIsolationMode {
  /// Separate subdirectory for each branch (e.g. `main/`, `branches/branch-1/`).
  directoryIsolation,

  /// Isolated Git Worktree with independent working tree and index (e.g. `git worktree add .worktrees/branch-1`).
  gitWorktree,
}

/// A node in a Grok-style branching conversation tree.
class BranchNode {
  final String id;
  final String? parentId;
  final String role; // 'user' or 'agent'
  final String content;
  final DateTime timestamp;
  final String environmentId; // Shared remote environment ID across all sibling branches
  final String branchName;
  final BranchIsolationMode isolationMode;
  final String workingDirectory;
  final String? worktreeBranch;
  final List<String> childrenIds;
  int selectedChildIndex;
  final Map<String, dynamic> metadata;
  final String? diffContent;

  BranchNode({
    required this.id,
    this.parentId,
    required this.role,
    required this.content,
    DateTime? timestamp,
    required this.environmentId,
    this.branchName = 'main',
    this.isolationMode = BranchIsolationMode.directoryIsolation,
    required this.workingDirectory,
    this.worktreeBranch,
    List<String>? childrenIds,
    this.selectedChildIndex = 0,
    Map<String, dynamic>? metadata,
    this.diffContent,
  })  : timestamp = timestamp ?? DateTime.now(),
        childrenIds = childrenIds ?? [],
        metadata = metadata ?? {};

  BranchNode copyWith({
    String? content,
    String? branchName,
    BranchIsolationMode? isolationMode,
    String? workingDirectory,
    String? worktreeBranch,
    List<String>? childrenIds,
    int? selectedChildIndex,
    Map<String, dynamic>? metadata,
    String? diffContent,
  }) {
    return BranchNode(
      id: id,
      parentId: parentId,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      environmentId: environmentId,
      branchName: branchName ?? this.branchName,
      isolationMode: isolationMode ?? this.isolationMode,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      worktreeBranch: worktreeBranch ?? this.worktreeBranch,
      childrenIds: childrenIds ?? List.from(this.childrenIds),
      selectedChildIndex: selectedChildIndex ?? this.selectedChildIndex,
      metadata: metadata ?? Map.from(this.metadata),
      diffContent: diffContent ?? this.diffContent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentId': parentId,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'environmentId': environmentId,
      'branchName': branchName,
      'isolationMode': isolationMode.name,
      'workingDirectory': workingDirectory,
      'worktreeBranch': worktreeBranch,
      'childrenIds': childrenIds,
      'selectedChildIndex': selectedChildIndex,
      'metadata': metadata,
      'diffContent': diffContent,
    };
  }

  factory BranchNode.fromJson(Map<String, dynamic> json) {
    return BranchNode(
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : null,
      environmentId: json['environmentId'] as String? ?? 'env-default',
      branchName: json['branchName'] as String? ?? 'main',
      isolationMode: BranchIsolationMode.values.firstWhere(
        (e) => e.name == json['isolationMode'],
        orElse: () => BranchIsolationMode.directoryIsolation,
      ),
      workingDirectory: json['workingDirectory'] as String? ?? 'main/',
      worktreeBranch: json['worktreeBranch'] as String?,
      childrenIds: (json['childrenIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      selectedChildIndex: json['selectedChildIndex'] as int? ?? 0,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      diffContent: json['diffContent'] as String?,
    );
  }
}

/// Represents a detected merge conflict between two branches modifying the same file.
class BranchFileConflict {
  final String relativePath;
  final String baseContent;
  final String currentBranchContent; // "Ours"
  final String incomingBranchContent; // "Theirs"
  String? resolvedContent;
  bool isResolved;

  BranchFileConflict({
    required this.relativePath,
    required this.baseContent,
    required this.currentBranchContent,
    required this.incomingBranchContent,
    this.resolvedContent,
    this.isResolved = false,
  });
}

/// Non-linear Grok-style conversation tree with per-message thread branching.
/// The isolation mode is locked per conversation (Directory Isolation or Git Worktree)
/// so that concurrent branches cannot switch on the fly and stay safely off the main thread.
/// Network allowlist is set to `['*']` by default for all conversations and subthreads.
class ConversationTree {
  final String environmentId;
  final BranchIsolationMode isolationMode;
  final List<String> networkAllowlist;
  String? rootNodeId;
  final Map<String, BranchNode> nodes = {};
  String? activeLeafNodeId;

  ConversationTree({
    required this.environmentId,
    this.isolationMode = BranchIsolationMode.directoryIsolation,
    this.networkAllowlist = const ['*'],
    this.rootNodeId,
  });

  /// Creates a conversation tree initialized with a root user prompt.
  /// Locks the isolationMode for the entire conversation.
  factory ConversationTree.createWithRoot({
    required String environmentId,
    required String initialPrompt,
    String branchName = 'main',
    BranchIsolationMode isolationMode = BranchIsolationMode.directoryIsolation,
    List<String> networkAllowlist = const ['*'],
  }) {
    final tree = ConversationTree(
      environmentId: environmentId,
      isolationMode: isolationMode,
      networkAllowlist: networkAllowlist,
    );
    const rootId = 'node-root-0';
    final workingDir = isolationMode == BranchIsolationMode.gitWorktree
        ? '.worktrees/main/'
        : 'main/';

    final rootNode = BranchNode(
      id: rootId,
      parentId: null,
      role: 'user',
      content: initialPrompt,
      environmentId: environmentId,
      branchName: branchName,
      isolationMode: isolationMode,
      workingDirectory: workingDir,
      worktreeBranch: isolationMode == BranchIsolationMode.gitWorktree ? 'orbit/main' : null,
      metadata: {'networkAllowlist': networkAllowlist},
    );

    tree.nodes[rootId] = rootNode;
    tree.rootNodeId = rootId;
    tree.activeLeafNodeId = rootId;
    return tree;
  }

  /// Adds a message node attached to [parentId].
  /// Strictly inherits the conversation's locked [isolationMode].
  BranchNode addMessage({
    required String parentId,
    required String role,
    required String content,
    String? branchName,
    String? diffContent,
    Map<String, dynamic>? metadata,
  }) {
    final parent = nodes[parentId];
    if (parent == null) {
      throw ArgumentError('Parent node $parentId does not exist in ConversationTree.');
    }

    final nodeId = 'node-${DateTime.now().millisecondsSinceEpoch}-${nodes.length}';
    final effectiveBranchName = branchName ?? parent.branchName;

    // Strict inheritance of the conversation's isolation mode
    final workingDir = isolationMode == BranchIsolationMode.gitWorktree
        ? '.worktrees/$effectiveBranchName/'
        : (effectiveBranchName == 'main' ? 'main/' : 'branches/$effectiveBranchName/');

    final effectiveMetadata = Map<String, dynamic>.from(metadata ?? {});
    effectiveMetadata['networkAllowlist'] = networkAllowlist;

    final newNode = BranchNode(
      id: nodeId,
      parentId: parentId,
      role: role,
      content: content,
      environmentId: environmentId,
      branchName: effectiveBranchName,
      isolationMode: isolationMode,
      workingDirectory: workingDir,
      worktreeBranch: isolationMode == BranchIsolationMode.gitWorktree
          ? 'orbit/$effectiveBranchName'
          : null,
      diffContent: diffContent,
      metadata: effectiveMetadata,
    );

    nodes[nodeId] = newNode;
    parent.childrenIds.add(nodeId);
    parent.selectedChildIndex = parent.childrenIds.length - 1;
    activeLeafNodeId = nodeId;
    return newNode;
  }

  /// Forks an alternative sibling branch from [fromNodeId].
  /// Sibling subthreads strictly inherit the conversation's [isolationMode] and network allowlist.
  BranchNode forkBranch({
    required String fromNodeId,
    required String newContent,
    required String role,
    required String newBranchName,
    String? diffContent,
  }) {
    final targetNode = nodes[fromNodeId];
    if (targetNode == null) {
      throw ArgumentError('Target node $fromNodeId not found for branch forking.');
    }

    final parentId = targetNode.parentId;
    if (parentId == null) {
      // Forking from root creates a root sibling turn
      return addMessage(
        parentId: fromNodeId,
        role: role,
        content: newContent,
        branchName: newBranchName,
        diffContent: diffContent,
      );
    }

    return addMessage(
      parentId: parentId,
      role: role,
      content: newContent,
      branchName: newBranchName,
      diffContent: diffContent,
    );
  }

  /// Returns the current active path of nodes from root down to active leaf.
  List<BranchNode> getActivePath() {
    if (rootNodeId == null || !nodes.containsKey(rootNodeId)) return [];

    final List<BranchNode> path = [];
    BranchNode? current = nodes[rootNodeId];

    while (current != null) {
      path.add(current);
      if (current.childrenIds.isEmpty) break;

      final selectedIndex = current.selectedChildIndex.clamp(0, current.childrenIds.length - 1);
      final nextChildId = current.childrenIds[selectedIndex];
      current = nodes[nextChildId];
    }

    return path;
  }

  /// Returns sibling branch nodes available at a given node's parent level.
  List<BranchNode> getSiblingBranches(String nodeId) {
    final node = nodes[nodeId];
    if (node == null || node.parentId == null) {
      return node != null ? [node] : [];
    }
    final parent = nodes[node.parentId];
    if (parent == null) return [node];

    return parent.childrenIds.map((id) => nodes[id]!).toList();
  }

  /// Gets the 0-indexed position and total siblings for a node: `(index, total)`.
  ({int index, int total}) getSiblingPosition(String nodeId) {
    final node = nodes[nodeId];
    if (node == null || node.parentId == null) return (index: 0, total: 1);
    final parent = nodes[node.parentId];
    if (parent == null) return (index: 0, total: 1);

    final idx = parent.childrenIds.indexOf(nodeId);
    return (index: idx >= 0 ? idx : 0, total: parent.childrenIds.length);
  }

  /// Switches active sibling branch at [parentId] to [targetIndex].
  void switchSiblingBranch(String parentId, int targetIndex) {
    final parent = nodes[parentId];
    if (parent == null || parent.childrenIds.isEmpty) return;
    if (targetIndex < 0 || targetIndex >= parent.childrenIds.length) return;

    parent.selectedChildIndex = targetIndex;
    // Walk down to the leaf of this newly selected branch
    var current = nodes[parent.childrenIds[targetIndex]];
    while (current != null && current.childrenIds.isNotEmpty) {
      final childIdx = current.selectedChildIndex.clamp(0, current.childrenIds.length - 1);
      current = nodes[current.childrenIds[childIdx]];
    }
    if (current != null) {
      activeLeafNodeId = current.id;
    }
  }

  /// Analyzes file states between two branches to detect 3-way merge conflicts.
  List<BranchFileConflict> detectBranchConflicts({
    required Map<String, String> baseFiles,
    required Map<String, String> currentBranchFiles,
    required Map<String, String> targetBranchFiles,
  }) {
    final List<BranchFileConflict> conflicts = [];
    final allKeys = {
      ...baseFiles.keys,
      ...currentBranchFiles.keys,
      ...targetBranchFiles.keys,
    };

    for (final path in allKeys) {
      final base = baseFiles[path] ?? '';
      final ours = currentBranchFiles[path] ?? '';
      final theirs = targetBranchFiles[path] ?? '';

      // Conflict occurs when both branches changed the file from base differently
      if (ours != base && theirs != base && ours != theirs) {
        conflicts.add(BranchFileConflict(
          relativePath: path,
          baseContent: base,
          currentBranchContent: ours,
          incomingBranchContent: theirs,
        ));
      }
    }
    return conflicts;
  }
}
