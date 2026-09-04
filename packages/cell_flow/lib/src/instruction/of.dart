// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Of/From/Range Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that create a sequence on the first trigger
/// (Rx `of` / `from` / `range`).
///
/// | Operator | Rx analogue | Emits |
/// |---|---|---|
/// | [Of] | `of(...)` | the given values, once |
/// | [FromIterable] | `from(iterable)` | each element, once |
/// | [Range] | `range` | `start .. start+count-1` |
/// | [Repeat] | `repeat` | [value] [count] times |
///
/// A Cell does not complete. These play their sequence when the bound
/// handle is first pulsed, then ignore later arms (except [Repeat]
/// / [FromIterable] which are also one-shot unless noted).
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for of/from/range operators.
///
/// Called when an error occurs during sequence emission.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = OfErrorHandler((error, stack) {
///   print('Of error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef OfErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// Helper to create an output pulse with proper provenance.
Pulse<T> _out<T>(T value, Pulse trigger, Cell? cell, String step) {
  return Pulse<T>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

// ─────────────────────────────────────────────────────────────
// Of - Emit Given Values Once
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits [values] in order on the first
/// trigger (Rx `of`).
///
/// [Of] is the simplest sequence creator. It emits a fixed list of
/// values in order when the bound source first pulses.
///
/// ### When to use
/// Use [Of] when you need to emit a fixed sequence of values on
/// the first trigger.
///
/// - **Initial Values**: Emitting initial values on startup.
/// - **Test Data**: Emitting test data sequences.
/// - **Configuration**: Emitting configuration values.
/// - **Static Sequences**: Emitting static sequences.
/// - **One-Time Setup**: Performing one-time setup sequences.
///
/// ### Choosing Between Sequence Operators
/// - **Use [Of]** for **Fixed Values**: When you have a fixed list
///   of values to emit.
/// - **Use [FromIterable]** for **Iterable Source**: When you have
///   an iterable source.
/// - **Use [Range]** for **Numeric Range**: When you need a range
///   of numbers.
/// - **Use [Repeat]** for **Repeated Value**: When you need the same
///   value repeated.
///
/// ### Comparison with Other Operators
/// | Operator | Source | Emits | First Trigger Only |
/// |----------|--------|-------|-------------------|
/// | **Of** | Fixed values | All values | Yes |
/// | **FromIterable** | Iterable | All elements | Yes |
/// | **Range** | Start, count | Numeric range | Yes |
/// | **Repeat** | Value, count | Repeated value | Yes |
///
/// ### How it works
/// 1. The first source pulse arms the instruction.
/// 2. Each value in [values] is emitted in order.
/// 3. Later pulses are ignored.
/// 4. Each emitted value gets the step `'Of'` for provenance.
///
/// ### Non‑obvious
/// - **First Trigger Only**: The sequence only plays on the first pulse.
/// - **Synchronous Emission**: Values are emitted synchronously.
/// - **No Completion**: Cells don't complete, but the instruction
///   stops emitting after all values are sent.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Error Handling**: If emission fails, the error is reported.
///
/// ### Example: Emitting Initial Values
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final initial = Of<int>([1, 2, 3, 4, 5])
///     .toHandle(source: start.cell);
///
/// start.emit(null);
/// // Outputs: 1, 2, 3, 4, 5
/// ```
///
/// ### Example: Configuration Values
/// ```dart
/// final init = Cell.ingress<void>();
///
/// final config = Of<String>(['app', 'version', '1.0.0'])
///     .toHandle(source: init.cell);
///
/// init.emit(null);
/// // Outputs: app, version, 1.0.0
/// ```
///
/// ### Parameters:
/// - [values]: **The Values to Emit.** The sequence of values to
///   emit on the first trigger.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The type of the values to emit.
///
/// ### Returns:
/// A [FlowInstruction] that emits fixed values once.
///
/// ### See Also:
/// - [FromIterable]: For emitting from an iterable.
/// - [Range]: For emitting a numeric range.
/// - [Repeat]: For emitting a repeated value.
class Of<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Of(
      Iterable<T> values, {
        OfErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var started = false;
      return (pulse, {cell, user, future, token}) {
        if (started) return null;
        started = true;
        try {
          for (final value in values) {
            future!(
              result: _out<T>(value, pulse, cell, 'Of'),
              token: token,
            );
          }
        } catch (e, stack) {
          onError?.call(e, stack);
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// FromIterable - Emit from Iterable Once
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits each element of [source] on the
/// first trigger (Rx `from`).
///
/// [FromIterable] is similar to [Of] but takes an iterable source.
/// It emits each element of the iterable in order on the first trigger.
///
/// ### When to use
/// Use [FromIterable] when you have an iterable source to emit.
///
/// - **Iterable Sources**: Emitting from any iterable (List, Set, etc.).
/// - **Dynamic Collections**: Emitting from collections that are
///   built dynamically.
/// - **Data Loading**: Emitting loaded data sequences.
/// - **Stream Conversion**: Converting iterables to pulses.
/// - **Batch Processing**: Processing collections as sequences.
///
/// ### Example: Emitting from a List
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final fromList = FromIterable<String>(['a', 'b', 'c'])
///     .toHandle(source: start.cell);
///
/// start.emit(null);
/// // Outputs: a, b, c
/// ```
///
/// ### Example: Emitting from a Set
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final fromSet = FromIterable<int>({1, 2, 3, 4, 5})
///     .toHandle(source: start.cell);
///
/// start.emit(null);
/// // Outputs: 1, 2, 3, 4, 5 (order not guaranteed)
/// ```
///
/// ### How it works
/// 1. The first source pulse arms the instruction.
/// 2. Each element of [source] is emitted in iteration order.
/// 3. Later pulses are ignored.
/// 4. Each emitted value gets the step `'FromIterable'` for provenance.
///
/// ### Non‑obvious
/// - **First Trigger Only**: The sequence only plays on the first pulse.
/// - **Iterable Order**: The iteration order of the iterable is used.
/// - **Synchronous Emission**: Values are emitted synchronously.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Error Handling**: If emission fails, the error is reported.
///
/// ### Parameters:
/// - [source]: **The Iterable Source.** The iterable to emit elements from.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The type of the elements to emit.
///
/// ### Returns:
/// A [FlowInstruction] that emits from an iterable once.
///
/// ### See Also:
/// - [Of]: For emitting fixed values.
/// - [Range]: For emitting a numeric range.
/// - [Repeat]: For emitting a repeated value.
class FromIterable<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  FromIterable(
      Iterable<T> source, {
        OfErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var started = false;
      return (pulse, {cell, user, future, token}) {
        if (started) return null;
        started = true;
        try {
          for (final value in source) {
            future!(
              result: _out<T>(value, pulse, cell, 'FromIterable'),
              token: token,
            );
          }
        } catch (e, stack) {
          onError?.call(e, stack);
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Range - Emit Numeric Range Once
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits `count` integers from [start]
/// (Rx `range`).
///
/// [Range] emits a sequence of integers starting from [start] and
/// incrementing by [step] for [count] times.
///
/// ### When to use
/// Use [Range] when you need to emit a numeric range.
///
/// - **Counters**: Emitting counter values.
/// - **Indices**: Emitting index sequences.
/// - **Test Data**: Emitting numeric test data.
/// - **Loops**: Emitting loop iteration values.
/// - **Paginations**: Emitting page numbers.
/// - **ID Generation**: Emitting sequential IDs.
///
/// ### Example: Simple Range
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final range = Range(3, 5)
///     .toHandle(source: start.cell);
///
/// start.emit(null);
/// // Outputs: 3, 4, 5, 6, 7
/// ```
///
/// ### Example: Range with Step
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final evens = Range(2, 5, step: 2)
///     .toHandle(source: start.cell);
///
/// start.emit(null);
/// // Outputs: 2, 4, 6, 8, 10
/// ```
///
/// ### How it works
/// 1. The first source pulse arms the instruction.
/// 2. Values are emitted starting from [start].
/// 3. Each value increases by [step].
/// 4. [count] values are emitted.
/// 5. Later pulses are ignored.
/// 6. Each emitted value gets the step `'Range'` for provenance.
///
/// ### Non‑obvious
/// - **First Trigger Only**: The range only plays on the first pulse.
/// - **Step Control**: [step] controls the increment between values.
/// - **Synchronous Emission**: Values are emitted synchronously.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Error Handling**: If emission fails, the error is reported.
///
/// ### Parameters:
/// - [start]: **Starting Value.** The first integer in the range.
/// - [count]: **Number of Values.** How many integers to emit.
/// - [step]: **Step Size.** The increment between values. Defaults to 1.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - The output type is always `int`.
///
/// ### Returns:
/// A [FlowInstruction] that emits a numeric range once.
///
/// ### See Also:
/// - [Of]: For emitting fixed values.
/// - [FromIterable]: For emitting from an iterable.
/// - [Repeat]: For emitting a repeated value.
class Range extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Range(
      int start,
      int count, {
        int step = 1,
        OfErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var started = false;
      return (pulse, {cell, user, future, token}) {
        if (started) return null;
        started = true;
        try {
          var value = start;
          for (var i = 0; i < count; i++) {
            future!(
              result: _out<int>(value, pulse, cell, 'Range'),
              token: token,
            );
            value += step;
          }
        } catch (e, stack) {
          onError?.call(e, stack);
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Repeat - Emit Repeated Value Once
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits [value] [count] times on the
/// first trigger (Rx `repeat` of a value).
///
/// [Repeat] emits the same value multiple times on the first trigger.
/// This is useful for generating repeated signals.
///
/// ### When to use
/// Use [Repeat] when you need to emit the same value multiple times.
///
/// - **Heartbeats**: Emitting multiple heartbeat signals.
/// - **Retry Signals**: Emitting multiple retry attempts.
/// - **Test Data**: Emitting repeated test values.
/// - **Pulses**: Generating multiple pulses.
/// - **Acknowledgments**: Sending multiple acknowledgment signals.
/// - **Alerts**: Emitting repeated alert signals.
///
/// ### Example: Repeating a Value
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final repeated = Repeat<String>('ping', count: 3)
///     .toHandle(source: start.cell);
///
/// start.emit(null);
/// // Outputs: ping, ping, ping
/// ```
///
/// ### Example: Multiple Heartbeats
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final heartbeat = Repeat<int>(1, count: 5)
///     .toHandle(source: start.cell);
///
/// start.emit(null);
/// // Outputs: 1, 1, 1, 1, 1
/// ```
///
/// ### How it works
/// 1. The first source pulse arms the instruction.
/// 2. [value] is emitted [count] times.
/// 3. Later pulses are ignored.
/// 4. Each emitted value gets the step `'Repeat'` for provenance.
///
/// ### Non‑obvious
/// - **First Trigger Only**: The sequence only plays on the first pulse.
/// - **Same Value**: The same value is emitted each time.
/// - **Synchronous Emission**: Values are emitted synchronously.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Error Handling**: If emission fails, the error is reported.
///
/// ### Parameters:
/// - [value]: **The Value to Repeat.** The value to emit multiple times.
/// - [count]: **Number of Repetitions.** How many times to emit the value.
///   Defaults to 1.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The type of the value to repeat.
///
/// ### Returns:
/// A [FlowInstruction] that emits a repeated value once.
///
/// ### See Also:
/// - [Of]: For emitting fixed values.
/// - [FromIterable]: For emitting from an iterable.
/// - [Range]: For emitting a numeric range.
class Repeat<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Repeat(
      T value, {
        int count = 1,
        OfErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var started = false;
      return (pulse, {cell, user, future, token}) {
        if (started) return null;
        started = true;
        try {
          for (var i = 0; i < count; i++) {
            future!(
              result: _out<T>(value, pulse, cell, 'Repeat'),
              token: token,
            );
          }
        } catch (e, stack) {
          onError?.call(e, stack);
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Of] instruction and related operators
/// showing their behavior in various sequence creation scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Of / From / Range Demo ────────────────────────────────────
///
/// 1. Of
///    [Of] a
///    [Of] b
///
/// 2. FromIterable
///    [FromIterable] 1
///    [FromIterable] 2
///
/// 3. Range
///    [Range] 3
///    [Range] 4
///    [Range] 5
///
/// 4. Repeat
///    [Repeat] x
///    [Repeat] x
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
/// 1. **Of - Fixed Values**: Shows emitting fixed values on the
///    first trigger. The values `['a', 'b']` are emitted in order.
///
/// 2. **FromIterable - Iterable Source**: Shows emitting from an
///    iterable. The list `[1, 2]` is emitted element by element.
///
/// 3. **Range - Numeric Range**: Shows emitting a numeric range.
///    Starting at 3, 3 values are emitted: 3, 4, 5.
///
/// 4. **Repeat - Repeated Value**: Shows emitting the same value
///    multiple times. The value `'x'` is emitted 2 times.
///
/// ### Key Takeaways
/// - Of emits fixed values on the first trigger.
/// - FromIterable emits from any iterable.
/// - Range emits a numeric range.
/// - Repeat emits the same value multiple times.
/// - All operators are first-trigger only.
/// - Later triggers are ignored.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Values are emitted synchronously.
///
/// ### Note on One-Shot Behavior
/// These operators are designed for one-shot emission. They play
/// their sequence on the first trigger and ignore later triggers.
/// This is different from [FromStream] which continues to emit
/// stream events.
Future<void> main() async {
  print('── Of / From / Range Demo ────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Of - Fixed Values
  // ─────────────────────────────────────────────────────────────────────
  print('1. Of');

  final a = Cell.ingress<void>();

  final of = Of<String>(['a', 'b']).toHandle(source: a.cell);

  final oObs = Cell.observe(
    source: of.cell,
    effect: (Pulse p) => print('   [Of] ${p.payload}'),
  );

  await a.emitAsync(null);

  oObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. FromIterable - Iterable Source
  // ─────────────────────────────────────────────────────────────────────
  print('2. FromIterable');

  final b = Cell.ingress<void>();

  final from = FromIterable<int>([1, 2]).toHandle(source: b.cell);

  final fObs = Cell.observe(
    source: from.cell,
    effect: (Pulse p) => print('   [FromIterable] ${p.payload}'),
  );

  await b.emitAsync(null);

  fObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. Range - Numeric Range
  // ─────────────────────────────────────────────────────────────────────
  print('3. Range');

  final c = Cell.ingress<void>();

  final range = Range(3, 3).toHandle(source: c.cell);

  final rObs = Cell.observe(
    source: range.cell,
    effect: (Pulse p) => print('   [Range] ${p.payload}'),
  );

  await c.emitAsync(null);

  rObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. Repeat - Repeated Value
  // ─────────────────────────────────────────────────────────────────────
  print('4. Repeat');

  final d = Cell.ingress<void>();

  final repeat = Repeat<String>('x', count: 2).toHandle(source: d.cell);

  final pObs = Cell.observe(
    source: repeat.cell,
    effect: (Pulse p) => print('   [Repeat] ${p.payload}'),
  );

  await d.emitAsync(null);

  pObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}