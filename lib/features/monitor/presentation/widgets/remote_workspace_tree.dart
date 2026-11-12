import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../sync/data/antigravity_sync_service.dart';

/// Interactive file tree widget mirroring the agent's remote `/workspace`.
class RemoteWorkspaceTree extends StatelessWidget {
  final List<RemoteFileEntry> files;
  final void Function(RemoteFileEntry file)? onFileSelected;

  const RemoteWorkspaceTree({
    super.key,
    required this.files,
    this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 36, color: Colors.white24),
            SizedBox(height: 8),
            Text(
              'Remote /workspace is empty.',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppTheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          final isOutput = file.relativePath.startsWith('output/');
          final icon = file.isDirectory
              ? Icons.folder
              : _getFileIcon(file.relativePath);

          return ListTile(
            dense: true,
            leading: Icon(
              icon,
              size: 18,
              color: isOutput ? AppTheme.accentCyan : AppTheme.primaryBlue,
            ),
            title: Text(
              file.relativePath,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: isOutput ? Colors.white : Colors.white70,
                fontWeight: isOutput ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            trailing: !file.isDirectory
                ? Text(
                    _formatBytes(file.sizeBytes),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppTheme.diffContextText,
                    ),
                  )
                : null,
            onTap: () => onFileSelected?.call(file),
          );
        },
      ),
    );
  }

  IconData _getFileIcon(String path) {
    if (path.endsWith('.dart')) return Icons.flutter_dash;
    if (path.endsWith('.py')) return Icons.terminal;
    if (path.endsWith('.json') || path.endsWith('.yaml')) return Icons.settings_ethernet;
    if (path.endsWith('.md')) return Icons.menu_book;
    if (path.endsWith('.png') || path.endsWith('.jpg')) return Icons.image;
    return Icons.insert_drive_file_outlined;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
