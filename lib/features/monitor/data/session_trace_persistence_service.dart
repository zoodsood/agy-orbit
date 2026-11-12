import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Entry in a durable session execution trace.
class TraceEntry {
  final DateTime timestamp;
  final String stage;
  final String type; // 'log', 'tool_call', 'diff', 'steering_nudge', 'telemetry'
  final String content;
  final Map<String, dynamic> metadata;

  const TraceEntry({
    required this.timestamp,
    required this.stage,
    required this.type,
    required this.content,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'stage': stage,
        'type': type,
        'content': content,
        'metadata': metadata,
      };

  factory TraceEntry.fromJson(Map<String, dynamic> json) => TraceEntry(
        timestamp: DateTime.parse(json['timestamp'] as String),
        stage: json['stage'] as String? ?? 'general',
        type: json['type'] as String? ?? 'log',
        content: json['content'] as String? ?? '',
        metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      );
}

/// Durable trace persistence service that writes session reasoning traces,
/// tool executions, diffs, and in-flight nudges to disk under `.orbit/sessions/<sessionId>/`.
/// Prevents loss of historical execution context across app restarts.
class SessionTracePersistenceService {
  final String baseStorageDirectory;

  SessionTracePersistenceService({
    String? baseStorageDirectory,
  }) : baseStorageDirectory = baseStorageDirectory ?? '.orbit/sessions';

  /// Returns the trace file for a given session.
  File getTraceFile(String sessionId) {
    final dir = Directory(p.join(baseStorageDirectory, sessionId));
    return File(p.join(dir.path, 'trace.jsonl'));
  }

  /// Appends a trace entry to the session's durable JSONL file.
  Future<void> appendEntry(String sessionId, TraceEntry entry) async {
    final file = getTraceFile(sessionId);
    await file.parent.create(recursive: true);
    final jsonLine = '${jsonEncode(entry.toJson())}\n';
    await file.writeAsString(jsonLine, mode: FileMode.append, flush: true);
  }

  /// Loads all durable trace entries for a session.
  Future<List<TraceEntry>> loadTrace(String sessionId) async {
    final file = getTraceFile(sessionId);
    if (!await file.exists()) return [];

    final lines = await file.readAsLines();
    final List<TraceEntry> entries = [];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        entries.add(TraceEntry.fromJson(json));
      } catch (_) {}
    }
    return entries;
  }

  /// Exports a session trace into a standalone portable `.orbit.trace` JSON snapshot.
  Future<File> exportTraceSnapshot(String sessionId, {String? targetPath}) async {
    final entries = await loadTrace(sessionId);
    final exportData = {
      'orbitVersion': '1.0.0',
      'sessionId': sessionId,
      'exportedAt': DateTime.now().toIso8601String(),
      'entryCount': entries.length,
      'entries': entries.map((e) => e.toJson()).toList(),
    };

    final destination = targetPath != null
        ? File(targetPath)
        : File(p.join(baseStorageDirectory, sessionId, '$sessionId.orbit.trace'));

    await destination.parent.create(recursive: true);
    await destination.writeAsString(const JsonEncoder.withIndent('  ').convert(exportData));
    return destination;
  }

  /// Clears durable trace data for a given session.
  Future<void> clearTrace(String sessionId) async {
    final file = getTraceFile(sessionId);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
