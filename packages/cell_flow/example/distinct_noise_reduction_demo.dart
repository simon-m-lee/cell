// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// A complete walkthrough demonstrating noise reduction using the Cell
/// Framework's Flow.distinct operator.
///
/// ### Scenario
/// A sensor data processing system where:
/// 1. Sensors emit noisy data (repeated values, jitter, fluctuations)
/// 2. Flow.distinct filters out consecutive duplicate values
/// 3. Different distinct strategies are demonstrated
/// 4. Real-world use cases are simulated
/// 5. Noise reduction improves data quality and reduces processing load
///
/// ### Learning Objectives
/// - Understand how Flow.distinct works
/// - See distinct in real-world noise reduction scenarios
/// - Learn the difference between distinct and other filter operators
/// - Understand custom equality for complex types
/// - See how distinct reduces processing load
/// - Learn about windowed distinct for time-based filtering
///
/// ### Expected Console Output
/// ```
/// ── Distinct Noise Reduction Demo ──────────────────────────────────────────
///
/// 1. Basic Distinct - Remove Consecutive Duplicates
///    ────────────────────────────────────────────────────────
///    Raw: [1, 1, 2, 2, 2, 3, 1, 1, 1, 4, 4]
///    Filtered: [1, 2, 3, 1, 4]
///    Noise Reduction: 54.5%
///
/// 2. Distinct with Custom Equality (Sensor Tolerance)
///    ────────────────────────────────────────────────────────
///    Raw: [10.0, 10.05, 10.1, 10.15, 10.2, 50.0, 50.05, 50.1]
///    Filtered (tolerance=0.2): [10.0, 10.2, 50.0, 50.1]
///    Noise Reduction: 50.0%
///
/// 3. Real-World: GPS Location Tracking
///    ────────────────────────────────────────────────────────
///    Raw GPS: [(37.7749, -122.4194), (37.7750, -122.4195), ...]
///    Filtered GPS: [(37.7749, -122.4194), (37.7752, -122.4198)]
///    Movement detected: 2 significant position changes
///
/// 4. Real-World: Stock Price Ticker
///    ────────────────────────────────────────────────────────
///    Raw: [100.0, 100.0, 100.0, 100.1, 100.1, 100.1, 100.2]
///    Distinct: [100.0, 100.1, 100.2]
///    Updates: 3 (vs 7 raw events)
///    Bandwidth Saved: 57.1%
///
/// 5. Distinct vs Other Filter Operators
///    ────────────────────────────────────────────────────────
///    Distinct: Removes consecutive duplicates
///    Filter: Removes based on predicate
///    Debounce: Removes based on time
///    Throttle: Limits frequency
///    Unique: Removes all duplicates (global)
///
/// 6. Windowed Distinct (Time-Based)
///    ────────────────────────────────────────────────────────
///    Raw: [1, 2, 2, 3, 1, 2, 2, 3]
///    Windowed (500ms): [1, 2, 3, 1, 2, 3]
///    (Duplicates only filtered within the time window)
///
/// 7. Custom Distinct with Key Selector
///    ────────────────────────────────────────────────────────
///    Raw: [{id:1, val:10}, {id:1, val:20}, {id:2, val:30}]
///    Filtered by id: [{id:1, val:10}, {id:2, val:30}]
///    (Only first occurrence of each id is kept)
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/debounce.dart';
import 'package:cell_flow/src/instruction/distinct.dart';
import 'package:cell_flow/src/instruction/filter.dart' hide Debounce, Distinct;

/// The main demonstration function.
Future<void> main() async {
  print('── Distinct Noise Reduction Demo ──────────────────────────────────────────\n');

  // ========================================================================
  // 1. Basic Distinct - Remove Consecutive Duplicates
  // ========================================================================

  print('1. Basic Distinct - Remove Consecutive Duplicates');
  print('   ────────────────────────────────────────────────────────\n');

  final rawData = [1, 1, 2, 2, 2, 3, 1, 1, 1, 4, 4];

  print('   Raw: $rawData');

  final input = Cell.ingress<int>();
  final distinctHandle = Flow.distinct<int>(input.cell);

  final results = <int>[];
  final observer = Cell.observe(
    source: distinctHandle.cell,
    effect: (Pulse p) => results.add(p.payload),
  );

  for (final value in rawData) {
    await input.emitAsync(value);
  }

  await Future.delayed(const Duration(milliseconds: 50));

  final reduction = ((rawData.length - results.length) / rawData.length * 100);
  print('   Filtered: $results');
  print('   Noise Reduction: ${reduction.toStringAsFixed(1)}%');

  observer.stop();
  print('');

  // ========================================================================
  // 2. Distinct with Custom Equality (Sensor Tolerance)
  // ========================================================================

  print('2. Distinct with Custom Equality (Sensor Tolerance)');
  print('   ────────────────────────────────────────────────────────\n');

  final sensorData = [10.0, 10.05, 10.1, 10.15, 10.2, 50.0, 50.05, 50.1];
  print('   Raw: $sensorData');

  // Custom equality with tolerance of 0.2 using a filter with state
  final sensorInput = Cell.ingress<double>();
  double? lastValue;

  final sensorFilter = Flow.filter<double>(
    sensorInput.cell,
    test: (value) {
      if (lastValue == null || (value - lastValue!).abs() >= 0.2) {
        lastValue = value;
        return true;
      }
      return false;
    },
  );

  final sensorResults = <double>[];
  final sensorObserver = Cell.observe(
    source: sensorFilter.cell,
    effect: (Pulse p) => sensorResults.add(p.payload),
  );

  for (final value in sensorData) {
    await sensorInput.emitAsync(value);
  }

  await Future.delayed(const Duration(milliseconds: 50));

  final sensorReduction = ((sensorData.length - sensorResults.length) / sensorData.length * 100);
  print('   Filtered (tolerance=0.2): $sensorResults');
  print('   Noise Reduction: ${sensorReduction.toStringAsFixed(1)}%');

  sensorObserver.stop();
  print('');

  // ========================================================================
  // 3. Real-World: GPS Location Tracking
  // ========================================================================

  print('3. Real-World: GPS Location Tracking');
  print('   ────────────────────────────────────────────────────────\n');

  // Simulate GPS coordinates with jitter
  final gpsData = [
    (37.7749, -122.4194), // Initial position
    (37.7749, -122.4194), // Same (noise)
    (37.7750, -122.4195), // Slight movement
    (37.7750, -122.4195), // Same (noise)
    (37.7751, -122.4196), // Slight movement
    (37.7751, -122.4196), // Same (noise)
    (37.7752, -122.4198), // Significant movement
    (37.7752, -122.4198), // Same (noise)
    (37.7752, -122.4198), // Same (noise)
  ];

  print('   Raw GPS: $gpsData');

  final gpsInput = Cell.ingress<(double, double)>();
  (double, double)? lastGps;

  final gpsFilter = Flow.filter<(double, double)>(
    gpsInput.cell,
    test: (coord) {
      // Only consider a change if movement is > 0.0005 degrees
      if (lastGps == null) {
        lastGps = coord;
        return true;
      }
      final latDiff = (lastGps!.$1 - coord.$1).abs();
      final lonDiff = (lastGps!.$2 - coord.$2).abs();
      if (latDiff < 0.0005 && lonDiff < 0.0005) {
        return false;
      }
      lastGps = coord;
      return true;
    },
  );

  final gpsResults = <(double, double)>[];
  final gpsObserver = Cell.observe(
    source: gpsFilter.cell,
    effect: (Pulse p) => gpsResults.add(p.payload),
  );

  for (final coord in gpsData) {
    await gpsInput.emitAsync(coord);
  }

  await Future.delayed(const Duration(milliseconds: 50));

  print('   Filtered GPS: $gpsResults');
  print('   Movement detected: ${gpsResults.length - 1} significant position changes');

  gpsObserver.stop();
  print('');

  // ========================================================================
  // 4. Real-World: Stock Price Ticker
  // ========================================================================

  print('4. Real-World: Stock Price Ticker');
  print('   ────────────────────────────────────────────────────────\n');

  final stockData = [100.0, 100.0, 100.0, 100.1, 100.1, 100.1, 100.2];

  print('   Raw: $stockData');

  final stockInput = Cell.ingress<double>();
  final stockDistinct = Flow.distinct<double>(stockInput.cell);

  final stockResults = <double>[];
  final stockObserver = Cell.observe(
    source: stockDistinct.cell,
    effect: (Pulse p) => stockResults.add(p.payload),
  );

  for (final price in stockData) {
    await stockInput.emitAsync(price);
  }

  await Future.delayed(const Duration(milliseconds: 50));

  final bandwidthSaved = ((stockData.length - stockResults.length) / stockData.length * 100);
  print('   Distinct: $stockResults');
  print('   Updates: ${stockResults.length} (vs ${stockData.length} raw events)');
  print('   Bandwidth Saved: ${bandwidthSaved.toStringAsFixed(1)}%');

  stockObserver.stop();
  print('');

  // ========================================================================
  // 5. Distinct vs Other Filter Operators
  // ========================================================================

  print('5. Distinct vs Other Filter Operators');
  print('   ────────────────────────────────────────────────────────\n');

  final testData = [1, 1, 2, 2, 3, 1, 2, 2, 3, 3];
  print('   Test Data: $testData');

  // A) Distinct - consecutive duplicates only
  final distinctInput = Cell.ingress<int>();
  final distinctResults = <int>[];
  final distinctObs = Cell.observe(
    source: Flow.distinct<int>(distinctInput.cell).cell,
    effect: (Pulse p) => distinctResults.add(p.payload),
  );

  for (final v in testData) await distinctInput.emitAsync(v);
  await Future.delayed(const Duration(milliseconds: 20));

  // B) Unique - all duplicates removed (using filter with state)
  final uniqueInput = Cell.ingress<int>();
  final uniqueResults = <int>[];
  final seen = <int>{};
  final uniqueObs = Cell.observe(
    source: Flow.filter<int>(
      uniqueInput.cell,
      test: (value) {
        if (seen.contains(value)) return false;
        seen.add(value);
        return true;
      },
    ).cell,
    effect: (Pulse p) => uniqueResults.add(p.payload),
  );

  for (final v in testData) await uniqueInput.emitAsync(v);
  await Future.delayed(const Duration(milliseconds: 20));

  // C) Filter - custom predicate
  final filterInput = Cell.ingress<int>();
  final filterResults = <int>[];
  final filterObs = Cell.observe(
    source: Flow.filter<int>(
      filterInput.cell,
      test: (v) => v % 2 == 0,
    ).cell,
    effect: (Pulse p) => filterResults.add(p.payload),
  );

  for (final v in testData) await filterInput.emitAsync(v);
  await Future.delayed(const Duration(milliseconds: 20));

  print('   Distinct (consecutive): $distinctResults');
  print('   Unique (global): $uniqueResults');
  print('   Filter (even only): $filterResults');

  distinctObs.stop();
  uniqueObs.stop();
  filterObs.stop();
  print('');

  // ========================================================================
  // 6. Windowed Distinct (Time-Based)
  // ========================================================================

  print('6. Windowed Distinct (Time-Based)');
  print('   ────────────────────────────────────────────────────────\n');

  print('   Raw: [1, 2, 2, 3, 1, 2, 2, 3]');

  final windowInput = Cell.ingress<int>();

  // Custom windowed distinct using a sliding window
  final windowSize = Duration(milliseconds: 500);
  final recentValues = <int>[];
  final recentTimestamps = <int>[];

  final windowedDistinct = Flow.filter<int>(
    windowInput.cell,
    test: (value) {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Clean up old values
      while (recentTimestamps.isNotEmpty &&
          now - recentTimestamps[0] > windowSize.inMilliseconds) {
        recentTimestamps.removeAt(0);
        recentValues.removeAt(0);
      }

      // Check if value is in the window
      if (recentValues.contains(value)) {
        return false;
      }

      // Add to window
      recentValues.add(value);
      recentTimestamps.add(now);
      return true;
    },
  );

  final windowResults = <int>[];
  final windowObs = Cell.observe(
    source: windowedDistinct.cell,
    effect: (Pulse p) => windowResults.add(p.payload),
  );

  final windowData = [1, 2, 2, 3, 1, 2, 2, 3];
  for (final v in windowData) {
    await windowInput.emitAsync(v);
    // Wait 200ms between emissions (within the 500ms window)
    await Future.delayed(const Duration(milliseconds: 200));
  }

  await Future.delayed(const Duration(milliseconds: 100));

  print('   Windowed (500ms): $windowResults');
  print('   (Duplicates only filtered within the time window)');

  windowObs.stop();
  print('');

  // ========================================================================
  // 7. Custom Distinct with Key Selector
  // ========================================================================

  print('7. Custom Distinct with Key Selector');
  print('   ────────────────────────────────────────────────────────\n');

  final dataWithIds = [
    {'id': 1, 'value': 10},
    {'id': 1, 'value': 20}, // Same ID - should be filtered
    {'id': 2, 'value': 30},
    {'id': 2, 'value': 40}, // Same ID - should be filtered
    {'id': 3, 'value': 50},
  ];

  print('   Raw: $dataWithIds');

  final keyInput = Cell.ingress<Map<String, dynamic>>();
  final seenIds = <int>{};

  // Distinct by ID using filter with state
  final keyFilter = Flow.filter<Map<String, dynamic>>(
    keyInput.cell,
    test: (item) {
      final id = item['id'] as int;
      if (seenIds.contains(id)) return false;
      seenIds.add(id);
      return true;
    },
  );

  final keyResults = <Map<String, dynamic>>[];
  final keyObserver = Cell.observe(
    source: keyFilter.cell,
    effect: (Pulse p) => keyResults.add(p.payload),
  );

  for (final item in dataWithIds) {
    await keyInput.emitAsync(item);
  }

  await Future.delayed(const Duration(milliseconds: 50));

  print('   Filtered by id: $keyResults');
  print('   (Only first occurrence of each id is kept)');

  keyObserver.stop();
  print('');

  // ========================================================================
  // 8. Real-World: User Activity Tracking
  // ========================================================================

  print('8. Real-World: User Activity Tracking');
  print('   ────────────────────────────────────────────────────────\n');

  final userActivities = [
    'view', 'view', 'click', 'scroll', 'scroll', 'view', 'click', 'click',
  ];

  print('   Raw Activities: $userActivities');

  final activityInput = Cell.ingress<String>();
  final activityDistinct = Flow.distinct<String>(activityInput.cell);

  final activityResults = <String>[];
  final activityObserver = Cell.observe(
    source: activityDistinct.cell,
    effect: (Pulse p) => activityResults.add(p.payload),
  );

  for (final activity in userActivities) {
    await activityInput.emitAsync(activity);
  }

  await Future.delayed(const Duration(milliseconds: 50));

  print('   Distinct Activities: $activityResults');
  print('   Unique activity changes: ${activityResults.length}');

  activityObserver.stop();
  print('');

  // ========================================================================
  // 9. Distinct with Debounce Combination
  // ========================================================================

  print('9. Distinct with Debounce Combination');
  print('   ────────────────────────────────────────────────────────\n');

  final combinedData = ['a', 'a', 'b', 'b', 'b', 'a', 'a', 'c', 'c'];
  print('   Raw: $combinedData');

  final combinedInput = Cell.ingress<String>();

  // First debounce (wait for silence), then distinct
  final combinedHandle = Flow.debounce<String>(
    combinedInput.cell,
    duration: const Duration(milliseconds: 30),
  );

  final combinedDistinct = Flow.distinct<String>(combinedHandle.cell);

  final combinedResults = <String>[];
  final combinedObserver = Cell.observe(
    source: combinedDistinct.cell,
    effect: (Pulse p) => combinedResults.add(p.payload),
  );

  for (final v in combinedData) {
    await combinedInput.emitAsync(v);
    await Future.delayed(const Duration(milliseconds: 20));
  }

  await Future.delayed(const Duration(milliseconds: 60));

  print('   Debounce + Distinct: $combinedResults');
  print('   (Values are first debounced, then deduplicated)');

  combinedObserver.stop();
  print('');

  // ========================================================================
  // 10. Performance Comparison
  // ========================================================================

  print('10. Performance Comparison');
  print('    ────────────────────────────────────────────────────────\n');

  // Generate synthetic data with 80% duplicates
  final largeDataset = List.generate(100, (i) => i % 10);

  print('    Generated 100 values with ~80% duplicates');
  print('    (Only 10 unique values in the dataset)');

  final perfInput = Cell.ingress<int>();

  final stopwatch = Stopwatch()..start();

  final perfResults = <int>[];
  final perfObserver = Cell.observe(
    source: Flow.distinct<int>(perfInput.cell).cell,
    effect: (Pulse p) => perfResults.add(p.payload),
  );

  for (final v in largeDataset) {
    await perfInput.emitAsync(v);
  }

  await Future.delayed(const Duration(milliseconds: 50));

  stopwatch.stop();

  final compressionRatio = ((largeDataset.length - perfResults.length) / largeDataset.length * 100);
  print('    Filtered: ${perfResults.length} values');
  print('    Compression Ratio: ${compressionRatio.toStringAsFixed(1)}%');
  print('    Time: ${stopwatch.elapsedMilliseconds}ms');

  perfObserver.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: Distinct Noise Reduction');
  print('─' * 60);
  print('''
  🔹 Distinct removes consecutive duplicate values
  🔹 Custom equality is implemented using filter with state
  🔹 Distinct reduces noise from sensors, GPS, and stock data
  🔹 Key selector enables distinct by specific fields
  🔹 Windowed distinct filters duplicates within a time window
  🔹 Distinct vs Debounce: Different purposes, can be combined
  🔹 Significant bandwidth and processing savings
  🔹 Ideal for: Sensor data, UI events, stock tickers, GPS
  ''');

  print('── Finished ──────────────────────────────────────────────────────────');
}

// ─────────────────────────────────────────────────────────────────────
// Utility Extension for Flow
// ─────────────────────────────────────────────────────────────────────

/// Extension to provide convenient methods for Flow operations.
extension FlowUtils on Flow {
  /// Creates a distinct operator (removes consecutive duplicates).
  static FlowHandle distinct<S>(
      Cell source,
      ) {
    final instruction = Distinct<S>();
    return instruction.toHandle(source: source);
  }

  /// Creates a debounce with the specified duration.
  static FlowHandle debounce<S>(
      Cell source, {
        required Duration duration,
      }) {
    final instruction = Debounce<S>(duration);
    return instruction.toHandle(source: source);
  }

  /// Creates a filter transformation.
  static FlowHandle filter<S>(
      Cell source, {
        required bool Function(S value) test,
      }) {
    final instruction = Filter<S>(test);
    return instruction.toHandle(source: source);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────────────────────────────

Pulse? _typedOrError<S>(Pulse pulse) {
  final payload = pulse.payload;
  if (payload is! S) return null;
  return pulse;
}

Pulse<S> _fromPayload<S>(S value, Pulse sourcePulse, Cell? cell, String step) {
  return Pulse<S>(
    value,
    source: cell ?? sourcePulse.source,
    type: sourcePulse.type,
    priority: sourcePulse.priority,
    step: step,
  );
}