// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell.dart';

// ─────────────────────────────────────────────────────────────
// factory - txApply (atomic multi-apply + compensation)
// ─────────────────────────────────────────────────────────────

/// Explicit soft-reject from [Cell.apply] (not the same as void → null).
class ApplyRejected {
  static const instance = ApplyRejected._();
  const ApplyRejected._();
}

// ── Events ───────────────────────────────────────────────────

sealed class TxApplyEvent {
  const TxApplyEvent();
}

class TxApplyBegun extends TxApplyEvent {
  final List<Cell> participants;
  const TxApplyBegun(this.participants);
}

class TxApplyStaged extends TxApplyEvent {
  final Cell cell;
  final Function function;
  const TxApplyStaged(this.cell, this.function);
}

class TxApplyCommitted extends TxApplyEvent {
  final int callCount;
  const TxApplyCommitted(this.callCount);
}

class TxApplyRolledBack extends TxApplyEvent {
  final Object? savepoint;
  const TxApplyRolledBack([this.savepoint]);
}

class TxApplyRejected extends TxApplyEvent {
  final Cell cell;
  final Object reason;
  const TxApplyRejected(this.cell, this.reason);
}

class TxApplyCompensationFailed extends TxApplyEvent {
  final CompensationFailure failure;
  const TxApplyCompensationFailed(this.failure);
}

class TxApplyCompensationRetry extends TxApplyEvent {
  final Cell cell;
  final int attempt;
  final int maxAttempts;
  final Object error;
  const TxApplyCompensationRetry({
    required this.cell,
    required this.attempt,
    required this.maxAttempts,
    required this.error,
  });
}

// ── Errors ───────────────────────────────────────────────────

class CompensationFailure {
  final Cell cell;
  final Function? function;
  final Object error;
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

class TxApplyException implements Exception {
  final String message;
  final Object? cause;
  TxApplyException(this.message, [this.cause]);
  @override
  String toString() => 'TxApplyException: $message';
}

class TxApplyCompensationException implements Exception {
  final String message;
  final List<CompensationFailure> failures;
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

enum CompensationErrorPolicy {
  bestEffort,
  failFast,
  collectThenThrow,
}

class TxApplyOptions {
  final void Function(TxApplyEvent event)? onEvent;
  final bool stopOnFirstFailure;
  final int Function(Cell a, Cell b)? comparator;
  final bool compensateIfNotExecuted;
  final CompensationErrorPolicy compensationErrorPolicy;
  final void Function(List<CompensationFailure> failures)? onCompensationFailures;
  final int compensationMaxAttempts;
  final Duration Function(int attempt)? compensationBackoff;
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

Duration _defaultCompensationBackoff(int attempt) {
  final ms = 20 * (1 << (attempt - 1).clamp(0, 5));
  return Duration(milliseconds: ms);
}

bool _defaultIsRetryableCompensationError(Object error) {
  if (error is TxApplyException) {
    final m = error.message;
    if (m.contains('not in modifiable')) return false;
    if (m.contains('ApplyRejected')) return false;
  }
  if (error is ArgumentError) return false;
  return true;
}

bool _isApplyRejected(dynamic result) => identical(result, ApplyRejected.instance);

// ── Staging ──────────────────────────────────────────────────

class _StagedApply {
  final Cell cell;
  final Function function;
  final List? positionalArguments;
  final Map<Symbol, dynamic>? namedArguments;

  final Cell? compensateCell;
  final Function? compensateFunction;
  final List? compensatePositional;
  final Map<Symbol, dynamic>? compensateNamed;

  bool executed = false;

  _StagedApply({
    required this.cell,
    required this.function,
    required this.positionalArguments,
    required this.namedArguments,
    this.compensateCell,
    this.compensateFunction,
    this.compensatePositional,
    this.compensateNamed,
  });

  bool get hasCompensation =>
      compensateCell != null && compensateFunction != null;
}

class _TxSavepoint {
  final int index;
  const _TxSavepoint(this.index);
}

// ── Scope API ────────────────────────────────────────────────

abstract class ApplyTransactionScope {
  Future<void> begin(Iterable<Cell> participants);

  void enqueue(
      Cell cell,
      Function function,
      List? positionalArguments,
      Map<Symbol, dynamic>? namedArguments, {
        Cell? compensateCell,
        Function? compensateFunction,
        List? compensatePositional,
        Map<Symbol, dynamic>? compensateNamed,
      });

  Future<void> commit();
  Future<void> rollback({Object? savepoint});
  Object savepoint();

  Future<void> execute({
    required Iterable<Cell> participants,
    required void Function(ApplyTransactionScope tx) body,
  });
}

// ── Implementation ───────────────────────────────────────────

class _ApplyTransactionScopeImpl implements ApplyTransactionScope {
  _ApplyTransactionScopeImpl(this.options);

  final TxApplyOptions options;
  final List<_StagedApply> _staged = <_StagedApply>[];
  final Set<Cell> _participants = <Cell>{};
  bool _begun = false;
  bool _finished = false;

  void _event(TxApplyEvent e) => options.onEvent?.call(e);

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
  void enqueue(
      Cell cell,
      Function function,
      List? positionalArguments,
      Map<Symbol, dynamic>? namedArguments, {
        Cell? compensateCell,
        Function? compensateFunction,
        List? compensatePositional,
        Map<Symbol, dynamic>? compensateNamed,
      }) {
    _ensureOpen();
    if (!_participants.contains(cell)) {
      throw TxApplyException(
        'cell is not a participant of this txApply scope',
      );
    }
    if (!cell.modifiable.contains(function)) {
      _event(TxApplyRejected(cell, 'not in modifiable'));
      throw TxApplyException('function not in cell.modifiable');
    }
    if (compensateFunction != null) {
      final cCell = compensateCell ?? cell;
      if (!_participants.contains(cCell)) {
        throw TxApplyException('compensate cell is not a participant');
      }
      if (!cCell.modifiable.contains(compensateFunction)) {
        _event(TxApplyRejected(cCell, 'compensate not in modifiable'));
        throw TxApplyException('compensate function not in modifiable');
      }
    }

    _staged.add(_StagedApply(
      cell: cell,
      function: function,
      positionalArguments: positionalArguments,
      namedArguments: namedArguments,
      compensateCell:
      compensateFunction == null ? null : (compensateCell ?? cell),
      compensateFunction: compensateFunction,
      compensatePositional: compensatePositional,
      compensateNamed: compensateNamed,
    ));
    _event(TxApplyStaged(cell, function));
  }

  @override
  Object savepoint() {
    _ensureOpen();
    return _TxSavepoint(_staged.length);
  }

  Future<void> _executeCompensation(_StagedApply call) async {
    final cCell = call.compensateCell!;
    final cFn = call.compensateFunction!;
    final max = options.compensationMaxAttempts < 1
        ? 1
        : options.compensationMaxAttempts;
    final isRetryable = options.isRetryableCompensationError ??
        _defaultIsRetryableCompensationError;
    final backoff =
        options.compensationBackoff ?? _defaultCompensationBackoff;

    Object? lastError;
    StackTrace? lastSt;

    for (var attempt = 1; attempt <= max; attempt++) {
      try {
        if (!cCell.modifiable.contains(cFn)) {
          throw TxApplyException('compensation function not in modifiable');
        }
        final result = cCell.apply(
          cFn,
          positionalArguments: call.compensatePositional,
          namedArguments: call.compensateNamed,
        );
        // void commands return null — only ApplyRejected is a soft fail
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

  Future<List<CompensationFailure>> _runCompensations(
      int fromIndexInclusive, {
        required bool onlyExecuted,
      }) async {
    final failures = <CompensationFailure>[];

    for (var i = _staged.length - 1; i >= fromIndexInclusive; i--) {
      final call = _staged[i];
      if (!call.hasCompensation) continue;
      if (onlyExecuted && !call.executed) continue;
      if (!onlyExecuted &&
          !call.executed &&
          !options.compensateIfNotExecuted) {
        continue;
      }

      try {
        await _executeCompensation(call);
      } catch (e, st) {
        final failure = CompensationFailure(
          cell: call.compensateCell!,
          function: call.compensateFunction,
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

  Future<void> _compensateExecutedOnly() async {
    await _runCompensations(0, onlyExecuted: true);
  }

  @override
  Future<void> rollback({Object? savepoint}) async {
    if (!_begun) return;

    if (savepoint is _TxSavepoint) {
      final i = savepoint.index.clamp(0, _staged.length);
      await _runCompensations(
        i,
        onlyExecuted: !options.compensateIfNotExecuted,
      );
      _staged.removeRange(i, _staged.length);
      _event(TxApplyRolledBack(savepoint));
      return;
    }

    await _runCompensations(
      0,
      onlyExecuted: !options.compensateIfNotExecuted,
    );
    _staged.clear();
    _finished = true;
    _event(const TxApplyRolledBack());
  }

  @override
  Future<void> commit() async {
    _ensureOpen();

    for (final call in _staged) {
      if (!call.cell.modifiable.contains(call.function)) {
        _event(TxApplyRejected(call.cell, 'not in modifiable at commit'));
        await rollback();
        throw TxApplyException('function not modifiable at commit');
      }
      if (call.hasCompensation) {
        final cCell = call.compensateCell!;
        final cFn = call.compensateFunction!;
        if (!cCell.modifiable.contains(cFn)) {
          await rollback();
          throw TxApplyException('compensate not modifiable at commit');
        }
      }
    }

    try {
      for (final call in _staged) {
        final result = call.cell.apply(
          call.function,
          positionalArguments: call.positionalArguments,
          namedArguments: call.namedArguments,
        );

        // FIX: void → null is OK. Only ApplyRejected is a soft integrity fail.
        if (_isApplyRejected(result) && options.stopOnFirstFailure) {
          _event(TxApplyRejected(call.cell, 'ApplyRejected'));
          await _compensateExecutedOnly();
          _finished = true;
          _staged.clear();
          throw TxApplyException('apply rejected by integrity gate');
        }

        call.executed = true;
      }
    } on TxApplyCompensationException {
      _finished = true;
      _staged.clear();
      rethrow;
    } catch (e, st) {
      // Domain errors (e.g. insufficient funds) land here
      try {
        await _compensateExecutedOnly();
      } on TxApplyCompensationException catch (ce) {
        _finished = true;
        _staged.clear();
        Error.throwWithStackTrace(
          TxApplyException('commit failed and compensation also failed', ce),
          st,
        );
      }
      _finished = true;
      _staged.clear();
      Error.throwWithStackTrace(TxApplyException('commit failed', e), st);
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

ApplyTransactionScope _txApply([
  TxApplyOptions options = const TxApplyOptions(),
]) =>
    _ApplyTransactionScopeImpl(options);