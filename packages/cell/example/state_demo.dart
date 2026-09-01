// =============================================================================
// Practical executable walkthrough – Cell.state
// Persistent State · Evolution Logic · Atomic Updates
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

/// ### Expected console output:
/// ```text
/// ── Cell.state – Persistent State & Evolution ──────────────────
///
/// 1. Basic State (Counter)
///    [Counter] value = 1
///    [Counter] value = 5
///
/// 2. Custom Evolution (Bounded Value 0-100)
///    [Bounded] value = 75
///    [Bounded] BLOCKED: 120 (exceeds 0-100)
///    [Bounded] value = 100
///
/// 3. Async Updates (Simulated Network Latency)
///    [Async] update started...
///    [Async] update started...
///    [Async] value = 10 (after 100ms)
///    [Async] value = 20 (after 100ms)
///
/// 4. StateHandle Orchestration
///    [Handle] initial = 0
///    [Handle] updated via .update() = 42
///    [Handle] updated via .ingest() = 42
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.state – Persistent State & Evolution ──────────────────\n');

  // -------------------------------------------------------------------------
  // 1. Basic State (Counter)
  // -------------------------------------------------------------------------
  print('1. Basic State (Counter)');

  final counter = Cell.state<int>(initial: 0);

  final counterObs = Cell.observe(
    source: counter.cell,
    effect: (Pulse pulse) => print('   [Counter] value = ${pulse.payload}'),
  );

  counter.update(1);
  counter.update(5);
  await Future.delayed(const Duration(milliseconds: 20));
  counterObs.stop();

  // -------------------------------------------------------------------------
  // 2. Custom Evolution (Bounded Value 0-100)
  // -------------------------------------------------------------------------
  print('\n2. Custom Evolution (Bounded Value 0-100)');

  final bounded = Cell.state<int>(
    initial: 50,
    evolve: (host, pulse) {
      final next = pulse.payload as int;
      if (next < 0 || next > 100) {
        print('   [Bounded] BLOCKED: $next (exceeds 0-100)');
        return null; // Reject the update
      }
      return Pulse(next);
    },
  );

  final boundedObs = Cell.observe(
    source: bounded.cell,
    effect: (Pulse pulse) => print('   [Bounded] value = ${pulse.payload}'),
  );

  bounded.update(75);
  bounded.update(120); // Should be blocked
  bounded.update(100);
  await Future.delayed(const Duration(milliseconds: 20));
  boundedObs.stop();

  // -------------------------------------------------------------------------
  // 3. Async Updates
  // -------------------------------------------------------------------------
  print('\n3. Async Updates (Simulated Network Latency)');

  final asyncState = Cell.state<int>(initial: 0);

  final asyncObs = Cell.observe(
    source: asyncState.cell,
    effect: (Pulse pulse) => print('   [Async] value = ${pulse.payload} (after 100ms)'),
  );

  print('   [Async] update started...');
  unawaited(Future.delayed(const Duration(milliseconds: 100), () => 10).then((v) => asyncState.updateAsync(v)));

  print('   [Async] update started...');
  final val20 = await Future.delayed(const Duration(milliseconds: 100), () => 20);
  await asyncState.updateAsync(val20);

  await Future.delayed(const Duration(milliseconds: 50));
  asyncObs.stop();

  // -------------------------------------------------------------------------
  // 4. StateHandle Orchestration
  // -------------------------------------------------------------------------
  print('\n4. StateHandle Orchestration');

  final handle = Cell.state<int>(initial: 0);
  print('   [Handle] initial = ${handle.cell.value}');

  handle.update(42);
  print('   [Handle] updated via .update() = ${handle.cell.value}');

  await handle.ingest(Pulse(100));
  print('   [Handle] updated via .ingest() = ${handle.cell.value}');

  print('\n── finished ──────────────────────────────────────────────────');
}
