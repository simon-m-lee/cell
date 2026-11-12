// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The boundary between a receptor and the outside world.
///
/// Every observation that is not a function of the receptor's inputs is
/// routed through an [EffectJournal]. On the recording side, the journal
/// captures each observation; on the replay side, it serves the recorded
/// value instead of touching the outside world. The receptor code is
/// identical in both cases — this is what makes replay exact.
///
/// ### Non-obvious: the journal is a *stack*, not a singleton
///
/// An outer transaction might record an effect, while an inner evaluation
/// (e.g. a what-if branch) needs to be replayed from a different journal
/// without disturbing the outer recording. `JournalScope` keeps a stack;
/// `EffectJournal.current` returns the top of the stack. The stack is
/// task-local (see `JournalScope`) — a `Future` spawned outside the
/// scope does *not* inherit the journal, which is deliberate: a spawned
/// task whose effects are not journalled is a bug we want to surface, not
/// hide.
abstract class EffectJournal {
  /// The journal currently in scope, or [NullJournal.instance] if none is
  /// pushed.
  ///
  /// **Effectful receptors that call this without a journal in scope
  /// will receive `NullJournal` and fail loudly on the first effect.**
  /// That is the contract; do not catch the failure.
  static EffectJournal get current => JournalScope.current;

  /// The number of effects consumed so far. On the recording side, this
  /// is the number of effects written. On the replay side, it is the
  /// number consumed from the log. [ReplayEngine] compares these.
  int get consumed;

  /// Record (or replay) a clock read.
  DateTime clock();

  /// Record (or replay) a UUID generation.
  String uuid();

  /// Record (or replay) an arbitrary I/O call. [rawOutput] is the value
  /// the caller's `run` closure returned; the journal records it (or
  /// serves the recorded value). If [serializeOutput] is not supplied, the
  /// raw result of `run` is stored directly and must be JSON-encodable —
  /// non-encodable results throw loudly at the fingerprint boundary.
  ///
  /// The [run] closure is **not** invoked on the replay side; the recorded
  /// output is returned directly. This is the mechanism by which replay
  /// avoids touching the network.
  Future<T> io<T>({
    required String label,
    required Object? input,
    required Future<T> Function() run,
    Object? Function(T)? serializeOutput,
  });

  /// Record (or replay) a timer firing. [duration] is the scheduled
  /// window; the journal records both the schedule and the fire time so
  /// that replay reproduces the same interleaving.
  ///
  /// The [onFire] callback is invoked by the journal at the appropriate
  /// moment. On the recording side, the actual `Timer` is scheduled and
  /// the callback is called when it fires. On the replay side, the
  /// callback is called in journal order, not against a real timer. This
  /// is what makes `debounce`/`throttle` replayable.
  Future<void> timer({
    required Duration duration,
    required Object? input,
    required FutureOr<void> Function() onFire,
  });

  /// Push this journal onto the stack. Must be paired with [pop].
  /// Called by `JournalScope.push`.
  void push();

  /// Pop this journal from the stack.
  void pop();

  /// Assert that the journal has been fully consumed (replay side) or
  /// that no pending un-journalled work remains (recording side). Phase 5
  /// calls this after each pulse.
  void assertExhausted();

  /// Canonical JSON of every recorded effect, in order.
  List<Map<String, Object?>> toJson();
}

/// The "no journal in scope" sentinel. Every effectful operation fails
/// loudly.
///
/// Deliberately not a no-op. A "null" journal that silently dropped
/// effects would make every effectful cell non-replayable *without* any
/// warning, which is precisely the failure mode the plan forbids (D3).
class NullJournal implements EffectJournal {
  /// Singleton.
  static const instance = NullJournal._();
  const NullJournal._();

  @override
  int get consumed => 0;

  @override
  DateTime clock() => _no('clock');

  @override
  String uuid() => _no('uuid');

  @override
  Future<T> io<T>({
    required String label,
    required Object? input,
    required Future<T> Function() run,
    Object? Function(T)? serializeOutput,
  }) =>
      _no('io($label)');

  @override
  Future<void> timer({
    required Duration duration,
    required Object? input,
    required FutureOr<void> Function() onFire,
  }) =>
      _no('timer(${duration.inMilliseconds}ms)');

  Never _no(String what) {
    throw StateError(
      'EffectJournal: operation "$what" was attempted with no journal in '
      'scope. This receptor (or test rule) is declared effectful, so it '
      'can only be used from inside a replayable path '
      '(CellGraph + JournalScope). To use this cell in a non-replayable '
      'context, override its purity to Purity.pure (if it is genuinely '
      'pure) or wrap the entry point in '
      'JournalScope.run(RecordingJournal(), () => ...).',
    );
  }

  @override
  void push() {}

  @override
  void pop() {}

  @override
  void assertExhausted() {}

  @override
  List<Map<String, Object?>> toJson() => const [];
}
