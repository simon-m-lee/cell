// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that keep or drop pulses (Rx `filter` and family).
///
/// | Operator | Input → Output | Async | Notes |
/// |---|---|---|---|
/// | [Filter] | 1 → 0..1 | No | predicate |
/// | [AsyncFilter] | 1 → 0..1 | Yes | sequential |
/// | [AsyncFilterConcurrent] | 1 → 0..1 | Yes | completion order |
/// | [AsyncFilterLatest] | 1 → 0..1 | Yes | latest only |
/// | [AsyncFilterWithRetry] | 1 → 0..1 | Yes | retries |
/// | [AsyncFilterWithTimeout] | 1 → 0..1 | Yes | timeout drop |
/// | [AsyncFilterWithFallback] | 1 → 0..1 | Yes | optional pass on error |
/// | [FilterNotNull] | 1 → 0..1 | No | drop null |
/// | [FilterType] | 1 → 0..1 | No | `is T` |
/// | [FilterAllowed] / [FilterBlocked] | 1 → 0..1 | No | set membership |
/// | [FilterByTime] | 1 → 0..1 | Timer | min gap |
///
/// Time gates live in `debounce.dart` / `throttle.dart`. Count gates
/// live in `take.dart` / `skip.dart`. Uniqueness lives in `distinct.dart`.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` below for console output.
///
/// ### Choosing a time operator
/// - [FilterByTime] — minimum spacing, first value immediate
/// - `Debounce` (`debounce.dart`) — last value after silence
/// - `Throttle` (`throttle.dart`) — leading / trailing window

// ─────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────

typedef FilterErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse? _typedOrError<S>(
  Pulse pulse, {
  FilterErrorHandler? onError,
  bool allowNull = false,
}) {
  final payload = pulse.payload;
  if (payload == null) {
    if (allowNull && null is S) return pulse;
    return null;
  }
  if (payload is! S) {
    onError?.call(
      FormatException('Expected payload of type $S, got ${payload.runtimeType}'),
      StackTrace.current,
    );
    return null;
  }
  return pulse;
}

Pulse _mark(Pulse pulse, String step) => pulse.withStep(step);

Pulse<S> _fromPayload<S>(S value, Pulse sourcePulse, Cell? cell, String step) {
  return Pulse<S>(
    value,
    source: cell ?? sourcePulse.source,
    type: sourcePulse.type,
    priority: sourcePulse.priority,
    step: step,
  );
}

// ─────────────────────────────────────────────────────────────
// Core filters
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that keeps pulses whose payload satisfies a
/// synchronous [predicate] (Rx `filter` / `where`).
///
/// 1 → 0..1, order preserved. Type mismatches are dropped and reported
/// via [onError]. Passing pulses are tagged with `withStep('Filter')`.
///
/// ### When to use
/// - Validation and range checks
/// - Noise reduction before a downstream observer
/// - Early drop so later async work is never scheduled
///
/// ### How it works
/// 1. The payload is type-checked against [S].
/// 2. [predicate] runs synchronously.
/// 3. `true` forwards the pulse; `false` or a thrown error drops it.
///
/// ### Example
/// ```dart
/// final numbers = Cell.ingress<int>();
/// final evens = Filter<int>((n) => n.isEven).toHandle(source: numbers.cell);
/// await numbers.emitAsync(2);
/// ```
///
/// ### See Also:
/// [AsyncFilter], [FilterNotNull], [FilterType]
class Filter<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Filter(
    bool Function(S value) predicate, {
    FilterErrorHandler? onError,
    dynamic user,
  }) : super(
          (pulse, {cell, user}) {
            final typed = _typedOrError<S>(pulse, onError: onError);
            if (typed == null) return null;
            try {
              return predicate(typed.payload as S) ? _mark(typed, 'Filter') : null;
            } catch (e, stack) {
              onError?.call(e, stack);
              return null;
            }
          },
          user: user,
        );
}

/// Sequential async filter. Each predicate completes before the next starts.
///
/// Emissions stay in input order. Failures go to [onError] and drop the pulse.
class AsyncFilter<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncFilter(
    FutureOr<bool> Function(S value) predicate, {
    FilterErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _AsyncQueueState();
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;

              state.enqueue(() async {
                try {
                  if (await predicate(typed.payload as S)) {
                    future!(result: _mark(typed, 'AsyncFilter'), token: token);
                  }
                } catch (e, stack) {
                  onError?.call(e, stack);
                }
              });
              return null;
            };
          })(),
          user: user,
        );
}

/// Concurrent async filter. Predicates run in parallel; emission order is
/// completion order, not input order.
class AsyncFilterConcurrent<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncFilterConcurrent(
    FutureOr<bool> Function(S value) predicate, {
    FilterErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (pulse, {cell, user, future, token}) {
            final typed = _typedOrError<S>(pulse, onError: onError);
            if (typed == null) return null;

            Future<void>(() async {
              try {
                if (await predicate(typed.payload as S)) {
                  future!(
                    result: _mark(typed, 'AsyncFilterConcurrent'),
                    token: token,
                  );
                }
              } catch (e, stack) {
                onError?.call(e, stack);
              }
            });
            return null;
          },
          user: user,
        );
}

/// Only the latest in-flight predicate may emit. Stale results are ignored.
class AsyncFilterLatest<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncFilterLatest(
    FutureOr<bool> Function(S value) predicate, {
    FilterErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _GenerationState();
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;

              final gen = ++state.generation;
              Future<void>(() async {
                try {
                  final ok = await predicate(typed.payload as S);
                  if (!ok || gen != state.generation) return;
                  future!(
                    result: _mark(typed, 'AsyncFilterLatest'),
                    token: token,
                  );
                } catch (e, stack) {
                  if (gen == state.generation) onError?.call(e, stack);
                }
              });
              return null;
            };
          })(),
          user: user,
        );
}

/// Retries a failing async predicate up to [maxAttempts] times.
class AsyncFilterWithRetry<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncFilterWithRetry(
    FutureOr<bool> Function(S value) predicate, {
    int maxAttempts = 3,
    Duration delay = const Duration(milliseconds: 50),
    FilterErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _AsyncQueueState();
            final attempts = maxAttempts < 1 ? 1 : maxAttempts;
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;

              state.enqueue(() async {
                Object? lastError;
                StackTrace? lastStack;
                for (var i = 0; i < attempts; i++) {
                  try {
                    if (await predicate(typed.payload as S)) {
                      future!(
                        result: _mark(typed, 'AsyncFilterWithRetry'),
                        token: token,
                      );
                    }
                    return;
                  } catch (e, stack) {
                    lastError = e;
                    lastStack = stack;
                    if (i < attempts - 1 && delay > Duration.zero) {
                      await Future<void>.delayed(delay);
                    }
                  }
                }
                if (lastError != null) onError?.call(lastError, lastStack);
              });
              return null;
            };
          })(),
          user: user,
        );
}

/// Drops the pulse if the predicate does not finish within [timeout].
class AsyncFilterWithTimeout<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncFilterWithTimeout(
    FutureOr<bool> Function(S value) predicate, {
    required Duration timeout,
    FilterErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _AsyncQueueState();
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;

              state.enqueue(() async {
                try {
                  final ok = await Future<bool>.sync(
                    () => predicate(typed.payload as S),
                  ).timeout(timeout);
                  if (ok) {
                    future!(
                      result: _mark(typed, 'AsyncFilterWithTimeout'),
                      token: token,
                    );
                  }
                } on TimeoutException catch (e, stack) {
                  onError?.call(e, stack);
                } catch (e, stack) {
                  onError?.call(e, stack);
                }
              });
              return null;
            };
          })(),
          user: user,
        );
}

/// On predicate error, keeps the pulse if [fallback] is true (default: drop).
class AsyncFilterWithFallback<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncFilterWithFallback(
    FutureOr<bool> Function(S value) predicate, {
    bool fallback = false,
    FilterErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _AsyncQueueState();
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;

              state.enqueue(() async {
                try {
                  if (await predicate(typed.payload as S)) {
                    future!(
                      result: _mark(typed, 'AsyncFilterWithFallback'),
                      token: token,
                    );
                  }
                } catch (e, stack) {
                  onError?.call(e, stack);
                  if (fallback) {
                    future!(
                      result: _mark(typed, 'AsyncFilterWithFallback.fallback'),
                      token: token,
                    );
                  }
                }
              });
              return null;
            };
          })(),
          user: user,
        );
}

/// Drops null payloads and keeps values of type [S].
class FilterNotNull<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  FilterNotNull({
    FilterErrorHandler? onError,
    dynamic user,
  }) : super(
          (pulse, {cell, user}) {
            final payload = pulse.payload;
            if (payload == null) return null;
            if (payload is! S) {
              onError?.call(
                FormatException(
                  'Expected payload of type $S, got ${payload.runtimeType}',
                ),
                StackTrace.current,
              );
              return null;
            }
            return _mark(pulse, 'FilterNotNull');
          },
          user: user,
        );
}

/// Keeps payloads that are a [T] (runtime type narrowing).
class FilterType<S, T extends S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  FilterType({
    FilterErrorHandler? onError,
    dynamic user,
  }) : super(
          (pulse, {cell, user}) {
            if (pulse.payload is T) return _mark(pulse, 'FilterType');
            return null;
          },
          user: user,
        );
}

/// Whitelist. O(1) [Set] membership.
class FilterAllowed<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  FilterAllowed({
    required Set<S> allowed,
    FilterErrorHandler? onError,
    dynamic user,
  }) : super(
          (pulse, {cell, user}) {
            final typed = _typedOrError<S>(pulse, onError: onError);
            if (typed == null) return null;
            return allowed.contains(typed.payload as S)
                ? _mark(typed, 'FilterAllowed')
                : null;
          },
          user: user,
        );
}

/// Blacklist. O(1) [Set] membership.
class FilterBlocked<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  FilterBlocked({
    required Set<S> blocked,
    FilterErrorHandler? onError,
    dynamic user,
  }) : super(
          (pulse, {cell, user}) {
            final typed = _typedOrError<S>(pulse, onError: onError);
            if (typed == null) return null;
            return blocked.contains(typed.payload as S)
                ? null
                : _mark(typed, 'FilterBlocked');
          },
          user: user,
        );
}

/// Time-gated pass. First value is immediate; later values must wait [duration]
/// since the last *emission*. Values that arrive early replace a pending
/// trailing emission.
class FilterByTime<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  FilterByTime(
    Duration duration, {
    FilterErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _TimeGateState<S>();
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              final payload = typed.payload as S;

              if (duration == Duration.zero) {
                return _mark(typed, 'FilterByTime');
              }

              final now = DateTime.now();
              if (state.lastEmitted == null) {
                state.lastEmitted = now;
                state.clearTimer();
                return _mark(typed, 'FilterByTime');
              }

              final elapsed = now.difference(state.lastEmitted!);
              if (elapsed >= duration) {
                state.lastEmitted = now;
                state.clearPending();
                return _mark(typed, 'FilterByTime');
              }

              state.pending = payload;
              state.pendingPulse = typed;
              state.timer?.cancel();
              state.timer = Timer(duration - elapsed, () {
                final value = state.pending;
                final src = state.pendingPulse;
                state.clearPending();
                if (value == null || src == null) return;
                state.lastEmitted = DateTime.now();
                future!(
                  result: _fromPayload(value, src, cell, 'FilterByTime.pending'),
                  token: token,
                );
              });
              return null;
            };
          })(),
          user: user,
        );
}

// Distinct → distinct.dart. Debounce → debounce.dart.
// Throttle → throttle.dart. Take / Skip → take.dart / skip.dart.

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

class _TimeGateState<S> {
  DateTime? lastEmitted;
  S? pending;
  Pulse? pendingPulse;
  Timer? timer;

  void clearTimer() {
    timer?.cancel();
    timer = null;
  }

  void clearPending() {
    pending = null;
    pendingPulse = null;
    clearTimer();
  }
}

class _GenerationState {
  int generation = 0;
}

class _AsyncQueueState {
  Future<void> tail = Future<void>.value();

  void enqueue(Future<void> Function() job) {
    tail = tail.then((_) => job()).catchError((_) {});
  }
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// Demonstration of the filter instruction family.
///
/// Distinct, debounce, throttle, take and skip live in their own files.
///
/// ### Expected console output:
/// ```text
/// ── Filter Operators Demo ──────────────────────────────────────
///
/// 1. Filter - Even Numbers
///    [Filter] 2
///    [Filter] 4
///
/// 2. FilterNotNull - Remove Nulls
///    [FilterNotNull] hello
///
/// 3. FilterType - Type Filtering
///    [FilterType] hello
///
/// 4. AsyncFilter - Async Validation
///    [AsyncFilter] john is available
///    [AsyncFilter] jane is available
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Filter Operators Demo ──────────────────────────────────────\n');

  print('1. Filter - Even Numbers');
  final numbers = Cell.ingress<int>();
  final evens = Filter<int>((n) => n % 2 == 0).toHandle(source: numbers.cell);
  final filterObs = Cell.observe(
    source: evens.cell,
    effect: (Pulse p) => print('   [Filter] ${p.payload}'),
  );
  for (var i = 1; i <= 5; i++) {
    await numbers.emitAsync(i);
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));
  filterObs.stop();
  print('');

  print('2. FilterNotNull - Remove Nulls');
  final nullable = Cell.ingress<String?>();
  final nonNull = FilterNotNull<String>().toHandle(source: nullable.cell);
  final notNullObs = Cell.observe(
    source: nonNull.cell,
    effect: (Pulse p) => print('   [FilterNotNull] ${p.payload}'),
  );
  await nullable.emitAsync(null);
  await nullable.emitAsync('hello');
  await nullable.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  notNullObs.stop();
  print('');

  print('3. FilterType - Type Filtering');
  final mixed = Cell.ingress<Object>();
  final strings = FilterType<Object, String>().toHandle(source: mixed.cell);
  final typeObs = Cell.observe(
    source: strings.cell,
    effect: (Pulse p) => print('   [FilterType] ${p.payload}'),
  );
  await mixed.emitAsync(42);
  await mixed.emitAsync('hello');
  await mixed.emitAsync(true);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  typeObs.stop();
  print('');

  print('4. AsyncFilter - Async Validation');
  final usernames = Cell.ingress<String>();
  final available = AsyncFilter<String>(
    (username) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return !['taken', 'reserved'].contains(username);
    },
  ).toHandle(source: usernames.cell);
  final asyncFilterObs = Cell.observe(
    source: available.cell,
    effect: (Pulse p) => print('   [AsyncFilter] ${p.payload} is available'),
  );
  await usernames.emitAsync('john');
  await usernames.emitAsync('taken');
  await usernames.emitAsync('jane');
  await Future<void>.delayed(const Duration(milliseconds: 150));
  asyncFilterObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}
