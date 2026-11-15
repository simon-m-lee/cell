// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// A cognitive handle: a cell wrapped with a policy, a decision log, and
/// an outcome channel.
///
/// ### When to use
/// Add recording to an existing cell, or layer a policy onto a cell that
/// was constructed without one. For pure policy enforcement without
/// recording, use **static mode** — compose the policy into the cell's
/// `testRule` at construction.
///
/// ### How it works
/// 1. **[cell]** is the original, untouched cell. Mutations via
///    `handle.cell` bypass the cognitive layer.
/// 2. **[cognitive]** is a deputy view whose `testRule` chains the
///    principal's rule with the recording rule. Actions applied via
///    `handle.cognitive.apply(...)` and pulses flowing through the view
///    are governed and recorded.
/// 3. **[decisions]** is a `TissueList<Decision>` appended to on every
///    evaluation. Observable via `Cell.observe`.
/// 4. **[outcomes]** is an `IngressHandle<Pulse>` — the channel feeding
///    rewards back to the learning loop (Phase 3).
///
/// ### Non-obvious
/// - **`cognitive` is `Cell`, not `C`.** The deputy view is a generic
///   cell, so `ValueCell.value` / `OpenCell.emit` are not available on
///   it. Use `apply` for mutations on the cognitive view, or static mode
///   when the concrete type matters.
/// - **The original cell is not governed.** Route through
///   `handle.cognitive` for policy enforcement and recording.
/// - **The principal's rule is evaluated twice on the deputy path.**
///   `Cell.deputy` chains `[principalRule, recordingRule]` and the
///   recorder re-runs the principal rule internally for attribution.
///   Correct, pure, and documented overhead.
/// - **Truncation drops the oldest.** At [maxDecisions], adding a new
///   decision removes the oldest first.
///
/// {@category Organ}
/// {@category Runtime}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class CognitiveHandle<C extends Cell> {
  /// The principal cell. Untouched; its behaviour is unchanged.
  final C cell;

  /// The cognitive view — a deputy whose rule composes the principal's
  /// rule, [policy], and the recording rule.
  final Cell cognitive;

  /// The active policy. `TestCell.allowAll` for recording-only handles.
  final Policy policy;

  /// The decision log. Appended to on every evaluation of the composite
  /// rule (both `apply` and pulse-reception paths).
  final TissueList<Decision> decisions;

  /// The outcome channel. Downstream code emits `mind.outcome` pulses
  /// here for the learning loop (Phase 3) to consume.
  final IngressHandle<Pulse> outcomes;

  final void Function() _dispose;
  final int _maxDecisions;
  bool _disposed = false;

  CognitiveHandle._({
    required this.cell,
    required this.cognitive,
    required this.policy,
    required this.decisions,
    required this.outcomes,
    required void Function() dispose,
    required int maxDecisions,
  })  : _dispose = dispose,
        _maxDecisions = maxDecisions;

  /// Records an outcome (reward) for the given [decisionId].
  ///
  /// ### Parameters
  /// * [decisionId] — the id of the decision being rewarded.
  /// * [reward] — positive for good, negative for bad, zero for neutral.
  /// * [metadata] — optional context for the outcome.
  ///
  /// ### Non-obvious
  /// - **The outcome channel is an `IngressHandle<Pulse>`.** Every entry's
  ///   payload *is the outcome pulse itself* (`type: 'mind.outcome'`,
  ///   payload = the reward map). Observers unwrap once:
  ///   `final outcome = p.payload as Pulse;`
  /// - **Does not verify the decision exists.** Unresolved decision ids
  ///   are dropped by the trainer (Phase 3).
  void recordOutcome({
    required String decisionId,
    required double reward,
    Map<String, dynamic>? metadata,
  }) {
    if (_disposed) {
      throw StateError('Cannot record an outcome on a disposed handle.');
    }
    outcomes.emit(
      Pulse<Object>(
        {
          'decisionId': decisionId,
          'reward': reward,
          if (metadata != null) 'metadata': metadata,
        },
        type: 'mind.outcome',
      ),
    );
  }

  /// Marks this handle as disposed.
  ///
  /// ### Non-obvious
  /// - **No-op in 0.2.0.** Reserved for Phase 6 (agent cleanup). The
  ///   decision log and outcome channel remain accessible after disposal;
  ///   observation is unaffected. Only [recordOutcome] is guarded.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _dispose();
  }

  /// Whether this handle has been disposed.
  bool get isDisposed => _disposed;

  /// The configured decision-log cap.
  int get maxDecisions => _maxDecisions;

  // Internal — invoked by _RecordingTestCell.
  void _record(Decision decision) {
    if (_disposed) return;
    if (decisions.length >= _maxDecisions) {
      // Roll the log — drop the oldest. The removal is observable via
      // the TissueList's removal pulse.
      decisions.remove(decisions.first);
    }
    decisions.add(decision);
  }
}

/// Creates a cognitive handle for [cell] with [policy] layered on top.
///
/// ### When to use
/// - **Recording-only**: `cognitive(cell: cell)` — records decisions
///   against the cell's existing rule.
/// - **Policy + recording**:
///   `cognitive(cell: cell, policy: domainPolicy())` — adds policy
///   enforcement alongside recording.
///
/// ### How it works
/// 1. Builds `_RecordingTestCell` wrapping `cell.validate` and [policy].
/// 2. Creates the cognitive view via `cell.deputy(testRule: recorder)` —
///    the public substrate path that shares the principal's container,
///    lock, and context while chaining the principal's rule.
/// 3. Returns a handle with `cell` (original), `cognitive` (view),
///    `decisions` (log), `outcomes` (channel).
///
/// ### Non-obvious
/// - **Both pulses and `apply` are governed.** The cognitive view's
///   receptor validates with the chained rule, and `apply` validates
///   through `validate.action` — one rule, two paths.
/// - **Principal rejections drop upstream.** The deputy chain runs the
///   principal's rule *first*; a principal-rejected pulse or command
///   never reaches the recorder, so it is not logged. The recorder's
///   `principal-rejected` attribution fires when it is used standalone
///   or when the principal rule is consulted inside it directly.
/// - **`maxDecisions` must be positive.** Zero throws [ArgumentError].
/// - **Asynchronous `Cell.deputy()` implementations are unsupported** —
///   the factory is synchronous and fails loudly if the substrate
///   returns a [Future].
///
/// {@category Organ}
/// {@category Runtime}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
CognitiveHandle<C> cognitive<C extends Cell>({
  required C cell,
  Policy policy = TestCell.allowAll,
  VerdictPolicy? verdictPolicy,
  Future<bool> Function(Decision, Verdict)? onDeferred,
  int maxDecisions = 10000,
}) {
  if (maxDecisions <= 0) {
    throw ArgumentError.value(
      maxDecisions,
      'maxDecisions',
      'Must be positive',
    );
  }

  final decisions = TissueList<Decision>();
  final outcomes = Cell.ingress<Pulse>();

  // Late-bound so the recorder can delegate to the handle's guarded
  // `_record` (truncation + disposed check live in one place).
  late final CognitiveHandle<C> handle;
  // Adaptive principal rule: plain cells expose `validate` as a
  // `TestCell` function; cell_organ stems expose a `TestStem` object
  // with the same call contract. Dispatch dynamically so both work.
  // (0.6.1 hotfix — Blend sources previously failed the cast.)
  final hostValidate = cell.validate;
  final principalRule = TestCell<C>((object, {arguments, host, user}) =>
      (hostValidate as dynamic).call(object, host: cell, arguments: arguments)
          as bool);
  final recorder = _RecordingTestCell<C>(
    principalRule: principalRule,
    policy: policy,
    onDecision: (decision) => handle._record(decision),
    cell: cell,
    verdictPolicy: verdictPolicy,
    onDeferred: onDeferred,
  );

  final viewOrFuture = cell.deputy(testRule: recorder);
  if (viewOrFuture is Future<Cell>) {
    throw StateError(
      'cell_mind: cognitive() requires a synchronous Cell.deputy() '
      'implementation; the substrate returned a Future.',
    );
  }

  handle = CognitiveHandle<C>._(
    cell: cell,
    cognitive: viewOrFuture,
    policy: policy,
    decisions: decisions,
    outcomes: outcomes,
    dispose: () {},
    maxDecisions: maxDecisions,
  );
  return handle;
}
