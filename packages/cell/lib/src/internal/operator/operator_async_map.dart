// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell.dart';

// ─────────────────────────────────────────────────────────────
// factory - asyncMap
// ─────────────────────────────────────────────────────────────

/// Maps each upstream payload through an async function and emits results.
///
/// Phase 3 (D6 breaking change): the mapper takes a **required named
/// `journal` parameter** and the factory takes a `journal:` argument —
/// asyncMap is effectful, and its I/O must go through the journal. The
/// mapper runs inside `JournalScope.run(journal, …)`, so both the
/// parameter and `EffectJournal.current` are the same journal.
///
/// ### Mapper contract
///
/// The mapper must **await** every `journal.io(...)`/`journal.clock(...)`
/// call before returning. A mapper that spawns a detached task must pass
/// its `journal` parameter into that task explicitly — `JournalScope.run`
/// covers the mapper call itself, not work spawned from it.
///
/// ### Concurrency modes
/// * [concurrency] `0` (default) – unlimited in-flight (mergeMap-style)
/// * [concurrency] `1` – sequential (concatMap-style)
/// * [concurrency] `n` – at most *n* concurrent futures
/// * [latestOnly] `true` – drop results from older generations (switchMap-style)
/// * [exhaust] `true` – **ignore new upstream values while any work is in flight**
///   (exhaustMap-style). Takes precedence over queueing when busy.
///
/// [latestOnly] and [exhaust] are mutually exclusive in intent:
/// * switch → cancel interest in in-flight when a newer value arrives
/// * exhaust → refuse new values until the current in-flight work finishes
///
/// ### Ledger attribution (Phase 8 hardening)
///
/// Concurrent mapper invocations share one [EffectJournal]; a positional
/// `recordsSince(before)` window over that shared sequence cannot tell
/// which invocation wrote which record. Under an active `LedgerScope`,
/// `concurrency > 1` and `latestOnly` therefore throw a loud
/// [StateError] instead of silently cross-contaminating ledger entries.
/// Pulse-tagged effect windows (the correct attribution) are the
/// deferred Phase 5.1 item; the default `concurrency: 0` remains
/// available, and attributes correctly when emissions wait for their
/// async work to settle.
Cell _asyncMap<S, T>(
  Cell source,
  Future<T> Function(S value, {required EffectJournal journal}) mapper, {
  required EffectJournal journal,
  int concurrency = 0,
  bool latestOnly = false,
  bool exhaust = false,
  EphemeralPolicy? ephemeralPolicy,
  Context context = Context.system,
  TestCell testRule = TestCell.allowAll,
  Synapses synapses = Synapses.enabled,
  bool forceLock = false,
}) {
  if (latestOnly && exhaust) {
    throw ArgumentError(
      'asyncMap: use either latestOnly or exhaust, not both',
    );
  }

  final state = _AsyncMapState<S, T>(
    mapper: mapper,
    journal: journal,
    concurrency: concurrency <= 0 ? 0 : concurrency,
    latestOnly: latestOnly,
    exhaust: exhaust,
  );

  final outputCell = Cell.governed(
    ephemeralPolicy: ephemeralPolicy,
    context: context,
    receptor: _EffectfulPassThroughReceptor(),
    testRule: testRule,
    synapses: synapses,
    forceLock: forceLock,
  );

  void emitResult(T value) {
    if (outputCell.isInvalidated) return;
    outputCell._nucleus.receptor.call(
      Pulse<T>.governed(payload: value, source: outputCell),
    );
  }

  final bridge = Cell.governed(
    bind: source,
    context: context,
    testRule: TestCell.allowAll,
    synapses: Synapses.disabled,
    receptor: Receptor(
      (cell, pulse, {user}) {
        if (outputCell.isInvalidated) return null;
        final payload = pulse.payload;
        if (payload is! S) return null;

        state.enqueue(payload, pulse: pulse as PulseBase, onResult: emitResult);
        return null; // do not forward source pulse
      },
    ),
  );

  state.retain(bridge);
  return outputCell;
}

class _AsyncMapState<S, T> {
  _AsyncMapState({
    required this.mapper,
    required this.journal,
    required this.concurrency,
    required this.latestOnly,
    required this.exhaust,
  });

  final Future<T> Function(S value, {required EffectJournal journal}) mapper;
  final EffectJournal journal;
  final int concurrency; // 0 = unlimited
  final bool latestOnly;
  final bool exhaust;

  final List<({S value, PulseBase pulse})> _queue = [];
  int _inFlight = 0;
  int _generation = 0;
  // ignore: unused_field
  Object? _pin;

  void retain(Object pin) => _pin = pin;

  bool get _busy => _inFlight > 0;

  void enqueue(
    S value, {
    required PulseBase pulse,
    required void Function(T value) onResult,
  }) {
    // ── exhaustMap: drop upstream while busy ─────────────────
    if (exhaust && _busy) {
      return; // ignore new values until idle
    }

    // Phase 8 hardening: overlapping mapper invocations share one
    // journal, so effect records cannot be attributed per invocation
    // (see the factory doc). Refuse the configuration loudly while a
    // ledger is recording instead of corrupting entries.
    if ((concurrency > 1 || latestOnly) && LedgerScope.current != null) {
      throw StateError(
        'asyncMap: concurrent mapper invocations '
        '(concurrency: $concurrency, latestOnly: $latestOnly) cannot be '
        'attributed to ledger entries in Phase 8 — their effect records '
        'share one journal and would cross-contaminate entries. '
        'Pulse-tagged effect windows are the deferred Phase 5.1 fix; use '
        'concurrency: 1 (and latestOnly: false) under a ledgered graph, '
        'or record without a ledger.',
      );
    }

    if (latestOnly) {
      _generation++;
      _queue
        ..clear()
        ..add((value: value, pulse: pulse));
      _pump(onResult, generation: _generation);
      return;
    }

    _queue.add((value: value, pulse: pulse));
    _pump(onResult, generation: _generation);
  }

  void _pump(void Function(T value) onResult, {required int generation}) {
    while (_queue.isNotEmpty) {
      if (concurrency > 0 && _inFlight >= concurrency) break;
      // exhaust uses concurrency effectively as 1 when in flight via enqueue gate;
      // still respect explicit concurrency for non-exhaust modes.

      final next = _queue.removeAt(0);
      _inFlight++;
      final gen = generation;

      Future<void>(() async {
        try {
          // The mapper runs inside JournalScope.run so that its I/O is
          // journalled — and so `EffectJournal.current` inside the mapper
          // resolves to the same journal as its `journal:` parameter.
          // Phase 5: the ambient journal wins when an outer scope has
          // pushed one (ReplayEngine's per-entry ReplayJournal); the
          // construction-time journal is the fallback for recording.
          final effective = JournalScope.effectiveJournal(journal);
          final before =
              effective is RecordingJournal ? effective.consumed : 0;
          final result = await JournalScope.run(
            effective,
            () => mapper(next.value, journal: effective),
          );
          // Phase 5 cooperative ledger capture: hand the just-recorded
          // effects to the active LedgerScope so the entry for the pulse
          // that caused this mapping carries them — every effect the
          // mapper invocation produced, not only the last one. Only for
          // RecordingJournal-backed runs (replays have no ledger scope).
          //
          // Phase 5.1 caveat: this positional window is only sound while
          // invocations do not overlap; overlapping configurations are
          // refused loudly at enqueue time (see above).
          final ledgerScope = LedgerScope.current;
          if (ledgerScope != null && effective is RecordingJournal) {
            for (final record in effective.recordsSince(before)) {
              LedgerScope.captureEffect(record);
            }
          }
          if (latestOnly && gen != _generation) return; // superseded
          onResult(result);
        } catch (e, st) {
          // Phase 8 hardening: the mapper failed. Route the failure to
          // the source pulse's onError channel instead of swallowing it
          // — a swallowed failure is invisible to the recording (and to
          // every downstream waiting on the pulse). No emission happens,
          // matching the documented "errors produce no output" contract.
          next.pulse._fail(e, stackTrace: st);
        } finally {
          _inFlight--;
          // Always drain. In `latestOnly` mode `enqueue` has already cleared
          // stale entries, so the remaining head is the latest generation.
          // Without this unconditional pump, a `latestOnly + concurrency > 0`
          // configuration leaves the queued latest value stranded when the
          // superseded future finishes (its `gen` no longer matches
          // `_generation`).
          _pump(onResult, generation: _generation);
        }
      });
    }
  }
}
