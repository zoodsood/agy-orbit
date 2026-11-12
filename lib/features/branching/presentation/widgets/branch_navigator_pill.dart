import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/conversation_tree.dart';

/// Grok-style branch navigator pill: `< 1 / 3 >`.
/// Renders inline at message nodes that have multiple sibling iterations.
/// Allows rapid flipping between branches without losing tree history.
class BranchNavigatorPill extends StatelessWidget {
  final int currentIndex;
  final int totalBranches;
  final String branchName;
  final BranchIsolationMode isolationMode;
  final ValueChanged<int> onBranchSelected;
  final VoidCallback onForkRequested;

  const BranchNavigatorPill({
    super.key,
    required this.currentIndex,
    required this.totalBranches,
    required this.branchName,
    required this.isolationMode,
    required this.onBranchSelected,
    required this.onForkRequested,
  });

  @override
  Widget build(BuildContext context) {
    final hasMultiple = totalBranches > 1;
    final isWorktree = isolationMode == BranchIsolationMode.gitWorktree;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Isolation Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isWorktree
                  ? AppTheme.accentCyan.withOpacity(0.15)
                  : AppTheme.primaryBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isWorktree ? 'WORKTREE' : 'DIR',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isWorktree ? AppTheme.accentCyan : AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Branch Name
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              branchName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Grok-style Navigation: < 1 / 3 >
          if (hasMultiple) ...[
            InkWell(
              onTap: currentIndex > 0 ? () => onBranchSelected(currentIndex - 1) : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.chevron_left,
                  size: 16,
                  color: currentIndex > 0 ? Colors.white : Colors.white24,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${currentIndex + 1} / $totalBranches',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: AppTheme.accentCyan,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: currentIndex < totalBranches - 1
                  ? () => onBranchSelected(currentIndex + 1)
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: currentIndex < totalBranches - 1 ? Colors.white : Colors.white24,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // In-line Fork Button
          InkWell(
            onTap: onForkRequested,
            borderRadius: BorderRadius.circular(12),
            child: const Tooltip(
              message: 'Fork new branch from this node',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_split, size: 14, color: AppTheme.primaryBlue),
                    SizedBox(width: 2),
                    Text(
                      'Fork',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
