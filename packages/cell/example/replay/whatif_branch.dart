// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// What-if demo: fork a ledger at seq 1, replace pulse 2 (parent seq 2)
// with a different value, and see the alternative outcome.
//
// `Cell.state` replaces its value on update, so the parent ends at 3
// (updates 1, 2, 3). The fork's baseline is the state after parent
// seq 1 (value 2); replacing parent seq 2 with 30 gives the fork 30.
//
// Run with: `dart run example/replay/whatif_branch.dart`

import 'package:cell/cell.dart';

Future<void> main() async {
  final counter = Cell.state<int>(initial: 0);
  final graph = (CellGraph.builder(graphId: 'whatif-demo')
        ..registerState('counter', counter))
      .build();
  final ledger = await graph.bindLedger(
    store: InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    ),
  );
  await graph.run(() async {
    counter.update(1); // seq 0
    counter.update(2); // seq 1
    counter.update(3); // seq 2
  });
  print('Recorded value: ${counter.cell.value} (expected 3)');

  // Fork at seq 1: the baseline is the state *after* parent seq 1
  // (value 2); the fork replays parent seq 2 from there.
  final fork = await graph.fork(
    parent: ledger,
    atSeq: 1,
    buildFreshGraph: () {
      // The fresh graph reuses the same cell names, so the live
      // registry must be cleared first; the demo is deliberately
      // exercising the framework's own test seam.
      // ignore: invalid_use_of_visible_for_testing_member
      CellGraphRegistry.forceReset();
      final fresh = Cell.state<int>(initial: 0);
      return (CellGraph.builder(graphId: 'whatif-demo')
            ..registerState('counter', fresh))
          .build();
    },
    buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
  );

  // Replay with a mutation: parent seq 2 is 30 instead of 3.
  final result = await ReplayEngineFork.replayFork(
    fork: fork,
    mutation: (entry, pulse) {
      if (entry.seq == 2) return Pulse<int>(30, source: pulse.source);
      return pulse;
    },
  );

  print('What-if result: success=${result.success}');
  final forkCounter = fork.graph['counter']!.cell as ValueCell<int>;
  print('What-if value: ${forkCounter.value} (expected 30)');
  if (!result.success || forkCounter.value != 30) {
    print('What-if demo FAILED: ${result.divergences}');
    return;
  }
  print('Demo complete.');
}
