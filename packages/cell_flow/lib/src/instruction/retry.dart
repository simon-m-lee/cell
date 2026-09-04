// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Retry Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that re-run a failing task (Rx `retry` family).
///
/// | Operator | Rx analogue | Policy |
/// |---|---|---|
/// | [Retry] | `retry` | up to [count] extra attempts |
/// | [RetryWhen] | `retryWhen` | [shouldRetry] decides each failure |
/// | [RetryWithDelay] | `retry` + `delay` | fixed pause between attempts |
/// | [RetryWithBackoff] | exponential backoff | `initial * factor^n`, capped |
/// | [RetryUntil] | retry while | keep going while [until] is false |
///
/// [task] runs for every source pulse. Failures are swallowed into
/// [onError] / an optional error pulse; they do not complete the Cell.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for retry operators.
///
/// Called when an error occurs during task execution or retry logic.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = RetryErrorHandler((error, stack) {
///   print('Retry error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef RetryErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// A function that executes a task that may fail and be retried.
///
/// The task takes an input value of type [S] and returns a `FutureOr<T>`.
/// If the task throws an error, the retry mechanism may re-execute it.
///
/// ### Example
/// ```dart
/// final task = RetryTask<int, String>((id) async {
///   final response = await http.get('https://api.example.com/user/$id');
///   return response.body;
/// });
/// ```
typedef RetryTask<S, T> = FutureOr<T> Function(S value);

/// Helper to create a success pulse with proper provenance.
Pulse<T> _ok<T>(T value, Pulse trigger, Cell? cell, String step) {
  return Pulse<T>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// Helper to create an error pulse with proper provenance.
Pulse _err(Object error, Pulse trigger, Cell? cell, String step) {
  return Pulse(
    error,
    source: cell ?? trigger.source,
    type: 'error',
    priority: trigger.priority,
    step: step,
  );
}

/// Executes a task and handles retry logic.
///
/// [_runTask] is a helper that ensures the task is executed as a `Future`,
/// even if it returns a synchronous value.
Future<T> _runTask<S, T>(RetryTask<S, T> task, S value) async {
  return await Future<T>.sync(() => task(value));
}

/// Core retry attempt loop.
///
/// [_attempt] is the internal engine that manages the retry cycle. It
/// executes the task, catches errors, and decides whether to retry
/// based on the [again] predicate.
///
/// ### Parameters:
/// - [task]: The task to execute.
/// - [value]: The input value for the task.
/// - [pulse]: The trigger pulse.
/// - [cell]: The host cell.
/// - [future]: The continuation callback.
/// - [token]: The continuation token.
/// - [step]: The step name for provenance.
/// - [onError]: Optional error handler.
/// - [emitErrorPulse]: Whether to emit an error pulse on final failure.
/// - [again]: Predicate that decides whether to retry.
///
/// ### How it works
/// 1. Attempt count starts at 0.
/// 2. Execute the task.
/// 3. If successful, emit the result and return.
/// 4. If failed, call [onError] and [again].
/// 5. If [again] returns true, increment attempt and loop.
/// 6. If [again] returns false, emit error pulse (if enabled) and return.
///
/// ### Non‑obvious
/// - **Infinite Loop Protection**: The [again] predicate controls retries.
/// - **Error Swallowing**: Errors are caught and handled without crashing.
/// - **Provenance Preservation**: Success and error pulses preserve metadata.
/// - **Type Safety**: Generic over [S] (input) and [T] (output).
Future<void> _attempt<S, T>({
  required RetryTask<S, T> task,
  required S value,
  required Pulse pulse,
  required Cell? cell,
  required void Function({required Pulse? result, required dynamic token})?
  future,
  required dynamic token,
  required String step,
  required RetryErrorHandler? onError,
  required bool emitErrorPulse,
  required Future<bool> Function(Object error, StackTrace stack, int attempt)
  again,
}) async {
  var attempt = 0;
  while (true) {
    try {
      final result = await _runTask(task, value);
      future?.call(
        result: _ok<T>(result, pulse, cell, step),
        token: token,
      );
      return;
    } catch (e, stack) {
      onError?.call(e, stack);
      final retry = await again(e, stack, attempt);
      if (!retry) {
        if (emitErrorPulse) {
          future?.call(
            result: _err(e, pulse, cell, '$step.error'),
            token: token,
          );
        }
        return;
      }
      attempt++;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Retry - Simple Retry with Count
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that re-runs a task up to [count] extra times
/// after a failure (Rx `retry`).
///
/// [Retry] is the simplest retry operator. It executes the task and
/// retries it up to [count] times if it fails. The task may run
/// `count + 1` times total.
///
/// ### When to use
/// Use [Retry] when you need a simple retry mechanism with a fixed
/// number of attempts.
///
/// - **Network Requests**: Retrying flaky API calls.
/// - **Database Operations**: Retrying transient database errors.
/// - **File I/O**: Retrying file operations that may fail temporarily.
/// - **External Services**: Retrying calls to unreliable services.
/// - **Rate Limiting**: Retrying after rate limit errors.
/// - **Transient Failures**: Handling temporary failures gracefully.
///
/// ### Choosing Between Retry Variants
/// - **Use [Retry]** for **Simple Fixed Count**: When you just need
///   a fixed number of retries.
/// - **Use [RetryWhen]** for **Conditional Retry**: When you need to
///   decide based on the error type or attempt number.
/// - **Use [RetryWithDelay]** for **Fixed Delay**: When you need a
///   pause between retries.
/// - **Use [RetryWithBackoff]** for **Exponential Backoff**: When you
///   want increasing delays between retries.
/// - **Use [RetryUntil]** for **Conditional Stop**: When you want to
///   retry until a condition is met.
///
/// ### Comparison with Other Operators
/// | Operator | Max Attempts | Delay | Condition |
/// |----------|--------------|-------|-----------|
/// | **Retry** | `count + 1` | None | None (all errors) |
/// | **RetryWhen** | Unlimited | None | Custom predicate |
/// | **RetryWithDelay** | `count + 1` | Fixed | None (all errors) |
/// | **RetryWithBackoff** | `count + 1` | Exponential | None (all errors) |
/// | **RetryUntil** | `maxAttempts` | None | Stop condition |
///
/// ### How it works
/// 1. Each incoming pulse triggers the [task].
/// 2. If the task succeeds, the result is emitted.
/// 3. If the task fails, the error is caught.
/// 4. The [count] determines how many retry attempts are made.
/// 5. The task may run `count + 1` times total.
/// 6. If [emitErrorPulse] is `true`, an error pulse is emitted
///    when all retries fail.
/// 7. Errors are reported via [onError] if provided.
/// 8. Each retry attempt preserves causal provenance.
///
/// ### Non‑obvious
/// - **Total Attempts**: The task runs up to `count + 1` times.
/// - **No Delay**: Retries are immediate (use [RetryWithDelay] for delays).
/// - **Error Swallowing**: Errors are caught and don't crash the flow.
/// - **Error Pulse**: The error pulse has type `'error'` for routing.
/// - **Provenance Preservation**: Success and error pulses preserve
///   the source cell, type, and priority from the trigger pulse.
/// - **Type Safety**: The instruction is generic over [S] (input type)
///   and [T] (output type), ensuring compile-time type safety.
///
/// ### Example: Simple API Retry
/// ```dart
/// final userIds = Cell.ingress<int>();
///
/// final users = Retry<int, UserProfile>(
///   (id) async {
///     // This may fail transiently
///     return await api.getUser(id);
///   },
///   count: 3,
///   emitErrorPulse: false,
///   onError: (error, stack) => print('API error: $error'),
/// ).toHandle(source: userIds.cell);
///
/// userIds.emit(1); // Retries up to 3 times if it fails
/// ```
///
/// ### Example: Database Retry
/// ```dart
/// final queries = Cell.ingress<String>();
///
/// final results = Retry<String, List<Map>>(
///   (query) async {
///     return await db.query(query);
///   },
///   count: 5,
/// ).toHandle(source: queries.cell);
/// ```
///
/// ### Parameters:
/// - [task]: **The Task to Execute.** Takes an input value and returns
///   a `FutureOr<T>` that may fail.
/// - [count]: **Maximum Retry Attempts.** Defaults to 3. The task may
///   run `count + 1` times total.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true`, emits an error
///   pulse when all retries fail. Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload on success.
///
/// ### Returns:
/// A [FlowInstruction] that retries a task on failure.
///
/// ### See Also:
/// - [RetryWhen]: For conditional retry logic.
/// - [RetryWithDelay]: For retries with a fixed delay.
/// - [RetryWithBackoff]: For retries with exponential backoff.
/// - [RetryUntil]: For retrying until a condition is met.
class Retry<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Retry(
      RetryTask<S, T> task, {
        int count = 3,
        RetryErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      final payload = pulse.payload;
      if (payload is! S) {
        onError?.call(
          FormatException(
            'Expected payload of type $S, got ${payload.runtimeType}',
          ),
          StackTrace.current,
        );
        return null;
      }
      _attempt<S, T>(
        task: task,
        value: payload,
        pulse: pulse,
        cell: cell,
        future: future,
        token: token,
        step: 'Retry',
        onError: onError,
        emitErrorPulse: emitErrorPulse,
        again: (e, stack, attempt) async => attempt < count,
      );
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// RetryWhen - Conditional Retry
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that retries a task based on a custom predicate
/// (Rx `retryWhen`).
///
/// [RetryWhen] is similar to [Retry] but the retry decision is made by
/// a custom [shouldRetry] function that sees the error and attempt number.
/// This allows for conditional retry logic based on error type or other
/// factors.
///
/// ### When to use
/// Use [RetryWhen] when you need to decide whether to retry based on
/// the error type, attempt number, or other conditions.
///
/// - **Error-Type Based**: Retry only for specific error types.
/// - **Rate Limiting**: Retry only on rate limit errors.
/// - **Network Errors**: Retry only on network errors, not validation.
/// - **Transient vs Permanent**: Distinguish between transient and
///   permanent failures.
/// - **Custom Conditions**: Implement custom retry policies.
/// - **Delayed Retry**: The [shouldRetry] function can return a
///   `Future` to delay the retry.
///
/// ### Example: Retry Only on Network Errors
/// ```dart
/// final requests = Cell.ingress<String>();
///
/// final results = RetryWhen<String, String>(
///   (url) async {
///     return await http.get(url).then((r) => r.body);
///   },
///   shouldRetry: (error, attempt) {
///     // Only retry network errors, not parsing errors
///     return error is NetworkException && attempt < 5;
///   },
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### Example: Retry with Delay
/// ```dart
/// final tasks = Cell.ingress<Task>();
///
/// final results = RetryWhen<Task, Result>(
///   (task) async {
///     return await processTask(task);
///   },
///   shouldRetry: (error, attempt) async {
///     // Retry with increasing delay
///     if (attempt >= 5) return false;
///     await Future.delayed(Duration(seconds: attempt));
///     return true;
///   },
/// ).toHandle(source: tasks.cell);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse triggers the [task].
/// 2. If the task succeeds, the result is emitted.
/// 3. If the task fails, [shouldRetry] is called with the error
///    and attempt number.
/// 4. If [shouldRetry] returns `true`, the task is retried.
/// 5. If [shouldRetry] returns `false`, retries stop.
/// 6. If [emitErrorPulse] is `true`, an error pulse is emitted
///    when all retries fail.
/// 7. [shouldRetry] may return a `Future<bool>` for async decisions.
///
/// ### Non‑obvious
/// - **Async Predicate**: [shouldRetry] can return a `Future<bool>`,
///   allowing async decisions (e.g., checking external state).
/// - **Error Inspection**: The predicate receives the error, allowing
///   type-based decisions.
/// - **Attempt Number**: The predicate receives the attempt number,
///   allowing attempt-based decisions.
/// - **No Built-in Limit**: Implement your own limit in [shouldRetry].
/// - **Error Swallowing**: Errors in [shouldRetry] are caught and
///   treated as `false` (stop retrying).
/// - **Provenance Preservation**: Success and error pulses preserve
///   the source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [task]: **The Task to Execute.** Takes an input value and returns
///   a `FutureOr<T>` that may fail.
/// - [shouldRetry]: **Retry Predicate.** Called with the error and
///   attempt number. Returns `true` to retry, `false` to stop.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true`, emits an error
///   pulse when all retries fail. Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload on success.
///
/// ### Returns:
/// A [FlowInstruction] that conditionally retries a task on failure.
///
/// ### See Also:
/// - [Retry]: For simple fixed-count retry.
/// - [RetryWithDelay]: For retries with a fixed delay.
/// - [RetryWithBackoff]: For retries with exponential backoff.
/// - [RetryUntil]: For retrying until a condition is met.
class RetryWhen<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  RetryWhen(
      RetryTask<S, T> task, {
        required FutureOr<bool> Function(Object error, int attempt) shouldRetry,
        RetryErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      final payload = pulse.payload;
      if (payload is! S) {
        onError?.call(
          FormatException(
            'Expected payload of type $S, got ${payload.runtimeType}',
          ),
          StackTrace.current,
        );
        return null;
      }
      _attempt<S, T>(
        task: task,
        value: payload,
        pulse: pulse,
        cell: cell,
        future: future,
        token: token,
        step: 'RetryWhen',
        onError: onError,
        emitErrorPulse: emitErrorPulse,
        again: (e, stack, attempt) async {
          try {
            return await shouldRetry(e, attempt);
          } catch (err, st) {
            onError?.call(err, st);
            return false;
          }
        },
      );
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// RetryWithDelay - Fixed Delay Retry
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that retries a task with a fixed delay between
/// attempts.
///
/// [RetryWithDelay] is similar to [Retry] but adds a fixed [delay]
/// between retry attempts. This is useful for giving external systems
/// time to recover.
///
/// ### When to use
/// Use [RetryWithDelay] when you need a pause between retries.
///
/// - **Rate Limiting**: Waiting for rate limit windows to reset.
/// - **External Services**: Giving services time to recover.
/// - **Throttling**: Preventing aggressive retry storms.
/// - **User Experience**: Providing feedback between attempts.
/// - **Cooldown Periods**: Allowing cooldown periods between retries.
///
/// ### Example: API Retry with Delay
/// ```dart
/// final requests = Cell.ingress<String>();
///
/// final results = RetryWithDelay<String, String>(
///   (url) async {
///     return await http.get(url).then((r) => r.body);
///   },
///   count: 3,
///   delay: Duration(seconds: 1),
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse triggers the [task].
/// 2. If the task succeeds, the result is emitted.
/// 3. If the task fails, the [delay] is awaited.
/// 4. The task is retried up to [count] times.
/// 5. If [emitErrorPulse] is `true`, an error pulse is emitted
///    when all retries fail.
///
/// ### Non‑obvious
/// - **Fixed Delay**: The delay is the same for every retry.
/// - **Total Time**: Total retry time is `count * delay`.
/// - **No Jitter**: No random variation (use [RetryWithBackoff] for that).
/// - **Error Swallowing**: Errors are caught and don't crash the flow.
/// - **Provenance Preservation**: Success and error pulses preserve
///   the source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [task]: **The Task to Execute.** Takes an input value and returns
///   a `FutureOr<T>` that may fail.
/// - [count]: **Maximum Retry Attempts.** Defaults to 3.
/// - [delay]: **Delay Between Retries.** Defaults to 50ms.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true`, emits an error
///   pulse when all retries fail. Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload on success.
///
/// ### Returns:
/// A [FlowInstruction] that retries a task with a fixed delay.
///
/// ### See Also:
/// - [Retry]: For simple fixed-count retry.
/// - [RetryWhen]: For conditional retry logic.
/// - [RetryWithBackoff]: For retries with exponential backoff.
/// - [RetryUntil]: For retrying until a condition is met.
class RetryWithDelay<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  RetryWithDelay(
      RetryTask<S, T> task, {
        int count = 3,
        Duration delay = const Duration(milliseconds: 50),
        RetryErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      final payload = pulse.payload;
      if (payload is! S) {
        onError?.call(
          FormatException(
            'Expected payload of type $S, got ${payload.runtimeType}',
          ),
          StackTrace.current,
        );
        return null;
      }
      _attempt<S, T>(
        task: task,
        value: payload,
        pulse: pulse,
        cell: cell,
        future: future,
        token: token,
        step: 'RetryWithDelay',
        onError: onError,
        emitErrorPulse: emitErrorPulse,
        again: (e, stack, attempt) async {
          if (attempt >= count) return false;
          await Future<void>.delayed(delay);
          return true;
        },
      );
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// RetryWithBackoff - Exponential Backoff Retry
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that retries a task with exponential backoff.
///
/// [RetryWithBackoff] retries a task with increasing delays between
/// attempts. The delay starts at [initial] and multiplies by [factor]
/// each attempt, optionally capped at [maxDelay].
///
/// ### When to use
/// Use [RetryWithBackoff] when you want increasing delays between
/// retries to avoid thundering herd problems.
///
/// - **Distributed Systems**: Avoiding thundering herd on recovery.
/// - **Rate Limiting**: Respecting rate limit reset windows.
/// - **External Services**: Giving services time to scale.
/// - **Network Recovery**: Allowing network recovery time.
/// - **Load Shedding**: Reducing load during failure cascades.
/// - **Circuit Breakers**: Integration with circuit breaker patterns.
///
/// ### Example: API Retry with Backoff
/// ```dart
/// final requests = Cell.ingress<String>();
///
/// final results = RetryWithBackoff<String, String>(
///   (url) async {
///     return await http.get(url).then((r) => r.body);
///   },
///   count: 5,
///   initial: Duration(milliseconds: 100),
///   factor: 2.0,
///   maxDelay: Duration(seconds: 10),
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse triggers the [task].
/// 2. If the task succeeds, the result is emitted.
/// 3. If the task fails, the delay is calculated as:
///    `initial * factor^attempt`, capped at [maxDelay].
/// 4. The delay is awaited.
/// 5. The task is retried up to [count] times.
/// 6. If [emitErrorPulse] is `true`, an error pulse is emitted
///    when all retries fail.
///
/// ### Non‑obvious
/// - **Exponential Growth**: Delay grows exponentially with each attempt.
/// - **Capping**: [maxDelay] prevents unbounded delay growth.
/// - **Jitter**: No random jitter (add your own if needed).
/// - **Total Time**: Total retry time is the sum of all delays.
/// - **Error Swallowing**: Errors are caught and don't crash the flow.
/// - **Provenance Preservation**: Success and error pulses preserve
///   the source cell, type, and priority from the trigger pulse.
///
/// ### Delay Calculation Examples
/// | Attempt | initial=10ms, factor=2 | initial=100ms, factor=1.5 |
/// |---------|------------------------|---------------------------|
/// | 0 | 10ms | 100ms |
/// | 1 | 20ms | 150ms |
/// | 2 | 40ms | 225ms |
/// | 3 | 80ms | 337ms |
/// | 4 | 160ms | 506ms |
///
/// ### Parameters:
/// - [task]: **The Task to Execute.** Takes an input value and returns
///   a `FutureOr<T>` that may fail.
/// - [count]: **Maximum Retry Attempts.** Defaults to 3.
/// - [initial]: **Initial Delay.** Defaults to 20ms.
/// - [factor]: **Backoff Factor.** Defaults to 2.0.
/// - [maxDelay]: **Maximum Delay.** Optional cap on delay growth.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true`, emits an error
///   pulse when all retries fail. Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload on success.
///
/// ### Returns:
/// A [FlowInstruction] that retries a task with exponential backoff.
///
/// ### See Also:
/// - [Retry]: For simple fixed-count retry.
/// - [RetryWhen]: For conditional retry logic.
/// - [RetryWithDelay]: For retries with a fixed delay.
/// - [RetryUntil]: For retrying until a condition is met.
class RetryWithBackoff<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  RetryWithBackoff(
      RetryTask<S, T> task, {
        int count = 3,
        Duration initial = const Duration(milliseconds: 20),
        double factor = 2,
        Duration? maxDelay,
        RetryErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      final payload = pulse.payload;
      if (payload is! S) {
        onError?.call(
          FormatException(
            'Expected payload of type $S, got ${payload.runtimeType}',
          ),
          StackTrace.current,
        );
        return null;
      }
      _attempt<S, T>(
        task: task,
        value: payload,
        pulse: pulse,
        cell: cell,
        future: future,
        token: token,
        step: 'RetryWithBackoff',
        onError: onError,
        emitErrorPulse: emitErrorPulse,
        again: (e, stack, attempt) async {
          if (attempt >= count) return false;
          var ms = initial.inMilliseconds * math.pow(factor, attempt);
          if (maxDelay != null) {
            ms = math.min(ms, maxDelay.inMilliseconds);
          }
          await Future<void>.delayed(
            Duration(milliseconds: ms.round()),
          );
          return true;
        },
      );
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// RetryUntil - Retry Until Condition
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that retries a task while a condition is false
/// (stop when it becomes true).
///
/// [RetryUntil] retries a task until the [until] predicate returns `true`
/// or [maxAttempts] is exhausted. The [until] predicate sees the error
/// and attempt number after a failure.
///
/// ### When to use
/// Use [RetryUntil] when you want to retry until a specific condition
/// is met (e.g., a specific error type is encountered).
///
/// - **Error-Type Stop**: Stop retrying on specific error types.
/// - **Timeout Detection**: Stop retrying after timeout errors.
/// - **Validation Errors**: Stop retrying on validation errors.
/// - **Permanent Failures**: Stop retrying on permanent failures.
/// - **Custom Conditions**: Implement custom stop conditions.
///
/// ### Example: Stop on Validation Error
/// ```dart
/// final requests = Cell.ingress<Request>();
///
/// final results = RetryUntil<Request, Response>(
///   (request) async {
///     return await api.process(request);
///   },
///   until: (error, attempt) {
///     // Stop retrying on validation errors
///     return error is ValidationException;
///   },
///   maxAttempts: 5,
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### Example: Stop on Specific Error
/// ```dart
/// final tasks = Cell.ingress<Task>();
///
/// final results = RetryUntil<Task, Result>(
///   (task) async {
///     return await processTask(task);
///   },
///   until: (error, attempt) {
///     // Stop retrying on permanent errors
///     return error is PermanentFailureException;
///   },
///   maxAttempts: 10,
/// ).toHandle(source: tasks.cell);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse triggers the [task].
/// 2. If the task succeeds, the result is emitted.
/// 3. If the task fails, [until] is called with the error and attempt.
/// 4. If [until] returns `true`, stop retrying (emit error if enabled).
/// 5. If [until] returns `false` and attempts < [maxAttempts], retry.
/// 6. If [maxAttempts] is reached, stop retrying.
/// 7. If [emitErrorPulse] is `true`, an error pulse is emitted
///    when all retries fail.
///
/// ### Non‑obvious
/// - **Stop Condition**: [until] returns `true` to *stop* retrying.
/// - **Error Inspection**: The predicate receives the error for inspection.
/// - **Attempt Number**: The predicate receives the attempt number.
/// - **Max Attempts**: [maxAttempts] is the total attempts limit.
/// - **Error Swallowing**: Errors in [until] are caught and treated
///   as `false` (continue retrying).
/// - **Provenance Preservation**: Success and error pulses preserve
///   the source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [task]: **The Task to Execute.** Takes an input value and returns
///   a `FutureOr<T>` that may fail.
/// - [until]: **Stop Condition.** Called with the error and attempt
///   number. Returns `true` to stop retrying, `false` to continue.
/// - [maxAttempts]: **Maximum Total Attempts.** Defaults to 8.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true`, emits an error
///   pulse when all retries fail. Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload on success.
///
/// ### Returns:
/// A [FlowInstruction] that retries a task until a condition is met.
///
/// ### See Also:
/// - [Retry]: For simple fixed-count retry.
/// - [RetryWhen]: For conditional retry logic.
/// - [RetryWithDelay]: For retries with a fixed delay.
/// - [RetryWithBackoff]: For retries with exponential backoff.
class RetryUntil<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  RetryUntil(
      RetryTask<S, T> task, {
        required bool Function(Object error, int attempt) until,
        int maxAttempts = 8,
        RetryErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      final payload = pulse.payload;
      if (payload is! S) {
        onError?.call(
          FormatException(
            'Expected payload of type $S, got ${payload.runtimeType}',
          ),
          StackTrace.current,
        );
        return null;
      }
      _attempt<S, T>(
        task: task,
        value: payload,
        pulse: pulse,
        cell: cell,
        future: future,
        token: token,
        step: 'RetryUntil',
        onError: onError,
        emitErrorPulse: emitErrorPulse,
        again: (e, stack, attempt) async {
          if (attempt + 1 >= maxAttempts) return false;
          try {
            return !until(e, attempt);
          } catch (err, st) {
            onError?.call(err, st);
            return false;
          }
        },
      );
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Retry] instruction and related operators
/// showing their behavior in various retry scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Retry Operators Demo ──────────────────────────────────────
///
/// 1. Retry - succeed on attempt 3
///    [Retry] ok
///
/// 2. RetryWhen - give up on StateError
///    [RetryWhen] error
///
/// 3. RetryWithDelay
///    [RetryWithDelay] late
///
/// 4. RetryWithBackoff
///    [RetryWithBackoff] ok
///
/// 5. RetryUntil - stop on FormatException
///    [RetryUntil] error
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
/// 1. **Retry - Simple Retry**: Shows the basic retry operator where
///    a task fails twice and succeeds on the third attempt. The
///    [emitErrorPulse] is `false`, so no error pulse is emitted.
///
/// 2. **RetryWhen - Conditional Retry**: Shows retry with a custom
///    condition. The task always fails with a `StateError`, and
///    [shouldRetry] only retries for non-`StateError` errors, so
///    it emits an error pulse immediately.
///
/// 3. **RetryWithDelay - Fixed Delay**: Shows retry with a fixed
///    delay between attempts. The task fails once and succeeds on
///    the second attempt after a 20ms delay.
///
/// 4. **RetryWithBackoff - Exponential Backoff**: Shows retry with
///    exponential backoff. The task fails once and succeeds on the
///    second attempt with a delay that grows exponentially.
///
/// 5. **RetryUntil - Conditional Stop**: Shows retry until a condition
///    is met. The task always fails with a `FormatException`, and
///    [until] stops retrying when a `FormatException` is encountered.
///
/// ### Key Takeaways
/// - Retry operators handle transient failures gracefully.
/// - [count] controls the number of retry attempts.
/// - [RetryWhen] provides custom retry logic.
/// - [RetryWithDelay] adds a fixed pause between retries.
/// - [RetryWithBackoff] provides exponential backoff.
/// - [RetryUntil] retries until a condition is met.
/// - Error pulses are optional via [emitErrorPulse].
/// - All operators preserve causal provenance via EvolvedPulse.
///
/// ### Note on Timing
/// The demo uses short delays for quick execution. In production,
/// you would typically use longer delays (e.g., seconds or minutes).
Future<void> main() async {
  print('── Retry Operators Demo ──────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Retry - Succeed on Attempt 3
  // ─────────────────────────────────────────────────────────────────────
  print('1. Retry - succeed on attempt 3');

  var n = 0;
  final a = Cell.ingress<void>();

  final retried = Retry<void, String>(
        (_) {
      n++;
      if (n < 3) throw StateError('try-$n');
      return 'ok';
    },
    count: 5,
    emitErrorPulse: false,
    onError: (_, __) {},
  ).toHandle(source: a.cell);

  final rObs = Cell.observe(
    source: retried.cell,
    effect: (Pulse p) => print('   [Retry] ${p.payload}'),
  );

  await a.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  rObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. RetryWhen - Give Up on StateError
  // ─────────────────────────────────────────────────────────────────────
  print('2. RetryWhen - give up on StateError');

  final b = Cell.ingress<void>();

  final when = RetryWhen<void, String>(
        (_) => throw StateError('nope'),
    shouldRetry: (e, attempt) => e is! StateError,
    onError: (_, __) {},
  ).toHandle(source: b.cell);

  final wObs = Cell.observe(
    source: when.cell,
    effect: (Pulse p) => print('   [RetryWhen] ${p.type}'),
  );

  await b.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  wObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. RetryWithDelay - Fixed Delay
  // ─────────────────────────────────────────────────────────────────────
  print('3. RetryWithDelay');

  var d = 0;
  final c = Cell.ingress<void>();

  final delayed = RetryWithDelay<void, String>(
        (_) {
      d++;
      if (d < 2) throw StateError('wait');
      return 'late';
    },
    count: 3,
    delay: const Duration(milliseconds: 20),
    emitErrorPulse: false,
    onError: (_, __) {},
  ).toHandle(source: c.cell);

  final dObs = Cell.observe(
    source: delayed.cell,
    effect: (Pulse p) => print('   [RetryWithDelay] ${p.payload}'),
  );

  await c.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 80));

  dObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. RetryWithBackoff - Exponential Backoff
  // ─────────────────────────────────────────────────────────────────────
  print('4. RetryWithBackoff');

  var k = 0;
  final e = Cell.ingress<void>();

  final backed = RetryWithBackoff<void, String>(
        (_) {
      k++;
      if (k < 2) throw StateError('again');
      return 'ok';
    },
    count: 3,
    initial: const Duration(milliseconds: 10),
    emitErrorPulse: false,
    onError: (_, __) {},
  ).toHandle(source: e.cell);

  final bObs = Cell.observe(
    source: backed.cell,
    effect: (Pulse p) => print('   [RetryWithBackoff] ${p.payload}'),
  );

  await e.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 80));

  bObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 5. RetryUntil - Stop on FormatException
  // ─────────────────────────────────────────────────────────────────────
  print('5. RetryUntil - stop on FormatException');

  final f = Cell.ingress<void>();

  final until = RetryUntil<void, String>(
        (_) => throw const FormatException('bad'),
    until: (e, _) => e is FormatException,
    onError: (_, __) {},
  ).toHandle(source: f.cell);

  final uObs = Cell.observe(
    source: until.cell,
    effect: (Pulse p) => print('   [RetryUntil] ${p.type}'),
  );

  await f.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  uObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}