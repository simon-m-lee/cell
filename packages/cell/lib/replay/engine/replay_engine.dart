// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The replay engine.
///
/// ### When to use
/// Given a [Ledger] and a [CellGraph] (the "target", typically freshly
/// built from the same [CellGraphBuilder] that produced the original),
/// the engine replays entries one by one, dispatching each reconstructed
/// pulse into the target graph and asserting that the resulting state
/// matches the ledger entry's recorded deltas.
///
/// ### Non-obvious: the target graph is provided, not reconstructed
///
/// The engine does **not** reconstruct a graph from a
/// [CellGraphSnapshot]: the snapshot does not store enough to rebuild a
/// graph's cells from scratch without a payload-codec registry. The
/// caller provides the target graph, typically freshly built from the
/// same [CellGraphBuilder] that produced the original — the target is
/// *the same graph shape*, not a reconstructed one. Replaying many pulses
/// against an identical graph is the intended acceptance test. A later
/// revision may relax this without changing the [ReplayEngine] API.
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
/// 5. Every recorded [StateDelta] is reproduced: after dispatch, each
///    delta cell's current value must equal `delta.after`.
///
/// What is deliberately **not** verified: the recorded `pulseDigest`
/// against a reconstructed pulse. The digest hashes the pulse's full
/// JSON including its wall-clock timestamp; a hash is one-way and a
/// reconstruction can never match it byte-for-byte. The delta
/// comparison is the authoritative state check. (A per-entry
/// pulse-digest check would fail on every entry; this engine documents
/// that honestly instead.)
///
/// See also:
/// * [Ledger] — the history that is replayed.
/// * [CellGraph] — the target the history is replayed into.
/// * [ReplayResult] — the outcome.
/// * [PulseReconstructor] — the reconstruction machinery.
/// {@category Replay}
class ReplayEngine {
  const ReplayEngine._();

  /// Replays the ledger into [target], starting at [fromSeq].
  ///
  /// [target] must be a graph bound to a *fresh* ledger store (or no
  /// ledger at all). The engine pushes a **ReplayJournal** per entry so
  /// the receptor's effectful calls are served from the recording, not
  /// re-executed against the real world.
  ///
  /// ### Parameters:
  /// - [ledger]: The recorded history to replay.
  /// - [target]: The graph to replay into.
  /// - [fromSeq]: The first ledger sequence to replay.
  /// - [options]: Strictness flags; defaults to [ReplayOptions.strict].
  ///
  /// ### Returns:
  /// On success, a [ReplayResult] whose `newSnapshot` is the target
  /// graph's state at the end of replay. On failure (strict mode),
  /// throws [ReplayDivergenceException]. In lenient mode, returns a
  /// result with `success == false` and non-empty `divergences`.
  ///
  /// ### Non-obvious: the purity gate is the journal, not a pre-check
  ///
  /// The engine does not consult `CellGraph.purityOf` up front. An
  /// `effectful` cell whose entry records no effects replays "fine" —
  /// but the only way to record *no* effects with an effectful
  /// component is to have journalled nothing, which the journal's
  /// exhaustion checks then cannot see either. The honest gate is on
  /// the recording side (`NullJournal` fails loudly, and every
  /// `effectful` rule writes a verdict); a dedicated purity
  /// pre-validation is a later hardening.
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

    // Hardening (review fix): never replay a corrupt history.
    // One pass recomputes every hash of the chain; a tampered ledger
    // fails here with a LedgerIntegrityException instead of producing a
    // confusing downstream divergence.
    await ledger.verify();

    final divergences = <DivergenceReport>[];
    int replayed = 0;
    int? firstDivergedAt;
    final checkBaseline = fromSeq == 0;
    // Pulse bodies resolve their parent chains by digest; the engine
    // registers each reconstructed pulse as it replays earlier entries.
    final parentsByDigest = <String, Pulse<dynamic>>{};
    // Timer fires are deferred to after the entry loop (see
    // ReplayJournal.deferredFires): the recording's trailing edges
    // happened between entries, and firing inside the consuming entry
    // moved downstream writes one entry too early.
    final deferredFires = <FutureOr<void> Function()>[];

    await for (final entry in ledger.entriesSince(fromSeq)) {
      if (options.maxEntries != null && replayed >= options.maxEntries!) {
        break;
      }
      // Review fix: a fork ledger's seq 0 is the ForkRecord marker
      // (cell `fork:<id>`), not a replayed pulse — replaying it always
      // diverged. Make the usage error loud instead: fork replays must
      // start at seq 1.
      if (entry.seq == 0 && entry.receipt.id.startsWith('fork:')) {
        throw StateError(
          'ReplayEngine.replay: seq 0 of a fork ledger is the '
          'ForkRecord marker, not an entry to replay. Replay a fork '
          'with fromSeq: 1.',
        );
      }

      final divergence = await _replayOne(
        entry: entry,
        target: target,
        options: options,
        checkBaseline: checkBaseline,
        parentsByDigest: parentsByDigest,
        deferredFires: deferredFires,
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

    // Run the deferred timer fires — the recording's trailing edges —
    // after every entry has replayed and every delta check has passed.
    // The fires may write the target cells; their downstream effect is
    // exactly what the recorded deltas of the following entries expect.
    for (final fire in deferredFires) {
      await fire();
    }

    final success = divergences.isEmpty;
    return ReplayResult(
      success: success,
      entriesReplayed: replayed,
      divergedAt: firstDivergedAt,
      divergences: List.unmodifiable(divergences),
      // Tie the snapshot to the sequence the replay actually reached
      // (review fix: the default -1 made the snapshot unbound).
      newSnapshot: target.snapshot(lastLedgerSeq: fromSeq + replayed - 1),
    );
  }

  /// Replays a single entry, returning a [DivergenceReport] if anything
  /// diverged, or `null` on success.
  static Future<DivergenceReport?> _replayOne({
    required LedgerEntry entry,
    required CellGraph target,
    required ReplayOptions options,
    required bool checkBaseline,
    required Map<String, Pulse<dynamic>> parentsByDigest,
    required List<FutureOr<void> Function()> deferredFires,
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
    //    The recorded id — not the live receipt cell's re-resolved id —
    //    must be used: the live registry may have been reset since the
    //    recording.
    final cellId = entry.receiptCellId;
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

    // Version check. If the target's live receptor/rule versions do
    // not match the ledger's, the version registry supplies the
    // historical pair — which the dispatch below actually RUNS (review
    // fix: a registry hit used to authorise the live implementation).
    // If neither matches, fail loudly (a version boundary without a
    // translator is a divergence, not a guess).
    final versionCheck = _checkVersions(entry: entry, target: target);
    if (versionCheck.report != null) return versionCheck.report!;
    final historicalReceptor = versionCheck.receptor;

    // 3. Reconstruct the input pulse. If it cannot be reconstructed,
    //    the entry is hand-crafted; treat as divergence.
    final pulse = PulseReconstructor.reconstruct(
      entry: entry,
      cell: cell,
      parentsByDigest: parentsByDigest,
    );
    if (pulse == null) {
      return DivergenceReport(
        seq: entry.seq,
        expected: '<reconstructable pulse>',
        actual: null,
        reason: 'pulse could not be reconstructed from the ledger '
            'entry (missing receipt.arguments and deltas)',
      );
    }

    // 4. Baseline verification (full replays only). Each delta's
    //    `before` must equal the target cell's value *before* dispatch:
    //    an absolute set on a graph that was not at the recorded
    //    baseline would otherwise pass silently (the `after` check below
    //    cannot see the wrong starting point). Partial replays
    //    (`fromSeq > 0`) deliberately skip this — the caller materialised
    //    the state at `fromSeq - 1` themselves.
    if (checkBaseline) {
      for (final delta in entry.deltas) {
        final deltaCell = target[delta.cellId]?.cell;
        if (deltaCell is! ValueCell) continue;
        final Object? actualBefore;
        try {
          actualBefore = ValueCell._encodeForLedger(deltaCell.value);
        } catch (e, st) {
          return DivergenceReport(
            seq: entry.seq,
            expected: delta.before,
            actual: '<not encodable: $e>',
            reason: 'baseline value of "${delta.cellId}" cannot be '
                'encoded for comparison: $e\n$st',
          );
        }
        if (canonicalJsonEncode(actualBefore) !=
            canonicalJsonEncode(delta.before)) {
          return DivergenceReport(
            seq: entry.seq,
            expected: delta.before,
            actual: actualBefore,
            reason: 'delta.before mismatch for cell "${delta.cellId}" '
                '(the target was not at the recorded baseline when this '
                'entry replayed; build the fresh graph with the recorded '
                'initial state)',
          );
        }
      }
    }

    // 5. Build a ReplayJournal from the entry's effects and run the
    //    pulse through the target graph inside that journal's scope.
    final replayJournal =
        ReplayJournal(entry.effects, deferredFires: deferredFires);

    // 6. Dispatch. The pulse's processing must be journalled; the
    //    asynchronous continuations (asyncMap mappers, deferred timer
    //    fires) settle in microtasks, so the event loop is drained
    //    before the journal and delta checks. A divergence thrown
    //    directly (sync receptors) is surfaced here; a divergence
    //    thrown inside a detached mapper continuation is swallowed by
    //    the operator's error contract and surfaced by the journal's
    //    divergence flag in step 6.
    try {
      await JournalScope.run(replayJournal, () async {
        await _dispatch(
          target: target,
          cell: cell,
          pulse: pulse,
          historicalReceptor: historicalReceptor,
        );
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

  /// Version enforcement. Returns a non-null [DivergenceReport] when the
  /// ledger's recorded receptor/rule versions cannot be satisfied by
  /// the target graph (no registry entry and no live match), and the
  /// historical [Receptor] when the registry supplied one.
  ///
  /// ### The registry *installs*, not just gates (review fix)
  ///
  /// A registry hit no longer authorises the live implementation: the
  /// registered historical receptor is returned and the dispatch clones
  /// and activates it on the target cell, so a registered v1 actually
  /// RUNS beside a live v2. The registered pair's rule version must also
  /// match the recorded rule version. What remains deferred: running
  /// the registered historical *rule* through the pipeline (the
  /// receptor alone cannot re-execute `TestCell` validation) and
  /// consulting the `ContextTranslatorRegistry` during dispatch.
  static ({DivergenceReport? report, Receptor? receptor}) _checkVersions({
    required LedgerEntry entry,
    required CellGraph target,
  }) {
    final cellId = entry.receiptCellId;
    final ledgerReceptorVersion = entry.receipt.receptorVersion;
    final ledgerRuleVersion = entry.receipt.ruleVersion;

    if (ledgerReceptorVersion == null || ledgerRuleVersion == null) {
      // Ledger without version fields. If the live versions
      // are also unversioned ('0.0.0'), treat as equal; otherwise
      // refuse to guess.
      final live = target[cellId]!.cell._nucleus;
      if (live.receptor.version == '0.0.0' &&
          live.testRule.version == '0.0.0') {
        return (report: null, receptor: null);
      }
      return (
        report: DivergenceReport(
          seq: entry.seq,
          expected: 'unversioned ledger',
          actual: 'live receptor version ${live.receptor.version}',
          reason: 'ledger has no version information, but the target graph '
              'is versioned; refusing to guess whether the receptor '
              'implementation is the one that produced the entry',
        ),
        receptor: null,
      );
    }

    // The version registry wins when it has the recorded version — and
    // its historical receptor is what dispatch will run.
    final resolved =
        target.versions.resolve(cellId: cellId, version: ledgerReceptorVersion);
    if (resolved != null) {
      if (resolved.testRule.version != ledgerRuleVersion) {
        return (
          report: DivergenceReport(
            seq: entry.seq,
            expected: 'rule version $ledgerRuleVersion',
            actual: 'registered rule version ${resolved.testRule.version}',
            reason: 'the version registry resolves receptor version '
                '$ledgerReceptorVersion but its rule version '
                '${resolved.testRule.version} does not match the recorded '
                'rule version $ledgerRuleVersion',
          ),
          receptor: null,
        );
      }
      return (report: null, receptor: resolved.receptor);
    }

    // Otherwise the live implementation must match exactly.
    final live = target[cellId]!.cell._nucleus;
    if (live.receptor.version == ledgerReceptorVersion &&
        live.testRule.version == ledgerRuleVersion) {
      return (report: null, receptor: null);
    }

    return (
      report: DivergenceReport(
        seq: entry.seq,
        expected: 'version $ledgerReceptorVersion / $ledgerRuleVersion',
        actual: 'version ${live.receptor.version} / ${live.testRule.version}',
        reason: 'version boundary: the ledger recorded receptor version '
            '$ledgerReceptorVersion and rule version $ledgerRuleVersion, '
            'but the target graph has versions '
            '${live.receptor.version} / ${live.testRule.version}. Register '
            'the recorded version in the graph\'s VersionRegistry '
            '(graph.registerVersion), or record a ledger at the current '
            'version.',
      ),
      receptor: null,
    );
  }

  /// Dispatches [pulse] through [target]'s [cell]. The dispatch goes
  /// straight through the cell's receptor — the same path the original
  /// emit/apply machinery used — without re-entering `Cell.apply` or
  /// the ledger hooks (no LedgerScope is active, so nothing is
  /// re-recorded). When [historicalReceptor] is supplied (a version
  /// registry hit), a fresh clone is activated on the target cell and
  /// THAT implementation runs instead of the live one.
  static Future<Pulse?> _dispatch({
    required CellGraph target,
    required Cell cell,
    required Pulse pulse,
    Receptor? historicalReceptor,
  }) async {
    final receptor = cell._nucleus.receptor;
    if (historicalReceptor == null) {
      final result = receptor.call(pulse);
      if (result is Future<Pulse?>) return await result;
      return result;
    }
    final historical = historicalReceptor.clone;
    if (!historical.activate(cell)) {
      throw StateError(
        'ReplayEngine._dispatch: the registered historical receptor '
        'could not be activated on cell "${cell.id}"',
      );
    }
    final result = historical.call(pulse);
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
        // a cell (if any) records a different kind of state. The engine
        // does not verify these; a later revision will, when the payload codec
        // gains support for non-ValueCell state snapshots.
        continue;
      }
      final actualValue = cell.value;
      // Encode the live value with the SAME codec that produced the
      // recorded delta, then compare canonical JSON. (Review fix: the
      // previous direct canonicalJsonEncode of the live value threw
      // ArgumentError for DateTime/Cell values instead of reporting a
      // divergence.)
      final Object? actualEncoded;
      try {
        actualEncoded = ValueCell._encodeForLedger(actualValue);
      } catch (e, st) {
        return DivergenceReport(
          seq: entry.seq,
          expected: delta.after,
          actual: '<not encodable: $e>',
          reason: 'delta.after comparison failed for cell '
              '"${delta.cellId}": the live value cannot be encoded '
              '($e)\n$st',
        );
      }
      final expectedJson = canonicalJsonEncode(delta.after);
      final actualJson = canonicalJsonEncode(actualEncoded);
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
