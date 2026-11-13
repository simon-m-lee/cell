// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The replay engine.
///
/// Given a [Ledger] and a [CellGraph] (the "target", typically freshly
/// built from the same `CellGraphBuilder` that produced the original),
/// the engine replays entries one by one, dispatching each reconstructed
/// pulse into the target graph and asserting that the resulting state
/// matches the ledger entry's recorded deltas.
///
/// ### Non-obvious: the target graph is provided, not reconstructed
///
/// Phase 5 does **not** reconstruct a graph from a `CellGraphSnapshot`
/// — that is Phase 5.1 (a payload-codec-driven concern; the current
/// Phase 1 snapshot does not store enough to rebuild a graph's cells
/// from scratch without the codec registry that Phase 3+ builds). The
/// caller provides the target graph, typically freshly built from the
/// same `CellGraphBuilder` that produced the original. The plan's
/// exit criterion "replay 500 pulses against an identical graph"
/// describes exactly this: the target is *the same graph shape*, not a
/// reconstructed one. Phase 5.1 will relax this, and the `ReplayEngine`
/// API does not need to change.
///
/// ### What is verified per entry
///
/// 1. The receipt's back-filled fields (`ledgerSeq`, `pulseDigest`).
/// 2. The receipt's cell is registered in the target graph.
/// 3. The pulse is reconstructable (arguments, or a recorded delta).
/// 4. The receptor consumes **exactly** the entry's recorded effects,
///    in order, through the per-entry [ReplayJournal] (the target's
///    effectful operators consult the ambient journal — see
///    `JournalScope.effectiveJournal`).
/// 5. Every recorded `StateDelta` is reproduced: after dispatch, each
///    delta cell's current value must equal `delta.after`.
///
/// What is deliberately **not** verified: the recorded `pulseDigest`
/// against a reconstructed pulse. The digest hashes the pulse's full
/// JSON including its wall-clock timestamp; a hash is one-way and a
/// reconstruction can never match it byte-for-byte. The delta
/// comparison is the authoritative state check. (The Phase 5 doc's
/// step 9 check would fail on every entry; this engine documents that
/// honestly instead.)
class ReplayEngine {
  const ReplayEngine._();

  /// Replays the ledger into [target], starting at [fromSeq].
  ///
  /// [target] must be a graph bound to a *fresh* ledger store (or no
  /// ledger at all). The engine pushes a **ReplayJournal** per entry so
  /// the receptor's effectful calls are served from the recording, not
  /// re-executed against the real world.
  ///
  /// On success, returns a [ReplayResult] whose `newSnapshot` is the
  /// target graph's state at the end of replay. On failure (strict
  /// mode), throws [ReplayDivergenceException]. In lenient mode,
  /// returns a result with `success == false` and non-empty
  /// `divergences`.
  static Future<ReplayResult> replay({
    required Ledger ledger,
    required CellGraph target,
    int fromSeq = 0,
    ReplayOptions options = ReplayOptions.strict,
  }) async {
    if (target.ledger != null) {
      throw StateError(
        'ReplayEngine.replay: target graph "${target.id}" is bound to a '
        'ledger. Replaying into a ledgered graph would re-append entries '
        'and corrupt the history. Use a graph that is not bound to a '
        'ledger (call unbindLedger first), or provide a graph built '
        'from the same CellGraphBuilder that produced the original.',
      );
    }

    final divergences = <DivergenceReport>[];
    int replayed = 0;
    int? firstDivergedAt;

    await for (final entry in ledger.entriesSince(fromSeq)) {
      if (options.maxEntries != null && replayed >= options.maxEntries!) {
        break;
      }

      final divergence = await _replayOne(
        entry: entry,
        target: target,
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

    final success = divergences.isEmpty;
    return ReplayResult(
      success: success,
      entriesReplayed: replayed,
      divergedAt: firstDivergedAt,
      divergences: List.unmodifiable(divergences),
      newSnapshot: target.snapshot(),
    );
  }

  /// Replays a single entry, returning a [DivergenceReport] if anything
  /// diverged, or `null` on success.
  static Future<DivergenceReport?> _replayOne({
    required LedgerEntry entry,
    required CellGraph target,
    required ReplayOptions options,
  }) async {
    // 1. Verify the receipt's back-filled fields (if requested).
    if (options.verifyReceipts) {
      if (entry.receipt.ledgerSeq != entry.seq) {
        return DivergenceReport(
          seq: entry.seq,
          expected: entry.seq,
          actual: entry.receipt.ledgerSeq,
          reason: 'receipt.ledgerSeq does not match entry.seq '
              '(the entry was not produced by Ledger.appendInternal)',
        );
      }
      if (entry.receipt.pulseDigest != entry.pulseDigest) {
        return DivergenceReport(
          seq: entry.seq,
          expected: entry.pulseDigest,
          actual: entry.receipt.pulseDigest,
          reason: 'receipt.pulseDigest does not match entry.pulseDigest',
        );
      }
    }

    // 2. Resolve the target cell. If the ledger refers to a cell that is
    //    not in the target graph, that is a hard divergence: the
    //    recording is for a graph that is not the one being replayed.
    final cellId = entry.receipt.cell.id;
    final registered = target[cellId];
    if (registered == null) {
      return DivergenceReport(
        seq: entry.seq,
        expected: cellId,
        actual: '<not registered>',
        reason: 'ledger entry refers to cell "$cellId", which is not '
            'registered in the target graph',
      );
    }
    final cell = registered.cell;

    // 3. Reconstruct the input pulse. If it cannot be reconstructed,
    //    the entry is hand-crafted; treat as divergence.
    final pulse = PulseReconstructor.reconstruct(entry: entry, cell: cell);
    if (pulse == null) {
      return DivergenceReport(
        seq: entry.seq,
        expected: '<reconstructable pulse>',
        actual: null,
        reason: 'pulse could not be reconstructed from the ledger '
            'entry (missing receipt.arguments and deltas)',
      );
    }

    // 4. Build a ReplayJournal from the entry's effects and run the
    //    pulse through the target graph inside that journal's scope.
    final replayJournal = ReplayJournal(entry.effects);

    // 5. Dispatch. The pulse's processing must be journalled; the
    //    asynchronous continuations (asyncMap mappers, deferred timer
    //    fires) settle in microtasks, so the event loop is drained
    //    before the journal and delta checks. A divergence thrown
    //    directly (sync receptors) is surfaced here; a divergence
    //    thrown inside a detached mapper continuation is swallowed by
    //    the operator's error contract and surfaced by the journal's
    //    divergence flag in step 6.
    try {
      await JournalScope.run(replayJournal, () async {
        await _dispatch(target: target, cell: cell, pulse: pulse);
        if (options.settleAfterDispatch) {
          await Future<void>.delayed(Duration.zero);
        }
      });
    } on ReplayDivergenceException catch (e) {
      return DivergenceReport(
        seq: entry.seq,
        expected: '<replay succeeded>',
        actual: e.message,
        lastEffect: _effectAt(entry, replayJournal.consumed),
        reason: 'journal divergence: ${e.message}',
      );
    }

    // 6. Verify the journal was fully consumed and never diverged.
    try {
      replayJournal.assertExhausted();
    } on ReplayDivergenceException catch (e) {
      return DivergenceReport(
        seq: entry.seq,
        expected: 'journal exhausted',
        actual: replayJournal.divergenceReason ??
            '${replayJournal.remaining} unused effect(s)',
        lastEffect: _effectAt(entry, replayJournal.consumed),
        reason: 'journal not exhausted: ${e.message}',
      );
    }

    // 7. Verify the delta list matches. `ValueCell.postProcessRule`
    //    captured `(before, after)` during the recording; the same
    //    capture is a no-op during replay (no LedgerScope is active),
    //    so the engine re-reads each delta cell's value after dispatch
    //    and compares it to `delta.after`. A cell whose value did not
    //    change during replay still diverges if its current value does
    //    not equal the recorded `after`.
    final mismatch = _verifyDeltas(entry: entry, target: target);
    if (mismatch != null) return mismatch;

    return null;
  }

  static EffectRecord? _effectAt(LedgerEntry entry, int index) {
    if (index < 0 || index >= entry.effects.length) return null;
    return entry.effects[index];
  }

  /// Dispatches [pulse] through [target]'s [cell]. The dispatch goes
  /// straight through the cell's receptor — the same path the original
  /// emit/apply machinery used — without re-entering `Cell.apply` or
  /// the ledger hooks (no LedgerScope is active, so nothing is
  /// re-recorded).
  static Future<Pulse?> _dispatch({
    required CellGraph target,
    required Cell cell,
    required Pulse pulse,
  }) async {
    final receptor = cell._nucleus.receptor;
    final result = receptor.call(pulse);
    if (result is Future<Pulse?>) return await result;
    return result;
  }

  /// Verifies that every recorded delta's `after` matches the current
  /// value of the corresponding cell in the target graph.
  static DivergenceReport? _verifyDeltas({
    required LedgerEntry entry,
    required CellGraph target,
  }) {
    for (final delta in entry.deltas) {
      final registered = target[delta.cellId];
      if (registered == null) {
        return DivergenceReport(
          seq: entry.seq,
          expected: delta.cellId,
          actual: '<not registered>',
          reason: 'ledger delta refers to cell "${delta.cellId}", which '
              'is not registered in the target graph',
        );
      }
      final cell = registered.cell;
      if (cell is! ValueCell) {
        // Non-ValueCell cells do not have a `value`; the delta for such
        // a cell (if any) records a different kind of state. Phase 5
        // does not verify these; Phase 5.1 will, when the payload codec
        // gains support for non-ValueCell state snapshots.
        continue;
      }
      final actualValue = cell.value;
      // Compare via canonical JSON so an `int` 5 and a `num` 5 are
      // treated as equal (they serialise the same way).
      final expectedJson = canonicalJsonEncode(delta.after);
      final actualJson = canonicalJsonEncode(actualValue);
      if (expectedJson != actualJson) {
        return DivergenceReport(
          seq: entry.seq,
          expected: delta.after,
          actual: actualValue,
          reason: 'delta.after mismatch for cell "${delta.cellId}" '
              '(the receptor produced a different value than recorded)',
        );
      }
    }
    return null;
  }
}
