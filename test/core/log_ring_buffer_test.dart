import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/core/buffer/log_ring_buffer.dart';

void main() {
  group('LogRingBuffer Tests', () {
    test('Maintains bounded capacity and evicts oldest entries in FIFO order', () {
      final buffer = LogRingBuffer(capacity: 5);
      expect(buffer.length, equals(0));
      expect(buffer.isFull, isFalse);

      for (int i = 1; i <= 5; i++) {
        buffer.add('Log line $i');
      }

      expect(buffer.length, equals(5));
      expect(buffer.isFull, isTrue);
      expect(buffer[0], equals('Log line 1'));
      expect(buffer[4], equals('Log line 5'));
      expect(buffer.evictedCount, equals(0));

      // Ingest 6th entry - line 1 should be evicted
      buffer.add('Log line 6');
      expect(buffer.length, equals(5));
      expect(buffer.evictedCount, equals(1));
      expect(buffer[0], equals('Log line 2'));
      expect(buffer[4], equals('Log line 6'));
      expect(buffer.totalIngestedLines, equals(6));
    });

    test('Spools evicted entries to temporary file if configured', () {
      final tempFile = File('${Directory.systemTemp.path}/test_spool_${DateTime.now().millisecondsSinceEpoch}.log');
      final buffer = LogRingBuffer(capacity: 3, spoolFile: tempFile);

      buffer.addAll(['line A', 'line B', 'line C', 'line D', 'line E']);

      expect(buffer.length, equals(3));
      expect(buffer.evictedCount, equals(2));
      expect(tempFile.existsSync(), isTrue);

      final spooledContent = tempFile.readAsStringSync();
      expect(spooledContent, contains('line A'));
      expect(spooledContent, contains('line B'));

      if (tempFile.existsSync()) tempFile.deleteSync();
    });

    test('Retrieves paginated window slice for virtualized view', () {
      final buffer = LogRingBuffer(capacity: 10);
      for (int i = 0; i < 10; i++) {
        buffer.add('Item $i');
      }

      final window = buffer.getWindow(2, 4);
      expect(window.length, equals(4));
      expect(window[0], equals('Item 2'));
      expect(window[3], equals('Item 5'));
    });
  });
}
