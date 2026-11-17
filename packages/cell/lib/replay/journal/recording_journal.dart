// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The recording side of the journal.
///
/// ### How it works
/// Every effect is executed for real; the journal records the observation
/// and the run continues. The recorded log is what [ReplayJournal]
/// consumes later.
///
/// ### Non-obvious: recording happens *after* the operation, not before
///
/// If the operation throws, there is no effect to record — the throw
/// propagates and the ledger records the *failure*, not an
/// effect. This is deliberate: a failed I/O call is not a re-runnable
/// observation; the caller must decide whether to retry (in which case
/// the retry is the new effect).
///
/// See also:
/// * [ReplayJournal] — consumes this journal's log.
/// * [EffectJournal] — the shared contract.
/// {@category Replay}
class RecordingJournal implements EffectJournal {
  final List<EffectRecord> _records = [];
  int _nextOrdinal = 0;

  /// The clock source. Defaults to `DateTime.now`. Tests inject a
  /// deterministic source so the test suite can assert byte-identical
  /// output.
  final DateTime Function() _clockSource;

  /// The UUID source. Defaults to `Uuid().v4`. Same test consideration.
  final String Function() _uuidSource;

  /// The timer scheduler. Defaults to a real `Timer`. Tests inject a
  /// virtual scheduler so the suite does not wait real time.
  final Future<void> Function(Duration, FutureOr<void> Function())
      _timerScheduler;

  /// Creates a recording journal.
  ///
  /// ### Parameters:
  /// - [clockSource]: The clock source; defaults to `DateTime.now`.
  /// - [uuidSource]: The UUID source; defaults to `Uuid().v4`.
  /// - [timerScheduler]: The timer scheduler; defaults to a real `Timer`.
  RecordingJournal({
    DateTime Function()? clockSource,
    String Function()? uuidSource,
    Future<void> Function(Duration, FutureOr<void> Function())?
        timerScheduler,
  })  : _clockSource = clockSource ?? DateTime.now,
        _uuidSource = uuidSource ?? _defaultUuid,
        _timerScheduler = timerScheduler ?? _defaultTimer;

  static String _defaultUuid() => const Uuid().v4();

  static Future<void> _defaultTimer(
    Duration d,
    FutureOr<void> Function() onFire,
  ) =>
      Future.delayed(d, onFire);

  @override
  int get consumed => _records.length;

  @override
  DateTime clock() {
    final now = _clockSource();
    _records.add(ClockEffect(
      ordinal: _nextOrdinal++,
      inputDigest: fingerprint('clock'),
      outputDigest: fingerprint(now.millisecondsSinceEpoch),
      at: now,
      epochMillis: now.millisecondsSinceEpoch,
    ));
    return now;
  }

  @override
  String uuid() {
    final id = _uuidSource();
    final at = _clockSource();
    _records.add(UuidEffect(
      ordinal: _nextOrdinal++,
      inputDigest: fingerprint('uuid'),
      outputDigest: fingerprint(id),
      at: at,
      uuid: id,
    ));
    return id;
  }

  @override
  Future<T> io<T>({
    required String label,
    required Object? input,
    required Future<T> Function() run,
    Object? Function(T)? serializeOutput,
  }) async {
    final at = _clockSource();
    final result = await run();
    final raw = serializeOutput != null ? serializeOutput(result) : result;
    _records.add(IoEffect(
      ordinal: _nextOrdinal++,
      inputDigest: fingerprint(input),
      outputDigest: fingerprint(raw),
      at: at,
      label: label,
      rawOutput: raw,
      // Review fix: the recorder always captures (raw may legitimately
      // be null); the flag lets the replay side distinguish "captured
      // null" from "never recorded".
      hasRawOutput: true,
    ));
    return result;
  }

  @override
  Future<void> timer({
    required Duration duration,
    required Object? input,
    required FutureOr<void> Function() onFire,
    bool fireAtEnd = false,
  }) async {
    final at = _clockSource();
    // Review fix: append the record BEFORE awaiting the fire callback.
    // Any effects the callback performs are nested inside the timer;
    // appending after the callback placed them BEFORE the timer record
    // in the journal, and the replay side consumes the timer record
    // first — an inversion that diverged for nested effects. The
    // recorded `firedAtMillis` therefore approximates the schedule/fire
    // moment rather than a post-fire timestamp (forensic only; replay
    // never validates it).
    _records.add(TimerEffect(
      ordinal: _nextOrdinal++,
      inputDigest: fingerprint(input),
      outputDigest: fingerprint(at.millisecondsSinceEpoch),
      at: at,
      scheduled: duration,
      scheduledAtMillis: at.millisecondsSinceEpoch,
      firedAtMillis: at.millisecondsSinceEpoch,
    ));
    await _timerScheduler(duration, onFire);
  }

  @override
  Future<bool> verdict({
    required String ruleLabel,
    required Object? input,
    required FutureOr<bool> Function() run,
  }) async {
    final at = _clockSource();
    final result = await run();
    _records.add(VerdictEffect(
      ordinal: _nextOrdinal++,
      inputDigest: fingerprint(input),
      outputDigest: fingerprint(result),
      at: at,
      verdict: result,
      ruleLabel: ruleLabel,
    ));
    return result;
  }

  @override
  void policyTick({
    required String policyLabel,
    required String cellId,
    required Object? input,
  }) {
    final at = _clockSource();
    _records.add(PolicyTickEffect(
      ordinal: _nextOrdinal++,
      inputDigest: fingerprint(input),
      outputDigest: fingerprint('$policyLabel@$cellId'),
      at: at,
      policyLabel: policyLabel,
      cellId: cellId,
    ));
  }

  @override
  void push() {}

  @override
  void pop() {}

  @override
  void assertExhausted() {
    // Recording side: there is nothing to exhaust. A recording is a
    // stream; we don't assert that the producer "finished".
  }

  @override
  List<Map<String, Object?>> toJson() =>
      _records.map((r) => r.toJson()).toList(growable: false);

  /// The most recently recorded effect, or `null` if none yet. Used by
  /// the engine's cooperative ledger capture: an effectful operator hands
  /// its just-recorded effect to the active [LedgerScope] so the entry
  /// for the pulse that caused it carries the effect.
  EffectRecord? get lastRecord => _records.isEmpty ? null : _records.last;

  /// All recorded effects, in ordinal order (unmodifiable). The engine's
  /// cooperative capture uses [recordsSince] to hand the active ledger
  /// scope every effect a single mapper invocation recorded.
  List<EffectRecord> get records => List.unmodifiable(_records);

  /// The effects recorded at index [from] and later.
  ///
  /// ### Parameters:
  /// - [from]: The inclusive start index.
  ///
  /// ### Returns:
  /// An iterable of the records at or after [from]; empty when [from] is
  /// past the end.
  Iterable<EffectRecord> recordsSince(int from) {
    if (from >= _records.length) return const Iterable.empty();
    return _records.sublist(from);
  }
}
