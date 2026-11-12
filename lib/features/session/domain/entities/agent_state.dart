import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Execution states of an autonomous agent in the remote managed sandbox.
enum AgentState {
  idle('Idle', 'Agent is awaiting instructions', Icons.pause_circle_outline, Colors.grey),
  planning('Planning', 'Synthesizing strategy and deep context research', Icons.psychology, AppTheme.statusPlanning),
  executingCode('Executing Code', 'Running code inside remote sandboxed Linux', Icons.terminal, AppTheme.statusExecuting),
  readingLogs('Reading Logs', 'Analyzing compiler errors, traces, and stdout', Icons.receipt_long, AppTheme.statusReadingLogs),
  browserQa('Browser QA', 'Running headless Playwright test suite', Icons.language, AppTheme.statusBrowserQa),
  awaitingApproval('Awaiting Approval', 'Changes ready for local Antigravity sync', Icons.check_circle_outline, AppTheme.accentCyan),
  done('Done', 'Agentic workflow completed successfully', Icons.task_alt, AppTheme.statusSuccess),
  failed('Failed', 'Agent encountered a fatal error', Icons.error_outline, AppTheme.statusFailed);

  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const AgentState(this.label, this.description, this.icon, this.color);

  static AgentState fromString(String? value) {
    if (value == null) return AgentState.idle;
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    for (final state in AgentState.values) {
      final stateNorm = state.name.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
      if (normalized == stateNorm || normalized == state.label.toLowerCase().replaceAll(' ', '')) {
        return state;
      }
    }
    return AgentState.idle;
  }
}
