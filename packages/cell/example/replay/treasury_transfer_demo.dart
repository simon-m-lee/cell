// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// ─────────────────────────────────────────────────────────────────────
// ACME Treasury — a complete Causal Replay demonstration
// ─────────────────────────────────────────────────────────────────────
//
// This example shows a realistic treasury service with three wire
// transfers recorded to a hash-chained ledger, and demonstrates:
//
//   1. Recording state mutations to a durable ledger
//   2. Verifying the ledger's integrity (proof of non-tampering)
//   3. Replaying the ledger into a fresh graph and asserting the state
//      matches exactly
//   4. Forking the history at a specific sequence and asking "what if
//      transfer #2 had been $50,000 instead of $25,000?"
//   5. Verifying that the fork is a legitimate branch of its parent
//   6. Catching a divergence when the graph's behaviour changes
//
// Run with:
//
//     dart run example/replay/treasury_transfer_demo.dart
//
// Exit code 0 on success, 1 on any failed assertion.

import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell/replay.dart';

Future<void> main() async {
  final tempDir = await Directory.systemTemp.createTemp('treasury_demo_');
  try {
    final ok = await _runDemo(tempDir);
    exit(ok ? 0 : 1);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<bool> _runDemo(Directory tempDir) async {
  _banner('ACME Treasury — Causal Replay Demo');
  print('Ledger directory: ${tempDir.path}');
  print('');

  final ledgerPath = '${tempDir.path}/ledger.jsonl';
  const genesis = 'acme-treasury-2025-11-13';

  // ─────────────────────────────────────────────────────────────────
  // 1. Build the graph and bind a durable ledger
  // ─────────────────────────────────────────────────────────────────
  _section('1. Build graph and bind ledger');

  final source = Cell.state<int>(initial: 100000);
  final target = Cell.state<int>(initial: 0);
  final count = Cell.state<int>(initial: 0);

  final graph = (CellGraph.builder(graphId: 'acme-treasury')
        ..registerState('source', source)
        ..registerState('target', target)
        ..registerState('count', count))
      .build();

  final ledger = await graph.bindLedger(
    store: await FileLedgerStore.open(ledgerPath, genesisHash: genesis),
  );

  print('  graph.id       = ${graph.id}');
  print('  ledger path    = $ledgerPath');
  print('  genesis hash   = ${fingerprint({'graphId': graph.id})}');
  print('  source balance = \$${source.cell.value}');
  print('  target balance = \$${target.cell.value}');
  print('  transfers done = ${count.cell.value}');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 2. Record three wire transfers
  // ─────────────────────────────────────────────────────────────────
  _section('2. Record three wire transfers');

  final transfers = [
    (25000, 'Invoice #2025-11-001'),
    (25000, 'Invoice #2025-11-002'),
    (25000, 'Invoice #2025-11-003'),
  ];

  await graph.run(() async {
    for (final (amount, memo) in transfers) {
      source.update(source.cell.value! - amount);
      target.update(target.cell.value! + amount);
      count.update(count.cell.value! + 1);
      print('  Wired \$$amount  ($memo)');
    }
  });

  final entryCount = await ledger.lastSeq + 1;
  print('');
  print('  entries recorded = $entryCount');
  print('  source balance   = \$${source.cell.value}');
  print('  target balance   = \$${target.cell.value}');
  print('  transfers done   = ${count.cell.value}');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 3. Verify ledger integrity
  // ─────────────────────────────────────────────────────────────────
  _section('3. Verify ledger integrity');

  await ledger.verify();
  print('  ✓ hash chain intact');
  print('  ✓ $entryCount entries verified from genesis to head');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 4. Replay into a fresh graph
  // ─────────────────────────────────────────────────────────────────
  _section('4. Replay into a fresh graph');

  // The registry that assigns graph-scoped ids is process-wide; clear
  // it so the fresh graph can claim the same 'source' / 'target' /
  // 'count' names.
  CellGraphRegistry.forceReset();

  final replaySource = Cell.state<int>(initial: 100000);
  final replayTarget = Cell.state<int>(initial: 0);
  final replayCount = Cell.state<int>(initial: 0);

  final replayGraph = (CellGraph.builder(graphId: 'acme-treasury')
        ..registerState('source', replaySource)
        ..registerState('target', replayTarget)
        ..registerState('count', replayCount))
      .build();

  final replayResult = await ReplayEngine.replay(
    ledger: ledger,
    target: replayGraph,
  );

  print('  entries replayed = ${replayResult.entriesReplayed}');
  print('  replayed source  = \$${replaySource.cell.value}');
  print('  replayed target  = \$${replayTarget.cell.value}');
  print('  replayed count   = ${replayCount.cell.value}');

  if (!replayResult.success) {
    print('  ✗ DIVERGENCE');
    for (final d in replayResult.divergences) {
      print('    ${d.toString()}');
    }
    return false;
  }

  if (replaySource.cell.value != source.cell.value ||
      replayTarget.cell.value != target.cell.value ||
      replayCount.cell.value != count.cell.value) {
    print('  ✗ state does not match recording');
    return false;
  }
  print('  ✓ replay reproduced the recorded state exactly');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 5. Fork at seq 2 and apply a what-if
  // ─────────────────────────────────────────────────────────────────
  _section('5. Fork at seq 2 (after transfer #1)');
  print('  what-if: transfer #2 was \$50,000 instead of \$25,000');
  print('');

  final fork = await graph.fork(
    parent: ledger,
    atSeq: 2,
    buildFreshGraph: () {
      CellGraphRegistry.forceReset();
      return (CellGraph.builder(graphId: 'acme-treasury-fork')
            ..registerState('source', Cell.state<int>(initial: 100000))
            ..registerState('target', Cell.state<int>(initial: 0))
            ..registerState('count', Cell.state<int>(initial: 0)))
          .build();
    },
    store: InMemoryLedgerStore(genesisHash: 'fork-genesis'),
  );

  print('  forkId              = ${fork.record.forkId}');
  print('  divergedAt          = ${fork.record.divergedAt}');
  print('  parentHeadHash      = ${_short(fork.record.parentHeadHash)}');
  print('  originalSnapshotHash= ${_short(fork.record.originalSnapshotHash)}');
  print('');

  final forkResult = await ReplayEngine.replayFork(
    fork: fork,
    mutation: (entry, pulse) {
      // Each transfer is 3 entries: source, target, count.
      // Transfer 1: seq 0, 1, 2
      // Transfer 2: seq 3, 4, 5
      // Transfer 3: seq 6, 7, 8
      //
      // The what-if: transfer 2 is $50,000 instead of $25,000. This
      // changes the *balances* after transfer 2, which changes the
      // balances after transfer 3 as well.
      switch (entry.seq) {
        case 3: // source after transfer 2: 75000 → 25000 (debit -50000)
          return Pulse<int>(25000, source: pulse.source);
        case 4: // target after transfer 2: 25000 → 75000 (credit +50000)
          return Pulse<int>(75000, source: pulse.source);
        case 6: // source after transfer 3: 25000 → 0 (debit -25000)
          return Pulse<int>(0, source: pulse.source);
        case 7: // target after transfer 3: 75000 → 100000 (credit +25000)
          return Pulse<int>(100000, source: pulse.source);
      }
      return pulse;
    },
  );

  final forkedSource = fork.graph['source']!.cell as ValueCell<int>;
  final forkedTarget = fork.graph['target']!.cell as ValueCell<int>;
  final forkedCount = fork.graph['count']!.cell as ValueCell<int>;

  print('  entries replayed = ${forkResult.entriesReplayed}');
  print('  forked source    = \$${forkedSource.value}');
  print('  forked target    = \$${forkedTarget.value}');
  print('  forked count     = ${forkedCount.value}');

  if (!forkResult.success) {
    print('  ✗ fork replay diverged');
    for (final d in forkResult.divergences) {
      print('    $d');
    }
    return false;
  }
  if (forkedSource.value != 0 ||
      forkedTarget.value != 100000 ||
      forkedCount.value != 3) {
    print('  ✗ fork produced unexpected state');
    return false;
  }
  print('  ✓ what-if branch produced (source=0, target=100000, count=3)');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 6. Verify the fork
  // ─────────────────────────────────────────────────────────────────
  _section('6. Verify the fork');

  await fork.verify();
  print('  ✓ parent ledger verified');
  print('  ✓ fork chain verified');
  print('  ✓ fork genesis bound to parent at seq 2');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 7. Divergence detection
  // ─────────────────────────────────────────────────────────────────
  _section('7. Divergence detection (receptor change)');

  // Replay the *original* ledger into a graph that has been subtly
  // reconfigured: the source cell now rejects any balance below
  // $50,000. The recording accepted a $25,000 balance at seq 6;
  // replay will reject it, and the state after seq 6 will differ.
  CellGraphRegistry.forceReset();

  final strictSource = Cell.state<int>(
    initial: 100000,
    testRule: TestCell<Cell>((object, {host, arguments, user}) {
      return (object as int) >= 50000;
    }),
  );
  final strictTarget = Cell.state<int>(initial: 0);
  final strictCount = Cell.state<int>(initial: 0);

  final strictGraph = (CellGraph.builder(graphId: 'acme-treasury')
        ..registerState('source', strictSource)
        ..registerState('target', strictTarget)
        ..registerState('count', strictCount))
      .build();

  try {
    await ReplayEngine.replay(ledger: ledger, target: strictGraph);
    print('  ✗ expected divergence but replay succeeded');
    return false;
  } on ReplayDivergenceException catch (e) {
    final r = e.report;
    print('  ✓ divergence caught at seq ${r?.seq}');
    print('    reason:   ${r?.reason}');
    print('    expected: ${r?.expected}');
    print('    actual:   ${r?.actual}');
    print('');
    print('  The replay refused to silently produce a state that the');
    print('  recorded ledger does not explain.');
    print('');
  }

  // ─────────────────────────────────────────────────────────────────
  // 8. Cleanup
  // ─────────────────────────────────────────────────────────────────
  await ledger.close();

  _banner('Demo complete — all checks passed');
  return true;
}

// ─────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────

void _banner(String text) {
  final line = '═' * (text.length + 4);
  print('╔$line╗');
  print('║  $text  ║');
  print('╚$line╝');
  print('');
}

void _section(String text) {
  print('▸ $text');
}

String _short(String h) => h.length > 16 ? '${h.substring(0, 16)}…' : h;