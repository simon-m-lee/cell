// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Fork-aware replay: replays a parent ledger into a fork handle,
/// applying a [Mutation] to each entry.
///
/// This is Phase 6's core addition to `ReplayEngine`. It shares the
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
  /// ### Non-obvious: the fork's effects are *newly recorded*
  ///
  /// The parent's effects are in the parent ledger; the fork's effects
  /// are in the fork ledger. When a mutation replaces a pulse, the new
  /// pulse's effects are recorded during the fork's replay (which uses
  /// a fresh `RecordingJournal`). When a mutation drops an entry, no
  /// effects are recorded. When a mutation passes a pulse through
  /// unchanged, the fork still re-records its effects — because the
  /// fork's ledger is independent and must be self-verifiable without
  /// the parent.
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
    final divergences = <DivergenceReport>[];
    int replayed = 0;
    int? firstDivergedAt;

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

      final originalPulse =
          PulseReconstructor.reconstruct(entry: entry, cell: registered.cell);
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
      newSnapshot: fork.graph.snapshot(),
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

    // Build a *fresh* RecordingJournal for the fork's effects. The
    // fork graph's effectful operators prefer the ambient journal
    // (Phase 5), so their effects land here.
    final recordingJournal = RecordingJournal();

    // Run the mutated pulse through the cell's receptor, settling the
    // microtask queue so asynchronous effect continuations finish
    // before the effects are read.
    try {
      await JournalScope.run(recordingJournal, () async {
        final receptor = cell._nucleus.receptor;
        final result = receptor.call(mutatedPulse);
        if (result is Future<Pulse?>) {
          await result;
        }
        if (options.settleAfterDispatch) {
          await Future<void>.delayed(Duration.zero);
        }
      });
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

    // Write the fork's entry to the fork's ledger.
    try {
      await fork.ledger.appendInternal(
        pulse: mutatedPulse,
        receipt: entry.receipt,
        cellId: cellId,
        effects: recordingJournal
            .toJson()
            .map(EffectRecord.fromJson)
            .toList(growable: false),
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
