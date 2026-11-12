import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:antigravity_flutter/core/config/app_config.dart';
import 'package:antigravity_flutter/features/interaction/data/data_plane_service.dart';
import 'package:antigravity_flutter/features/interaction/data/memory_bank_service.dart';
import 'package:antigravity_flutter/features/interaction/domain/entities/interaction_event.dart';
import 'package:antigravity_flutter/features/session/domain/entities/agent_session.dart';
import 'package:antigravity_flutter/features/session/domain/entities/agent_state.dart';

void main() {
  group('Data Plane & Memory Bank Reconnection Tests', () {
    test('Parses streaming event chunks from Interactions API', () async {
      final appConfig = AppConfig();
      final dataPlane = DataPlaneService(httpClient: http.Client(), appConfig: appConfig);

      final streamController = StreamController<String>();
      final eventsFuture = dataPlane.parseEventStream(
        streamController.stream,
        'session-101',
        'turn-001',
      ).toList();

      streamController.add('data: {"type": "thoughtDelta", "content": "Analyzing repository..."}\n');
      streamController.add('data: {"type": "stateChange", "targetState": "executingCode", "content": "Running tests"}\n');
      streamController.add('data: [DONE]\n');
      await streamController.close();

      final events = await eventsFuture;
      expect(events.length, equals(3));
      expect(events[0].type, equals(InteractionEventType.thoughtDelta));
      expect(events[0].content, equals('Analyzing repository...'));

      expect(events[1].type, equals(InteractionEventType.stateChange));
      expect(events[1].targetState, equals(AgentState.executingCode));

      expect(events[2].type, equals(InteractionEventType.turnComplete));
      expect(events[2].targetState, equals(AgentState.done));
    });

    test('InteractionEvent serializes and deserializes accurately with sequence id', () {
      final now = DateTime.now();
      final event = InteractionEvent(
        id: 'evt-test-1',
        seqId: 42,
        sessionId: 'session-xyz',
        turnId: 'turn-999',
        type: InteractionEventType.toolExecution,
        timestamp: now,
        content: 'dart analyze',
        targetState: AgentState.readingLogs,
        payload: {'exitCode': 0},
      );

      final json = event.toJson();
      final reconstructed = InteractionEvent.fromJson(json);

      expect(reconstructed.id, equals('evt-test-1'));
      expect(reconstructed.seqId, equals(42));
      expect(reconstructed.type, equals(InteractionEventType.toolExecution));
      expect(reconstructed.targetState, equals(AgentState.readingLogs));
      expect(reconstructed.payload['exitCode'], equals(0));
    });

    test('Filters duplicate stream events and maintains highest sequence id', () {
      final memoryBank = MemoryBankService(httpClient: http.Client(), appConfig: AppConfig());
      final now = DateTime.now();

      final e1 = InteractionEvent(
        id: 'evt-1',
        seqId: 1,
        sessionId: 's1',
        turnId: 't1',
        type: InteractionEventType.textDelta,
        timestamp: now,
        content: 'Chunk 1',
      );
      final e2 = InteractionEvent(
        id: 'evt-2',
        seqId: 2,
        sessionId: 's1',
        turnId: 't1',
        type: InteractionEventType.textDelta,
        timestamp: now,
        content: 'Chunk 2',
      );

      final firstBatch = memoryBank.deduplicateEvents([e1, e2]);
      expect(firstBatch.length, equals(2));
      expect(memoryBank.lastSeenSeqId, equals(2));

      // Re-delivery of e2 and new e3
      final e3 = InteractionEvent(
        id: 'evt-3',
        seqId: 3,
        sessionId: 's1',
        turnId: 't1',
        type: InteractionEventType.textDelta,
        timestamp: now,
        content: 'Chunk 3',
      );

      final secondBatch = memoryBank.deduplicateEvents([e2, e3]); // e2 is duplicate!
      expect(secondBatch.length, equals(1));
      expect(secondBatch.first.id, equals('evt-3'));
      expect(memoryBank.lastSeenSeqId, equals(3));
    });

    test('Manages mobile background pause and resume states without battery drain', () {
      final memoryBank = MemoryBankService(httpClient: http.Client(), appConfig: AppConfig());

      expect(memoryBank.isBackgrounded, isFalse);
      memoryBank.handleAppPaused('turn-final-78');

      expect(memoryBank.isBackgrounded, isTrue);
      expect(memoryBank.cachedLastTurnId, equals('turn-final-78'));
    });

    test('AgentSession strictly rejects execution with mismatched locked model', () {
      final session = AgentSession(
        id: 'sess-lock-test',
        name: 'Refactor',
        modelId: 'gemini-4-argon',
      );

      // Same model is allowed
      expect(() => session.validateModel('gemini-4-argon'), returnsNormally);

      // Attempting to use a different model throws SessionModelLockException
      expect(
        () => session.validateModel('gemini-3.8-flash'),
        throwsA(isA<SessionModelLockException>()),
      );
    });
  });
}
