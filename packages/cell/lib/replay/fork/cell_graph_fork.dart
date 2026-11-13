// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Forking extensions for [CellGraph].
///
/// Provided as an extension so `cell_graph.dart` does not gain a `fork`
/// method — the fork diff surface keeps `cell_graph.dart`
/// unchanged and puts all fork code in `fork/`. The trade-off is that
/// `graph.fork(...)` is only available when `replay.dart` is imported,
/// which is correct: fork is a replay concern, not a graph concern.
extension CellGraphFork on CellGraph {
  /// Forks [this] graph at [atSeq] of [parent].
  ///
  /// [buildFreshGraph] is a factory that builds a *fresh* `CellGraph`
  /// with the same shape as `this`. Typically it closes over the same
  /// `CellGraphBuilder` invocation the original graph was built from.
  /// The fork's `CellGraph` will be the result of calling this factory —
  /// the fork does not clone `this`'s cells, because cell cloning is
  /// a snapshot-reconstruction concern and cloning is *not* required for the
  /// isolated fork policy (the fresh graph's cells are the fork's
  /// working state).
  ///
  /// [buildStore] is the fork's ledger store factory. It receives the
  /// fork's chain genesis (`ForkRecord.genesisHash`) and must construct
  /// a store with that genesis — ledger stores enforce their genesis
  /// hash, and the fork genesis is only known once the fork record
  /// exists. (The doc's caller-supplied store cannot satisfy the
  /// genesis check; a factory is the honest shape.)
  ///
  /// The fresh graph is brought to the parent's state at `atSeq` by
  /// replaying parent entries `0..atSeq` into it (the **baseline
  /// replay**) — the fork ledger does not contain those entries; they
  /// belong to the parent.
  ///
  /// Returns a [ForkHandle] whose `graph` is the fresh graph, whose
  /// `ledger` is a fork ledger seeded by the `ForkRecord`, and whose
  /// `record` is the `ForkRecord`.
  ///
  /// ### Non-obvious: `atSeq` is the *parent*'s sequence, not the
  /// fork's
  ///
  /// If `atSeq == 100`, the fork's `ForkRecord.divergedAt` is 100 and
  /// the fork replays from parent seq 101. `atSeq == 0` forks at the
  /// parent's first entry — the fork's baseline is that entry's state.
  Future<ForkHandle> fork({
    required Ledger parent,
    required int atSeq,
    required CellGraph Function() buildFreshGraph,
    required LedgerStore Function(String genesisHash) buildStore,
    ForkPolicy policy = ForkPolicy.isolated,
  }) async {
    if (policy != ForkPolicy.isolated) {
      throw UnimplementedError(
        'CellGraph.fork: ForkPolicy.${policy.name} is not implemented '
        'in this release. The fork engine only supports isolated forks; '
        'sharedTopology and dropUnreached require snapshot reconstruction.',
      );
    }
    if (atSeq < 0) {
      throw ArgumentError.value(
        atSeq,
        'atSeq',
        'must be >= 0 (the fork baseline includes parent seq atSeq)',
      );
    }

    // 1. Verify the parent is valid before forking from it.
    await parent.verify();

    // 2. The fork binds to the parent's hash AT atSeq — the same value
    //    fork.verify() compares against. (The doc stored the parent's
    //    HEAD hash here, which its own verify() would then reject for
    //    any atSeq below the head.)
    final parentHead = await parent.hashAtSeq(atSeq);

    // 3. Build the fresh graph first: the ForkRecord's snapshot hash
    //    must describe the PARENT'S STATE AT atSeq, not whatever state
    //    the live receiver happens to be in now (review fix: the
    //    previous order fingerprinted `this.snapshot()` — live values
    //    possibly past the fork point — and labelled it with atSeq).
    final freshGraph = buildFreshGraph();
    if (freshGraph.ledger != null) {
      throw StateError(
        'CellGraph.fork: buildFreshGraph returned a graph bound to a '
        'ledger. The fork graph must be unbound.',
      );
    }

    // 4. Baseline replay: bring the fresh graph to the parent's state
    //    at atSeq. This is what makes the fork's starting state equal
    //    the parent's recorded state at the fork point; the doc's
    //    expected alternative states (e.g. 16000 in the what-if test)
    //    assume it.
    if (await parent.lastSeq >= 0) {
      await ReplayEngine.replay(
        ledger: parent,
        target: freshGraph,
        options: ReplayOptions(maxEntries: atSeq + 1),
      );
    }

    // 5. Now the fork point is materialised: fingerprint the
    //    baseline-replayed graph's snapshot as the fork's
    //    originalSnapshotHash.
    final snapshotHash = fingerprint(
      freshGraph.snapshot(lastLedgerSeq: atSeq).toJson(),
    );

    // 6. Build the ForkRecord.
    final record = ForkRecord(
      forkId: const Uuid().v4(),
      originalLedgerId: parent.graph.id,
      divergedAt: atSeq,
      originalSnapshotHash: snapshotHash,
      parentHeadHash: parentHead,
      at: DateTime.now(),
    );

    // 7. Wrap the caller's store so the fork's genesis is the
    //    ForkRecord.
    final forkStore = ForkLedgerStore(
      record: record,
      inner: buildStore(record.genesisHash),
    );

    // 8. Open the fork's ledger, chained from the ForkRecord.
    final forkLedger = await Ledger.open(
      graph: freshGraph,
      store: forkStore,
      genesisHash: record.genesisHash,
    );

    return ForkHandle._(
      graph: freshGraph,
      ledger: forkLedger,
      record: record,
      parent: parent,
    );
  }
}
