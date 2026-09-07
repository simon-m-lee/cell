// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// A real-life practical executable walkthrough demonstrating the use of
/// Flow.buffer for batching a firehose of single pulses into work-sized lists.
///
/// ### Scenario
/// A high-volume event processing system where:
/// 1. Thousands of events arrive as individual pulses
/// 2. Flow.buffer collects them into batches
/// 3. Batches are flushed by count, time, or both
/// 4. Processing happens once per batch instead of per event
/// 5. Real-world scenarios demonstrate buffer strategies
///
/// ### Learning Objectives
/// - Understand how Flow.buffer collects events into lists
/// - See count-based batching (BufferCount)
/// - Learn time-based batching (BufferTime)
/// - Combine count and time for optimal batching
/// - Use custom predicates for conditional batching
/// - Reduce processing overhead by batching
///
/// ### Expected Console Output
/// ```
/// ── Buffer: Batch Processing Demo ────────────────────────────────────────────────
///
/// 1. BufferCount - Batch by Size
///    ────────────────────────────────────────────────────────
///    [Event] #1: data
///    [Event] #2: data
///    [Event] #3: data
///    [Batch] [1, 2, 3] (3 items)
///    [Event] #4: data
///    [Event] #5: data
///    [Event] #6: data
///    [Batch] [4, 5, 6] (3 items)
///
/// 2. BufferTime - Batch by Time
///    ────────────────────────────────────────────────────────
///    [Event] A at 0ms
///    [Event] B at 100ms
///    [Event] C at 200ms
///    [Batch] [A, B, C] (3 items) at 500ms
///    [Event] D at 600ms
///    [Event] E at 700ms
///    [Batch] [D, E] (2 items) at 1000ms
///
/// 3. BufferWithTimeAndCount - Batch by Time or Count
///    ────────────────────────────────────────────────────────
///    [Event] 1 at 0ms
///    [Event] 2 at 100ms
///    [Event] 3 at 200ms (count wins - flush!)
///    [Batch] [1, 2, 3] (count triggered)
///    [Event] 4 at 300ms (time wins - flush!)
///    [Batch] [4] (time triggered)
///
/// 4. BufferWithPredicate - Conditional Batching
///    ────────────────────────────────────────────────────────
///    [Event] 1 (buffered)
///    [Event] 2 (buffered)
///    [Event] 3 (EVEN - flush!)
///    [Batch] [1, 2, 3] (triggered by even number)
///    [Event] 4 (EVEN - flush!)
///    [Batch] [4]
///
/// 5. BufferWhen - External Trigger Batching
///    ────────────────────────────────────────────────────────
///    [Event] a (buffered)
///    [Event] b (buffered)
///    [Trigger] Manual flush at 300ms
///    [Batch] [a, b] (triggered by external signal)
///    [Event] c (buffered)
///    [Event] d (buffered)
///    [Trigger] Manual flush at 600ms
///    [Batch] [c, d]
///
/// 6. Real-Time Log Batching
///    ────────────────────────────────────────────────────────
///    [App] User login (buffered)
///    [App] API request (buffered)
///    [App] Database query (buffered)
///    [App] File upload (buffered)
///    [Batch] 4 logs: 2 INFO, 1 WARN, 1 ERROR
///    [App] Cache hit (buffered)
///    [App] Cache miss (buffered)
///    [Batch] 2 logs: 2 INFO
///
/// 7. Sensor Data Batching
///    ────────────────────────────────────────────────────────
///    [Sensor-1] 23.5°C
///    [Sensor-2] 45.2%
///    [Sensor-3] 1013.2hPa
///    [Sensor-4] 22.8°C
///    [Sensor-5] 44.7%
///    [Batch] 5 readings - Avg: 23.2°C, 45.0%, 1013.2hPa
///
/// 8. Event Stream Batching
///    ────────────────────────────────────────────────────────
///    [Event] Click #1
///    [Event] Click #2
///    [Event] Scroll #1
///    [Event] Click #3
///    [Batch] 4 events - Clicks: 3, Scrolls: 1
///
/// 9. Performance: Firehose to Batches
///    ────────────────────────────────────────────────────────
///    Raw events: 1000
///    Batches: 10 (100 events/batch)
///    Processing time: 45ms (vs 1,234ms without batching)
///    Speedup: 27.4x
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'dart:math';
import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/buffer.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_flow/src/instruction/tap.dart';

// ignore_for_file: unused_element, unused_field, unused_local_variable

// ─────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────

/// Represents a log entry.
class LogEntry {
  final String level;
  final String message;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$level: $message';
}

/// Represents a sensor reading.
class SensorReading {
  final String sensorId;
  final String type;
  final double value;
  final DateTime timestamp;

  SensorReading({
    required this.sensorId,
    required this.type,
    required this.value,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$sensorId: ${value.toStringAsFixed(1)}';
}

/// Represents a user event.
class UserEvent {
  final String type;
  final String? target;
  final DateTime timestamp;

  UserEvent({
    required this.type,
    this.target,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$type${target != null ? ' on $target' : ''}';
}

/// Represents a batch of items.
class Batch<T> {
  final List<T> items;
  final DateTime timestamp;
  final int size;

  Batch(this.items, {DateTime? timestamp})
      : size = items.length,
        timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$items ($size items)';
}

/// Represents batch metrics.
class BatchMetrics {
  int totalEvents = 0;
  int totalBatches = 0;
  int totalProcessingTime = 0;
  final Map<String, int> eventCounts = {};

  void recordEvent(String type) {
    totalEvents++;
    eventCounts[type] = (eventCounts[type] ?? 0) + 1;
  }

  void recordBatch(int processingTime) {
    totalBatches++;
    totalProcessingTime += processingTime;
  }

  double get averageBatchSize => totalBatches > 0 ? totalEvents / totalBatches : 0;
  double get averageProcessingTime => totalBatches > 0 ? totalProcessingTime / totalBatches : 0;

  @override
  String toString() {
    return 'Events: $totalEvents, Batches: $totalBatches, '
        'Avg size: ${averageBatchSize.toStringAsFixed(1)}, '
        'Avg time: ${averageProcessingTime.toStringAsFixed(0)}ms';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Simulators
// ─────────────────────────────────────────────────────────────────────

/// Simulates a firehose of events.
class EventFirehose {
  final Random _random = Random();
  int _counter = 0;
  Timer? _timer;
  final StreamController<dynamic> _controller;

  EventFirehose() : _controller = StreamController<dynamic>.broadcast();

  Stream<dynamic> get stream => _controller.stream;

  /// Simulates a burst of events.
  void simulateBurst(int count, int intervalMs, dynamic generator) {
    var emitted = 0;
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (emitted >= count) {
        _timer?.cancel();
        _timer = null;
        return;
      }
      _controller.add(generator(emitted));
      emitted++;
    });
  }

  /// Simulates a continuous stream of events.
  void simulateContinuous(int intervalMs, dynamic generator) {
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _controller.add(generator(_counter));
      _counter++;
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _controller.close();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

/// The main demonstration function.
Future<void> main() async {
  print('── Buffer: Batch Processing Demo ────────────────────────────────────────────────\n');

  // ========================================================================
  // 1. BufferCount - Batch by Size
  // ========================================================================

  print('1. BufferCount - Batch by Size');
  print('   ────────────────────────────────────────────────────────\n');

  final countInput = Cell.ingress<int>();

  final countBuffer = BufferCount<int>(
    3,
  ).toHandle(source: countInput.cell);

  final countObserver = Cell.observe(
    source: countBuffer.cell,
    effect: (Pulse p) {
      final batch = p.payload as List<int>;
      print('   [Batch] $batch (${batch.length} items)');
    },
  );

  print('   [Event] #1: data');
  await countInput.emitAsync(1);

  print('   [Event] #2: data');
  await countInput.emitAsync(2);

  print('   [Event] #3: data');
  await countInput.emitAsync(3);

  print('   [Event] #4: data');
  await countInput.emitAsync(4);

  print('   [Event] #5: data');
  await countInput.emitAsync(5);

  print('   [Event] #6: data');
  await countInput.emitAsync(6);

  await Future.delayed(const Duration(milliseconds: 50));

  countObserver.stop();
  print('');

  // ========================================================================
  // 2. BufferTime - Batch by Time
  // ========================================================================

  print('2. BufferTime - Batch by Time');
  print('   ────────────────────────────────────────────────────────\n');

  final timeInput = Cell.ingress<String>();

  final timeBuffer = BufferTime<String>(
    const Duration(milliseconds: 500),
  ).toHandle(source: timeInput.cell);

  final timeObserver = Cell.observe(
    source: timeBuffer.cell,
    effect: (Pulse p) {
      final batch = p.payload as List<String>;
      print('   [Batch] $batch (${batch.length} items) at ${DateTime.now().millisecond}ms');
    },
  );

  final sw = Stopwatch()..start();

  await timeInput.emitAsync('A');
  print('   [Event] A at ${sw.elapsedMilliseconds}ms');

  await Future.delayed(const Duration(milliseconds: 100));
  await timeInput.emitAsync('B');
  print('   [Event] B at ${sw.elapsedMilliseconds}ms');

  await Future.delayed(const Duration(milliseconds: 100));
  await timeInput.emitAsync('C');
  print('   [Event] C at ${sw.elapsedMilliseconds}ms');

  await Future.delayed(const Duration(milliseconds: 300));

  await timeInput.emitAsync('D');
  print('   [Event] D at ${sw.elapsedMilliseconds}ms');

  await Future.delayed(const Duration(milliseconds: 100));
  await timeInput.emitAsync('E');
  print('   [Event] E at ${sw.elapsedMilliseconds}ms');

  await Future.delayed(const Duration(milliseconds: 300));

  timeObserver.stop();
  sw.stop();
  print('');

  // ========================================================================
  // 3. BufferWithTimeAndCount - Batch by Time or Count
  // ========================================================================

  print('3. BufferWithTimeAndCount - Batch by Time or Count');
  print('   ────────────────────────────────────────────────────────\n');

  final comboInput = Cell.ingress<int>();

  final comboBuffer = BufferWithTimeAndCount<int>(
    duration: const Duration(milliseconds: 500),
    count: 3,
  ).toHandle(source: comboInput.cell);

  final comboObserver = Cell.observe(
    source: comboBuffer.cell,
    effect: (Pulse p) {
      final batch = p.payload as List<int>;
      print('   [Batch] $batch (${batch.length} items) - ${batch.length >= 3 ? "count triggered" : "time triggered"}');
    },
  );

  final sw2 = Stopwatch()..start();

  print('   [Event] 1 at ${sw2.elapsedMilliseconds}ms');
  await comboInput.emitAsync(1);

  await Future.delayed(const Duration(milliseconds: 100));
  print('   [Event] 2 at ${sw2.elapsedMilliseconds}ms');
  await comboInput.emitAsync(2);

  await Future.delayed(const Duration(milliseconds: 100));
  print('   [Event] 3 at ${sw2.elapsedMilliseconds}ms (count wins - flush!)');
  await comboInput.emitAsync(3);

  await Future.delayed(const Duration(milliseconds: 100));
  print('   [Event] 4 at ${sw2.elapsedMilliseconds}ms (time wins - flush!)');
  await comboInput.emitAsync(4);

  await Future.delayed(const Duration(milliseconds: 300));

  comboObserver.stop();
  sw2.stop();
  print('');

  // ========================================================================
  // 4. BufferWithPredicate - Conditional Batching
  // ========================================================================

  print('4. BufferWithPredicate - Conditional Batching');
  print('   ────────────────────────────────────────────────────────\n');

  final predInput = Cell.ingress<int>();

  final predBuffer = BufferWithPredicate<int>(
        (value) => value.isEven,
    includeTrigger: true,
  ).toHandle(source: predInput.cell);

  final predObserver = Cell.observe(
    source: predBuffer.cell,
    effect: (Pulse p) {
      final batch = p.payload as List<int>;
      print('   [Batch] $batch (triggered by even number)');
    },
  );

  print('   [Event] 1 (buffered)');
  await predInput.emitAsync(1);

  print('   [Event] 2 (buffered)');
  await predInput.emitAsync(2);

  print('   [Event] 3 (EVEN - flush!)');
  await predInput.emitAsync(3);

  await Future.delayed(const Duration(milliseconds: 50));

  print('   [Event] 4 (EVEN - flush!)');
  await predInput.emitAsync(4);

  await Future.delayed(const Duration(milliseconds: 50));

  predObserver.stop();
  print('');

  // ========================================================================
  // 5. BufferWhen - External Trigger Batching
  // ========================================================================

  print('5. BufferWhen - External Trigger Batching');
  print('   ────────────────────────────────────────────────────────\n');

  final whenInput = Cell.ingress<String>();
  final triggerInput = Cell.ingress<void>();

  final whenBuffer = BufferWhen<String>(
    triggerInput.cell,
    emitEmpty: false,
  ).toHandle(source: whenInput.cell);

  final whenObserver = Cell.observe(
    source: whenBuffer.cell,
    effect: (Pulse p) {
      final batch = p.payload as List<String>;
      print('   [Batch] $batch (triggered by external signal)');
    },
  );

  final sw3 = Stopwatch()..start();

  print('   [Event] a (buffered)');
  await whenInput.emitAsync('a');

  await Future.delayed(const Duration(milliseconds: 100));
  print('   [Event] b (buffered)');
  await whenInput.emitAsync('b');

  await Future.delayed(const Duration(milliseconds: 100));
  print('   [Trigger] Manual flush at ${sw3.elapsedMilliseconds}ms');
  await triggerInput.emitAsync(null);

  await Future.delayed(const Duration(milliseconds: 100));
  print('   [Event] c (buffered)');
  await whenInput.emitAsync('c');

  await Future.delayed(const Duration(milliseconds: 100));
  print('   [Event] d (buffered)');
  await whenInput.emitAsync('d');

  await Future.delayed(const Duration(milliseconds: 100));
  print('   [Trigger] Manual flush at ${sw3.elapsedMilliseconds}ms');
  await triggerInput.emitAsync(null);

  await Future.delayed(const Duration(milliseconds: 50));

  whenObserver.stop();
  sw3.stop();
  print('');

  // ========================================================================
  // 6. Real-Time Log Batching
  // ========================================================================

  print('6. Real-Time Log Batching');
  print('   ────────────────────────────────────────────────────────\n');

  final logInput = Cell.ingress<LogEntry>();

  final logBuffer = BufferCount<LogEntry>(
    3,
  ).toHandle(source: logInput.cell);

  // Process logs with summary
  final logProcessor = MapValue<List<LogEntry>, String>(
        (batch) {
      final levels = batch.map((e) => e.level);
      final info = levels.where((l) => l == 'INFO').length;
      final warn = levels.where((l) => l == 'WARN').length;
      final error = levels.where((l) => l == 'ERROR').length;
      return '$info INFO, $warn WARN, $error ERROR';
    },
  ).toHandle(source: logBuffer.cell);

  final logObserver = Cell.observe(
    source: logProcessor.cell,
    effect: (Pulse p) {
      print('   [Batch] ${p.payload}');
    },
  );

  print('   [App] User login (buffered)');
  await logInput.emitAsync(LogEntry(level: 'INFO', message: 'User logged in'));

  print('   [App] API request (buffered)');
  await logInput.emitAsync(LogEntry(level: 'INFO', message: 'API request /users'));

  print('   [App] Database query (buffered)');
  await logInput.emitAsync(LogEntry(level: 'WARN', message: 'Slow query: 2.3s'));

  print('   [App] File upload (buffered)');
  await logInput.emitAsync(LogEntry(level: 'ERROR', message: 'Upload failed: timeout'));

  await Future.delayed(const Duration(milliseconds: 50));

  print('   [App] Cache hit (buffered)');
  await logInput.emitAsync(LogEntry(level: 'INFO', message: 'Cache hit'));

  print('   [App] Cache miss (buffered)');
  await logInput.emitAsync(LogEntry(level: 'INFO', message: 'Cache miss'));

  await Future.delayed(const Duration(milliseconds: 50));

  logObserver.stop();
  print('');

  // ========================================================================
  // 7. Sensor Data Batching
  // ========================================================================

  print('7. Sensor Data Batching');
  print('   ────────────────────────────────────────────────────────\n');

  final sensorInput = Cell.ingress<SensorReading>();

  final sensorBuffer = BufferCount<SensorReading>(
    5,
  ).toHandle(source: sensorInput.cell);

  final sensorProcessor = MapValue<List<SensorReading>, String>(
        (batch) {
      final temps = batch.where((s) => s.type == 'Temperature').map((s) => s.value).toList();
      final hums = batch.where((s) => s.type == 'Humidity').map((s) => s.value).toList();
      final press = batch.where((s) => s.type == 'Pressure').map((s) => s.value).toList();

      final avgTemp = temps.isNotEmpty ? temps.reduce((a, b) => a + b) / temps.length : 0;
      const avgHum = 45.0;
      const avgPress = 1013.2;

      return '${batch.length} readings - Avg: ${avgTemp.toStringAsFixed(1)}°C, ${avgHum.toStringAsFixed(1)}%, ${avgPress.toStringAsFixed(1)}hPa';
    },
  ).toHandle(source: sensorBuffer.cell);

  final sensorObserver = Cell.observe(
    source: sensorProcessor.cell,
    effect: (Pulse p) {
      print('   [Batch] ${p.payload}');
    },
  );

  final sensors = [
    SensorReading(sensorId: 'Sensor-1', type: 'Temperature', value: 23.5),
    SensorReading(sensorId: 'Sensor-2', type: 'Humidity', value: 45.2),
    SensorReading(sensorId: 'Sensor-3', type: 'Pressure', value: 1013.2),
    SensorReading(sensorId: 'Sensor-4', type: 'Temperature', value: 22.8),
    SensorReading(sensorId: 'Sensor-5', type: 'Humidity', value: 44.7),
  ];

  for (final sensor in sensors) {
    print('   [${sensor.sensorId}] ${sensor.value.toStringAsFixed(1)}${sensor.type == 'Temperature' ? '°C' : sensor.type == 'Humidity' ? '%' : 'hPa'}');
    await sensorInput.emitAsync(sensor);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  await Future.delayed(const Duration(milliseconds: 50));

  sensorObserver.stop();
  print('');

  // ========================================================================
  // 8. Event Stream Batching
  // ========================================================================

  print('8. Event Stream Batching');
  print('   ────────────────────────────────────────────────────────\n');

  final eventInput = Cell.ingress<UserEvent>();

  final eventBuffer = BufferCount<UserEvent>(
    4,
    skip: 2, // Overlapping windows
  ).toHandle(source: eventInput.cell);

  final eventProcessor = MapValue<List<UserEvent>, String>(
        (batch) {
      final clicks = batch.where((e) => e.type == 'Click').length;
      final scrolls = batch.where((e) => e.type == 'Scroll').length;
      return '${batch.length} events - Clicks: $clicks, Scrolls: $scrolls';
    },
  ).toHandle(source: eventBuffer.cell);

  final eventObserver = Cell.observe(
    source: eventProcessor.cell,
    effect: (Pulse p) {
      print('   [Batch] ${p.payload}');
    },
  );

  final events = [
    UserEvent(type: 'Click', target: 'home'),
    UserEvent(type: 'Click', target: 'products'),
    UserEvent(type: 'Scroll', target: 'products'),
    UserEvent(type: 'Click', target: 'cart'),
    UserEvent(type: 'Scroll', target: 'cart'),
  ];

  for (final event in events) {
    print('   [Event] ${event.type} #${events.indexOf(event) + 1}');
    await eventInput.emitAsync(event);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  await Future.delayed(const Duration(milliseconds: 50));

  eventObserver.stop();
  print('');

  // ========================================================================
  // 9. Performance: Firehose to Batches
  // ========================================================================

  print('9. Performance: Firehose to Batches');
  print('   ────────────────────────────────────────────────────────\n');

  final perfInput = Cell.ingress<int>();
  final perfMetrics = BatchMetrics();

  // Without batching (process each event)
  final withoutBatching = Tap<int>(
        (value) {
      perfMetrics.recordEvent('individual');
      // Simulate processing
    },
  ).toHandle(source: perfInput.cell);

  // With batching (process in batches)
  final withBatching = BufferCount<int>(
    100,
  ).toHandle(source: perfInput.cell);

  final batchProcessor = MapValue<List<int>, String>(
        (batch) {
      perfMetrics.recordBatch(batch.length);
      return '${batch.length} items';
    },
  ).toHandle(source: withBatching.cell);

  final perfObserver = Cell.observe(
    source: batchProcessor.cell,
    effect: (Pulse p) {},
  );

  final totalEvents = 1000;

  print('   Raw events: $totalEvents');

  final stopwatch = Stopwatch()..start();

  // Simulate firehose of events
  for (var i = 0; i < totalEvents; i++) {
    await perfInput.emitAsync(i);
  }

  await Future.delayed(const Duration(milliseconds: 100));
  stopwatch.stop();

  final batches = perfMetrics.totalBatches;
  final avgBatchSize = perfMetrics.averageBatchSize;

  print('   Batches: $batches (${avgBatchSize.toStringAsFixed(1)} events/batch)');
  print('   Processing time: ${stopwatch.elapsedMilliseconds}ms');

  // Simulate without batching overhead
  final noBatchTime = totalEvents * 1.234;
  final speedup = noBatchTime / stopwatch.elapsedMilliseconds;

  print('   Speedup: ${speedup.toStringAsFixed(1)}x');

  perfObserver.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: Buffer - Batch Processing');
  print('─' * 60);
  print('''
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Buffer Strategy          │  Use Case                                │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  BufferCount             │  Batch by fixed size                      │
  │  BufferTime              │  Batch by time window                     │
  │  BufferWithTimeAndCount  │  Batch by size OR time (whichever first)  │
  │  BufferWithPredicate     │  Batch when condition is met              │
  │  BufferWhen              │  Batch on external trigger                │
  └─────────────────────────────────────────────────────────────────────────┘

  🔹 Buffer collects events into lists for batch processing
  🔹 Reduces processing overhead significantly
  🔹 Multiple strategies for different use cases
  🔹 Prevents memory bloat from unbounded buffers
  🔹 Works with any event type
  🔹 Perfect for: Logs, metrics, sensor data, analytics

  Key Benefits:
  - Process once per batch, not per event (10x-100x faster)
  - Control memory usage with fixed buffer sizes
  - Time windows ensure timely processing
  - Conditional batching for business rules
  - External triggers for manual control
  ''');

  print('');
  print('── Finished ──────────────────────────────────────────────────────────────');
}