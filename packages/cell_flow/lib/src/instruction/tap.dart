// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Tap Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that run a side effect without changing values
/// (Rx `tap` / `do` family).
///
/// | Operator | Rx analogue | Calls |
/// |---|---|---|
/// | [Tap] | `tap` / `doOnData` | [onValue] on each typed payload |
/// | [TapAll] | `tap` + `doOnEach` | every pulse, typed or not |
/// | [TapWithIndex] | `tap` + index | `(value, index)` |
/// | [TapState] | `tap` + fold | `(state, value)` updates a snapshot |
///
/// A throw in the side effect goes to [onError] and the pulse is
/// **dropped**. Successful taps pass the pulse through unchanged
/// (plus a lineage step).
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for tap operators.
///
/// Called when an error occurs during the side effect execution.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = TapErrorHandler((error, stack) {
///   print('Tap error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef TapErrorHandler = void Function(Object error, StackTrace? stackTrace);

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
      TapErrorHandler? onError,
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

/// Snapshot used by [TapState] to track state and count.
///
/// [TapSnapshot] holds the current state value and the number of
/// typed pulses processed. It is the in-memory accumulator for the
/// [TapState] operator.
///
/// ### When to use
/// Use [TapSnapshot] to access the accumulated state and seen count
/// from a [TapState] instruction.
///
/// ### How it works
/// 1. [value] is updated on each typed pulse.
/// 2. [seen] is incremented on each typed pulse.
/// 3. The snapshot is shared between the instruction and external code.
///
/// ### Non‑obvious
/// - **Volatile**: The snapshot is not persisted across process restarts.
/// - **In-Memory**: The state lives only in the current process.
/// - **Shared State**: The snapshot is mutable and shared with the
///   instruction.
/// - **Count Tracking**: [seen] tracks how many pulses were processed.
///
/// ### Example: Inspecting State
/// ```dart
/// final snapshot = TapSnapshot<int>(0);
/// final tap = TapState<int, int>(
///   0,
///   (acc, n) => acc + n,
///   snapshot: snapshot,
/// ).toHandle(source: input.cell);
///
/// // Later, inspect the state
/// print('Current sum: ${snapshot.value}');
/// print('Processed: ${snapshot.seen}');
/// ```
///
/// ### Type Parameters:
/// - [A]: The type of the accumulated value.
///
/// ### See Also:
/// - [TapState]: The operator that uses this snapshot.
class TapSnapshot<A> {
  /// Creates a snapshot with an initial [value].
  TapSnapshot(this.value);

  /// The current accumulated state value.
  A value;

  /// The number of typed pulses processed.
  int seen = 0;
}

// ─────────────────────────────────────────────────────────────
// Tap - Simple Side Effect
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that runs [onValue] for every typed payload
/// (Rx `tap` / `doOnData`).
///
/// [Tap] is the simplest side effect operator. It executes a callback
/// for each typed pulse without modifying the pulse. This is useful
/// for logging, debugging, or triggering external side effects.
///
/// ### When to use
/// Use [Tap] when you need to perform a side effect on each value
/// without changing the stream.
///
/// - **Logging**: Logging values as they flow through.
/// - **Debugging**: Printing values for debugging.
/// - **Analytics**: Tracking events for analytics.
/// - **Metrics**: Collecting metrics on values.
/// - **External Effects**: Triggering external side effects.
/// - **Validation**: Validating values with side effects.
///
/// ### Choosing Between Tap Variants
/// - **Use [Tap]** for **Typed Side Effects**: When you only care
///   about typed payloads.
/// - **Use [TapAll]** for **All Pulses**: When you need to see every
///   pulse, including type mismatches.
/// - **Use [TapWithIndex]** for **Indexed Side Effects**: When you
///   need the index of each value.
/// - **Use [TapState]** for **Stateful Side Effects**: When you need
///   to accumulate state across pulses.
///
/// ### Comparison with Other Operators
/// | Operator | Type Check | Index | State | Modifies Pulse |
/// |----------|------------|-------|-------|----------------|
/// | **Tap** | Yes (typed only) | No | No | No (pass-through) |
/// | **TapAll** | No (all pulses) | No | No | No (pass-through) |
/// | **TapWithIndex** | Yes (typed only) | Yes | No | No (pass-through) |
/// | **TapState** | Yes (typed only) | No | Yes | No (pass-through) |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [onValue] is called with the payload.
/// 3. If [onValue] throws an error, the pulse is dropped.
/// 4. If [onValue] succeeds, the pulse is passed through unchanged.
/// 5. The pulse gets the step `'Tap'` for provenance.
///
/// ### Non‑obvious
/// - **Error Handling**: If [onValue] throws, the pulse is dropped.
/// - **Pass-through**: The pulse is not modified.
/// - **Type Safety**: Only typed payloads trigger the callback.
/// - **Provenance Preservation**: The pulse gets the `'Tap'` step.
/// - **Synchronous Callback**: [onValue] is synchronous.
///
/// ### Example: Logging
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final logged = Tap<int>(
///   (value) => print('Value: $value'),
/// ).toHandle(source: input.cell);
///
/// input.emit(42); // Prints: Value: 42
/// ```
///
/// ### Example: Debugging
/// ```dart
/// final data = Cell.ingress<Data>();
///
/// final debug = Tap<Data>(
///   (data) {
///     print('Processing: ${data.id}');
///     assert(data.isValid);
///   },
///   onError: (error, stack) => print('Invalid data: $error'),
/// ).toHandle(source: data.cell);
/// ```
///
/// ### Parameters:
/// - [onValue]: **Side Effect Callback.** Called with each typed
///   payload. If it throws, the pulse is dropped.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that performs a side effect on each value.
///
/// ### See Also:
/// - [TapAll]: For side effects on all pulses.
/// - [TapWithIndex]: For indexed side effects.
/// - [TapState]: For stateful side effects.
class Tap<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Tap(
      void Function(S value) onValue, {
        TapErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      try {
        onValue(typed.payload as S);
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
      return typed.withStep('Tap');
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// TapAll - Side Effect on All Pulses
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that runs [onPulse] for every pulse,
/// including wrong types (Rx `tap` + `doOnEach`).
///
/// [TapAll] is similar to [Tap] but the callback receives the full
/// [Pulse] object, not just the payload. This allows side effects
/// on all pulses, including those with type mismatches.
///
/// ### When to use
/// Use [TapAll] when you need to perform side effects on every pulse,
/// including those that don't match the expected type.
///
/// - **Logging**: Logging all pulses including errors.
/// - **Debugging**: Debugging pulse flow including type mismatches.
/// - **Monitoring**: Monitoring all pulses for metrics.
/// - **Auditing**: Auditing all pulses including invalid ones.
/// - **Tracing**: Tracing pulse flow through the system.
///
/// ### Example: Logging All Pulses
/// ```dart
/// final input = Cell.ingress<Object>();
///
/// final logged = TapAll(
///   (pulse) => print('Pulse: ${pulse.payload} (type: ${pulse.type})'),
/// ).toHandle(source: input.cell);
///
/// input.emit(42);       // Logs typed pulse
/// input.emit('hello');  // Logs typed pulse
/// // Also logs pulses with type mismatches
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is passed to [onPulse] directly.
/// 2. No type checking is performed.
/// 3. If [onPulse] throws an error, the pulse is dropped.
/// 4. If [onPulse] succeeds, the pulse is passed through unchanged.
/// 5. The pulse gets the step `'TapAll'` for provenance.
///
/// ### Non‑obvious
/// - **No Type Check**: The callback receives all pulses.
/// - **Full Pulse Access**: The callback receives the full [Pulse] object.
/// - **Error Handling**: If [onPulse] throws, the pulse is dropped.
/// - **Provenance Preservation**: The pulse gets the `'TapAll'` step.
/// - **Synchronous Callback**: [onPulse] is synchronous.
///
/// ### Parameters:
/// - [onPulse]: **Side Effect Callback.** Called with each pulse.
///   If it throws, the pulse is dropped.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload (inferred from context, but the
///   callback receives the full pulse).
///
/// ### Returns:
/// A [FlowInstruction] that performs a side effect on every pulse.
///
/// ### See Also:
/// - [Tap]: For typed side effects.
/// - [TapWithIndex]: For indexed side effects.
/// - [TapState]: For stateful side effects.
class TapAll extends FlowInstructionBase<Cell, Pulse, Pulse> {
  TapAll(
      void Function(Pulse pulse) onPulse, {
        TapErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      try {
        onPulse(pulse);
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
      return pulse.withStep('TapAll');
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// TapWithIndex - Indexed Side Effect
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that runs a side effect with a 0-based index
/// for each typed payload (Rx `tap` + index).
///
/// [TapWithIndex] is similar to [Tap] but the callback receives the
/// index of each value in the sequence. This is useful when the side
/// effect depends on the position of the value.
///
/// ### When to use
/// Use [TapWithIndex] when you need the index of each value in your
/// side effect.
///
/// - **Position Tracking**: Tracking the position of values.
/// - **Progress Reporting**: Reporting progress through a sequence.
/// - **Index-Based Logging**: Logging with index information.
/// - **Sequence Debugging**: Debugging sequence order.
/// - **Batch Processing**: Tracking batch position.
///
/// ### Example: Progress Reporting
/// ```dart
/// final items = Cell.ingress<Item>();
///
/// final processed = TapWithIndex<Item>(
///   (item, index) {
///     print('Processing item ${index + 1}/${totalItems}');
///   },
/// ).toHandle(source: items.cell);
/// ```
///
/// ### Example: Index-Based Logging
/// ```dart
/// final data = Cell.ingress<Data>();
///
/// final logged = TapWithIndex<Data>(
///   (data, index) {
///     log.info('Entry #$index: ${data.id}');
///   },
/// ).toHandle(source: data.cell);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [onValue] is called with the payload and index.
/// 3. The index starts at 0 and increments on each typed pulse.
/// 4. If [onValue] throws an error, the pulse is dropped.
/// 5. If [onValue] succeeds, the pulse is passed through unchanged.
/// 6. The index is incremented after the callback.
/// 7. The pulse gets the step `'TapWithIndex'` for provenance.
///
/// ### Non‑obvious
/// - **Index Type**: The index is a 0-based integer.
/// - **Typed Only**: Only typed pulses increment the index.
/// - **Error Handling**: If [onValue] throws, the pulse is dropped
///   and the index is not incremented.
/// - **Provenance Preservation**: The pulse gets the `'TapWithIndex'` step.
/// - **Synchronous Callback**: [onValue] is synchronous.
///
/// ### Parameters:
/// - [onValue]: **Indexed Side Effect Callback.** Called with each
///   typed payload and its index. If it throws, the pulse is dropped.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that performs an indexed side effect.
///
/// ### See Also:
/// - [Tap]: For simple side effects.
/// - [TapAll]: For side effects on all pulses.
/// - [TapState]: For stateful side effects.
class TapWithIndex<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  TapWithIndex(
      void Function(S value, int index) onValue, {
        TapErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      var index = 0;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        try {
          onValue(typed.payload as S, index);
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        index++;
        return typed.withStep('TapWithIndex');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// TapState - Stateful Side Effect
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that maintains state across side effects
/// (Rx `tap` + fold).
///
/// [TapState] is similar to [Tap] but maintains an accumulator that
/// is updated on each typed pulse. The state is updated as a side
/// effect, and the pulse is passed through unchanged.
///
/// ### When to use
/// Use [TapState] when you need to maintain state across side effects
/// without modifying the pulse stream.
///
/// - **Counting**: Counting items as they flow through.
/// - **Summing**: Summing values as they flow through.
/// - **Statistics**: Computing running statistics.
/// - **Caching**: Maintaining a cache of processed values.
/// - **Aggregation**: Aggregating values for side effects.
/// - **Tracking**: Tracking state across a stream.
///
/// ### Example: Running Sum
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final tap = TapState<int, int>(
///   0,
///   (acc, n) => acc + n,
/// );
/// final stateful = tap.toHandle(source: input.cell);
///
/// input.emit(5);  // State updated to 5
/// input.emit(3);  // State updated to 8
/// input.emit(7);  // State updated to 15
///
/// print(tap.snapshot.value); // 15
/// print(tap.snapshot.seen);  // 3
/// ```
///
/// ### Example: Counting Items
/// ```dart
/// final items = Cell.ingress<Item>();
///
/// final counter = TapState<Item, int>(
///   0,
///   (acc, item) => acc + 1,
/// );
/// final counted = counter.toHandle(source: items.cell);
///
/// // After processing 5 items:
/// print(counter.snapshot.value); // 5
/// ```
///
/// ### Example: Running Statistics
/// ```dart
/// final data = Cell.ingress<double>();
///
/// final stats = TapState<double, (int, double, double)>(
///   (0, 0.0, 0.0),
///   (state, value) {
///     final (count, sum, sumSq) = state;
///     return (count + 1, sum + value, sumSq + value * value);
///   },
/// );
/// final statStream = stats.toHandle(source: data.cell);
///
/// // After processing values:
/// final (count, sum, sumSq) = stats.snapshot.value;
/// final mean = sum / count;
/// final variance = sumSq / count - mean * mean;
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [next] is called with the current state
///    and the payload.
/// 3. The new state is stored in the [snapshot].
/// 4. The [seen] counter is incremented.
/// 5. If [next] throws an error, the pulse is dropped.
/// 6. If [next] succeeds, the pulse is passed through unchanged.
/// 7. The pulse gets the step `'TapState'` for provenance.
///
/// ### Non‑obvious
/// - **State Persistence**: The state persists across all pulses.
/// - **Pass-through**: The pulse is not modified.
/// - **Type Safety**: Only typed pulses update the state.
/// - **Error Handling**: If [next] throws, the pulse is dropped
///   and the state is not updated.
/// - **Snapshot Access**: The snapshot can be read externally.
/// - **Provenance Preservation**: The pulse gets the `'TapState'` step.
/// - **Synchronous Update**: [next] is synchronous.
///
/// ### Parameters:
/// - [seed]: **Initial State.** The starting value for the accumulator.
/// - [next]: **State Update Function.** Called with the current state
///   and the payload, returns the new state.
/// - [snapshot]: **Shared Snapshot.** Optional. Creates a new one if
///   not provided. Use this to access the state externally.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
/// - [A]: The type of the accumulated state.
///
/// ### Returns:
/// A [FlowInstruction] that maintains state across side effects.
///
/// ### See Also:
/// - [Tap]: For simple side effects.
/// - [TapAll]: For side effects on all pulses.
/// - [TapWithIndex]: For indexed side effects.
/// - [Reduce]: For stateful transformations that emit the state.
class TapState<S, A> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  TapState(
      A seed,
      A Function(A state, S value) next, {
        TapSnapshot<A>? snapshot,
        TapErrorHandler? onError,
        dynamic user,
      }) : this._(next, snapshot ?? TapSnapshot<A>(seed), onError, user);

  TapState._(
      A Function(A state, S value) next,
      this.snapshot,
      TapErrorHandler? onError,
      dynamic user,
      ) : super(
    (() {
      final snap = snapshot;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        try {
          snap.value = next(snap.value, typed.payload as S);
          snap.seen++;
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        return typed.withStep('TapState');
      };
    })(),
    user: user,
  );

  /// The shared snapshot containing the current state.
  ///
  /// Use this to access the [value] and [seen] count from outside
  /// the instruction.
  final TapSnapshot<A> snapshot;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Tap] instruction and related operators
/// showing their behavior in various side effect scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Tap Operators Demo ────────────────────────────────────────
///
/// 1. Tap
///    tap 1
///    [Tap] 1
///    tap 2
///    [Tap] 2
///
/// 2. TapAll
///    all 1
///    [TapAll] 1
///    all x
///    [TapAll] x
///
/// 3. TapWithIndex
///    #0 a
///    [TapWithIndex] a
///    #1 b
///    [TapWithIndex] b
///
/// 4. TapState
///    [TapState] 1
///    [TapState] 2
///    sum=3 seen=2
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
/// 1. **Tap - Simple Side Effect**: Shows the basic tap operator
///    executing a side effect for each typed payload. The side effect
///    prints the value, and the pulse is passed through unchanged.
///
/// 2. **TapAll - All Pulses**: Shows the tap operator that runs on
///    every pulse, including those with type mismatches. Both integer
///    and string pulses trigger the side effect.
///
/// 3. **TapWithIndex - Indexed Side Effect**: Shows the indexed tap
///    operator where each side effect receives the index of the value.
///    The index starts at 0 and increments on each typed pulse.
///
/// 4. **TapState - Stateful Side Effect**: Shows the stateful tap
///    operator that maintains an accumulator across pulses. The state
///    is updated as a side effect, and the snapshot can be inspected
///    externally to see the accumulated sum and count.
///
/// ### Key Takeaways
/// - Tap operators perform side effects without modifying pulses.
/// - Tap is for typed payloads only.
/// - TapAll runs on every pulse (no type checking).
/// - TapWithIndex provides the index of each value.
/// - TapState maintains state across pulses.
/// - Side effect errors drop the pulse.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Snapshots provide external access to state.
///
/// ### Note on Side Effects
/// Tap operators are designed for side effects like logging,
/// debugging, analytics, and metrics. They do not modify the
/// pulse stream, making them safe to insert anywhere in a pipeline.
Future<void> main() async {
  print('── Tap Operators Demo ────────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Tap - Simple Side Effect
  // ─────────────────────────────────────────────────────────────────────
  print('1. Tap');

  final nums = Cell.ingress<int>();

  final tapped = Tap<int>(
        (n) => print('   tap $n'),
  ).toHandle(source: nums.cell);

  final tObs = Cell.observe(
    source: tapped.cell,
    effect: (Pulse p) => print('   [Tap] ${p.payload}'),
  );

  await nums.emitAsync(1);
  await nums.emitAsync(2);

  tObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. TapAll - All Pulses
  // ─────────────────────────────────────────────────────────────────────
  print('2. TapAll');

  final any = Cell.ingress<Object>();

  final all = TapAll(
        (p) => print('   all ${p.payload}'),
  ).toHandle(source: any.cell);

  final aObs = Cell.observe(
    source: all.cell,
    effect: (Pulse p) => print('   [TapAll] ${p.payload}'),
  );

  await any.emitAsync(1);
  await any.emitAsync('x');

  aObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. TapWithIndex - Indexed Side Effect
  // ─────────────────────────────────────────────────────────────────────
  print('3. TapWithIndex');

  final letters = Cell.ingress<String>();

  final indexed = TapWithIndex<String>(
        (s, i) => print('   #$i $s'),
  ).toHandle(source: letters.cell);

  final iObs = Cell.observe(
    source: indexed.cell,
    effect: (Pulse p) => print('   [TapWithIndex] ${p.payload}'),
  );

  await letters.emitAsync('a');
  await letters.emitAsync('b');

  iObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. TapState - Stateful Side Effect
  // ─────────────────────────────────────────────────────────────────────
  print('4. TapState');

  final add = Cell.ingress<int>();

  final state = TapState<int, int>(
    0,
        (acc, n) => acc + n,
  );

  final folded = state.toHandle(source: add.cell);

  final sObs = Cell.observe(
    source: folded.cell,
    effect: (Pulse p) => print('   [TapState] ${p.payload}'),
  );

  await add.emitAsync(1);
  await add.emitAsync(2);

  print('   sum=${state.snapshot.value} seen=${state.snapshot.seen}');

  sObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}