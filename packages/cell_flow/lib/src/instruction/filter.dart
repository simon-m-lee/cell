// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';

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

/// Callback signature for handling errors during filter operations.
///
/// ### When to use
/// Provide this to any filter operator that can fail. The callback
/// receives the error and its stack trace for logging or recovery.
///
/// ### Parameters
/// - [error]: The error that occurred during filtering.
/// - [stackTrace]: The stack trace at the point of failure.
typedef FilterErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// Internal helper that type-checks a pulse payload against type [S].
///
/// ### When to use
/// This is used internally by all filter operators. You don't need
/// to call it directly.
///
/// ### How it works
/// 1. If the payload is `null`, returns `null` (unless `allowNull` is true).
/// 2. If the payload is not of type [S], calls [onError] and returns `null`.
/// 3. Otherwise returns the original pulse.
///
/// ### Parameters
/// - [pulse]: The pulse to type-check.
/// - [onError]: Called when a type mismatch occurs.
/// - [allowNull]: If true, allows `null` payloads when `null is S`.
///
/// ### Returns
/// The original pulse if type-check passes, otherwise `null`.
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

/// Internal helper that adds a step to a pulse's trace.
///
/// ### When to use
/// Used internally to mark pulses that pass through a filter.
///
/// ### Parameters
/// - [pulse]: The pulse to mark.
/// - [step]: The step name to add to the trace.
///
/// ### Returns
/// A new pulse with the step added to its trace.
Pulse _mark(Pulse pulse, String step) => pulse.withStep(step);

/// Internal helper that creates a new pulse from a value.
///
/// ### When to use
/// Used internally to emit delayed or transformed values.
///
/// ### Parameters
/// - [value]: The payload value for the new pulse.
/// - [sourcePulse]: The source pulse providing metadata.
/// - [cell]: The source cell (optional).
/// - [step]: The step name to add to the trace.
///
/// ### Returns
/// A new [Pulse] with the given payload and metadata.
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
  /// Creates a synchronous filter instruction.
  ///
  /// ### Parameters
  /// - [predicate]: A synchronous function that returns `true` to keep the pulse.
  /// - [onError]: Optional callback for type mismatches or predicate errors.
  /// - [user]: Optional user metadata passed to the instruction.
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
///
/// ### When to use
/// - Async validation that must preserve input order
/// - Database checks where order matters
/// - API calls that depend on previous results
///
/// ### How it works
/// 1. Each incoming pulse is type-checked against [S].
/// 2. The [predicate] is awaited for each pulse in sequence.
/// 3. Only pulses where [predicate] returns `true` are emitted.
/// 4. If [predicate] throws, the pulse is dropped and [onError] is called.
///
/// ### Example
/// ```dart
/// final usernames = Cell.ingress<String>();
/// final available = AsyncFilter<String>(
///   (username) async => !await db.usernameExists(username),
/// ).toHandle(source: usernames.cell);
/// await usernames.emitAsync('john');
/// ```
///
/// ### See Also:
/// [Filter], [AsyncFilterConcurrent], [AsyncFilterLatest]
class AsyncFilter<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a sequential async filter instruction.
  ///
  /// ### Parameters
  /// - [predicate]: An async function that returns `true` to keep the pulse.
  /// - [onError]: Optional callback for type mismatches or predicate errors.
  /// - [user]: Optional user metadata passed to the instruction.
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
///
/// ### When to use
/// - High-throughput validation where order doesn't matter
/// - Parallel API checks
/// - Batch validation of independent items
///
/// ### How it works
/// 1. Each incoming pulse is type-checked against [S].
/// 2. The [predicate] is started immediately for each pulse.
/// 3. Results are emitted as they complete (unordered).
/// 4. If [predicate] throws, the pulse is dropped and [onError] is called.
///
/// ### Example
/// ```dart
/// final items = Cell.ingress<Item>();
/// final validItems = AsyncFilterConcurrent<Item>(
///   (item) async => await api.validateItem(item),
/// ).toHandle(source: items.cell);
/// ```
///
/// ### See Also:
/// [AsyncFilter], [AsyncFilterLatest]
class AsyncFilterConcurrent<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a concurrent async filter instruction.
  ///
  /// ### Parameters
  /// - [predicate]: An async function that returns `true` to keep the pulse.
  /// - [onError]: Optional callback for type mismatches or predicate errors.
  /// - [user]: Optional user metadata passed to the instruction.
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
///
/// ### When to use
/// - Search-as-you-type validation
/// - Real-time validation where only the latest matters
/// - User input validation that cancels previous checks
///
/// ### How it works
/// 1. Each incoming pulse is type-checked against [S].
/// 2. Each pulse gets a generation ID. Only the latest generation can emit.
/// 3. If a newer pulse arrives, older predicate results are ignored.
/// 4. If [predicate] throws and it's the latest generation, [onError] is called.
///
/// ### Example
/// ```dart
/// final search = Cell.ingress<String>();
/// final validSearch = AsyncFilterLatest<String>(
///   (query) async => await api.validateSearch(query),
/// ).toHandle(source: search.cell);
/// ```
///
/// ### See Also:
/// [AsyncFilter], [AsyncFilterConcurrent]
class AsyncFilterLatest<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a latest-only async filter instruction.
  ///
  /// ### Parameters
  /// - [predicate]: An async function that returns `true` to keep the pulse.
  /// - [onError]: Optional callback for type mismatches or predicate errors.
  /// - [user]: Optional user metadata passed to the instruction.
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
///
/// ### When to use
/// - Transient failures in validation (network timeouts, rate limits)
/// - External API validation that may fail temporarily
/// - Database checks that may have transient locks
///
/// ### How it works
/// 1. Each incoming pulse is type-checked against [S].
/// 2. The [predicate] is attempted up to [maxAttempts] times.
/// 3. Between attempts, waits for [delay] duration.
/// 4. If a retry succeeds, the pulse is emitted.
/// 5. If all retries fail, the pulse is dropped and [onError] is called.
///
/// ### Example
/// ```dart
/// final requests = Cell.ingress<String>();
/// final validated = AsyncFilterWithRetry<String>(
///   (id) async => await api.validateId(id),
///   maxAttempts: 3,
///   delay: Duration(milliseconds: 100),
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### See Also:
/// [AsyncFilter], [AsyncFilterWithTimeout]
class AsyncFilterWithRetry<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates an async filter with retry instruction.
  ///
  /// ### Parameters
  /// - [predicate]: An async function that returns `true` to keep the pulse.
  /// - [maxAttempts]: Maximum number of attempts. Defaults to 3.
  /// - [delay]: Delay between retry attempts. Defaults to 50ms.
  /// - [onError]: Optional callback for type mismatches or predicate errors.
  /// - [user]: Optional user metadata passed to the instruction.
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
///
/// ### When to use
/// - Time-sensitive validation that must complete within a deadline
/// - API validation with SLA requirements
/// - User-facing validation that must not hang
///
/// ### How it works
/// 1. Each incoming pulse is type-checked against [S].
/// 2. The [predicate] is started with a [timeout].
/// 3. If the predicate completes within the timeout and returns `true`, emit.
/// 4. If the predicate times out, the pulse is dropped and [onError] is called.
/// 5. If the predicate throws, the pulse is dropped and [onError] is called.
///
/// ### Example
/// ```dart
/// final requests = Cell.ingress<String>();
/// val validated = AsyncFilterWithTimeout<String>(
///   (id) async => await slowApi.validateId(id),
///   timeout: Duration(seconds: 5),
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### See Also:
/// [AsyncFilter], [AsyncFilterWithRetry]
class AsyncFilterWithTimeout<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates an async filter with timeout instruction.
  ///
  /// ### Parameters
  /// - [predicate]: An async function that returns `true` to keep the pulse.
  /// - [timeout]: Maximum time allowed for the predicate to complete.
  /// - [onError]: Optional callback for timeouts or predicate errors.
  /// - [user]: Optional user metadata passed to the instruction.
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
///
/// ### When to use
/// - Graceful degradation when validation fails
/// - Default accept on error (e.g., allow through if can't validate)
/// - Resilience in validation pipelines
///
/// ### How it works
/// 1. Each incoming pulse is type-checked against [S].
/// 2. The [predicate] is awaited.
/// 3. If the predicate returns `true`, the pulse is emitted.
/// 4. If the predicate throws and [fallback] is `true`, the pulse is emitted.
/// 5. If the predicate throws and [fallback] is `false`, the pulse is dropped.
///
/// ### Example
/// ```dart
/// final requests = Cell.ingress<String>();
/// final validated = AsyncFilterWithFallback<String>(
///   (id) async => await api.validateId(id),
///   fallback: true, // Allow through on validation errors
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### See Also:
/// [AsyncFilter], [AsyncFilterWithRetry]
class AsyncFilterWithFallback<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates an async filter with fallback instruction.
  ///
  /// ### Parameters
  /// - [predicate]: An async function that returns `true` to keep the pulse.
  /// - [fallback]: If `true`, keeps the pulse when [predicate] throws.
  ///   Defaults to `false` (drop on error).
  /// - [onError]: Optional callback for type mismatches or predicate errors.
  /// - [user]: Optional user metadata passed to the instruction.
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
///
/// ### When to use
/// - Removing null values from a stream
/// - Data cleaning before processing
/// - Optional value extraction
///
/// ### How it works
/// 1. Each incoming pulse is checked for a null payload.
/// 2. If payload is null, the pulse is dropped.
/// 3. If payload is of type [S], the pulse is emitted.
/// 4. If payload is not of type [S], [onError] is called.
///
/// ### Example
/// ```dart
/// final nullable = Cell.ingress<String?>();
/// final nonNull = FilterNotNull<String>().toHandle(source: nullable.cell);
/// await nullable.emitAsync('hello'); // Emitted
/// await nullable.emitAsync(null);    // Dropped
/// ```
///
/// ### See Also:
/// [Filter], [FilterType]
class FilterNotNull<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a filter that removes null payloads.
  ///
  /// ### Parameters
  /// - [onError]: Optional callback for type mismatches.
  /// - [user]: Optional user metadata passed to the instruction.
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
///
/// ### When to use
/// - Filtering mixed-type streams
/// - Type-safe extraction from union types
/// - Processing only specific subtypes
///
/// ### How it works
/// 1. Each incoming pulse is checked if its payload is of type [T].
/// 2. If yes, the pulse is emitted with step `FilterType`.
/// 3. If no, the pulse is dropped.
///
/// ### Example
/// ```dart
/// final mixed = Cell.ingress<Object>();
/// final strings = FilterType<Object, String>().toHandle(source: mixed.cell);
/// await mixed.emitAsync('hello'); // Emitted
/// await mixed.emitAsync(42);      // Dropped
/// ```
///
/// ### Type Parameters
/// - [S]: The supertype of the input payload.
/// - [T]: The subtype to keep (must extend [S]).
///
/// ### See Also:
/// [Filter], [FilterNotNull]
class FilterType<S, T extends S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a type filter instruction.
  ///
  /// ### Parameters
  /// - [onError]: Optional callback for errors.
  /// - [user]: Optional user metadata passed to the instruction.
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
///
/// Keeps pulses whose payload is in the [allowed] set.
///
/// ### When to use
/// - Validating against a list of acceptable values
/// - Permission checks (allowed users, roles)
/// - Feature flags (allowed features)
///
/// ### How it works
/// 1. Each incoming pulse is type-checked against [S].
/// 2. The payload is checked for membership in [allowed].
/// 3. If present, the pulse is emitted with step `FilterAllowed`.
/// 4. If not present, the pulse is dropped.
///
/// ### Example
/// ```dart
/// final actions = Cell.ingress<String>();
/// final allowed = FilterAllowed<String>(
///   allowed: {'read', 'write', 'delete'},
/// ).toHandle(source: actions.cell);
/// await actions.emitAsync('read');  // Emitted
/// await actions.emitAsync('admin'); // Dropped
/// ```
///
/// ### See Also:
/// [FilterBlocked]
class FilterAllowed<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a whitelist filter instruction.
  ///
  /// ### Parameters
  /// - [allowed]: The set of allowed values. O(1) membership.
  /// - [onError]: Optional callback for type mismatches.
  /// - [user]: Optional user metadata passed to the instruction.
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
///
/// Keeps pulses whose payload is NOT in the [blocked] set.
///
/// ### When to use
/// - Blocking specific values from a stream
/// - Exclusion lists (blocked users, roles)
/// - Feature flag overrides (blocked features)
///
/// ### How it works
/// 1. Each incoming pulse is type-checked against [S].
/// 2. The payload is checked for membership in [blocked].
/// 3. If NOT present, the pulse is emitted with step `FilterBlocked`.
/// 4. If present, the pulse is dropped.
///
/// ### Example
/// ```dart
/// final actions = Cell.ingress<String>();
/// final allowed = FilterBlocked<String>(
///   blocked: {'admin', 'sudo'},
/// ).toHandle(source: actions.cell);
/// await actions.emitAsync('read');  // Emitted
/// await actions.emitAsync('admin'); // Dropped
/// ```
///
/// ### See Also:
/// [FilterAllowed]
class FilterBlocked<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a blacklist filter instruction.
  ///
  /// ### Parameters
  /// - [blocked]: The set of blocked values. O(1) membership.
  /// - [onError]: Optional callback for type mismatches.
  /// - [user]: Optional user metadata passed to the instruction.
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
///
/// ### When to use
/// - Minimum time between emissions (rate limiting)
/// - Throttling with trailing replacement
/// - Event debouncing with immediate first response
///
/// ### How it works
/// 1. The first pulse is emitted immediately.
/// 2. Subsequent pulses must wait [duration] since the last emission.
/// 3. If a pulse arrives during the wait, it replaces the pending value.
/// 4. When the wait expires, the latest pending value is emitted.
///
/// ### Example
/// ```dart
/// final events = Cell.ingress<String>();
/// val rateLimited = FilterByTime<String>(
///   Duration(milliseconds: 300),
/// ).toHandle(source: events.cell);
/// await events.emitAsync('first');  // Emitted immediately
/// await events.emitAsync('second'); // Waits 300ms, then emitted
/// ```
///
/// ### See Also:
/// - `Debounce` in `debounce.dart` (last value after silence)
/// - `Throttle` in `throttle.dart` (leading/trailing window)
class FilterByTime<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a time-gated filter instruction.
  ///
  /// ### Parameters
  /// - [duration]: Minimum time between emissions.
  /// - [onError]: Optional callback for errors.
  /// - [user]: Optional user metadata passed to the instruction.
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

/// Internal state for [FilterByTime].
///
/// Tracks the last emission time, pending value, and active timer.
class _TimeGateState<S> {
  /// The time of the last emission.
  DateTime? lastEmitted;

  /// The pending value waiting for emission.
  S? pending;

  /// The pending pulse waiting for emission.
  Pulse? pendingPulse;

  /// The active timer for delayed emission.
  Timer? timer;

  /// Cancels the active timer.
  void clearTimer() {
    timer?.cancel();
    timer = null;
  }

  /// Clears pending values and cancels the timer.
  void clearPending() {
    pending = null;
    pendingPulse = null;
    clearTimer();
  }
}

/// Internal state for generation-based operators ([AsyncFilterLatest]).
///
/// Tracks the current generation ID for stale result detection.
class _GenerationState {
  /// The current generation ID. Incremented on each new pulse.
  int generation = 0;
}

/// Internal state for sequential async queues.
///
/// Ensures that async operations are processed one at a time.
class _AsyncQueueState {
  /// The tail of the async queue.
  Future<void> tail = Future<void>.value();

  /// Enqueues a job to run after the current tail completes.
  ///
  /// ### Parameters
  /// - [job]: A function that returns a [Future] to execute.
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