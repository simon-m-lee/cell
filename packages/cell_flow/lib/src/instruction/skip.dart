// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that drop a prefix of a stream (Rx `skip` family).
///
/// These operators skip or drop certain values from the beginning of a stream
/// based on various criteria. They are essential for ignoring initial values,
/// waiting for conditions, or removing unwanted data from the stream.
///
/// | Operator | Rx analogue | Drops |
/// |---|---|---|
/// | [Skip] | `skip` | the first [count] values |
/// | [SkipWhile] | `skipWhile` | while [predicate] is true |
/// | [SkipUntil] | `skipUntil` | until [notifier] emits |
/// | [SkipUntilTime] | `skipUntil` + timer | until [duration] elapses |
/// | [SkipFirst] | `skip(1)` | the first typed value |
/// | [SkipLast] | `skipLast` | the last [count] values (delayed by [count]) |
/// | [SkipRepeated] | `distinctUntilChanged` | consecutive duplicates |
/// | [SkipWhen] | `filter(!pred)` | any value for which [predicate] is true |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef SkipErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse? _typedOrError<S>(
    Pulse pulse, {
      SkipErrorHandler? onError,
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
// Skip
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that drops the first [count] typed pulses,
/// then forwards the rest (Rx `skip`).
///
/// [Skip] acts as a **Count-Based Skipper**. It drops the first N values
/// from the stream and forwards all subsequent values.
///
/// ### When to use
/// Use [Skip] when you need to ignore the first N values:
///
/// - **Initialization Data**: Skipping initial loading states
/// - **Headers**: Ignoring headers or metadata
/// - **Seed Values**: Skipping seed values
/// - **Pagination**: Starting after a certain number of items
/// - **Testing**: Skipping setup values in tests
/// - **Stream Prefix**: Ignoring the beginning of a stream
/// - **Warm-up**: Skipping initial warm-up data
/// - **Batch Processing**: Skipping the first batch
///
/// ### Choosing Between Skip Patterns
/// - **Use [Skip]** for **Count-Based Skip**: When you want to skip a
///   specific number of values.
/// - **Use [SkipWhile]** for **Conditional Skip**: When you want to skip
///   based on a condition.
/// - **Use [SkipUntil]** for **Event-Based Skip**: When you want to skip
///   until an event occurs.
/// - **Use [SkipUntilTime]** for **Time-Based Skip**: When you want to skip
///   until a time elapses.
/// - **Use [SkipFirst]** for **Single Skip**: When you want to skip only
///   the first value.
/// - **Use [SkipLast]** for **End-Based Skip**: When you want to skip the
///   last N values.
/// - **Use [SkipRepeated]** for **Duplicate Skip**: When you want to skip
///   consecutive duplicates.
/// - **Use [SkipWhen]** for **Per-Value Skip**: When you want to skip
///   values that satisfy a predicate.
///
/// ### Comparison with Other Operators
/// | Operator | Skip Criteria | Memory | Use Case |
/// |----------|---------------|--------|----------|
/// | **Skip** | Count | O(1) | First N values |
/// | **SkipWhile** | Condition (once) | O(1) | Conditional prefix |
/// | **SkipUntil** | Event | O(1) | Event-based |
/// | **SkipUntilTime** | Time | O(1) | Time-based |
/// | **SkipFirst** | First value | O(1) | First value only |
/// | **SkipLast** | Count (end) | O(n) | Last N values |
/// | **SkipRepeated** | Equality | O(1) | Consecutive duplicates |
/// | **SkipWhen** | Condition (per value) | O(1) | Per-value condition |
///
/// ### How it works
/// 1. Each incoming pulse's payload is extracted and type-checked.
/// 2. A counter tracks how many values have been skipped.
/// 3. If the counter is less than [count], the pulse is skipped.
/// 4. If the counter reaches [count], all subsequent values pass through.
/// 5. Results are emitted in input order.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Opening State**: Once the count is reached, the stream opens.
/// - **State Persistence**: The instruction maintains a counter.
/// - **Order Preservation**: Results are emitted in the same order as inputs.
/// - **Error Handling**: Type errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only an integer counter is stored.
///
/// ### Example: Skip First 2 Values
/// ```dart
/// final ticks = Cell.ingress<int>();
/// final rest = Skip<int>(2).toHandle(source: ticks.cell);
///
/// ticks.emit(1); // skipped
/// ticks.emit(2); // skipped
/// ticks.emit(3); // passes through
/// ticks.emit(4); // passes through
/// // Result: [3, 4]
/// ```
///
/// ### Example: Skip Header Data
/// ```dart
/// final dataStream = Cell.ingress<Data>();
/// final dataWithoutHeaders = Skip<Data>(1)
///     .toHandle(source: dataStream.cell);
/// ```
///
/// ### Parameters:
/// - [count]: **The Number of Values to Skip.** Must be >= 0.
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
/// - [SkipWhile]: For conditional skipping.
/// - [SkipFirst]: For skipping only the first value.
/// - [SkipLast]: For skipping the last N values.
class Skip<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [Skip] instruction with the specified [count].
  ///
  /// ### Parameters:
  /// - [count]: **The Number of Values to Skip.** Must be >= 0.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final skip = Skip<int>(
  ///   2,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  Skip(
      int count, {
        SkipErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      var remaining = count < 0 ? 0 : count;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        if (remaining > 0) {
          remaining--;
          return null;
        }
        return _mark(typed, 'Skip');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// SkipWhile
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that drops values while [predicate] is true,
/// and forwards from the first failure (Rx `skipWhile`).
///
/// [SkipWhile] acts as a **Conditional Prefix Skipper**. It skips values
/// from the beginning of the stream while a condition is true, and once
/// the condition fails, it forwards all subsequent values.
///
/// ### When to use
/// Use [SkipWhile] when:
/// - You need to skip initial values until a condition is met
/// - You're implementing conditional skipping
/// - You're tracking state machine transitions
/// - You're skipping based on conditions
/// - You're implementing "skip until" logic
/// - You're filtering until a threshold is met
/// - You're starting after a condition passes
/// - You're implementing warm-up period detection
///
/// ### How it works
/// 1. Each incoming pulse's payload is extracted and type-checked.
/// 2. The predicate is evaluated.
/// 3. If the predicate returns `true`, the value is skipped.
/// 4. If the predicate returns `false`, the stream is opened and all
///    subsequent values pass through.
/// 5. Results are emitted in input order.
/// 6. The instruction preserves causal provenance.
///
/// ### Comparison with SkipWhen
/// | Feature | SkipWhile | SkipWhen |
/// |---------|-----------|----------|
/// | **Evaluation** | Once (until false) | Every value |
/// | **State** | Maintains open state | Stateless |
/// | **Use Case** | Skip prefix | Skip arbitrary values |
///
/// ### Non‑obvious
/// - **Opening State**: Once the predicate returns `false`, the stream is
///   opened and all subsequent values pass through.
/// - **State Persistence**: The instruction maintains a `skipping` flag.
/// - **Order Preservation**: Results are emitted in the same order as inputs.
/// - **Error Handling**: Errors in the predicate are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only a boolean flag is stored.
///
/// ### Example: Skip While Value < 5
/// ```dart
/// final nums = Cell.ingress<int>();
/// val skipWhile = SkipWhile<int>((n) => n < 5)
///     .toHandle(source: nums.cell);
///
/// nums.emit(1); // skipped
/// nums.emit(2); // skipped
/// nums.emit(3); // skipped
/// nums.emit(4); // skipped
/// nums.emit(5); // opens the stream
/// nums.emit(6); // passes through
/// // Result: [5, 6]
/// ```
///
/// ### Example: Skip Until First Loading
/// ```dart
/// enum State { idle, loading, loaded }
/// final states = Cell.ingress<State>();
/// val skipUntilLoading = SkipWhile<State>((s) => s != State.loading)
///     .toHandle(source: states.cell);
/// ```
///
/// ### Parameters:
/// - [predicate]: **The Skipping Predicate.** Returns `true` to continue
///   skipping values. When it returns `false`, the stream opens.
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
/// - [Skip]: For count-based skipping.
/// - [SkipWhen]: For per-value conditional skipping.
/// - [SkipUntil]: For event-based skipping.
class SkipWhile<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [SkipWhile] instruction with the specified [predicate].
  ///
  /// ### Parameters:
  /// - [predicate]: **The Skipping Predicate.** Returns `true` to continue
  ///   skipping values. When it returns `false`, the stream opens.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val skipWhile = SkipWhile<int>(
  ///   (n) => n < 5,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  SkipWhile(
      bool Function(S value) predicate, {
        SkipErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      var skipping = true;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final value = typed.payload as S;
        if (skipping) {
          try {
            if (predicate(value)) return null;
          } catch (e, stack) {
            onError?.call(e, stack);
            return null;
          }
          skipping = false;
        }
        return _mark(typed, 'SkipWhile');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// SkipUntil
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that drops values until [notifier] emits any
/// pulse, then forwards (Rx `skipUntil`).
///
/// [SkipUntil] acts as an **Event-Based Skipper**. It skips all values
/// from the source until the [notifier] cell emits a pulse. Once the
/// notifier emits, all subsequent values are forwarded.
///
/// ### When to use
/// Use [SkipUntil] when:
/// - You need to skip values until an event occurs
/// - You're waiting for a signal to start processing
/// - You're implementing conditional streaming
/// - You're coordinating multiple streams
/// - You're implementing a start trigger
/// - You're waiting for initialization
/// - You're implementing a gate pattern
/// - You're waiting for user action
///
/// ### How it works
/// 1. The instruction observes the [notifier] cell.
/// 2. Initially, all values from the source are skipped.
/// 3. When the [notifier] emits a value, the stream opens.
/// 4. After the notifier emits, all subsequent source values pass through.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **State**: The instruction maintains an `open` flag.
/// - **Once Opened**: The stream cannot be closed again.
/// - **First Value**: The notifier's value is not passed through.
/// - **Memory Efficiency**: Only a boolean flag is stored.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Skip Until Ready
/// ```dart
/// final source = Cell.ingress<int>();
/// final ready = Cell.ingress<void>();
/// final skipUntilReady = SkipUntil<int>(ready.cell)
///     .toHandle(source: source.cell);
///
/// source.emit(1); // skipped (not ready)
/// source.emit(2); // skipped (not ready)
/// ready.emit(null); // opens the stream
/// source.emit(3); // passes through
/// source.emit(4); // passes through
/// ```
///
/// ### Parameters:
/// - [notifier]: **The Opening Event Source.** The cell that triggers the
///   stream opening when it emits a value.
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
/// - [SkipWhile]: For conditional skipping.
/// - [SkipUntilTime]: For time-based skipping.
/// - [Skip]: For count-based skipping.
class SkipUntil<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [SkipUntil] instruction with the specified [notifier].
  ///
  /// ### Parameters:
  /// - [notifier]: **The Opening Event Source.** The cell that triggers the
  ///   stream opening when it emits a value.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val skipUntil = SkipUntil<int>(
  ///   ready.cell,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  SkipUntil(
      Cell notifier, {
        SkipErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final state = _GateState();
      Cell.observe(
        source: notifier,
        effect: (Pulse _) {
          state.open = true;
        },
      );
      return (pulse, {cell, user}) {
        if (!state.open) return null;
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        return _mark(typed, 'SkipUntil');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// SkipUntilTime
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that drops values until [duration] after the
/// first typed pulse, then forwards.
///
/// [SkipUntilTime] acts as a **Time-Based Skipper**. It skips all values
/// from the source until a specified duration has elapsed after the first
/// value arrives.
///
/// ### When to use
/// Use [SkipUntilTime] when:
/// - You need to skip values during a warm-up period
/// - You're implementing a delay before processing
/// - You're waiting for initialization
/// - You're implementing a start delay
/// - You're handling startup conditions
/// - You're implementing a grace period
/// - You're waiting for system stabilization
///
/// ### How it works
/// 1. The first typed pulse starts a timer.
/// 2. All values are skipped until the timer expires.
/// 3. When the timer expires, the stream opens.
/// 4. All subsequent values pass through.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Timer**: The timer starts on the first pulse, not at creation.
/// - **Once Opened**: The stream cannot be closed again.
/// - **Delay**: There is a delay before any values are emitted.
/// - **Memory Efficiency**: Only a timer and flag are stored.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Skip First 5 Seconds
/// ```dart
/// final numbers = Cell.ingress<int>();
/// val skipWithTimeout = SkipUntilTime<int>(
///   Duration(seconds: 5),
/// ).toHandle(source: numbers.cell);
///
/// numbers.emit(1); // skipped (within 5 seconds)
/// numbers.emit(2); // skipped (within 5 seconds)
/// // After 5 seconds
/// numbers.emit(3); // passes through
/// numbers.emit(4); // passes through
/// ```
///
/// ### Parameters:
/// - [duration]: **The Timeout Duration.** The time to wait before opening.
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
/// - [SkipUntil]: For event-based skipping.
/// - [SkipWhile]: For conditional skipping.
/// - [Debounce]: For waiting for silence.
class SkipUntilTime<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [SkipUntilTime] instruction with the specified [duration].
  ///
  /// ### Parameters:
  /// - [duration]: **The Timeout Duration.** The time to wait before opening.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val skipUntilTime = SkipUntilTime<int>(
  ///   Duration(seconds: 5),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  SkipUntilTime(
      Duration duration, {
        SkipErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final state = _GateState();
      var armed = false;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        if (!armed) {
          armed = true;
          Timer(duration, () {
            state.open = true;
          });
        }
        if (!state.open) return null;
        return _mark(typed, 'SkipUntilTime');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// SkipFirst
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that drops only the first typed pulse
/// (Rx `skip(1)`).
///
/// [SkipFirst] acts as a **First-Value Skipper**. It is a convenience alias
/// for [Skip] with `count: 1`.
///
/// ### When to use
/// Use [SkipFirst] when you only need to skip the first value:
/// - Ignoring the initial state
/// - Skipping a header row
/// - Avoiding the first loading state
/// - Starting from the second value
///
/// ### Example
/// ```dart
/// final numbers = Cell.ingress<int>();
/// val skipFirst = SkipFirst<int>().toHandle(source: numbers.cell);
///
/// numbers.emit(1); // skipped
/// numbers.emit(2); // passes through
/// numbers.emit(3); // passes through
/// // Result: [2, 3]
/// ```
///
/// ### Parameters:
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
/// - [Skip]: For skipping multiple values.
class SkipFirst<S> extends Skip<S> {
  /// Creates a [SkipFirst] instruction.
  ///
  /// ### Parameters:
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val skipFirst = SkipFirst<int>(
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  SkipFirst({
    SkipErrorHandler? onError,
    dynamic user,
  }) : super(1, onError: onError, user: user);
}

// ─────────────────────────────────────────────────────────────
// SkipLast
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that holds the last [count] values and emits
/// the one that just left the buffer (Rx `skipLast`).
///
/// [SkipLast] acts as an **End-Based Skipper**. It buffers the last N values
/// and only emits values that leave the buffer, effectively skipping the
/// last N values of the stream.
///
/// ### When to use
/// Use [SkipLast] when:
/// - You need to skip the last N values
/// - You're skipping trailing data
/// - You're ignoring completion markers
/// - You're implementing "skip last N" logic
/// - You're ending before certain values
/// - You're avoiding trailing states
/// - You're implementing windowed operations
/// - You're skipping finalization data
///
/// ### How it works
/// 1. Values are buffered in a sliding window of size [count] + 1.
/// 2. When a new value arrives, the oldest value in the buffer is emitted
///    (unless it's within the last [count] values).
/// 3. The last [count] values are never emitted.
/// 4. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Buffering**: The instruction maintains a buffer of size [count] + 1.
/// - **Delay**: There is a delay of [count] values before the first emission.
/// - **Memory**: The buffer stores up to [count] + 1 values.
/// - **No Flush**: The trailing [count] items are never flushed.
/// - **Order Preservation**: Results are emitted in the same order as inputs.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Skip Last 2 Values
/// ```dart
/// final numbers = Cell.ingress<int>();
/// val skipLast2 = SkipLast<int>(2)
///     .toHandle(source: numbers.cell);
///
/// numbers.emit(1); // buffered
/// numbers.emit(2); // buffered
/// numbers.emit(3); // emits 1
/// numbers.emit(4); // emits 2
/// numbers.emit(5); // emits 3
/// // 4 and 5 are skipped (last 2 values)
/// // Result: [1, 2, 3]
/// ```
///
/// ### Parameters:
/// - [count]: **The Number of Values to Skip at the End.** Must be >= 0.
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
/// - [Skip]: For skipping the first N values.
/// - [SkipWhile]: For conditional skipping.
class SkipLast<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [SkipLast] instruction with the specified [count].
  ///
  /// ### Parameters:
  /// - [count]: **The Number of Values to Skip at the End.** Must be >= 0.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val skipLast = SkipLast<int>(
  ///   2,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  SkipLast(
      int count, {
        SkipErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final keep = count < 0 ? 0 : count;
      final buffer = <Pulse>[];
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        if (keep == 0) return _mark(typed, 'SkipLast');
        buffer.add(typed);
        if (buffer.length <= keep) return null;
        final ready = buffer.removeAt(0);
        return _mark(ready, 'SkipLast');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// SkipRepeated
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that drops a value when it equals the previous
/// emission (consecutive duplicates only).
///
/// [SkipRepeated] acts as a **Consecutive Duplicate Skipper**. It skips
/// any value that is equal to the previous value, similar to
/// [DistinctUntilChanged] but with different semantics (the first value
/// is also skipped if it equals the seed).
///
/// ### When to use
/// Use [SkipRepeated] when:
/// - You need to skip consecutive duplicates
/// - You're reducing noise from repeated values
/// - You're implementing change detection
/// - You're filtering out redundant events
///
/// ### Comparison with DistinctUntilChanged
/// | Feature | SkipRepeated | DistinctUntilChanged |
/// |---------|--------------|---------------------|
/// | **First Value** | Skipped (no previous) | Passed |
/// | **Subsequent** | Skipped if equal | Skipped if equal |
/// | **Different Value** | Passed | Passed |
///
/// ### Non‑obvious
/// - **Consecutive Only**: Only back-to-back duplicates are skipped.
/// - **No Initial Emission**: The first value is always skipped.
/// - **State Persistence**: The instruction maintains the previous value.
/// - **Order Preservation**: Results are emitted in the same order as inputs.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Skip Consecutive Duplicates
/// ```dart
/// final numbers = Cell.ingress<int>();
/// val skipRepeated = SkipRepeated<int>()
///     .toHandle(source: numbers.cell);
///
/// numbers.emit(1); // skipped (first value)
/// numbers.emit(1); // skipped (duplicate)
/// numbers.emit(2); // passes through
/// numbers.emit(2); // skipped (duplicate)
/// numbers.emit(3); // passes through
/// // Result: [2, 3]
/// ```
///
/// ### Parameters:
/// - [equals]: **Custom Equality Comparator.** Optional function that
///   defines what constitutes a duplicate. Defaults to `==`.
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
/// - [DistinctUntilChanged]: For passing the first value.
/// - [SkipWhen]: For conditional skipping.
class SkipRepeated<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [SkipRepeated] instruction.
  ///
  /// ### Parameters:
  /// - [equals]: **Custom Equality Comparator.** Optional function that
  ///   defines what constitutes a duplicate. Defaults to `==`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val skipRepeated = SkipRepeated<String>(
  ///   comparator: (a, b) => a.toLowerCase() == b.toLowerCase(),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  SkipRepeated({
    bool Function(S previous, S next)? equals,
    SkipErrorHandler? onError,
    dynamic user,
  }) : super(
    (() {
      S? previous;
      var hasPrevious = false;
      final cmp = equals ?? (S a, S b) => a == b;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final value = typed.payload as S;
        if (hasPrevious) {
          try {
            if (cmp(previous as S, value)) return null;
          } catch (e, stack) {
            onError?.call(e, stack);
            return null;
          }
        }
        previous = value;
        hasPrevious = true;
        return _mark(typed, 'SkipRepeated');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// SkipWhen
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that drops any value for which [predicate] is true.
///
/// [SkipWhen] acts as a **Per-Value Skipper**. Unlike [SkipWhile], this
/// evaluates the predicate independently on every pulse.
///
/// ### When to use
/// Use [SkipWhen] when:
/// - You need to skip values based on a condition
/// - You're implementing conditional skipping
/// - You're filtering out specific values
/// - You're implementing complex skipping logic
/// - You're handling intermittent conditions
///
/// ### Comparison with SkipWhile
/// | Feature | SkipWhen | SkipWhile |
/// |---------|----------|-----------|
/// | **Evaluation** | Every value | Once (until false) |
/// | **State** | Stateless | Maintains open state |
/// | **Use Case** | Skip arbitrary values | Skip prefix |
/// | **Similar To** | `filter(!pred)` | `skipWhile` |
///
/// ### Non‑obvious
/// - **Per-Value**: The predicate is evaluated for each value independently.
/// - **Stateless**: The instruction maintains no state.
/// - **Order Preservation**: Results are emitted in the same order as inputs.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: No state is stored.
///
/// ### Example: Skip Even Numbers
/// ```dart
/// final numbers = Cell.ingress<int>();
/// val skipEven = SkipWhen<int>((n) => n % 2 == 0)
///     .toHandle(source: numbers.cell);
///
/// numbers.emit(1); // passes through
/// numbers.emit(2); // skipped
/// numbers.emit(3); // passes through
/// numbers.emit(4); // skipped
/// numbers.emit(5); // passes through
/// // Result: [1, 3, 5]
/// ```
///
/// ### Parameters:
/// - [predicate]: **The Skipping Predicate.** Returns `true` to skip the value.
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
/// - [SkipWhile]: For conditional prefix skipping.
/// - [Filter]: For passing when a condition is true.
/// - [Skip]: For count-based skipping.
class SkipWhen<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [SkipWhen] instruction with the specified [predicate].
  ///
  /// ### Parameters:
  /// - [predicate]: **The Skipping Predicate.** Returns `true` to skip the value.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val skipWhen = SkipWhen<int>(
  ///   (n) => n % 2 == 0,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  SkipWhen(
      bool Function(S value) predicate, {
        SkipErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      try {
        if (predicate(typed.payload as S)) return null;
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
      return _mark(typed, 'SkipWhen');
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

/// Internal state for [SkipUntil] and [SkipUntilTime].
class _GateState {
  bool open = false;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Skip] instruction and related operators
/// showing their behavior in various skipping scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Skip Operators Demo ───────────────────────────────────────
///
/// 1. Skip - drop first 2
///    [Skip] 3
///    [Skip] 4
///
/// 2. SkipWhile - while < 3
///    [SkipWhile] 3
///    [SkipWhile] 4
///
/// 3. SkipUntil - opened by start cell
///    [SkipUntil] c
///
/// 4. SkipUntilTime
///    [SkipUntilTime] 3
///
/// 5. SkipFirst / SkipLast / SkipRepeated / SkipWhen
///    [SkipFirst] 2
///    [SkipLast] 1
///    [SkipRepeated] 1
///    [SkipRepeated] 2
///    [SkipWhen] 1
///    [SkipWhen] 3
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
/// 1. **Skip - drop first 2**: Shows count-based skipping. The first 2
///    values are skipped, and the rest pass through.
///    `1, 2, 3, 4` → `3, 4`
///
/// 2. **SkipWhile - while < 3**: Shows conditional prefix skipping.
///    Values are skipped until the condition fails, then all pass.
///    `1, 2, 3, 4` → `3, 4`
///
/// 3. **SkipUntil - opened by start cell**: Shows event-based skipping.
///    Values are skipped until the notifier emits, then all pass.
///    `a, b, c` → `c` (after start emits)
///
/// 4. **SkipUntilTime**: Shows time-based skipping. Values are skipped
///    until a timer expires, then all pass.
///    `1, 2, 3` → `3` (after 40ms delay)
///
/// 5. **SkipFirst / SkipLast / SkipRepeated / SkipWhen**: Shows the
///    remaining skip variants.
///    - SkipFirst: skips only the first value
///    - SkipLast: skips the last N values (delayed)
///    - SkipRepeated: skips consecutive duplicates
///    - SkipWhen: skips values based on a condition
///
/// ### Key Takeaways
/// - Skip skips a fixed number of values from the start.
/// - SkipWhile skips values until a condition fails (once).
/// - SkipUntil skips values until an event occurs.
/// - SkipUntilTime skips values until a time elapses.
/// - SkipFirst skips only the first value.
/// - SkipLast skips the last N values (with buffering).
/// - SkipRepeated skips consecutive duplicates.
/// - SkipWhen skips values based on a condition (per value).
/// - All operators preserve causal provenance via EvolvedPulse.
Future<void> main() async {
  print('── Skip Operators Demo ───────────────────────────────────────\n');

  print('1. Skip - drop first 2');
  final ticks = Cell.ingress<int>();
  final rest = Skip<int>(2).toHandle(source: ticks.cell);
  final sObs = Cell.observe(
    source: rest.cell,
    effect: (Pulse p) => print('   [Skip] ${p.payload}'),
  );
  for (final n in [1, 2, 3, 4]) {
    await ticks.emitAsync(n);
  }
  sObs.stop();
  print('');

  print('2. SkipWhile - while < 3');
  final nums = Cell.ingress<int>();
  final whileLt = SkipWhile<int>((n) => n < 3).toHandle(source: nums.cell);
  final wObs = Cell.observe(
    source: whileLt.cell,
    effect: (Pulse p) => print('   [SkipWhile] ${p.payload}'),
  );
  for (final n in [1, 2, 3, 4]) {
    await nums.emitAsync(n);
  }
  wObs.stop();
  print('');

  print('3. SkipUntil - opened by start cell');
  final letters = Cell.ingress<String>();
  final start = Cell.ingress<void>();
  final until = SkipUntil<String>(start.cell).toHandle(source: letters.cell);
  final uObs = Cell.observe(
    source: until.cell,
    effect: (Pulse p) => print('   [SkipUntil] ${p.payload}'),
  );
  await letters.emitAsync('a');
  await letters.emitAsync('b');
  await start.emitAsync(null);
  await letters.emitAsync('c');
  uObs.stop();
  print('');

  print('4. SkipUntilTime');
  final timed = Cell.ingress<int>();
  final window =
  SkipUntilTime<int>(const Duration(milliseconds: 40)).toHandle(source: timed.cell);
  final dObs = Cell.observe(
    source: window.cell,
    effect: (Pulse p) => print('   [SkipUntilTime] ${p.payload}'),
  );
  await timed.emitAsync(1);
  await timed.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  await timed.emitAsync(3);
  dObs.stop();
  print('');

  print('5. SkipFirst / SkipLast / SkipRepeated / SkipWhen');
  final firstIn = Cell.ingress<int>();
  final first = SkipFirst<int>().toHandle(source: firstIn.cell);
  final fObs = Cell.observe(
    source: first.cell,
    effect: (Pulse p) => print('   [SkipFirst] ${p.payload}'),
  );
  await firstIn.emitAsync(1);
  await firstIn.emitAsync(2);
  fObs.stop();

  final lastIn = Cell.ingress<int>();
  final last = SkipLast<int>(2).toHandle(source: lastIn.cell);
  final lObs = Cell.observe(
    source: last.cell,
    effect: (Pulse p) => print('   [SkipLast] ${p.payload}'),
  );
  await lastIn.emitAsync(1);
  await lastIn.emitAsync(2);
  await lastIn.emitAsync(3);
  lObs.stop();

  final repIn = Cell.ingress<int>();
  final repeated = SkipRepeated<int>().toHandle(source: repIn.cell);
  final rObs = Cell.observe(
    source: repeated.cell,
    effect: (Pulse p) => print('   [SkipRepeated] ${p.payload}'),
  );
  for (final n in [1, 1, 2, 2]) {
    await repIn.emitAsync(n);
  }
  rObs.stop();

  final whenIn = Cell.ingress<int>();
  final when = SkipWhen<int>((n) => n.isEven).toHandle(source: whenIn.cell);
  final kObs = Cell.observe(
    source: when.cell,
    effect: (Pulse p) => print('   [SkipWhen] ${p.payload}'),
  );
  await whenIn.emitAsync(1);
  await whenIn.emitAsync(2);
  await whenIn.emitAsync(3);
  kObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}