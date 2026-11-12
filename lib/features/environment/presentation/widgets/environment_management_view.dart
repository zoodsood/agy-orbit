import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/environment_resource_governor.dart';
import '../../domain/entities/managed_environment.dart';

/// Environment Management View displaying Google Managed Linux Sandboxes,
/// tracking the 144-Hour lifecycle limit and enforcing gVisor resource safety.
class EnvironmentManagementView extends StatefulWidget {
  final List<ManagedEnvironment> environments;
  final ValueChanged<ManagedEnvironment> onSelectEnvironment;
  final VoidCallback onCreateNewEnvironment;

  const EnvironmentManagementView({
    super.key,
    required this.environments,
    required this.onSelectEnvironment,
    required this.onCreateNewEnvironment,
  });

  @override
  State<EnvironmentManagementView> createState() => _EnvironmentManagementViewState();
}

class _EnvironmentManagementViewState extends State<EnvironmentManagementView> {
  final EnvironmentResourceGovernor _governor = EnvironmentResourceGovernor();
  String? _feedbackMessage;

  void _pruneEnvironmentDisk(ManagedEnvironment env) async {
    final freedBytes = await _governor.performAutoPrune('/tmp');
    final freedMb = freedBytes / (1024 * 1024);
    setState(() {
      env.diskUsageMb = (env.diskUsageMb - freedMb).clamp(500.0, 6144.0);
      _feedbackMessage = 'Cleaned ${freedMb.toStringAsFixed(1)} MB of temporary compiler artifacts for ${env.id}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.terminalBlack,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_queue, color: AppTheme.primaryBlue, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Managed Agent Environments (144-Hour Technical Limit)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Remote gVisor Linux sandboxes are retained up to 144 hours (6 days) from last message. '
                        'Resource ceilings: CPU < 80%, RAM < 12GB, Disk < 6GB.',
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Environment'),
                  onPressed: widget.onCreateNewEnvironment,
                ),
              ],
            ),
          ),
          if (_feedbackMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.statusSuccess.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.statusSuccess),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.statusSuccess, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_feedbackMessage!, style: const TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                  InkWell(
                    onTap: () => setState(() => _feedbackMessage = null),
                    child: const Icon(Icons.close, size: 14, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Environment Cards List
          Expanded(
            child: ListView.separated(
              itemCount: widget.environments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final env = widget.environments[idx];
                final report = _governor.assessEnvironment(env);
                return _buildEnvironmentCard(env, report);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard(ManagedEnvironment env, ResourceHealthReport report) {
    final isExpired = env.isExpired;
    final isExpiringSoon = env.isExpiringSoon;
    final remainingHours = env.timeRemaining.inHours;
    final remainingMinutes = env.timeRemaining.inMinutes % 60;

    final Color statusColor = isExpired
        ? AppTheme.statusError
        : (isExpiringSoon ? AppTheme.statusWarning : AppTheme.statusSuccess);

    final double progressFraction = (env.timeRemaining.inMinutes / (144 * 60)).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExpired ? AppTheme.statusError.withOpacity(0.4) : Colors.white12,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.terminalBlack,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  env.id,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentCyan,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                env.displayName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      env.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Retention Countdown Progress Bar
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: Colors.white60),
              const SizedBox(width: 6),
              Text(
                isExpired
                    ? 'Retention limit reached (>144 hours elapsed). Sandbox purged.'
                    : '$remainingHours h $remainingMinutes m remaining before Google 144-hour purge',
                style: TextStyle(
                  fontSize: 12,
                  color: isExpired ? AppTheme.statusError : Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressFraction,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),

          // Resource Usage Gauges (CPU < 80%, RAM < 12GB, Disk < 6GB)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.terminalBlack,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildResourceMeter(
                    label: 'CPU Usage',
                    valueStr: '${env.cpuUsagePercent.toStringAsFixed(1)}%',
                    limitStr: '< 80%',
                    fraction: (env.cpuUsagePercent / 80.0).clamp(0.0, 1.0),
                    isCritical: report.isCpuCritical,
                    isWarning: report.isCpuWarning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildResourceMeter(
                    label: 'Memory',
                    valueStr: '${(env.memoryUsageMb / 1024).toStringAsFixed(1)} GB',
                    limitStr: '< 12 GB',
                    fraction: (env.memoryUsageMb / 12288.0).clamp(0.0, 1.0),
                    isCritical: report.isMemoryCritical,
                    isWarning: report.isMemoryWarning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildResourceMeter(
                    label: 'Disk Spool',
                    valueStr: '${(env.diskUsageMb / 1024).toStringAsFixed(1)} GB',
                    limitStr: '< 6 GB',
                    fraction: (env.diskUsageMb / 6144.0).clamp(0.0, 1.0),
                    isCritical: report.isDiskCritical,
                    isWarning: report.isDiskWarning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Text(
                'Linked Sessions: ${env.linkedSessionIds.length} | Last Active: ${env.lastActiveAt.month}/${env.lastActiveAt.day} ${env.lastActiveAt.hour.toString().padLeft(2, '0')}:${env.lastActiveAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.cleaning_services_outlined, size: 14),
                label: const Text('Prune Caches', style: TextStyle(fontSize: 12)),
                onPressed: () => _pruneEnvironmentDisk(env),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpired ? Colors.white12 : AppTheme.primaryBlue,
                  foregroundColor: isExpired ? Colors.white38 : Colors.white,
                ),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: Text(
                  isExpired ? 'Retention Expired (>144h)' : 'Start Conversation in this Environment',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: isExpired ? null : () => widget.onSelectEnvironment(env),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResourceMeter({
    required String label,
    required String valueStr,
    required String limitStr,
    required double fraction,
    required bool isCritical,
    required bool isWarning,
  }) {
    final color = isCritical
        ? AppTheme.statusError
        : (isWarning ? AppTheme.statusWarning : AppTheme.accentCyan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
            Text('$valueStr ($limitStr)', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
