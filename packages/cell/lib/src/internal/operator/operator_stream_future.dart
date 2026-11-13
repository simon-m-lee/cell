// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell.dart';

// ─────────────────────────────────────────────────────────────
// operator - fromStream
// ─────────────────────────────────────────────────────────────

/// Creates a cell that emits the values produced by a Dart [Stream].
///
/// Phase 3 (D6 breaking change): `journal:` is required. Each event is
/// recorded through the journal before the live pulse is emitted, so the
/// recorded event order is what Phase 5's `ReplayEngine` re-injects
/// during replay. Events whose values are not JSON-encodable fail loudly
/// at the fingerprint boundary — such streams cannot be replayed.
///
/// ### Ordering guarantee
///
/// The record is written with the *same* `JournalScope` the emission runs
/// in, and the shipped `RecordingJournal.io` appends in invocation order
/// for this operator's constant-time `run` closure (microtasks resolve
/// FIFO), so event N's record precedes event N+1's on the ledger. A
/// custom journal that reorders its writes must not be passed here; a
/// per-event monotonic sequence tag is the Phase 5.1 hardening.
///
/// ### Error handling gap (documented, Phase 5.1)
///
/// `onError` currently only cancels the subscription when
/// `cancelOnError` is set — the error itself is neither emitted as a
/// pulse nor journalled, so replay omits it. Journaling stream errors as
/// effect records is deferred to Phase 5.1 (error-pulse reconstruction).
///
/// The subscription is cancelled automatically when the cell is
/// invalidated.
Cell _fromStream<T>(
  Stream<T> stream, {
  required EffectJournal journal,
  EphemeralPolicy? ephemeralPolicy,
  Context context = Context.system,
  TestCell testRule = TestCell.allowAll,
  Synapses synapses = Synapses.enabled,
  bool forceLock = false,
  bool cancelOnError = false,
}) {
  late final Cell cell;
  StreamSubscription<T>? sub;

  void cancelSubscription() {
    final current = sub;
    sub = null;
    current?.cancel();
  }

  final lifecycle = EphemeralPolicy<Cell>(
    duration: ephemeralPolicy?.duration,
    eventLimit: ephemeralPolicy?.eventLimit,
    onEvent: (object, {required Cell cell, required policy, arguments, user}) {
      // Tick the caller's policy so its own onEvent/limit/invalidation
      // semantics are preserved, then report the wrapper's own counter.
      ephemeralPolicy?.call(object, cell: cell, arguments: arguments);
      return (events: policy.events + 1);
    },
    onInvalidate: (nucleus) {
      cancelSubscription();
      // Preserve the caller's policy's own invalidation hook — the wrapper
      // replaced it on the host cell, so it would otherwise never run.
      ephemeralPolicy?.invalidate(nucleus.cell);
      return true;
    },
  );

  cell = Cell.governed(
    ephemeralPolicy: lifecycle,
    context: context,
    receptor: _EffectfulPassThroughReceptor(),
    testRule: testRule,
    synapses: synapses,
    forceLock: forceLock,
  );

  final hostRef = WeakReference(cell);
  final streamLabel = 'fromStream<${T.toString()}>';

  sub = stream.listen(
    (value) {
      final host = hostRef.target;
      if (host == null || host.isInvalidated) {
        cancelSubscription();
        return;
      }
      // Record the event through the journal. The recorded value is what
      // Phase 5's ReplayEngine re-injects during replay; the live path
      // emits the actual value either way, synchronously as before.
      final effective = JournalScope.effectiveJournal(journal);
      unawaited(JournalScope.run(
        effective,
        () => effective.io(
          label: streamLabel,
          input: value,
          run: () async => value,
        ),
      ));
      JournalScope.runSync(effective, () {
        host._nucleus.receptor.call(
          Pulse<T>.governed(payload: value, source: host),
        );
      });
      // Removed: redundant lifecycle(value, cell: host) call.
      // passThrough is not governed, but the cell is.
      // ReceptorBase._proceed handles the lifecycle policy tick automatically.
      final limit = lifecycle.eventLimit;
      if (host.isInvalidated || (limit != null && lifecycle.events >= limit)) {
        cancelSubscription();
      }
    },
    onError: (Object error, StackTrace st) {
      if (cancelOnError) {
        cancelSubscription();
      }
    },
    onDone: cancelSubscription,
    cancelOnError: cancelOnError,
  );

  Finalizer<void Function()>(
    (cancel) => cancel(),
  ).attach(cell, cancelSubscription, detach: cell);

  return cell;
}

// ─────────────────────────────────────────────────────────────
// operator - fromFuture
// ─────────────────────────────────────────────────────────────

/// Creates a cell that emits the result of a [Future] exactly once.
///
/// Phase 3 (D6 breaking change): `journal:` is required. The future's
/// *value* is journalled so replay can rebuild the pulse without
/// re-awaiting the future (which would re-trigger I/O); the completion is
/// recorded in journal order. The live path emits the actual value
/// synchronously, as before.
///
/// Phase 8 fix: the completion resolves the **ambient** journal
/// (`JournalScope.effectiveJournal`), matching `fromStream` and
/// `asyncMap` — an outer `ReplayEngine`-pushed `ReplayJournal` therefore
/// wins over the construction-time journal even though the future's
/// continuation may run in a different scope than the one that created
/// the cell.
///
/// ### Error handling gap (documented, Phase 5.1)
///
/// `onError` emits a `type: 'error'` pulse through the cell (so the live
/// graph reacts), but the failure is not journalled as an effect — replay
/// cannot reconstruct the error pulse. Journaling future errors is
/// deferred to Phase 5.1 (error-pulse reconstruction).
Cell _fromFuture<T>(
  Future<T> future, {
  required EffectJournal journal,
  EphemeralPolicy? ephemeralPolicy,
  Context context = Context.system,
  TestCell testRule = TestCell.allowAll,
  Synapses synapses = Synapses.enabled,
  bool forceLock = false,
}) {
  final cell = Cell.governed(
    ephemeralPolicy: ephemeralPolicy,
    context: context,
    receptor: _EffectfulPassThroughReceptor(),
    testRule: testRule,
    synapses: synapses,
    forceLock: forceLock,
  );

  final futureLabel = 'fromFuture<${T.toString()}>';

  future.then((value) {
    if (!cell.isInvalidated) {
      final effective = JournalScope.effectiveJournal(journal);
      unawaited(JournalScope.run(
        effective,
        () => effective.io(
          label: futureLabel,
          input: null,
          run: () async => value,
        ),
      ));
      JournalScope.runSync(effective, () {
        cell._nucleus.receptor.call(
          Pulse<T>.governed(payload: value, source: cell),
        );
      });
    }
  }, onError: (Object error, StackTrace stackTrace) {
    if (!cell.isInvalidated) {
      final effective = JournalScope.effectiveJournal(journal);
      JournalScope.runSync(effective, () {
        cell._nucleus.receptor.call(
          Pulse<Object>.governed(
            payload: error,
            type: 'error',
            source: cell,
          ),
        );
      });
    }
  });

  return cell;
}
