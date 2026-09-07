// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flow/cell_flow.dart';

// ─────────────────────────────────────────────────────────────
// Flow instructions that emit adjacent pairs
// ─────────────────────────────────────────────────────────────

/// Error handler callback for pairwise operators.
///
/// Called when an error occurs during pairwise operations, such as
/// type mismatches or errors in the combine function.
///
/// ### Example
/// ```dart
/// final errorHandler = PairwiseErrorHandler((error, stack) {
///   print('Pairwise error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef PairwiseErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// Helper to validate and extract a typed payload from a pulse.
///
/// Checks that the pulse payload matches the expected type [S].
/// If the type check fails, calls the [onError] handler and returns `null`.
///
/// ### Parameters:
/// - [pulse]: The pulse to validate.
/// - [onError]: Optional error handler for type mismatches.
///
/// ### Returns:
/// The validated pulse if the type matches, or `null` if it doesn't.
Pulse? _typedOrError<S>(
    Pulse pulse, {
      PairwiseErrorHandler? onError,
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

/// Helper to create an output pulse with proper provenance.
///
/// Creates a new [Pulse] with the given [value], preserving the source,
/// type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [value]: The payload value for the new pulse.
/// - [trigger]: The source pulse providing provenance metadata.
/// - [cell]: Optional cell to use as the source.
/// - [step]: The trace step to add for provenance.
///
/// ### Returns:
/// A new [Pulse] with preserved provenance.
Pulse<A> _out<A>(A value, Pulse trigger, Cell? cell, String step) {
  return Pulse<A>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

// ─────────────────────────────────────────────────────────────
// Pairwise
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits `(previous, current)` starting at the
/// second typed value (Rx `pairwise`).
///
/// [Pairwise] acts as a **Sliding Window of Size 2**. It maintains a sliding
/// window of the last two values and emits them as a pair for each consecutive
/// pair in the stream.
///
/// ### When to use
/// Use [Pairwise] when you need to compare adjacent values:
///
/// - **Deltas**: Computing `current - previous` for change detection
/// - **Edge Detection**: Detecting direction changes or state transitions
/// - **Trend Analysis**: Comparing a reading to the one before it
/// - **Change Detection**: Detecting when a value changes
/// - **Motion Detection**: Detecting movement based on position changes
/// - **Signal Processing**: Computing derivatives or differences
/// - **Data Validation**: Validating that values change appropriately
/// - **Stream Comparison**: Comparing consecutive values in a stream
///
/// ### Choosing Between Pairwise Patterns
/// - **Use [Pairwise]** for **Raw Pairs**: When you want the raw `(prev, current)`
///   pair.
/// - **Use [PairwiseWith]** for **Custom Combination**: When you want to
///   transform the pair into a different value (e.g., difference).
///
/// ### Comparison with Other Operators
/// | Operator | Output | Memory | Use Case |
/// |----------|--------|--------|----------|
/// | **Pairwise** | `(prev, current)` | O(1) | Adjacent pairs |
/// | **PairwiseWith** | Custom transform | O(1) | Custom adjacent comparison |
/// | **Scan** | Accumulated state | O(1) | Running totals |
/// | **DistinctUntilChanged** | Changed values | O(1) | Remove duplicates |
///
/// ### How it works
/// 1. The first typed pulse is stored and **not** emitted.
/// 2. For each subsequent pulse, the previous value and the current value
///    are emitted as a pair `(previous, current)`.
/// 3. The current value becomes the previous value for the next pair.
/// 4. The instruction preserves causal provenance.
/// 5. Each emitted value gets the step `'Pairwise'` for provenance.
///
/// ### Non‑obvious
/// - **Sliding Window**: Only the last two values are kept.
/// - **First Pulse Silent**: The first pulse is not emitted.
/// - **State Persistence**: Only the previous value is stored (O(1) memory).
/// - **Order Preservation**: Results are emitted in input order.
/// - **Error Handling**: Type errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Type Safety**: The instruction is generic over [S] (input type),
///   ensuring compile-time type safety.
/// - **Memory Efficiency**: Only the previous value is stored.
///
/// ### Example: Adjacent Pairs
/// ```dart
/// final ticks = Cell.ingress<int>();
/// final pairs = Pairwise<int>().toHandle(source: ticks.cell);
///
/// ticks.emit(1); // No output (stored)
/// ticks.emit(2); // Emits (1, 2)
/// ticks.emit(3); // Emits (2, 3)
/// // Result: [(1, 2), (2, 3)]
/// ```
///
/// ### Example: Change Detection
/// ```dart
/// final readings = Cell.ingress<double>();
/// final changes = Pairwise<double>().toHandle(source: readings.cell);
///
/// // Derive the difference
/// final deltas = Cell.derive(
///   source: changes.cell,
///   project: (Pulse p) {
///     final (prev, current) = p.payload as (double, double);
///     return Pulse(current - prev);
///   },
/// );
/// ```
///
/// ### Example: Direction Detection
/// ```dart
/// final positions = Cell.ingress<int>();
/// final directions = Pairwise<int>().toHandle(source: positions.cell);
///
/// // Detect direction changes
/// final dirChanges = Cell.derive(
///   source: directions.cell,
///   project: (Pulse p) {
///     final (prev, current) = p.payload as (int, int);
///     final direction = current > prev ? 'up' : (current < prev ? 'down' : 'same');
///     return Pulse(direction);
///   },
/// );
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
/// A [FlowInstruction] that emits adjacent pairs.
///
/// ### See Also:
/// - [PairwiseWith]: For custom combination of adjacent pairs.
/// - [Scan]: For accumulating values over time.
/// - [DistinctUntilChanged]: For removing consecutive duplicates.
class Pairwise<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Sliding Window of Size 2**—a specialized instruction
  /// that emits each consecutive pair of values from the stream.
  ///
  /// [Pairwise] acts as a **Adjacent Pair Emitter**. It maintains a sliding
  /// window of the last two values and emits them as a pair for each
  /// consecutive pair in the stream. The first value is always silent
  /// (used as the seed for the first pair).
  ///
  /// ### How it works
  /// 1. **First Pulse Storage**: The first typed pulse is stored as the
  ///    previous value and is not emitted.
  /// 2. **Subsequent Pulse Processing**: For each subsequent pulse, the
  ///    previous value and the current value are emitted as a pair.
  /// 3. **State Update**: The current value becomes the previous value for
  ///    the next pair.
  /// 4. **Step Evolution**: Each emitted pair is wrapped in a new pulse
  ///    that inherits the original provenance (source, priority, type) and
  ///    is tagged with the `'Pairwise'` step.
  /// 5. **Provenance Preservation**: Every emitted result preserves the
  ///    forensic history of the triggering pulse.
  ///
  /// ### Memory Model
  /// * **O(1) Memory**: Only the previous value is stored.
  /// * **Sliding Window**: Only the last two values are kept.
  /// * **No Accumulation**: Older values are discarded.
  ///
  /// ### Parameters
  /// - [onError]: **Integrity Handler.** A callback invoked if a payload
  ///   violates type [S] or an error occurs during processing.
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the composition chain for auditing and tracing.
  ///
  /// ### Example: Raw Adjacent Pairs
  /// ```dart
  /// // Emits (1, 2), (2, 3) for input 1, 2, 3
  /// final pairwise = Pairwise<int>(
  ///   user: 'Adjacent-Pair-Generator'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [PairwiseWith]: For custom combination of adjacent pairs.
  /// - [Scan]: For accumulating values over time.
  /// - [DistinctUntilChanged]: For removing consecutive duplicates.
  Pairwise({
    PairwiseErrorHandler? onError,
    dynamic user,
  }) : super(
    (() {
      final state = _PrevState<S>();
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final value = typed.payload as S;
        if (!state.hasPrev) {
          state.prev = value;
          state.hasPrev = true;
          return null;
        }
        final previous = state.prev as S;
        state.prev = value;
        return _out<(S, S)>(
          (previous, value),
          typed,
          cell,
          'Pairwise',
        );
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// PairwiseWith
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a custom combination of adjacent pairs
/// (Rx `pairwise` + map).
///
/// [PairwiseWith] acts as a **Custom Adjacent Pair Transformer**. It is similar
/// to [Pairwise] but applies a custom [combine] function to each pair,
/// allowing you to compute deltas, ratios, or any other derived value from
/// consecutive values.
///
/// ### When to use
/// Use [PairwiseWith] when you need to compute a derived value from adjacent
/// pairs:
///
/// - **Deltas**: Computing `current - previous`
/// - **Ratios**: Computing `current / previous`
/// - **Distances**: Computing the distance between consecutive points
/// - **Velocity**: Computing speed from position changes
/// - **Acceleration**: Computing acceleration from velocity changes
/// - **Trends**: Computing the direction or magnitude of change
/// - **Custom Metrics**: Any custom metric from consecutive values
/// - **Data Validation**: Validating that changes are within acceptable bounds
///
/// ### How it works
/// 1. The first typed pulse is stored and **not** emitted.
/// 2. For each subsequent pulse, the [combine] function is called with
///    the previous value and the current value.
/// 3. The result of [combine] is emitted.
/// 4. The current value becomes the previous value for the next pair.
/// 5. The instruction preserves causal provenance.
/// 6. Each emitted value gets the step `'PairwiseWith'` for provenance.
///
/// ### Non‑obvious
/// - **Custom Combination**: The [combine] function defines what to emit.
/// - **First Pulse Silent**: The first pulse is not emitted.
/// - **State Persistence**: Only the previous value is stored (O(1) memory).
/// - **Error Handling**: Errors in [combine] are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Type Safety**: The instruction is generic over [S] (input) and
///   [T] (output), ensuring compile-time type safety.
/// - **Memory Efficiency**: Only the previous value is stored.
///
/// ### Example: Deltas
/// ```dart
/// final samples = Cell.ingress<int>();
/// final deltas = PairwiseWith<int, int>((prev, next) => next - prev)
///     .toHandle(source: samples.cell);
///
/// samples.emit(1); // No output (stored)
/// samples.emit(4); // Emits 3 (4 - 1)
/// samples.emit(6); // Emits 2 (6 - 4)
/// // Result: [3, 2]
/// ```
///
/// ### Example: Ratios
/// ```dart
/// final values = Cell.ingress<double>();
/// final ratios = PairwiseWith<double, double>((prev, next) => next / prev)
///     .toHandle(source: values.cell);
///
/// values.emit(2.0); // No output (stored)
/// values.emit(4.0); // Emits 2.0 (4/2)
/// values.emit(8.0); // Emits 2.0 (8/4)
/// ```
///
/// ### Example: Velocity
/// ```dart
/// final positions = Cell.ingress<({double x, double y})>();
/// final velocity = PairwiseWith<({double x, double y}), double>(
///   (prev, curr) {
///     final dx = curr.x - prev.x;
///     final dy = curr.y - prev.y;
///     return sqrt(dx * dx + dy * dy);
///   }
/// ).toHandle(source: positions.cell);
/// ```
///
/// ### Parameters:
/// - [combine]: **The Combination Function.** Takes the previous and current
///   values, returns a derived value of type [T].
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload from the combination.
///
/// ### Returns:
/// A [FlowInstruction] that emits custom combination of adjacent pairs.
///
/// ### See Also:
/// - [Pairwise]: For raw adjacent pairs.
/// - [Scan]: For accumulating values over time.
/// - [DistinctUntilChanged]: For removing consecutive duplicates.
class PairwiseWith<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Custom Adjacent Pair Transformer**—a specialized
  /// instruction that applies a custom function to each consecutive pair
  /// of values.
  ///
  /// [PairwiseWith] is similar to [Pairwise] but applies a custom [combine]
  /// function to each pair, allowing you to compute deltas, ratios, or any
  /// other derived value from consecutive values.
  ///
  /// ### How it works
  /// 1. **First Pulse Storage**: The first typed pulse is stored as the
  ///    previous value and is not emitted.
  /// 2. **Pair Combination**: For each subsequent pulse, the [combine]
  ///    function is called with the previous and current values.
  /// 3. **Result Emission**: The result of [combine] is emitted.
  /// 4. **State Update**: The current value becomes the previous value for
  ///    the next pair.
  /// 5. **Step Evolution**: Each emitted result is wrapped in a new pulse
  ///    that inherits the original provenance (source, priority, type) and
  ///    is tagged with the `'PairwiseWith'` step.
  /// 6. **Error Handling**: If [combine] throws an error, it's reported
  ///    via [onError] and the pulse is dropped.
  ///
  /// ### Memory Model
  /// * **O(1) Memory**: Only the previous value is stored.
  /// * **Sliding Window**: Only the last two values are kept.
  /// * **No Accumulation**: Older values are discarded.
  ///
  /// ### Parameters
  /// - [combine]: **The Combination Function.** Takes the previous and current
  ///   values, returns a derived value of type [T].
  /// - [onError]: **Integrity Handler.** A callback invoked if a payload
  ///   violates type [S], [combine] throws an error, or a type mismatch occurs.
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the composition chain for auditing and tracing.
  ///
  /// ### Example: Delta Calculator
  /// ```dart
  /// // Computes the difference between consecutive values
  /// final delta = PairwiseWith<int, int>(
  ///   (prev, next) => next - prev,
  ///   user: 'Delta-Calculator'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [Pairwise]: For raw adjacent pairs.
  /// - [Scan]: For accumulating values over time.
  /// - [DistinctUntilChanged]: For removing consecutive duplicates.
  PairwiseWith(
      T Function(S previous, S current) combine, {
        PairwiseErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final state = _PrevState<S>();
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final value = typed.payload as S;
        if (!state.hasPrev) {
          state.prev = value;
          state.hasPrev = true;
          return null;
        }
        final previous = state.prev as S;
        state.prev = value;
        try {
          return _out<T>(
            combine(previous, value),
            typed,
            cell,
            'PairwiseWith',
          );
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

/// Internal state for pairwise operators.
///
/// Maintains the previous value and a flag indicating whether a value
/// has been stored yet. This state is used by both [Pairwise] and
/// [PairwiseWith] to track the sliding window.
///
/// ### Fields:
/// - [prev]: The previous value in the stream.
/// - [hasPrev]: Whether a previous value has been stored.
///
/// ### Non‑obvious
/// - **O(1) Memory**: Only one value is stored at a time.
/// - **State Reset**: The state is not automatically reset; it persists
///   for the lifetime of the instruction.
class _PrevState<S> {
  S? prev;
  bool hasPrev = false;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Pairwise] instruction and related operators
/// showing their behavior in various adjacent pair scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Pairwise Operators Demo ───────────────────────────────────
///
/// 1. Pairwise
///    [Pairwise] (1, 2)
///    [Pairwise] (2, 3)
///
/// 2. PairwiseWith - deltas
///    [PairwiseWith] 3
///    [PairwiseWith] 2
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
/// 1. **Pairwise**: Shows basic adjacent pair emission. Each consecutive
///    pair of values is emitted as a tuple.
///    `1, 2, 3` → `(1, 2), (2, 3)`
///
/// 2. **PairwiseWith - deltas**: Shows custom combination. Each consecutive
///    pair is transformed using a custom function.
///    `1, 4, 6` → `3, 2` (deltas)
///
/// ### Key Takeaways
/// - Pairwise emits adjacent pairs, not accumulated state.
/// - The first value is always silent (used as the previous value).
/// - Memory is O(1) - only the previous value is stored.
/// - PairwiseWith allows custom transformation of adjacent pairs.
/// - Both operators preserve causal provenance via EvolvedPulse.
/// - Use Pairwise for raw pairs, PairwiseWith for derived values.
/// - Both operators handle type mismatches gracefully via [onError].
///
/// ### Note on Use Cases
/// Pairwise operators are ideal for:
/// - Change detection (deltas, diffs)
/// - Motion detection (velocity, acceleration)
/// - Signal processing (derivatives, smoothing)
/// - Edge detection (direction changes)
/// - Trend analysis (up/down detection)
/// - Data validation (change validation)
Future<void> main() async {
  print('── Pairwise Operators Demo ───────────────────────────────────\n');

  print('1. Pairwise');
  final ticks = Cell.ingress<int>();
  final pairs = Pairwise<int>().toHandle(source: ticks.cell);
  final pObs = Cell.observe(
    source: pairs.cell,
    effect: (Pulse p) => print('   [Pairwise] ${p.payload}'),
  );
  await ticks.emitAsync(1);
  await ticks.emitAsync(2);
  await ticks.emitAsync(3);
  pObs.stop();
  print('');

  print('2. PairwiseWith - deltas');
  final samples = Cell.ingress<int>();
  final deltas = PairwiseWith<int, int>((prev, next) => next - prev)
      .toHandle(source: samples.cell);
  final dObs = Cell.observe(
    source: deltas.cell,
    effect: (Pulse p) => print('   [PairwiseWith] ${p.payload}'),
  );
  await samples.emitAsync(1);
  await samples.emitAsync(4);
  await samples.emitAsync(6);
  dObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}