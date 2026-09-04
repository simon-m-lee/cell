// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that forward a prefix of a stream (Rx `take` family).
///
/// These operators take a limited number of values from the beginning of a
/// stream and then stop forwarding. They are essential for limiting the
/// number of values processed, implementing pagination, or taking samples.
///
/// | Operator | Rx analogue | Stops after |
/// |---|---|---|
/// | [Take] | `take` | [count] values |
/// | [TakeWhile] | `takeWhile` | [predicate] becomes false |
/// | [TakeUntil] | `takeUntil` | [notifier] emits |
/// | [TakeUntilTime] | `takeUntil` + timer | [duration] elapses |
///
/// After the operator is done it stays silent. It does not complete the
/// source Cell.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef TakeErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse? _typedOrError<S>(
    Pulse pulse, {
      TakeErrorHandler? onError,
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

Pulse _mark(Pulse pulse, String step) => pulse.withStep(step);

// ─────────────────────────────────────────────────────────────
// Take
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that forwards the first [count] typed pulses
/// (Rx `take`).
///
/// [Take] acts as a **Count-Based Taker**. It forwards the first N values
/// from the stream and then stops forwarding, remaining silent for all
/// subsequent values.
///
/// ### When to use
/// Use [Take] when you need to limit the number of values:
///
/// - **Prefetch**: Getting the first page of results
/// - **Sampling**: Taking a sample of data
/// - **Capping**: Capping a burst of events
/// - **Testing**: Testing with a fixed number of values
/// - **Pagination**: Implementing "take N" operations
/// - **Limiting**: Limiting the number of processed items
/// - **Preview**: Showing a preview of data
/// - **Batching**: Taking a batch of items
///
/// ### Choosing Between Take Patterns
/// - **Use [Take]** for **Count-Based Take**: When you want to take a
///   specific number of values.
/// - **Use [TakeWhile]** for **Conditional Take**: When you want to take
///   based on a condition.
/// - **Use [TakeUntil]** for **Event-Based Take**: When you want to take
///   until an event occurs.
/// - **Use [TakeUntilTime]** for **Time-Based Take**: When you want to take
///   until a time elapses.
///
/// ### Comparison with Other Operators
/// | Operator | Stop Condition | Memory | Use Case |
/// |----------|----------------|--------|----------|
/// | **Take** | Count | O(1) | First N values |
/// | **TakeWhile** | Condition | O(1) | Conditional prefix |
/// | **TakeUntil** | Event | O(1) | Event-based |
/// | **TakeUntilTime** | Time | O(1) | Time-based |
/// | **Skip** | Skip N then forward | O(1) | Skip prefix |
///
/// ### How it works
/// 1. Each incoming pulse's payload is extracted and type-checked.
/// 2. A counter tracks how many values have been taken.
/// 3. If the counter is less than [count], the pulse passes through.
/// 4. If the counter reaches [count], the stream closes and all subsequent
///    pulses are dropped.
/// 5. Results are emitted in input order.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Terminal State**: Once the count is reached, the stream closes.
/// - **State Persistence**: The instruction maintains a counter.
/// - **Order Preservation**: Results are emitted in the same order as inputs.
/// - **No Completion Signal**: The source cell is not completed.
/// - **Error Handling**: Type errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only an integer counter is stored.
///
/// ### Example: Take First 3 Values
/// ```dart
/// final ticks = Cell.ingress<int>();
/// val first3 = Take<int>(3).toHandle(source: ticks.cell);
///
/// ticks.emit(1); // passes through
/// ticks.emit(2); // passes through
/// ticks.emit(3); // passes through
/// ticks.emit(4); // dropped (stream closed)
/// ticks.emit(5); // dropped (stream closed)
/// // Result: [1, 2, 3]
/// ```
///
/// ### Example: Taking a Sample
/// ```dart
/// final events = Cell.ingress<Event>();
/// val firstEvents = Take<Event>(10)
///     .toHandle(source: events.cell);
/// ```
///
/// ### Parameters:
/// - [count]: **The Number of Values to Take.** Must be >= 0.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [TakeWhile]: For conditional taking.
/// - [TakeUntil]: For event-based taking.
/// - [TakeUntilTime]: For time-based taking.
/// - [Skip]: For skipping values.
class Take<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [Take] instruction with the specified [count].
  ///
  /// ### Parameters:
  /// - [count]: **The Number of Values to Take.** Must be >= 0.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val take = Take<int>(
  ///   3,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  Take(
      int count, {
        TakeErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      var remaining = count < 0 ? 0 : count;
      return (pulse, {cell, user}) {
        if (remaining <= 0) return null;
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        remaining--;
        return _mark(typed, 'Take');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// TakeWhile
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that forwards values while [predicate] is true
/// (Rx `takeWhile`).
///
/// [TakeWhile] acts as a **Conditional Prefix Taker**. It forwards values
/// from the beginning of the stream while a condition is true, and stops
/// forwarding when the condition fails. The failing value can optionally
/// be included.
///
/// ### When to use
/// Use [TakeWhile] when:
/// - You need to take values until a condition fails
/// - You're implementing conditional streaming
/// - You're tracking state machine transitions
/// - You're limiting based on conditions
/// - You're implementing "take until" logic
/// - You're filtering until a threshold is met
/// - You're implementing early termination
/// - You're taking a prefix based on a condition
///
/// ### How it works
/// 1. Each incoming pulse's payload is extracted and type-checked.
/// 2. The predicate is evaluated.
/// 3. If the predicate returns `true`, the value passes through.
/// 4. If the predicate returns `false`, the stream closes.
/// 5. With [inclusive], the failing value is still emitted.
/// 6. Results are emitted in input order.
/// 7. The instruction preserves causal provenance.
///
/// ### Comparison with Filter
/// | Feature | TakeWhile | Filter |
/// |---------|-----------|--------|
/// | **Behavior** | Stops after failure | Continues filtering |
/// | **Use Case** | Take prefix | Filter all |
/// | **State** | Maintains open state | Stateless |
///
/// ### Non‑obvious
/// - **Terminal State**: Once the predicate returns `false`, the stream
///   closes and no further values are emitted.
/// - **Inclusive Mode**: The failing value can be included with [inclusive].
/// - **State Persistence**: The instruction maintains an `open` flag.
/// - **Order Preservation**: Results are emitted in the same order as inputs.
/// - **Error Handling**: Errors in the predicate close the stream.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only a boolean flag is stored.
///
/// ### Example: Take Until Value >= 5
/// ```dart
/// final numbers = Cell.ingress<int>();
/// val takeWhile = TakeWhile<int>((n) => n < 5)
///     .toHandle(source: numbers.cell);
///
/// numbers.emit(1); // passes through
/// numbers.emit(2); // passes through
/// numbers.emit(3); // passes through
/// numbers.emit(4); // passes through
/// numbers.emit(5); // closes the stream (not emitted)
/// numbers.emit(6); // dropped
/// // Result: [1, 2, 3, 4]
/// ```
///
/// ### Example: Inclusive Take While
/// ```dart
/// val takeWhileInclusive = TakeWhile<int>(
///   (n) => n < 5,
///   inclusive: true
/// ).toHandle(source: numbers.cell);
///
/// // Result: [1, 2, 3, 4, 5] (5 is included)
/// ```
///
/// ### Parameters:
/// - [predicate]: **The Taking Predicate.** Returns `true` to continue
///   taking values. When it returns `false`, the stream closes.
/// - [inclusive]: **Include the Failing Value.** If `true`, the value that
///   causes the predicate to fail is still emitted.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Take]: For count-based taking.
/// - [TakeUntil]: For event-based taking.
/// - [Filter]: For filtering all values.
class TakeWhile<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [TakeWhile] instruction with the specified [predicate].
  ///
  /// ### Parameters:
  /// - [predicate]: **The Taking Predicate.** Returns `true` to continue
  ///   taking values. When it returns `false`, the stream closes.
  /// - [inclusive]: **Include the Failing Value.** If `true`, the value that
  ///   causes the predicate to fail is still emitted.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val takeWhile = TakeWhile<int>(
  ///   (n) => n < 5,
  ///   inclusive: true,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  TakeWhile(
      bool Function(S value) predicate, {
        bool inclusive = false,
        TakeErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      var open = true;
      return (pulse, {cell, user}) {
        if (!open) return null;
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final value = typed.payload as S;
        late final bool pass;
        try {
          pass = predicate(value);
        } catch (e, stack) {
          onError?.call(e, stack);
          open = false;
          return null;
        }
        if (pass) return _mark(typed, 'TakeWhile');
        open = false;
        return inclusive ? _mark(typed, 'TakeWhile.inclusive') : null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// TakeUntil
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that forwards values until [notifier] emits
/// any pulse (Rx `takeUntil`).
///
/// [TakeUntil] acts as an **Event-Based Taker**. It forwards values from
/// the source until the [notifier] cell emits a pulse. Once the notifier
/// emits, the stream closes and all subsequent values are dropped.
///
/// ### When to use
/// Use [TakeUntil] when:
/// - You need to take values until an event occurs
/// - You're implementing conditional streaming
/// - You're coordinating multiple streams
/// - You're implementing a stop trigger
/// - You're waiting for a termination signal
/// - You're implementing a gate pattern
/// - You're reacting to user action to stop
/// - You're implementing a timeout with a notifier
///
/// ### How it works
/// 1. The instruction observes the [notifier] cell.
/// 2. Initially, all values from the source are forwarded.
/// 3. When the [notifier] emits a value, the stream closes.
/// 4. After the notifier emits, all subsequent source values are dropped.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **State**: The instruction maintains an `open` flag.
/// - **Once Closed**: The stream cannot be opened again.
/// - **First Value**: The notifier's value is not passed through.
/// - **Memory Efficiency**: Only a boolean flag is stored.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Take Until Stop
/// ```dart
/// final source = Cell.ingress<int>();
/// final stop = Cell.ingress<void>();
/// val takeUntilStop = TakeUntil<int>(stop.cell)
///     .toHandle(source: source.cell);
///
/// source.emit(1); // passes through
/// source.emit(2); // passes through
/// stop.emit(null); // closes the stream
/// source.emit(3); // dropped
/// source.emit(4); // dropped
/// // Result: [1, 2]
/// ```
///
/// ### Parameters:
/// - [notifier]: **The Closing Event Source.** The cell that triggers the
///   stream closing when it emits a value.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [TakeWhile]: For conditional taking.
/// - [TakeUntilTime]: For time-based taking.
/// - [Take]: For count-based taking.
class TakeUntil<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [TakeUntil] instruction with the specified [notifier].
  ///
  /// ### Parameters:
  /// - [notifier]: **The Closing Event Source.** The cell that triggers the
  ///   stream closing when it emits a value.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val takeUntil = TakeUntil<int>(
  ///   stop.cell,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  TakeUntil(
      Cell notifier, {
        TakeErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final state = _OpenState();
      Cell.observe(
        source: notifier,
        effect: (Pulse _) {
          state.open = false;
        },
      );
      return (pulse, {cell, user}) {
        if (!state.open) return null;
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        return _mark(typed, 'TakeUntil');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// TakeUntilTime
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that forwards values until a time elapses
/// (timer `takeUntil`).
///
/// [TakeUntilTime] acts as a **Time-Based Taker**. It forwards values from
/// the source until a specified duration has elapsed after the first value
/// arrives, then closes the stream.
///
/// ### When to use
/// Use [TakeUntilTime] when:
/// - You need to take values during a limited time window
/// - You're implementing a timeout for data collection
/// - You're taking a sample within a time period
/// - You're implementing a time-limited operation
/// - You're collecting data for a fixed duration
/// - You're implementing a windowed operation
/// - You're taking a snapshot within a timeframe
///
/// ### How it works
/// 1. The first typed pulse starts a timer.
/// 2. All values are forwarded until the timer expires.
/// 3. When the timer expires, the stream closes.
/// 4. All subsequent values are dropped.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Timer**: The timer starts on the first pulse, not at creation.
/// - **Once Closed**: The stream cannot be opened again.
/// - **Time Window**: There is a limited time window for values.
/// - **Memory Efficiency**: Only a timer and flag are stored.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Take First 40ms of Values
/// ```dart
/// final numbers = Cell.ingress<int>();
/// val takeUntilTime = TakeUntilTime<int>(
///   Duration(milliseconds: 40)
/// ).toHandle(source: numbers.cell);
///
/// numbers.emit(1); // passes through
/// numbers.emit(2); // passes through
/// // After 40ms
/// numbers.emit(3); // dropped (timer expired)
/// numbers.emit(4); // dropped (timer expired)
/// // Result: [1, 2]
/// ```
///
/// ### Parameters:
/// - [duration]: **The Time Duration.** The time window after the first
///   value before the stream closes.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [TakeUntil]: For event-based taking.
/// - [TakeWhile]: For conditional taking.
/// - [Take]: For count-based taking.
class TakeUntilTime<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [TakeUntilTime] instruction with the specified [duration].
  ///
  /// ### Parameters:
  /// - [duration]: **The Time Duration.** The time window after the first
  ///   value before the stream closes.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val takeUntilTime = TakeUntilTime<int>(
  ///   Duration(milliseconds: 100),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  TakeUntilTime(
      Duration duration, {
        TakeErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final state = _OpenState();
      var armed = false;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        if (!armed) {
          armed = true;
          Timer(duration, () {
            state.open = false;
          });
        }
        if (!state.open) return null;
        return _mark(typed, 'TakeUntilTime');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

/// Internal state for [TakeUntil] and [TakeUntilTime].
class _OpenState {
  bool open = true;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Take] instruction and related operators
/// showing their behavior in various taking scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Take Operators Demo ───────────────────────────────────────
///
/// 1. Take - first 3
///    [Take] 1
///    [Take] 2
///    [Take] 3
///
/// 2. TakeWhile - while < 3
///    [TakeWhile] 1
///    [TakeWhile] 2
///
/// 3. TakeUntil - closed by stop cell
///    [TakeUntil] a
///    [TakeUntil] b
///
/// 4. TakeUntilTime
///    [TakeUntilTime] 1
///    [TakeUntilTime] 2
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
/// 1. **Take - first 3**: Shows count-based taking. The first 3 values
///    are taken, then the stream closes.
///    `1, 2, 3, 4, 5` → `1, 2, 3`
///
/// 2. **TakeWhile - while < 3**: Shows conditional prefix taking. Values
///    are taken until the condition fails, then the stream closes.
///    `1, 2, 3, 4` → `1, 2`
///
/// 3. **TakeUntil - closed by stop cell**: Shows event-based taking.
///    Values are taken until the notifier emits, then the stream closes.
///    `a, b, c` → `a, b` (after stop emits)
///
/// 4. **TakeUntilTime**: Shows time-based taking. Values are taken until
///    a timer expires, then the stream closes.
///    `1, 2, 3` → `1, 2` (after 40ms)
///
/// ### Key Takeaways
/// - Take takes a fixed number of values from the start.
/// - TakeWhile takes values until a condition fails.
/// - TakeUntil takes values until an event occurs.
/// - TakeUntilTime takes values until a time elapses.
/// - All take operators close the stream after their condition is met.
/// - The source cell is not completed; it just becomes silent.
/// - All operators preserve causal provenance via EvolvedPulse.
Future<void> main() async {
  print('── Take Operators Demo ───────────────────────────────────────\n');

  print('1. Take - first 3');
  final ticks = Cell.ingress<int>();
  final first = Take<int>(3).toHandle(source: ticks.cell);
  final tObs = Cell.observe(
    source: first.cell,
    effect: (Pulse p) => print('   [Take] ${p.payload}'),
  );
  for (final n in [1, 2, 3, 4, 5]) {
    await ticks.emitAsync(n);
  }
  tObs.stop();
  print('');

  print('2. TakeWhile - while < 3');
  final nums = Cell.ingress<int>();
  final whileLt = TakeWhile<int>((n) => n < 3).toHandle(source: nums.cell);
  final wObs = Cell.observe(
    source: whileLt.cell,
    effect: (Pulse p) => print('   [TakeWhile] ${p.payload}'),
  );
  for (final n in [1, 2, 3, 4]) {
    await nums.emitAsync(n);
  }
  wObs.stop();
  print('');

  print('3. TakeUntil - closed by stop cell');
  final letters = Cell.ingress<String>();
  final stop = Cell.ingress<void>();
  final until = TakeUntil<String>(stop.cell).toHandle(source: letters.cell);
  final uObs = Cell.observe(
    source: until.cell,
    effect: (Pulse p) => print('   [TakeUntil] ${p.payload}'),
  );
  await letters.emitAsync('a');
  await letters.emitAsync('b');
  await stop.emitAsync(null);
  await letters.emitAsync('c');
  uObs.stop();
  print('');

  print('4. TakeUntilTime');
  final timed = Cell.ingress<int>();
  final window =
  TakeUntilTime<int>(const Duration(milliseconds: 40)).toHandle(source: timed.cell);
  final dObs = Cell.observe(
    source: window.cell,
    effect: (Pulse p) => print('   [TakeUntilTime] ${p.payload}'),
  );
  await timed.emitAsync(1);
  await timed.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  await timed.emitAsync(3);
  dObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}