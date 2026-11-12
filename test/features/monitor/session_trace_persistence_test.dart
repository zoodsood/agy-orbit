import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/features/monitor/data/session_trace_persistence_service.dart';

void main() {
  group('SessionTracePersistenceService Tests', () {
    late Directory tempDir;
    late SessionTracePersistenceService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('orbit_trace_test_');
      service = SessionTracePersistenceService(baseStorageDirectory: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Appends and loads JSONL trace entries reliably', () async {
      const sessionId = 'session-test-01';

      await service.appendEntry(
        sessionId,
        TraceEntry(
          timestamp: DateTime.now(),
          stage: 'planning',
          type: 'log',
          content: 'Synthesizing codebase AST',
        ),
      );

      await service.appendEntry(
        sessionId,
        TraceEntry(
          timestamp: DateTime.now(),
          stage: 'executingCode',
          type: 'diff',
          content: '+ Future<AuthResult> authenticate()',
          metadata: {'file': 'auth.dart'},
        ),
      );

      final entries = await service.loadTrace(sessionId);
      expect(entries.length, 2);
      expect(entries[0].stage, 'planning');
      expect(entries[0].content, 'Synthesizing codebase AST');
      expect(entries[1].stage, 'executingCode');
      expect(entries[1].type, 'diff');
      expect(entries[1].metadata['file'], 'auth.dart');
    });

    test('Exports portable .orbit.trace snapshot', () async {
      const sessionId = 'session-test-02';

      await service.appendEntry(
        sessionId,
        TraceEntry(
          timestamp: DateTime.now(),
          stage: 'done',
          type: 'completion',
          content: '100% tests passed',
        ),
      );

      final exportedFile = await service.exportTraceSnapshot(sessionId);
      expect(await exportedFile.exists(), isTrue);
      expect(exportedFile.path.endsWith('.orbit.trace'), isTrue);

      final fileContent = await exportedFile.readAsString();
      expect(fileContent.contains('orbitVersion'), isTrue);
      expect(fileContent.contains('session-test-02'), isTrue);
      expect(fileContent.contains('100% tests passed'), isTrue);
    });

    test('Clears session trace on demand', () async {
      const sessionId = 'session-test-03';

      await service.appendEntry(
        sessionId,
        TraceEntry(
          timestamp: DateTime.now(),
          stage: 'init',
          type: 'prompt',
          content: 'Hello',
        ),
      );

      expect((await service.loadTrace(sessionId)).isNotEmpty, isTrue);
      await service.clearTrace(sessionId);
      expect((await service.loadTrace(sessionId)).isEmpty, isTrue);
    });
  });
}
