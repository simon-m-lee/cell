// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell.dart';

// ─────────────────────────────────────────────────────────────
// factory - txApply (atomic multi-apply + compensation)
// ─────────────────────────────────────────────────────────────

// ── Events ───────────────────────────────────────────────────

/// Base class for all lifecycle events emitted by an [ApplyTransactionScope].
///
/// Consumers subscribe by supplying [TxApplyOptions.onEvent]. Events are
/// **informational**: they describe what happened but do not influence
/// control flow. They are useful for logging, monitoring, distributed
/// tracing, and forensic reconstruction of a transaction.
///
/// ### When to use
/// Observe a transaction's lifecycle without altering its semantics.
///
/// ### How it works
/// An event is fired at each meaningful phase transition:
/// * [TxApplyBegun] — once, when [ApplyTransactionScope.begin] completes.
/// * [TxApplyStaged] — once per successful [ApplyTransactionScope.enqueueCommand].
/// * [TxApplyRejected] — when a command is refused (at staging time or at
///   commit time — see [TxApplyRejected]).
/// * [TxApplyCompensationFailed] / [TxApplyCompensationRetry] — during
///   compensation.
/// * [TxApplyRolledBack] — when a rollback (full or savepoint-scoped)
///   completes.
/// * [TxApplyCommitted] — on a successful [ApplyTransactionScope.commit].
///
sealed class TxApplyEvent {
  const TxApplyEvent();
}

/// Emitted once, immediately after [ApplyTransactionScope.begin] succeeds.
///
/// Carries the resolved participant set — the cells allowed to receive
/// commands or compensations in this scope.
class TxApplyBegun extends TxApplyEvent {
  /// The participant cells, in the order they were passed to `begin`.
  final List<Cell> participants;
  const TxApplyBegun(this.participants);
}

/// Emitted once per successful [ApplyTransactionScope.enqueueCommand].
///
/// This fires at **staging time**, not at commit time. It signals that the
/// command was accepted into the queue — not that it has been executed.
class TxApplyStaged extends TxApplyEvent {
  /// The cell that will receive the staged command.
  final Cell cell;

  /// The function the staged command will invoke.
  final Function function;
  const TxApplyStaged(this.cell, this.function);
}

/// Emitted after a successful [ApplyTransactionScope.commit].
///
/// The `callCount` is captured **before** the staging buffer is cleared, so
/// it reflects the number of commands attempted in the committed batch.
class TxApplyCommitted extends TxApplyEvent {
  /// The number of commands that were in the committed batch.
  final int callCount;
  const TxApplyCommitted(this.callCount);
}

/// Emitted after a rollback (full or savepoint-scoped).
///
/// When [savepoint] is non-null, the rollback was partial — commands before
/// the savepoint remain staged and may still be committed.
class TxApplyRolledBack extends TxApplyEvent {
  /// The opaque savepoint the rollback targeted, or `null` for a full rollback.
  final Object? savepoint;
  const TxApplyRolledBack([this.savepoint]);
}

/// Emitted when a staged command is refused.
///
/// This event can fire at **two distinct points**:
/// 1. During [ApplyTransactionScope.enqueueCommand] — if the function is not
///    in the cell's `modifiable` set, or a compensation target is not a
///    participant. In this case the call **throws** [TxApplyException]
///    immediately after emitting this event.
/// 2. During [ApplyTransactionScope.commit] — if a staged command's function
///    was removed from `modifiable` between staging and commit, or if the
///    command's function returns an [ApplyVeto] at execution time.
///
/// `reason` is a human-readable string in the current implementation, but it
/// is typed as [Object] to allow richer diagnostic payloads in future
/// versions. Consumers should not assume a specific type.
class TxApplyRejected extends TxApplyEvent {
  /// The cell whose staged command was refused.
  final Cell cell;

  /// The reason for the rejection. Currently a `String`; treat as opaque.
  final Object reason;
  const TxApplyRejected(this.cell, this.reason);
}

/// Emitted each time a compensation attempt fails.
///
/// One event is emitted **per failed compensation**, after retries have been
/// exhausted for that command. Compensations run in reverse-staging order,
/// so events may arrive interleaved with subsequent compensation attempts.
class TxApplyCompensationFailed extends TxApplyEvent {
  /// Details of the failed compensation.
  final CompensationFailure failure;
  const TxApplyCompensationFailed(this.failure);
}

/// Emitted before each retry of a compensation function.
///
/// Fires between attempts — not after the final failed attempt (that
/// produces [TxApplyCompensationFailed] instead).
class TxApplyCompensationRetry extends TxApplyEvent {
  /// The cell whose compensation is being retried.
  final Cell cell;

  /// The 1-based attempt number that just failed.
  final int attempt;

  /// The total number of attempts configured for this compensation.
  final int maxAttempts;

  /// The error that caused the retry.
  final Object error;
  const TxApplyCompensationRetry({
    required this.cell,
    required this.attempt,
    required this.maxAttempts,
    required this.error,
  });
}

// ── Errors ───────────────────────────────────────────────────

/// Describes a single failed compensation attempt.
///
/// Aggregated by [TxApplyCompensationException] when the compensation policy
/// allows failures to accumulate. Each instance captures enough forensic
/// information to reproduce or diagnose the failure.
class CompensationFailure {
  /// The cell on which the compensation was attempted.
  final Cell cell;

  /// The compensation function, if the failure could be attributed to one.
  final Function? function;

  /// The error raised by the compensation attempt.
  final Object error;

  /// Optional stack trace captured at the failure site.
  final StackTrace? stackTrace;

  const CompensationFailure({
    required this.cell,
    required this.error,
    this.function,
    this.stackTrace,
  });

  @override
  String toString() => 'CompensationFailure(cell=$cell, error=$error)';
}

/// Raised for **control-flow** problems in a [ApplyTransactionScope]: wrong
/// phase (e.g. `commit` before `begin`), non-modifiable function, non-
/// participant cell, or a rejected command at commit time.
///
/// This is distinct from [TxApplyCompensationException], which describes a
/// failure of the **rollback path** rather than the forward path.
class TxApplyException implements Exception {
  /// A human-readable description of the failure.
  final String message;

  /// Optional underlying cause, typically the original error that triggered
  /// the abort.
  final Object? cause;
  TxApplyException(this.message, [this.cause]);
  @override
  String toString() => 'TxApplyException: $message';
}

/// Raised when one or more compensations fail under
/// [CompensationErrorPolicy.collectThenThrow] or
/// [CompensationErrorPolicy.failFast].
///
/// The transaction is **already in an unrecoverable state** when this is
/// thrown: the forward path failed, and some compensations that should have
/// reversed earlier effects also failed. Callers must escalate (alert,
/// manual reconciliation), not retry the transaction blindly.
class TxApplyCompensationException implements Exception {
  /// Human-readable description of the compensation failure batch.
  final String message;

  /// All compensations that failed, in the order they were attempted
  /// (reverse-staging order).
  final List<CompensationFailure> failures;

  /// Optional underlying cause — the error that triggered the rollback in
  /// the first place (as opposed to the compensation failures themselves).
  final Object? cause;

  TxApplyCompensationException(
    this.message,
    this.failures, [
    this.cause,
  ]);

  @override
  String toString() =>
      'TxApplyCompensationException: $message (${failures.length} failure(s))';
}

// ── Policy ───────────────────────────────────────────────────

/// Determines how the transaction scope behaves when a compensation attempt
/// fails.
///
/// The policy only governs the **rollback path**. Forward-path failures
/// (command execution errors) always trigger compensation regardless of this
/// value.
enum CompensationErrorPolicy {
  /// Continue attempting the remaining compensations, collect all failures,
  /// and **return normally**. The transaction's [ApplyTransactionScope.commit]
  /// will subsequently throw the *forward-path* error, not the compensation
  /// error — the compensation failures are emitted as events but discarded
  /// from the thrown exception.
  ///
  /// Use when compensation failures are low-stakes and must not mask the
  /// original forward-path error.
  bestEffort,

  /// Abort the compensation loop on the **first** compensation failure.
  ///
  /// A [TxApplyCompensationException] is thrown immediately with the failures
  /// collected so far. Remaining compensations are **not attempted** —
  /// earlier effects may remain un-reverted. Use when a compensation failure
  /// is so severe that continued attempts risk cascading damage.
  failFast,

  /// Attempt all compensations, collect every failure, and **throw**
  /// [TxApplyCompensationException] at the end if any failed.
  ///
  /// The original forward-path error becomes the `cause` of the compensation
  /// exception, so the caller sees both the trigger and the leftover damage.
  /// Use in financial or invariant-critical systems where the operator must
  /// be notified that state may be inconsistent.
  collectThenThrow,
}

/// Configuration for [Cell.txApply].
///
/// All fields are optional; the default configuration is safe for most
/// ordinary use cases (single-attempt compensation, best-effort error
/// handling, fail-fast on the first forward-path rejection).
class TxApplyOptions {
  /// Called for each lifecycle event — see [TxApplyEvent].
  ///
  /// Handlers run synchronously inside the transaction scope. Keep them
  /// cheap. An exception here aborts the transaction at the point of
  /// emission.
  final void Function(TxApplyEvent event)? onEvent;

  /// If `true` (default), a forward-path rejection or veto stops the commit
  /// loop and triggers compensation of previously-executed commands.
  ///
  /// If `false`, rejections are **logged via [TxApplyRejected] but not
  /// treated as failures** — commit continues to the next staged command.
  /// Use with care: this defeats the atomicity contract.
  final bool stopOnFirstFailure;

  /// **Reserved for future use.**
  ///
  /// Currently has no effect on the transaction scope's behaviour. It exists
  /// so API consumers can pass a comparator through to the eventual
  /// commit-ordering implementation without a breaking change.
  final int Function(Cell a, Cell b)? comparator;

  /// If `true`, compensation functions are invoked for staged commands that
  /// were **not** executed — i.e., commands after the failure point.
  ///
  /// Defaults to `false`. Enable only when a command's *staging* itself has
  /// observable side effects (rare). The default matches the intuition that
  /// "not executed" ⇒ "no effect to reverse".
  final bool compensateIfNotExecuted;

  /// How to handle compensation failures. See [CompensationErrorPolicy].
  final CompensationErrorPolicy compensationErrorPolicy;

  /// Optional hook receiving the complete list of compensation failures.
  ///
  /// Called before [TxApplyCompensationException] is thrown (for policies
  /// that throw), or before `commit` returns (for [CompensationErrorPolicy.bestEffort]). Use for
  /// alerting and persistence.
  final void Function(List<CompensationFailure> failures)?
      onCompensationFailures;

  /// Maximum attempts per compensation, including the initial attempt.
  ///
  /// Values `< 1` are clamped to `1`. Default `1` disables retries — the
  /// most predictable behaviour for callers who do not opt in.
  final int compensationMaxAttempts;

  /// Delay strategy between compensation attempts.
  ///
  /// Receives the 1-based number of the attempt that just failed. When
  /// `null`, [_defaultCompensationBackoff] is used (exponential with cap).
  final Duration Function(int attempt)? compensationBackoff;

  /// Predicate deciding whether a compensation error is retryable.
  ///
  /// When `null`, [_defaultIsRetryableCompensationError] is used — a
  /// heuristic that treats framework exceptions and [ArgumentError] as
  /// non-retryable.
  final bool Function(Object error)? isRetryableCompensationError;

  const TxApplyOptions({
    this.onEvent,
    this.stopOnFirstFailure = true,
    this.comparator,
    this.compensateIfNotExecuted = false,
    this.compensationErrorPolicy = CompensationErrorPolicy.bestEffort,
    this.onCompensationFailures,
    this.compensationMaxAttempts = 1,
    this.compensationBackoff,
    this.isRetryableCompensationError,
  });
}

/// Default compensation backoff: exponential in the attempt number, capped
/// at 2^5 = 32× the base unit (so the longest delay is 20 ms × 32 = 640 ms).
///
/// Attempt 1 → 20 ms, 2 → 40 ms, 3 → 80 ms, ... 6 → 640 ms, ≥7 → 640 ms.
Duration _defaultCompensationBackoff(int attempt) {
  final ms = 20 * (1 << (attempt - 1).clamp(0, 5));
  return Duration(milliseconds: ms);
}

/// Default retryability heuristic for compensation errors.
///
/// Framework-level control-flow errors (wrong phase, not in `modifiable`,
/// explicit rejection) and [ArgumentError]s are **not** retried — repeating
/// them cannot change their outcome. All other errors are treated as
/// transient and retried subject to [TxApplyOptions.compensationMaxAttempts].
bool _defaultIsRetryableCompensationError(Object error) {
  if (error is TxApplyException) {
    final m = error.message;
    if (m.contains('not in modifiable')) return false;
    if (m.contains('ApplyRejected')) return false;
  }
  if (error is ArgumentError) return false;
  return true;
}

/// Classifies an [ApplyOutcome] as "rejected" for the purpose of transaction
/// control flow.
///
/// Two cases count as rejections:
/// * [ApplyRejected] — the integrity gate refused the command.
/// * [ApplyAccepted] whose `result` is [ApplyVeto.instance] — the function
///   itself decided to abort.
///
/// `ApplyStaged` cannot occur here: the transaction scope calls `apply`
/// **without** a `tx`, so the result is always `Accepted` or `Rejected`.
bool _isApplyRejected(dynamic result) =>
    result is ApplyRejected ||
    (result is ApplyAccepted && identical(result.result, ApplyVeto.instance));

// ── Staging ──────────────────────────────────────────────────

/// A single queued command within a transaction, tracked through its
/// lifecycle.
///
/// The `executed` flag drives compensation selection: only commands that
/// were actually invoked are compensated by default (see
/// [TxApplyOptions.compensateIfNotExecuted]). It is set to `true` **before**
/// the command is invoked so that a throwing command — whose partial side
/// effects may already be visible — still triggers its compensation.
class _StagedApply {
  /// The participant cell receiving the command.
  final Cell cell;

  /// The command to execute.
  final ApplyCommand command;

  /// Whether the command's forward path was (or was about to be) invoked.
  ///
  /// Set `true` pre-invocation, cleared on successful compensation.
  bool executed = false;

  _StagedApply({required this.cell, required this.command});

  /// The command's compensation blueprint, or `null` if none was declared.
  ApplyCompensation? get compensation => command.compensation;

  /// The cell on which compensation will run.
  ///
  /// Returns `null` when there is no compensation. When a compensation exists
  /// without an explicit `cell`, defaults to the command's own [cell].
  Cell? get compensateCell => command.compensation == null
      ? null
      : (command.compensation!.cell ?? cell);

  /// Whether this staged call carries a compensation blueprint.
  bool get hasCompensation => command.compensation != null;
}

/// Opaque savepoint returned by [ApplyTransactionScope.savepoint].
///
/// Ties a buffer offset to a specific scope so that a savepoint from another
/// scope cannot be passed to [ApplyTransactionScope.rollback] by mistake —
/// such misuse is rejected with [ArgumentError] rather than silently
/// triggering a full rollback.
class _TxSavepoint {
  /// The scope that issued this savepoint. Used to validate cross-scope
  /// misuse at rollback time.
  final int scopeId;

  /// The buffer offset at the moment the savepoint was created.
  final int index;
  const _TxSavepoint(this.scopeId, this.index);
}

// ── Scope API ────────────────────────────────────────────────

/// Handle for a **staged command transaction** — the mechanism behind
/// [Cell.txApply].
///
/// ### When to use
/// Use `txApply` when you need to execute multiple `Cell.apply` commands
/// atomically, with the ability to **compensate** already-executed commands
/// if a later command fails. This is the Saga-style counterpart to
/// `Cell.transaction` (which buffers **value** updates and provides
/// isolation levels).
///
/// ### How it works
/// 1. [begin] registers participant cells.
/// 2. Commands are staged via [enqueueCommand] (indirectly, through
///    `Cell.apply(command, tx: scope)`).
/// 3. [commit] validates each command's whitelist status, then executes
///    them sequentially. On any failure, executed commands are compensated
///    in reverse order.
/// 4. [rollback] discards the staging buffer, optionally compensating
///    already-executed commands. With a savepoint, only commands after the
///    savepoint are affected and the scope remains active.
///
abstract class ApplyTransactionScope {
  /// Activates the transaction for the given [participants].
  ///
  /// ### Throws
  /// * [TxApplyException] if already begun.
  /// * [ArgumentError] if [participants] is empty.
  Future<void> begin(Iterable<Cell> participants);

  /// Stages a first-class [ApplyCommand] for atomic execution at commit time.
  ///
  /// The staged position of the command within the transaction is returned
  /// as its **transaction sequence** for forensic receipts.
  ///
  /// ### Throws
  /// * [TxApplyException] if the transaction has not begun, has finished,
  ///   [cell] is not a participant, the command's function is not in
  ///   `cell.modifiable`, or the compensation target violates the same
  ///   constraints.
  int enqueueCommand(Cell cell, ApplyCommand command);

  /// Executes every staged command atomically, compensating on failure.
  ///
  /// ### Throws
  /// * [TxApplyException] if not begun, a function is no longer in
  ///   `modifiable` at commit time, a command was rejected, or a command
  ///   threw.
  /// * [TxApplyCompensationException] if compensations failed under
  ///   [CompensationErrorPolicy.collectThenThrow] or
  ///   [CompensationErrorPolicy.failFast].
  Future<void> commit();

  /// Discards staged calls, optionally rolling back only to an earlier
  /// [savepoint].
  ///
  /// ### How it works
  /// - With a `savepoint`, compensates and discards the staged calls after
  ///   that point. The transaction remains active.
  /// - Without a `savepoint`, compensates and discards all staged calls and
  ///   finishes the transaction.
  ///
  /// ### Throws
  /// - [ArgumentError] if the savepoint was not returned by [savepoint] on
  ///   this scope.
  Future<void> rollback({Object? savepoint});

  /// Captures the current buffer position as a rollback target.
  ///
  /// The returned object is opaque and must be passed to [rollback] on the
  /// **same** scope. Passing it to another scope raises [ArgumentError].
  Object savepoint();

  /// Runs [body] between [begin] and [commit], rolling back on any error.
  ///
  /// Convenience wrapper for the common begin/body/commit pattern. If [body]
  /// throws, the scope is rolled back before the error propagates. If
  /// [commit] itself throws, the scope is already finished and is **not**
  /// rolled back again.
  Future<void> execute({
    required Iterable<Cell> participants,
    required void Function(ApplyTransactionScope tx) body,
  });
}

// ── Implementation ───────────────────────────────────────────

/// Default implementation of [ApplyTransactionScope].
///
/// Serialises command staging and commit, and drives the compensation loop
/// on failure. Not designed for reuse: construct a new scope per logical
/// transaction.
class _ApplyTransactionScopeImpl extends ApplyTransactionScope {
  _ApplyTransactionScopeImpl(this.options);

  /// Monotonic id generator used to distinguish savepoints issued by
  /// different scopes. Incremented once per scope construction.
  static int _nextScopeId = 0;
  final int _scopeId = _nextScopeId++;
  final TxApplyOptions options;
  final List<_StagedApply> _staged = <_StagedApply>[];
  final Set<Cell> _participants = <Cell>{};
  bool _begun = false;
  bool _finished = false;

  void _event(TxApplyEvent e) => options.onEvent?.call(e);

  /// Asserts the scope is in an open state (begun and not finished).
  ///
  /// Called at the top of every state-mutating public method.
  void _ensureOpen() {
    if (!_begun) throw TxApplyException('txApply not begun');
    if (_finished) throw TxApplyException('txApply already finished');
  }

  @override
  Future<void> begin(Iterable<Cell> participants) async {
    if (_begun) throw TxApplyException('txApply already begun');
    _participants
      ..clear()
      ..addAll(participants);
    if (_participants.isEmpty) {
      throw ArgumentError('txApply requires at least one participant');
    }
    _begun = true;
    _finished = false;
    _staged.clear();
    _event(TxApplyBegun(_participants.toList(growable: false)));
  }

  @override
  int enqueueCommand(Cell cell, ApplyCommand command) {
    _ensureOpen();
    if (!_participants.contains(cell)) {
      throw TxApplyException(
        'cell is not a participant of this txApply scope',
      );
    }
    // One capability model, shared with direct `Cell.apply`: authorization
    // is decided by the cell's integrity gate (`validate.action`) at commit
    // time — not by whitelist membership at enqueue time. The whitelist
    // would reject every caller-supplied function (a fresh tear-off set is
    // never identity-equal to it), which transactions would then reject
    // while direct apply ran freely.
    final compensation = command.compensation;
    if (compensation != null) {
      final cCell = compensation.cell ?? cell;
      if (!_participants.contains(cCell)) {
        throw TxApplyException('compensate cell is not a participant');
      }
    }

    _staged.add(_StagedApply(cell: cell, command: command));
    _event(TxApplyStaged(cell, command.function));
    return _staged.length - 1;
  }

  @override
  Object savepoint() {
    _ensureOpen();
    return _TxSavepoint(_scopeId, _staged.length);
  }

  /// Executes a single compensation, applying retry and backoff according to
  /// [TxApplyOptions].
  ///
  /// On success, clears `call.executed` so the same command is not
  /// compensated twice by a subsequent rollback pass.
  ///
  /// Rethrows the final error if all attempts fail.
  Future<void> _executeCompensation(_StagedApply call) async {
    final compensation = call.compensation!;
    final cCell = call.compensateCell!;
    final cFn = compensation.function;
    final max = options.compensationMaxAttempts < 1
        ? 1
        : options.compensationMaxAttempts;
    final isRetryable = options.isRetryableCompensationError ??
        _defaultIsRetryableCompensationError;
    final backoff = options.compensationBackoff ?? _defaultCompensationBackoff;

    Object? lastError;
    StackTrace? lastSt;

    for (var attempt = 1; attempt <= max; attempt++) {
      try {
        if (!cCell.modifiable.contains(cFn)) {
          throw TxApplyException('compensation function not in modifiable');
        }
        final result = await cCell.apply<Object?>((
          function: cFn,
          arguments: compensation.arguments,
          compensation: null,
        ));
        // void commands return null — only a rejection is a soft fail
        if (_isApplyRejected(result)) {
          throw TxApplyException('compensation ApplyRejected');
        }
        call.executed = false;
        return;
      } catch (e, st) {
        lastError = e;
        lastSt = st;
        final canRetry = attempt < max && isRetryable(e);
        if (!canRetry) {
          Error.throwWithStackTrace(e, st);
        }
        _event(TxApplyCompensationRetry(
          cell: cCell,
          attempt: attempt,
          maxAttempts: max,
          error: e,
        ));
        final delay = backoff(attempt);
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
      }
    }

    Error.throwWithStackTrace(
      lastError ?? TxApplyException('compensation failed'),
      lastSt ?? StackTrace.current,
    );
  }

  /// Runs compensations for staged calls in reverse-staging order, applying
  /// [TxApplyOptions.compensationErrorPolicy].
  ///
  /// Returns the collected failures (empty on full success). May throw
  /// [TxApplyCompensationException] under fail-fast or collect-then-throw
  /// policies.
  Future<List<CompensationFailure>> _runCompensations(
    int fromIndexInclusive, {
    required bool onlyExecuted,
  }) async {
    final failures = <CompensationFailure>[];

    for (var i = _staged.length - 1; i >= fromIndexInclusive; i--) {
      final call = _staged[i];
      if (!call.hasCompensation) continue;
      if (onlyExecuted && !call.executed) continue;
      if (!onlyExecuted && !call.executed && !options.compensateIfNotExecuted) {
        continue;
      }

      try {
        await _executeCompensation(call);
      } catch (e, st) {
        final failure = CompensationFailure(
          cell: call.compensateCell!,
          function: call.compensation?.function,
          error: e,
          stackTrace: st,
        );
        failures.add(failure);
        _event(TxApplyCompensationFailed(failure));

        if (options.compensationErrorPolicy ==
            CompensationErrorPolicy.failFast) {
          options.onCompensationFailures?.call(failures);
          throw TxApplyCompensationException(
            'compensation failed (failFast)',
            List.unmodifiable(failures),
            e,
          );
        }
      }
    }

    if (failures.isNotEmpty) {
      options.onCompensationFailures?.call(failures);
      if (options.compensationErrorPolicy ==
          CompensationErrorPolicy.collectThenThrow) {
        throw TxApplyCompensationException(
          'one or more compensations failed',
          List.unmodifiable(failures),
        );
      }
    }
    return failures;
  }

  /// Compensates **only** commands whose `executed` flag is set.
  ///
  /// Used by [commit] on failure: commands that were staged but never
  /// invoked have no side effect to reverse, and commands whose compensation
  /// already succeeded have `executed` cleared.
  Future<void> _compensateExecutedOnly() async {
    await _runCompensations(0, onlyExecuted: true);
  }

  @override
  Future<void> rollback({Object? savepoint}) async {
    if (!_begun) return;

    if (savepoint == null) {
      await _runCompensations(
        0,
        onlyExecuted: !options.compensateIfNotExecuted,
      );
      _staged.clear();
      _finished = true;
      _event(const TxApplyRolledBack());
      return;
    }

    // A non-null savepoint that is not one of ours — either not the opaque
    // savepoint type at all, or a savepoint issued by a different scope — is
    // unknown. Fail closed instead of silently degrading to a full rollback:
    // in financial contexts a full rollback is a different failure mode than
    // the caller requested.
    if (savepoint is! _TxSavepoint || savepoint.scopeId != _scopeId) {
      throw ArgumentError('Unknown savepoint: $savepoint');
    }

    final i = savepoint.index.clamp(0, _staged.length);
    await _runCompensations(
      i,
      onlyExecuted: !options.compensateIfNotExecuted,
    );
    _staged.removeRange(i, _staged.length);
    _event(TxApplyRolledBack(savepoint));
  }

  @override
  Future<void> commit() async {
    _ensureOpen();

    // Phase 1: integrity-gate re-validation. A rule may have been
    // tightened between staging and commit — this pre-pass catches that
    // *before* any command executes, so no forward-path work is done if
    // the batch is already invalid. Whitelist membership is NOT checked:
    // direct apply and txApply share one capability model, in which the
    // gate (`validate.action`) — not the `modifiable` manifest — decides
    // authorization. (The manifest could never match a caller-supplied
    // function anyway: a freshly allocated tear-off set has no identity
    // overlap with it.)
    for (final call in _staged) {
      final gate = call.cell.validate.action(call.command.function,
          host: call.cell,
          arguments: call.command.arguments,
          command: call.command);
      final passed = gate is Future<bool> ? await gate : gate;
      if (!passed) {
        _event(TxApplyRejected(call.cell, 'integrity gate'));
        await rollback();
        throw TxApplyException('action rejected by integrity gate');
      }
      if (call.hasCompensation) {
        final cCell = call.compensateCell!;
        final compensation = call.compensation!;
        final compGate = cCell.validate.action(compensation.function,
            host: cCell, arguments: compensation.arguments, command: null);
        final compPassed =
            compGate is Future<bool> ? await compGate : compGate;
        if (!compPassed) {
          await rollback();
          throw TxApplyException('compensate rejected by integrity gate');
        }
      }
    }

    // Phase 2: execution. Each command is invoked in staging order. On any
    // failure or veto, previously-executed commands are compensated exactly
    // once, in reverse-staging order, via _compensateExecutedOnly().
    Object? firstFailure;
    StackTrace? firstStack;
    var fromRejection = false;
    try {
      for (final call in _staged) {
        // Mark the call as attempted *before* invoking it so that a throw
        // (which may have left partial side effects) still triggers its
        // compensation during the rollback below.
        call.executed = true;

        final result = await call.cell.apply<Object?>(call.command);

        // void commands return null — only a rejection is a soft integrity
        // fail. Both a gate-level [ApplyRejected] outcome and an
        // [ApplyVeto]-returning function are treated as rejections.
        if (_isApplyRejected(result)) {
          // The integrity gate rejected the action: nothing ran, so this
          // call must never be compensated — regardless of
          // stopOnFirstFailure. Clearing the flag here (before any
          // continuation or throw) keeps a later failure from compensating
          // a command that never executed.
          call.executed = false;
          if (options.stopOnFirstFailure) {
            _event(TxApplyRejected(call.cell, 'ApplyRejected'));
            firstFailure = TxApplyException('apply rejected by integrity gate');
            firstStack = StackTrace.current;
            fromRejection = true;
            break;
          }
        }
      }
    } on TxApplyCompensationException {
      _finished = true;
      _staged.clear();
      rethrow;
    } catch (e, st) {
      // Domain errors (e.g. insufficient funds) land here.
      firstFailure = e;
      firstStack = st;
    }

    // Compensate once for either the rejection or the domain error — never
    // twice. Re-running a compensation is a hazard for non-idempotent undo,
    // and a failed compensation under bestEffort would otherwise be retried
    // by a second pass.
    if (firstFailure != null) {
      try {
        await _compensateExecutedOnly();
      } on TxApplyCompensationException catch (ce) {
        _finished = true;
        _staged.clear();
        if (fromRejection) {
          // The gate-level rejection path surfaces the compensation
          // failure as-is.
          Error.throwWithStackTrace(ce, firstStack!);
        }
        Error.throwWithStackTrace(
          TxApplyException('commit failed and compensation also failed', ce),
          firstStack!,
        );
      }
      _finished = true;
      _staged.clear();
      Error.throwWithStackTrace(
        TxApplyException('commit failed', firstFailure),
        firstStack!,
      );
    }

    final n = _staged.length;
    _staged.clear();
    _finished = true;
    _event(TxApplyCommitted(n));
  }

  @override
  Future<void> execute({
    required Iterable<Cell> participants,
    required void Function(ApplyTransactionScope tx) body,
  }) async {
    await begin(participants);
    try {
      body(this);
      await commit();
    } catch (e) {
      if (!_finished) {
        try {
          await rollback();
        } catch (_) {}
      }
      rethrow;
    }
  }
}

/// Creates a new [ApplyTransactionScope] with the supplied [options].
///
/// This is the entry point behind [Cell.txApply]. Each call returns a fresh,
/// independent scope — a scope is **one-shot**: after commit or full
/// rollback it cannot be reused.
ApplyTransactionScope _txApply([
  TxApplyOptions options = const TxApplyOptions(),
]) =>
    _ApplyTransactionScopeImpl(options);
