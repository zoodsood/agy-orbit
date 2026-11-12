import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/antigravity_sync_service.dart';

/// Modal dialog prompting user to review and approve downsyncing
/// remote `/workspace/output` artifacts into `AGY-{SessionID}-workspace`.
class SyncApprovalDialog extends StatelessWidget {
  final String sessionId;
  final List<RemoteFileEntry> modifiedFiles;
  final String targetPath;
  final VoidCallback onApprove;

  const SyncApprovalDialog({
    super.key,
    required this.sessionId,
    required this.modifiedFiles,
    required this.targetPath,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final workspaceName = 'AGY-$sessionId-workspace';

    return AlertDialog(
      backgroundColor: AppTheme.surfaceElevated,
      title: const Row(
        children: [
          Icon(Icons.sync_alt, color: AppTheme.accentCyan, size: 22),
          SizedBox(width: 10),
          Text('Antigravity Sync Approval', style: TextStyle(fontSize: 16)),
        ],
      ),

      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The autonomous agent has finished executing code and verified tests. '
              'Approve downsyncing modified artifacts into your local filesystem:',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.terminalBlack,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 16, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$targetPath/$workspaceName',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Files to downsync (${modifiedFiles.length}):',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: modifiedFiles.length,
                itemBuilder: (context, index) {
                  final f = modifiedFiles[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.check, size: 14, color: AppTheme.accentCyan),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            f.relativePath,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentCyan,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onApprove();
          },
          child: const Text('Accept & Sync to Local'),
        ),
      ],
    );
  }
}
