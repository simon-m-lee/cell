// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Map Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that transform each payload (Rx `map` family).
///
/// | Operator | Rx analogue | Result |
/// |---|---|---|
/// | [MapValue] | `map` | `project(value)` |
/// | [MapTo] | `mapTo` | the same constant |
/// | [MapWithIndex] | `map` + index | `project(value, index)` |
/// | [MapNotNull] | `map` + `whereNotNull` | drop null projections |
/// | [MapWhen] / [MapValueIf] | `map` + `filter` | project only when [test] is true |
/// | [MapValueOr] | `map` + fallback | [orElse] when [project] throws |
/// | [MapValues] | map on `Map` values | new `Map` with projected values |
/// | [MapKeys] | map on `Map` keys | new `Map` with projected keys |
///
/// Named [MapValue] so it does not clash with `dart:core` `Map`.
/// That class **is** Rx `map`. The extras are MapValue-family variants.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for map operators.
///
/// Called when an error occurs during mapping operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = MapErrorHandler((error, stack) {
///   print('Map error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef MapErrorHandler = void Function(Object error, StackTrace? stackTrace);

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
      MapErrorHandler? onError,
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
// MapValue - Transform Each Payload
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that transforms each typed payload using
/// [project] (Rx `map`).
///
/// [MapValue] is the fundamental mapping operator. It applies a
/// transformation function to each typed payload and emits the result.
///
/// ### When to use
/// Use [MapValue] when you need to transform each value in a stream.
///
/// - **Data Transformation**: Converting data from one format to another.
/// - **Data Enrichment**: Enriching data with additional information.
/// - **Data Cleaning**: Cleaning or sanitizing data.
/// - **Data Projection**: Projecting a subset of data.
/// - **Type Conversion**: Converting between types.
/// - **Formatting**: Formatting values for display.
/// - **Computation**: Computing derived values.
///
/// ### Choosing Between Map Variants
/// - **Use [MapValue]** for **Standard Mapping**: When you need to
///   transform each value with a function.
/// - **Use [MapTo]** for **Constant Mapping**: When you always want
///   the same value.
/// - **Use [MapWithIndex]** for **Indexed Mapping**: When you need
///   the index in the transformation.
/// - **Use [MapNotNull]** for **Null Filtering**: When you want to
///   drop null results.
/// - **Use [MapWhen]** for **Conditional Mapping**: When you only
///   want to map values that pass a test.
/// - **Use [MapValueOr]** for **Error Handling**: When you want a
///   fallback value on error.
/// - **Use [MapValues]** for **Map Values**: When transforming map values.
/// - **Use [MapKeys]** for **Map Keys**: When transforming map keys.
///
/// ### Comparison with Other Operators
/// | Operator | Transformation | Nullable | Index | Filter | Error Handling |
/// |----------|---------------|----------|-------|--------|----------------|
/// | **MapValue** | `project(value)` | No | No | No | No |
/// | **MapTo** | constant | No | No | No | No |
/// | **MapWithIndex** | `project(value, index)` | No | Yes | No | No |
/// | **MapNotNull** | `project(value)` | Yes | No | Drops null | No |
/// | **MapWhen** | `project(value)` | No | No | Test required | No |
/// | **MapValueOr** | `project(value)` | No | No | No | Yes |
/// | **MapValues** | `project(value)` | No | No | No | No |
/// | **MapKeys** | `project(key)` | No | No | No | No |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [project] is called with the payload.
/// 3. The result is emitted as a typed pulse.
/// 4. If [project] throws an error, the pulse is dropped.
/// 5. The emitted pulse gets the step `'MapValue'` for provenance.
///
/// ### Non‑obvious
/// - **Type Safety**: Input type [S] and output type [T] are separate.
/// - **Error Handling**: If [project] throws, the pulse is dropped.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Transformation**: [project] is synchronous.
///
/// ### Example: Doubling Values
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final doubled = MapValue<int, int>(
///   (n) => n * 2,
/// ).toHandle(source: input.cell);
///
/// input.emit(5);  // -> 10
/// input.emit(7);  // -> 14
/// ```
///
/// ### Example: String Formatting
/// ```dart
/// final users = Cell.ingress<User>();
///
/// final names = MapValue<User, String>(
///   (user) => '${user.firstName} ${user.lastName}',
/// ).toHandle(source: users.cell);
/// ```
///
/// ### Example: Type Conversion
/// ```dart
/// final strings = Cell.ingress<String>();
///
/// final lengths = MapValue<String, int>(
///   (str) => str.length,
/// ).toHandle(source: strings.cell);
///
/// strings.emit('Hello');  // -> 5
/// strings.emit('World');  // -> 5
/// ```
///
/// ### Parameters:
/// - [project]: **Transformation Function.** Called with each typed
///   payload, returns the transformed value.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that transforms each payload.
///
/// ### See Also:
/// - [MapTo]: For mapping to a constant value.
/// - [MapWithIndex]: For indexed mapping.
/// - [MapNotNull]: For dropping null results.
/// - [MapWhen]: For conditional mapping.
/// - [MapValueOr]: For error handling with fallback.
/// - [MapValues]: For transforming map values.
/// - [MapKeys]: For transforming map keys.
class MapValue<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MapValue(
      T Function(S value) project, {
        MapErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      try {
        return _out<T>(
          project(typed.payload as S),
          typed,
          cell,
          'MapValue',
        );
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// MapTo - Constant Mapping
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits [value] for every typed pulse
/// (Rx `mapTo`).
///
/// [MapTo] is a specialized mapping operator that always emits the
/// same constant value, regardless of the input. This is useful for
/// converting any input into a fixed output.
///
/// ### When to use
/// Use [MapTo] when you need to map any input to a constant value.
///
/// - **Event Conversion**: Converting any event to a specific event.
/// - **Signal Generation**: Generating a fixed signal on any input.
/// - **Toggle**: Converting any input to a toggle signal.
/// - **Trigger**: Converting any input to a trigger signal.
/// - **Mapping to Void**: Mapping any input to a void signal.
/// - **Default Responses**: Always responding with a fixed value.
///
/// ### Example: Ping on Any Click
/// ```dart
/// final clicks = Cell.ingress<void>();
///
/// final pings = MapTo<void, String>(
///   'ping',
/// ).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // -> ping
/// clicks.emit(null); // -> ping
/// ```
///
/// ### Example: Toggle on Any Input
/// ```dart
/// final inputs = Cell.ingress<int>();
///
/// final toggles = MapTo<int, bool>(
///   true,
/// ).toHandle(source: inputs.cell);
///
/// inputs.emit(42); // -> true
/// inputs.emit(100); // -> true
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, the constant [value] is emitted.
/// 3. The input value is ignored (only the type is checked).
/// 4. The emitted pulse gets the step `'MapTo'` for provenance.
///
/// ### Non‑obvious
/// - **Input Ignored**: The input value is not used in the output.
/// - **Type Check**: The type is still checked to ensure proper typing.
/// - **Constant Output**: The same value is emitted for every input.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Mapping**: The mapping is synchronous.
///
/// ### Parameters:
/// - [value]: **Constant Value.** The value to emit for every input.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload (for type checking).
/// - [T]: The type of the constant output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maps all inputs to a constant.
///
/// ### See Also:
/// - [MapValue]: For transforming inputs.
/// - [MapWithIndex]: For indexed mapping.
/// - [MapNotNull]: For dropping null results.
/// - [MapWhen]: For conditional mapping.
class MapTo<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MapTo(
      T value, {
        MapErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      return _out<T>(value, typed, cell, 'MapTo');
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// MapWithIndex - Indexed Mapping
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that transforms each payload with its index
/// (Rx `map` + index).
///
/// [MapWithIndex] is similar to [MapValue] but the transformation
/// function receives the index of each value in the sequence.
///
/// ### When to use
/// Use [MapWithIndex] when your transformation depends on the
/// position of the value.
///
/// - **Position Tracking**: Including position in the output.
/// - **ID Generation**: Generating IDs based on position.
/// - **Progress Tracking**: Tracking progress through a sequence.
/// - **Offset Calculation**: Calculating offsets based on position.
/// - **Enumeration**: Enumerating items in a sequence.
/// - **Pattern Generation**: Generating patterns based on index.
///
/// ### Example: Indexed Labeling
/// ```dart
/// final items = Cell.ingress<String>();
///
/// final labeled = MapWithIndex<String, String>(
///   (item, index) => 'Item #${index + 1}: $item',
/// ).toHandle(source: items.cell);
///
/// items.emit('Apple');  // -> Item #1: Apple
/// items.emit('Banana'); // -> Item #2: Banana
/// ```
///
/// ### Example: Position-Based IDs
/// ```dart
/// final data = Cell.ingress<Data>();
///
/// final withIds = MapWithIndex<Data, (int, Data)>(
///   (data, index) => (index, data),
/// ).toHandle(source: data.cell);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [project] is called with the payload and index.
/// 3. The index starts at 0 and increments on each typed pulse.
/// 4. The result is emitted as a typed pulse.
/// 5. If [project] throws an error, the pulse is dropped.
/// 6. The emitted pulse gets the step `'MapWithIndex'` for provenance.
///
/// ### Non‑obvious
/// - **Index Type**: The index is a 0-based integer.
/// - **Typed Only**: Only typed pulses increment the index.
/// - **Error Handling**: If [project] throws, the pulse is dropped
///   and the index is not incremented.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Transformation**: [project] is synchronous.
///
/// ### Parameters:
/// - [project]: **Indexed Transformation Function.** Called with each
///   typed payload and its index, returns the transformed value.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that transforms each payload with its index.
///
/// ### See Also:
/// - [MapValue]: For standard mapping.
/// - [MapTo]: For constant mapping.
/// - [MapNotNull]: For dropping null results.
/// - [MapWhen]: For conditional mapping.
class MapWithIndex<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MapWithIndex(
      T Function(S value, int index) project, {
        MapErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      var index = 0;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        try {
          final result = project(typed.payload as S, index);
          index++;
          return _out<T>(result, typed, cell, 'MapWithIndex');
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
// MapNotNull - Drop Null Results
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that transforms and drops null results
/// (Rx `map` + `whereNotNull`).
///
/// [MapNotNull] is similar to [MapValue] but the transformation
/// function can return `null`, which will be dropped (not emitted).
///
/// ### When to use
/// Use [MapNotNull] when you want to skip values that don't meet a
/// criteria by returning `null`.
///
/// - **Filtering with Transformation**: Filter and transform in one step.
/// - **Optional Values**: Only emitting when a value is present.
/// - **Validation**: Skipping invalid values.
/// - **Conditional Mapping**: Only mapping valid values.
/// - **Data Cleaning**: Skipping null or invalid data.
/// - **Optional Extraction**: Extracting optional fields.
///
/// ### Example: Only Even Numbers
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final evens = MapNotNull<int, int>(
///   (n) => n.isEven ? n : null,
/// ).toHandle(source: input.cell);
///
/// input.emit(1); // dropped (null)
/// input.emit(2); // -> 2
/// input.emit(3); // dropped (null)
/// input.emit(4); // -> 4
/// ```
///
/// ### Example: Optional Field Extraction
/// ```dart
/// final users = Cell.ingress<Map<String, Object>>();
///
/// final emails = MapNotNull<Map<String, Object>, String>(
///   (user) => user['email'] as String?,
/// ).toHandle(source: users.cell);
///
/// // Only users with email will emit
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [project] is called with the payload.
/// 3. If [project] returns `null`, the pulse is dropped.
/// 4. If [project] returns a non-null value, it's emitted.
/// 5. If [project] throws an error, the pulse is dropped.
/// 6. The emitted pulse gets the step `'MapNotNull'` for provenance.
///
/// ### Non‑obvious
/// - **Null Dropping**: `null` results are dropped silently.
/// - **Type Safety**: The output type [T] is non-nullable.
/// - **Error Handling**: If [project] throws, the pulse is dropped.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Transformation**: [project] is synchronous.
///
/// ### Parameters:
/// - [project]: **Optional Transformation Function.** Called with each
///   typed payload, returns `T?` or `null` to drop.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload (non-nullable).
///
/// ### Returns:
/// A [FlowInstruction] that transforms and drops null results.
///
/// ### See Also:
/// - [MapValue]: For standard mapping.
/// - [MapTo]: For constant mapping.
/// - [MapWithIndex]: For indexed mapping.
/// - [MapWhen]: For conditional mapping.
class MapNotNull<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MapNotNull(
      T? Function(S value) project, {
        MapErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      try {
        final result = project(typed.payload as S);
        if (result == null) return null;
        return _out<T>(result, typed, cell, 'MapNotNull');
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// MapWhen - Conditional Mapping
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that forwards `project(value)` only when
/// [test] is true; otherwise drops (Rx `map` + `filter`).
///
/// [MapWhen] combines filtering and mapping into a single operation.
/// Values that pass the test are mapped; values that fail are dropped.
///
/// ### When to use
/// Use [MapWhen] when you want to filter and map in one step.
///
/// - **Filter and Transform**: Filtering and transforming in one pass.
/// - **Conditional Mapping**: Only mapping values that meet criteria.
/// - **Data Validation**: Validating and transforming data.
/// - **Type Safety**: Ensuring values meet criteria before mapping.
/// - **Data Cleaning**: Cleaning data while transforming.
/// - **Selective Processing**: Processing only certain values.
///
/// ### Example: Even Numbers Only
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final evenLabels = MapWhen<int, String>(
///   (n) => n.isEven,
///   (n) => 'even-$n',
/// ).toHandle(source: input.cell);
///
/// input.emit(1); // dropped
/// input.emit(2); // -> even-2
/// input.emit(3); // dropped
/// input.emit(4); // -> even-4
/// ```
///
/// ### Example: Non-Empty Strings
/// ```dart
/// final input = Cell.ingress<String>();
///
/// final nonEmpty = MapWhen<String, String>(
///   (s) => s.isNotEmpty,
///   (s) => s.trim(),
/// ).toHandle(source: input.cell);
///
/// input.emit('');     // dropped
/// input.emit('  a  '); // -> a
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [test] is called with the payload.
/// 3. If [test] returns `false`, the pulse is dropped.
/// 4. If [test] returns `true`, [project] is called with the payload.
/// 5. The result is emitted as a typed pulse.
/// 6. If [test] or [project] throws an error, the pulse is dropped.
/// 7. The emitted pulse gets the step `'MapWhen'` for provenance.
///
/// ### Non‑obvious
/// - **Two Steps**: Test then project (both synchronous).
/// - **Dropping**: If [test] fails, the pulse is dropped.
/// - **Error Handling**: If [test] or [project] throws, the pulse is dropped.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Operations**: Both [test] and [project] are synchronous.
///
/// ### Parameters:
/// - [test]: **Predicate Function.** Called with each typed payload,
///   returns `true` to map, `false` to drop.
/// - [project]: **Transformation Function.** Called with each typed
///   payload that passes [test], returns the transformed value.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that conditionally maps values.
///
/// ### See Also:
/// - [MapValue]: For standard mapping.
/// - [MapTo]: For constant mapping.
/// - [MapWithIndex]: For indexed mapping.
/// - [MapNotNull]: For dropping null results.
/// - [MapValueIf]: Alias of [MapWhen].
class MapWhen<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MapWhen(
      bool Function(S value) test,
      T Function(S value) project, {
        MapErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      final value = typed.payload as S;
      try {
        if (!test(value)) return null;
        return _out<T>(project(value), typed, cell, 'MapWhen');
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

/// Alias of [MapWhen] for Rx compatibility.
///
/// [MapValueIf] provides the same conditional mapping functionality
/// as [MapWhen] under a name that better reflects the "if" condition.
///
/// ### Example
/// ```dart
/// final labeled = MapValueIf<int, String>(
///   (n) => n.isEven,
///   (n) => 'even-$n',
/// ).toHandle(source: input.cell);
/// // Same as MapWhen
/// ```
class MapValueIf<S, T> extends MapWhen<S, T> {
  MapValueIf(
      super.test,
      super.project, {
        super.onError,
        super.user,
      });
}

// ─────────────────────────────────────────────────────────────
// MapValueOr - Error Handling with Fallback
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] like [MapValue], but [orElse] is used when
/// [project] throws.
///
/// [MapValueOr] provides graceful error handling by allowing a
/// fallback value when the mapping function fails.
///
/// ### When to use
/// Use [MapValueOr] when your mapping function may throw and you
/// want to provide a fallback value.
///
/// - **Division by Zero**: Handling division by zero gracefully.
/// - **Data Parsing**: Parsing data with fallback on parse errors.
/// - **API Responses**: Handling malformed API responses.
/// - **Type Casting**: Safe type casting with fallback.
/// - **Calculations**: Calculations that may fail.
///
/// ### Example: Safe Division
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final safeDiv = MapValueOr<int, int>(
///   (n) => n == 0 ? throw StateError('zero') : 10 ~/ n,
///   orElse: (_, __) => 0,
/// ).toHandle(source: input.cell);
///
/// input.emit(0); // -> 0 (fallback)
/// input.emit(5); // -> 2
/// ```
///
/// ### Example: Safe Parsing
/// ```dart
/// final input = Cell.ingress<String>();
///
/// final parsed = MapValueOr<String, int>(
///   (s) => int.parse(s),
///   orElse: (_, __) => 0,
/// ).toHandle(source: input.cell);
///
/// input.emit('123'); // -> 123
/// input.emit('invalid'); // -> 0 (fallback)
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [project] is called with the payload.
/// 3. If [project] succeeds, the result is emitted.
/// 4. If [project] throws an error, [orElse] is called with the
///    value and the error.
/// 5. If [orElse] succeeds, the result is emitted with step
///    `'MapValueOr.orElse'`.
/// 6. If [orElse] throws, the pulse is dropped.
/// 7. If [project] throws and [orElse] succeeds, the emitted pulse
///    gets the step `'MapValueOr.orElse'` for provenance.
///
/// ### Non‑obvious
/// - **Two-Level Error Handling**: Errors in [project] go to [orElse].
/// - **Errors in [orElse]**: If [orElse] throws, the pulse is dropped.
/// - **Provenance Preservation**: Fallback emissions get the step
///   `'MapValueOr.orElse'` to distinguish them.
/// - **Synchronous Operations**: Both [project] and [orElse] are synchronous.
///
/// ### Parameters:
/// - [project]: **Transformation Function.** Called with each typed
///   payload, returns the transformed value.
/// - [orElse]: **Fallback Function.** Called with the value and error
///   when [project] throws, returns the fallback value.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maps with error handling.
///
/// ### See Also:
/// - [MapValue]: For standard mapping.
/// - [MapNotNull]: For dropping null results.
/// - [MapWhen]: For conditional mapping.
class MapValueOr<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MapValueOr(
      T Function(S value) project, {
        required T Function(S value, Object error) orElse,
        MapErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      final value = typed.payload as S;
      try {
        return _out<T>(project(value), typed, cell, 'MapValueOr');
      } catch (e, stack) {
        onError?.call(e, stack);
        try {
          return _out<T>(orElse(value, e), typed, cell, 'MapValueOr.orElse');
        } catch (e2, stack2) {
          onError?.call(e2, stack2);
          return null;
        }
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// MapValues - Transform Map Values
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] where the payload is a [Map]; emit a new map
/// with [project] applied to each value.
///
/// [MapValues] is a specialized operator for transforming the values
/// of a map payload.
///
/// ### When to use
/// Use [MapValues] when you have a map payload and want to transform
/// its values.
///
/// - **Data Transformation**: Transforming values in a map.
/// - **Data Enrichment**: Enriching map values.
/// - **Type Conversion**: Converting map value types.
/// - **Data Cleaning**: Cleaning map values.
/// - **Formatting**: Formatting map values.
///
/// ### Example: Doubling Map Values
/// ```dart
/// final input = Cell.ingress<Map<String, int>>();
///
/// final doubled = MapValues<String, int, int>(
///   (n) => n * 2,
/// ).toHandle(source: input.cell);
///
/// input.emit({'a': 1, 'b': 2}); // -> {'a': 2, 'b': 4}
/// ```
///
/// ### Example: Stringifying Values
/// ```dart
/// final input = Cell.ingress<Map<String, int>>();
///
/// final stringified = MapValues<String, int, String>(
///   (n) => 'Value: $n',
/// ).toHandle(source: input.cell);
///
/// input.emit({'x': 10, 'y': 20}); // -> {'x': 'Value: 10', 'y': 'Value: 20'}
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked to ensure it's a `Map`.
/// 2. For each entry in the map, [project] is called with the value.
/// 3. A new map is created with the same keys and transformed values.
/// 4. The new map is emitted.
/// 5. If [project] throws an error, the pulse is dropped.
/// 6. The emitted pulse gets the step `'MapValues'` for provenance.
///
/// ### Non‑obvious
/// - **Map Payload Required**: The payload must be a `Map`.
/// - **Keys Preserved**: The keys remain unchanged.
/// - **Type Safety**: Generic over key type [K], value type [V],
///   and result type [R].
/// - **Error Handling**: If [project] throws, the pulse is dropped.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Transformation**: [project] is synchronous.
///
/// ### Parameters:
/// - [project]: **Value Transformation Function.** Called with each
///   map value, returns the transformed value.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [K]: The type of the map keys.
/// - [V]: The type of the map values.
/// - [R]: The type of the transformed values.
///
/// ### Returns:
/// A [FlowInstruction] that transforms map values.
///
/// ### See Also:
/// - [MapKeys]: For transforming map keys.
/// - [MapValue]: For transforming individual values.
class MapValues<K, V, R> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MapValues(
      R Function(V value) project, {
        MapErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final payload = pulse.payload;
      if (payload is! Map) {
        onError?.call(
          FormatException(
            'Expected Map, got ${payload.runtimeType}',
          ),
          StackTrace.current,
        );
        return null;
      }
      try {
        final out = <K, R>{
          for (final e in payload.entries)
            e.key as K: project(e.value as V),
        };
        return _out<Map<K, R>>(out, pulse, cell, 'MapValues');
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// MapKeys - Transform Map Keys
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] where the payload is a [Map]; emit a new map
/// with [project] applied to each key.
///
/// [MapKeys] is a specialized operator for transforming the keys
/// of a map payload.
///
/// ### When to use
/// Use [MapKeys] when you have a map payload and want to transform
/// its keys.
///
/// - **Key Transformation**: Transforming map keys.
/// - **Key Type Conversion**: Converting map key types.
/// - **Key Normalization**: Normalizing map keys (e.g., lowercase).
/// - **Key Filtering**: Filtering map keys.
/// - **Key Mapping**: Mapping keys to different values.
///
/// ### Example: Lowercasing Keys
/// ```dart
/// final input = Cell.ingress<Map<String, int>>();
///
/// final lowercased = MapKeys<String, int, String>(
///   (key) => key.toLowerCase(),
/// ).toHandle(source: input.cell);
///
/// input.emit({'A': 1, 'B': 2}); // -> {'a': 1, 'b': 2}
/// ```
///
/// ### Example: Prefixing Keys
/// ```dart
/// final input = Cell.ingress<Map<String, int>>();
///
/// final prefixed = MapKeys<String, int, String>(
///   (key) => 'prefix_$key',
/// ).toHandle(source: input.cell);
///
/// input.emit({'x': 10, 'y': 20}); // -> {'prefix_x': 10, 'prefix_y': 20}
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked to ensure it's a `Map`.
/// 2. For each entry in the map, [project] is called with the key.
/// 3. A new map is created with transformed keys and the same values.
/// 4. The new map is emitted.
/// 5. If [project] throws an error, the pulse is dropped.
/// 6. The emitted pulse gets the step `'MapKeys'` for provenance.
///
/// ### Non‑obvious
/// - **Map Payload Required**: The payload must be a `Map`.
/// - **Values Preserved**: The values remain unchanged.
/// - **Type Safety**: Generic over key type [K], value type [V],
///   and result key type [R].
/// - **Error Handling**: If [project] throws, the pulse is dropped.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Transformation**: [project] is synchronous.
/// - **Key Collisions**: If two keys map to the same value, the last
///   one wins (standard Map behavior).
///
/// ### Parameters:
/// - [project]: **Key Transformation Function.** Called with each
///   map key, returns the transformed key.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [K]: The type of the input map keys.
/// - [V]: The type of the map values.
/// - [R]: The type of the transformed keys.
///
/// ### Returns:
/// A [FlowInstruction] that transforms map keys.
///
/// ### See Also:
/// - [MapValues]: For transforming map values.
/// - [MapValue]: For transforming individual values.
class MapKeys<K, V, R> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MapKeys(
      R Function(K key) project, {
        MapErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final payload = pulse.payload;
      if (payload is! Map) {
        onError?.call(
          FormatException(
            'Expected Map, got ${payload.runtimeType}',
          ),
          StackTrace.current,
        );
        return null;
      }
      try {
        final out = <R, V>{
          for (final e in payload.entries)
            project(e.key as K): e.value as V,
        };
        return _out<Map<R, V>>(out, pulse, cell, 'MapKeys');
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [MapValue] instruction and related operators
/// showing their behavior in various mapping scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Map Operators Demo ────────────────────────────────────────
///
/// 1. MapValue
///    [MapValue] 2
///    [MapValue] 4
///
/// 2. MapTo
///    [MapTo] ping
///    [MapTo] ping
///
/// 3. MapWithIndex
///    [MapWithIndex] 0:a
///    [MapWithIndex] 1:b
///
/// 4. MapNotNull
///    [MapNotNull] 2
///
/// 5. MapWhen
///    [MapWhen] even-2
///
/// 6. MapValueOr
///    [MapValueOr] 0
///
/// 7. MapValues
///    [MapValues] {a: 2, b: 4}
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
/// 1. **MapValue - Standard Mapping**: Shows basic transformation.
///    Each input value is doubled and emitted as a new value.
///
/// 2. **MapTo - Constant Mapping**: Shows mapping to a constant.
///    Every input emits the same constant `'ping'`.
///
/// 3. **MapWithIndex - Indexed Mapping**: Shows mapping with index.
///    Each value is labeled with its position in the sequence.
///
/// 4. **MapNotNull - Drop Null Results**: Shows filtering via null
///    return. Odd numbers return null and are dropped; even numbers
///    are emitted.
///
/// 5. **MapWhen - Conditional Mapping**: Shows filtering and mapping
///    in one step. Only even numbers pass the test and are mapped
///    to labels.
///
/// 6. **MapValueOr - Error Handling with Fallback**: Shows error
///    handling with fallback. Division by zero triggers the fallback.
///
/// 7. **MapValues - Transform Map Values**: Shows transforming the
///    values of a map payload. Each value is doubled.
///
/// ### Key Takeaways
/// - Map operators transform payloads.
/// - MapValue applies a transformation function.
/// - MapTo emits a constant value.
/// - MapWithIndex includes the index in the transformation.
/// - MapNotNull drops null results.
/// - MapWhen combines filtering and mapping.
/// - MapValueOr provides error handling with fallback.
/// - MapValues transforms map values.
/// - MapKeys transforms map keys.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Errors in transformation drop the pulse (unless using MapValueOr).
///
/// ### Note on Types
/// Map operators are generic over input type [S] and output type [T].
/// This allows for type-safe transformations between different types.
Future<void> main() async {
  print('── Map Operators Demo ────────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. MapValue - Standard Mapping
  // ─────────────────────────────────────────────────────────────────────
  print('1. MapValue');

  final nums = Cell.ingress<int>();

  final doubled = MapValue<int, int>(
        (n) => n * 2,
  ).toHandle(source: nums.cell);

  final mObs = Cell.observe(
    source: doubled.cell,
    effect: (Pulse p) => print('   [MapValue] ${p.payload}'),
  );

  await nums.emitAsync(1);
  await nums.emitAsync(2);

  mObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. MapTo - Constant Mapping
  // ─────────────────────────────────────────────────────────────────────
  print('2. MapTo');

  final clicks = Cell.ingress<void>();

  final ping = MapTo<void, String>(
    'ping',
  ).toHandle(source: clicks.cell);

  final tObs = Cell.observe(
    source: ping.cell,
    effect: (Pulse p) => print('   [MapTo] ${p.payload}'),
  );

  await clicks.emitAsync(null);
  await clicks.emitAsync(null);

  tObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. MapWithIndex - Indexed Mapping
  // ─────────────────────────────────────────────────────────────────────
  print('3. MapWithIndex');

  final letters = Cell.ingress<String>();

  final indexed = MapWithIndex<String, String>(
        (s, i) => '$i:$s',
  ).toHandle(source: letters.cell);

  final iObs = Cell.observe(
    source: indexed.cell,
    effect: (Pulse p) => print('   [MapWithIndex] ${p.payload}'),
  );

  await letters.emitAsync('a');
  await letters.emitAsync('b');

  iObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. MapNotNull - Drop Null Results
  // ─────────────────────────────────────────────────────────────────────
  print('4. MapNotNull');

  final maybe = Cell.ingress<int>();

  final evens = MapNotNull<int, int>(
        (n) => n.isEven ? n : null,
  ).toHandle(source: maybe.cell);

  final nObs = Cell.observe(
    source: evens.cell,
    effect: (Pulse p) => print('   [MapNotNull] ${p.payload}'),
  );

  await maybe.emitAsync(1);
  await maybe.emitAsync(2);

  nObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 5. MapWhen - Conditional Mapping
  // ─────────────────────────────────────────────────────────────────────
  print('5. MapWhen');

  final when = Cell.ingress<int>();

  final labeled = MapWhen<int, String>(
        (n) => n.isEven,
        (n) => 'even-$n',
  ).toHandle(source: when.cell);

  final wObs = Cell.observe(
    source: labeled.cell,
    effect: (Pulse p) => print('   [MapWhen] ${p.payload}'),
  );

  await when.emitAsync(1);
  await when.emitAsync(2);

  wObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 6. MapValueOr - Error Handling with Fallback
  // ─────────────────────────────────────────────────────────────────────
  print('6. MapValueOr');

  final risky = Cell.ingress<int>();

  final safe = MapValueOr<int, int>(
        (n) => n == 0 ? throw StateError('zero') : 10 ~/ n,
    orElse: (_, __) => 0,
  ).toHandle(source: risky.cell);

  final oObs = Cell.observe(
    source: safe.cell,
    effect: (Pulse p) => print('   [MapValueOr] ${p.payload}'),
  );

  await risky.emitAsync(0);

  oObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 7. MapValues - Transform Map Values
  // ─────────────────────────────────────────────────────────────────────
  print('7. MapValues');

  final dict = Cell.ingress<Map<String, int>>();

  final doubledMap = MapValues<String, int, int>(
        (n) => n * 2,
  ).toHandle(source: dict.cell);

  final vObs = Cell.observe(
    source: doubledMap.cell,
    effect: (Pulse p) => print('   [MapValues] ${p.payload}'),
  );

  await dict.emitAsync({'a': 1, 'b': 2});

  vObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}