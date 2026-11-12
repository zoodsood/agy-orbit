import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// In-Flight Agent Steering / Nudge Dialog.
/// Allows injecting a mid-loop conversational course correction into an active agent run
/// without terminating execution or discarding accumulated reasoning context.
class AgentNudgeDialog extends StatefulWidget {
  final String sessionId;
  final ValueChanged<String> onNudgeSubmitted;

  const AgentNudgeDialog({
    super.key,
    required this.sessionId,
    required this.onNudgeSubmitted,
  });

  @override
  State<AgentNudgeDialog> createState() => _AgentNudgeDialogState();
}

class _AgentNudgeDialogState extends State<AgentNudgeDialog> {
  final TextEditingController _controller = TextEditingController();

  final List<String> _quickNudges = [
    'Focus only on authentication logic; do not modify database schemas.',
    'Keep backwards compatibility with deprecated methods.',
    'Run unit tests after every single file edit.',
    'Reduce verbosity in terminal output.',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Row(
        children: [
          const Icon(Icons.navigation_outlined, color: AppTheme.accentCyan, size: 20),
          const SizedBox(width: 8),
          Text(
            'Steer Active Agent [${widget.sessionId}]',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inject a real-time interrupt turn to correct the agent course without restarting or losing context:',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'e.g., "Skip the integration tests for now, focus on auth_service.dart..."',
                hintStyle: const TextStyle(color: Colors.white38),
                isDense: true,
                filled: true,
                fillColor: AppTheme.terminalBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Quick Nudges:', style: TextStyle(fontSize: 11, color: Colors.white60)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickNudges.map((nudge) {
                return ActionChip(
                  label: Text(
                    nudge,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                  backgroundColor: AppTheme.terminalBlack,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onPressed: () => _controller.text = nudge,
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentCyan,
            foregroundColor: Colors.black,
          ),
          icon: const Icon(Icons.send, size: 16),
          label: const Text('Inject Nudge', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              widget.onNudgeSubmitted(text);
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}
