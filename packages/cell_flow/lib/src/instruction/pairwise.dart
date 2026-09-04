// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

/// Flow instructions that emit adjacent pairs (Rx `pairwise` family).
///
/// These operators emit each consecutive pair of values from the stream.
/// This is a **sliding window of size 2**, not an accumulator. Keep it
/// separate from [Scan]: `scan` folds history into one value; `pairwise`
/// forwards `(previous, current)` and forgets everything older.
///
/// | Operator | Rx analogue | Emission |
/// |---|---|---|
/// | [Pairwise] | `pairwise` | `(prev, next)` from the second pulse |
/// | [PairwiseWith] | `pairwise` + map | custom combine of prev and next |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef PairwiseErrorHandler = void Function(Object error, StackTrace? stackTrace);

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

/// A [Receptor] instruction that emits `(previous, current)` starting at the
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
/// val changes = Pairwise<double>().toHandle(source: readings.cell);
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
/// val directions = Pairwise<int>().toHandle(source: positions.cell);
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
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [PairwiseWith]: For custom combination of adjacent pairs.
/// - [Scan]: For accumulating values over time.
/// - [DistinctUntilChanged]: For removing consecutive duplicates.
class Pairwise<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [Pairwise] instruction.
  ///
  /// ### Parameters:
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final pairwise = Pairwise<int>(
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
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

/// A [Receptor] instruction that emits a custom combination of adjacent pairs
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
/// val deltas = PairwiseWith<int, int>((prev, next) => next - prev)
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
/// val ratios = PairwiseWith<double, double>((prev, next) => next / prev)
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
/// val velocity = PairwiseWith<({double x, double y}), double>(
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
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Pairwise]: For raw adjacent pairs.
/// - [Scan]: For accumulating values over time.
/// - [DistinctUntilChanged]: For removing consecutive duplicates.
class PairwiseWith<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [PairwiseWith] instruction with the specified [combine] function.
  ///
  /// ### Parameters:
  /// - [combine]: **The Combination Function.** Takes the previous and current
  ///   values, returns a derived value of type [T].
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final pairwiseWith = PairwiseWith<int, int>(
  ///   (prev, next) => next - prev,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
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