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
/// [ReplayDivergenceException]. This is the mechanism the plan describes
/// as "reordered effects diverge loudly".
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

  /// Creates a replay journal from a recorded log. The list must be in
  /// ordinal order (which `RecordingJournal.toJson` guarantees).
  ReplayJournal(List<EffectRecord> records) : _records = records;

  @override
  int get consumed => _cursor;

  /// The number of effects remaining to be consumed. Used by
  /// [assertExhausted] and by Phase 5's divergence diagnostics.
  int get remaining => _records.length - _cursor;

  @override
  DateTime clock() {
    final record = _consume<ClockEffect>(ClockEffect);
    return DateTime.fromMillisecondsSinceEpoch(record.epochMillis);
  }

  @override
  String uuid() {
    final record = _consume<UuidEffect>(UuidEffect);
    return record.uuid;
  }

  @override
  Future<T> io<T>({
    required String label,
    required Object? input,
    required Future<T> Function() run,
    Object? Function(T)? serializeOutput,
  }) async {
    final record = _consume<IoEffect>(IoEffect);
    if (record.label != label) {
      throw ReplayDivergenceException(
        'I/O label mismatch: expected "$label", recorded "${record.label}"',
        ordinal: record.ordinal,
      );
    }
    if (record.inputDigest != fingerprint(input)) {
      throw ReplayDivergenceException(
        'I/O input mismatch for "$label": the replay attempted an effect '
        'whose input differs from the recorded one. The receptor has '
        'changed since the recording was taken.',
        ordinal: record.ordinal,
      );
    }
    if (record.rawOutput == null) {
      throw ReplayDivergenceException(
        'I/O effect "$label" cannot be replayed: rawOutput was not '
        'recorded. Pass serializeOutput to RecordingJournal.io.',
        ordinal: record.ordinal,
      );
    }
    return record.rawOutput as T;
  }

  @override
  Future<void> timer({
    required Duration duration,
    required Object? input,
    required FutureOr<void> Function() onFire,
  }) async {
    final record = _consume<TimerEffect>(TimerEffect);
    if (record.scheduled != duration) {
      throw ReplayDivergenceException(
        'timer duration mismatch: expected $duration, '
        'recorded ${record.scheduled}',
        ordinal: record.ordinal,
      );
    }
    if (record.inputDigest != fingerprint(input)) {
      throw ReplayDivergenceException(
        'timer input mismatch: the replay attempted a timer with a '
        'different input than the recorded one.',
        ordinal: record.ordinal,
      );
    }
    // On the replay side, `onFire` IS called — it is the *internal
    // continuation* of the debounce/throttle state machine. What is
    // skipped is the actual `Timer` wait; the replay fires the callback
    // in journal order, which reproduces the interleaving.
    await onFire();
  }

  @override
  void push() {}

  @override
  void pop() {}

  @override
  void assertExhausted() {
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

  T _consume<T extends EffectRecord>(Type type) {
    if (_cursor >= _records.length) {
      throw ReplayDivergenceException(
        'ReplayJournal is empty, but the receptor attempted another '
        'effect of type $type. The receptor now performs more effects '
        'than were recorded.',
      );
    }
    final record = _records[_cursor++];
    if (record is! T) {
      throw ReplayDivergenceException(
        'Effect kind mismatch at ordinal ${record.ordinal}: expected '
        '$type, recorded ${record.runtimeType}.',
        ordinal: record.ordinal,
      );
    }
    return record;
  }
}

/// Thrown when a replay diverges from the recording.
///
/// Catching this exception is the *only* correct response to a
/// divergence — the replay has produced a state that does not match the
/// ledger, and continuing would silently corrupt the caller's
/// understanding of the recording. Phase 5's `DivergenceReport` wraps
/// this with the ledger's `seq` and the before/after state, for the CLI.
class ReplayDivergenceException implements Exception {
  final String message;
  final int? ordinal;

  ReplayDivergenceException(this.message, {this.ordinal});

  @override
  String toString() =>
      'ReplayDivergenceException${ordinal != null ? ' (ordinal $ordinal)' : ''}: '
      '$message';
}
