// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Fork-aware replay: replays a parent ledger into a fork handle,
/// applying a [Mutation] to each entry.
///
/// The fork engine's core addition to `ReplayEngine`. It shares the
/// engine's reconstruction machinery but:
///
/// * **Applies the mutation** before dispatch: `mutation(entry, pulse)`
///   can drop the entry (`null`) or replace the pulse (`Pulse`).
/// * **Writes to the fork ledger**, not the parent: each replayed entry
///   (whether original or replaced) is appended to `fork.ledger`, so
///   the fork has its own history.
/// * **Does not verify against the parent's deltas** — the fork is
///   *expected* to diverge; its own ledger records what it actually
///   did.
extension ReplayEngineFork on ReplayEngine {
  /// Replays [fork.parent]'s entries from `fork.record.divergedAt + 1`
  /// into `fork.graph`, applying [mutation] to each entry.
  ///
  /// [mutation] receives the reconstructed input pulse. Returning
  /// `null` drops the entry (the fork's ledger will not contain it).
  /// Returning a pulse — same or different — replays that pulse into
  /// the fork's graph.
  ///
  /// The fork's ledger is written via `fork.ledger.appendInternal`.
  /// This is the *only* path that writes a fork ledger; a fork does
  /// not accept external `append` calls.
  ///
  /// ### Non-obvious: the fork replays from `divergedAt + 1`, not from
  /// `divergedAt`
  ///
  /// The fork's `seq 0` is the `ForkRecord`. The parent's seq
  /// `divergedAt` is the *last entry* included in the fork's baseline.
  /// The first entry the fork replays is parent seq `divergedAt + 1`.
  /// This is what makes "fork at 100" mean "the fork's baseline is the
  /// parent's state at 100; the fork replays 101 onward".
  ///
  /// ### Non-obvious: the fork *serves* the parent's effects
  ///
  /// The parent's effects are in the parent ledger; the fork's entries
  /// carry them forward into the fork ledger. Each replayed entry is
  /// dispatched under a `ReplayJournal` built from the PARENT entry's
  /// records — the fork never re-runs effectful `io` against the real
  /// world, and the fork's ledger stores the same effect list the
  /// parent recorded. Consequence: a mutation that replaces a pulse
  /// whose I/O *differs* from the parent's will diverge instead of
  /// becoming the fork's history. What-if is defined over
  /// **pulses**, not effects; re-recording mutated effects (a fresh
  /// RecordingJournal + live I/O) is a later forking revision. When
  /// a mutation drops an entry, nothing is appended.
  static Future<ReplayResult> replayFork({
    required ForkHandle fork,
    required Mutation mutation,
    ReplayOptions options = ReplayOptions.strict,
  }) async {
    if (!identical(fork.ledger.graph, fork.graph)) {
      throw StateError(
        'ReplayEngine.replayFork: fork.ledger.graph is not fork.graph. '
        'This is a bug in CellGraph.fork; file an issue.',
      );
    }

    final parent = fork.parent;
    final startSeq = fork.record.divergedAt + 1;

    // Hardening (review fix): never replay a corrupt history,
    // and never append onto a corrupt fork chain.
    await parent.verify();
    await fork.ledger.verify();

    final divergences = <DivergenceReport>[];
    int replayed = 0;
    int? firstDivergedAt;
    final parentsByDigest = <String, Pulse<dynamic>>{};

    await for (final entry in parent.entriesSince(startSeq)) {
      if (options.maxEntries != null && replayed >= options.maxEntries!) {
        break;
      }

      // The parent ledger's entries are the source of truth for
      // *what was recorded*; the mutation decides *what the fork
      // replays*.
      final cellId = entry.receiptCellId;
      final registered = fork.graph[cellId];
      if (registered == null) {
        final d = DivergenceReport(
          seq: entry.seq,
          expected: cellId,
          actual: '<not registered in fork>',
          reason: 'parent entry refers to cell "$cellId", which is not '
              'registered in the fork graph',
        );
        divergences.add(d);
        firstDivergedAt ??= entry.seq;
        if (options.failOnDivergence) {
          throw ReplayDivergenceException(d.reason, seq: entry.seq, report: d);
        }
        replayed++;
        continue;
      }

      final originalPulse = PulseReconstructor.reconstruct(
        entry: entry,
        cell: registered.cell,
        parentsByDigest: parentsByDigest,
      );
      if (originalPulse == null) {
        final d = DivergenceReport(
          seq: entry.seq,
          expected: '<reconstructable pulse>',
          actual: null,
          reason: 'pulse could not be reconstructed from parent entry',
        );
        divergences.add(d);
        firstDivergedAt ??= entry.seq;
        if (options.failOnDivergence) {
          throw ReplayDivergenceException(d.reason, seq: entry.seq, report: d);
        }
        replayed++;
        continue;
      }

      // Apply the mutation.
      final mutatedPulse = mutation(entry, originalPulse);
      if (mutatedPulse == null) {
        // Dropped. The fork's ledger will not contain a record of this
        // entry. That's the mutation's explicit choice.
        replayed++;
        continue;
      }

      // Replay the mutated pulse into the fork's graph, writing to the
      // fork's ledger.
      final divergence = await _replayForkOne(
        entry: entry,
        mutatedPulse: mutatedPulse,
        fork: fork,
        options: options,
      );

      replayed++;
      if (divergence != null) {
        divergences.add(divergence);
        firstDivergedAt ??= entry.seq;
        if (options.failOnDivergence) {
          throw ReplayDivergenceException(
            divergence.reason,
            seq: entry.seq,
            report: divergence,
          );
        }
      }
    }

    return ReplayResult(
      success: divergences.isEmpty,
      entriesReplayed: replayed,
      divergedAt: firstDivergedAt,
      divergences: List.unmodifiable(divergences),
      newSnapshot: fork.graph.snapshot(
        // Tie the snapshot to the parent sequence the fork reached
        // (review fix: the default -1 made the snapshot unbound).
        lastLedgerSeq: startSeq + replayed - 1,
      ),
    );
  }

  /// Replays a single mutated pulse into the fork's graph and appends
  /// the result to the fork's ledger.
  static Future<DivergenceReport?> _replayForkOne({
    required LedgerEntry entry,
    required Pulse mutatedPulse,
    required ForkHandle fork,
    required ReplayOptions options,
  }) async {
    final cellId = entry.receiptCellId;
    final cell = fork.graph[cellId]!.cell;

    // The fork's actual before-value — read BEFORE dispatch. (The doc
    // assumed the parent entry's before; that equality holds only until
    // the first mutation, after which the fork's history is its own.)
    final Object? beforeValue = cell is ValueCell ? cell.value : null;

    // Build the replay journal from the PARENT entry's effects. (Review
    // fix: the fork used a fresh RecordingJournal here, which re-ran the
    // effectful operators' `io` against the real world. The fork replays
    // the parent's entry, so its effects must be SERVED from the
    // parent's records — exactly like the main engine.)
    final replayJournal = ReplayJournal(entry.effects);

    // Run the mutated pulse through the cell's receptor, settling the
    // microtask queue so asynchronous effect continuations finish
    // before the journal is checked.
    try {
      await JournalScope.run(replayJournal, () async {
        final receptor = cell._nucleus.receptor;
        final result = receptor.call(mutatedPulse);
        if (result is Future<Pulse?>) {
          await result;
        }
        if (options.settleAfterDispatch) {
          await Future<void>.delayed(Duration.zero);
        }
      });
      try {
        replayJournal.assertExhausted();
      } on ReplayDivergenceException catch (e) {
        return DivergenceReport(
          seq: entry.seq,
          expected: 'journal exhausted',
          actual: replayJournal.divergenceReason ??
              '${replayJournal.remaining} unused effect(s)',
          reason: 'fork journal not exhausted: ${e.message}',
        );
      }
    } catch (e) {
      return DivergenceReport(
        seq: entry.seq,
        expected: '<replay succeeds>',
        actual: e.toString(),
        reason: 'fork replay threw: $e',
      );
    }

    // Capture the delta the fork produced. For a ValueCell, the before
    // is the state the fork's baseline + previous replays left; the
    // after is what this dispatch actually produced.
    final forkDeltas = <StateDelta>[];
    if (cell is ValueCell) {
      forkDeltas.add(StateDelta(
        cellId: cellId,
        before: ValueCell._encodeForLedger(beforeValue),
        after: ValueCell._encodeForLedger(cell.value),
        at: DateTime.now(),
      ));
    }

    // Write the fork's entry to the fork's ledger. (Review fix: the
    // receipt's arguments are rebuilt from the MUTATED pulse — the
    // parent's arguments described the pre-mutation input, so a later
    // ReplayEngine.replay of the fork ledger would have reconstructed
    // the wrong pulse. The engine reconstructs "first positional
    // argument as payload", so that is exactly what we store.)
    final forkReceipt = (
      id: entry.receipt.id,
      cell: entry.receipt.cell,
      function: entry.receipt.function,
      arguments: (
        positionalArguments: <Object?>[mutatedPulse.payload],
        namedArguments: null,
      ),
      timestamp: entry.receipt.timestamp,
      txSequence: entry.receipt.txSequence,
      vetted: entry.receipt.vetted,
      ledgerSeq: null,
      pulseDigest: null,
      receptorVersion: null,
      ruleVersion: null,
      contextVersion: null,
    );
    try {
      await fork.ledger.appendInternal(
        pulse: mutatedPulse,
        receipt: forkReceipt,
        cellId: cellId,
        effects: entry.effects,
        deltas: forkDeltas,
      );
    } catch (e) {
      return DivergenceReport(
        seq: entry.seq,
        expected: '<fork append succeeds>',
        actual: e.toString(),
        reason: 'fork append failed: $e',
      );
    }

    return null;
  }
}
