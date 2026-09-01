// =============================================================================
// Practical executable walkthrough – Cell.debounce
// User-input stabilization · Debounced API calls · Search · Resize
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

/// ### Expected console output:
/// ```text
/// ── Cell.debounce – Input Stabilization & API Calls ───────────
///
/// 1. Search-as-you-type (debounce 80ms)
///    [API]    GET /search?q=cats
///
/// 2. Debounced email validation
///    [Valid]  "ada@ex.com" → ok
///
/// 3. Debounced resize handler
///    [Layout] recalculate for {width: 840, height: 600}
///
/// 4. Autosave after typing pause
///    [Save]   persist "Hello"
///
/// 5. Two separate typing bursts → two API calls
///    [API]    q=ab
///    [API]    q=xyz
///
/// 6. leading: true – first event immediate, then settle
///    [Scrub]  1
///    [Scrub]  4
///
/// 7. debounce → pretend HTTP
///    [HTTP]   start lookup "dart"
///    [HTTP]   results for "dart"
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.debounce – Input Stabilization & API Calls ───────────\n');

  // -------------------------------------------------------------------------
  // 1. Search-as-you-type – only final query after pause
  // -------------------------------------------------------------------------
  print('1. Search-as-you-type (debounce 80ms)');

  final queries = Cell.ingress<String>();
  final stableQuery = Cell.debounce(
    queries.cell,
    const Duration(milliseconds: 80),
  );

  final searchObs = Cell.observe(
    source: stableQuery,
    effect: (Pulse p) => print('   [API]    GET /search?q=${p.payload}'),
  );

  for (final q in ['c', 'ca', 'cat', 'cats']) {
    await queries.ingest(
      Pulse(q, source: queries.cell),
    );
    await Future.delayed(const Duration(milliseconds: 20));
  }
  await Future.delayed(const Duration(milliseconds: 120));
  searchObs.stop();
  // Only "cats" hits the API

  // -------------------------------------------------------------------------
  // 2. Form field validation – wait until user pauses typing
  // -------------------------------------------------------------------------
  print('\n2. Debounced email validation');

  final email = Cell.ingress<String>();
  final validate = Cell.debounce(
    email.cell,
    const Duration(milliseconds: 70),
  );

  final valObs = Cell.observe(
    source: validate,
    effect: (Pulse p) {
      final v = p.payload as String;
      final ok = v.contains('@') && v.contains('.');
      print('   [Valid]  "$v" → ${ok ? 'ok' : 'invalid'}');
    },
  );

  for (final s in ['a', 'ad', 'ada@', 'ada@ex', 'ada@ex.com']) {
    await email.ingest(
      Pulse(s, source: email.cell),
    );
    await Future.delayed(const Duration(milliseconds: 15));
  }
  await Future.delayed(const Duration(milliseconds: 100));
  valObs.stop();

  // -------------------------------------------------------------------------
  // 3. Window resize – stabilize layout recalculation
  // -------------------------------------------------------------------------
  print('\n3. Debounced resize handler');

  final sizes = Cell.ingress<Map<String, int>>();
  final stableSize = Cell.debounce(
    sizes.cell,
    const Duration(milliseconds: 60),
  );

  final sizeObs = Cell.observe(
    source: stableSize,
    effect: (Pulse p) => print('   [Layout] recalculate for ${p.payload}'),
  );

  for (final w in [800, 810, 824, 830, 840]) {
    await sizes.ingest(
      Pulse({'width': w, 'height': 600},
        source: sizes.cell,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 12));
  }
  await Future.delayed(const Duration(milliseconds: 100));
  sizeObs.stop();

  // -------------------------------------------------------------------------
  // 4. Autosave – debounce document edits
  // -------------------------------------------------------------------------
  print('\n4. Autosave after typing pause');

  final edits = Cell.ingress<String>();
  final autosave = Cell.debounce(
    edits.cell,
    const Duration(milliseconds: 90),
  );

  final saveObs = Cell.observe(
    source: autosave,
    effect: (Pulse p) => print('   [Save]   persist "${p.payload}"'),
  );

  for (final text in ['H', 'He', 'Hel', 'Hello']) {
    await edits.ingest(
      Pulse(text, source: edits.cell),
    );
    await Future.delayed(const Duration(milliseconds: 18));
  }
  await Future.delayed(const Duration(milliseconds: 120));
  saveObs.stop();

  // -------------------------------------------------------------------------
  // 5. Two bursts – debounce resets per burst
  // -------------------------------------------------------------------------
  print('\n5. Two separate typing bursts → two API calls');

  final q2 = Cell.ingress<String>();
  final debounced = Cell.debounce(
    q2.cell,
    const Duration(milliseconds: 50),
  );

  final q2Obs = Cell.observe(
    source: debounced,
    effect: (Pulse p) => print('   [API]    q=${p.payload}'),
  );

  for (final q in ['a', 'ab']) {
    await q2.ingest(Pulse(q, source: q2.cell));
    await Future.delayed(const Duration(milliseconds: 10));
  }
  await Future.delayed(const Duration(milliseconds: 80));

  for (final q in ['x', 'xy', 'xyz']) {
    await q2.ingest(Pulse(q, source: q2.cell));
    await Future.delayed(const Duration(milliseconds: 10));
  }
  await Future.delayed(const Duration(milliseconds: 80));
  q2Obs.stop();
  // Expect ab, then xyz

  // -------------------------------------------------------------------------
  // 6. leading: true – immediate first paint + trailing settle
  // -------------------------------------------------------------------------
  print('\n6. leading: true – first event immediate, then settle');

  final scrub = Cell.ingress<int>();
  final scrubbed = Cell.debounce(
    scrub.cell,
    const Duration(milliseconds: 70),
    leading: true,
  );

  final scrubObs = Cell.observe(
    source: scrubbed,
    effect: (Pulse p) => print('   [Scrub]  ${p.payload}'),
  );

  for (final n in [1, 2, 3, 4]) {
    await scrub.ingest(
      Pulse(n, source: scrub.cell),
    );
    await Future.delayed(const Duration(milliseconds: 12));
  }
  await Future.delayed(const Duration(milliseconds: 100));
  scrubObs.stop();
  // Expect leading 1, trailing 4

  // -------------------------------------------------------------------------
  // 7. Debounce → asyncMap (debounced network call)
  // -------------------------------------------------------------------------
  print('\n7. debounce → pretend HTTP');

  final term = Cell.ingress<String>();
  final stable = Cell.debounce(
    term.cell,
    const Duration(milliseconds: 60),
  );

  // Lightweight stand-in if asyncMap exhaust not required:
  final httpObs = Cell.observe(
    source: stable,
    effect: (Pulse p) async {
      final q = p.payload as String;
      print('   [HTTP]   start lookup "$q"');
      await Future.delayed(const Duration(milliseconds: 25));
      print('   [HTTP]   results for "$q"');
    },
  );

  for (final q in ['d', 'da', 'dar', 'dart']) {
    await term.ingest(
      Pulse(q, source: term.cell),
    );
    await Future.delayed(const Duration(milliseconds: 12));
  }
  await Future.delayed(const Duration(milliseconds: 120));
  httpObs.stop();

  print('\n── finished ──────────────────────────────────────────────────');
}