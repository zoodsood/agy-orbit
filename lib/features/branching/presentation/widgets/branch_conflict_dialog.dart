import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/conversation_tree.dart';

/// 3-Way Visual Conflict Resolution Dialog for branch merging.
/// Fully responsive: displays 3 side-by-side panes on desktop (>=720px),
/// and a segmented pane switcher on narrower or mobile screens (<720px).
class BranchConflictDialog extends StatefulWidget {
  final List<BranchFileConflict> conflicts;
  final ValueChanged<List<BranchFileConflict>> onResolved;

  const BranchConflictDialog({
    super.key,
    required this.conflicts,
    required this.onResolved,
  });

  @override
  State<BranchConflictDialog> createState() => _BranchConflictDialogState();
}

class _BranchConflictDialogState extends State<BranchConflictDialog> {
  int _selectedConflictIndex = 0;
  late final List<BranchFileConflict> _conflictList;
  // Active view tab for narrow/mobile screens: 0: Ours, 1: Base, 2: Theirs
  int _mobileActivePaneIndex = 0;

  @override
  void initState() {
    super.initState();
    _conflictList = List.from(widget.conflicts);
  }

  void _resolveCurrent(String resolutionType) {
    if (_conflictList.isEmpty) return;
    final current = _conflictList[_selectedConflictIndex];

    String resolved;
    if (resolutionType == 'ours') {
      resolved = current.currentBranchContent;
    } else if (resolutionType == 'theirs') {
      resolved = current.incomingBranchContent;
    } else {
      // Merge both with delimiters
      resolved = '<<<<<<< CURRENT (${current.relativePath})\n'
          '${current.currentBranchContent}\n'
          '=======\n'
          '${current.incomingBranchContent}\n'
          '>>>>>>> INCOMING\n';
    }

    setState(() {
      current.resolvedContent = resolved;
      current.isResolved = true;
      if (_selectedConflictIndex < _conflictList.length - 1) {
        _selectedConflictIndex++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_conflictList.isEmpty) {
      return AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('No Conflicts Detected'),
        content: const Text('Branches can be cleanly merged without manual resolution.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    final current = _conflictList[_selectedConflictIndex];
    final allResolved = _conflictList.every((c) => c.isResolved);

    return Dialog(
      backgroundColor: AppTheme.surfaceElevated,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final dialogWidth = constraints.maxWidth.clamp(320.0, 960.0);
          final dialogHeight = constraints.maxHeight.clamp(400.0, 680.0);

          return Container(
            width: dialogWidth,
            height: dialogHeight,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.merge_type, color: AppTheme.statusWarning, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '3-Way Conflict Resolver (${_selectedConflictIndex + 1}/${_conflictList.length})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Conflicted File: ${current.relativePath}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppTheme.accentCyan,
                  ),
                ),
                const SizedBox(height: 10),

                // If on narrow layout, show segmented toggle bar
                if (!isWide) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              label: Text('Ours', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.person, size: 14),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text('Base', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.history, size: 14),
                            ),
                            ButtonSegment(
                              value: 2,
                              label: Text('Theirs', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.cloud_download, size: 14),
                            ),
                          ],
                          selected: {_mobileActivePaneIndex},
                          onSelectionChanged: (newSelection) {
                            setState(() => _mobileActivePaneIndex = newSelection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Comparison View (3-pane if wide, single segmented pane if narrow)
                Expanded(
                  child: isWide
                      ? Row(
                          children: [
                            // Ours
                            Expanded(
                              child: _buildCodePane(
                                title: 'Current Branch (Ours)',
                                color: AppTheme.primaryBlue,
                                code: current.currentBranchContent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Base
                            Expanded(
                              child: _buildCodePane(
                                title: 'Common Ancestor (Base)',
                                color: Colors.white38,
                                code: current.baseContent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Theirs
                            Expanded(
                              child: _buildCodePane(
                                title: 'Incoming Branch (Theirs)',
                                color: AppTheme.accentCyan,
                                code: current.incomingBranchContent,
                              ),
                            ),
                          ],
                        )
                      : _buildNarrowActivePane(current),
                ),
                const SizedBox(height: 12),

                // Responsive Resolution Action Buttons (Wrap)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.check, size: 15),
                          label: const Text('Keep Ours', style: TextStyle(fontSize: 11)),
                          onPressed: () => _resolveCurrent('ours'),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 15),
                          label: const Text('Accept Theirs', style: TextStyle(fontSize: 11)),
                          onPressed: () => _resolveCurrent('theirs'),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.call_merge, size: 15),
                          label: const Text('Combine Both', style: TextStyle(fontSize: 11)),
                          onPressed: () => _resolveCurrent('both'),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: allResolved ? AppTheme.statusSuccess : Colors.white24,
                      ),
                      onPressed: allResolved
                          ? () {
                              widget.onResolved(_conflictList);
                              Navigator.of(context).pop();
                            }
                          : null,
                      child: Text(
                        allResolved ? 'Apply All Resolutions' : 'Resolve all (${_conflictList.where((c) => c.isResolved).length}/${_conflictList.length})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNarrowActivePane(BranchFileConflict current) {
    if (_mobileActivePaneIndex == 0) {
      return _buildCodePane(
        title: 'Current Branch (Ours)',
        color: AppTheme.primaryBlue,
        code: current.currentBranchContent,
      );
    } else if (_mobileActivePaneIndex == 1) {
      return _buildCodePane(
        title: 'Common Ancestor (Base)',
        color: Colors.white38,
        code: current.baseContent,
      );
    } else {
      return _buildCodePane(
        title: 'Incoming Branch (Theirs)',
        color: AppTheme.accentCyan,
        code: current.incomingBranchContent,
      );
    }
  }

  Widget _buildCodePane({required String title, required Color color, required String code}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.terminalBlack,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: color.withOpacity(0.1),
            child: Text(
              title,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Text(
                code.isEmpty ? '<empty file>' : code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
