import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/heartbeat_scheduler.dart';
import '../../domain/entities/heartbeat_task.dart';

/// Heartbeat Scheduler View inspired by OpenClaw.
/// Provides autonomous agent task scheduling, sandbox keepalive pulses,
/// and live heartbeat telemetry logs.
class HeartbeatSchedulerView extends StatefulWidget {
  final HeartbeatScheduler scheduler;

  const HeartbeatSchedulerView({
    super.key,
    required this.scheduler,
  });

  @override
  State<HeartbeatSchedulerView> createState() => _HeartbeatSchedulerViewState();
}

class _HeartbeatSchedulerViewState extends State<HeartbeatSchedulerView> {
  @override
  Widget build(BuildContext context) {
    final isRunning = widget.scheduler.isRunning;
    final tasks = widget.scheduler.tasks;
    final pulseLogs = widget.scheduler.pulseLogs;

    return Container(
      color: AppTheme.terminalBlack,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner & Master Controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isRunning ? AppTheme.statusSuccess.withOpacity(0.4) : Colors.white12,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: isRunning ? AppTheme.statusSuccess : Colors.white38,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Autonomous Heartbeat Engine (OpenClaw-Inspired)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isRunning
                                  ? AppTheme.statusSuccess.withOpacity(0.15)
                                  : Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isRunning ? 'RUNNING' : 'PAUSED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isRunning ? AppTheme.statusSuccess : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Pings Google Managed Sandbox to prevent idling within the 144-hour window '
                        'and runs scheduled background sweeps.',
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRunning ? AppTheme.statusWarning : AppTheme.statusSuccess,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(isRunning ? Icons.pause : Icons.play_arrow, size: 16),
                  label: Text(isRunning ? 'Pause Heartbeat' : 'Start Heartbeat'),
                  onPressed: () {
                    setState(() {
                      if (isRunning) {
                        widget.scheduler.stop();
                      } else {
                        widget.scheduler.start();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Two Panes: Left = Scheduled Tasks, Right = Pulse Telemetry Stream
          Expanded(
            child: Row(
              children: [
                // Scheduled Tasks List
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scheduled Autonomous Tasks',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            itemCount: tasks.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final task = tasks[idx];
                              return _buildTaskTile(task);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Live Pulse Telemetry Log Stream
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.terminalBlack,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history, size: 16, color: AppTheme.accentCyan),
                            const SizedBox(width: 6),
                            const Text(
                              'Heartbeat Pulse History',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const Spacer(),
                            Text(
                              '${pulseLogs.length} events',
                              style: const TextStyle(fontSize: 10, color: Colors.white38),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: pulseLogs.isEmpty
                              ? const Center(
                                  child: Text('No heartbeat pulses recorded yet.', style: TextStyle(fontSize: 11, color: Colors.white38)),
                                )
                              : ListView.separated(
                                  itemCount: pulseLogs.length,
                                  separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 8),
                                  itemBuilder: (ctx, idx) {
                                    final log = pulseLogs[idx];
                                    return _buildLogEntry(log);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(HeartbeatTask task) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.terminalBlack,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Switch(
            value: task.isEnabled,
            activeColor: AppTheme.accentCyan,
            onChanged: (val) {
              setState(() {
                widget.scheduler.toggleTask(task.id, val);
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      task.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Every ${task.interval.inMinutes}m',
                        style: const TextStyle(fontSize: 9, color: AppTheme.accentCyan),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  task.description,
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                ),
                const SizedBox(height: 2),
                Text(
                  'Command: \$ ${task.command}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white38),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: const BorderSide(color: Colors.white24),
            ),
            onPressed: () async {
              await widget.scheduler.runTaskNow(task.id);
              setState(() {});
            },
            child: const Text('Run Now', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(HeartbeatPulseLog log) {
    final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          log.success ? Icons.check_circle : Icons.error_outline,
          size: 14,
          color: log.success ? AppTheme.statusSuccess : AppTheme.statusError,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    log.taskName,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const Spacer(),
                  Text(timeStr, style: const TextStyle(fontSize: 9, color: Colors.white38)),
                ],
              ),
              Text(
                log.message,
                style: const TextStyle(fontSize: 10, color: Colors.white60),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
