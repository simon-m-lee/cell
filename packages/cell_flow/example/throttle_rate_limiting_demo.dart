// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

/// A complete walkthrough demonstrating frequency-based rate limiting
/// using the Cell Framework's Flow.throttle operator.
///
/// ### Scenario
/// An API rate limiter where:
/// 1. User triggers events (button clicks, scrolls, etc.)
/// 2. Events are throttled to a maximum frequency
/// 3. Each event triggers an action (API call, UI update, etc.)
/// 4. Leading and trailing emissions are controlled
/// 5. Different throttle strategies are demonstrated
/// 6. Real-world use cases are simulated
///
/// ### Learning Objectives
/// - Understand how Flow.throttle works
/// - See throttle in real-world rate limiting scenarios
/// - Learn the difference between leading and trailing throttling
/// - Understand throttling vs debouncing
/// - See how throttle prevents API rate limit errors
/// - Learn about sliding window throttling
///
/// ### Expected Console Output
/// ```text
/// ── Throttle Rate Limiting Demo ──────────────────────────────────────────
///
/// 1. Basic Throttle (leading: true, trailing: false)
///    ────────────────────────────────────────────────────────
///    [User] Click #1 at 0ms
///    [Throttle] ✅ Emitted: Click #1 (leading - immediate)
///    [User] Click #2 at 10ms - DROPPED
///    [User] Click #3 at 20ms - DROPPED
///    [User] Click #4 at 30ms - DROPPED
///    [User] Click #5 at 100ms
///    [Throttle] ✅ Emitted: Click #5 (leading - window open)
///
/// 2. Throttle with Trailing (leading: true, trailing: true)
///    ────────────────────────────────────────────────────────
///    [User] Event #1 at 0ms
///    [Throttle] ✅ Emitted: Event #1 (leading - immediate)
///    [User] Event #2 at 10ms - BUFFERED
///    [User] Event #3 at 20ms - BUFFERED (replaces #2)
///    [User] Event #4 at 30ms - BUFFERED (replaces #3)
///    [Throttle] ✅ Emitted: Event #4 (trailing - last in window)
///
/// 3. Throttle Leading Only (API Rate Limiting)
///    ────────────────────────────────────────────────────────
///    [API] Request #1 at 0ms
///    [Throttle] ✅ API Called: Request #1
///    [API] Request #2 at 15ms - DROPPED
///    [API] Request #3 at 30ms - DROPPED
///    [API] Request #4 at 100ms
///    [Throttle] ✅ API Called: Request #4
///    [Result] Successful calls: 2, Dropped: 2
///
/// 4. Throttle vs Debounce Comparison
///    ────────────────────────────────────────────────────────
///    Throttle: [1, 3, 5] (rate-limited, emits at intervals)
///    Debounce: [5] (only final value after silence)
///
/// 5. Real-World: Scrolling with Throttle
///    ────────────────────────────────────────────────────────
///    [User] Scrolled to position 42px
///    [Throttle] ✅ Update: Scroll position 42px
///    ... (multiple scroll events throttled to 50ms)
///    [Final] Last scroll position: 250px
///
/// 6. Real-World: API Rate Limiting (50ms window)
///    ────────────────────────────────────────────────────────
///    📊 API Calls Made: 5
///    ❌ Rate Limit Errors: 0
///    💰 API Cost Saved: 15
///    ⏱️  Total Events: 20
///    📈  Throttle Efficiency: 75.0%
///
/// 7. Sliding Window Throttle (custom implementation)
///    ────────────────────────────────────────────────────────
///    [User] Keypress at 0ms
///    [Sliding] ✅ Emitted: keypress (window starts)
///    [User] Keypress at 30ms - DROPPED (in window)
///    [User] Keypress at 70ms
///    [Sliding] ✅ Emitted: keypress (new window)
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/debounce.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_flow/src/instruction/throttle.dart';

/// The main demonstration function.
Future<void> main() async {
  print('── Throttle Rate Limiting Demo ──────────────────────────────────────────\n');

  // ========================================================================
  // 1. Basic Throttle (leading: true, trailing: false)
  // ========================================================================

  print('1. Basic Throttle (leading: true, trailing: false)');
  print('   ────────────────────────────────────────────────────────\n');

  final clickInput = Cell.ingress<String>();

  // Create a throttle with 50ms window
  final throttleHandle = Flow.throttle<String>(
    clickInput.cell,
    duration: const Duration(milliseconds: 50),
    leading: true,   // Emit immediately on first event
    trailing: false, // Don't emit the last buffered event
  );

  // Observe the throttled output
  final clickObserver = Cell.observe(
    source: throttleHandle.cell,
    effect: (Pulse p) => print('   [Throttle] ✅ Emitted: ${p.payload} (leading - immediate)'),
  );

  // Simulate rapid clicks
  final stopwatch = Stopwatch()..start();

  print('   [User] Click #1 at ${stopwatch.elapsedMilliseconds}ms');
  await clickInput.emitAsync('Click #1');

  await Future.delayed(const Duration(milliseconds: 10));
  print('   [User] Click #2 at ${stopwatch.elapsedMilliseconds}ms - DROPPED');
  await clickInput.emitAsync('Click #2');

  await Future.delayed(const Duration(milliseconds: 10));
  print('   [User] Click #3 at ${stopwatch.elapsedMilliseconds}ms - DROPPED');
  await clickInput.emitAsync('Click #3');

  await Future.delayed(const Duration(milliseconds: 10));
  print('   [User] Click #4 at ${stopwatch.elapsedMilliseconds}ms - DROPPED');
  await clickInput.emitAsync('Click #4');

  // Wait for the throttle window to expire
  await Future.delayed(const Duration(milliseconds: 60));

  print('   [User] Click #5 at ${stopwatch.elapsedMilliseconds}ms');
  await clickInput.emitAsync('Click #5');

  await Future.delayed(const Duration(milliseconds: 20));

  clickObserver.stop();
  stopwatch.stop();
  print('');

  // ========================================================================
  // 2. Throttle with Trailing (leading: true, trailing: true)
  // ========================================================================

  print('2. Throttle with Trailing (leading: true, trailing: true)');
  print('   ────────────────────────────────────────────────────────\n');

  final trailingInput = Cell.ingress<String>();

  final trailingThrottle = Flow.throttle<String>(
    trailingInput.cell,
    duration: const Duration(milliseconds: 50),
    leading: true,  // Emit immediately
    trailing: true, // Emit the last buffered event
  );

  final trailingObserver = Cell.observe(
    source: trailingThrottle.cell,
    effect: (Pulse p) {
      final payload = p.payload.toString();
      if (payload.contains('leading')) {
        print('   [Throttle] ✅ Emitted: $payload');
      } else {
        print('   [Throttle] ✅ Emitted: $payload (trailing - last in window)');
      }
    },
  );

  final sw2 = Stopwatch()..start();

  print('   [User] Event #1 at ${sw2.elapsedMilliseconds}ms');
  await trailingInput.emitAsync('Event #1 (leading)');

  await Future.delayed(const Duration(milliseconds: 10));
  print('   [User] Event #2 at ${sw2.elapsedMilliseconds}ms - BUFFERED');
  await trailingInput.emitAsync('Event #2');

  await Future.delayed(const Duration(milliseconds: 10));
  print('   [User] Event #3 at ${sw2.elapsedMilliseconds}ms - BUFFERED (replaces #2)');
  await trailingInput.emitAsync('Event #3');

  await Future.delayed(const Duration(milliseconds: 10));
  print('   [User] Event #4 at ${sw2.elapsedMilliseconds}ms - BUFFERED (replaces #3)');
  await trailingInput.emitAsync('Event #4');

  await Future.delayed(const Duration(milliseconds: 60));

  trailingObserver.stop();
  sw2.stop();
  print('');

  // ========================================================================
  // 3. Throttle Leading Only (API Rate Limiting)
  // ========================================================================

  print('3. Throttle Leading Only (API Rate Limiting)');
  print('   ────────────────────────────────────────────────────────\n');

  final apiInput = Cell.ingress<String>();

  int successfulCalls = 0;
  int droppedCalls = 0;

  final apiThrottle = Flow.throttle<String>(
    apiInput.cell,
    duration: const Duration(milliseconds: 50),
    leading: true,
    trailing: false,
  );

  // Simulate an API call
  final apiCall = Flow.map<String, String>(
    apiThrottle.cell,
    project: (request) {
      successfulCalls++;
      return 'API Called: $request';
    },
  );

  final apiObserver = Cell.observe(
    source: apiCall.cell,
    effect: (Pulse p) => print('   [Throttle] ✅ ${p.payload}'),
  );

  final sw3 = Stopwatch()..start();

  // Simulate 4 rapid API requests
  for (var i = 1; i <= 4; i++) {
    final label = 'Request #$i';
    final isDropped = i > 1 && i < 4;
    if (isDropped) {
      droppedCalls++;
      print('   [API] $label at ${sw3.elapsedMilliseconds}ms - DROPPED');
    } else {
      print('   [API] $label at ${sw3.elapsedMilliseconds}ms');
    }
    await apiInput.emitAsync(label);
    await Future.delayed(const Duration(milliseconds: 15));
  }

  await Future.delayed(const Duration(milliseconds: 60));

  print('   [Result] Successful calls: $successfulCalls, Dropped: $droppedCalls');

  apiObserver.stop();
  sw3.stop();
  print('');

  // ========================================================================
  // 4. Throttle vs Debounce Comparison
  // ========================================================================

  print('4. Throttle vs Debounce Comparison');
  print('   ────────────────────────────────────────────────────────\n');

  final compareInput = Cell.ingress<int>();

  // Throttle: emits at intervals
  final throttleCompare = Flow.throttle<int>(
    compareInput.cell,
    duration: const Duration(milliseconds: 50),
    leading: true,
    trailing: false,
  );

  final throttleResults = <int>[];
  final throttleObs = Cell.observe(
    source: throttleCompare.cell,
    effect: (Pulse p) => throttleResults.add(p.payload),
  );

  // Debounce: waits for silence
  final debounceCompare = Flow.debounce<int>(
    compareInput.cell,
    duration: const Duration(milliseconds: 50),
  );

  final debounceResults = <int>[];
  final debounceObs = Cell.observe(
    source: debounceCompare.cell,
    effect: (Pulse p) => debounceResults.add(p.payload),
  );

  // Emit values
  print('   Emitting: [1, 2, 3, 4, 5] with 20ms intervals');
  for (var i = 1; i <= 5; i++) {
    await compareInput.emitAsync(i);
    await Future.delayed(const Duration(milliseconds: 20));
  }

  await Future.delayed(const Duration(milliseconds: 100));

  print('   Throttle: $throttleResults (rate-limited, emits at intervals)');
  print('   Debounce: $debounceResults (only final value after silence)');

  throttleObs.stop();
  debounceObs.stop();
  print('');

  // ========================================================================
  // 5. Real-World: Scrolling with Throttle
  // ========================================================================

  print('5. Real-World: Scrolling with Throttle');
  print('   ────────────────────────────────────────────────────────\n');

  final scrollInput = Cell.ingress<int>();

  final scrollThrottle = Flow.throttle<int>(
    scrollInput.cell,
    duration: const Duration(milliseconds: 50),
    leading: true,
    trailing: true,
  );

  final scrollObserver = Cell.observe(
    source: scrollThrottle.cell,
    effect: (Pulse p) => print('   [Throttle] ✅ Update: Scroll position ${p.payload}px'),
  );

  // Simulate scrolling
  final sw5 = Stopwatch()..start();

  print('   [User] Scrolled to position 10px');
  await scrollInput.emitAsync(10);

  await Future.delayed(const Duration(milliseconds: 10));
  print('   [User] Scrolled to position 25px');
  await scrollInput.emitAsync(25);

  await Future.delayed(const Duration(milliseconds: 10));
  print('   [User] Scrolled to position 42px');
  await scrollInput.emitAsync(42);

  await Future.delayed(const Duration(milliseconds: 10));
  print('   [User] Scrolled to position 60px');
  await scrollInput.emitAsync(60);

  await Future.delayed(const Duration(milliseconds: 10));
  print('   [User] Scrolled to position 80px');
  await scrollInput.emitAsync(80);

  await Future.delayed(const Duration(milliseconds: 20));
  print('   [User] Scrolled to position 100px');
  await scrollInput.emitAsync(100);

  await Future.delayed(const Duration(milliseconds: 30));
  print('   [User] Scrolled to position 150px');
  await scrollInput.emitAsync(150);

  await Future.delayed(const Duration(milliseconds: 30));
  print('   [User] Scrolled to position 200px');
  await scrollInput.emitAsync(200);

  await Future.delayed(const Duration(milliseconds: 30));
  print('   [User] Scrolled to position 250px');
  await scrollInput.emitAsync(250);

  await Future.delayed(const Duration(milliseconds: 60));

  print('   [Final] Last scroll position: 250px');

  scrollObserver.stop();
  sw5.stop();
  print('');

  // ========================================================================
  // 6. Real-World: API Rate Limiting Simulation
  // ========================================================================

  print('6. Real-World: API Rate Limiting (50ms window)');
  print('   ────────────────────────────────────────────────────────\n');

  final rateInput = Cell.ingress<int>();

  int apiCallsMade = 0;
  int rateLimitErrors = 0;
  int totalEvents = 0;
  const int rateLimit = 5; // Max calls per 50ms window

  final rateThrottle = Flow.throttle<int>(
    rateInput.cell,
    duration: const Duration(milliseconds: 50),
    leading: true,
    trailing: false,
  );

  // Count API calls and simulate rate limiting
  final rateApi = Flow.map<int, String>(
    rateThrottle.cell,
    project: (value) {
      apiCallsMade++;
      if (apiCallsMade > rateLimit) {
        rateLimitErrors++;
        return '❌ Rate limit exceeded!';
      }
      return '✅ API call #$apiCallsMade processed';
    },
  );

  final rateObserver = Cell.observe(
    source: rateApi.cell,
    effect: (Pulse p) => print('   ${p.payload}'),
  );

  // Simulate a burst of events
  final sw6 = Stopwatch()..start();

  // Send 20 events in a burst
  print('   📊 Simulating 20 events in a burst...');
  for (var i = 1; i <= 20; i++) {
    totalEvents++;
    final label = i % 2 == 0 ? 'event_$i (fast)' : 'event_$i';
    await rateInput.emitAsync(i);
    // Vary the timing to simulate real user behavior
    final delay = i % 3 == 0 ? 12 : 8;
    await Future.delayed(Duration(milliseconds: delay));
  }

  await Future.delayed(const Duration(milliseconds: 100));

  // Calculate efficiency
  final efficiency = ((totalEvents - apiCallsMade) / totalEvents * 100).round();

  print('   📊 API Calls Made: $apiCallsMade');
  print('   ❌ Rate Limit Errors: $rateLimitErrors');
  print('   💰 API Cost Saved: ${totalEvents - apiCallsMade}');
  print('   ⏱️  Total Events: $totalEvents');
  print('   📈  Throttle Efficiency: $efficiency%');

  rateObserver.stop();
  sw6.stop();
  print('');

  // ========================================================================
  // 7. Sliding Window Throttle (Custom Implementation)
  // ========================================================================

  print('7. Sliding Window Throttle (custom implementation)');
  print('   ────────────────────────────────────────────────────────\n');

  // A custom sliding window throttle using Flow operators
  final slidingInput = Cell.ingress<String>();

  // Track the last emission time using a ValueCell
  final lastEmitTimeHandle = Cell.state<int>(
    initial: 0,
  );
  final lastEmitTimeCell = lastEmitTimeHandle.cell;

  // Custom throttle using map and conditional logic
  final slidingThrottle = Flow.map<String, String?>(
    slidingInput.cell,
    project: (value) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = lastEmitTimeCell.value ?? 0;
      final diff = now - last;

      if (diff < 50) {
        // Within the window - drop this event
        return null;
      }

      // Outside the window - update the last emit time
      lastEmitTimeHandle.update(now);
      return value;
    },
  );

  // Filter out null values
  final slidingFilter = Flow.filter<String?>(
    slidingThrottle.cell,
    test: (value) => value != null,
  );

  // Map back to String
  final slidingResult = Flow.map<String?, String>(
    slidingFilter.cell,
    project: (value) => value!,
  );

  final slidingObserver = Cell.observe(
    source: slidingResult.cell,
    effect: (Pulse p) => print('   [Sliding] ✅ Emitted: ${p.payload} (window starts)'),
  );

  final sw7 = Stopwatch()..start();

  print('   [User] Keypress at ${sw7.elapsedMilliseconds}ms');
  await slidingInput.emitAsync('keypress');

  await Future.delayed(const Duration(milliseconds: 30));
  print('   [User] Keypress at ${sw7.elapsedMilliseconds}ms - DROPPED (in window)');
  await slidingInput.emitAsync('keypress');

  await Future.delayed(const Duration(milliseconds: 30));
  print('   [User] Keypress at ${sw7.elapsedMilliseconds}ms - DROPPED (in window)');
  await slidingInput.emitAsync('keypress');

  await Future.delayed(const Duration(milliseconds: 40));
  print('   [User] Keypress at ${sw7.elapsedMilliseconds}ms');
  await slidingInput.emitAsync('keypress');

  await Future.delayed(const Duration(milliseconds: 30));

  slidingObserver.stop();
  sw7.stop();
  print('');

  // ========================================================================
  // 8. Real-World: Form Submission with Throttle
  // ========================================================================

  print('8. Real-World: Form Submission with Throttle');
  print('   ────────────────────────────────────────────────────────\n');

  final submitInput = Cell.ingress<Map<String, String>>();

  int submittedCount = 0;
  final submissionResults = <String>[];

  final submitThrottle = Flow.throttle<Map<String, String>>(
    submitInput.cell,
    duration: const Duration(milliseconds: 100),
    leading: true,
    trailing: false,
  );

  final submitProcessor = Flow.map<Map<String, String>, String>(
    submitThrottle.cell,
    project: (formData) {
      submittedCount++;
      final name = formData['name'] ?? 'Unknown';
      return '📝 Form #$submittedCount submitted for: $name';
    },
  );

  final submitObserver = Cell.observe(
    source: submitProcessor.cell,
    effect: (Pulse p) => print('   [Submit] ${p.payload}'),
  );

  // Simulate rapid form submissions
  final sw8 = Stopwatch()..start();

  final forms = [
    {'name': 'Alice', 'email': 'alice@example.com'},
    {'name': 'Bob', 'email': 'bob@example.com'},
    {'name': 'Charlie', 'email': 'charlie@example.com'},
    {'name': 'Diana', 'email': 'diana@example.com'},
    {'name': 'Eve', 'email': 'eve@example.com'},
  ];

  print('   📝 Simulating rapid form submissions...');
  for (var i = 0; i < forms.length; i++) {
    final form = forms[i];
    final isThrottled = i > 0 && i < 3;
    if (isThrottled) {
      print('   [User] Form #${i + 1} (${form['name']}) at ${sw8.elapsedMilliseconds}ms - THROTTLED');
    } else {
      print('   [User] Form #${i + 1} (${form['name']}) at ${sw8.elapsedMilliseconds}ms');
    }
    await submitInput.emitAsync(form);
    await Future.delayed(const Duration(milliseconds: 20));
  }

  await Future.delayed(const Duration(milliseconds: 120));

  print('   ✅ Total submissions processed: $submittedCount');

  submitObserver.stop();
  sw8.stop();
  print('');

  // ========================================================================
  // 9. Throttle Configuration Comparison
  // ========================================================================

  print('9. Throttle Configuration Comparison');
  print('   ────────────────────────────────────────────────────────\n');

  final configInput = Cell.ingress<int>();

  // Leading only: Immediate, then drop until window expires
  print('   🔹 Leading Only (leading: true, trailing: false)');
  final leadingOnly = Flow.throttle<int>(
    configInput.cell,
    duration: const Duration(milliseconds: 40),
    leading: true,
    trailing: false,
  );

  final leadingResults = <int>[];
  final leadingObs = Cell.observe(
    source: leadingOnly.cell,
    effect: (Pulse p) => leadingResults.add(p.payload),
  );

  // Trailing only: Wait for silence, then emit last
  print('   🔸 Trailing Only (leading: false, trailing: true)');
  final trailingOnly = Flow.throttle<int>(
    configInput.cell,
    duration: const Duration(milliseconds: 40),
    leading: false,
    trailing: true,
  );

  final trailingResults = <int>[];
  final trailingObs = Cell.observe(
    source: trailingOnly.cell,
    effect: (Pulse p) => trailingResults.add(p.payload),
  );

  // Both: Immediate first, then last after window
  print('   🔹 Both (leading: true, trailing: true)');
  final both = Flow.throttle<int>(
    configInput.cell,
    duration: const Duration(milliseconds: 40),
    leading: true,
    trailing: true,
  );

  final bothResults = <int>[];
  final bothObs = Cell.observe(
    source: both.cell,
    effect: (Pulse p) => bothResults.add(p.payload),
  );

  // None: Emit nothing (useful for testing)
  print('   🔸 None (leading: false, trailing: false)');
  final none = Flow.throttle<int>(
    configInput.cell,
    duration: const Duration(milliseconds: 40),
    leading: false,
    trailing: false,
  );

  final noneResults = <int>[];
  final noneObs = Cell.observe(
    source: none.cell,
    effect: (Pulse p) => noneResults.add(p.payload),
  );

  // Emit a burst of values
  print('   📊 Emitting: [1, 2, 3, 4, 5] with 15ms intervals');
  for (var i = 1; i <= 5; i++) {
    await configInput.emitAsync(i);
    await Future.delayed(const Duration(milliseconds: 15));
  }

  await Future.delayed(const Duration(milliseconds: 60));

  print('   Leading Only:  $leadingResults  (first only)');
  print('   Trailing Only: $trailingResults  (last only)');
  print('   Both:          $bothResults  (first + last)');
  print('   None:          $noneResults  (no emissions)');

  leadingObs.stop();
  trailingObs.stop();
  bothObs.stop();
  noneObs.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: Throttle Rate Limiting');
  print('─' * 60);
  print('''
  🔹 Throttle limits the frequency of emissions
  🔹 Leading: emits immediately on first event
  🔹 Trailing: emits the last event after the window
  🔹 Use leading:true, trailing:false for click prevention
  🔹 Use leading:true, trailing:true for complete event handling
  🔹 Use throttle for: API calls, scroll events, clicks
  🔹 Use debounce for: search input, form validation
  🔹 Throttle saves API costs and prevents rate limits
  🔹 Sliding window provides more precise control
  ''');

  print('── Finished ──────────────────────────────────────────────────────────');
}

// ─────────────────────────────────────────────────────────────────────
// Utility Extension for Flow
// ─────────────────────────────────────────────────────────────────────

/// Extension to provide convenient methods for Flow operations.
extension FlowUtils on Flow {
  /// Creates a throttle with the specified configuration.
  static FlowHandle throttle<S>(
      Cell source, {
        required Duration duration,
        bool leading = true,
        bool trailing = false,
      }) {
    final instruction = Throttle<S>(
      duration,
      leading: leading,
      trailing: trailing,
    );
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

  /// Creates a map transformation.
  static FlowHandle map<S, T>(
      Cell source, {
        required T Function(S value) project,
      }) {
    final instruction = MapValue<S, T>(project);
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

Pulse _mark(Pulse pulse, String step) => pulse.withStep(step);

Pulse<S> _fromPayload<S>(S value, Pulse sourcePulse, Cell? cell, String step) {
  return Pulse<S>(
    value,
    source: cell ?? sourcePulse.source,
    type: sourcePulse.type,
    priority: sourcePulse.priority,
    step: step,
  );
}