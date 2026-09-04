// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Pluck Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that pick fields out of a payload (Rx `pluck`).
///
/// | Operator | Rx analogue | Result |
/// |---|---|---|
/// | [Pluck] | `pluck(key)` | one field |
/// | [PluckOr] | `pluck` + default | field or [orElse] |
/// | [PluckAll] | several `pluck`s | [Map] of requested keys |
/// | [PluckPath] | `pluck('a', 'b')` | nested walk |
///
/// Source payloads may be a [Map], an [Iterable] (integer keys), or
/// any object with `[]`. Missing keys go to [onError] unless a default
/// is provided.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for pluck operators.
///
/// Called when an error occurs during field extraction, such as
/// missing keys, type mismatches, or path navigation errors.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = PluckErrorHandler((error, stack) {
///   print('Pluck error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef PluckErrorHandler = void Function(Object error, StackTrace? stackTrace);

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
///
/// ### Non‑obvious
/// - **Type Safety**: The extracted value must match type [T].
/// - **Error Handling**: Missing keys or type mismatches drop the pulse.
/// - **Source Types**: Supports Map, List/Iterable, and objects with `[]`.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Extraction**: All extraction is synchronous.
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
///
/// ### Parameters:
/// - [keys]: **The Keys to Extract.** An iterable of field names or indices.
/// - [orElse]: **Default Value.** Used when [useOrElse] is `true`.
/// - [useOrElse]: **Use Default.** If `true`, missing keys get [orElse].
///   If `false`, missing keys trigger [onError]. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload (inferred from context).
///
/// ### Returns:
/// A [FlowInstruction] that extracts multiple fields.
///
/// ### See Also:
/// - [Pluck]: For single field extraction.
/// - [PluckOr]: For single field extraction with default.
/// - [PluckPath]: For nested field extraction.
class PluckAll extends FlowInstructionBase<Cell, Pulse, Pulse> {
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
///
/// ### Note on Source Types
/// Pluck operators support:
/// - `Map` with any key type
/// - `List` with integer keys
/// - `Iterable` with integer keys (converted to List)
/// - Any object with `[]` operator
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