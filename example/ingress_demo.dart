// =============================================================================
// Practical executable example – Cell.ingress (corrected)
// =============================================================================
//
// Demonstrates:
//   • Creating an ingress port with a refine step
//   • Synchronous emit
//   • Asynchronous emitAsync
//   • Full Pulse injection with ingest + serializedCompletion
//   • Proper payload handling via input.evolve(...)
//
// =============================================================================

// =============================================================================
// Practical executable example – Cell.ingress (final corrected version)
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

/// ### Expected console output:
/// ```text
/// ── Cell.ingress demonstration ────────────────────────────────
///
/// 1. Synchronous emit
///    emit("  Hello World  ") → accepted: true
///    emit("   ")             → accepted: false  (expected false)
///   → observer received: "hello world"  (type=search.query)
///
/// 2. Asynchronous emitAsync
///    emitAsync("Dart Reactive") → accepted: true
///   → observer received: "dart reactive"  (type=search.query)
///
/// 3. Full Pulse via ingest (serializedCompletion)
///   → observer received: "advanced.query"  (type=search.query)
///    ingest completed – reactive graph has stabilised
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.ingress demonstration ────────────────────────────────\n');

  // -------------------------------------------------------------------------
  // 1. Create a typed ingress gateway
  // -------------------------------------------------------------------------
  final IngressHandle<String> searchGate = Cell.ingress<String>(
    refine: (Cell host, Pulse<String> input) {
      final raw = (input.payload ?? '').toString().trim();
      if (raw.isEmpty) return null; // suppress empty queries

      // return a new Pulse with the cleaned value.
      return Pulse<String>(raw.toLowerCase(), type: 'search.query');
    },
    forceLock: true,
  );

  // -------------------------------------------------------------------------
  // 2. Attach an observer
  // -------------------------------------------------------------------------
  final observer = Cell.observe(
    source: searchGate.cell,
    effect: (Pulse pulse) {
      print('  → observer received: "${pulse.payload}"  (type=${pulse.type})');
    },
  );

  // -------------------------------------------------------------------------
  // 3. Synchronous emit
  // -------------------------------------------------------------------------
  print('1. Synchronous emit');
  final accepted1 = searchGate.emit('  Hello World  ');
  print('   emit("  Hello World  ") → accepted: $accepted1');

  final accepted2 = searchGate.emit('   ');
  print('   emit("   ")             → accepted: $accepted2  (expected false)');

  await Future.delayed(const Duration(milliseconds: 40));

  // -------------------------------------------------------------------------
  // 4. Asynchronous emit
  // -------------------------------------------------------------------------
  print('\n2. Asynchronous emitAsync');
  final accepted3 = await searchGate.emitAsync('Dart Reactive');
  await Future.delayed(const Duration(milliseconds: 40));
  print('   emitAsync("Dart Reactive") → accepted: $accepted3');
  // -------------------------------------------------------------------------
  // 5. Full Pulse injection with ingest
  // -------------------------------------------------------------------------
  print('\n3. Full Pulse via ingest (serializedCompletion)');
  await searchGate.ingest(
    Pulse('advanced.query'),
    serializedCompletion: true,
  );
  await Future.delayed(const Duration(milliseconds: 40));
  print('   ingest completed – reactive graph has stabilised');
  // -------------------------------------------------------------------------
  // 6. Clean-up
  // -------------------------------------------------------------------------
  observer.stop();

  print('\n── finished ──────────────────────────────────────────────────');
}