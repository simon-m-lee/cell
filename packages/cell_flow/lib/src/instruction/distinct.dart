// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that suppress repeated values (Rx `distinct` family).
///
/// These operators filter out duplicate values from a stream, either
/// consecutively or globally. They are essential for reducing noise,
/// preventing redundant processing, and ensuring that downstream components
/// only react to new or changed values.
///
/// | Operator | Rx analogue | Drops |
/// |---|---|---|
/// | [DistinctUntilChanged] | `distinctUntilChanged` | consecutive duplicates |
/// | [DistinctUntilKeyChanged] | `distinctUntilKeyChanged` | consecutive equal keys |
/// | [Distinct] | `distinct` | any previously seen value |
/// | [DistinctKey] | `distinct({key})` | any previously seen key |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef DistinctErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse? _typedOrError<S>(
    Pulse pulse, {
      DistinctErrorHandler? onError,
      bool allowNull = false,
    }) {
  final payload = pulse.payload;
  if (payload == null) {
    if (allowNull && null is S) return pulse;
    return null;
  }
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

bool _defaultEquals(Object? a, Object? b) => a == b;

// ─────────────────────────────────────────────────────────────
// Consecutive
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that keeps a pulse only when it differs from the
/// previous emission (Rx `distinctUntilChanged`).
///
/// [DistinctUntilChanged] acts as a **Consecutive Duplicate Filter**. It
/// suppresses consecutive duplicate values while allowing the same value
/// to appear again after a different value.
///
/// ### When to use
/// Use [DistinctUntilChanged] when you need to remove consecutive duplicates:
///
/// - **UI State**: Prevent unnecessary UI rebuilds on identical state
/// - **Sensor Data**: Filter out chattering sensors that repeat the same reading
/// - **User Input**: Remove repeated key presses
/// - **State Changes**: Only emit when state actually changes
/// - **Stream Deduplication**: Reduce noise from consecutive identical values
/// - **Logging**: Reduce log noise from repeated entries
/// - **Caching**: Avoid redundant cache operations
/// - **Network Requests**: Prevent duplicate requests in succession
///
/// ### Choosing Between Distinct Patterns
/// - **Use [DistinctUntilChanged]** for **Consecutive Duplicates**: When you
///   only care about removing back-to-back duplicates.
/// - **Use [DistinctUntilKeyChanged]** for **Consecutive Key Duplicates**: When
///   you want to deduplicate based on a key extracted from the value.
/// - **Use [Distinct]** for **Global Duplicates**: When you want to remove
///   any value that has ever been seen.
/// - **Use [DistinctKey]** for **Global Key Duplicates**: When you want to
///   deduplicate based on a key globally.
///
/// ### Comparison with Other Operators
/// | Operator | Scope | Comparison | Memory |
/// |----------|-------|------------|--------|
/// | **DistinctUntilChanged** | Consecutive | Full value | O(1) |
/// | **DistinctUntilKeyChanged** | Consecutive | Key | O(1) |
/// | **Distinct** | Global | Full value | O(n) |
/// | **DistinctKey** | Global | Key | O(n) |
/// | **Filter** | Per value | Predicate | O(1) |
///
/// ### How it works
/// 1. The first typed pulse always passes through.
/// 2. Later pulses are compared to the last **emitted** value using [equals].
/// 3. Equal pulses are dropped; a different value updates the memory.
/// 4. Values that fail the type check never update the previous slot.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Consecutive Only**: Only back-to-back duplicates are suppressed.
///   A sequence `1, 2, 1` will emit three times.
/// - **Initial Emission**: The first pulse is always allowed as there is
///   no previous value for comparison.
/// - **Custom Comparator**: Providing an [equals] function allows for deep
///   equality, case-insensitive comparison, or numeric tolerance bands.
/// - **State Persistence**: The instruction maintains the previous value
///   across multiple inputs.
/// - **Memory Efficiency**: Only the previous value is stored (O(1) memory).
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Composability**: Can be chained with other operators.
///
/// ### Example: Unique Consecutive Values
/// ```dart
/// final ticks = Cell.ingress<int>();
/// final changed = DistinctUntilChanged<int>().toHandle(source: ticks.cell);
///
/// ticks.emit(1); // passes through
/// ticks.emit(1); // dropped (duplicate)
/// ticks.emit(2); // passes through
/// ticks.emit(2); // dropped (duplicate)
/// ticks.emit(1); // passes through (different from previous)
/// // Result: [1, 2, 1]
/// ```
///
/// ### Example: Case-Insensitive Names
/// ```dart
/// final names = Cell.ingress<String>();
/// final uniqueNames = DistinctUntilChanged<String>(
///   equals: (a, b) => a.toLowerCase() == b.toLowerCase()
/// ).toHandle(source: names.cell);
///
/// names.emit('Alice'); // passes through
/// names.emit('alice'); // dropped (case-insensitive)
/// names.emit('Bob');   // passes through
/// ```
///
/// ### Example: Numeric Tolerance
/// ```dart
/// final readings = Cell.ingress<double>();
/// val stable = DistinctUntilChanged<double>(
///   equals: (a, b) => (a - b).abs() < 0.01
/// ).toHandle(source: readings.cell);
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
/// - [DistinctUntilKeyChanged]: For deduplication by key.
/// - [Distinct]: For global deduplication.
/// - [DistinctKey]: For global key-based deduplication.
class DistinctUntilChanged<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [DistinctUntilChanged] instruction.
  ///
  /// ### Parameters:
  /// - [equals]: **Custom Equality Comparator.** Optional function that
  ///   defines what constitutes a duplicate. Defaults to `==`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final distinctUntilChanged = DistinctUntilChanged<String>(
  ///   equals: (a, b) => a.toLowerCase() == b.toLowerCase(),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  DistinctUntilChanged({
    bool Function(S previous, S next)? equals,
    DistinctErrorHandler? onError,
    dynamic user,
  }) : super(
    (() {
      final state = _ConsecutiveState<S>();
      final cmp = equals ?? (S a, S b) => _defaultEquals(a, b);
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final value = typed.payload as S;
        if (state.hasPrevious) {
          try {
            if (cmp(state.previous as S, value)) return null;
          } catch (e, stack) {
            onError?.call(e, stack);
            return null;
          }
        }
        state.previous = value;
        state.hasPrevious = true;
        return _mark(typed, 'DistinctUntilChanged');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// DistinctUntilKeyChanged
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that deduplicates consecutively by key
/// (Rx `distinctUntilKeyChanged`).
///
/// [DistinctUntilKeyChanged] acts as a **Consecutive Key-Based Duplicate Filter**.
/// Only the key is compared for deduplication. The original payload is
/// forwarded when the key changes.
///
/// ### When to use
/// Use [DistinctUntilKeyChanged] when:
/// - You want to deduplicate based on a property of the value
/// - The payload contains mutable data but a stable identifier
/// - You're tracking entities by ID
/// - You're filtering by a computed key
/// - You're comparing objects by a subset of their properties
/// - You're implementing change detection on specific fields
///
/// ### How it works
/// 1. The first typed pulse always passes through.
/// 2. For each pulse, the [keyOf] function extracts a key from the payload.
/// 3. The key is compared to the previous key using [equals].
/// 4. If the keys are equal, the pulse is dropped.
/// 5. If the keys differ, the pulse passes through and the key is updated.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Key-Based**: Only the key is compared, not the full payload.
/// - **Consecutive Only**: Only back-to-back key duplicates are suppressed.
/// - **Payload Preserved**: The original payload is forwarded, not the key.
/// - **State Persistence**: The instruction maintains the previous key.
/// - **Memory Efficiency**: Only the previous key is stored (O(1) memory).
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Composability**: Can be chained with other operators.
///
/// ### Example: By ID
/// ```dart
/// final users = Cell.ingress<{int id, String name}>();
/// val uniqueUsers = DistinctUntilKeyChanged<{int id, String name}, int>(
///   keyOf: (u) => u.id
/// ).toHandle(source: users.cell);
///
/// users.emit({id: 1, name: 'Alice'}); // passes through
/// users.emit({id: 1, name: 'Alicia'}); // dropped (same id)
/// users.emit({id: 2, name: 'Bob'});   // passes through
/// ```
///
/// ### Example: Case-Insensitive Name
/// ```dart
/// final names = Cell.ingress<String>();
/// val uniqueNames = DistinctUntilKeyChanged<String, String>(
///   keyOf: (s) => s.toLowerCase()
/// ).toHandle(source: names.cell);
///
/// names.emit('Alice'); // passes through
/// names.emit('alice'); // dropped (same key)
/// names.emit('Bob');   // passes through
/// ```
///
/// ### Parameters:
/// - [keyOf]: **Key Extractor.** Takes the payload and returns a key for
///   comparison.
/// - [equals]: **Custom Equality Comparator.** Optional function that
///   defines what constitutes a duplicate key. Defaults to `==`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [K]: The type of the key used for comparison.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [DistinctUntilChanged]: For full value deduplication.
/// - [DistinctKey]: For global key-based deduplication.
class DistinctUntilKeyChanged<S, K> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [DistinctUntilKeyChanged] instruction.
  ///
  /// ### Parameters:
  /// - [keyOf]: **Key Extractor.** Takes the payload and returns a key for
  ///   comparison.
  /// - [equals]: **Custom Equality Comparator.** Optional function that
  ///   defines what constitutes a duplicate key. Defaults to `==`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final distinctUntilKey = DistinctUntilKeyChanged<{int id, String name}, int>(
  ///   keyOf: (u) => u.id,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  DistinctUntilKeyChanged(
      K Function(S value) keyOf, {
        bool Function(K previous, K next)? equals,
        DistinctErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final state = _ConsecutiveState<K>();
      final cmp = equals ?? (K a, K b) => _defaultEquals(a, b);
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final value = typed.payload as S;
        late final K key;
        try {
          key = keyOf(value);
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        if (state.hasPrevious) {
          try {
            if (cmp(state.previous as K, key)) return null;
          } catch (e, stack) {
            onError?.call(e, stack);
            return null;
          }
        }
        state.previous = key;
        state.hasPrevious = true;
        return _mark(typed, 'DistinctUntilKeyChanged');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Global (seen-set)
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that drops a value if it has ever been emitted
/// (Rx `distinct`).
///
/// [Distinct] acts as a **Global Duplicate Filter**. It keeps track of all
/// values that have ever been emitted and drops any value that has been seen
/// before, regardless of position.
///
/// ### When to use
/// Use [Distinct] when:
/// - You need to ensure each value is emitted only once
/// - You're processing unique items from a stream
/// - You're implementing a set-like deduplication
/// - You're removing all duplicates, not just consecutive ones
/// - You're processing a stream where values may repeat non-consecutively
/// - You're implementing a unique-event tracker
/// - You're deduplicating a stream of IDs
/// - You're processing a stream with a known finite set of values
///
/// ### How it works
/// 1. Each typed pulse's payload is extracted.
/// 2. The payload is compared to all previously seen values using [equals].
/// 3. If a match is found, the pulse is dropped.
/// 4. If no match is found, the pulse passes through and the value is stored.
/// 5. The instruction preserves causal provenance.
///
/// ### Memory Considerations
/// - **O(n) Memory**: The instruction stores all seen values in a list.
/// - **Unbounded Growth**: Memory grows with the number of unique values.
/// - **Use [DistinctUntilChanged]** when only consecutive repeats matter
///   to avoid unbounded memory growth.
///
/// ### Non‑obvious
/// - **Global Scope**: Any previously seen value is dropped, even if it
///   appeared long ago.
/// - **Memory Growth**: The instruction stores all seen values, so memory
///   grows with the number of unique values.
/// - **Custom Comparator**: Providing an [equals] function allows for
///   custom comparison logic.
/// - **State Persistence**: The instruction maintains a list of all seen values.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Composability**: Can be chained with other operators.
///
/// ### Example: Unique Values
/// ```dart
/// final nums = Cell.ingress<int>();
/// val unique = Distinct<int>().toHandle(source: nums.cell);
///
/// nums.emit(1); // passes through (first time)
/// nums.emit(2); // passes through (first time)
/// nums.emit(1); // dropped (seen before)
/// nums.emit(3); // passes through (first time)
/// nums.emit(2); // dropped (seen before)
/// // Result: [1, 2, 3]
/// ```
///
/// ### Example: Unique Strings (Case-Insensitive)
/// ```dart
/// final words = Cell.ingress<String>();
/// val unique = Distinct<String>(
///   equals: (a, b) => a.toLowerCase() == b.toLowerCase()
/// ).toHandle(source: words.cell);
///
/// words.emit('Hello'); // passes through
/// words.emit('hello'); // dropped (case-insensitive)
/// words.emit('World'); // passes through
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
/// - [DistinctUntilChanged]: For consecutive-only deduplication (O(1) memory).
/// - [DistinctKey]: For global key-based deduplication.
/// - [DistinctUntilKeyChanged]: For consecutive key-based deduplication.
class Distinct<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [Distinct] instruction.
  ///
  /// ### Parameters:
  /// - [equals]: **Custom Equality Comparator.** Optional function that
  ///   defines what constitutes a duplicate. Defaults to `==`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final distinct = Distinct<String>(
  ///   equals: (a, b) => a.toLowerCase() == b.toLowerCase(),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  Distinct({
    bool Function(S previous, S next)? equals,
    DistinctErrorHandler? onError,
    dynamic user,
  }) : super(
    (() {
      final seen = <S>[];
      final cmp = equals ?? (S a, S b) => _defaultEquals(a, b);
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final value = typed.payload as S;
        try {
          for (final prior in seen) {
            if (cmp(prior, value)) return null;
          }
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        seen.add(value);
        return _mark(typed, 'Distinct');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// DistinctKey
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that deduplicates globally by key
/// (Rx `distinct({ key: ... })`).
///
/// [DistinctKey] acts as a **Global Key-Based Duplicate Filter**. The first
/// payload for each key passes; later payloads with the same key are dropped
/// even if they are not consecutive.
///
/// ### When to use
/// Use [DistinctKey] when:
/// - You want to ensure each key is emitted only once
/// - You're processing unique entities by ID
/// - You're implementing a set-like deduplication by key
/// - You're removing duplicates based on a property
/// - You're tracking unique items in a stream
/// - You're processing a stream where keys may repeat non-consecutively
/// - You're implementing a unique-event tracker by category
///
/// ### How it works
/// 1. Each typed pulse's payload is extracted.
/// 2. The [keyOf] function extracts a key from the payload.
/// 3. The key is checked against a set of seen keys.
/// 4. If the key is new, the pulse passes through and the key is stored.
/// 5. If the key has been seen before, the pulse is dropped.
/// 6. The instruction preserves causal provenance.
///
/// ### Memory Considerations
/// - **O(n) Memory**: The instruction stores all seen keys in a set.
/// - **Unbounded Growth**: Memory grows with the number of unique keys.
/// - **Use [DistinctUntilKeyChanged]** when only consecutive repeats matter
///   to avoid unbounded memory growth.
///
/// ### Non‑obvious
/// - **Global Scope**: Any previously seen key is dropped, even if it
///   appeared long ago.
/// - **Key-Based**: Only the key is compared, not the full payload.
/// - **Payload Preserved**: The original payload is forwarded, not the key.
/// - **Memory Growth**: The instruction stores all seen keys in a set.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Composability**: Can be chained with other operators.
///
/// ### Example: First Record per ID
/// ```dart
/// final records = Cell.ingress<{int id, String name}>();
/// final first = DistinctKey<{int id, String name}, int>(
///   keyOf: (r) => r.id
/// ).toHandle(source: records.cell);
///
/// records.emit({id: 1, name: 'Ann'});   // passes through
/// records.emit({id: 1, name: 'Ann-2'}); // dropped (same id)
/// records.emit({id: 2, name: 'Bea'});   // passes through
/// // Result: [{id: 1, name: 'Ann'}, {id: 2, name: 'Bea'}]
/// ```
///
/// ### Example: First Email per Domain
/// ```dart
/// final emails = Cell.ingress<String>();
/// val firstPerDomain = DistinctKey<String, String>(
///   keyOf: (email) => email.split('@').last
/// ).toHandle(source: emails.cell);
///
/// emails.emit('alice@gmail.com'); // passes through (gmail)
/// emails.emit('bob@gmail.com');   // dropped (gmail seen)
/// emails.emit('charlie@yahoo.com'); // passes through (yahoo)
/// ```
///
/// ### Parameters:
/// - [keyOf]: **Key Extractor.** Takes the payload and returns a key for
///   deduplication.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [K]: The type of the key used for deduplication.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Distinct]: For global full-value deduplication.
/// - [DistinctUntilKeyChanged]: For consecutive key-based deduplication.
/// - [DistinctUntilChanged]: For consecutive full-value deduplication.
class DistinctKey<S, K> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [DistinctKey] instruction.
  ///
  /// ### Parameters:
  /// - [keyOf]: **Key Extractor.** Takes the payload and returns a key for
  ///   deduplication.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final distinctKey = DistinctKey<{int id, String name}, int>(
  ///   keyOf: (r) => r.id,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  DistinctKey(
      K Function(S value) keyOf, {
        DistinctErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final seen = <K>{};
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final value = typed.payload as S;
        late final K key;
        try {
          key = keyOf(value);
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        if (!seen.add(key)) return null;
        return _mark(typed, 'DistinctKey');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

/// Internal state for [DistinctUntilChanged] and [DistinctUntilKeyChanged].
class _ConsecutiveState<T> {
  T? previous;
  bool hasPrevious = false;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Distinct] instruction and related operators
/// showing their behavior in various deduplication scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Distinct Operators Demo ───────────────────────────────────
///
/// 1. DistinctUntilChanged - consecutive only
///    [UntilChanged] 1
///    [UntilChanged] 2
///    [UntilChanged] 1
///
/// 2. DistinctUntilKeyChanged - by lowercased name
///    [UntilKey] Alice
///    [UntilKey] Bob
///
/// 3. Distinct - ever seen
///    [Distinct] 1
///    [Distinct] 2
///    [Distinct] 3
///
/// 4. DistinctKey - first record per id
///    [DistinctKey] {id: 1, name: Ann}
///    [DistinctKey] {id: 2, name: Bea}
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
/// 1. **DistinctUntilChanged - consecutive only**: Shows consecutive
///    deduplication. Only back-to-back duplicates are dropped.
///    `1, 1, 2, 2, 1` becomes `1, 2, 1`.
///
/// 2. **DistinctUntilKeyChanged - by lowercased name**: Shows consecutive
///    key-based deduplication. The key is extracted and compared.
///    `Alice, alice, Bob` becomes `Alice, Bob`.
///
/// 3. **Distinct - ever seen**: Shows global deduplication. Any value
///    seen before is dropped, regardless of position.
///    `1, 2, 1, 3, 2, 1` becomes `1, 2, 3`.
///
/// 4. **DistinctKey - first record per id**: Shows global key-based
///    deduplication. The first record for each ID passes; later records
///    with the same ID are dropped.
///
/// ### Key Takeaways
/// - DistinctUntilChanged keeps O(1) memory but only filters consecutive.
/// - Distinct keeps O(n) memory but filters globally.
/// - Key-based operators compare a key instead of the full value.
/// - Custom comparators allow flexible equality logic.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Choose the right operator based on memory and scope requirements.
Future<void> main() async {
  print('── Distinct Operators Demo ───────────────────────────────────\n');

  print('1. DistinctUntilChanged - consecutive only');
  final ticks = Cell.ingress<int>();
  final changed = DistinctUntilChanged<int>().toHandle(source: ticks.cell);
  final cObs = Cell.observe(
    source: changed.cell,
    effect: (Pulse p) => print('   [UntilChanged] ${p.payload}'),
  );
  for (final n in [1, 1, 2, 2, 1]) {
    await ticks.emitAsync(n);
  }
  await Future<void>.delayed(const Duration(milliseconds: 20));
  cObs.stop();
  print('');

  print('2. DistinctUntilKeyChanged - by lowercased name');
  final names = Cell.ingress<String>();
  final byKey = DistinctUntilKeyChanged<String, String>((s) => s.toLowerCase())
      .toHandle(source: names.cell);
  final kObs = Cell.observe(
    source: byKey.cell,
    effect: (Pulse p) => print('   [UntilKey] ${p.payload}'),
  );
  await names.emitAsync('Alice');
  await names.emitAsync('alice');
  await names.emitAsync('Bob');
  await Future<void>.delayed(const Duration(milliseconds: 20));
  kObs.stop();
  print('');

  print('3. Distinct - ever seen');
  final nums = Cell.ingress<int>();
  final unique = Distinct<int>().toHandle(source: nums.cell);
  final uObs = Cell.observe(
    source: unique.cell,
    effect: (Pulse p) => print('   [Distinct] ${p.payload}'),
  );
  for (final n in [1, 2, 1, 3, 2, 1]) {
    await nums.emitAsync(n);
  }
  await Future<void>.delayed(const Duration(milliseconds: 20));
  uObs.stop();
  print('');

  print('4. DistinctKey - first record per id');
  final rows = Cell.ingress<Map<String, Object>>();
  final first = DistinctKey<Map<String, Object>, Object>((m) => m['id']!)
      .toHandle(source: rows.cell);
  final fObs = Cell.observe(
    source: first.cell,
    effect: (Pulse p) => print('   [DistinctKey] ${p.payload}'),
  );
  await rows.emitAsync({'id': 1, 'name': 'Ann'});
  await rows.emitAsync({'id': 1, 'name': 'Ann-2'});
  await rows.emitAsync({'id': 2, 'name': 'Bea'});
  await Future<void>.delayed(const Duration(milliseconds: 20));
  fObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}