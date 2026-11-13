// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Audit demo: the workflow an external auditor follows.
//
//   1. Open the ledger.
//   2. Verify the hash chain (proves it hasn't been tampered with).
//   3. Inspect the summary (proves the shape of the history).
//   4. Replay into a fresh graph (proves the recorded state is
//      reachable from the recorded pulses).
//   5. Compare the replayed state to the state the operator reports.
//
// Run with: `dart run example/replay/audit_ledger.dart`

import 'package:cell/cell.dart';

Future<void> main() async {
  // 1. The "operator" produces a graph and a ledger.
  final account = Cell.state<int>(initial: 1000);
  final graph = (CellGraph.builder(graphId: 'audit-demo')
        ..registerState('account', account))
      .build();
  final ledger = await graph.bindLedger(
    store: InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    ),
  );
  await graph.run(() async {
    // Cell.state replaces on update: the balance steps 1000 → 900 →
    // 800 → 500.
    account.update(900);
    account.update(800);
    account.update(500);
  });
  final operatorReportedValue = account.cell.value;
  print('Operator reports balance: $operatorReportedValue');

  // 2. The "auditor" gets the ledger, not the operator's state.
  print('--- Auditor workflow ---');
  await ledger.verify();
  print('OK: hash chain is intact.');

  final entries = await ledger.entriesSince(0).toList();
  print('Ledger has ${entries.length} entries.');
  print('Cells touched: '
      '${entries.expand((e) => e.deltas.map((d) => d.cellId)).toSet()}');

  // 3. Auditor reconstructs a fresh graph and replays.
  // The fresh graph reuses the same cell names, so the live registry
  // must be cleared first; the demo is deliberately exercising the
  // framework's own test seam.
  // ignore: invalid_use_of_visible_for_testing_member
  CellGraphRegistry.forceReset();
  final freshAccount = Cell.state<int>(initial: 1000);
  final freshGraph = (CellGraph.builder(graphId: 'audit-demo')
        ..registerState('account', freshAccount))
      .build();
  final result = await ReplayEngine.replay(
    ledger: ledger,
    target: freshGraph,
  );
  print('Replay: success=${result.success}');

  // 4. Auditor compares.
  final replayedValue = freshAccount.cell.value;
  print('Replayed balance: $replayedValue');
  if (result.success && replayedValue == operatorReportedValue) {
    print('OK: operator report matches replayed state.');
  } else {
    print('MISMATCH: operator report does not match replayed state.');
    print('Divergences: ${result.divergences}');
    return;
  }
  print('Demo complete.');
}
