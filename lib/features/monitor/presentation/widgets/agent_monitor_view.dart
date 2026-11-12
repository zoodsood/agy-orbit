import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../session/domain/entities/agent_state.dart';

/// Agent Monitor View displaying current agent execution states:
/// Planning, Executing Code, Reading Logs, Browser QA, Done.
class AgentMonitorView extends StatelessWidget {
  final AgentState currentState;
  final String modelName;
  final String sessionId;
  final Duration elapsed;
  final VoidCallback? onCancel;

  const AgentMonitorView({
    super.key,
    required this.currentState,
    required this.modelName,
    required this.sessionId,
    required this.elapsed,
    this.onCancel,
  });

  static const List<AgentState> pipelineStages = [
    AgentState.planning,
    AgentState.executingCode,
    AgentState.readingLogs,
    AgentState.browserQa,
    AgentState.done,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Session ID, Model Badge, Elapsed Timer
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  'AGY: $sessionId',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF0F6FC),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                ),
                child: Text(
                  modelName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.timer_outlined, size: 14, color: AppTheme.diffContextText),
              const SizedBox(width: 4),
              Text(
                _formatDuration(elapsed),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppTheme.diffContextText,
                ),
              ),
              if (currentState != AgentState.done && currentState != AgentState.idle && onCancel != null) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.statusFailed.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Stop Agent',
                      style: TextStyle(fontSize: 11, color: AppTheme.statusFailed),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Pipeline Status Badges
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: pipelineStages.map((stage) {
                final isCurrent = stage == currentState;
                final isPassed = _stageOrder(stage) < _stageOrder(currentState);
                final color = isCurrent
                    ? stage.color
                    : (isPassed ? AppTheme.statusSuccess : Colors.white24);

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? stage.color.withOpacity(0.15)
                            : (isPassed ? AppTheme.surfaceElevated : Colors.transparent),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCurrent ? stage.color : (isPassed ? Colors.white24 : Colors.white10),
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isCurrent && stage != AgentState.done) ...[
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: stage.color,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ] else ...[
                            Icon(
                              isPassed ? Icons.check : stage.icon,
                              size: 14,
                              color: color,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            stage.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isCurrent ? Colors.white : (isPassed ? Colors.white70 : Colors.white38),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (stage != pipelineStages.last) ...[
                      Container(
                        width: 16,
                        height: 2,
                        color: isPassed ? AppTheme.statusSuccess.withOpacity(0.4) : Colors.white12,
                      ),
                    ],
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  int _stageOrder(AgentState state) {
    switch (state) {
      case AgentState.idle:
        return -1;
      case AgentState.planning:
        return 0;
      case AgentState.executingCode:
        return 1;
      case AgentState.readingLogs:
        return 2;
      case AgentState.browserQa:
        return 3;
      case AgentState.awaitingApproval:
      case AgentState.done:
        return 4;
      case AgentState.failed:
        return 99;
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds';
  }
}
