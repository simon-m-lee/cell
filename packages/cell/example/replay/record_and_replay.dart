// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// End-to-end demo: record a graph's history to a ledger, then replay
// it into a fresh graph and verify the state matches.
//
// Run with: `dart run example/replay/record_and_replay.dart`

import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell/replay.dart';

Future<void> main() async {
  final dir = await Directory.systemTemp.createTemp('cell_replay_demo');
  final path = '${dir.path}/ledger.jsonl';
  try {
    // 1. Record.
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder(graphId: 'demo-graph')
          ..registerState('counter', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: await FileLedgerStore.open(
        path,
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update(1);
      counter.update(2);
      counter.update(3);
    });
    await ledger.verify();
    print('Recorded: ${await ledger.lastSeq + 1} entries at $path');
    await ledger.close();

    // 2. Replay into a fresh graph.
    // The fresh graph reuses the same cell names, so the live registry
    // must be cleared first; the demo is deliberately exercising the
    // framework's own test seam.
    // ignore: invalid_use_of_visible_for_testing_member
    CellGraphRegistry.forceReset();
    final freshCounter = Cell.state<int>(initial: 0);
    final freshGraph = (CellGraph.builder(graphId: 'demo-graph')
          ..registerState('counter', freshCounter))
        .build();
    final reopenStore = await FileLedgerStore.open(
      path,
      genesisHash: Ledger.genesisHashOf(graph.id),
    );
    final reopenLedger = await Ledger.open(
      graph: graph,
      store: reopenStore,
      genesisHash: Ledger.genesisHashOf(graph.id),
    );

    final result = await ReplayEngine.replay(
      ledger: reopenLedger,
      target: freshGraph,
    );
    print('Replayed: success=${result.success}, '
        'entries=${result.entriesReplayed}');
    print('Fresh counter value: ${freshCounter.cell.value}');
    if (!result.success || freshCounter.cell.value != 3) {
      stderr.writeln('Record-and-replay demo FAILED: '
          '${result.divergences}');
      exitCode = 1;
      return;
    }
    await reopenLedger.close();
    print('Demo complete.');
  } finally {
    await dir.delete(recursive: true);
  }
}
