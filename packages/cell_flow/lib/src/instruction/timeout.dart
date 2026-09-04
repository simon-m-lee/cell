// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Timeout Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that fire when the source goes quiet
/// (Rx `timeout` family).
///
/// The clock **starts on the first typed pulse** (a FlowInstruction
/// only receives `future` then) and **resets on every later pulse**,
/// unless the operator is first-only.
///
/// | Operator | Rx analogue | On timeout |
/// |---|---|---|
/// | [Timeout] | `timeout` | error pulse (`TimeoutException`) |
/// | [TimeoutWithError] | `timeout` + custom error | [error] / [errorOf] |
/// | [TimeoutWithFallback] | `timeout` + `with` | [fallback] value |
/// | [TimeoutFirst] | first-gap only | same as [Timeout], timer not reset |
/// | [TimeoutLast] | idle after last | alias of [Timeout] |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for timeout operators.
///
/// Called when an error occurs during timeout handling.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = TimeoutErrorHandler((error, stack) {
///   print('Timeout error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef TimeoutErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// Helper for type-safe payload extraction.
///
/// [_typedOrError] checks that the pulse payload matches the expected
/// type [S]. If it does, returns the pulse. If not, calls [onError]
/// and returns `null`.
///
/// ### Parameters:
/// - [pulse]: The incoming pulse to check.
/// - [onError]: Optional error handler for type mismatches.
///
/// ### Returns:
/// The pulse if the payload type matches, otherwise `null`.
Pulse? _typedOrError<S>(
    Pulse pulse, {
      TimeoutErrorHandler? onError,
    }) {
  final payload = pulse.payload;
  if (payload is! S) {
    onError?.call(
      FormatException('Expected payload of type $S, got ${payload.runtimeType}'),
      StackTrace.current,
    );
    return null;
  }
  return pulse;
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

/// Internal clock state for timeout operators.
///
/// [_Clock] manages the timer and continuation state for timeout operators.
/// It tracks the timer, whether the clock is closed, and the context for
/// emitting timeout pulses.
///
/// ### When to use
/// This is an internal implementation detail. You don't need to use it
/// directly in application code.
///
/// ### How it works
/// 1. [timer] holds the active [Timer] for the timeout.
/// 2. [closed] indicates whether the clock has been closed.
/// 3. [future], [token], [cell], and [last] store the context for
///    emitting the timeout pulse.
/// 4. [cancel] cancels the active timer.
///
/// ### Non‑obvious
/// - **Single Timer**: Only one timer is active at a time.
/// - **Closed State**: When closed, the clock no longer fires.
/// - **Last Pulse**: The last pulse is stored for provenance.
/// - **Continuation Context**: Stores the callback and token for
///    asynchronous emission.
class _Clock {
  Timer? timer;
  bool closed = false;
  void Function({required Pulse? result, required dynamic token})? future;
  dynamic token;
  Cell? cell;
  Pulse? last;

  /// Cancels the active timer.
  void cancel() {
    timer?.cancel();
    timer = null;
  }
}

/// Arms the timeout clock.
///
/// [_arm] sets up the clock state and starts the timer. It's the internal
/// engine for all timeout operators.
///
/// ### Parameters:
/// - [clock]: The clock state to arm.
/// - [duration]: The timeout duration.
/// - [resetOnPulse]: Whether to reset the timer on each pulse.
/// - [onTimeout]: The callback to execute on timeout.
/// - [pulse]: The current pulse.
/// - [cell]: The host cell.
/// - [future]: The continuation callback.
/// - [token]: The continuation token.
///
/// ### How it works
/// 1. Stores the continuation context.
/// 2. If the clock is closed, returns.
/// 3. If [resetOnPulse] is true or the timer is null, cancels the
///    existing timer and starts a new one.
/// 4. The timer executes [onTimeout] after [duration].
///
/// ### Non‑obvious
/// - **Reset Behavior**: [resetOnPulse] controls whether the timer
///   resets on each pulse.
/// - **Closed Clock**: Once closed, no further timeouts are triggered.
/// - **Provenance**: The [pulse] and [cell] are stored for provenance.
void _arm<S>({
  required _Clock clock,
  required Duration duration,
  required bool resetOnPulse,
  required void Function() onTimeout,
  required Pulse pulse,
  required Cell? cell,
  required void Function({required Pulse? result, required dynamic token})?
  future,
  required dynamic token,
}) {
  clock.future = future;
  clock.token = token;
  clock.cell = cell;
  clock.last = pulse;
  if (clock.closed) return;
  if (clock.timer == null || resetOnPulse) {
    clock.cancel();
    clock.timer = Timer(duration, onTimeout);
  }
}

// ─────────────────────────────────────────────────────────────
// Timeout - Standard Timeout with Error
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits an error if the gap between typed
/// pulses exceeds [duration] (Rx `timeout`).
///
/// [Timeout] is the standard timeout operator. It starts a timer on
/// the first pulse and resets it on every subsequent pulse. If the
/// timer expires, a [TimeoutException] is emitted as an error pulse.
///
/// ### When to use
/// Use [Timeout] when you need to detect idle periods in a stream.
///
/// - **Idle Detection**: Detecting user inactivity.
/// - **Connection Timeout**: Detecting network connection timeouts.
/// - **Heartbeat Monitoring**: Detecting missing heartbeats.
/// - **Response Timeout**: Detecting slow responses.
/// - **Session Timeout**: Detecting session expiration.
/// - **Resource Cleanup**: Cleaning up idle resources.
///
/// ### Choosing Between Timeout Variants
/// - **Use [Timeout]** for **Standard Timeout**: When you want a
///   standard error on timeout.
/// - **Use [TimeoutWithError]** for **Custom Error**: When you want
///   to control the error payload.
/// - **Use [TimeoutWithFallback]** for **Fallback Value**: When you
///   want to emit a fallback instead of an error.
/// - **Use [TimeoutFirst]** for **First-Gap Only**: When the timer
///   should not reset on later pulses.
/// - **Use [TimeoutLast]** for **Idle After Last**: Alias of Timeout.
///
/// ### Comparison with Other Operators
/// | Operator | Timer Reset | On Timeout |
/// |----------|-------------|------------|
/// | **Timeout** | Yes (each pulse) | Error |
/// | **TimeoutWithError** | Yes (each pulse) | Custom error |
/// | **TimeoutWithFallback** | Yes (each pulse) | Fallback value |
/// | **TimeoutFirst** | No (first only) | Error |
/// | **TimeoutLast** | Yes (each pulse) | Error |
///
/// ### How it works
/// 1. The first typed pulse starts the timer.
/// 2. Each subsequent typed pulse resets the timer.
/// 3. If the timer expires, a timeout error is emitted.
/// 4. The error pulse has type `'error'` for routing.
/// 5. The pulse is passed through unchanged.
/// 6. The clock is closed after the first timeout.
///
/// ### Non‑obvious
/// - **Single Timeout**: The clock closes after the first timeout.
/// - **Reset Behavior**: Timer resets on every typed pulse.
/// - **Error Type**: The error is a [TimeoutException].
/// - **Type Safety**: The instruction is generic over [S].
/// - **Provenance Preservation**: The error pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Step Tracking**: Passed-through pulses get the `'Timeout'` step.
///
/// ### Example: Idle Detection
/// ```dart
/// final userActivity = Cell.ingress<String>();
///
/// final timeout = Timeout<String>(
///   Duration(seconds: 5),
///   onError: (error, stack) => print('User idle: $error'),
/// ).toHandle(source: userActivity.cell);
///
/// Cell.observe(
///   source: timeout.cell,
///   effect: (pulse) {
///     if (pulse.type == 'error') {
///       print('Idle timeout detected');
///     } else {
///       print('Activity: ${pulse.payload}');
///     }
///   },
/// );
/// ```
///
/// ### Parameters:
/// - [duration]: **Timeout Duration.** The maximum gap between pulses
///   before a timeout is triggered.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true`, emits an error
///   pulse on timeout. Defaults to `true`.
/// - [resetOnPulse]: **Reset Timer on Pulse.** If `true`, the timer
///   resets on every pulse. Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that detects timeouts.
///
/// ### See Also:
/// - [TimeoutWithError]: For custom error payload.
/// - [TimeoutWithFallback]: For fallback on timeout.
/// - [TimeoutFirst]: For first-gap only timeout.
/// - [TimeoutLast]: Alias of [Timeout].
class Timeout<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Timeout(
      Duration duration, {
        TimeoutErrorHandler? onError,
        bool emitErrorPulse = true,
        bool resetOnPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final clock = _Clock();
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        _arm<S>(
          clock: clock,
          duration: duration,
          resetOnPulse: resetOnPulse,
          pulse: typed,
          cell: cell,
          future: future,
          token: token,
          onTimeout: () {
            if (clock.closed) return;
            clock.closed = true;
            final err = TimeoutException(
              'No pulse within $duration',
              duration,
            );
            onError?.call(err, StackTrace.current);
            if (emitErrorPulse && clock.last != null) {
              clock.future?.call(
                result: _err(err, clock.last!, clock.cell, 'Timeout'),
                token: clock.token,
              );
            }
          },
        );
        return typed.withStep('Timeout');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// TimeoutWithError - Custom Error Payload
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a custom error payload on timeout.
///
/// [TimeoutWithError] is similar to [Timeout] but allows you to control
/// the error payload. You can provide a fixed [error] or an [errorOf]
/// function that computes the error dynamically.
///
/// ### When to use
/// Use [TimeoutWithError] when you need to emit a specific error type
/// or a custom error message on timeout.
///
/// - **Custom Error Types**: Emitting specific error types for routing.
/// - **Dynamic Error Messages**: Generating error messages dynamically.
/// - **Error Context**: Including context in the error payload.
/// - **Error Enrichment**: Enriching errors with additional data.
/// - **Domain-Specific Errors**: Emitting domain-specific errors.
///
/// ### Example: Custom Error Type
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final timeout = TimeoutWithError<int>(
///   Duration(seconds: 2),
///   error: StateError('Connection timed out'),
/// ).toHandle(source: input.cell);
///
/// // On timeout, emits a StateError instead of TimeoutException
/// ```
///
/// ### Example: Dynamic Error
/// ```dart
/// final input = Cell.ingress<int>();
///
/// var timeoutCount = 0;
/// final timeout = TimeoutWithError<int>(
///   Duration(seconds: 2),
///   errorOf: () => StateError('Timeout #${++timeoutCount}'),
/// ).toHandle(source: input.cell);
///
/// // Each timeout emits a different error message
/// ```
///
/// ### How it works
/// 1. Same as [Timeout] but with custom error payload.
/// 2. If [errorOf] is provided, it's called to produce the error.
/// 3. If [error] is provided, it's used as the error payload.
/// 4. If neither is provided, falls back to [TimeoutException].
/// 5. Errors in [errorOf] are caught and reported via [onError].
///
/// ### Non‑obvious
/// - **Error Priority**: [errorOf] takes precedence over [error].
/// - **Fallback**: If neither [error] nor [errorOf] is provided,
///   falls back to [TimeoutException].
/// - **Error Handling**: Errors in [errorOf] are caught and reported.
/// - **Provenance Preservation**: The error pulse preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [duration]: **Timeout Duration.** The maximum gap between pulses.
/// - [error]: **Fixed Error Payload.** The error to emit on timeout.
/// - [errorOf]: **Dynamic Error Factory.** Called on timeout to produce
///   the error payload.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits a custom error on timeout.
///
/// ### See Also:
/// - [Timeout]: For standard timeout with error.
/// - [TimeoutWithFallback]: For fallback on timeout.
/// - [TimeoutFirst]: For first-gap only timeout.
class TimeoutWithError<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  TimeoutWithError(
      Duration duration, {
        Object? error,
        Object Function()? errorOf,
        TimeoutErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final clock = _Clock();
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        _arm<S>(
          clock: clock,
          duration: duration,
          resetOnPulse: true,
          pulse: typed,
          cell: cell,
          future: future,
          token: token,
          onTimeout: () {
            if (clock.closed) return;
            clock.closed = true;
            late final Object err;
            try {
              err = errorOf != null
                  ? errorOf()
                  : (error ??
                  TimeoutException(
                    'No pulse within $duration',
                    duration,
                  ));
            } catch (e, stack) {
              onError?.call(e, stack);
              return;
            }
            onError?.call(err, StackTrace.current);
            if (emitErrorPulse && clock.last != null) {
              clock.future?.call(
                result: _err(err, clock.last!, clock.cell, 'TimeoutWithError'),
                token: clock.token,
              );
            }
          },
        );
        return typed.withStep('TimeoutWithError');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// TimeoutWithFallback - Fallback Value on Timeout
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a [fallback] value instead of an
/// error when the gap exceeds [duration].
///
/// [TimeoutWithFallback] is similar to [Timeout] but emits a fallback
/// value instead of an error on timeout. This is useful for providing
/// default values when the stream goes quiet.
///
/// ### When to use
/// Use [TimeoutWithFallback] when you want to provide a default value
/// on timeout instead of an error.
///
/// - **Default Values**: Providing default values on timeout.
/// - **Graceful Degradation**: Degrading gracefully on timeouts.
/// - **Cached Data**: Using cached data on timeout.
/// - **Placeholder Values**: Using placeholder values.
/// - **Offline Mode**: Emitting offline mode values.
///
/// ### Example: Default Value on Timeout
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final timeout = TimeoutWithFallback<int>(
///   Duration(seconds: 2),
///   fallback: -1,
/// ).toHandle(source: input.cell);
///
/// // On timeout, emits -1 instead of an error
/// ```
///
/// ### Example: Cached Data on Timeout
/// ```dart
/// final requests = Cell.ingress<Request>();
/// final cache = Cache();
///
/// final timeout = TimeoutWithFallback<Response>(
///   Duration(seconds: 3),
///   fallback: cache.getLastResponse(),
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### How it works
/// 1. Same as [Timeout] but with fallback value.
/// 2. On timeout, [fallback] is emitted instead of an error.
/// 3. If [once] is `true`, the fallback is emitted only once.
/// 4. If [once] is `false`, the fallback is emitted on every timeout.
/// 5. The pulse is passed through unchanged.
///
/// ### Non‑obvious
/// - **Once vs Continuous**: [once] controls whether the fallback is
///   emitted repeatedly.
/// - **No Error**: No error pulse is emitted.
/// - **Provenance Preservation**: The fallback pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Type Safety**: The fallback must match the payload type [S].
///
/// ### Parameters:
/// - [duration]: **Timeout Duration.** The maximum gap between pulses.
/// - [fallback]: **Fallback Value.** The value to emit on timeout.
/// - [once]: **Emit Once.** If `true`, the fallback is emitted only
///   once. If `false`, it's emitted on every timeout. Defaults to `true`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits a fallback on timeout.
///
/// ### See Also:
/// - [Timeout]: For standard timeout with error.
/// - [TimeoutWithError]: For custom error on timeout.
/// - [TimeoutFirst]: For first-gap only timeout.
/// - [TimeoutLast]: Alias of [Timeout].
class TimeoutWithFallback<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  TimeoutWithFallback(
      Duration duration, {
        required S fallback,
        bool once = true,
        TimeoutErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final clock = _Clock();
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        _arm<S>(
          clock: clock,
          duration: duration,
          resetOnPulse: true,
          pulse: typed,
          cell: cell,
          future: future,
          token: token,
          onTimeout: () {
            if (clock.closed && once) return;
            if (once) clock.closed = true;
            if (clock.last == null) return;
            clock.future?.call(
              result: _ok<S>(
                fallback,
                clock.last!,
                clock.cell,
                'TimeoutWithFallback',
              ),
              token: clock.token,
            );
          },
        );
        return typed.withStep('TimeoutWithFallback');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// TimeoutFirst - First-Gap Only Timeout
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] where the timer starts on the first pulse and
/// is **not** reset by later pulses (first-gap / overall deadline).
///
/// [TimeoutFirst] is similar to [Timeout] but the timer only runs from
/// the first pulse. Later pulses do not reset the timer. This is useful
/// for enforcing an overall deadline.
///
/// ### When to use
/// Use [TimeoutFirst] when you need to enforce an overall deadline
/// from the first pulse.
///
/// - **Overall Deadlines**: Enforcing a deadline from the first pulse.
/// - **Session Timeouts**: Session expiration from first activity.
/// - **Job Timeouts**: Job execution timeouts.
/// - **Operation Deadlines**: Overall operation deadlines.
/// - **Initialization Timeouts**: Timeouts from initialization.
///
/// ### Example: Overall Deadline
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final timeout = TimeoutFirst<int>(
///   Duration(seconds: 5),
/// ).toHandle(source: input.cell);
///
/// // Timer starts at first pulse and never resets
/// input.emit(1); // starts timer
/// input.emit(2); // timer continues (not reset)
/// // After 5 seconds from first pulse, timeout occurs
/// ```
///
/// ### How it works
/// 1. The first typed pulse starts the timer.
/// 2. Later pulses do not reset the timer.
/// 3. If the timer expires, a timeout is emitted.
/// 4. The clock closes after the timeout.
///
/// ### Non‑obvious
/// - **No Reset**: Later pulses do not reset the timer.
/// - **Overall Deadline**: The timeout is from the first pulse.
/// - **Single Timeout**: Only one timeout is emitted.
/// - **Provenance Preservation**: The error pulse preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [duration]: **Timeout Duration.** The maximum time from the
///   first pulse before a timeout is triggered.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that times out from the first pulse.
///
/// ### See Also:
/// - [Timeout]: For standard timeout (resets on each pulse).
/// - [TimeoutWithError]: For custom error on timeout.
/// - [TimeoutWithFallback]: For fallback on timeout.
/// - [TimeoutLast]: Alias of [Timeout].
class TimeoutFirst<S> extends Timeout<S> {
  TimeoutFirst(
      super.duration, {
        super.onError,
        super.emitErrorPulse,
        super.user,
      }) : super(
    resetOnPulse: false,
  );
}

// ─────────────────────────────────────────────────────────────
// TimeoutLast - Idle After Last Pulse
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that times out after the latest pulse
/// (idle timeout). Alias of [Timeout].
///
/// [TimeoutLast] is an alias for [Timeout] that emphasizes the
/// "idle after last pulse" behavior. It resets the timer on every
/// pulse and times out when the gap between pulses exceeds
/// [duration].
///
/// ### When to use
/// Use [TimeoutLast] when you want to detect idle periods after
/// the last pulse.
///
/// - **Idle Detection**: Detecting periods of inactivity.
/// - **Heartbeat Monitoring**: Detecting missing heartbeats.
/// - **Connection Timeout**: Detecting connection timeouts.
/// - **User Inactivity**: Detecting user inactivity.
/// - **Resource Cleanup**: Cleaning up idle resources.
///
/// ### Example: Idle Detection
/// ```dart
/// final userActivity = Cell.ingress<String>();
///
/// final timeout = TimeoutLast<String>(
///   Duration(seconds: 5),
/// ).toHandle(source: userActivity.cell);
///
/// // Timer resets on every activity
/// // Times out after 5 seconds of inactivity
/// ```
///
/// ### How it works
/// Identical to [Timeout] with `resetOnPulse: true`.
///
/// ### Non‑obvious
/// - **Alias**: This is exactly the same as [Timeout].
/// - **Semantic Name**: The name emphasizes "idle after last pulse".
/// - **Identical Behavior**: Same behavior as [Timeout].
///
/// ### Parameters:
/// Same as [Timeout].
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that times out after idle periods.
///
/// ### See Also:
/// - [Timeout]: The primary implementation.
/// - [TimeoutFirst]: For overall deadline from first pulse.
class TimeoutLast<S> extends Timeout<S> {
  TimeoutLast(
      super.duration, {
        super.onError,
        super.emitErrorPulse,
        super.user,
      }) : super(
    resetOnPulse: true,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Timeout] instruction and related operators
/// showing their behavior in various timeout scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Timeout Operators Demo ────────────────────────────────────
///
/// 1. Timeout - error after idle
///    [Timeout] 1
///    [Timeout] error
///
/// 2. TimeoutWithError - custom payload
///    [TimeoutWithError] 1
///    [TimeoutWithError] late
///
/// 3. TimeoutWithFallback
///    [TimeoutWithFallback] 1
///    [TimeoutWithFallback] none
///
/// 4. TimeoutFirst - overall deadline
///    [TimeoutFirst] 1
///    [TimeoutFirst] 2
///    [TimeoutFirst] error
///
/// 5. TimeoutLast - idle after last
///    [TimeoutLast] 1
///    [TimeoutLast] error
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
/// 1. **Timeout - Error After Idle**: Shows the standard timeout
///    operator. A pulse is emitted, then after a delay the timeout
///    triggers and an error is emitted.
///
/// 2. **TimeoutWithError - Custom Payload**: Shows timeout with a
///    custom error payload. Instead of a standard TimeoutException,
///    a custom StateError is emitted on timeout.
///
/// 3. **TimeoutWithFallback - Fallback Value**: Shows timeout with a
///    fallback value. On timeout, the fallback value `-1` (displayed
///    as `none`) is emitted instead of an error.
///
/// 4. **TimeoutFirst - Overall Deadline**: Shows the first-gap
///    timeout. The timer starts on the first pulse and does not reset
///    on later pulses. Multiple pulses are emitted but the timeout
///    still triggers based on the first pulse.
///
/// 5. **TimeoutLast - Idle After Last**: Shows the idle timeout
///    (alias of Timeout). The timer resets on each pulse and times
///    out after the last pulse.
///
/// ### Key Takeaways
/// - Timeout operators detect idle periods in a stream.
/// - The timer resets on each pulse (unless TimeoutFirst).
/// - Timeout emits a standard TimeoutException by default.
/// - TimeoutWithError allows custom error payloads.
/// - TimeoutWithFallback emits a fallback value instead of an error.
/// - TimeoutFirst only times out from the first pulse.
/// - TimeoutLast is an alias for Timeout.
/// - All operators preserve causal provenance via EvolvedPulse.
///
/// ### Note on Timing
/// The demo uses short delays (40-70ms) for quick execution. In
/// production, you would typically use longer durations (e.g.,
/// seconds or minutes) for timeout detection.
Future<void> main() async {
  print('── Timeout Operators Demo ────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Timeout - Error After Idle
  // ─────────────────────────────────────────────────────────────────────
  print('1. Timeout - error after idle');

  final a = Cell.ingress<int>();

  final timed = Timeout<int>(
    const Duration(milliseconds: 40),
    onError: (_, __) {},
  ).toHandle(source: a.cell);

  final tObs = Cell.observe(
    source: timed.cell,
    effect: (Pulse p) =>
        print('   [Timeout] ${p.type == 'error' ? 'error' : p.payload}'),
  );

  await a.emitAsync(1);
  await Future<void>.delayed(const Duration(milliseconds: 70));

  tObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. TimeoutWithError - Custom Payload
  // ─────────────────────────────────────────────────────────────────────
  print('2. TimeoutWithError - custom payload');

  final e = Cell.ingress<int>();

  final custom = TimeoutWithError<int>(
    const Duration(milliseconds: 40),
    error: StateError('late'),
    onError: (_, __) {},
  ).toHandle(source: e.cell);

  final eObs = Cell.observe(
    source: custom.cell,
    effect: (Pulse p) => print(
      '   [TimeoutWithError] ${p.type == 'error' ? (p.payload as StateError).message : p.payload}',
    ),
  );

  await e.emitAsync(1);
  await Future<void>.delayed(const Duration(milliseconds: 70));

  eObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. TimeoutWithFallback - Fallback Value
  // ─────────────────────────────────────────────────────────────────────
  print('3. TimeoutWithFallback');

  final b = Cell.ingress<int>();

  final fb = TimeoutWithFallback<int>(
    const Duration(milliseconds: 40),
    fallback: -1,
  ).toHandle(source: b.cell);

  final fObs = Cell.observe(
    source: fb.cell,
    effect: (Pulse p) =>
        print('   [TimeoutWithFallback] ${p.payload == -1 ? 'none' : p.payload}'),
  );

  await b.emitAsync(1);
  await Future<void>.delayed(const Duration(milliseconds: 70));

  fObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. TimeoutFirst - Overall Deadline
  // ─────────────────────────────────────────────────────────────────────
  print('4. TimeoutFirst - overall deadline');

  final c = Cell.ingress<int>();

  final first = TimeoutFirst<int>(
    const Duration(milliseconds: 50),
    onError: (_, __) {},
  ).toHandle(source: c.cell);

  final dObs = Cell.observe(
    source: first.cell,
    effect: (Pulse p) =>
        print('   [TimeoutFirst] ${p.type == 'error' ? 'error' : p.payload}'),
  );

  await c.emitAsync(1);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await c.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 50));

  dObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 5. TimeoutLast - Idle After Last
  // ─────────────────────────────────────────────────────────────────────
  print('5. TimeoutLast - idle after last');

  final lastIn = Cell.ingress<int>();

  final last = TimeoutLast<int>(
    const Duration(milliseconds: 40),
    onError: (_, __) {},
  ).toHandle(source: lastIn.cell);

  final lObs = Cell.observe(
    source: last.cell,
    effect: (Pulse p) =>
        print('   [TimeoutLast] ${p.type == 'error' ? 'error' : p.payload}'),
  );

  await lastIn.emitAsync(1);
  await Future<void>.delayed(const Duration(milliseconds: 70));

  lObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}