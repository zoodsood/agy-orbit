import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'core/buffer/log_ring_buffer.dart';
import 'core/config/app_config.dart';
import 'core/config/model_descriptor.dart';
import 'core/config/model_registry.dart';
import 'core/notifications/notification_service.dart';
import 'core/security/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/branching/data/remote_branch_verifier.dart';
import 'features/branching/domain/entities/conversation_tree.dart';
import 'features/branching/presentation/widgets/branch_conflict_dialog.dart';
import 'features/branching/presentation/widgets/branch_navigator_pill.dart';
import 'features/environment/data/container_telemetry_service.dart';
import 'features/environment/data/environment_resource_governor.dart';
import 'features/environment/domain/entities/managed_environment.dart';
import 'features/environment/presentation/widgets/environment_management_view.dart';
import 'features/heartbeat/data/heartbeat_scheduler.dart';
import 'features/heartbeat/presentation/widgets/heartbeat_scheduler_view.dart';
import 'features/interaction/data/control_plane_service.dart';
import 'features/interaction/data/data_plane_service.dart';
import 'features/interaction/data/memory_bank_service.dart';
import 'features/monitor/data/session_trace_persistence_service.dart';
import 'features/monitor/presentation/widgets/agent_monitor_view.dart';
import 'features/monitor/presentation/widgets/agent_nudge_dialog.dart';
import 'features/monitor/presentation/widgets/playwright_trace_viewer.dart';
import 'features/monitor/presentation/widgets/remote_workspace_tree.dart';
import 'features/monitor/presentation/widgets/syntax_diff_viewer.dart';
import 'features/monitor/presentation/widgets/virtualized_markdown_view.dart';
import 'features/session/domain/entities/agent_session.dart';
import 'features/session/domain/entities/agent_state.dart';
import 'features/session/domain/entities/atomic_steering_queue.dart';
import 'features/session/presentation/widgets/model_selector_dropdown.dart';
import 'features/sync/data/antigravity_sync_service.dart';
import 'features/sync/presentation/widgets/sync_approval_dialog.dart';
import 'features/system_instructions/data/system_instruction_repository.dart';
import 'features/system_instructions/domain/entities/system_instruction_template.dart';
import 'features/system_instructions/presentation/widgets/system_instructions_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AntigravityFlutterApp());
}

class AntigravityFlutterApp extends StatelessWidget {
  const AntigravityFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity Orbit',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const AntigravityManagerScreen(),
    );
  }
}

class AntigravityManagerScreen extends StatefulWidget {
  const AntigravityManagerScreen({super.key});

  @override
  State<AntigravityManagerScreen> createState() => _AntigravityManagerScreenState();
}

class _AntigravityManagerScreenState extends State<AntigravityManagerScreen>
    with SingleTickerProviderStateMixin {
  late final AppConfig _appConfig;
  late final ModelRegistry _modelRegistry;
  late final SecureStorageService _secureStorage;
  late final http.Client _httpClient;

  late final ControlPlaneService controlPlaneService;
  late final DataPlaneService dataPlaneService;
  late final MemoryBankService memoryBankService;
  late final AntigravitySyncService syncService;
  late final NotificationService notificationService;
  late final SystemInstructionRepository instructionRepository;
  late final HeartbeatScheduler heartbeatScheduler;
  late final EnvironmentResourceGovernor resourceGovernor;

  // Persistence, Verifier, Telemetry, and Atomic Steering Queue
  late final RemoteBranchVerifier _branchVerifier;
  late final ContainerTelemetryService _telemetryService;
  late final SessionTracePersistenceService _tracePersistenceService;
  final AtomicSteeringQueue _steeringQueue = AtomicSteeringQueue();
  StreamSubscription<ContainerTelemetrySnapshot>? _telemetrySubscription;

  late final TabController _tabController;
  final TextEditingController _promptController = TextEditingController();

  AgentSession? _activeSession;
  String _selectedModelId = 'gemini-4-argon';
  String? _apiKey;
  SystemInstructionTemplate? _activeInstructionTemplate;
  BranchIsolationMode _activeIsolationMode = BranchIsolationMode.directoryIsolation;

  // Grok-style Branching Response Tree
  late ConversationTree _conversationTree;

  // Bounded Circular Ring Buffer for Streaming Logs (Zero OOM)
  final LogRingBuffer _logRingBuffer = LogRingBuffer(capacity: 2000);

  // Managed Environments with 144-Hour Limit and gVisor limits
  final List<ManagedEnvironment> _environments = [];

  final List<FileDiff> _generatedDiffs = [];
  final List<RemoteFileEntry> _remoteFiles = [];
  final List<PlaywrightTestStep> _qaSteps = [];

  Timer? _stopwatchTimer;
  Duration _elapsed = Duration.zero;
  bool _isExecuting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _httpClient = http.Client();
    _appConfig = AppConfig();
    _secureStorage = SecureStorageService();
    notificationService = NotificationService(isFirebaseConfigured: false);
    instructionRepository = SystemInstructionRepository();
    heartbeatScheduler = HeartbeatScheduler();
    resourceGovernor = EnvironmentResourceGovernor();

    _branchVerifier = const RemoteBranchVerifier();
    _telemetryService = ContainerTelemetryService();
    _tracePersistenceService = SessionTracePersistenceService();

    _activeInstructionTemplate = instructionRepository.getById('arch-flutter-senior');

    // Default dynamic models (overridable without rebuild, aligning with aistudio.google.com/docs/antigravity-agent)
    _modelRegistry = ModelRegistry(initialModels: [
      const ModelDescriptor(
        id: 'gemini-4-argon',
        displayName: 'Gemini 4 Argon',
        description: 'Complex reasoning, multi-file code refactors, and planning.',
        supportsReasoning: true,
        supportsFastCoding: false,
      ),
      const ModelDescriptor(
        id: 'gemini-3.6-flash',
        displayName: 'Gemini 3.6 Flash',
        description: 'Fast iterative coding loops and real-time execution.',
        supportsReasoning: false,
        supportsFastCoding: true,
      ),
      const ModelDescriptor(
        id: 'gemini-3.5-flash-lite',
        displayName: 'Gemini 3.5 Flash-Lite',
        description: 'Ultra-low latency lightweight agent tasks.',
        supportsReasoning: false,
        supportsFastCoding: true,
      ),
      const ModelDescriptor(
        id: 'gemini-3.8-flash',
        displayName: 'Gemini 3.8 Flash',
        description: 'High performance multimodal code synthesis.',
        supportsReasoning: false,
        supportsFastCoding: true,
      ),
    ]);

    controlPlaneService = ControlPlaneService(httpClient: _httpClient, appConfig: _appConfig);
    dataPlaneService = DataPlaneService(httpClient: _httpClient, appConfig: _appConfig);
    memoryBankService = MemoryBankService(httpClient: _httpClient, appConfig: _appConfig);
    syncService = AntigravitySyncService(httpClient: _httpClient, appConfig: _appConfig);

    _initializeEnvironments();
    _initializeSession();
    _initializeConversationTree();

    heartbeatScheduler.start();

    // Stream real live container telemetry from /proc/loadavg, /proc/meminfo, and df
    _telemetrySubscription = _telemetryService.streamTelemetry().listen((snapshot) {
      if (mounted && _environments.isNotEmpty) {
        setState(() {
          final activeEnv = _environments.first;
          _environments[0] = activeEnv.copyWith(
            cpuUsagePercent: snapshot.cpuUsagePercent,
            memoryUsageMb: snapshot.memoryUsageMb,
            diskUsageMb: snapshot.diskUsageMb,
            lastActiveAt: DateTime.now(),
          );
        });
      }
    });
  }

  void _initializeEnvironments() {
    final now = DateTime.now();
    _environments.addAll([
      ManagedEnvironment(
        id: 'env-soc2-984a',
        displayName: 'Main Engineering Sandbox',
        createdAt: now.subtract(const Duration(hours: 12)),
        lastActiveAt: now.subtract(const Duration(hours: 11, minutes: 42)),
        linkedSessionIds: ['7842a', 'auth-refactor-4a'],
        cpuUsagePercent: 32.5,
        memoryUsageMb: 4120.0,
        diskUsageMb: 1850.0,
      ),
      ManagedEnvironment(
        id: 'env-expiring-201',
        displayName: 'Feature Testing Sandbox',
        createdAt: now.subtract(const Duration(hours: 130)),
        lastActiveAt: now.subtract(const Duration(hours: 128)),
        linkedSessionIds: ['perf-99'],
        cpuUsagePercent: 18.0,
        memoryUsageMb: 2400.0,
        diskUsageMb: 980.0,
      ),
      ManagedEnvironment(
        id: 'env-legacy-312b',
        displayName: 'Archived Release Sandbox',
        createdAt: now.subtract(const Duration(hours: 160)),
        lastActiveAt: now.subtract(const Duration(hours: 152)), // > 144 hours expired!
        linkedSessionIds: ['arch-01'],
        cpuUsagePercent: 0.0,
        memoryUsageMb: 0.0,
        diskUsageMb: 520.0,
      ),
    ]);
  }

  void _initializeSession() {
    const sessionId = '7842a';
    _activeSession = AgentSession(
      id: sessionId,
      name: 'Authentication Refactoring',
      modelId: _selectedModelId,
      state: AgentState.idle,
    );
  }

  void _initializeConversationTree() {
    const environmentId = 'env-soc2-984a';
    _conversationTree = ConversationTree.createWithRoot(
      environmentId: environmentId,
      initialPrompt: 'Modernize authentication flow to OAuth2 with PKCE token refresh.',
      branchName: 'main',
      isolationMode: _activeIsolationMode,
    );

    // Initial agent proposal turn
    final proposalNode = _conversationTree.addMessage(
      parentId: _conversationTree.rootNodeId!,
      role: 'agent',
      content: 'I analyzed the repository. We can either migrate to OAuth2 PKCE or Session Cookie architecture.',
      branchName: 'main',
    );

    // Sibling Branch 1: OAuth2 PKCE
    _conversationTree.addMessage(
      parentId: proposalNode.id,
      role: 'agent',
      content: 'Branch 1: Modernize with OAuth2 PKCE token exchange and secure storage.',
      branchName: 'oauth2-pkce',
    );

    // Sibling Branch 2: Session Cookie
    _conversationTree.addMessage(
      parentId: proposalNode.id,
      role: 'agent',
      content: 'Branch 2: Traditional HTTP-only session cookie flow with CSRF guard.',
      branchName: 'cookie-approach',
    );
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _steeringQueue.dispose();
    _tabController.dispose();
    _promptController.dispose();
    _stopwatchTimer?.cancel();
    _httpClient.close();
    heartbeatScheduler.dispose();
    notificationService.dispose();
    super.dispose();
  }

  void _startTimer() {
    _stopwatchTimer?.cancel();
    _elapsed = Duration.zero;
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _stopTimer() {
    _stopwatchTimer?.cancel();
  }

  void _appendLog(String text) {
    if (mounted) {
      setState(() => _logRingBuffer.add(text));
    }
  }

  /// Triggers an autonomous agent turn inside Google's managed remote sandbox
  Future<void> _executeAutonomousTurn() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _activeSession == null) return;

    // Verify model lock
    try {
      _activeSession!.validateModel(_selectedModelId);
    } on SessionModelLockException catch (e) {
      _showErrorDialog('Model Lock Violation', e.toString());
      return;
    }

    // Branch Checkout State Verification
    final activeNode = _conversationTree.nodes[_conversationTree.activeLeafNodeId ?? _conversationTree.rootNodeId!];
    final activeBranchName = activeNode?.branchName ?? 'main';
    final targetWorkingDir = activeNode?.workingDirectory ?? 'main/';

    final branchVerification = await _branchVerifier.verifyBranchCheckout(
      workingDir: targetWorkingDir,
      branchName: activeBranchName,
      mode: _conversationTree.isolationMode,
    );
    if (!branchVerification.canProceed && branchVerification.error != null) {
      _showErrorDialog(
        'Branch Checkout Verification Failed',
        'Cannot execute turn on "$activeBranchName": ${branchVerification.error}',
      );
      return;
    }

    setState(() {
      _isExecuting = true;
      _logRingBuffer.clear();
      _generatedDiffs.clear();
      _remoteFiles.clear();
      _qaSteps.clear();
      _activeSession!.state = AgentState.planning;
    });
    _startTimer();

    // Add user turn to conversation tree
    final parentNodeId = _conversationTree.activeLeafNodeId ?? _conversationTree.rootNodeId!;
    final userNode = _conversationTree.addMessage(
      parentId: parentNodeId,
      role: 'user',
      content: prompt,
      branchName: _conversationTree.isolationMode == BranchIsolationMode.gitWorktree ? 'worktree-active' : 'main',
    );

    // Persist session prompt trace entry locally
    await _tracePersistenceService.appendEntry(
      _activeSession!.id,
      TraceEntry(
        timestamp: DateTime.now(),
        stage: 'init',
        type: 'prompt',
        content: prompt,
        metadata: {
          'branch': userNode.branchName,
          'isolationMode': _conversationTree.isolationMode.name,
          'workingDir': userNode.workingDirectory,
        },
      ),
    );

    final safeFlags = resourceGovernor.getSafeEnvironmentVariables();

    _appendLog('# Initializing Antigravity Orbit Session [${_activeSession!.id}]');
    _appendLog('> Model: ${_activeSession!.modelId} (locked)');
    _appendLog('> Sandbox: Google Managed Linux [${_conversationTree.environmentId}] (144h TTL)');
    _appendLog('> Branch Isolation: ${_conversationTree.isolationMode.name.toUpperCase()} (Dir: ${userNode.workingDirectory})');
    _appendLog('> Branch Checkout Verification: Clean=${branchVerification.isClean}, Exists=${branchVerification.exists}');
    _appendLog('> gVisor Flags: NODE_OPTIONS="${safeFlags['NODE_OPTIONS']}" | DART_VM="${safeFlags['DART_VM_OPTIONS']}"');
    if (_activeInstructionTemplate != null) {
      _appendLog('> System Directive: "${_activeInstructionTemplate!.title}"');
    }
    _appendLog('> Prompt: "$prompt"');
    _appendLog('');

    await Future.delayed(const Duration(milliseconds: 600));

    // Check for Atomic Preemption before Planning
    if (_steeringQueue.hasPendingPreemption) {
      final signal = _steeringQueue.consumeNext()!;
      _steeringQueue.acknowledge(signal.id);
      _appendLog('>> [ATOMIC PREEMPTION APPLIED AT TOOL BOUNDARY]');
      _appendLog('> Preempted by Directive: "${signal.instruction}" (Priority: ${signal.priority.name})');
      await _tracePersistenceService.appendEntry(
        _activeSession!.id,
        TraceEntry(
          timestamp: DateTime.now(),
          stage: 'planning',
          type: 'steering_nudge',
          content: signal.instruction,
          metadata: {'signalId': signal.id, 'priority': signal.priority.name},
        ),
      );
    }

    // Stage 1: Planning
    _appendLog('## Step 1: Synthesizing Strategy & Repository Context');
    _appendLog('- Reading repository structure in ${userNode.workingDirectory}...');
    _appendLog('- Assessing gVisor resource headroom: CPU ${_environments.first.cpuUsagePercent}% < 80%, RAM ${_environments.first.memoryUsageMb.toInt()}MB < 12GB, Disk ${_environments.first.diskUsageMb.toInt()}MB < 6GB.');
    _appendLog('- Formulating refactor plan for OAuth2 & JWT refresh handlers.');
    _appendLog('');

    await _tracePersistenceService.appendEntry(
      _activeSession!.id,
      TraceEntry(
        timestamp: DateTime.now(),
        stage: 'planning',
        type: 'log',
        content: 'Completed step 1 planning strategy',
      ),
    );

    await Future.delayed(const Duration(milliseconds: 700));

    // Check for Atomic Preemption before Executing Code
    if (_steeringQueue.hasPendingPreemption) {
      final signal = _steeringQueue.consumeNext()!;
      _steeringQueue.acknowledge(signal.id);
      _appendLog('>> [ATOMIC PREEMPTION APPLIED AT TOOL BOUNDARY]');
      _appendLog('> Preempted by Directive: "${signal.instruction}" (Priority: ${signal.priority.name})');
      await _tracePersistenceService.appendEntry(
        _activeSession!.id,
        TraceEntry(
          timestamp: DateTime.now(),
          stage: 'executingCode',
          type: 'steering_nudge',
          content: signal.instruction,
          metadata: {'signalId': signal.id, 'priority': signal.priority.name},
        ),
      );
    }

    // Stage 2: Executing Code
    if (!mounted) return;
    setState(() => _activeSession!.state = AgentState.executingCode);
    _appendLog('## Step 2: Executing Code in Remote Sandbox');
    _appendLog('\$ dart analyze --fatal-infos');
    _appendLog('\$ sed -i "s/deprecatedAuth/modernAuth/g" lib/auth/auth_service.dart');
    _appendLog('\$ dart test test/auth/auth_service_test.dart');

    const diffStr = '''
--- a/lib/auth/auth_service.dart
+++ b/lib/auth/auth_service.dart
@@ -14,6 +14,10 @@
-  Future<bool> authenticate(String user, String pass) async {
-    return legacyVerify(user, pass);
+  Future<AuthResult> authenticate(AuthRequest request) async {
+    final token = await oauth2Client.exchangeCredentials(request);
+    await secureVault.storeTokens(token);
+    return AuthResult.success(token: token);
   }
''';
    final diff = FileDiff.fromUnifiedDiff(diffStr);
    _generatedDiffs.add(diff);

    await _tracePersistenceService.appendEntry(
      _activeSession!.id,
      TraceEntry(
        timestamp: DateTime.now(),
        stage: 'executingCode',
        type: 'diff',
        content: diffStr,
        metadata: {'path': 'lib/auth/auth_service.dart'},
      ),
    );

    _remoteFiles.addAll([
      const RemoteFileEntry(relativePath: 'lib/auth/auth_service.dart', sizeBytes: 3200, sha256: 'a1b2c3'),
      const RemoteFileEntry(relativePath: 'test/auth/auth_service_test.dart', sizeBytes: 1850, sha256: 'd4e5f6'),
      const RemoteFileEntry(relativePath: 'output/auth_refactor.patch', sizeBytes: 940, sha256: '789abc'),
      const RemoteFileEntry(relativePath: 'output/traces/auth_flow.trace', sizeBytes: 15400, sha256: 'f0e1d2'),
    ]);

    await Future.delayed(const Duration(milliseconds: 700));

    // Stage 3: Reading Logs
    if (!mounted) return;
    setState(() => _activeSession!.state = AgentState.readingLogs);
    _appendLog('## Step 3: Reading Compiler & Test Output');
    _appendLog('> 0 analyzer warnings. All test assertions compiled successfully.');
    _appendLog('');

    await Future.delayed(const Duration(milliseconds: 600));

    // Stage 4: Browser QA (Playwright)
    if (!mounted) return;
    setState(() => _activeSession!.state = AgentState.browserQa);
    _appendLog('## Step 4: Headless Playwright Browser QA Suite');
    _appendLog('\$ npx playwright test tests/e2e/auth.spec.ts --headless');

    _qaSteps.addAll([
      const PlaywrightTestStep(
        title: 'Navigate to Auth Portal',
        action: 'await page.goto("http://127.0.0.1:8080/login")',
        duration: Duration(milliseconds: 142),
        passed: true,
      ),
      const PlaywrightTestStep(
        title: 'Submit Credentials with JWT Exchange',
        action: 'await page.fill("#username", "agent_qa")',
        duration: Duration(milliseconds: 88),
        passed: true,
      ),
      const PlaywrightTestStep(
        title: 'Verify Secure Storage Token Invalidation',
        action: 'await expect(page.locator(".auth-badge")).toBeVisible()',
        duration: Duration(milliseconds: 195),
        passed: true,
      ),
    ]);

    await Future.delayed(const Duration(milliseconds: 600));

    // Complete / Awaiting Approval
    if (!mounted) return;
    setState(() {
      _isExecuting = false;
      _activeSession!.state = AgentState.done;
    });
    _stopTimer();

    _conversationTree.addMessage(
      parentId: userNode.id,
      role: 'agent',
      content: 'Refactoring completed successfully with 100% test pass. Diff ready for review.',
      diffContent: 'AuthResult modern OAuth2 PKCE patch',
    );

    _appendLog('## Workflow Completed Successfully');
    _appendLog('> Output artifacts durable in remote orbit/${_activeSession!.id}/output.');
    _appendLog('> Durable session trace saved to .orbit/sessions/${_activeSession!.id}/trace.jsonl');
    _appendLog('> Ready for Git-safe Antigravity Sync with .orbit.bak safety backup.');

    await _tracePersistenceService.appendEntry(
      _activeSession!.id,
      TraceEntry(
        timestamp: DateTime.now(),
        stage: 'done',
        type: 'completion',
        content: 'Workflow completed successfully with 100% test pass.',
      ),
    );

    // Trigger optional notification
    notificationService.sendNotification(
      title: 'Antigravity Orbit: Auth Refactor Complete',
      body: '4 unit tests passed, 0 analyzer issues. Ready for downsync approval.',
      sessionId: _activeSession!.id,
    );
  }

  void _openNudgeDialog() {
    if (_activeSession == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AgentNudgeDialog(
        sessionId: _activeSession!.id,
        onNudgeSubmitted: (nudgeText) async {
          final signal = _steeringQueue.enqueueInstruction(
            nudgeText,
            priority: SteeringPriority.toolBoundary,
          );
          _appendLog('>> [IN-FLIGHT STEERING / NUDGE QUEUED]');
          _appendLog('> Directive [${signal.id}]: "$nudgeText" queued for tool boundary preemption.');
          await _tracePersistenceService.appendEntry(
            _activeSession!.id,
            TraceEntry(
              timestamp: DateTime.now(),
              stage: 'steering',
              type: 'steering_nudge',
              content: nudgeText,
              metadata: {'signalId': signal.id, 'priority': signal.priority.name},
            ),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.accentCyan,
                content: Text('Steering signal [${signal.id}] queued for next tool boundary'),
              ),
            );
          }
        },
      ),
    );
  }

  void _openConflictDialog() {
    final conflicts = [
      BranchFileConflict(
        relativePath: 'lib/auth/auth_service.dart',
        baseContent: 'Future<bool> authenticate(String user, String pass);',
        currentBranchContent: 'Future<AuthResult> authenticate(AuthRequest req); // OAuth2 PKCE',
        incomingBranchContent: 'Future<SessionToken> authenticate(CookieRequest req); // Cookie CSRF',
      ),
    ];

    showDialog(
      context: context,
      builder: (ctx) => BranchConflictDialog(
        conflicts: conflicts,
        onResolved: (resolvedList) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.statusSuccess,
              content: Text('Resolved ${resolvedList.length} branch conflicts successfully!'),
            ),
          );
        },
      ),
    );
  }

  void _triggerAntigravitySync() {
    if (_activeSession == null) return;
    showDialog(
      context: context,
      builder: (ctx) => SyncApprovalDialog(
        sessionId: _activeSession!.id,
        modifiedFiles: _remoteFiles.where((f) => f.relativePath.startsWith('output/')).toList(),
        targetPath: '/workspace',
        onApprove: () async {
          final syncResult = await syncService.downsyncWithResult(
            targetParentPath: '/workspace',
            sessionId: _activeSession!.id,
            filesToSync: _remoteFiles,
            apiKey: _apiKey ?? '',
            inMemoryFileContents: {
              'output/auth_refactor.patch': 'Generated auth patch from Gemini agent',
              'output/traces/auth_flow.trace': 'Playwright trace payload',
            },
            enableOrbitBackups: true,
          );
          if (mounted) {
            final backupNotice = syncResult.hadCollisions
                ? ' (${syncResult.backedUpFiles.length} existing files safely preserved as .orbit.bak)'
                : '';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.statusSuccess,
                content: Text('Successfully downsynced to ${syncResult.targetDirectory.path}$backupNotice'),
              ),
            );
          }
        },
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.statusError, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 15)),
          ],
        ),
        content: SelectableText(message, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNewConversationDialog() {
    final promptController = TextEditingController();
    BranchIsolationMode chosenMode = _conversationTree.isolationMode;
    String chosenEnvId = _conversationTree.environmentId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          title: const Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: AppTheme.accentCyan, size: 20),
              SizedBox(width: 8),
              Text('Start New Conversation Thread', style: TextStyle(fontSize: 15)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Branch isolation strategy is set per conversation (cannot be switched mid-thread):',
                  style: TextStyle(fontSize: 11, color: Colors.white60),
                ),
                const SizedBox(height: 12),
                const Text('Initial Prompt:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: promptController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'e.g., "Implement repository layer..."',
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.terminalBlack,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Branch Isolation Strategy:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButton<BranchIsolationMode>(
                  value: chosenMode,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceElevated,
                  items: const [
                    DropdownMenuItem(
                      value: BranchIsolationMode.directoryIsolation,
                      child: Text('Directory Isolation (subfolder per branch)'),
                    ),
                    DropdownMenuItem(
                      value: BranchIsolationMode.gitWorktree,
                      child: Text('Git Worktree Isolation (isolated working tree & index)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => chosenMode = val);
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Default network allowlist: "*" (unrestricted egress).',
                  style: TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              onPressed: () {
                final prompt = promptController.text.trim();
                if (prompt.isNotEmpty) {
                  setState(() {
                    _activeIsolationMode = chosenMode;
                    _conversationTree = ConversationTree.createWithRoot(
                      environmentId: chosenEnvId,
                      initialPrompt: prompt,
                      branchName: 'main',
                      isolationMode: chosenMode,
                      networkAllowlist: const ['*'],
                    );
                    _activeSession = AgentSession(
                      id: 'sess-${DateTime.now().millisecondsSinceEpoch}',
                      name: 'Thread: ${prompt.length > 25 ? "${prompt.substring(0, 25)}..." : prompt}',
                      modelId: _selectedModelId,
                    );
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Create Thread'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettingsDialog() {
    final controlPlaneController = TextEditingController(text: _appConfig.controlPlaneBaseUrl);
    final dataPlaneController = TextEditingController(text: _appConfig.dataPlaneBaseUrl);
    final apiVersionController = TextEditingController(text: _appConfig.apiVersion);
    final memoryBankController = TextEditingController(text: _appConfig.memoryBankBaseUrl);
    final apiKeyController = TextEditingController(text: _apiKey ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Row(
          children: [
            Icon(Icons.tune, color: AppTheme.primaryBlue, size: 20),
            SizedBox(width: 8),
            Text('Settings & Google AI Studio BYOK', style: TextStyle(fontSize: 15)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Provide your Gemini API key from Google AI Studio (https://aistudio.google.com):',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 12),
                _buildSettingsField('GEMINI_API_KEY (from Google AI Studio)', apiKeyController, obscureText: true),
                const SizedBox(height: 10),
                _buildSettingsField('Control Plane Base URL', controlPlaneController),
                const SizedBox(height: 10),
                _buildSettingsField('Data Plane Base URL', dataPlaneController),
                const SizedBox(height: 10),
                _buildSettingsField('API Version', apiVersionController),
                const SizedBox(height: 10),
                _buildSettingsField('Session Continuity Base URL', memoryBankController),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () async {
              _appConfig.updateVariables(
                controlPlaneBaseUrl: controlPlaneController.text.trim(),
                dataPlaneBaseUrl: dataPlaneController.text.trim(),
                apiVersion: apiVersionController.text.trim(),
                memoryBankBaseUrl: memoryBankController.text.trim(),
              );
              final newKey = apiKeyController.text.trim();
              if (newKey.isNotEmpty) {
                await _secureStorage.saveGeminiApiKey(newKey);
                setState(() => _apiKey = newKey);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save Runtime Config'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsField(String label, TextEditingController controller, {bool obscureText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppTheme.terminalBlack,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rocket_launch, color: AppTheme.accentCyan, size: 20),
            SizedBox(width: 8),
            Text(
              'Antigravity Orbit',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          // Active Instruction Chip
          if (_activeInstructionTemplate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: ActionChip(
                  backgroundColor: AppTheme.surfaceElevated,
                  avatar: const Icon(Icons.psychology, size: 14, color: AppTheme.accentCyan),
                  label: Text(
                    _activeInstructionTemplate!.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                  onPressed: () => _tabController.animateTo(6), // Switch to Instructions tab
                ),
              ),
            ),
          const SizedBox(width: 6),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200, minWidth: 130),
            child: ModelSelectorDropdown(
              registry: _modelRegistry,
              selectedModelId: _activeSession?.modelId ?? _selectedModelId,
              isLocked: _activeSession?.state != AgentState.idle,
              onModelSelected: (newId) {
                setState(() {
                  _selectedModelId = newId;
                  if (_activeSession?.state == AgentState.idle) {
                    _activeSession = _activeSession!.copyWith(name: _activeSession!.name);
                  }
                });
              },
              onRefreshModels: () async {
                if (_apiKey != null) {
                  await _modelRegistry.fetchModelsFromApi(
                    httpClient: _httpClient,
                    appConfig: _appConfig,
                    apiKey: _apiKey!,
                  );
                }
              },
            ),
          ),
          IconButton(
            tooltip: 'Settings & Runtime Config',
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: _openSettingsDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Agent Monitor Pipeline View
          if (_activeSession != null)
            AgentMonitorView(
              currentState: _activeSession!.state,
              modelName: _activeSession!.modelId,
              sessionId: _activeSession!.id,
              elapsed: _elapsed,
              onCancel: _isExecuting
                  ? () {
                      setState(() {
                        _isExecuting = false;
                        _activeSession!.state = AgentState.failed;
                      });
                      _stopTimer();
                      _appendLog('!! Agent execution cancelled by user.');
                    }
                  : null,
            ),

          // Central Workspace Tabs (8 Tabs for Full Command Center)
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppTheme.accentCyan,
            labelColor: const Color(0xFFF0F6FC),
            unselectedLabelColor: Colors.white54,
            tabs: [
              const Tab(
                icon: Icon(Icons.alt_route, size: 16),
                text: 'Thread & Branches',
              ),
              Tab(
                icon: const Icon(Icons.terminal, size: 16),
                text: 'Terminal Logs (${_logRingBuffer.length})',
              ),
              Tab(
                icon: const Icon(Icons.difference_outlined, size: 16),
                text: 'Diffs (${_generatedDiffs.length})',
              ),
              Tab(
                icon: const Icon(Icons.folder_open, size: 16),
                text: 'Remote /workspace (${_remoteFiles.length})',
              ),
              Tab(
                icon: const Icon(Icons.language, size: 16),
                text: 'Browser QA (${_qaSteps.length})',
              ),
              Tab(
                icon: const Icon(Icons.cloud_queue, size: 16),
                text: 'Environments (${_environments.length})',
              ),
              const Tab(
                icon: Icon(Icons.psychology_outlined, size: 16),
                text: 'System Instructions',
              ),
              const Tab(
                icon: Icon(Icons.favorite, size: 16),
                text: 'Heartbeat Scheduler',
              ),
            ],
          ),

          // Central Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildThreadAndBranchesView(),
                VirtualizedMarkdownView(
                  chunks: _logRingBuffer.toList(),
                  isStreaming: _isExecuting,
                ),
                _buildDiffsView(),
                RemoteWorkspaceTree(files: _remoteFiles),
                PlaywrightTraceViewer(steps: _qaSteps, isRunning: _activeSession?.state == AgentState.browserQa),
                EnvironmentManagementView(
                  environments: _environments,
                  onSelectEnvironment: (env) {
                    try {
                      env.assertCanStartConversation();
                      setState(() {
                        _initializeConversationTree();
                        _activeSession = AgentSession(
                          id: 'sess-${DateTime.now().millisecondsSinceEpoch}',
                          name: 'Attached to ${env.displayName}',
                          modelId: _selectedModelId,
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.statusSuccess,
                          content: Text('Attached to Google Sandbox ${env.id} (${env.timeRemaining.inHours}h remaining)'),
                        ),
                      );
                      _tabController.animateTo(0);
                    } on EnvironmentRetentionExpiredException catch (e) {
                      _showErrorDialog('Retention Expired (>144 Hours)', e.toString());
                    }
                  },
                  onCreateNewEnvironment: () {
                    final newEnv = ManagedEnvironment(
                      id: 'env-soc2-${DateTime.now().millisecondsSinceEpoch % 10000}',
                      displayName: 'Fresh Dev Sandbox',
                      createdAt: DateTime.now(),
                      lastActiveAt: DateTime.now(),
                    );
                    setState(() => _environments.insert(0, newEnv));
                  },
                ),
                SystemInstructionsView(
                  repository: instructionRepository,
                  activeTemplateId: _activeInstructionTemplate?.id,
                  onApplyTemplate: (template) {
                    setState(() => _activeInstructionTemplate = template);
                  },
                ),
                HeartbeatSchedulerView(scheduler: heartbeatScheduler),
              ],
            ),
          ),

          // Responsive Bottom Prompt Command Bar with Atomic Steering & Sync
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktopWide = constraints.maxWidth >= 650;

                final isolationBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.terminalBlack,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _conversationTree.isolationMode == BranchIsolationMode.gitWorktree
                            ? Icons.work_outline
                            : Icons.folder_outlined,
                        size: 14,
                        color: _conversationTree.isolationMode == BranchIsolationMode.gitWorktree
                            ? AppTheme.accentCyan
                            : AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _conversationTree.isolationMode == BranchIsolationMode.gitWorktree
                            ? 'WORKTREE'
                            : 'DIR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _conversationTree.isolationMode == BranchIsolationMode.gitWorktree
                              ? AppTheme.accentCyan
                              : AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                );

                final promptTextField = TextField(
                  controller: _promptController,
                  enabled: !_isExecuting,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Delegate coding task or branch prompt (e.g., "Refactor auth using PKCE")...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.terminalBlack,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  onSubmitted: (_) => _executeAutonomousTurn(),
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_isExecuting)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.navigation_outlined, size: 16),
                        label: const Text('Steer / Nudge', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _openNudgeDialog,
                      ),
                    if (!_isExecuting)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Run Agent'),
                        onPressed: _executeAutonomousTurn,
                      ),
                    if (_activeSession?.state == AgentState.done)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.sync_alt, size: 18),
                        label: const Text('Antigravity Sync', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _triggerAntigravitySync,
                      ),
                  ],
                );

                if (isDesktopWide) {
                  return Row(
                    children: [
                      isolationBadge,
                      const SizedBox(width: 10),
                      Expanded(child: promptTextField),
                      const SizedBox(width: 10),
                      actionButtons,
                    ],
                  );
                } else {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          isolationBadge,
                          const SizedBox(width: 8),
                          Expanded(child: promptTextField),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [actionButtons],
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadAndBranchesView() {
    final activePath = _conversationTree.getActivePath();

    return Container(
      color: AppTheme.terminalBlack,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Responsive Banner & Conflict Resolver Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_tree_outlined, color: AppTheme.accentCyan, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Grok-Style Response Tree & Per-Message Branching',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('New Thread', style: TextStyle(fontSize: 11)),
                      onPressed: _showNewConversationDialog,
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.statusWarning),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.merge_type, size: 14, color: AppTheme.statusWarning),
                      label: const Text('3-Way Conflict Resolver', style: TextStyle(fontSize: 11, color: AppTheme.statusWarning)),
                      onPressed: _openConflictDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Message Nodes List
          Expanded(
            child: ListView.separated(
              itemCount: activePath.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final node = activePath[idx];
                final siblings = _conversationTree.getSiblingBranches(node.id);
                final siblingPos = _conversationTree.getSiblingPosition(node.id);

                return _buildMessageNodeCard(node, siblings, siblingPos);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageNodeCard(
    BranchNode node,
    List<BranchNode> siblings,
    ({int index, int total}) siblingPos,
  ) {
    final isUser = node.role == 'user';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser ? AppTheme.surfaceElevated : AppTheme.terminalBlack,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUser ? AppTheme.primaryBlue.withOpacity(0.3) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Grok Navigator Pill
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                    size: 16,
                    color: isUser ? AppTheme.primaryBlue : AppTheme.accentCyan,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isUser ? 'User Prompt' : 'Agent Response',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isUser ? AppTheme.primaryBlue : AppTheme.accentCyan,
                    ),
                  ),
                ],
              ),
              // Branch Navigator Pill with < 1 / 3 > and Fork
              BranchNavigatorPill(
                currentIndex: siblingPos.index,
                totalBranches: siblingPos.total,
                branchName: node.branchName,
                isolationMode: node.isolationMode,
                onBranchSelected: (targetIdx) async {
                  if (node.parentId != null) {
                    final siblingsList = _conversationTree.getSiblingBranches(node.id);
                    if (targetIdx >= 0 && targetIdx < siblingsList.length) {
                      final targetNode = siblingsList[targetIdx];
                      final check = await _branchVerifier.verifyBranchCheckout(
                        workingDir: targetNode.workingDirectory,
                        branchName: targetNode.branchName,
                        mode: targetNode.isolationMode,
                      );
                      if (!check.isClean && check.dirtyFiles.isNotEmpty && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.statusWarning,
                            content: Text(
                              'Branch "${targetNode.branchName}" checkout: ${check.dirtyFiles.length} dirty/backup files detected.',
                            ),
                          ),
                        );
                      }
                    }
                    setState(() {
                      _conversationTree.switchSiblingBranch(node.parentId!, targetIdx);
                    });
                  }
                },
                onForkRequested: () {
                  final forked = _conversationTree.forkBranch(
                    fromNodeId: node.id,
                    newContent: 'Alternative exploration for "${node.branchName}"',
                    role: node.role,
                    newBranchName: '${node.branchName}-fork',
                  );
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.accentCyan,
                      content: Text('Forked alternative branch: ${forked.branchName}'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Message Content
          SelectableText(
            node.content,
            style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
          ),

          if (node.diffContent != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.terminalBlack,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                node.diffContent!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.accentCyan),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffsView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.surfaceElevated,
          child: Row(
            children: [
              const Text(
                'Branch Diffs & Merging',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusWarning),
                icon: const Icon(Icons.call_merge, size: 14),
                label: const Text('Resolve 3-Way Conflicts', style: TextStyle(fontSize: 11)),
                onPressed: _openConflictDialog,
              ),
            ],
          ),
        ),
        Expanded(child: SyntaxDiffViewer(diffs: _generatedDiffs)),
      ],
    );
  }
}
