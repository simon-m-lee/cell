// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flow/cell_flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Scan Operators
// ─────────────────────────────────────────────────────────────

/// Error handler callback for scan operators.
///
/// Called when an error occurs during accumulation, such as errors in
/// the accumulate function or type mismatches.
///
/// ### Example
/// ```dart
/// final errorHandler = ScanErrorHandler((error, stack) {
///   print('Scan error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef ScanErrorHandler = void Function(Object error, StackTrace? stackTrace);

// ─────────────────────────────────────────────────────────────
// Helper Functions and State
// ─────────────────────────────────────────────────────────────

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
      ScanErrorHandler? onError,
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
Pulse<A> _acc<A>(A value, Pulse trigger, Cell? cell, String step) {
  return Pulse<A>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// Internal state for scan operators.
///
/// Maintains the current accumulator value and a flag indicating whether
/// a value has been stored yet.
///
/// ### Fields:
/// - [acc]: The current accumulator value.
/// - [hasAcc]: Whether the accumulator has been initialized.
///
/// ### Non‑obvious
/// - **Stateful**: The state is maintained across pulses.
/// - **Type Safety**: Generic over the accumulator type [A].
/// - **Mutable**: The state is mutable and updated on each pulse.
class _ScanState<A> {
  A? acc;
  bool hasAcc = false;
}

// ─────────────────────────────────────────────────────────────
// Scan - Seedless Accumulator
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that accumulates values without an explicit seed
/// (Rx `scan`).
///
/// [Scan] acts as a **Seedless Accumulator**. The first typed value becomes
/// the seed and is **not** emitted. Every later value is combined with the
/// running total and the new total is emitted.
///
/// ### When to use
/// Use [Scan] when you need to accumulate values over time:
///
/// - **Running Totals**: Computing a running sum, average, or count
/// - **Reducers**: When the first sample itself is the starting amount
/// - **State Machines**: Tracking state transitions over time
/// - **Data Aggregation**: Aggregating data from a stream
/// - **Progressive Enrichment**: Building a result incrementally
/// - **Event Sourcing**: Building an aggregate from a stream of events
/// - **Streaming Aggregations**: Computing running metrics
/// - **Progressive Loading**: Loading data in chunks and updating state
///
/// ### Choosing Between Scan Patterns
/// - **Use [Scan]** for **Seedless Accumulation**: When the first value
///   itself should be the seed and not emitted.
/// - **Use [ScanSeeded]** for **Seeded Accumulation**: When you want to
///   provide an explicit seed and emit on the first pulse.
/// - **Use [ScanIndexed]** for **Indexed Accumulation**: When you need the
///   index in addition to the value.
///
/// ### Comparison with Other Operators
/// | Operator | Seed | First Emission | Emits | Rx Analogue |
/// |----------|------|----------------|-------|-------------|
/// | **Scan** | First value | Second pulse | Each step after first | `scan` |
/// | **ScanSeeded** | Explicit | First pulse | Each step | `scan(seed)` |
/// | **ScanIndexed** | Explicit + index | First pulse | Each step | `scan` + index |
/// | **Reduce** | First value | Last pulse | Final only | `reduce` |
/// | **AsyncFold** | Explicit | First pulse | Each step | `async` + `scan` |
///
/// ### How it works
/// 1. The first typed pulse becomes the accumulator and is stored.
/// 2. The first pulse is **not** emitted.
/// 3. For each subsequent pulse, the [accumulate] function is called with
///    the current accumulator and the new value.
/// 4. The result becomes the new accumulator and is emitted.
/// 5. Each emitted value gets the step `'Scan'` for provenance.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **No Seed**: The first value is used as the seed and not emitted.
/// - **Silent First**: The instruction is silent on the first pulse.
/// - **State Persistence**: The accumulator is maintained across pulses.
/// - **Order Preservation**: Results are emitted in input order.
/// - **Error Handling**: Errors in [accumulate] are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Type Safety**: The instruction is generic over [S] (input) and
///   [A] (accumulator), ensuring compile-time type safety.
/// - **Memory Efficiency**: Only the accumulator state is stored.
/// - **Type Casting**: The first value is cast to [A] when used as seed.
///
/// ### Example: Running Sum (No Seed)
/// ```dart
/// final nums = Cell.ingress<int>();
/// final sums = Scan<int, int>((acc, n) => acc + n)
///     .toHandle(source: nums.cell);
///
/// nums.emit(1); // No output (becomes seed)
/// nums.emit(2); // Emits 3 (1 + 2)
/// nums.emit(3); // Emits 6 (1 + 2 + 3)
/// // Result: [3, 6]
/// ```
///
/// ### Example: Running Max
/// ```dart
/// final nums = Cell.ingress<int>();
/// val maxSoFar = Scan<int, int>((acc, n) => n > acc ? n : acc)
///     .toHandle(source: nums.cell);
///
/// nums.emit(3); // No output (becomes seed: 3)
/// nums.emit(1); // Emits 3 (max(3, 1))
/// nums.emit(5); // Emits 5 (max(3, 5))
/// ```
///
/// ### Parameters:
/// - [accumulate]: **The Accumulation Function.** Takes the current
///   accumulator and the new value, returns the new accumulator.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [A]: The type of the accumulator state.
///
/// ### Returns:
/// A [FlowInstruction] that accumulates without an explicit seed.
///
/// ### See Also:
/// - [ScanSeeded]: For seeded accumulation.
/// - [ScanIndexed]: For indexed accumulation.
/// - [Reduce]: For reducing to a single final value.
class Scan<S, A> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Seedless Accumulator**—a specialized instruction
  /// that accumulates values without an explicit seed.
  ///
  /// [Scan] acts as a **Seedless Accumulator**. The first typed value becomes
  /// the seed and is not emitted. Every later value is combined with the
  /// running total and the new total is emitted.
  ///
  /// ### How it works
  /// 1. **Type Check**: The pulse payload is validated against type [S].
  /// 2. **First Pulse**: The first value is stored as the accumulator
  ///    and is not emitted.
  /// 3. **Accumulation**: For each subsequent pulse, [accumulate] is called
  ///    with the current accumulator and the new value.
  /// 4. **Emission**: The new accumulator is emitted with the step `'Scan'`.
  /// 5. **Error Handling**: If [accumulate] throws, [onError] is called
  ///    and the pulse is dropped.
  ///
  /// ### Parameters
  /// - [accumulate]: **The Accumulation Function.** Combines accumulator
  ///   and value to produce new accumulator.
  /// - [onError]: **Integrity Handler.** Called on errors.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: Running Sum Calculator
  /// ```dart
  /// // Computes running sum without an explicit seed
  /// val runningSum = Scan<int, int>(
  ///   (acc, n) => acc + n,
  ///   user: 'Running-Sum'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [ScanSeeded]: For seeded accumulation.
  /// - [ScanIndexed]: For indexed accumulation.
  Scan(
      A Function(A acc, S value) accumulate, {
        ScanErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final state = _ScanState<A>();
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final value = typed.payload as S;
        if (!state.hasAcc) {
          state.acc = value as A;
          state.hasAcc = true;
          return null;
        }
        try {
          state.acc = accumulate(state.acc as A, value);
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        return _acc(state.acc as A, typed, cell, 'Scan');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// ScanSeeded - Seeded Accumulator
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that accumulates with an explicit seed
/// (Rx `scan(acc, seed)`).
///
/// [ScanSeeded] acts as a **Seeded Accumulator**. The seed is combined with
/// the first typed value, so the first pulse already emits an accumulated
/// result.
///
/// ### When to use
/// Use [ScanSeeded] when:
/// - You want to provide an explicit initial state
/// - You want the first pulse to emit a result
/// - You're implementing a running total starting from a known base
/// - You're building a state machine with an initial state
/// - You're implementing a reducer with a known initial value
/// - You're tracking cumulative metrics from a known starting point
/// - You're implementing a counter starting from a specific value
/// - You're building a progressive aggregation
///
/// ### Comparison with Scan
/// | Feature | Scan | ScanSeeded |
/// |---------|------|------------|
/// | **Seed** | First value | Explicit |
/// | **First Emission** | Second pulse | First pulse |
/// | **Use Case** | No known initial state | Known initial state |
/// | **Seed Type** | Must match [A] | Explicitly typed |
///
/// ### How it works
/// 1. The [seed] is stored as the initial accumulator.
/// 2. For each pulse, the [accumulate] function is called with the
///    current accumulator and the new value.
/// 3. The result becomes the new accumulator and is emitted.
/// 4. Each emitted value gets the step `'ScanSeeded'` for provenance.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Explicit Seed**: The seed is provided as a parameter.
/// - **First Pulse Emits**: The first pulse always emits a result.
/// - **State Persistence**: The accumulator is maintained across pulses.
/// - **Order Preservation**: Results are emitted in input order.
/// - **Error Handling**: Errors in [accumulate] are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Type Safety**: The instruction is generic over [S] (input) and
///   [A] (accumulator), ensuring compile-time type safety.
/// - **Memory Efficiency**: Only the accumulator state is stored.
/// - **Seed as Initial State**: The seed is used as the initial state.
///
/// ### Example: Running Sum with Seed
/// ```dart
/// final nums = Cell.ingress<int>();
/// final sums = ScanSeeded<int, int>(0, (acc, n) => acc + n)
///     .toHandle(source: nums.cell);
///
/// nums.emit(1); // Emits 1 (0 + 1)
/// nums.emit(2); // Emits 3 (1 + 2)
/// nums.emit(3); // Emits 6 (3 + 3)
/// // Result: [1, 3, 6]
/// ```
///
/// ### Example: Running Average
/// ```dart
/// final nums = Cell.ingress<double>();
/// val avg = ScanSeeded<double, (double sum, int count)>(
///   (0.0, 0),
///   (state, value) => (state.$1 + value, state.$2 + 1)
/// ).toHandle(source: nums.cell);
///
/// // Derive the average from the state
/// final avgDerived = Cell.derive(
///   source: avg.cell,
///   project: (Pulse p) {
///     final (sum, count) = p.payload as (double, int);
///     return Pulse(count == 0 ? 0.0 : sum / count);
///   },
/// );
/// ```
///
/// ### Parameters:
/// - [seed]: **The Initial State.** The starting value of the accumulator.
/// - [accumulate]: **The Accumulation Function.** Takes the current
///   accumulator and the new value, returns the new accumulator.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [A]: The type of the accumulator state.
///
/// ### Returns:
/// A [FlowInstruction] that accumulates with an explicit seed.
///
/// ### See Also:
/// - [Scan]: For seedless accumulation.
/// - [ScanIndexed]: For indexed accumulation.
class ScanSeeded<S, A> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Seeded Accumulator**—a specialized instruction
  /// that accumulates with an explicit seed.
  ///
  /// [ScanSeeded] acts as a **Seeded Accumulator**. The seed is combined with
  /// the first typed value, so the first pulse already emits an accumulated
  /// result.
  ///
  /// ### How it works
  /// 1. **Seed Storage**: The [seed] is stored as the initial accumulator.
  /// 2. **Type Check**: The pulse payload is validated against type [S].
  /// 3. **Accumulation**: The [accumulate] function is called with the
  ///    current accumulator and the new value.
  /// 4. **Emission**: The new accumulator is emitted with the step
  ///    `'ScanSeeded'`.
  /// 5. **Error Handling**: If [accumulate] throws, [onError] is called
  ///    and the pulse is dropped.
  ///
  /// ### Parameters
  /// - [seed]: **The Initial State.** Starting value of the accumulator.
  /// - [accumulate]: **The Accumulation Function.** Combines accumulator
  ///   and value to produce new accumulator.
  /// - [onError]: **Integrity Handler.** Called on errors.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: Counter with Initial Value
  /// ```dart
  /// // Starts counting from 100
  /// val counter = ScanSeeded<int, int>(
  ///   100,
  ///   (acc, n) => acc + n,
  ///   user: 'Counter'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [Scan]: For seedless accumulation.
  /// - [ScanIndexed]: For indexed accumulation.
  ScanSeeded(
      A seed,
      A Function(A acc, S value) accumulate, {
        ScanErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final state = _ScanState<A>()..acc = seed;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        try {
          state.acc = accumulate(state.acc as A, typed.payload as S);
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        return _acc(state.acc as A, typed, cell, 'ScanSeeded');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// ScanIndexed - Indexed Seeded Accumulator
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that accumulates with an explicit seed and
/// passes the index to the accumulation function.
///
/// [ScanIndexed] acts as an **Indexed Seeded Accumulator**. It is similar to
/// [ScanSeeded] but also passes a zero-based [index] to the [accumulate]
/// function, allowing the accumulation to depend on the position of the
/// element.
///
/// ### When to use
/// Use [ScanIndexed] when:
/// - You need the index for your accumulation logic
/// - You're implementing pagination or chunking
/// - You're tracking progress or position
/// - You're generating sequential IDs
/// - You're implementing rate limiting per element
/// - You're building a list with positional information
/// - You're computing metrics that depend on the index
/// - You're implementing a state machine with position awareness
///
/// ### How it works
/// 1. The [seed] is stored as the initial accumulator.
/// 2. An index counter starts at 0.
/// 3. For each pulse, the [accumulate] function is called with the
///    current accumulator, the new value, and the current index.
/// 4. The index is incremented after each accumulation.
/// 5. The result becomes the new accumulator and is emitted.
/// 6. Each emitted value gets the step `'ScanIndexed'` for provenance.
/// 7. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Index Provided**: The index is passed to the accumulation function.
/// - **Zero-Based**: The index starts at 0 for the first pulse.
/// - **State Persistence**: Both the accumulator and index are maintained.
/// - **Order Preservation**: Results are emitted in input order.
/// - **Error Handling**: Errors in [accumulate] are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Type Safety**: The instruction is generic over [S] (input) and
///   [A] (accumulator), ensuring compile-time type safety.
/// - **Index Increments**: The index increments after each successful
///   accumulation.
///
/// ### Example: Building a List with Index
/// ```dart
/// final items = Cell.ingress<String>();
/// val listed = ScanIndexed<String, List<String>>(
///   <String>[],
///   (acc, value, index) => [...acc, '$index: $value']
/// ).toHandle(source: items.cell);
///
/// items.emit('a'); // Emits ['0: a']
/// items.emit('b'); // Emits ['0: a', '1: b']
/// ```
///
/// ### Example: Weighted Sum by Index
/// ```dart
/// final values = Cell.ingress<int>();
/// val weighted = ScanIndexed<int, int>(
///   0,
///   (acc, value, index) => acc + value * index
/// ).toHandle(source: values.cell);
///
/// values.emit(5); // Emits 0 (5 * 0)
/// values.emit(5); // Emits 5 (0 + 5 * 1)
/// values.emit(5); // Emits 15 (5 + 5 * 2)
/// ```
///
/// ### Parameters:
/// - [seed]: **The Initial State.** The starting value of the accumulator.
/// - [accumulate]: **The Indexed Accumulation Function.** Takes the current
///   accumulator, the new value, and the index, returns the new accumulator.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [A]: The type of the accumulator state.
///
/// ### Returns:
/// A [FlowInstruction] that accumulates with an explicit seed and index.
///
/// ### See Also:
/// - [Scan]: For seedless accumulation.
/// - [ScanSeeded]: For seeded accumulation without index.
class ScanIndexed<S, A> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes an **Indexed Seeded Accumulator**—a specialized instruction
  /// that accumulates with an explicit seed and passes the index to the
  /// accumulation function.
  ///
  /// [ScanIndexed] acts as an **Indexed Seeded Accumulator**. It is similar to
  /// [ScanSeeded] but also passes a zero-based index to the accumulation
  /// function, allowing the accumulation to depend on the position of the
  /// element.
  ///
  /// ### How it works
  /// 1. **Seed Storage**: The [seed] is stored as the initial accumulator.
  /// 2. **Type Check**: The pulse payload is validated against type [S].
  /// 3. **Indexed Accumulation**: The [accumulate] function is called with
  ///    the current accumulator, the new value, and the current index.
  /// 4. **Index Increment**: The index is incremented after each accumulation.
  /// 5. **Emission**: The new accumulator is emitted with the step
  ///    `'ScanIndexed'`.
  /// 6. **Error Handling**: If [accumulate] throws, [onError] is called
  ///    and the pulse is dropped.
  ///
  /// ### Parameters
  /// - [seed]: **The Initial State.** Starting value of the accumulator.
  /// - [accumulate]: **The Indexed Accumulation Function.** Combines
  ///   accumulator, value, and index.
  /// - [onError]: **Integrity Handler.** Called on errors.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: Position-Aware Accumulator
  /// ```dart
  /// // Accumulates with position weighting
  /// val positionAware = ScanIndexed<int, int>(
  ///   0,
  ///   (acc, value, index) => acc + value * (index + 1),
  ///   user: 'Position-Aware'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [Scan]: For seedless accumulation.
  /// - [ScanSeeded]: For seeded accumulation without index.
  ScanIndexed(
      A seed,
      A Function(A acc, S value, int index) accumulate, {
        ScanErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final state = _ScanState<A>()..acc = seed;
      var index = 0;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        try {
          state.acc = accumulate(
            state.acc as A,
            typed.payload as S,
            index++,
          );
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        return _acc(state.acc as A, typed, cell, 'ScanIndexed');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Scan] instruction and related operators
/// showing their behavior in various accumulation scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Scan Operators Demo ───────────────────────────────────────
///
/// 1. Scan - first value is the seed
///    [Scan] 3
///    [Scan] 6
///
/// 2. ScanSeeded - seed 0
///    [ScanSeeded] 1
///    [ScanSeeded] 3
///    [ScanSeeded] 6
///
/// 3. ScanIndexed - running list
///    [ScanIndexed] [a]
///    [ScanIndexed] [a, b]
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
/// 1. **Scan - first value is the seed**: Shows seedless accumulation.
///    The first value (1) becomes the seed and is not emitted.
///    The second value (2) produces the first emission (3).
///    The third value (3) produces the second emission (6).
///    `1, 2, 3` → `3, 6`
///
/// 2. **ScanSeeded - seed 0**: Shows seeded accumulation.
///    The seed (0) is provided explicitly.
///    Each value produces an emission immediately.
///    `1, 2, 3` → `1, 3, 6`
///
/// 3. **ScanIndexed - running list**: Shows indexed accumulation.
///    The seed (empty list) is provided explicitly.
///    Each value is appended to the list.
///    `a, b` → `[a], [a, b]`
///
/// ### Key Takeaways
/// - Scan uses the first value as the seed (no emission on first pulse).
/// - ScanSeeded uses an explicit seed (emits on every pulse).
/// - ScanIndexed provides the index to the accumulation function.
/// - All scan operators maintain state across pulses.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Use Scan for running totals when the first value is the base.
/// - Use ScanSeeded when you need a known initial state.
/// - Use ScanIndexed when position matters in the accumulation.
/// - Choose the right operator for your use case:
///   - Seedless accumulation → Scan
///   - Seeded accumulation → ScanSeeded
///   - Indexed accumulation → ScanIndexed
///
/// ### Note on State
/// All scan operators maintain state across pulses. The state is volatile
/// and not persisted. Use [Cell.state] for persistent state storage.
Future<void> main() async {
  print('── Scan Operators Demo ───────────────────────────────────────\n');

  print('1. Scan - first value is the seed');
  final a = Cell.ingress<int>();
  final scanned = Scan<int, int>((acc, n) => acc + n).toHandle(source: a.cell);
  final sObs = Cell.observe(
    source: scanned.cell,
    effect: (Pulse p) => print('   [Scan] ${p.payload}'),
  );
  await a.emitAsync(1);
  await a.emitAsync(2);
  await a.emitAsync(3);
  sObs.stop();
  print('');

  print('2. ScanSeeded - seed 0');
  final b = Cell.ingress<int>();
  final seeded =
  ScanSeeded<int, int>(0, (acc, n) => acc + n).toHandle(source: b.cell);
  final dObs = Cell.observe(
    source: seeded.cell,
    effect: (Pulse p) => print('   [ScanSeeded] ${p.payload}'),
  );
  await b.emitAsync(1);
  await b.emitAsync(2);
  await b.emitAsync(3);
  dObs.stop();
  print('');

  print('3. ScanIndexed - running list');
  final c = Cell.ingress<String>();
  final listed = ScanIndexed<String, List<String>>(
    <String>[],
        (acc, value, index) => [...acc, value],
  ).toHandle(source: c.cell);
  final iObs = Cell.observe(
    source: listed.cell,
    effect: (Pulse p) => print('   [ScanIndexed] ${p.payload}'),
  );
  await c.emitAsync('a');
  await c.emitAsync('b');
  iObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}