// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

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
/// | [Distinct] | 1 → 0..1 | No | consecutive |
/// | [DistinctAll] | 1 → 0..1 | No | global seen-set |
/// | [FilterType] | 1 → 0..1 | No | `is T` |
/// | [FilterAllowed] / [FilterBlocked] | 1 → 0..1 | No | set membership |
/// | [FilterByTime] | 1 → 0..1 | Timer | min gap |
/// | [Throttle] | 1 → 0..1 | Timer | leading / trailing |
/// | [Debounce] / [DebounceLeading] | 1 → 0..1 | Timer | silence window |
/// | [TakeWhile] / [SkipWhile] | 1 → 0..1 | No | sticky gate |
/// | [Take] / [Skip] | 1 → 0..1 | No | count |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` below for console output.
///
/// ### Choosing a time operator
/// - [Debounce] — search-as-you-type (last value after silence)
/// - [DebounceLeading] — first click immediate, then debounce
/// - [Throttle] — scroll / API rate limit
/// - [FilterByTime] — minimum spacing, first value immediate

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
/// [AsyncFilter], [FilterNotNull], [FilterType], [Distinct]
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

/// Suppresses consecutive duplicates. Non-adjacent repeats still pass.
class Distinct<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Distinct({
    bool Function(S a, S b)? comparator,
    FilterErrorHandler? onError,
    dynamic user,
  }) : super(
          (() {
            final state = _DistinctState<S>();
            final eq = comparator ?? (S a, S b) => a == b;
            return (pulse, {cell, user}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              final payload = typed.payload as S;
              if (state.hasPrevious && eq(state.previous as S, payload)) {
                return null;
              }
              state.previous = payload;
              state.hasPrevious = true;
              return _mark(typed, 'Distinct');
            };
          })(),
          user: user,
        );
}

/// Suppresses any value already seen (global distinct), keyed by [keyOf].
class DistinctAll<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  DistinctAll({
    Object? Function(S value)? keyOf,
    FilterErrorHandler? onError,
    dynamic user,
  }) : super(
          (() {
            final seen = <Object?>{};
            return (pulse, {cell, user}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              final payload = typed.payload as S;
              final key = keyOf == null ? payload : keyOf(payload);
              if (!seen.add(key)) return null;
              return _mark(typed, 'DistinctAll');
            };
          })(),
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

/// Rate-limits emissions to at most one leading and/or trailing value per
/// [duration] window.
///
/// - `leading: true` — first pulse in a window emits immediately
/// - `trailing: true` — last pulse in the window emits when the window closes
class Throttle<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Throttle(
    Duration duration, {
    bool leading = true,
    bool trailing = true,
    FilterErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _TimeGateState<S>();

            void armTrailing(
              void Function({required Pulse? result, required dynamic token})?
                  future,
              dynamic token,
              Cell? cell,
            ) {
              if (!trailing) return;
              final elapsed = state.lastEmitted == null
                  ? duration
                  : DateTime.now().difference(state.lastEmitted!);
              final remaining =
                  elapsed >= duration ? duration : duration - elapsed;
              state.timer?.cancel();
              state.timer = Timer(remaining, () {
                final value = state.pending;
                final src = state.pendingPulse;
                state.clearPending();
                state.timer = null;
                if (value == null || src == null || future == null) return;
                state.lastEmitted = DateTime.now();
                future(
                  result: _fromPayload(value, src, cell, 'Throttle.trailing'),
                  token: token,
                );
              });
            }

            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              final payload = typed.payload as S;
              final now = DateTime.now();

              if (state.lastEmitted == null) {
                state.lastEmitted = now;
                if (leading) {
                  if (trailing) armTrailing(future, token, cell);
                  return _mark(typed, 'Throttle.leading');
                }
                state.pending = payload;
                state.pendingPulse = typed;
                armTrailing(future, token, cell);
                return null;
              }

              final elapsed = now.difference(state.lastEmitted!);
              if (elapsed >= duration) {
                state.lastEmitted = now;
                state.clearPending();
                if (trailing) armTrailing(future, token, cell);
                return _mark(typed, 'Throttle.window');
              }

              if (trailing) {
                state.pending = payload;
                state.pendingPulse = typed;
                if (state.timer?.isActive != true) {
                  armTrailing(future, token, cell);
                }
              }
              return null;
            };
          })(),
          user: user,
        );
}

/// Emits the last value after [duration] of silence.
class Debounce<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Debounce(
    Duration duration, {
    FilterErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _TimeGateState<S>();
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;

              state.pending = typed.payload as S;
              state.pendingPulse = typed;
              state.timer?.cancel();
              state.timer = Timer(duration, () {
                final value = state.pending;
                final src = state.pendingPulse;
                state.clearPending();
                state.timer = null;
                if (value == null || src == null) return;
                future!(
                  result: _fromPayload(value, src, cell, 'Debounce'),
                  token: token,
                );
              });
              return null;
            };
          })(),
          user: user,
        );
}

/// Emits the first pulse immediately, then debounces the rest of the burst.
class DebounceLeading<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  DebounceLeading(
    Duration duration, {
    FilterErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _TimeGateState<S>();
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;

              final timerActive = state.timer?.isActive == true;
              if (!timerActive) {
                state.clearPending();
                future!(result: _mark(typed, 'DebounceLeading.leading'), token: token);
                state.timer = Timer(duration, () {
                  state.timer = null;
                });
                return null;
              }

              state.pending = typed.payload as S;
              state.pendingPulse = typed;
              state.timer?.cancel();
              state.timer = Timer(duration, () {
                final value = state.pending;
                final src = state.pendingPulse;
                state.clearPending();
                state.timer = null;
                if (value == null || src == null) return;
                future!(
                  result: _fromPayload(value, src, cell, 'DebounceLeading.trailing'),
                  token: token,
                );
              });
              return null;
            };
          })(),
          user: user,
        );
}

/// Passes values while [predicate] is true; then stays closed.
class TakeWhile<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  TakeWhile(
    bool Function(S value) predicate, {
    FilterErrorHandler? onError,
    dynamic user,
  }) : super(
          (() {
            final state = _GateState();
            return (pulse, {cell, user}) {
              if (state.done) return null;
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              try {
                if (!predicate(typed.payload as S)) {
                  state.done = true;
                  return null;
                }
                return _mark(typed, 'TakeWhile');
              } catch (e, stack) {
                onError?.call(e, stack);
                state.done = true;
                return null;
              }
            };
          })(),
          user: user,
        );
}

/// Drops values while [predicate] is true; then stays open.
class SkipWhile<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  SkipWhile(
    bool Function(S value) predicate, {
    FilterErrorHandler? onError,
    dynamic user,
  }) : super(
          (() {
            final state = _GateState();
            return (pulse, {cell, user}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              if (state.done) return _mark(typed, 'SkipWhile');
              try {
                if (predicate(typed.payload as S)) return null;
                state.done = true;
                return _mark(typed, 'SkipWhile');
              } catch (e, stack) {
                onError?.call(e, stack);
                state.done = true;
                return _mark(typed, 'SkipWhile');
              }
            };
          })(),
          user: user,
        );
}

/// First [count] values only.
class Take<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Take(
    int count, {
    FilterErrorHandler? onError,
    dynamic user,
  }) : super(
          (() {
            final state = _CountState();
            final n = count < 0 ? 0 : count;
            return (pulse, {cell, user}) {
              if (state.n >= n) return null;
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              state.n++;
              return _mark(typed, 'Take');
            };
          })(),
          user: user,
        );
}

/// Drops the first [count] values, then passes everything.
class Skip<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Skip(
    int count, {
    FilterErrorHandler? onError,
    dynamic user,
  }) : super(
          (() {
            final state = _CountState();
            final n = count < 0 ? 0 : count;
            return (pulse, {cell, user}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              if (state.n < n) {
                state.n++;
                return null;
              }
              return _mark(typed, 'Skip');
            };
          })(),
          user: user,
        );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

class _DistinctState<S> {
  S? previous;
  bool hasPrevious = false;
}

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

class _GateState {
  bool done = false;
}

class _CountState {
  int n = 0;
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
/// ### Expected console output:
/// ```text
/// ── Filter Operators Demo ──────────────────────────────────────
///
/// 1. Filter - Even Numbers
///    [Filter] 2
///    [Filter] 4
///
/// 2. Distinct - Unique Values
///    [Distinct] 1
///    [Distinct] 2
///    [Distinct] 3
///
/// 3. FilterNotNull - Remove Nulls
///    [FilterNotNull] hello
///
/// 4. FilterType - Type Filtering
///    [FilterType] hello
///
/// 5. Debounce - Search
///    [Debounce] hello
///
/// 6. TakeWhile - Conditional Take
///    [TakeWhile] 1
///    [TakeWhile] 2
///    [TakeWhile] 3
///    [TakeWhile] 4
///
/// 7. SkipWhile - Conditional Skip
///    [SkipWhile] 5
///    [SkipWhile] 6
///    [SkipWhile] 7
///
/// 8. Take - First N Values
///    [Take] 1
///    [Take] 2
///    [Take] 3
///
/// 9. Skip - First N Values
///    [Skip] 3
///    [Skip] 4
///    [Skip] 5
///
/// 10. Throttle - Rate Limiting
///    [Throttle] 1
///    [Throttle] 5
///
/// 11. AsyncFilter - Async Validation
///    [AsyncFilter] john is available
///    [AsyncFilter] jane is available
///
/// ── finished ──────────────────────────────────────────────────
/// ```
///
/// ### How to run
/// ```dart
/// void main() => main();
/// ```
///
/// ### What it demonstrates
/// 1. **Filter** — even numbers only.
/// 2. **Distinct** — consecutive duplicates removed.
/// 3. **FilterNotNull** — nulls dropped.
/// 4. **FilterType** — `Object` stream narrowed to `String`.
/// 5. **Debounce** — only the last search term after silence.
/// 6. **TakeWhile** — values while `n < 5`, then closed.
/// 7. **SkipWhile** — skip until `n >= 5`.
/// 8. **Take(3)** / **Skip(2)** — count gates.
/// 9. **Throttle** — leading + trailing in a 150ms window.
/// 10. **AsyncFilter** — sequential async validation.
///
/// ### Key takeaways
/// - All filters are 1 → 0..1 and preserve input order unless documented
///   otherwise (concurrent / latest variants).
/// - Time operators use real [Timer]s; wait in demos and tests.
/// - Inject with [IngressHandle.emitAsync], not `Cell.emitAsync`.
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

  print('2. Distinct - Unique Values');
  final duplicates = Cell.ingress<int>();
  final unique = Distinct<int>().toHandle(source: duplicates.cell);
  final distinctObs = Cell.observe(
    source: unique.cell,
    effect: (Pulse p) => print('   [Distinct] ${p.payload}'),
  );
  await duplicates.emitAsync(1);
  await duplicates.emitAsync(1);
  await duplicates.emitAsync(2);
  await duplicates.emitAsync(2);
  await duplicates.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  distinctObs.stop();
  print('');

  print('3. FilterNotNull - Remove Nulls');
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

  print('4. FilterType - Type Filtering');
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

  print('5. Debounce - Search');
  final searchInput = Cell.ingress<String>();
  final debounced = Debounce<String>(
    const Duration(milliseconds: 200),
  ).toHandle(source: searchInput.cell);
  final debounceObs = Cell.observe(
    source: debounced.cell,
    effect: (Pulse p) => print('   [Debounce] ${p.payload}'),
  );
  await searchInput.emitAsync('h');
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await searchInput.emitAsync('he');
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await searchInput.emitAsync('hel');
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await searchInput.emitAsync('hell');
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await searchInput.emitAsync('hello');
  await Future<void>.delayed(const Duration(milliseconds: 250));
  debounceObs.stop();
  print('');

  print('6. TakeWhile - Conditional Take');
  final takeNumbers = Cell.ingress<int>();
  final takeWhile =
      TakeWhile<int>((n) => n < 5).toHandle(source: takeNumbers.cell);
  final takeWhileObs = Cell.observe(
    source: takeWhile.cell,
    effect: (Pulse p) => print('   [TakeWhile] ${p.payload}'),
  );
  for (var i = 1; i <= 7; i++) {
    await takeNumbers.emitAsync(i);
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));
  takeWhileObs.stop();
  print('');

  print('7. SkipWhile - Conditional Skip');
  final skipNumbers = Cell.ingress<int>();
  final skipWhile =
      SkipWhile<int>((n) => n < 5).toHandle(source: skipNumbers.cell);
  final skipWhileObs = Cell.observe(
    source: skipWhile.cell,
    effect: (Pulse p) => print('   [SkipWhile] ${p.payload}'),
  );
  for (var i = 1; i <= 7; i++) {
    await skipNumbers.emitAsync(i);
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));
  skipWhileObs.stop();
  print('');

  print('8. Take - First N Values');
  final takeNumbers2 = Cell.ingress<int>();
  final take3 = Take<int>(3).toHandle(source: takeNumbers2.cell);
  final takeObs = Cell.observe(
    source: take3.cell,
    effect: (Pulse p) => print('   [Take] ${p.payload}'),
  );
  for (var i = 1; i <= 5; i++) {
    await takeNumbers2.emitAsync(i);
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));
  takeObs.stop();
  print('');

  print('9. Skip - First N Values');
  final skipNumbers2 = Cell.ingress<int>();
  final skip2 = Skip<int>(2).toHandle(source: skipNumbers2.cell);
  final skipObs = Cell.observe(
    source: skip2.cell,
    effect: (Pulse p) => print('   [Skip] ${p.payload}'),
  );
  for (var i = 1; i <= 5; i++) {
    await skipNumbers2.emitAsync(i);
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));
  skipObs.stop();
  print('');

  print('10. Throttle - Rate Limiting');
  final throttleInput = Cell.ingress<int>();
  final throttled = Throttle<int>(
    const Duration(milliseconds: 150),
    leading: true,
    trailing: true,
  ).toHandle(source: throttleInput.cell);
  final throttleObs = Cell.observe(
    source: throttled.cell,
    effect: (Pulse p) => print('   [Throttle] ${p.payload}'),
  );
  for (var i = 1; i <= 5; i++) {
    await throttleInput.emitAsync(i);
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
  await Future<void>.delayed(const Duration(milliseconds: 200));
  throttleObs.stop();
  print('');

  print('11. AsyncFilter - Async Validation');
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
