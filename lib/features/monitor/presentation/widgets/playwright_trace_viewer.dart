import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PlaywrightTestStep {
  final String title;
  final String action; // e.g., "page.goto", "page.click", "expect.toBeVisible"
  final Duration duration;
  final bool passed;
  final String? errorMessage;
  final String? screenshotUrl;

  const PlaywrightTestStep({
    required this.title,
    required this.action,
    required this.duration,
    required this.passed,
    this.errorMessage,
    this.screenshotUrl,
  });
}

/// Headless Playwright browser test results and trace viewer.
class PlaywrightTraceViewer extends StatelessWidget {
  final List<PlaywrightTestStep> steps;
  final bool isRunning;

  const PlaywrightTraceViewer({
    super.key,
    required this.steps,
    this.isRunning = false,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.language, size: 40, color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              isRunning ? 'Playwright browser QA tests in progress...' : 'No browser QA traces recorded.',
              style: const TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    final totalPassed = steps.where((s) => s.passed).length;
    final totalFailed = steps.where((s) => !s.passed).length;

    return Column(
      children: [
        // QA Summary Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.surfaceElevated,
          child: Row(
            children: [
              const Text(
                'Playwright QA Suite',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.statusSuccess.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$totalPassed Passed',
                  style: const TextStyle(
                    color: AppTheme.statusSuccess,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (totalFailed > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.statusFailed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$totalFailed Failed',
                    style: const TextStyle(
                      color: AppTheme.statusFailed,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Steps List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        step.passed ? Icons.check_circle : Icons.cancel,
                        color: step.passed ? AppTheme.statusSuccess : AppTheme.statusFailed,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  step.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${step.duration.inMilliseconds}ms',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: AppTheme.diffContextText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.action,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                color: Color(0xFF79C0FF),
                              ),
                            ),
                            if (step.errorMessage != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusFailed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  step.errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.statusFailed,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
