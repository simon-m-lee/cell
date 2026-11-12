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
    final journal = EffectJournal.current;
    final effects = journal is RecordingJournal
        ? journal
            .toJson()
            .map(EffectRecord.fromJson)
            .toList(growable: false)
        : const <EffectRecord>[];
    unawaited(scope.recordAndAppend(
      pulse: pulse,
      receipt: effectiveReceipt,
      effects: effects,
    ));
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
  Future<void> _tail = Future<void>.value();

  LedgerScopeImpl({required this.ledger}) : parent = null;

  LedgerScopeImpl._child(this.ledger, this.parent);

  LedgerScopeImpl withParent(LedgerScopeImpl? newParent) {
    if (identical(newParent, parent)) return this;
    return LedgerScopeImpl._child(ledger, newParent);
  }

  void captureDelta(StateDelta delta) {
    _pending.add(delta);
  }

  /// Queues a coordinated append. The deltas are snapshotted *now* (the
  /// current pulse's captured set) and the append runs on the scope's
  /// serialisation chain, so many synchronous `ValueCell.update`s inside
  /// one scope produce entries in the exact update order with the exact
  /// delta attribution.
  Future<void> recordAndAppend({
    required Pulse pulse,
    required ApplyReceipt receipt,
    required List<EffectRecord> effects,
  }) {
    final deltas = List<StateDelta>.from(_pending);
    _pending.clear();
    final task = _tail.then(
      (_) => ledger.appendInternal(
        pulse: pulse,
        receipt: receipt,
        effects: effects,
        deltas: deltas,
      ),
    );
    // Keep the chain alive after a failed append; the failure is still
    // reported to the caller of this method.
    _tail = task.catchError((_) {});
    return task;
  }

  /// Resolves when every queued append has completed.
  Future<void> drain() => _tail;
}
