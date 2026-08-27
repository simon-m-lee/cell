// =============================================================================
// Practical executable walkthrough – Cell.throttle
// Frequency-based sampling · High-frequency stream reduction · Forensic Trace
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

/// ### Expected console output:
/// ```text
/// ── Cell.throttle – Frequency-based Rate Limiting ─────────────
///
/// 1. Simulating a high-frequency burst (5 pulses in 100ms)...
///    [UI]        Update display: 1
///    [Raw]    New reading: 1
///    [Raw]    New reading: 2
///    [Raw]    New reading: 3
///    [Raw]    New reading: 4
///    [Raw]    New reading: 5
///    [Throttled] Update display: 5
///
/// 2. Testing Forensic Traceability...
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.throttle – Frequency-based Rate Limiting ─────────────\n');

  // -------------------------------------------------------------------------
  // 1. Setup a high-frequency source (e.g., a sensor or scroll position)
  // -------------------------------------------------------------------------
  final rawSensor = Cell.state<int>(initial: 0);

  // -------------------------------------------------------------------------
  // 2. Apply throttle: At most one update every 200ms
  // -------------------------------------------------------------------------
  final throttledSensor = Cell.throttle(
    rawSensor.cell,
    const Duration(milliseconds: 200),
    leading: true,   // Emit the first pulse immediately
    trailing: true,  // Emit the last pulse seen during the window once window closes
  );

  // -------------------------------------------------------------------------
  // 3. Observe the difference
  // -------------------------------------------------------------------------
  Cell.observe<Pulse<int>>(
    source: rawSensor.cell,
    effect: (pulse) => print('   [Raw]    New reading: ${pulse.payload}'),
  );

  Cell.observe<Pulse<int>>(
    source: throttledSensor,
    effect: (pulse) {
      // In the current version, we check for timer-driven pulses by looking 
      // for the step name "throttle_timer" in the trace.
      final isTimerDriven = pulse.trace.contains('throttle_timer');
      final tag = isTimerDriven ? '[Throttled]' : '[UI]       ';
      print('   $tag Update display: ${pulse.payload}');
    },
  );

  // Simulate a burst of signals
  print('1. Simulating a high-frequency burst (5 pulses in 100ms)...');

  rawSensor.update(1); // Should emit immediately (leading: true)
  await Future.delayed(const Duration(milliseconds: 20));
  rawSensor.update(2); // Should be suppressed
  await Future.delayed(const Duration(milliseconds: 20));
  rawSensor.update(3); // Should be suppressed
  await Future.delayed(const Duration(milliseconds: 20));
  rawSensor.update(4); // Should be suppressed
  await Future.delayed(const Duration(milliseconds: 20));
  rawSensor.update(5); // Should be suppressed, but captured for trailing edge

  // Wait for the throttle window (200ms) to expire
  await Future.delayed(const Duration(milliseconds: 250));
  // At this point, pulse '5' should have been emitted by the timer (trailing: true)

  print('\n2. Testing Forensic Traceability...');
  // We can see in the logs above that pulse 1 was direct, and pulse 5 was timer-driven.

  print('\n── finished ──────────────────────────────────────────────────');
}
