import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class FileDiff {
  final String filePath;
  final List<DiffLine> lines;

  const FileDiff({
    required this.filePath,
    required this.lines,
  });

  factory FileDiff.fromUnifiedDiff(String rawDiff) {
    final lines = rawDiff.split('\n');
    String currentPath = 'unknown_file';
    final diffLines = <DiffLine>[];

    for (final line in lines) {
      if (line.startsWith('+++ b/')) {
        currentPath = line.substring(6).trim();
      } else if (line.startsWith('--- a/')) {
        // Source header
      } else if (line.startsWith('+')) {
        diffLines.add(DiffLine(type: DiffLineType.added, text: line.substring(1)));
      } else if (line.startsWith('-')) {
        diffLines.add(DiffLine(type: DiffLineType.removed, text: line.substring(1)));
      } else if (line.startsWith('@@')) {
        diffLines.add(DiffLine(type: DiffLineType.header, text: line));
      } else {
        diffLines.add(DiffLine(type: DiffLineType.context, text: line.isNotEmpty ? line.substring(1) : ''));
      }
    }

    return FileDiff(filePath: currentPath, lines: diffLines);
  }
}

enum DiffLineType { added, removed, context, header }

class DiffLine {
  final DiffLineType type;
  final String text;

  const DiffLine({required this.type, required this.text});
}

/// Syntax Diff Viewer for rendering file changes produced in the remote sandbox.
class SyntaxDiffViewer extends StatelessWidget {
  final List<FileDiff> diffs;

  const SyntaxDiffViewer({
    super.key,
    required this.diffs,
  });

  @override
  Widget build(BuildContext context) {
    if (diffs.isEmpty) {
      return const Center(
        child: Text(
          'No code diffs available yet.',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: diffs.length,
      itemBuilder: (context, index) {
        final diff = diffs[index];
        return _buildDiffCard(diff);
      },
    );
  }

  Widget _buildDiffCard(FileDiff diff) {
    final additions = diff.lines.where((l) => l.type == DiffLineType.added).length;
    final deletions = diff.lines.where((l) => l.type == DiffLineType.removed).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppTheme.surfaceElevated,
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 16, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    diff.filePath,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.diffAddedBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+$additions',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.diffAddedText,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.diffRemovedBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-$deletions',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.diffRemovedText,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Diff Code Lines
          Container(
            color: AppTheme.terminalBlack,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: diff.lines.map((line) => _buildDiffLine(line)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffLine(DiffLine line) {
    Color bg = Colors.transparent;
    Color textColor = AppTheme.diffContextText;
    String prefix = ' ';

    switch (line.type) {
      case DiffLineType.added:
        bg = AppTheme.diffAddedBg;
        textColor = AppTheme.diffAddedText;
        prefix = '+';
        break;
      case DiffLineType.removed:
        bg = AppTheme.diffRemovedBg;
        textColor = AppTheme.diffRemovedText;
        prefix = '-';
        break;
      case DiffLineType.header:
        bg = AppTheme.surfaceElevated.withOpacity(0.5);
        textColor = const Color(0xFF79C0FF);
        prefix = '@';
        break;
      case DiffLineType.context:
        textColor = const Color(0xFFC9D1D9);
        break;
    }

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Text(
              prefix,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: textColor.withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              line.text,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
