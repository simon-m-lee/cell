// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The replay side of the journal.
///
/// Each operation consumes the next recorded effect of the matching kind
/// and asserts that its input digest matches. On mismatch (wrong kind,
/// wrong input, or journal empty), the replay **fails loudly** with a
/// [ReplayDivergenceException]. This is the mechanism the design describes
/// as "reordered effects diverge loudly".
///
/// ### Non-obvious: validation happens *before* consumption
///
/// A record is only consumed (cursor advanced) after its kind, label,
/// and input have been validated. A mismatched attempt leaves the
/// record unconsumed, which is what lets `assertExhausted` (and 
/// 5's engine) report the divergence after a detached mapper
/// continuation has swallowed the thrown exception. Any failed attempt
/// also latches [diverged] so that a replay which *touched* a mismatch
/// can never report success, even when all records happen to be
/// consumed afterwards.
///
/// ### Non-obvious: the `run` and `onFire` closures are *ignored*
///
/// On the replay side, the caller's `run` callback is not executed. If
/// it were, the replay would touch the network — which is precisely what
/// replay is supposed to avoid. Instead, the recorded `rawOutput` is
/// returned. This means that **any code path that depends on the `run`
/// closure's side effects (as opposed to its return value) is not
/// replayed** — which is correct: replay reproduces the *observations*,
/// not the *actions*.
class ReplayJournal implements EffectJournal {
  final List<EffectRecord> _records;
  int _cursor = 0;
  bool _diverged = false;
  String? _divergenceReason;

  /// Whether any consumption attempt has diverged from the recording,
  /// even if the thrown exception was caught by the caller (e.g. an
  /// operator's mapper error contract).
  bool get diverged => _diverged;

  /// The first divergence reason, if [diverged] is true.
  String? get divergenceReason => _divergenceReason;

  /// Creates a replay journal from a recorded log. The list must be in
  /// ordinal order (which `RecordingJournal.toJson` guarantees).
  ///
  /// [deferredFires] changes the timer semantics for ENGINE replay: fire
  /// callbacks are collected instead of run inside the consuming entry,
  /// and the engine runs them after the entry loop. (Review fix: the
  /// eager fire landed a debounce trailing edge one entry before the
  /// recording's, breaking the recorded baseline of the next entry.
  /// Direct journal users — the tests — pass nothing and keep the eager
  /// behaviour.)
  ReplayJournal(
    List<EffectRecord> records, {
    List<FutureOr<void> Function()>? deferredFires,
  })  : _records = records,
        _deferredFires = deferredFires;

  final List<FutureOr<void> Function()>? _deferredFires;

  @override
  int get consumed => _cursor;

  /// The number of effects remaining to be consumed. Used by
  /// [assertExhausted] and by the engine's divergence diagnostics.
  int get remaining => _records.length - _cursor;

  @override
  DateTime clock() {
    final record = _peek<ClockEffect>(ClockEffect);
    _commit();
    return DateTime.fromMillisecondsSinceEpoch(record.epochMillis);
  }

  @override
  String uuid() {
    final record = _peek<UuidEffect>(UuidEffect);
    _commit();
    return record.uuid;
  }

  @override
  Future<T> io<T>({
    required String label,
    required Object? input,
    required Future<T> Function() run,
    Object? Function(T)? serializeOutput,
  }) async {
    final record = _peek<IoEffect>(IoEffect);
    if (record.label != label) {
      _fail(
        'I/O label mismatch: expected "$label", recorded "${record.label}"',
        ordinal: record.ordinal,
      );
    }
    if (record.inputDigest != fingerprint(input)) {
      _fail(
        'I/O input mismatch for "$label": the replay attempted an effect '
        'whose input differs from the recorded one. The receptor has '
        'changed since the recording was taken.',
        ordinal: record.ordinal,
      );
    }
    if (!record.hasRawOutput) {
      _fail(
        'I/O effect "$label" cannot be replayed: rawOutput was not '
        'recorded. Pass serializeOutput to RecordingJournal.io.',
        ordinal: record.ordinal,
      );
    }
    // Validate the stored digest against the stored output (review fix:
    // outputDigest was never checked, and a mutated stored object would
    // otherwise rewrite history silently). Catch ONLY the codec error:
    // `_fail` throws ReplayDivergenceException, which must propagate as
    // the digest-mismatch divergence — not be swallowed by this catch
    // and re-wrapped as a bogus "not encodable" failure (the first
    // review regression).
    final Object? served;
    try {
      served = record.rawOutput;
      if (fingerprint(served) != record.outputDigest) {
        _fail(
          'I/O output digest mismatch for "$label": the stored rawOutput '
          'no longer matches the recorded outputDigest (the recorded '
          'object was mutated after the fact, or the ledger is '
          'tampered).',
          ordinal: record.ordinal,
        );
      }
    } on ArgumentError catch (e, st) {
      _fail(
        'I/O output for "$label" cannot be validated: the stored '
        'rawOutput is not encodable ($e)\n$st',
        ordinal: record.ordinal,
      );
    }
    _commit();
    try {
      return served as T;
    } on TypeError catch (e, st) {
      // Consumed but unusable: surface as a replay divergence instead of
      // a raw TypeError — AND latch the divergence (review fix: the
      // previous bare throw left `_diverged` false, so an operator error
      // contract could swallow the exception and `assertExhausted`
      // would pass if this was the last effect).
      _diverged = true;
      _divergenceReason ??= 'I/O output type mismatch for "$label": '
          'the recorded output cannot be used as the requested type '
          '($e)';
      throw ReplayDivergenceException(
        'I/O output type mismatch for "$label": the recorded output '
        'cannot be used as the requested type ($e)\n$st',
        ordinal: record.ordinal,
      );
    }
  }

  @override
  Future<void> timer({
    required Duration duration,
    required Object? input,
    required FutureOr<void> Function() onFire,
    bool fireAtEnd = false,
  }) async {
    final record = _peek<TimerEffect>(TimerEffect);
    if (record.scheduled != duration) {
      _fail(
        'timer duration mismatch: expected $duration, '
        'recorded ${record.scheduled}',
        ordinal: record.ordinal,
      );
    }
    if (record.inputDigest != fingerprint(input)) {
      _fail(
        'timer input mismatch: the replay attempted a timer with a '
        'different input than the recorded one.',
        ordinal: record.ordinal,
      );
    }
    _commit();
    // Review fix: a recorded timer that was CANCELLED before it fired
    // must not fire during replay — the recording already re-armed (or
    // dropped) it, and firing here would emit a pulse the recording
    // never produced.
    if (record.cancelled) {
      return;
    }
    // On the replay side, `onFire` IS called — it is the *internal
    // continuation* of the debounce/throttle state machine. What is
    // skipped is the actual `Timer` wait. The callback is deferred one
    // microtask first: a real timer can never fire inside the same
    // synchronous burst that scheduled it, and that ordering is exactly
    // what lets a superseded debounce/throttle timer be cancelled before
    // its fire callback runs during replay.
    //
    // Engine replays pass `deferredFires` and OUTPUT fires (a debounce
    // trailing edge) are marked with `fireAtEnd`: they run AFTER the
    // entry loop, at the point in the causal order where the recording's
    // trailing edge actually happened — firing them inside the consuming
    // entry moved downstream writes one entry too early and broke the
    // next entry's recorded baseline. INTERNAL fires (a throttle gate
    // release, the default) stay eager: the next entry needs the
    // released gate.
    if (_deferredFires != null && fireAtEnd) {
      _deferredFires!.add(onFire);
      return;
    }
    await Future<void>.delayed(Duration.zero);
    await onFire();
  }

  @override
  void push() {}

  @override
  void pop() {}

  @override
  Future<bool> verdict({
    required String ruleLabel,
    required Object? input,
    required FutureOr<bool> Function() run,
  }) async {
    final record = _peek<VerdictEffect>(VerdictEffect);
    if (record.ruleLabel != ruleLabel) {
      _fail(
        'verdict rule label mismatch: expected "$ruleLabel", '
        'recorded "${record.ruleLabel}"',
        ordinal: record.ordinal,
      );
    }
    if (record.inputDigest != fingerprint(input)) {
      _fail(
        'verdict input mismatch for rule "$ruleLabel": the replay '
        'asked about a different input than the recording did.',
        ordinal: record.ordinal,
      );
    }
    _commit();
    return record.verdict;
  }

  @override
  void policyTick({
    required String policyLabel,
    required String cellId,
    required Object? input,
  }) {
    final record = _peek<PolicyTickEffect>(PolicyTickEffect);
    if (record.policyLabel != policyLabel) {
      _fail(
        'policy tick label mismatch: expected "$policyLabel", '
        'recorded "${record.policyLabel}"',
        ordinal: record.ordinal,
      );
    }
    if (record.cellId != cellId) {
      _fail(
        'policy tick cell mismatch: expected "$cellId", '
        'recorded "${record.cellId}"',
        ordinal: record.ordinal,
      );
    }
    if (record.inputDigest != fingerprint(input)) {
      _fail(
        'policy tick input mismatch for "$policyLabel@$cellId": the '
        'replay ticked a different input than the recording did.',
        ordinal: record.ordinal,
      );
    }
    _commit();
    // The tick is consumed; the caller applies it to the CycleChecker.
  }

  @override
  void assertExhausted() {
    if (_diverged) {
      throw ReplayDivergenceException(
        _divergenceReason!,
        ordinal: _cursor < _records.length ? _records[_cursor].ordinal : null,
      );
    }
    if (remaining != 0) {
      throw ReplayDivergenceException(
        'ReplayJournal exhausted with $remaining unused effect(s). '
        'This means the receptor consumed fewer effects than were '
        'recorded — the receptor implementation has changed since the '
        'recording was taken.',
        ordinal: _records[_cursor].ordinal,
      );
    }
  }

  @override
  List<Map<String, Object?>> toJson() => const []; // Replay never writes.

  /// Latch a divergence and throw. The latch makes the failure visible
  /// even when the thrown exception is swallowed by an operator's
  /// mapper error contract; `assertExhausted` rethrows it afterwards.
  Never _fail(String message, {int? ordinal}) {
    _diverged = true;
    _divergenceReason ??= message;
    throw ReplayDivergenceException(message, ordinal: ordinal);
  }

  T _peek<T extends EffectRecord>(Type type) {
    if (_cursor >= _records.length) {
      _fail(
        'ReplayJournal is empty, but the receptor attempted another '
        'effect of type $type. The receptor now performs more effects '
        'than were recorded.',
      );
    }
    final record = _records[_cursor];
    if (record is! T) {
      _fail(
        'Effect kind mismatch at ordinal ${record.ordinal}: expected '
        '$type, recorded ${record.runtimeType}.',
        ordinal: record.ordinal,
      );
    }
    return record;
  }

  /// Advances the cursor past the currently peeked record. Only called
  /// after the record's fields validated — a field mismatch leaves the
  /// record unconsumed, which is the load-bearing detail for the engine's
  /// divergence diagnostics (the mismatched effect stays identifiable).
  void _commit() {
    _cursor++;
  }
}

/// Thrown when a replay diverges from the recording.
///
/// Catching this exception is the *only* correct response to a
/// divergence — the replay has produced a state that does not match the
/// ledger, and continuing would silently corrupt the caller's
/// understanding of the recording. `DivergenceReport` wraps
/// this with the ledger's `seq` and the before/after state, for the CLI.
class ReplayDivergenceException implements Exception {
  final String message;
  final int? ordinal;

  /// The ledger seq at which the divergence occurred.
  final int? seq;

  /// The full report, when available.
  final DivergenceReport? report;

  ReplayDivergenceException(
    this.message, {
    this.ordinal,
    this.seq,
    this.report,
  });

  @override
  String toString() {
    final buf = StringBuffer('ReplayDivergenceException');
    if (seq != null) buf.write(' (seq $seq)');
    if (ordinal != null) buf.write(' (ordinal $ordinal)');
    buf.write(': $message');
    return buf.toString();
  }
}
