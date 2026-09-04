// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Delay Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that shift values in time (Rx `delay` family).
///
/// | Operator | Wait |
/// |---|---|
/// | [Delay] | fixed [duration] |
/// | [DelayWithSelector] | [durationOf] the payload |
/// | [DelayWhen] | inner Future / Duration / Stream first event |
/// | [DelayLatest] | like [Delay], but a new pulse cancels the pending one |
/// | [DelayWithTimeout] | [Delay] + give up after [timeout] |
///
/// [DelayLatest] is the trailing-only cousin (`DelayWithTrailing`).
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for delay operators.
///
/// Called when an error occurs during delay operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = DelayErrorHandler((error, stack) {
///   print('Delay error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef DelayErrorHandler = void Function(Object error, StackTrace? stackTrace);

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
      DelayErrorHandler? onError,
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

/// Waits for a notifier to complete.
///
/// [_until] handles various notifier types:
/// - `null`: returns immediately
/// - `Duration`: delays for that duration
/// - `Future`: waits for the future to complete
/// - `Stream`: waits for the first event
///
/// ### Parameters:
/// - [notifier]: The object to wait for.
///
/// ### Returns:
/// A `Future` that completes when the notifier is ready.
///
/// ### Non‑obvious
/// - **Duration**: Uses `Future.delayed`.
/// - **Future**: Awaits the future.
/// - **Stream**: Awaits the first event.
/// - **Null**: Returns immediately.
Future<void> _until(Object? notifier) async {
  if (notifier == null) return;
  if (notifier is Duration) {
    await Future<void>.delayed(notifier);
    return;
  }
  if (notifier is Future) {
    await notifier;
    return;
  }
  if (notifier is Stream) {
    await notifier.first;
  }
}

// ─────────────────────────────────────────────────────────────
// Delay - Fixed Delay
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that shifts every typed pulse by [duration]
/// (Rx `delay`).
///
/// [Delay] is the fundamental delay operator. It delays each pulse
/// by a fixed duration before forwarding it.
///
/// ### When to use
/// Use [Delay] when you need to introduce a fixed time delay
/// between receiving a pulse and forwarding it.
///
/// - **Debouncing**: Delaying actions to avoid rapid triggers.
/// - **Animation**: Delaying UI updates for animation timing.
/// - **Throttling**: Introducing latency for rate limiting.
/// - **Synchronization**: Synchronizing with external timing.
/// - **Testing**: Simulating network latency.
/// - **User Experience**: Adding deliberate delays for UX.
///
/// ### Choosing Between Delay Variants
/// - **Use [Delay]** for **Fixed Delay**: When the delay is constant.
/// - **Use [DelayWithSelector]** for **Payload-Dependent Delay**:
///   When the delay depends on the payload.
/// - **Use [DelayWhen]** for **Conditional Delay**: When the delay
///   depends on a notifier (Future, Duration, Stream).
/// - **Use [DelayLatest]** for **Trailing Delay**: When a new pulse
///   cancels the pending one.
/// - **Use [DelayWithTimeout]** for **Timeout**: When the delay must
///   not exceed a timeout.
///
/// ### Comparison with Other Operators
/// | Operator | Delay Source | Cancels | Timeout |
/// |----------|--------------|---------|---------|
/// | **Delay** | Fixed | No | No |
/// | **DelayWithSelector** | Payload | No | No |
/// | **DelayWhen** | Notifier | No | No |
/// | **DelayLatest** | Fixed | Yes | No |
/// | **DelayWithTimeout** | Fixed | No | Yes |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. A timer is started for [duration].
/// 3. When the timer fires, the pulse is forwarded.
/// 4. The pulse gets the step `'Delay'` for provenance.
///
/// ### Non‑obvious
/// - **Fixed Delay**: The delay is the same for all pulses.
/// - **No Cancellation**: Previous delays are not cancelled.
/// - **Provenance Preservation**: The forwarded pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Timer Management**: Timers are scheduled and managed automatically.
///
/// ### Example: Fixed Delay
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final delayed = Delay<int>(
///   Duration(milliseconds: 500),
/// ).toHandle(source: input.cell);
///
/// input.emit(42); // Will be emitted after 500ms
/// ```
///
/// ### Parameters:
/// - [duration]: **Delay Duration.** The time to wait before
///   forwarding each pulse.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that delays each pulse by a fixed duration.
///
/// ### See Also:
/// - [DelayWithSelector]: For payload-dependent delay.
/// - [DelayWhen]: For notifier-based delay.
/// - [DelayLatest]: For trailing delay.
/// - [DelayWithTimeout]: For delay with timeout.
class Delay<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Delay(
      Duration duration, {
        DelayErrorHandler? onError,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      Future<void>.delayed(duration, () {
        future!(
          result: typed.withStep('Delay'),
          token: token,
        );
      });
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// DelayWithSelector - Payload-Dependent Delay
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] where [durationOf] picks the wait from the
/// payload.
///
/// [DelayWithSelector] is similar to [Delay] but the delay duration
/// is computed from the payload value. This allows different delays
/// for different values.
///
/// ### When to use
/// Use [DelayWithSelector] when the delay depends on the payload.
///
/// - **Priority-Based Delay**: Higher priority values get shorter delays.
/// - **Size-Based Delay**: Larger items get longer delays.
/// - **Type-Based Delay**: Different types get different delays.
/// - **Conditional Delay**: Delay based on payload conditions.
/// - **Adaptive Delay**: Delay adapts to payload characteristics.
///
/// ### Example: Size-Based Delay
/// ```dart
/// final input = Cell.ingress<String>();
///
/// final delayed = DelayWithSelector<String>(
///   (str) => Duration(milliseconds: str.length * 10),
/// ).toHandle(source: input.cell);
///
/// input.emit('a');    // 10ms delay
/// input.emit('hello'); // 50ms delay
/// ```
///
/// ### Example: Priority-Based Delay
/// ```dart
/// final tasks = Cell.ingress<Task>();
///
/// final delayed = DelayWithSelector<Task>(
///   (task) => Duration(milliseconds: task.priority == 'high' ? 10 : 100),
/// ).toHandle(source: tasks.cell);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. [durationOf] is called with the payload.
/// 3. A timer is started for the computed duration.
/// 4. When the timer fires, the pulse is forwarded.
/// 5. The pulse gets the step `'DelayWithSelector'` for provenance.
///
/// ### Non‑obvious
/// - **Payload-Dependent**: The delay is computed from the payload.
/// - **Error Handling**: If [durationOf] throws, the pulse is dropped.
/// - **Provenance Preservation**: The forwarded pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Extraction**: [durationOf] is synchronous.
///
/// ### Parameters:
/// - [durationOf]: **Duration Selector.** Called with each typed
///   payload, returns the delay duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that delays based on the payload.
///
/// ### See Also:
/// - [Delay]: For fixed delay.
/// - [DelayWhen]: For notifier-based delay.
/// - [DelayLatest]: For trailing delay.
/// - [DelayWithTimeout]: For delay with timeout.
class DelayWithSelector<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  DelayWithSelector(
      Duration Function(S value) durationOf, {
        DelayErrorHandler? onError,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      late final Duration wait;
      try {
        wait = durationOf(typed.payload as S);
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
      Future<void>.delayed(wait, () {
        future!(
          result: typed.withStep('DelayWithSelector'),
          token: token,
        );
      });
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// DelayWhen - Notifier-Based Delay
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that waits for [when] to complete
/// (Future / Duration / Stream.first) before forwarding the pulse
/// (Rx `delayWhen`).
///
/// [DelayWhen] is a flexible delay operator that can wait for a
/// Duration, a Future, or the first event of a Stream.
///
/// ### When to use
/// Use [DelayWhen] when the delay depends on an external notifier.
///
/// - **External Events**: Waiting for external events before forwarding.
/// - **Async Conditions**: Waiting for async conditions to complete.
/// - **Stream Signals**: Waiting for the first stream event.
/// - **Complex Timing**: Coordinating with complex timing signals.
/// - **Synchronization**: Synchronizing with external processes.
///
/// ### Example: Waiting for a Future
/// ```dart
/// final input = Cell.ingress<String>();
///
/// final delayed = DelayWhen<String>(
///   (_) => Future.delayed(Duration(seconds: 1)),
/// ).toHandle(source: input.cell);
///
/// // Emits after the Future completes
/// ```
///
/// ### Example: Waiting for a Stream
/// ```dart
/// final input = Cell.ingress<String>();
/// final trigger = StreamController<void>.broadcast();
///
/// final delayed = DelayWhen<String>(
///   (_) => trigger.stream.first,
/// ).toHandle(source: input.cell);
///
/// // Emits when the trigger stream emits
/// ```
///
/// ### Example: Duration
/// ```dart
/// final input = Cell.ingress<String>();
///
/// final delayed = DelayWhen<String>(
///   (_) => Duration(seconds: 1),
/// ).toHandle(source: input.cell);
///
/// // Emits after 1 second
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. [when] is called with the payload to get a notifier.
/// 3. The notifier is awaited:
///    - `Duration`: uses `Future.delayed`
///    - `Future`: awaits the future
///    - `Stream`: waits for the first event
///    - `null`: returns immediately
/// 4. When the notifier completes, the pulse is forwarded.
/// 5. The pulse gets the step `'DelayWhen'` for provenance.
///
/// ### Non‑obvious
/// - **Flexible Notifier**: Supports Duration, Future, Stream, null.
/// - **Async Wait**: The wait is asynchronous.
/// - **Error Handling**: If [when] throws or the notifier errors,
///   the error is reported.
/// - **Provenance Preservation**: The forwarded pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Stream First**: For Stream, waits for the first event only.
///
/// ### Parameters:
/// - [when]: **Notifier Factory.** Called with each typed payload,
///   returns a Duration, Future, Stream, or null to wait for.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that delays based on a notifier.
///
/// ### See Also:
/// - [Delay]: For fixed delay.
/// - [DelayWithSelector]: For payload-dependent delay.
/// - [DelayLatest]: For trailing delay.
/// - [DelayWithTimeout]: For delay with timeout.
class DelayWhen<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  DelayWhen(
      FutureOr<Object?> Function(S value) when, {
        DelayErrorHandler? onError,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      Future<void> run() async {
        try {
          final notifier = await Future.sync(() => when(typed.payload as S));
          await _until(notifier);
          future!(
            result: typed.withStep('DelayWhen'),
            token: token,
          );
        } catch (e, stack) {
          onError?.call(e, stack);
        }
      }

      run();
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// DelayLatest - Trailing Delay
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that only delivers the latest pulse after
/// [duration] (`DelayWithTrailing`).
///
/// [DelayLatest] is similar to [Delay] but when a new pulse arrives,
/// it cancels the pending delayed pulse. Only the latest pulse is
/// delivered.
///
/// ### When to use
/// Use [DelayLatest] when you only care about the latest value
/// after a delay.
///
/// - **Search-as-you-type**: Only the latest search query matters.
/// - **Real-time Updates**: Only the most recent update is relevant.
/// - **User Input**: Only the latest user input matters.
/// - **Selection Changes**: Only the latest selection matters.
/// - **Debouncing with Reset**: Debouncing with cancellation on new input.
///
/// ### Example: Trailing Delay
/// ```dart
/// final input = Cell.ingress<String>();
///
/// final delayed = DelayLatest<String>(
///   Duration(milliseconds: 300),
/// ).toHandle(source: input.cell);
///
/// input.emit('a'); // Cancelled by 'b'
/// input.emit('b'); // Cancelled by 'c'
/// input.emit('c'); // Delivered after 300ms
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. A timer is started for [duration].
/// 3. If a new pulse arrives before the timer fires, the previous
///    timer is cancelled.
/// 4. Only the latest pulse is delivered.
/// 5. The delivered pulse gets the step `'DelayLatest'` for provenance.
///
/// ### Non‑obvious
/// - **Cancellation**: Previous timers are cancelled on new pulses.
/// - **Latest Only**: Only the latest pulse is delivered.
/// - **Trailing**: The delay is trailing (after the last pulse).
/// - **Provenance Preservation**: The delivered pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Generation Tracking**: Each pulse gets a generation ID to
///   determine if it's still current.
///
/// ### Parameters:
/// - [duration]: **Delay Duration.** The time to wait before
///   forwarding the latest pulse.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that delays the latest pulse.
///
/// ### See Also:
/// - [Delay]: For fixed delay.
/// - [DelayWithSelector]: For payload-dependent delay.
/// - [DelayWhen]: For notifier-based delay.
/// - [DelayWithTimeout]: For delay with timeout.
class DelayLatest<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  DelayLatest(
      Duration duration, {
        DelayErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var generation = 0;
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final id = ++generation;
        Future<void>.delayed(duration, () {
          if (id != generation) return;
          future!(
            result: typed.withStep('DelayLatest'),
            token: token,
          );
        });
        return null;
      };
    })(),
    user: user,
  );
}

/// Alias of [DelayLatest] for Rx compatibility.
///
/// [DelayWithTrailing] is an alias for [DelayLatest] that emphasizes
/// the trailing-edge behavior.
///
/// ### Example
/// ```dart
/// final delayed = DelayWithTrailing<String>(
///   Duration(milliseconds: 300),
/// ).toHandle(source: input.cell);
/// // Same as DelayLatest
/// ```
class DelayWithTrailing<S> extends DelayLatest<S> {
  DelayWithTrailing(
      super.duration, {
        super.onError,
        super.user,
      });
}

// ─────────────────────────────────────────────────────────────
// DelayWithTimeout - Delay with Timeout
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] like [Delay], but if the wait exceeds
/// [timeout] the pulse is dropped and [onError] sees a
/// [TimeoutException].
///
/// [DelayWithTimeout] adds a timeout to the delay. If the delay
/// exceeds the timeout, the pulse is dropped.
///
/// ### When to use
/// Use [DelayWithTimeout] when you need to ensure delays don't
/// exceed a maximum time.
///
/// - **Latency Guarantees**: Ensuring latency doesn't exceed limits.
/// - **Timeouts**: Enforcing timeout on delayed operations.
/// - **User Experience**: Preventing long delays.
/// - **Resource Protection**: Preventing resource exhaustion from
///   long delays.
/// - **Service Level Agreements**: Enforcing SLA time limits.
///
/// ### Example: Delay with Timeout
/// ```dart
/// final input = Cell.ingress<String>();
///
/// final delayed = DelayWithTimeout<String>(
///   Duration(milliseconds: 100),
///   timeout: Duration(milliseconds: 500),
/// ).toHandle(source: input.cell);
///
/// // If delay > 500ms, pulse is dropped
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If [duration] > [timeout], an error is reported and the pulse
///    is dropped.
/// 3. A timer is started for [duration].
/// 4. When the timer fires, the pulse is forwarded.
/// 5. The delivered pulse gets the step `'DelayWithTimeout'` for
///    provenance.
///
/// ### Non‑obvious
/// - **Timeout Check**: If [duration] > [timeout], the pulse is
///   dropped immediately.
/// - **No Timer**: No timer is started if the delay exceeds the timeout.
/// - **Error Reporting**: A [TimeoutException] is reported via [onError].
/// - **Provenance Preservation**: The delivered pulse preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [duration]: **Delay Duration.** The time to wait before
///   forwarding the pulse.
/// - [timeout]: **Timeout Duration.** The maximum allowed delay.
///   If [duration] > [timeout], the pulse is dropped.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that delays with a timeout.
///
/// ### See Also:
/// - [Delay]: For fixed delay.
/// - [DelayWithSelector]: For payload-dependent delay.
/// - [DelayWhen]: For notifier-based delay.
/// - [DelayLatest]: For trailing delay.
class DelayWithTimeout<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  DelayWithTimeout(
      Duration duration, {
        required Duration timeout,
        DelayErrorHandler? onError,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      if (duration > timeout) {
        onError?.call(
          TimeoutException('Delay $duration exceeds $timeout', timeout),
          StackTrace.current,
        );
        return null;
      }
      Future<void>.delayed(duration, () {
        future!(
          result: typed.withStep('DelayWithTimeout'),
          token: token,
        );
      });
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Delay] instruction and related operators
/// showing their behavior in various delay scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Delay Operators Demo ──────────────────────────────────────
///
/// 1. Delay
///    [Delay] 1
///
/// 2. DelayWithSelector
///    [DelayWithSelector] fast
///    [DelayWithSelector] slow
///
/// 3. DelayWhen
///    [DelayWhen] go
///
/// 4. DelayLatest
///    [DelayLatest] last
///
/// 5. DelayWithTimeout
///    [DelayWithTimeout] ok
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
/// 1. **Delay - Fixed Delay**: Shows fixed delay where a pulse is
///    emitted after a fixed duration. The value `1` is emitted after 30ms.
///
/// 2. **DelayWithSelector - Payload-Dependent Delay**: Shows
///    payload-dependent delay where different values have different
///    delays. `'slow'` has a 40ms delay, `'fast'` has a 5ms delay.
///    `'fast'` arrives first despite being emitted second.
///
/// 3. **DelayWhen - Notifier-Based Delay**: Shows notifier-based
///    delay where a Future is used as the notifier. The value `'go'`
///    is emitted after the Future completes.
///
/// 4. **DelayLatest - Trailing Delay**: Shows trailing delay where
///    `'first'` is cancelled by `'last'`. Only `'last'` is emitted
///    after the delay.
///
/// 5. **DelayWithTimeout - Delay with Timeout**: Shows delay with
///    timeout where the delay is within the timeout limit, so the
///    pulse is emitted.
///
/// ### Key Takeaways
/// - Delay shifts pulses in time by a fixed duration.
/// - DelayWithSelector computes the delay from the payload.
/// - DelayWhen waits for a notifier (Future, Duration, Stream).
/// - DelayLatest only delivers the latest pulse.
/// - DelayWithTimeout enforces a maximum delay time.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - _until handles Duration, Future, Stream, and null notifiers.
///
/// ### Note on Timing
/// The demo uses short delays (5-50ms) for quick execution. In
/// production, you would typically use longer durations (e.g.,
/// milliseconds to seconds) for delay operations.
Future<void> main() async {
  print('── Delay Operators Demo ──────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Delay - Fixed Delay
  // ─────────────────────────────────────────────────────────────────────
  print('1. Delay');

  final a = Cell.ingress<int>();

  final delayed = Delay<int>(
    const Duration(milliseconds: 30),
  ).toHandle(source: a.cell);

  final dObs = Cell.observe(
    source: delayed.cell,
    effect: (Pulse p) => print('   [Delay] ${p.payload}'),
  );

  await a.emitAsync(1);
  await Future<void>.delayed(const Duration(milliseconds: 50));

  dObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. DelayWithSelector - Payload-Dependent Delay
  // ─────────────────────────────────────────────────────────────────────
  print('2. DelayWithSelector');

  final b = Cell.ingress<String>();

  final selected = DelayWithSelector<String>(
        (s) => Duration(milliseconds: s == 'slow' ? 40 : 5),
  ).toHandle(source: b.cell);

  final sObs = Cell.observe(
    source: selected.cell,
    effect: (Pulse p) => print('   [DelayWithSelector] ${p.payload}'),
  );

  await b.emitAsync('slow');
  await b.emitAsync('fast');
  await Future<void>.delayed(const Duration(milliseconds: 60));

  sObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. DelayWhen - Notifier-Based Delay
  // ─────────────────────────────────────────────────────────────────────
  print('3. DelayWhen');

  final c = Cell.ingress<String>();

  final when = DelayWhen<String>(
        (_) => Future<void>.delayed(const Duration(milliseconds: 20)),
  ).toHandle(source: c.cell);

  final wObs = Cell.observe(
    source: when.cell,
    effect: (Pulse p) => print('   [DelayWhen] ${p.payload}'),
  );

  await c.emitAsync('go');
  await Future<void>.delayed(const Duration(milliseconds: 40));

  wObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. DelayLatest - Trailing Delay
  // ─────────────────────────────────────────────────────────────────────
  print('4. DelayLatest');

  final d = Cell.ingress<String>();

  final latest = DelayLatest<String>(
    const Duration(milliseconds: 30),
  ).toHandle(source: d.cell);

  final lObs = Cell.observe(
    source: latest.cell,
    effect: (Pulse p) => print('   [DelayLatest] ${p.payload}'),
  );

  await d.emitAsync('first');
  await d.emitAsync('last');
  await Future<void>.delayed(const Duration(milliseconds: 50));

  lObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 5. DelayWithTimeout - Delay with Timeout
  // ─────────────────────────────────────────────────────────────────────
  print('5. DelayWithTimeout');

  final e = Cell.ingress<String>();

  final timed = DelayWithTimeout<String>(
    const Duration(milliseconds: 10),
    timeout: const Duration(milliseconds: 50),
  ).toHandle(source: e.cell);

  final tObs = Cell.observe(
    source: timed.cell,
    effect: (Pulse p) => print('   [DelayWithTimeout] ${p.payload}'),
  );

  await e.emitAsync('ok');
  await Future<void>.delayed(const Duration(milliseconds: 30));

  tObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}