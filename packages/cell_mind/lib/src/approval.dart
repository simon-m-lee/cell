// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

// Approval effect labels (journaled via journal.io):
const _approvalSubmittedLabel = 'mind.approval.submitted';
const _approvalDecidedLabel = 'mind.approval.decided';
const _approvalExpiredLabel = 'mind.approval.expired';
const _approvalDisposedLabel = 'mind.approval.disposed';

/// A pending approval request. Carries the full decision for audit.
///
/// ### When to use
/// Read from [ApprovalQueue.pending]; serialized for audit records.
///
/// ### How it works
/// An immutable record: the decision that deferred, the `Defer`
/// verdict, the request timestamp, and the attempt counter.
///
/// ### Non-obvious
/// - **`attempts` counts TTL sweeps**, not user decisions.
/// - **Serialization round-trips** via `toMap` / `fromMap`.
///
/// ### See also
/// - [ApprovalQueue], [approvalResolver],
///   `guide/05-Approval.md`.
///
/// ## AI Agent Guide
/// - Never await [ApprovalQueue.submit] before deciding — the
///   future resolves only when a human acts.
///
/// {@category Organ}
/// {@category Approval}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class ApprovalRequest<T> {
  /// The request identifier (`Identity.next()`).
  final String id;

  /// The decision that triggered the `Defer`.
  final Decision decision;

  /// The specific `Defer` verdict.
  final Defer verdict;

  /// When the request was submitted.
  final DateTime requestedAt;

  /// Retry count (always 1 in 0.4.0; reserved for Phase 6).
  final int attempts;

  const ApprovalRequest({
    required this.id,
    required this.decision,
    required this.verdict,
    required this.requestedAt,
    this.attempts = 1,
  });

  /// The value being approved — the deferred pulse's payload when it
  /// is a `T`; `null` otherwise (command decisions carry no
  /// pre-execution payload).
  T? get value =>
      decision.pulse?.payload is T ? decision.pulse!.payload as T : null;

  /// Serializes the request for the audit trail.
  Map<String, dynamic> toMap() => {
        'id': id,
        'decision': decision.toMap(),
        'verdict': verdict.toMap(),
        'requestedAt': requestedAt.toUtc().toIso8601String(),
        'attempts': attempts,
      };

  /// Reconstructs the request shell from [ApprovalRequest.toMap]
  /// output (the decision's live objects are lossy per `Decision`).
  static ApprovalRequest<T> fromMap<T>(Map<String, dynamic> map) =>
      ApprovalRequest<T>(
        id: map['id'] as String,
        decision: Decision.fromMap(map['decision'] as Map<String, dynamic>),
        verdict:
            verdictFromMap(map['verdict'] as Map<String, dynamic>) as Defer,
        requestedAt: DateTime.parse(map['requestedAt'] as String),
        attempts: map['attempts'] as int? ?? 1,
      );

  @override
  String toString() => 'ApprovalRequest($id, ${verdict.resolver})';
}

/// A `Defer` resolver that queues decisions for human approval.
///
/// ### When to use
/// Use when a `Defer` verdict requires asynchronous human resolution —
/// financial approvals, compliance reviews, or any "are you sure?"
/// workflow that must leave an audit trail.
///
/// ### How it works
/// 1. [submit] adds the decision to [pending] and returns a
///    `Future<bool>` that resolves when decided.
/// 2. [approve] / [reject] stage the mutation via `Cell.txApply`,
///    removing from [pending] and committing to [committed] as one
///    atomic unit.
/// 3. A periodic sweeper expires requests older than [ttl], resolving
///    their futures with `false`.
/// 4. Every action is journaled (`mind.approval.*` effects).
///
/// ### Non-obvious
/// - **`committed` is a `ValueCell<T?>`.** Required so `Cell.txApply`
///   can stage and roll back the commit (verified on the live
///   substrate: both `TissueMap.apply(tx:)` and
///   `ValueCell.apply(tx:)` stage correctly).
/// - **`approve()` is atomic.** Either the pending removal AND the
///   commit both succeed, or neither does.
/// - **`dispose()` is destructive.** Pending futures resolve `false`
///   and further submissions throw.
///
/// ### See also
/// - [ApprovalRequest], [approvalResolver],
///   `guide/05-Approval.md`.
///
/// ## AI Agent Guide
/// - Deferred pulses are dropped from the wave; deliver through
///   [ApprovalQueue.committed], never by re-injection.
///
/// {@category Organ}
/// {@category Approval}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class ApprovalQueue<T> {
  /// Pending requests, keyed by request id.
  final TissueMap<String, ApprovalRequest<T>> pending;

  /// The committed value stream. Observers see approved values.
  final ValueCell<T?> committed;

  /// The effect journal. Required — approval is effectful.
  final EffectJournal journal;

  /// Maximum request age before automatic rejection.
  final Duration ttl;

  /// Maximum pending queue size; submissions beyond this throw.
  final int maxPending;

  final Map<String, Completer<bool>> _completers = {};
  bool _disposed = false;
  bool _sweepScheduled = false;
  Timer? _sweeperTimer;

  /// Creates an approval queue.
  ApprovalQueue({
    required this.journal,
    this.ttl = const Duration(minutes: 5),
    this.maxPending = 100,
    TissueMap<String, ApprovalRequest<T>>? pending,
    ValueCell<T?>? committed,
  })  : pending = pending ?? TissueMap<String, ApprovalRequest<T>>(),
        committed = committed ?? Cell.state<T?>(initial: null).cell {
    if (maxPending <= 0) {
      throw ArgumentError.value(maxPending, 'maxPending', 'Must be positive');
    }
    if (ttl <= Duration.zero) {
      throw ArgumentError.value(ttl, 'ttl', 'Must be positive');
    }
  }

  /// The sweeper cadence: fires often enough that expirations are not
  /// delayed by more than 25% of the TTL.
  Duration get sweepInterval => ttl ~/ 4;

  /// Submits a deferred [decision] for approval.
  ///
  /// Returns `true` when approved, `false` when rejected or expired.
  ///
  /// ### Throws
  /// - [ArgumentError] if `decision.verdict` is not a [Defer].
  /// - [StateError] if `pending.length >= maxPending`.
  /// - [StateError] if the queue has been disposed.
  Future<bool> submit(Decision decision) async {
    if (_disposed) {
      throw StateError('Cannot submit to a disposed approval queue.');
    }
    final verdict = decision.verdict;
    if (verdict is! Defer) {
      throw ArgumentError.value(
        decision.verdict,
        'decision.verdict',
        'ApprovalQueue only resolves Defer verdicts',
      );
    }
    if (pending.length >= maxPending) {
      throw StateError(
        'Approval queue capacity reached ($maxPending); submission '
        'rejected.',
      );
    }

    final request = ApprovalRequest<T>(
      id: Identity.next(),
      decision: decision,
      verdict: verdict,
      requestedAt: journal.clock(),
    );
    final outcome = await pending.apply<void>((
      function: pending.put,
      arguments: (
        positionalArguments: [request.id, request],
        namedArguments: null,
      ),
      compensation: null,
    ));
    if (outcome is! ApplyAccepted<void>) {
      return false;
    }
    if (_disposed) {
      // Disposed while the gated apply was in flight — nothing can
      // ever resolve this request. Fail closed without a leak.
      return false;
    }
    await _recordEffect(_approvalSubmittedLabel, {
      'requestId': request.id,
      'decisionId': decision.id,
      'resolver': verdict.resolver,
    });
    final completer = Completer<bool>();
    _completers[request.id] = completer;
    _scheduleSweep();
    return completer.future;
  }

  /// Approves a pending request.
  ///
  /// ### Returns
  /// `true` if the request was found and committed; `false` otherwise
  /// (already decided, expired, or unknown id).
  Future<bool> approve(String requestId) => _decide(
        requestId,
        accept: true,
        reason: null,
      );

  /// Rejects a pending request.
  ///
  /// ### Returns
  /// `true` if the request was found and removed; `false` otherwise.
  Future<bool> reject(String requestId, String reason) => _decide(
        requestId,
        accept: false,
        reason: reason,
      );

  Future<bool> _decide(
    String requestId, {
    required bool accept,
    required String? reason,
  }) async {
    if (_disposed) return false;
    final request = pending[requestId];
    if (request == null) return false;

    final tx = Cell.txApply();
    try {
      await tx.execute(
        participants: [pending, committed],
        body: (scope) {
          pending.apply<void>(
            (
              function: pending.remove,
              arguments: (
                positionalArguments: [requestId],
                namedArguments: null,
              ),
              compensation: null,
            ),
            tx: scope,
          );
          committed.apply<void>(
            (
              function: (T? value) {
                committed.value = value;
              },
              arguments: (
                positionalArguments: [accept ? request.value : null],
                namedArguments: null,
              ),
              compensation: null,
            ),
            tx: scope,
          );
        },
      );
    } on Exception {
      // The staged mutations roll back atomically; the request stays
      // pending.
      return false;
    }

    final completer = _completers.remove(requestId);
    completer?.complete(accept);
    await _recordEffect(_approvalDecidedLabel, {
      'requestId': requestId,
      'decisionId': request.decision.id,
      'decision': accept ? 'approved' : 'rejected',
      'reason': reason,
    });
    return true;
  }

  /// Disposes the queue: cancels the sweeper and completes all pending
  /// futures with `false`.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sweeperTimer?.cancel();
    _sweeperTimer = null;
    _sweepScheduled = false;
    for (final completer in _completers.values) {
      if (!completer.isCompleted) completer.complete(false);
    }
    _completers.clear();
    await _recordEffect(_approvalDisposedLabel, {
      'pending': pending.length,
    });
  }

  /// Whether the queue has been disposed.
  bool get isDisposed => _disposed;

  void _scheduleSweep() {
    if (_disposed || _sweepScheduled) return;
    _sweepScheduled = true;
    // A cancellable `dart:async` Timer, not `journal.timer`: the
    // journal's timer future cannot be cancelled and a long-TTL queue
    // would keep the isolate alive forever. Sweeps and expirations
    // are still journaled explicitly (`mind.approval.expired`), so the
    // timeline is reconstructible from the ledger.
    _sweeperTimer = Timer(sweepInterval, () async {
      _sweepScheduled = false;
      _sweeperTimer = null;
      await _sweep();
      if (!_disposed && pending.isNotEmpty) _scheduleSweep();
    });
  }

  Future<void> _sweep() async {
    if (_disposed) return;
    final now = journal.clock();
    final expiredIds = <String>[];
    for (final entry in pending.entries) {
      if (now.difference(entry.value.requestedAt) >= ttl) {
        expiredIds.add(entry.key);
      }
    }
    for (final id in expiredIds) {
      await pending.apply<void>((
        function: pending.remove,
        arguments: (positionalArguments: [id], namedArguments: null),
        compensation: null,
      ));
      final completer = _completers.remove(id);
      completer?.complete(false);
      await _recordEffect(_approvalExpiredLabel, {'requestId': id});
    }
  }

  Future<void> _recordEffect(String label, Map<String, dynamic> data) async {
    await journal.io<Object?>(
      label: label,
      input: data,
      run: () async => null,
      serializeOutput: (_) => data,
    );
  }
}

/// Creates a `Defer` resolver that routes to [queue].
///
/// ### Parameters
/// * [queue] — the approval queue.
/// * [resolverName] — the name to match (`'approval'` by default).
///
/// ### When to use
/// Wire as `cognitive(onDeferred:)` so `Defer('approval')` verdicts
/// land in [ApprovalQueue] for human decision.
///
/// ### How it works
/// Matches the verdict resolver name; unmatched verdicts return
/// `false` (the recorder then records `defer-no-resolver`).
///
/// ### Non-obvious
/// - **The resolver's `true` means handled**, not approved — the
///   human decision arrives later through the queue.
/// - **`resolverName` distinguishes queues** when several approval
///   flows share one handle.
///
/// ### See also
/// - [ApprovalQueue], [ApprovalRequest],
///   `guide/05-Approval.md`.
///
/// ## AI Agent Guide
/// - Return `false` for verdicts this resolver does not own.
///
/// ### Usage
/// ```dart
/// final handle = cognitive(
///   cell: cell,
///   verdictPolicy: learnedVerdictPolicy(),
///   onDeferred: approvalResolver(queue),
/// );
/// ```
///
/// {@category Organ}
/// {@category Approval}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Future<bool> Function(Decision, Verdict) approvalResolver(
  ApprovalQueue queue, {
  String resolverName = 'approval',
}) {
  return (decision, verdict) async {
    if (verdict is! Defer) return false;
    if (verdict.resolver != resolverName) return false;
    return await queue.submit(decision);
  };
}
