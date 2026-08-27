// =============================================================================
// Practical executable walkthrough – Cell.asyncMap
// Concurrent background tasks · latestOnly · sequential mode
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

/// Simulated network / disk latency.
Future<T> pretendWork<T>(String label, T result, {int ms = 80}) async {
  print('   … start  $label');
  await Future.delayed(Duration(milliseconds: ms));
  print('   … done   $label → $result');
  return result;
}

/// ### Expected console output:
/// ```text
/// ── Cell.asyncMap – Concurrent Background Tasks ───────────────
///
/// 1. Parallel fetches (concurrency: 0 = unlimited)
///    … start  fetch user 1
///    … start  fetch user 2
///    … start  fetch user 3
///    … done   fetch user 3 → {id: 3, name: User-3}
///    [Profile] {id: 3, name: User-3}
///    … done   fetch user 2 → {id: 2, name: User-2}
///    [Profile] {id: 2, name: User-2}
///    … done   fetch user 1 → {id: 1, name: User-1}
///    [Profile] {id: 1, name: User-1}
///
/// 2. Typeahead search (latestOnly: true)
///    … searching "c"
///    … searching "ca"
///    … searching "cat"
///    [Search] [cat-result-1, cat-result-2]
///
/// 3. Ordered job queue (concurrency: 1)
///    … start  job A
///    … done   job A → A✓
///    [Job] A✓
///    … start  job B
///    … done   job B → B✓
///    [Job] B✓
///    … start  job C
///    … done   job C → C✓
///    [Job] C✓
///
/// 4. Bounded pool (concurrency: 2)
///    … pool start #1 (active=1)
///    … pool start #2 (active=2)
///    …
///    max concurrent in flight observed: 2 (expect ≤ 2)
///
/// 5. Image thumbnails (parallel background work)
///    … start  thumb a.png
///    …
///    [Thumb] a_thumb.png
///    [Thumb] b_thumb.png
///    [Thumb] c_thumb.png
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.asyncMap – Concurrent Background Tasks ───────────────\n');

  // -------------------------------------------------------------------------
  // 1. Unlimited concurrency (mergeMap-style) – all tasks run in parallel
  // -------------------------------------------------------------------------
  print('1. Parallel fetches (concurrency: 0 = unlimited)');

  final userIds = Cell.ingress<int>();

  final profiles = Cell.asyncMap<int, Map<String, dynamic>>(
    userIds.cell,
        (id) => pretendWork(
      'fetch user $id',
      {'id': id, 'name': 'User-$id'},
      ms: 100 - id * 20, // higher ids finish first
    ),
    concurrency: 0,
  );

  final profileObs = Cell.observe(
    source: profiles,
    effect: (Pulse p) => print('   [Profile] ${p.payload}'),
  );

  for (final id in [1, 2, 3]) {
    await userIds.ingest(
      Pulse<int>.governed(payload: id, source: userIds.cell),
    );
  }
  await Future.delayed(const Duration(milliseconds: 250));
  profileObs.stop();
  // Results may arrive out of order (3 before 1) — expected for merge style.

  // -------------------------------------------------------------------------
  // 2. latestOnly – cancel interest in stale work (switchMap-style async)
  // -------------------------------------------------------------------------
  print('\n2. Typeahead search (latestOnly: true)');

  final query = Cell.ingress<String>();

  final searchResults = Cell.asyncMap<String, List<String>>(
    query.cell,
        (q) async {
      print('   … searching "$q"');
      await Future.delayed(Duration(milliseconds: 60 + q.length * 20));
      return ['$q-result-1', '$q-result-2'];
    },
    latestOnly: true,
  );

  final searchObs = Cell.observe(
    source: searchResults,
    effect: (Pulse p) => print('   [Search] ${p.payload}'),
  );

  // User types quickly — only the last query should surface
  for (final q in ['c', 'ca', 'cat']) {
    await query.ingest(
      Pulse<String>.governed(payload: q, source: query.cell),
    );
    await Future.delayed(const Duration(milliseconds: 15));
  }
  await Future.delayed(const Duration(milliseconds: 250));
  searchObs.stop();

  // -------------------------------------------------------------------------
  // 3. Sequential background jobs (concurrency: 1 = concatMap)
  // -------------------------------------------------------------------------
  print('\n3. Ordered job queue (concurrency: 1)');

  final jobs = Cell.ingress<String>();

  final jobResults = Cell.asyncMap<String, String>(
    jobs.cell,
        (job) => pretendWork('job $job', '$job✓', ms: 50),
    concurrency: 1,
  );

  final jobObs = Cell.observe(
    source: jobResults,
    effect: (Pulse p) => print('   [Job] ${p.payload}'),
  );

  for (final j in ['A', 'B', 'C']) {
    await jobs.ingest(
      Pulse<String>.governed(payload: j, source: jobs.cell),
    );
  }
  await Future.delayed(const Duration(milliseconds: 250));
  jobObs.stop();
  // A✓ then B✓ then C✓ — strict order.

  // -------------------------------------------------------------------------
  // 4. Bounded parallelism (concurrency: 2)
  // -------------------------------------------------------------------------
  print('\n4. Bounded pool (concurrency: 2)');

  final tasks = Cell.ingress<int>();
  var active = 0;
  var maxActive = 0;

  final pooled = Cell.asyncMap<int, int>(
    tasks.cell,
        (n) async {
      active++;
      if (active > maxActive) maxActive = active;
      print('   … pool start #$n (active=$active)');
      await Future.delayed(const Duration(milliseconds: 70));
      active--;
      print('   … pool end   #$n (active=$active)');
      return n * n;
    },
    concurrency: 2,
  );

  final poolObs = Cell.observe(
    source: pooled,
    effect: (Pulse p) => print('   [Pool] ${p.payload}'),
  );

  for (final n in [1, 2, 3, 4]) {
    await tasks.ingest(
      Pulse<int>.governed(payload: n, source: tasks.cell),
    );
  }
  await Future.delayed(const Duration(milliseconds: 400));
  poolObs.stop();
  print('   max concurrent in flight observed: $maxActive (expect ≤ 2)');

  // -------------------------------------------------------------------------
  // 5. Mixed pipeline: ingress → asyncMap → observe
  // -------------------------------------------------------------------------
  print('\n5. Image thumbnails (parallel background work)');

  final paths = Cell.ingress<String>();

  final thumbs = Cell.asyncMap<String, String>(
    paths.cell,
        (path) => pretendWork(
      'thumb $path',
      path.replaceAll('.png', '_thumb.png'),
      ms: 60,
    ),
  );

  final thumbObs = Cell.observe(
    source: thumbs,
    effect: (Pulse p) => print('   [Thumb] ${p.payload}'),
  );

  for (final path in ['a.png', 'b.png', 'c.png']) {
    await paths.ingest(
      Pulse<String>.governed(payload: path, source: paths.cell),
    );
  }
  await Future.delayed(const Duration(milliseconds: 200));
  thumbObs.stop();

  print('\n── finished ──────────────────────────────────────────────────');
}