// =============================================================================
// Practical executable walkthrough – Cell.observe
// UI side-effects · Terminal lifecycle · Forensic logging
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

/// ### Expected console output:
/// ```text
/// ── Cell.observe – UI, Lifecycle & Forensic Logging ───────────
///
/// 1. UI side-effect observer
///    [UI]     setState → count = 1
///    [UI]     setState → count = 2
///    [UI]     setState → count = 3
///    uiCount after emissions: 3
///
/// 2. Terminal lifecycle – start / stop
///    emit while stopped (should be silent)
///    [UI]     setState → count = 10
///    calling start()
///    emit while running
///    [UI]     setState → count = 20
///    [Life]   effect ran → 20
///    calling stop()
///    emit while stopped again (should be silent)
///    [UI]     setState → count = 30
///
/// 3. Forensic logging observer
///    [UI]     setState → count = 100
///    [Audit]  [2026-08-15T17:27:29.358528] payload=100 type=null source=null
///    [UI]     setState → count = 200
///    [Audit]  [2026-08-15T17:27:29.359533] payload=200 type=null source=null
///    audit log size: 2
///
/// 4. Multiple independent observers on the same cell
///    [UI]     setState → count = 42
///    [Audit]  [2026-08-15T17:27:29.405054] payload=42 type=null source=null
///    [UI-2]   badge text → "42"
///
/// 5. Stopping all observers
///    final emit (all observers stopped – should be silent)
///
/// ── finished ──────────────────────────────────────────────────
/// Final UI count captured: 42
/// Forensic entries captured: 3
///
/// Process finished with exit code 0
/// ```
Future<void> main() async {
  print('── Cell.observe – UI, Lifecycle & Forensic Logging ───────────\n');

  // -------------------------------------------------------------------------
  // Shared source: a simple stateful counter
  // -------------------------------------------------------------------------
  final counter = Cell.state<int>(
    initial: 0,
    evolve: (host, pulse) {
      final incoming = pulse.payload;
      if (incoming is int) return Pulse(incoming);
      return null;
    },
  );

  // -------------------------------------------------------------------------
  // 1. UI side-effect observer (simulates a widget / setState)
  // -------------------------------------------------------------------------
  print('1. UI side-effect observer');

  int uiCount = -1; // “widget” local state

  final uiObserver = Cell.observe(
    source: counter.cell,
    effect: (Pulse pulse) {
      // Imperative side-effect – the reactive graph ends here
      uiCount = pulse.payload as int? ?? uiCount;
      print('   [UI]     setState → count = $uiCount');
    },
    initiallyStarted: true, // start immediately
  );

  counter.update(1);
  counter.update(2);
  counter.update(3);
  print('   uiCount after emissions: $uiCount');
  await Future.delayed(const Duration(milliseconds: 30));

  // -------------------------------------------------------------------------
  // 2. Terminal lifecycle management (start / stop)
  // -------------------------------------------------------------------------
  print('\n2. Terminal lifecycle – start / stop');

  final lifecycleObserver = Cell.observe(
    source: counter.cell,
    initiallyStarted: false, // created dormant
    effect: (Pulse pulse) {
      print('   [Life]   effect ran → ${pulse.payload}');
    },
  );

  print('   emit while stopped (should be silent)');
  counter.update(10);
  await Future.delayed(const Duration(milliseconds: 20));

  print('   calling start()');
  lifecycleObserver.start();

  print('   emit while running');
  counter.update(20);
  await Future.delayed(const Duration(milliseconds: 20));

  print('   calling stop()');
  lifecycleObserver.stop();

  print('   emit while stopped again (should be silent)');
  counter.update(30);
  await Future.delayed(const Duration(milliseconds: 20));

  // -------------------------------------------------------------------------
  // 3. Forensic / audit logging observer
  // -------------------------------------------------------------------------
  print('\n3. Forensic logging observer');

  final auditLog = <String>[];

  final forensicObserver = Cell.observe(
    source: counter.cell,
    effect: (Pulse pulse) {
      final entry = StringBuffer()
        ..write('[${DateTime.now().toIso8601String()}] ')
        ..write('payload=${pulse.payload} ')
        ..write('type=${pulse.type} ')
        ..write('source=${pulse.source?.runtimeType}');
      final line = entry.toString();
      auditLog.add(line);
      print('   [Audit]  $line');
    },
  );

  counter.update(100);
  counter.update(200);
  await Future.delayed(const Duration(milliseconds: 30));

  print('   audit log size: ${auditLog.length}');

  // -------------------------------------------------------------------------
  // 4. Multiple observers on the same source (fan-out of side-effects)
  // -------------------------------------------------------------------------
  print('\n4. Multiple independent observers on the same cell');

  final secondaryUi = Cell.observe(
    source: counter.cell,
    effect: (Pulse pulse) {
      print('   [UI-2]   badge text → "${pulse.payload}"');
    },
  );

  counter.update(42);
  await Future.delayed(const Duration(milliseconds: 30));

  // -------------------------------------------------------------------------
  // 5. Clean shutdown of all terminals
  // -------------------------------------------------------------------------
  print('\n5. Stopping all observers');
  uiObserver.stop();
  lifecycleObserver.stop();
  forensicObserver.stop();
  secondaryUi.stop();

  print('   final emit (all observers stopped – should be silent)');
  counter.update(999);
  await Future.delayed(const Duration(milliseconds: 30));

  print('\n── finished ──────────────────────────────────────────────────');
  print('Final UI count captured: $uiCount');
  print('Forensic entries captured: ${auditLog.length}');
}