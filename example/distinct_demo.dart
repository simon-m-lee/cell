// =============================================================================
// Practical executable walkthrough – Cell.distinct
// Noise reduction · Change detection · Custom equality
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

/// ### Expected console output:
/// ```text
/// ── Cell.distinct – Noise Reduction & Change Detection ────────
///
/// 1. Consecutive duplicate suppression
///    [Status] idle
///    [Status] loading
///    [Status] done
///
/// 2. Sensor noise filter
///    [Temp]   20.0°C
///    [Temp]   20.5°C
///    [Temp]   21.0°C
///    [Temp]   20.0°C
///
/// 3. Custom equals (case-insensitive)
///    [Tag]    Dart
///    [Tag]    Flutter
///
/// 4. Distinct by object id (ignore other fields)
///    [User]   {id: 1, name: Ada, status: online}
///    [User]   {id: 2, name: Grace, status: online}
///    [User]   {id: 1, name: Ada, status: online}
///
/// 5. UI change detection
///    [UI]     paint #1 value=1
///    [UI]     paint #2 value=2
///    [UI]     paint #3 value=3
///    paints=3 (expect 3)
///
/// 6. Consecutive only (A→B→A all emit)
///    [Flag]   on
///    [Flag]   off
///    [Flag]   on
///
/// 7. Pulse without source is ignored
///    count=0 (expect 0)
///    [N] 1
///    [N] 2
///    count=2 (expect 2)
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.distinct – Noise Reduction & Change Detection ────────\n');

  // -------------------------------------------------------------------------
  // 1. Suppress consecutive duplicate strings
  // -------------------------------------------------------------------------
  print('1. Consecutive duplicate suppression');

  final status = Cell.ingress<String>();
  final distinctStatus = Cell.distinct(status.cell);

  final statusObs = Cell.observe(
    source: distinctStatus,
    effect: (Pulse p) => print('   [Status] ${p.payload}'),
  );

  for (final s in ['idle', 'idle', 'idle', 'loading', 'loading', 'done', 'done']) {
    await status.ingest(
      Pulse(s, source: status.cell),
    );
  }
  await Future.delayed(const Duration(milliseconds: 30));
  statusObs.stop();
  // Expect: idle, loading, done

  // -------------------------------------------------------------------------
  // 2. Sensor noise – same reading repeated
  // -------------------------------------------------------------------------
  print('\n2. Sensor noise filter');

  final temp = Cell.ingress<double>();
  final stableTemp = Cell.distinct(temp.cell);

  final tempObs = Cell.observe(
    source: stableTemp,
    effect: (Pulse p) => print('   [Temp]   ${p.payload}°C'),
  );

  for (final t in [20.0, 20.0, 20.0, 20.5, 20.5, 21.0, 21.0, 20.0]) {
    await temp.ingest(
      Pulse(t, source: temp.cell),
    );
  }
  await Future.delayed(const Duration(milliseconds: 30));
  tempObs.stop();
  // Expect: 20.0, 20.5, 21.0, 20.0

  // -------------------------------------------------------------------------
  // 3. Custom equals – ignore case
  // -------------------------------------------------------------------------
  print('\n3. Custom equals (case-insensitive)');

  final tags = Cell.ingress<String>();
  final distinctTags = Cell.distinct(
    tags.cell,
    equals: (a, b) =>
    (a as String).toLowerCase() == (b as String).toLowerCase(),
  );

  final tagObs = Cell.observe(
    source: distinctTags,
    effect: (Pulse p) => print('   [Tag]    ${p.payload}'),
  );

  for (final t in ['Dart', 'dart', 'DART', 'Flutter', 'flutter']) {
    await tags.ingest(
      Pulse(t, source: tags.cell),
    );
  }
  await Future.delayed(const Duration(milliseconds: 30));
  tagObs.stop();
  // Expect: Dart, Flutter

  // -------------------------------------------------------------------------
  // 4. Custom equals – map by id only
  // -------------------------------------------------------------------------
  print('\n4. Distinct by object id (ignore other fields)');

  final users = Cell.ingress<Map<String, dynamic>>();
  final distinctUsers = Cell.distinct(
    users.cell,
    equals: (a, b) =>
    (a as Map)['id'] == (b as Map)['id'],
  );

  final userObs = Cell.observe(
    source: distinctUsers,
    effect: (Pulse p) => print('   [User]   ${p.payload}'),
  );

  await users.ingest(Pulse({'id': 1, 'name': 'Ada', 'status': 'online'},
    source: users.cell,
  ));
  await users.ingest(Pulse({'id': 1, 'name': 'Ada', 'status': 'away'}, // same id → drop
    source: users.cell,
  ));
  await users.ingest(Pulse({'id': 2, 'name': 'Grace', 'status': 'online'},
    source: users.cell,
  ));
  await users.ingest(Pulse({'id': 2, 'name': 'Grace Hopper', 'status': 'online'}, // drop
    source: users.cell,
  ));
  await users.ingest(Pulse({'id': 1, 'name': 'Ada', 'status': 'online'}, // id changed back → emit
    source: users.cell,
  ));
  await Future.delayed(const Duration(milliseconds: 40));
  userObs.stop();

  // -------------------------------------------------------------------------
  // 5. UI: avoid redundant setState-style updates
  // -------------------------------------------------------------------------
  print('\n5. UI change detection');

  final tick = Cell.ingress<int>();
  final visible = Cell.distinct(tick.cell);

  var paintCount = 0;
  final uiObs = Cell.observe(
    source: visible,
    effect: (Pulse p) {
      paintCount++;
      print('   [UI]     paint #$paintCount value=${p.payload}');
    },
  );

  for (final n in [1, 1, 1, 2, 2, 3, 3, 3, 3]) {
    await tick.ingest(Pulse(n, source: tick.cell));
  }
  await Future.delayed(const Duration(milliseconds: 30));
  print('   paints=$paintCount (expect 3)');
  uiObs.stop();

  // -------------------------------------------------------------------------
  // 6. Distinct is consecutive only – values can reappear later
  // -------------------------------------------------------------------------
  print('\n6. Consecutive only (A→B→A all emit)');

  final flags = Cell.ingress<String>();
  final distinctFlags = Cell.distinct(flags.cell);

  final flagObs = Cell.observe(
    source: distinctFlags,
    effect: (Pulse p) => print('   [Flag]   ${p.payload}'),
  );

  for (final f in ['on', 'off', 'on']) {
    await flags.ingest(
      Pulse(f, source: flags.cell),
    );
  }
  await Future.delayed(const Duration(milliseconds: 30));
  flagObs.stop();
  // all three emit – not global uniqueness

  // -------------------------------------------------------------------------
  // 7. Missing source → ignored
  // -------------------------------------------------------------------------
  print('\n7. Pulse without source is ignored');

  final raw = Cell.ingress<int>();
  final dedup = Cell.distinct(raw.cell);

  var count = 0;
  final cObs = Cell.observe(
    source: dedup,
    effect: (Pulse p) {
      count++;
      print('   [N] ${p.payload}');
    },
  );

  await raw.ingest(Pulse(1)); // no source
  await Future.delayed(const Duration(milliseconds: 15));
  print('   count=$count (expect 0)');

  await raw.ingest(Pulse(1, source: raw.cell));
  await raw.ingest(Pulse(1, source: raw.cell));
  await raw.ingest(Pulse(2, source: raw.cell));
  await Future.delayed(const Duration(milliseconds: 20));
  print('   count=$count (expect 2)');

  cObs.stop();

  print('\n── finished ──────────────────────────────────────────────────');
}