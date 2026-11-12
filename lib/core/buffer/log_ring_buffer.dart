import 'dart:collection';
import 'dart:io';

/// High-throughput, bounded circular FIFO buffer for streaming terminal logs.
/// Prevents Out-Of-Memory (OOM) crashes on 1,000,000+ token runs by retaining
/// a fixed active capacity in memory while spooling evicted chunks to disk if desired.
class LogRingBuffer {
  final int capacity;
  final Queue<String> _buffer;
  int _totalIngestedLines = 0;
  int _evictedCount = 0;
  File? _spoolFile;

  LogRingBuffer({
    this.capacity = 2000,
    File? spoolFile,
  })  : assert(capacity > 0, 'Capacity must be greater than zero'),
        _buffer = Queue<String>(),
        _spoolFile = spoolFile;

  /// Returns the number of lines currently held in active memory.
  int get length => _buffer.length;

  /// Returns the total number of lines evicted from active memory since inception.
  int get evictedCount => _evictedCount;

  /// Returns the cumulative number of lines ingested.
  int get totalIngestedLines => _totalIngestedLines;

  /// Whether the buffer has reached maximum active capacity.
  bool get isFull => _buffer.length >= capacity;

  /// Configures or updates the disk spooling target.
  void setSpoolFile(File file) {
    _spoolFile = file;
  }

  /// Appends a single log line into the ring buffer.
  /// If the buffer exceeds [capacity], the oldest entry is evicted (and spooled if configured).
  void add(String line) {
    _totalIngestedLines++;
    if (_buffer.length >= capacity) {
      final evicted = _buffer.removeFirst();
      _evictedCount++;
      if (_spoolFile != null) {
        _spoolFile!.writeAsStringSync('$evicted\n', mode: FileMode.append);
      }
    }
    _buffer.addLast(line);
  }

  /// Appends multiple log lines in order.
  void addAll(Iterable<String> lines) {
    for (final line in lines) {
      add(line);
    }
  }

  /// Clears active memory buffer and resets counters.
  void clear() {
    _buffer.clear();
    _totalIngestedLines = 0;
    _evictedCount = 0;
  }

  /// Retrieves the item at [index] from the active memory window.
  String operator [](int index) {
    if (index < 0 || index >= _buffer.length) {
      throw RangeError.index(index, _buffer, 'LogRingBuffer index out of bounds');
    }
    return _buffer.elementAt(index);
  }

  /// Returns a snapshot list of current in-memory log entries.
  List<String> toList() => List.unmodifiable(_buffer);

  /// Returns a joined string of all active lines.
  String toLines({String separator = '\n'}) => _buffer.join(separator);

  /// Retrieves a paginated slice of active lines for virtualized rendering.
  List<String> getWindow(int startIndex, int count) {
    if (startIndex < 0) startIndex = 0;
    if (startIndex >= _buffer.length) return const [];
    final endIndex = (startIndex + count).clamp(0, _buffer.length);
    return _buffer.toList().sublist(startIndex, endIndex);
  }
}
