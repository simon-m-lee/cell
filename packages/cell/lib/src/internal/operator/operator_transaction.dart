// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// ignore_for_file: no_leading_underscores_for_local_identifiers

part of '../../../cell.dart';

// ─────────────────────────────────────────────────────────────
// Isolation levels
// ─────────────────────────────────────────────────────────────

/// Defines the consistency and visibility guarantees for a transaction.
///
/// The isolation level determines how a transaction sees changes made by
/// other concurrent transactions, and what guarantees it has about the
/// stability of the data it reads.
///
/// ### When to use
/// Choose the isolation level based on your consistency requirements:
/// - `readCommitted` – for simple, independent updates where you don't
///   care about concurrent modifications.
/// - `repeatableRead` – when you need a stable view of the data during
///   the transaction, and want to abort if another transaction changes it.
/// - `serializable` – when you need full isolation with no write skew,
///   at the cost of performance and global ordering.
///
/// ### How it works
/// - `readCommitted`: Reads return the current live value. No snapshot
///   is taken. This is the default and fastest option.
/// - `repeatableRead`: A snapshot is taken at `begin`. Reads return the
///   snapshot value. During commit, if any participant has changed since
///   the snapshot, the transaction aborts with a conflict.
/// - `serializable`: Like repeatable read, but also tracks the read set.
///   If any cell that was read (but not written) has changed, the
///   transaction aborts. Commits are globally serialized.
///
enum IsolationLevel {
  /// **Read Committed** – the default level.
  ///
  /// Reads return the current live value at the time of the read.
  /// No snapshot is taken. This provides the best performance and
  /// the least consistency guarantees.
  ///
  /// ### When to use
  /// - Simple updates that don't depend on reading stable values.
  /// - High‑throughput scenarios where consistency can be relaxed.
  /// - When you only need atomicity for writes, not isolation for reads.
  ///
  readCommitted,

  /// **Repeatable Read** – ensures a stable view of participant cells.
  ///
  /// A snapshot of all participant cells is taken at `begin`. All reads
  /// return the snapshot value. During commit, if any participant has
  /// changed since the snapshot, the transaction aborts with a
  /// [TransactionConflictException].
  ///
  /// ### When to use
  /// - When you need to read a set of values and base updates on them,
  ///   and you want to ensure no other transaction changes them.
  /// - For scenarios like "read balance, then deduct amount" where you
  ///   need consistency.
  ///
  repeatableRead,

  /// **Serializable** – the strongest isolation level.
  ///
  /// Like repeatable read, but also tracks the read set. If any cell that
  /// was read (but not written) has changed since the snapshot, the
  /// transaction aborts. Commits are globally serialized via a single
  /// gate, ensuring a total order of all serializable transactions.
  ///
  /// ### When to use
  /// - When you need full isolation with no anomalies.
  /// - For invariants that span multiple cells (e.g., "sum of accounts
  ///   must be zero").
  /// - When you can tolerate the performance overhead of global ordering.
  ///
  serializable,
}

/// Defines the order in which locks are acquired during commit.
///
/// Lock ordering is critical for preventing deadlocks when multiple
/// transactions commit simultaneously. The order must be consistent
/// across all transactions.
///
/// ### When to use
/// - `byHashCode` – default, uses cell hash codes for ordering.
/// - `insertion` – uses the order passed to `begin`.
/// - `explicit` – uses a custom comparator.
///
enum LockOrdering {
  /// Order locks by cell hash code.
  ///
  /// This is the default and ensures a deterministic order that is
  /// consistent across all transactions. Deadlocks are prevented because
  /// all transactions acquire locks in the same order.
  ///
  byHashCode,

  /// Order locks by the insertion order passed to `begin`.
  ///
  /// Locks are acquired in the exact order the cells were provided.
  /// This can be useful if you have a natural order in your domain.
  ///
  insertion,

  /// Use a custom comparator provided in [TransactionOptions.comparator].
  ///
  /// This gives you full control over lock ordering. The comparator must
  /// be total and consistent with `==`.
  ///
  explicit,
}

// ─────────────────────────────────────────────────────────────
// Events
// ─────────────────────────────────────────────────────────────

/// Base class for all transaction lifecycle events.
///
/// These events are emitted via the `onEvent` callback in
/// [TransactionOptions]. They provide visibility into the transaction's
/// progress for logging, monitoring, or debugging.
///
/// ### When to use
/// Use these events to:
/// - Log transaction activity for auditing.
/// - Monitor transaction performance.
/// - Debug transaction failures.
/// - Implement custom retry logic.
///
/// See also [TransactionOptions.onEvent].
sealed class TransactionEvent {
  const TransactionEvent();
}

/// Emitted when a transaction begins.
///
/// Contains the list of participant cells and the isolation level
/// being used.
///
/// ### When to use
/// Use this to track transaction boundaries – start timing, log the
/// participants, or initialize monitoring.
class TransactionBegun extends TransactionEvent {
  /// The cells participating in the transaction.
  final List<Cell> cells;

  /// The isolation level being used.
  final IsolationLevel isolation;

  const TransactionBegun(this.cells, this.isolation);
}

/// Emitted when a cell is updated during a transaction.
///
/// Each call to `update` emits a `TransactionUpdated` event with the
/// affected cell and the new value.
///
/// ### When to use
/// Use this to track individual updates within a transaction, for
/// debugging or detailed auditing.
class TransactionUpdated extends TransactionEvent {
  /// The cell being updated.
  final Cell cell;

  /// The new value being buffered.
  final dynamic value;

  const TransactionUpdated(this.cell, this.value);
}

/// Emitted when a transaction commits successfully.
///
/// Contains the list of all changes that were applied.
///
/// ### When to use
/// Use this to confirm that the transaction completed successfully,
/// and to see exactly what changed.
class TransactionCommitted extends TransactionEvent {
  /// The list of cells and their new values that were applied.
  final List<({Cell cell, dynamic value})> changes;

  const TransactionCommitted(this.changes);
}

/// Emitted when a transaction is rolled back.
///
/// If a savepoint is provided, the rollback was partial.
///
/// ### When to use
/// Use this to detect transaction failures and log the reason.
class TransactionRolledBack extends TransactionEvent {
  /// The savepoint identifier, if a partial rollback was performed.
  final Object? savepoint;

  const TransactionRolledBack([this.savepoint]);
}

/// Emitted when a transaction times out.
///
/// The transaction is automatically rolled back when a timeout occurs.
///
/// ### When to use
/// Use this to detect long‑running transactions and alert on potential
/// performance issues.
class TransactionTimedOut extends TransactionEvent {
  /// The timeout duration that was exceeded.
  final Duration timeout;

  const TransactionTimedOut(this.timeout);
}

// ─────────────────────────────────────────────────────────────
// Errors
// ─────────────────────────────────────────────────────────────

/// Represents a validation failure for a specific cell.
///
/// This is used to provide detailed information about why a transaction
/// failed validation.
///
/// ### When to use
/// When a transaction fails, you receive a list of [ValidationFailure]s
/// that tell you exactly which cells failed and why.
///
/// See also [TransactionValidationException], [TransactionConflictException].
class ValidationFailure {
  /// The cell that failed validation.
  final Cell cell;

  /// The value that was rejected.
  final dynamic value;

  /// A human‑readable reason for the failure.
  final String reason;

  const ValidationFailure({
    required this.cell,
    required this.value,
    required this.reason,
  });
}

/// Thrown when validation of buffered writes fails during commit.
///
/// This exception contains a list of [ValidationFailure]s, one for each
/// cell that rejected its value.
///
/// ### When to use
/// Catch this to handle validation failures gracefully, e.g., by
/// presenting errors to the user or retrying with corrected values.
///
class TransactionValidationException implements Exception {
  final List<ValidationFailure> failures;

  const TransactionValidationException(this.failures);

  @override
  String toString() =>
      'TransactionValidationException(${failures.length} failure(s)): '
      '${failures.map((f) => '${f.cell}: ${f.reason}').join('; ')}';
}

/// Thrown when an isolation conflict is detected during commit.
///
/// This occurs when:
/// - `repeatableRead`: a participant cell changed since the snapshot.
/// - `serializable`: a cell that was read (but not written) changed.
///
/// ### When to use
/// Catch this to retry the transaction with fresh values.
///
class TransactionConflictException implements Exception {
  final List<ValidationFailure> conflicts;

  const TransactionConflictException(this.conflicts);

  @override
  String toString() =>
      'TransactionConflictException(${conflicts.length} conflict(s)): '
      '${conflicts.map((c) => '${c.cell}: ${c.reason}').join('; ')}';
}

/// Thrown when a transaction exceeds its [timeout] duration.
///
/// The transaction is automatically rolled back when this occurs.
///
/// ### When to use
/// Catch this to implement retry logic or alert on performance issues.
class TransactionTimeoutException implements Exception {
  final Duration timeout;
  const TransactionTimeoutException(this.timeout);

  @override
  String toString() => 'TransactionTimeoutException after $timeout';
}

// ─────────────────────────────────────────────────────────────
// Options
// ─────────────────────────────────────────────────────────────

/// Configuration options for a [Cell.transaction].
///
/// The options control isolation level, lock ordering, timeout, validation,
/// and application logic for the transaction.
///
/// ### Where to start
/// Use the default constructor with the parameters you need:
/// ```dart
/// final tx = Cell.transaction(TransactionOptions(
///   isolation: IsolationLevel.repeatableRead,
///   timeout: Duration(seconds: 5),
///   onEvent: (e) => print(e),
/// ));
/// ```
///
/// ### When to use
/// - Use `isolation` to control consistency guarantees.
/// - Use `timeout` to prevent transactions from running indefinitely.
/// - Use `validate` to add custom validation logic for all cells.
/// - Use `apply` to customize how values are applied to cells.
/// - Use `onEvent` for logging and monitoring.
///
class TransactionOptions {
  /// The isolation level for the transaction.
  ///
  /// Defaults to [IsolationLevel.readCommitted].
  final IsolationLevel isolation;

  /// The lock ordering strategy.
  ///
  /// Defaults to [LockOrdering.byHashCode].
  final LockOrdering ordering;

  /// Custom comparator for [LockOrdering.explicit].
  ///
  /// Required when [ordering] is `explicit`. [Cell.transaction] throws
  /// [ArgumentError] if it is omitted.
  final int Function(Cell a, Cell b)? comparator;

  /// Maximum duration the transaction can run.
  ///
  /// If exceeded, the transaction is automatically rolled back and a
  /// [TransactionTimeoutException] is thrown by the next interaction.
  ///
  final Duration? timeout;

  /// Additional validation callback applied during commit.
  ///
  /// Called after each cell's own `testRule`. If either fails, the
  /// transaction is rolled back.
  ///
  final FutureOr<bool> Function(Cell cell, dynamic value)? validate;

  /// Custom application callback for applying changes.
  ///
  /// Called for each change during commit. If not provided, the default
  /// logic is used ([ValueCell] updates via `_emit`, others via their
  /// receptor).
  ///
  final FutureOr<void> Function(Cell cell, dynamic value)? apply;

  /// Callback for transaction lifecycle events.
  ///
  /// Called when the transaction begins, updates, commits, rolls back,
  /// or times out.
  final void Function(TransactionEvent event)? onEvent;

  const TransactionOptions({
    this.isolation = IsolationLevel.readCommitted,
    this.ordering = LockOrdering.byHashCode,
    this.comparator,
    this.timeout,
    this.validate,
    this.apply,
    this.onEvent,
  });
}

// ─────────────────────────────────────────────────────────────
// Internal records
// ─────────────────────────────────────────────────────────────

/// Internal record for buffered changes.
class _Change {
  final Cell cell;
  final dynamic newValue;
  final int savepointId;
  _Change({
    required this.cell,
    required this.newValue,
    required this.savepointId,
  });
}

/// Internal record for savepoints.
class _Savepoint {
  final int id;
  final int bufferLength;
  const _Savepoint(this.id, this.bufferLength);
}

/// Global lock for serializable transactions.
final _serializableGate = Lock();

// ─────────────────────────────────────────────────────────────
// Transaction scope type
// ─────────────────────────────────────────────────────────────

/// A handle for coordinating atomic, multi‑cell transactions.
///
/// ### Where to start
/// You get a [TransactionScope] from [Cell.transaction]. Use it when you
/// need to update several cells together atomically:
/// ```dart
/// final tx = Cell.transaction();
/// await tx.begin([accountA, accountB]);
/// tx.update(accountA, 100);
/// tx.update(accountB, 200);
/// await tx.commit();
/// ```
///
/// ### When to use
/// Use transactions when:
/// - Multiple cells must change together (all or nothing).
/// - You need to read values and base updates on them consistently.
/// - You want to avoid partial updates that could leave the system
///   in an inconsistent state.
/// - You're implementing financial transfers, inventory adjustments,
///   or any operation with invariants across cells.
/// - You need to coordinate changes across different cell types.
///
/// ### How it works
/// 1. **Begin**: Register participants and (optionally) snapshot values.
/// 2. **Update**: Buffer writes — cells are not actually modified yet.
/// 3. **Read**: Observe values according to the isolation level.
/// 4. **Commit**: Acquire locks, validate, apply all changes atomically.
/// 5. **Rollback**: Discard buffered changes.
///
/// ### Example 1: Basic Transfer
/// ```dart
/// final tx = Cell.transaction();
///
/// await tx.begin([fromAccount, toAccount]);
///
/// final fromBalance = tx.read(fromAccount) as int;
/// final toBalance = tx.read(toAccount) as int;
///
/// tx.update(fromAccount, fromBalance - 50);
/// tx.update(toAccount, toBalance + 50);
///
/// await tx.commit();
/// ```
///
/// ### Example 2: With Savepoint
/// ```dart
/// final tx = Cell.transaction();
/// await tx.begin([cell1, cell2, cell3]);
///
/// tx.update(cell1, 10);
/// tx.update(cell2, 20);
///
/// // Create a checkpoint
/// final sp = tx.savepoint();
///
/// // Speculative updates
/// tx.update(cell2, 30);
/// tx.update(cell3, 40);
///
/// // Something went wrong — rollback to checkpoint
/// await tx.rollback(savepoint: sp);
///
/// // cell1 = 10, cell2 = 20, cell3 unchanged
/// await tx.commit();
/// ```
///
/// ### Example 3: Repeatable Read Isolation
/// ```dart
/// final tx = Cell.transaction(TransactionOptions(
///   isolation: IsolationLevel.repeatableRead,
///   timeout: Duration(seconds: 5),
///   onEvent: (e) => print(e),
/// ));
///
/// await tx.begin([accountA, accountB]);
///
/// // Both reads return the snapshot from begin
/// final a = tx.read(accountA) as int;
/// final b = tx.read(accountB) as int;
///
/// // If another transaction changed accountA after begin,
/// // commit will throw TransactionConflictException
/// tx.update(accountA, a + 100);
/// await tx.commit();
/// ```
///
/// See also [Cell.transaction].
typedef TransactionScope = ({
  /// Starts a transaction that locks all [cells] atomically.
  ///
  /// ### When to use
  /// Call this before any updates. The transaction is active until
  /// `commit` or `rollback` is called.
  ///
  /// ### How it works
  /// - Registers the participants and (if needed) takes a snapshot.
  /// - Resolves lock ordering for the commit phase.
  /// - Starts a timeout timer if [timeout] is set.
  ///
  /// ### Throws
  /// - [StateError] if a transaction is already active.
  /// - [ArgumentError] if [cells] is empty.
  /// - [TransactionTimeoutException] if the timeout expires.
  Future<void> Function(Iterable<Cell> cells) begin,

  /// Buffers a change to a cell (does not apply it yet).
  ///
  /// ### When to use
  /// Call this for each cell you want to update. The changes are buffered
  /// until `commit` is called.
  ///
  /// ### How it works
  /// - The change is stored in a buffer.
  /// - The cell is marked as pending for `pending` reads.
  /// - Emits a [TransactionUpdated] event.
  ///
  /// ### Throws
  /// - [StateError] if no transaction is active.
  /// - [ArgumentError] if the cell is not a participant.
  /// - [TransactionTimeoutException] if the timeout expires.
  void Function(Cell cell, dynamic value) update,

  /// Reads a cell's value according to the isolation level.
  ///
  /// ### When to use
  /// Use this to read participant values during the transaction.
  ///
  /// ### How it works
  /// - `readCommitted`: returns the current live value.
  /// - `repeatableRead`: returns the snapshot value from `begin`.
  /// - `serializable`: returns the snapshot value and tracks the read set.
  ///
  /// ### Returns
  /// The value of the cell according to the isolation level.
  ///
  /// ### Throws
  /// - [StateError] if no transaction is active.
  /// - [ArgumentError] if the cell is not a participant.
  /// - [TransactionTimeoutException] if the timeout expires.
  dynamic Function(Cell cell) read,

  /// Reads a cell's value, preferring buffered writes over snapshots.
  ///
  /// ### When to use
  /// Use this when you need to see changes made earlier in the same
  /// transaction (e.g., to calculate a new value based on a pending update).
  ///
  /// ### How it works
  /// - If the cell has a buffered write, returns that value.
  /// - Otherwise, falls back to `read`.
  ///
  /// ### Returns
  /// The pending value if available, otherwise the isolation‑level read.
  ///
  /// ### Throws
  /// - [StateError] if no transaction is active.
  /// - [ArgumentError] if the cell is not a participant.
  /// - [TransactionTimeoutException] if the timeout expires.
  dynamic Function(Cell cell) pending,

  /// Applies all buffered changes atomically and releases the lock.
  ///
  /// ### When to use
  /// Call this when you are ready to apply all changes. The transaction
  /// is completed and cannot be used again.
  ///
  /// ### How it works
  /// 1. Acquires locks on all participants in deterministic order.
  /// 2. Checks for isolation conflicts (if applicable).
  /// 3. Validates all buffered changes (own `testRule` + custom validator).
  /// 4. Applies all changes atomically.
  /// 5. Releases locks and resets the transaction state.
  /// 6. Emits a [TransactionCommitted] event.
  ///
  /// ### Throws
  /// - [StateError] if no transaction is active.
  /// - [TransactionValidationException] if validation fails.
  /// - [TransactionConflictException] if an isolation conflict occurs.
  /// - [TransactionTimeoutException] if the timeout expires.
  /// - Any error from custom `validate` or `apply` callbacks.
  Future<void> Function() commit,

  /// Discards all buffered changes and releases the lock.
  ///
  /// ### When to use
  /// Call this to cancel the transaction without applying any changes.
  /// Optionally pass a `savepoint` to rollback only to that point.
  ///
  /// ### How it works
  /// - If a `savepoint` is provided, discards changes after that point.
  /// - Otherwise, discards all changes and resets the transaction.
  /// - Emits a [TransactionRolledBack] event.
  ///
  /// ### Throws
  /// - [ArgumentError] if the savepoint is unknown.
  Future<void> Function({Object? savepoint}) rollback,

  /// Captures a restoration point for partial rollback.
  ///
  /// ### When to use
  /// Use this to create a checkpoint within a transaction. Later, you can
  /// roll back to this point without discarding all changes.
  ///
  /// ### How it works
  /// - Records the current buffer length.
  /// - Returns an opaque identifier that can be passed to `rollback`.
  ///
  /// ### Returns
  /// An opaque identifier that can be passed to `rollback`.
  Object Function() savepoint,
});

// ─────────────────────────────────────────────────────────────
// Implementation
// ─────────────────────────────────────────────────────────────

/// Internal implementation of [Cell.transaction].
///
/// This function creates a transaction scope with the given options.
/// It handles isolation, locking, validation, and application of changes.
///
/// ### How it works
/// 1. A transaction scope is created with internal state.
/// 2. `begin` registers participants and (if needed) takes a snapshot.
/// 3. `update` buffers changes.
/// 4. `commit` acquires locks, checks conflicts, validates, applies.
/// 5. `rollback` discards changes.
/// 6. `savepoint` captures a restoration point.
///
TransactionScope _transaction([
  TransactionOptions options = const TransactionOptions(),
]) {
  if (options.ordering == LockOrdering.explicit && options.comparator == null) {
    throw ArgumentError(
      'LockOrdering.explicit requires TransactionOptions.comparator',
    );
  }

  final buffer = <_Change>[];
  final pendingMap = <Cell, dynamic>{};
  final snapshots = <Cell, dynamic>{};
  final readSet = <Cell>{};
  Set<Cell>? participants;
  var isActive = false;
  var nextSavepointId = 0;
  final savepoints = <int, _Savepoint>{};
  Timer? timeoutTimer;
  var timedOut = false;

  int Function(Cell, Cell)? _resolvedOrder;

  final scopeLock = Lock();
  final isolation = options.isolation;
  final needsSnapshot = isolation != IsolationLevel.readCommitted;

  void _emit(TransactionEvent e) => options.onEvent?.call(e);

  void _ensureActive() {
    if (timedOut) throw TransactionTimeoutException(options.timeout!);
    if (!isActive) {
      throw StateError('No active transaction. Call begin() first.');
    }
  }

  void _clearTimeout() {
    timeoutTimer?.cancel();
    timeoutTimer = null;
  }

  void _reset() {
    buffer.clear();
    pendingMap.clear();
    savepoints.clear();
    snapshots.clear();
    readSet.clear();
    isActive = false;
    participants = null;
    _resolvedOrder = null;
    _clearTimeout();
  }

  dynamic _liveValue(Cell cell) {
    if (cell is ValueCell) return cell.value;
    return null;
  }

  int Function(Cell, Cell) _insertionOrder(List<Cell> cells) {
    final rank = <Cell, int>{
      for (var i = 0; i < cells.length; i++) cells[i]: i,
    };
    return (a, b) => rank[a]!.compareTo(rank[b]!);
  }

  int Function(Cell, Cell) _resolveOrder(List<Cell> cells) {
    switch (options.ordering) {
      case LockOrdering.byHashCode:
        return (a, b) {
          final byHash = a.hashCode.compareTo(b.hashCode);
          // Equal hash codes must still get a deterministic total order:
          // `List.sort` is not stable, so two transactions locking the same
          // colliding pair in different orders would deadlock.
          if (byHash != 0) return byHash;
          return identityHashCode(a).compareTo(identityHashCode(b));
        };
      case LockOrdering.insertion:
        return _insertionOrder(cells);
      case LockOrdering.explicit:
        final cmp = options.comparator;
        if (cmp == null) {
          throw ArgumentError(
            'LockOrdering.explicit requires TransactionOptions.comparator',
          );
        }
        return cmp;
    }
  }

  // ── begin ──────────────────────────────────────────────────

  Future<void> begin(Iterable<Cell> cells) {
    return scopeLock.synchronized(() async {
      if (isActive) {
        throw StateError(
          'Transaction already active. Commit or rollback first.',
        );
      }

      final cellList = cells.toList();
      if (cellList.isEmpty) {
        throw ArgumentError('At least one cell must be provided.');
      }

      // Resolve lock ordering once (insertion ranking needs the list).
      _resolvedOrder = _resolveOrder(cellList);

      snapshots.clear();
      readSet.clear();
      if (needsSnapshot) {
        for (final cell in cellList) {
          snapshots[cell] = _liveValue(cell);
        }
      }

      if (options.timeout != null) {
        timedOut = false;
        timeoutTimer = Timer(options.timeout!, () {
          // The timeout fires asynchronously: serialize the state mutation
          // through the scope lock so it cannot race a commit/rollback in
          // flight. Per the documented contract, timing out automatically
          // rolls the transaction back (leaving `timedOut` set so the next
          // gate interaction still reports TransactionTimeoutException).
          scopeLock.synchronized(() {
            if (!isActive || timedOut) return;
            timedOut = true;
            _emit(TransactionTimedOut(options.timeout!));
            _reset();
          });
        });
      }

      participants = Set.of(cellList);
      buffer.clear();
      pendingMap.clear();
      savepoints.clear();
      nextSavepointId = 0;
      isActive = true;
      _emit(TransactionBegun(cellList, isolation));
    });
  }

  // ── update ─────────────────────────────────────────────────

  void update(Cell cell, dynamic value) {
    _ensureActive();
    if (!participants!.contains(cell)) {
      throw ArgumentError('Cell $cell is not part of this transaction.');
    }
    buffer.add(_Change(
      cell: cell,
      newValue: value,
      savepointId: nextSavepointId,
    ));
    pendingMap[cell] = value;
    _emit(TransactionUpdated(cell, value));
  }

  // ── read / pending ─────────────────────────────────────────

  dynamic read(Cell cell) {
    _ensureActive();
    if (!participants!.contains(cell)) {
      throw ArgumentError('Cell $cell is not part of this transaction.');
    }
    if (isolation == IsolationLevel.serializable) {
      readSet.add(cell);
    }
    if (needsSnapshot) return snapshots[cell];
    return _liveValue(cell);
  }

  dynamic pending(Cell cell) {
    _ensureActive();
    if (pendingMap.containsKey(cell)) return pendingMap[cell];
    return read(cell);
  }

  // ── savepoint ──────────────────────────────────────────────

  Object savepoint() {
    _ensureActive();
    final id = nextSavepointId;
    savepoints[id] = _Savepoint(id, buffer.length);
    nextSavepointId++;
    return id;
  }

  // ── rollback ───────────────────────────────────────────────

  Future<void> rollback({Object? savepoint}) {
    return scopeLock.synchronized(() async {
      if (!isActive) return;

      if (savepoint != null) {
        final sp = savepoints[savepoint as int];
        if (sp == null) {
          throw ArgumentError('Unknown savepoint: $savepoint');
        }
        if (buffer.length > sp.bufferLength) {
          buffer.removeRange(sp.bufferLength, buffer.length);
          pendingMap
            ..clear()
            ..addEntries(buffer.map((c) => MapEntry(c.cell, c.newValue)));
          savepoints.removeWhere((id, _) => id > sp.id);
        }
        _emit(TransactionRolledBack(savepoint));
        return;
      }

      _reset();
      _emit(const TransactionRolledBack());
    });
  }

  // ── validate / apply defaults ──────────────────────────────

  FutureOr<bool> _defaultValidate(Cell cell, dynamic value) async {
    // Mirror the direct mutation path: validation sees the same Pulse shape
    // the receptor will receive at apply time. Validating the raw value
    // here would silently bypass TestPulseRules — they return `true` for
    // non-pulse inputs — while direct updates enforce them through
    // `receptor.call(pulse)`.
    final result = cell.validate(
      Pulse.governed(payload: value, source: cell),
      host: cell,
    );
    return result is Future<bool> ? await result : result;
  }

  FutureOr<void> _defaultApply(Cell cell, dynamic value) async {
    if (cell is ValueCell) {
      // Cross-package ValueCell implementations (e.g., TissueValue) do not
      // inherit the private `_emit`; commit through the public value
      // setter. Unmodifiable views reject the write loudly, which surfaces
      // as a commit failure and rolls the transaction back.
      cell.value = value;
      return;
    }
    final out = cell._nucleus.receptor
        .call(Pulse.governed(payload: value, source: cell));
    if (out is Future) await out;
  }

  // ── conflict detection ─────────────────────────────────────

  List<ValidationFailure> _detectConflicts(Iterable<Cell> cells) {
    switch (isolation) {
      case IsolationLevel.readCommitted:
        return const [];

      case IsolationLevel.repeatableRead:
        return [
          for (final cell in cells)
            if (snapshots.containsKey(cell) &&
                _liveValue(cell) != snapshots[cell])
              ValidationFailure(
                cell: cell,
                value: _liveValue(cell),
                reason: 'Repeatable-read conflict (cell changed since begin)',
              ),
        ];

      case IsolationLevel.serializable:
        final checked = {...readSet, ...pendingMap.keys};
        return [
          for (final cell in checked)
            if (snapshots.containsKey(cell) &&
                _liveValue(cell) != snapshots[cell])
              ValidationFailure(
                cell: cell,
                value: _liveValue(cell),
                reason: 'Serializable conflict (cell changed since begin)',
              ),
        ];
    }
  }

  // ── commit ─────────────────────────────────────────────────

  Future<void> commit() {
    return scopeLock.synchronized(() async {
      _ensureActive();

      final cells = participants!.toList();
      final validate = options.validate ?? _defaultValidate;
      final apply = options.apply ?? _defaultApply;

      Future<void> doCommit() async {
        await withCellLocks(cells, order: _resolvedOrder, () async {
          // 1. Isolation conflict check (under locks).
          final conflicts = _detectConflicts(cells);
          if (conflicts.isNotEmpty) {
            throw TransactionConflictException(conflicts);
          }

          // 2. Validate buffered writes.
          final failures = <ValidationFailure>[];
          for (final change in buffer) {
            if (!await validate(change.cell, change.newValue)) {
              failures.add(ValidationFailure(
                cell: change.cell,
                value: change.newValue,
                reason: 'TestCell rejected value',
              ));
            }
          }
          if (failures.isNotEmpty) {
            throw TransactionValidationException(failures);
          }

          // 3. Apply while locks are held. A mid-commit failure must not
          // leave earlier writes of THIS commit applied: record each
          // cell's prior value and restore it (in reverse order) before
          // the rollback is reported.
          final applied = <({Cell cell, dynamic value})>[];
          final priors = <({Cell cell, dynamic value})>[];
          for (final change in buffer) {
            try {
              final prior = change.cell is ValueCell
                  ? (change.cell as ValueCell).value
                  : null;
              priors.add((cell: change.cell, value: prior));
              await apply(change.cell, change.newValue);
              applied.add((cell: change.cell, value: change.newValue));
            } catch (_) {
              for (final prior in priors.reversed) {
                if (prior.cell is ValueCell) {
                  try {
                    (prior.cell as ValueCell).value = prior.value;
                  } catch (_) {
                    // Best effort: an unmodifiable projection cannot be
                    // restored, and that surfaces through the original
                    // exception below.
                  }
                }
              }
              rethrow;
            }
          }

          final committed = List.of(applied);
          _reset();
          try {
            _emit(TransactionCommitted(committed));
          } catch (_) {
            // The batch is already applied at this point; a throwing
            // onEvent handler cannot roll it back, and reporting a
            // TransactionRolledBack afterwards would contradict the
            // committed state. Swallow the handler error and keep the
            // committed outcome.
          }
        });
      }

      try {
        if (isolation == IsolationLevel.serializable) {
          await _serializableGate.synchronized(doCommit);
        } else {
          await doCommit();
        }
      } catch (e) {
        _reset();
        _emit(const TransactionRolledBack());
        rethrow;
      }
    });
  }

  return (
    begin: begin,
    update: update,
    read: read,
    pending: pending,
    commit: commit,
    rollback: rollback,
    savepoint: savepoint,
  );
}
