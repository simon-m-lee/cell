// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The graph-scoped ambient that coordinates state capture and ledger
/// append.
///
/// `LedgerScope` is **not** per-pulse (that is `JournalScope`'s role);
/// it lives for the lifetime of a `CellGraph`'s binding to a `Ledger`.
/// It provides two functions:
///
/// * `captureDelta` — called by `ValueCell.postProcessRule` when a cell
///   commits a new value. Appends the delta to the *current pulse's*
///   pending list. No-op if no `Ledger` is bound.
/// * `recordAndAppend` — called by `Cell.apply` and the `ValueCell`
///   emit path after the receptor has produced its output. Takes the
///   pulse, the receipt, and the effects from the active `JournalScope`,
///   combines them with the deltas captured during the pulse's
///   processing, and calls `Ledger.appendInternal`.
///
/// ### Why the split
///
/// `postProcessRule` runs *inside* the receptor pipeline (it is the
/// "postProcess" stage). It has access to `(before, after)` and to the
/// cell's id, but **not** to the `ApplyReceipt` — the receipt is created
/// by `Cell.apply` *before* the receptor runs. Conversely, `Cell.apply`
/// has the receipt but cannot observe the delta (the receptor is opaque).
/// The two halves must meet somewhere; `LedgerScope` is that meeting
/// point.
///
/// ### Non-obvious: no scope means no ledger
///
/// If no `LedgerScope` is active (a cell used outside a `CellGraph`),
/// `captureDelta` and `recordAndAppend` are silent no-ops. This is what
/// keeps existing code working: the framework's default is *not* to
/// record, and recording is an opt-in provided by `CellGraph` +
/// `Ledger`. A user who wants auditable state binds a ledger; a user who
/// does not, does not pay.
class LedgerScope {
  static final Object _key = Object();

  /// The currently active scope, or `null` if no ledger is bound.
  static LedgerScopeImpl? get current {
    return Zone.current[_key] as LedgerScopeImpl?;
  }

  /// Runs [body] with [scope] pushed. Pops on exit (success or error),
  /// and drains the scope's queued appends before returning so a
  /// synchronous `body` that performed `ValueCell.update`s has its
  /// entries committed by the time this resolves.
  static Future<T> run<T>(
    LedgerScopeImpl scope,
    FutureOr<T> Function() body,
  ) async {
    final previous = Zone.current[_key] as LedgerScopeImpl?;
    final zoned = Zone.current.fork(
      zoneValues: {_key: scope.withParent(previous)},
    );
    try {
      return await zoned.run(body);
    } finally {
      await scope.drain();
      // Phase-8.3 (review): surface a component's refusal after the
      // body, outside the receptor pipeline where it cannot be
      // swallowed. The first poison wins.
      final poison = scope.poisonReason;
      if (poison != null) {
        throw StateError(
          'LedgerScope.run aborted: a component refused to run under '
          'this ledger: $poison',
        );
      }
    }
  }

  /// The synchronous variant. Used by `ValueCell.postProcessRule`, which
  /// is synchronous.
  static T runSync<T>(LedgerScopeImpl scope, T Function() body) {
    final previous = Zone.current[_key] as LedgerScopeImpl?;
    final zoned = Zone.current.fork(
      zoneValues: {_key: scope.withParent(previous)},
    );
    return zoned.run(body);
  }

  /// Capture a delta from `ValueCell.postProcessRule`. No-op if no scope
  /// is active.
  static void captureDelta(StateDelta delta) {
    current?.captureDelta(delta);
  }

  /// Records a completed pulse through the active scope (if any). When
  /// no receipt exists (the direct `ValueCell` emit path), a synthetic
  /// receipt is produced from [emitCell] and [emitFunction]. The caller
  /// remains synchronous: the append is queued on the scope's
  /// serialisation chain and drained when the enclosing
  /// `LedgerScope.run` completes.
  static void recordPulse({
    required Pulse pulse,
    ApplyReceipt? receipt,
    Cell? emitCell,
    Function? emitFunction,
    Object? emittedValue,
  }) {
    final scope = current;
    if (scope == null) return;
    final effectiveReceipt = receipt ??
        _syntheticReceipt(
          cell: emitCell ?? (pulse.source ?? (throw ArgumentError(
                'LedgerScope.recordPulse: a synthetic receipt needs '
                'emitCell or a pulse source.',
              ))),
          function: emitFunction ?? ((Object? _) => null),
          emittedValue: emittedValue,
        );
    // Resolve the cell id HERE, in the caller's direct context:
    // `Cell.id` walks the nucleus principal chain through a dynamic
    // record access that costs ~0.5 ms per call inside future callbacks
    // (debug VM), which is exactly where the queued append will run.
    final cellId = effectiveReceipt.cell.id;
    final journal = EffectJournal.current;
    // Phase 7: capture only the records written since the previous
    // immediate append (a per-scope watermark), not the whole journal.
    // Without the watermark, a burst of apply pulses would attribute
    // every earlier pulse's records to each later entry.
    final effects = journal is RecordingJournal
        ? journal
            .recordsSince(scope._journalWatermark)
            .toList(growable: false)
        : const <EffectRecord>[];
    if (journal is RecordingJournal) {
      scope._journalWatermark = journal.consumed;
    }
    unawaited(scope.recordAndAppend(
      pulse: pulse,
      receipt: effectiveReceipt,
      cellId: cellId,
      effects: effects,
    ));
  }

  /// Records a pulse whose *observable settlement* happens
  /// asynchronously (Phase 5: ingress emits whose downstream operators
  /// perform effects in detached continuations). The entry is appended
  /// one event-loop turn later — after the microtask queue settles, and
  /// with it the operator's cooperative [captureEffect] calls — so the
  /// entry carries the effects and deltas the pulse actually produced.
  ///
  /// Bursts of emits that do not wait for their asynchronous work to
  /// settle share one settlement turn; their effect attribution is a
  /// Phase 5.1+ concern (pulse-tagged effect windows).
  static void recordPulseDeferred({
    required Pulse pulse,
    ApplyReceipt? receipt,
    Cell? emitCell,
    Function? emitFunction,
    Object? emittedValue,
  }) {
    final scope = current;
    if (scope == null) return;
    final effectiveReceipt = receipt ??
        _syntheticReceipt(
          cell: emitCell ?? (pulse.source ?? (throw ArgumentError(
                'LedgerScope.recordPulse: a synthetic receipt needs '
                'emitCell or a pulse source.',
              ))),
          function: emitFunction ?? ((Object? _) => null),
          emittedValue: emittedValue,
        );
    final cellId = effectiveReceipt.cell.id;
    scope.openWindow(
      pulse: pulse,
      receipt: effectiveReceipt,
      cellId: cellId,
    );
  }

  /// Hands an operator-recorded effect to the current scope. The effect
  /// is attributed to the pending pulse window; the append at window
  /// close carries it in the entry's `effects` list.
  static void captureEffect(EffectRecord record) {
    current?._pendingEffects.add(record);
  }

  static ApplyReceipt _syntheticReceipt({
    required Cell cell,
    required Function function,
    required Object? emittedValue,
  }) {
    return ApplyLedger.receipt(
      cell: cell,
      command: (
        function: function,
        arguments: (
          positionalArguments: [emittedValue],
          namedArguments: null,
        ),
        compensation: null,
      ),
      vetted: false,
    );
  }
}

/// The per-graph implementation of the scope.
///
/// The leading underscore keeps it out of the user-facing surface;
/// `CellGraph.run` constructs it.
class LedgerScopeImpl {
  final Ledger ledger;
  final LedgerScopeImpl? parent;
  final List<StateDelta> _pending = [];
  final List<EffectRecord> _pendingEffects = [];
  final List<Future<void>> _windows = [];
  Future<void> _tail = Future<void>.value();

  /// Phase 7: how many ambient-journal records the immediate
  /// [LedgerScope.recordPulse] path has already attributed. Each
  /// immediate append sweeps only records written after this watermark.
  int _journalWatermark = 0;

  /// Set when a component refuses to run under this ledger scope (e.g.
  /// asyncMap in a non-serial mode). The refusal must be LOUD at the
  /// `graph.run` boundary, because errors thrown inside the receptor
  /// pipeline are swallowed by the framework's error contract
  /// (`pulse._fail`); [LedgerScope.run] rethrows this after the body.
  Object? _poison;

  LedgerScopeImpl({required this.ledger}) : parent = null;

  LedgerScopeImpl._child(this.ledger, this.parent);

  LedgerScopeImpl withParent(LedgerScopeImpl? newParent) {
    if (identical(newParent, parent)) return this;
    return LedgerScopeImpl._child(ledger, newParent);
  }

  /// Records a fatal, scope-wide refusal. The first reason wins.
  void poison(Object reason) {
    _poison ??= reason;
  }

  /// The recorded poison, if any. [LedgerScope.run] throws it after
  /// draining so callers cannot miss a component's refusal.
  Object? get poisonReason => _poison;

  void captureDelta(StateDelta delta) {
    _pending.add(delta);
  }

  /// Opens a deferred pulse window: the append runs one event-loop turn
  /// later, once the microtask queue (and with it the pulse's
  /// asynchronous effect continuations) has settled.
  void openWindow({
    required Pulse pulse,
    required ApplyReceipt receipt,
    required String cellId,
  }) {
    final done = Future<void>.delayed(Duration.zero).then((_) {
      // Still current scope? The zone captured at scheduling keeps
      // `LedgerScope.current` resolving here even after the enclosing
      // run's body returned (drain waits for this window).
      final effects = List<EffectRecord>.of(_pendingEffects);
      _pendingEffects.clear();
      unawaited(recordAndAppend(
        pulse: pulse,
        receipt: receipt,
        cellId: cellId,
        effects: effects,
      ));
    });
    _windows.add(done);
    done.whenComplete(() => _windows.remove(done));
  }

  /// Queues a coordinated append. The deltas are snapshotted *now* (the
  /// current pulse's captured set) and the append runs on the scope's
  /// serialisation chain, so many synchronous `ValueCell.update`s inside
  /// one scope produce entries in the exact update order with the exact
  /// delta attribution. [effects] are the explicitly captured effects;
  /// any cooperatively captured [_pendingEffects] are appended to them.
  ///
  /// ### Non-obvious: identity dedup is load-bearing
  ///
  /// On the immediate (apply/update) path, a cooperative capture (e.g.
  /// `TestCellReplay`'s verdict sweep) stores the *same record instances*
  /// that the journal-watermark sweep in `recordPulse` already collected.
  /// Concatenating both lists would store every such effect twice, and
  /// the replay journal would report one unused effect. `EffectRecord`
  /// does not override `==`, so a set dedupes by identity — exactly the
  /// "same record captured twice" case, and nothing else.
  Future<void> recordAndAppend({
    required Pulse pulse,
    required ApplyReceipt receipt,
    required String cellId,
    required List<EffectRecord> effects,
  }) {
    final deltas = List<StateDelta>.from(_pending);
    _pending.clear();
    final extraEffects = List<EffectRecord>.of(_pendingEffects);
    _pendingEffects.clear();
    final allEffects = <EffectRecord>{...effects, ...extraEffects}.toList(
      growable: false,
    );
    final task = _tail.then(
      (_) => ledger.appendInternal(
        pulse: pulse,
        receipt: receipt,
        cellId: cellId,
        effects: allEffects,
        deltas: deltas,
      ),
    );
    // Keep the chain alive after a failed append; the failure is still
    // reported to the caller of this method.
    _tail = task.catchError((_) {});
    return task;
  }

  /// Resolves when every queued append — including deferred windows —
  /// has completed.
  Future<void> drain() async {
    while (_windows.isNotEmpty) {
      final snapshot = List<Future<void>>.of(_windows);
      await Future.wait(snapshot);
    }
    await _tail;
  }
}
