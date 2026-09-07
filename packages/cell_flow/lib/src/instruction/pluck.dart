// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flow/cell_flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Pluck Operators
// ─────────────────────────────────────────────────────────────

/// Error handler callback for pluck operators.
///
/// Called when an error occurs during field extraction, such as
/// missing keys, type mismatches, path navigation errors, or
/// unsupported source types.
///
/// ### Example
/// ```dart
/// final errorHandler = PluckErrorHandler((error, stack) {
///   print('Pluck error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef PluckErrorHandler = void Function(Object error, StackTrace? stackTrace);

// ─────────────────────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────────────────────

/// Internal helper to read a value from a source object.
///
/// [_read] handles various source types:
/// - [Map]: uses `source[key]`
/// - [List] or [Iterable]: uses `source[key]` with integer key
/// - Any object with `[]`: attempts to use the index operator
///
/// ### Parameters:
/// - [source]: The source object to read from.
/// - [key]: The key to look up.
///
/// ### Returns:
/// The value at the given key.
///
/// ### Throws:
/// - [FormatException] if the source type is not supported.
/// - [RangeError] if the key is out of bounds for an iterable.
///
/// ### Non‑obvious
/// - **Iterable Support**: For iterables, the key must be an integer.
/// - **List Conversion**: Non-list iterables are converted to lists.
/// - **Index Operator**: Any object with `[]` can be used.
/// - **Null Handling**: Returns `null` if the key exists with a null value.
Object? _read(Object? source, Object key) {
  if (source is Map) return source[key];
  if (source is Iterable && key is int) {
    final list = source is List ? source : source.toList();
    if (key < 0 || key >= list.length) {
      throw RangeError.index(key, list, 'key');
    }
    return list[key];
  }
  if (source is List && key is int) return source[key];
  throw FormatException(
    'Cannot pluck $key from ${source.runtimeType}',
  );
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
// Pluck - Single Field Extraction
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits `payload[key]` as type [T]
/// (Rx `pluck`).
///
/// [Pluck] extracts a single field from each payload using the
/// provided [key]. The extracted value is emitted as a typed pulse.
///
/// ### When to use
/// Use [Pluck] when you need to extract a single field from a
/// complex payload.
///
/// - **Data Extraction**: Extracting fields from API responses.
/// - **Field Access**: Accessing properties of objects.
/// - **Data Transformation**: Extracting values for further processing.
/// - **Filtering**: Extracting fields for filtering logic.
/// - **Mapping**: Mapping complex objects to simple values.
/// - **Data Normalization**: Extracting normalized values.
///
/// ### Choosing Between Pluck Variants
/// - **Use [Pluck]** for **Simple Field Extraction**: When you know
///   the field exists and has the right type.
/// - **Use [PluckOr]** for **Default Values**: When the field may be
///   missing or have the wrong type.
/// - **Use [PluckAll]** for **Multiple Fields**: When you need to
///   extract several fields at once.
/// - **Use [PluckPath]** for **Nested Fields**: When you need to
///   navigate nested structures.
///
/// ### Comparison with Other Operators
/// | Operator | Fields | Default | Nested | Output Type |
/// |----------|--------|---------|--------|--------------|
/// | **Pluck** | Single | No | No | Single value |
/// | **PluckOr** | Single | Yes | No | Single value |
/// | **PluckAll** | Multiple | Optional | No | Map |
/// | **PluckPath** | Single | Optional | Yes | Single value |
///
/// ### How it works
/// 1. Each incoming pulse's payload is read using [key].
/// 2. The extracted value is type-checked to ensure it matches [T].
/// 3. If successful, the value is emitted as a typed pulse.
/// 4. If extraction fails, [onError] is called and the pulse is dropped.
/// 5. The pulse gets the step `'Pluck'` for provenance.
/// 6. The emitted value preserves the source, type, and priority.
///
/// ### Non‑obvious
/// - **Type Safety**: The extracted value must match type [T].
/// - **Error Handling**: Missing keys or type mismatches drop the pulse.
/// - **Source Types**: Supports Map, List/Iterable, and objects with `[]`.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Extraction**: All extraction is synchronous.
/// - **Null Values**: If the field exists with a null value, it's
///   emitted as null (if T is nullable).
///
/// ### Example: Extracting Name
/// ```dart
/// final users = Cell.ingress<Map<String, Object>>();
///
/// final names = Pluck<String>('name').toHandle(source: users.cell);
///
/// users.emit({'id': 1, 'name': 'Alice'}); // -> Alice
/// users.emit({'id': 2, 'name': 'Bob'});   // -> Bob
/// ```
///
/// ### Example: Extracting from List
/// ```dart
/// final arrays = Cell.ingress<List<String>>();
///
/// final first = Pluck<String>(0).toHandle(source: arrays.cell);
///
/// arrays.emit(['a', 'b', 'c']); // -> a
/// arrays.emit(['x', 'y', 'z']); // -> x
/// ```
///
/// ### Example: With Error Handling
/// ```dart
/// final data = Cell.ingress<Map<String, Object>>();
///
/// final extracted = Pluck<int>(
///   'age',
///   onError: (error, stack) {
///     print('Extraction failed: $error');
///   },
/// ).toHandle(source: data.cell);
///
/// data.emit({'id': 1});  // Drops the pulse (age missing)
/// data.emit({'age': 25}); // -> 25
/// ```
///
/// ### Parameters:
/// - [key]: **The Key to Extract.** The field name or index to look up.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The expected type of the extracted value.
///
/// ### Returns:
/// A [FlowInstruction] that extracts a single field.
///
/// ### See Also:
/// - [PluckOr]: For extraction with default values.
/// - [PluckAll]: For extracting multiple fields.
/// - [PluckPath]: For extracting nested fields.
class Pluck<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Single Field Extractor**—a specialized instruction
  /// that extracts and emits a single field from each payload.
  ///
  /// [Pluck] is the fundamental field extraction operator. It reads a
  /// value from each payload using the provided key, type-checks it,
  /// and emits it as a typed pulse.
  ///
  /// ### How it works
  /// 1. **Field Read**: The [_read] helper extracts the value at [key].
  /// 2. **Type Check**: The extracted value must match type [T].
  /// 3. **Step Evolution**: The value is wrapped in a new pulse with
  ///    the step `'Pluck'`.
  /// 4. **Error Handling**: If reading or type-checking fails, [onError]
  ///    is called and the pulse is dropped.
  ///
  /// ### Parameters
  /// - [key]: **The Key.** The field name or index to extract.
  /// - [onError]: **Integrity Handler.** Called if extraction fails or
  ///   the value type doesn't match.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: Simple Field Extractor
  /// ```dart
  /// // Extracts 'name' field as String
  /// final nameExtractor = Pluck<String>(
  ///   'name',
  ///   user: 'Name-Extractor'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [PluckOr]: For extraction with default values.
  /// - [PluckAll]: For extracting multiple fields.
  /// - [PluckPath]: For extracting nested fields.
  Pluck(
      Object key, {
        PluckErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      try {
        final value = _read(pulse.payload, key);
        if (value is! T) {
          throw FormatException(
            'Expected plucked $key of type $T, got ${value.runtimeType}',
          );
        }
        return _out<T>(value, pulse, cell, 'Pluck');
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// PluckOr - Field Extraction with Default
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that extracts a field with a default value
/// (Rx `pluck` + default).
///
/// [PluckOr] is similar to [Pluck] but provides a default value when
/// the field is missing or has the wrong type. This ensures that a
/// value is always emitted.
///
/// ### When to use
/// Use [PluckOr] when you need to extract a field but want to
/// provide a default value on failure.
///
/// - **Optional Fields**: Extracting optional fields with defaults.
/// - **Graceful Degradation**: Providing defaults on missing data.
/// - **Fallback Values**: Using fallback values on errors.
/// - **Data Cleaning**: Cleaning missing data with defaults.
/// - **Default Configuration**: Using default configuration values.
/// - **Safe Extraction**: Ensuring a value is always emitted.
///
/// ### How it works
/// 1. Each incoming pulse's payload is read using [key].
/// 2. If the value exists and matches type [T], it's emitted.
/// 3. If the value is missing or has the wrong type, [orElse] is emitted.
/// 4. The default value always matches type [T].
/// 5. The pulse gets the step `'PluckOr'` (or `'PluckOr.orElse'` for defaults).
///
/// ### Non‑obvious
/// - **Always Emits**: A value is always emitted (success or default).
/// - **Type Safety**: The default must match type [T].
/// - **Error Handling**: Errors are caught and the default is used.
/// - **Provenance Preservation**: Default emissions get the step
///   `'PluckOr.orElse'` to distinguish them.
/// - **Synchronous Extraction**: All extraction is synchronous.
/// - **Null Defaults**: If T is nullable, [orElse] can be null.
///
/// ### Example: Optional Field
/// ```dart
/// final users = Cell.ingress<Map<String, Object>>();
///
/// final cities = PluckOr<String>(
///   'city',
///   orElse: 'Unknown',
/// ).toHandle(source: users.cell);
///
/// users.emit({'id': 1, 'name': 'Alice', 'city': 'NYC'}); // -> NYC
/// users.emit({'id': 2, 'name': 'Bob'});                  // -> Unknown
/// ```
///
/// ### Example: Type Mismatch Fallback
/// ```dart
/// final data = Cell.ingress<Map<String, Object>>();
///
/// final ages = PluckOr<int>(
///   'age',
///   orElse: 0,
/// ).toHandle(source: data.cell);
///
/// data.emit({'id': 1, 'age': 25});     // -> 25
/// data.emit({'id': 2, 'age': 'old'});  // -> 0 (type mismatch)
/// ```
///
/// ### Parameters:
/// - [key]: **The Key to Extract.** The field name or index to look up.
/// - [orElse]: **Default Value.** The value to emit on failure.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The expected type of the extracted value and the default.
///
/// ### Returns:
/// A [FlowInstruction] that extracts a field with a default.
///
/// ### See Also:
/// - [Pluck]: For simple field extraction.
/// - [PluckAll]: For extracting multiple fields.
/// - [PluckPath]: For extracting nested fields.
class PluckOr<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Safe Field Extractor**—a specialized instruction
  /// that extracts a field with a fallback default value.
  ///
  /// [PluckOr] is similar to [Pluck] but provides a default value when
  /// the field is missing or has the wrong type. This ensures that a
  /// value is always emitted, making it ideal for optional fields.
  ///
  /// ### How it works
  /// 1. **Field Read**: The [_read] helper attempts to extract the value.
  /// 2. **Type Check**: If the value exists and matches type [T], it's emitted.
  /// 3. **Default Fallback**: If the value is missing or the type doesn't
  ///    match, [orElse] is emitted.
  /// 4. **Step Evolution**: Success emissions get `'PluckOr'`,
  ///    default emissions get `'PluckOr.orElse'`.
  /// 5. **Error Handling**: Any error is caught and [onError] is called.
  ///
  /// ### Parameters
  /// - [key]: **The Key.** The field name or index to extract.
  /// - [orElse]: **The Default Value.** Emitted on extraction failure.
  /// - [onError]: **Integrity Handler.** Called if extraction fails or
  ///   the value type doesn't match.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: Optional Field Extractor
  /// ```dart
  /// // Extracts 'city' field or uses 'Unknown' if missing
  /// final cityExtractor = PluckOr<String>(
  ///   'city',
  ///   orElse: 'Unknown',
  ///   user: 'City-Extractor'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [Pluck]: For simple field extraction.
  /// - [PluckAll]: For extracting multiple fields.
  /// - [PluckPath]: For extracting nested fields.
  PluckOr(
      Object key, {
        required T orElse,
        PluckErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      try {
        final value = _read(pulse.payload, key);
        if (value is T) {
          return _out<T>(value, pulse, cell, 'PluckOr');
        }
        return _out<T>(orElse, pulse, cell, 'PluckOr.orElse');
      } catch (e, stack) {
        onError?.call(e, stack);
        return _out<T>(orElse, pulse, cell, 'PluckOr.orElse');
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// PluckAll - Multiple Field Extraction
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a [Map] of several extracted keys
/// (Rx several `pluck`s).
///
/// [PluckAll] extracts multiple fields from each payload and returns
/// them as a map. This is useful when you need several fields at once.
///
/// ### When to use
/// Use [PluckAll] when you need to extract multiple fields from a
/// payload.
///
/// - **Data Projection**: Projecting multiple fields from an object.
/// - **Data Transformation**: Creating a subset of fields.
/// - **API Responses**: Extracting specific fields from API responses.
/// - **Data Aggregation**: Aggregating multiple fields.
/// - **View Models**: Creating view models from data.
/// - **Data Normalization**: Normalizing multiple fields at once.
///
/// ### How it works
/// 1. Each incoming pulse's payload is read for each key in [keys].
/// 2. For each key, the value is extracted.
/// 3. If [useOrElse] is `true`, missing keys get [orElse].
/// 4. If [useOrElse] is `false`, missing keys trigger [onError].
/// 5. The collected key-value pairs are emitted as a map.
/// 6. The pulse gets the step `'PluckAll'` for provenance.
///
/// ### Non‑obvious
/// - **Map Output**: The output is always a `Map<Object, Object?>`.
/// - **Partial Success**: Even if some keys fail, successful ones are
///   included in the output.
/// - **Error Handling**: Missing keys can either use defaults or trigger
///   error handlers.
/// - **Provenance Preservation**: The emitted map preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Extraction**: All extraction is synchronous.
/// - **Key Order**: The output map preserves the order of [keys].
///
/// ### Example: Projecting Multiple Fields
/// ```dart
/// final users = Cell.ingress<Map<String, Object>>();
///
/// final projections = PluckAll(['id', 'name', 'email'])
///     .toHandle(source: users.cell);
///
/// users.emit({
///   'id': 1,
///   'name': 'Alice',
///   'email': 'alice@example.com',
///   'extra': 'ignored'
/// });
/// // -> {id: 1, name: Alice, email: alice@example.com}
/// ```
///
/// ### Example: With Default Values
/// ```dart
/// final data = Cell.ingress<Map<String, Object>>();
///
/// final extracted = PluckAll(
///   ['id', 'name', 'age'],
///   orElse: 'unknown',
///   useOrElse: true,
/// ).toHandle(source: data.cell);
///
/// // Missing 'age' gets the default value
/// data.emit({'id': 1, 'name': 'Bob'});
/// // -> {id: 1, name: Bob, age: unknown}
/// ```
///
/// ### Parameters:
/// - [keys]: **The Keys to Extract.** An iterable of field names or indices.
/// - [orElse]: **Default Value.** Used when [useOrElse] is `true`.
/// - [useOrElse]: **Use Default.** If `true`, missing keys get [orElse].
///   If `false`, missing keys trigger [onError]. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Returns:
/// A [FlowInstruction] that extracts multiple fields.
///
/// ### See Also:
/// - [Pluck]: For single field extraction.
/// - [PluckOr]: For single field extraction with default.
/// - [PluckPath]: For nested field extraction.
class PluckAll extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Multi-Field Extractor**—a specialized instruction
  /// that extracts multiple fields from each payload.
  ///
  /// [PluckAll] extracts multiple fields from each payload and returns
  /// them as a map. This is useful when you need several fields at once.
  ///
  /// ### How it works
  /// 1. **Field Iteration**: Each key in [keys] is processed in order.
  /// 2. **Field Extraction**: The [_read] helper extracts the value.
  /// 3. **Error Handling**: If a key fails and [useOrElse] is `true`,
  ///    [orElse] is used. If [useOrElse] is `false`, [onError] is called.
  /// 4. **Map Assembly**: All successful extractions are collected into a map.
  /// 5. **Step Evolution**: The map is emitted with the step `'PluckAll'`.
  ///
  /// ### Parameters
  /// - [keys]: **The Keys.** The field names or indices to extract.
  /// - [orElse]: **The Default Value.** Used when a key is missing.
  /// - [useOrElse]: **Use Default.** If `true`, missing keys use [orElse].
  ///   If `false`, missing keys trigger [onError]. Defaults to `false`.
  /// - [onError]: **Integrity Handler.** Called if a key fails and
  ///   [useOrElse] is `false`.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: View Model Extractor
  /// ```dart
  /// // Extracts fields for a view model
  /// final viewModel = PluckAll(
  ///   ['id', 'name', 'role'],
  ///   orElse: 'unknown',
  ///   useOrElse: true,
  ///   user: 'ViewModel-Extractor'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [Pluck]: For single field extraction.
  /// - [PluckOr]: For single field extraction with default.
  /// - [PluckPath]: For nested field extraction.
  PluckAll(
      Iterable<Object> keys, {
        Object? orElse,
        bool useOrElse = false,
        PluckErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final out = <Object, Object?>{};
      try {
        for (final key in keys) {
          try {
            out[key] = _read(pulse.payload, key);
          } catch (e, stack) {
            if (useOrElse) {
              out[key] = orElse;
            } else {
              onError?.call(e, stack);
            }
          }
        }
        return _out<Map<Object, Object?>>(out, pulse, cell, 'PluckAll');
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// PluckPath - Nested Field Extraction
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that walks a [path] left to right
/// (`pluck('user', 'name')`).
///
/// [PluckPath] navigates nested structures by following a sequence
/// of keys. This allows extracting deeply nested fields from complex
/// objects.
///
/// ### When to use
/// Use [PluckPath] when you need to extract a deeply nested field
/// from a complex object.
///
/// - **Deep Navigation**: Extracting deeply nested values.
/// - **JSON Traversal**: Navigating JSON responses.
/// - **Object Graph**: Traversing object graphs.
/// - **Nested Data**: Extracting data from nested structures.
/// - **Data Unwrapping**: Unwrapping nested data containers.
/// - **API Response Parsing**: Extracting fields from nested API responses.
///
/// ### How it works
/// 1. Each incoming pulse's payload is used as the starting point.
/// 2. For each key in [path], the current value is read using that key.
/// 3. The value becomes the new current value for the next key.
/// 4. After all keys are processed, the final value is emitted.
/// 5. If any step fails, [onError] is called and the pulse is dropped.
/// 6. If [useOrElse] is `true`, [orElse] is emitted on failure.
/// 7. The pulse gets the step `'PluckPath'` (or `'PluckPath.orElse'` for defaults).
///
/// ### Non‑obvious
/// - **Path Traversal**: The path is walked left to right.
/// - **Any Step Failure**: If any step in the path fails, the whole
///   extraction fails.
/// - **Type Safety**: The final value must match type [T].
/// - **Error Handling**: Missing keys or type mismatches can trigger
///   error handlers or fallbacks.
/// - **Provenance Preservation**: The emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Extraction**: All extraction is synchronous.
/// - **Default Path Step**: The default value can be used at any step.
///
/// ### Example: Nested Field
/// ```dart
/// final users = Cell.ingress<Map<String, Object>>();
///
/// final names = PluckPath<String>(['user', 'profile', 'name'])
///     .toHandle(source: users.cell);
///
/// users.emit({
///   'user': {
///     'profile': {
///       'name': 'Alice',
///       'age': 30
///     }
///   }
/// });
/// // -> Alice
/// ```
///
/// ### Example: With Default Value
/// ```dart
/// final data = Cell.ingress<Map<String, Object>>();
///
/// final extracted = PluckPath<String>(
///   ['user', 'profile', 'name'],
///   orElse: 'Unknown',
///   useOrElse: true,
/// ).toHandle(source: data.cell);
///
/// // Missing path uses the default
/// data.emit({'user': {}});
/// // -> Unknown
/// ```
///
/// ### Example: Deep Navigation
/// ```dart
/// final response = Cell.ingress<Map<String, Object>>();
///
/// final data = PluckPath<String>(
///   ['data', 'attributes', 'name'],
///   orElse: 'Not Found',
///   useOrElse: true,
/// ).toHandle(source: response.cell);
///
/// // With default, always emits something
/// ```
///
/// ### Parameters:
/// - [path]: **The Navigation Path.** An iterable of keys to follow.
/// - [orElse]: **Default Value.** Used when [useOrElse] is `true`.
/// - [useOrElse]: **Use Default.** If `true`, missing path steps get
///   [orElse]. If `false`, missing steps trigger [onError]. Defaults
///   to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The expected type of the final extracted value.
///
/// ### Returns:
/// A [FlowInstruction] that extracts nested fields.
///
/// ### See Also:
/// - [Pluck]: For single field extraction.
/// - [PluckOr]: For single field extraction with default.
/// - [PluckAll]: For extracting multiple fields.
class PluckPath<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Nested Field Extractor**—a specialized instruction
  /// that navigates nested structures to extract a deeply nested field.
  ///
  /// [PluckPath] navigates nested structures by following a sequence
  /// of keys. This allows extracting deeply nested fields from complex
  /// objects like JSON responses.
  ///
  /// ### How it works
  /// 1. **Path Navigation**: Starting from the payload, each key in
  ///    [path] is applied in sequence.
  /// 2. **Step Validation**: If any step fails (key not found, wrong
  ///    type), the operation stops.
  /// 3. **Final Extraction**: The value at the end of the path is extracted.
  /// 4. **Type Check**: The final value must match type [T].
  /// 5. **Step Evolution**: Success emissions get `'PluckPath'`,
  ///    default emissions get `'PluckPath.orElse'`.
  /// 6. **Error Handling**: If any step fails and [useOrElse] is `false`,
  ///    [onError] is called and the pulse is dropped.
  ///
  /// ### Parameters
  /// - [path]: **The Navigation Path.** The sequence of keys to follow.
  /// - [orElse]: **The Default Value.** Emitted on navigation failure
  ///   when [useOrElse] is `true`.
  /// - [useOrElse]: **Use Default.** If `true`, navigation failures use
  ///   [orElse]. If `false`, failures trigger [onError]. Defaults to `false`.
  /// - [onError]: **Integrity Handler.** Called if navigation fails and
  ///   [useOrElse] is `false`.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: JSON Path Extractor
  /// ```dart
  /// // Extracts a deeply nested field from JSON
  /// final pathExtractor = PluckPath<String>(
  ///   ['data', 'attributes', 'name'],
  ///   orElse: 'Not Found',
  ///   useOrElse: true,
  ///   user: 'JSON-Extractor'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [Pluck]: For single field extraction.
  /// - [PluckOr]: For single field extraction with default.
  /// - [PluckAll]: For extracting multiple fields.
  PluckPath(
      Iterable<Object> path, {
        T? orElse,
        bool useOrElse = false,
        PluckErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      try {
        Object? current = pulse.payload;
        for (final key in path) {
          current = _read(current, key);
        }
        if (current is T) {
          return _out<T>(current, pulse, cell, 'PluckPath');
        }
        if (useOrElse) {
          return _out<T>(orElse as T, pulse, cell, 'PluckPath.orElse');
        }
        throw FormatException(
          'Expected path $path of type $T, got ${current.runtimeType}',
        );
      } catch (e, stack) {
        onError?.call(e, stack);
        if (useOrElse) {
          return _out<T>(orElse as T, pulse, cell, 'PluckPath.orElse');
        }
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Pluck] instruction and related operators
/// showing their behavior in various field extraction scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Pluck Operators Demo ──────────────────────────────────────
///
/// 1. Pluck
///    [Pluck] Ann
///
/// 2. PluckOr
///    [PluckOr] n/a
///
/// 3. PluckAll
///    [PluckAll] {id: 1, name: Ann}
///
/// 4. PluckPath
///    [PluckPath] Ann
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
/// 1. **Pluck - Single Field**: Shows basic field extraction. The
///    `'name'` field is extracted from the map payload and emitted.
///
/// 2. **PluckOr - Field with Default**: Shows extraction with a
///    default value. The `'city'` field is missing, so the default
///    `'n/a'` is emitted instead.
///
/// 3. **PluckAll - Multiple Fields**: Shows extraction of multiple
///    fields. The `'id'` and `'name'` fields are extracted and
///    returned as a map. The `'extra'` field is ignored.
///
/// 4. **PluckPath - Nested Field**: Shows nested field extraction.
///    The path `['user', 'name']` navigates the nested structure
///    to extract the `'name'` field.
///
/// ### Key Takeaways
/// - Pluck operators extract fields from payloads.
/// - Pluck extracts a single field with type checking.
/// - PluckOr provides a default value on failure.
/// - PluckAll extracts multiple fields as a map.
/// - PluckPath navigates nested structures.
/// - Source payloads can be Maps, Lists, or objects with `[]`.
/// - Missing keys can trigger errors or use defaults.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Choose the right operator for your use case:
///   - Single field → Pluck
///   - Single with default → PluckOr
///   - Multiple fields → PluckAll
///   - Nested field → PluckPath
///
/// ### Note on Source Types
/// Pluck operators support:
/// - `Map` with any key type
/// - `List` with integer keys
/// - `Iterable` with integer keys (converted to List)
/// - Any object with `[]` operator
///
/// ### Note on Type Safety
/// - Pluck requires the extracted value to match type [T].
/// - PluckOr will use the default if the type doesn't match.
/// - PluckPath checks the final value type against [T].
/// - Type mismatches are reported via [onError].
Future<void> main() async {
  print('── Pluck Operators Demo ──────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Pluck - Single Field
  // ─────────────────────────────────────────────────────────────────────
  print('1. Pluck');

  final rows = Cell.ingress<Map<String, Object>>();

  final names = Pluck<String>('name').toHandle(source: rows.cell);

  final nObs = Cell.observe(
    source: names.cell,
    effect: (Pulse p) => print('   [Pluck] ${p.payload}'),
  );

  await rows.emitAsync({'id': 1, 'name': 'Ann'});

  nObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. PluckOr - Field with Default
  // ─────────────────────────────────────────────────────────────────────
  print('2. PluckOr');

  final sparse = Cell.ingress<Map<String, Object>>();

  final city = PluckOr<String>(
    'city',
    orElse: 'n/a',
  ).toHandle(source: sparse.cell);

  final cObs = Cell.observe(
    source: city.cell,
    effect: (Pulse p) => print('   [PluckOr] ${p.payload}'),
  );

  await sparse.emitAsync({'id': 1});

  cObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. PluckAll - Multiple Fields
  // ─────────────────────────────────────────────────────────────────────
  print('3. PluckAll');

  final allIn = Cell.ingress<Map<String, Object>>();

  final picked = PluckAll(['id', 'name']).toHandle(source: allIn.cell);

  final aObs = Cell.observe(
    source: picked.cell,
    effect: (Pulse p) => print('   [PluckAll] ${p.payload}'),
  );

  await allIn.emitAsync({'id': 1, 'name': 'Ann', 'extra': true});

  aObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. PluckPath - Nested Field
  // ─────────────────────────────────────────────────────────────────────
  print('4. PluckPath');

  final nested = Cell.ingress<Map<String, Object>>();

  final deep = PluckPath<String>(['user', 'name']).toHandle(source: nested.cell);

  final pObs = Cell.observe(
    source: deep.cell,
    effect: (Pulse p) => print('   [PluckPath] ${p.payload}'),
  );

  await nested.emitAsync({
    'user': {'name': 'Ann'},
  });

  pObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}