// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Partition Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that split a stream on a predicate
/// (Rx `partition` family).
///
/// All of them emit on **one** downstream cell. They do not fork the
/// graph into two Cells; bind two instructions if you need two sinks.
///
/// | Operator | Emits |
/// |---|---|
/// | [Partition] | [Split] `{matched, value}` |
/// | [PartitionMap] | `thenMap` / `elseMap` result |
/// | [PartitionCollect] | running `{matched: [...], other: [...]}` |
/// | [PartitionOnly] | value only when [test] matches |
///
/// [PartitionTag] in `routing.dart` is the same shape as [Partition].
/// Prefer this file for the partition family.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for partition operators.
///
/// Called when an error occurs during predicate evaluation.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = PartitionErrorHandler((error, stack) {
///   print('Partition error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef PartitionErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// One item tagged with whether it matched the predicate.
///
/// [Split] is a simple record that pairs a value with a boolean
/// indicating whether it matched the predicate. It's the output of
/// the [Partition] operator.
///
/// ### When to use
/// Use [Split] when you need to know whether a value matched the
/// predicate while preserving the original value. It's created
/// automatically by [Partition] and emitted as a pulse payload.
///
/// ### How it works
/// 1. [matched] is `true` if the value passed the predicate.
/// 2. [value] is the original payload.
/// 3. The combination preserves both the result and the original value.
///
/// ### Non‑obvious
/// - **Immutable**: [Split] is immutable.
/// - **Type Safety**: Generic over value type [S].
/// - **Equality**: Implements `==` and `hashCode` for value equality.
/// - **String Representation**: Provides a readable `toString()`.
///
/// ### Example: Accessing Split Values
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final partitioned = Partition<int>(
///   (n) => n.isEven,
/// ).toHandle(source: input.cell);
///
/// Cell.observe(
///   source: partitioned.cell,
///   effect: (Pulse<Split<int>> p) {
///     final split = p.payload;
///     if (split.matched) {
///       print('Even: ${split.value}');
///     } else {
///       print('Odd: ${split.value}');
///     }
///   },
/// );
/// ```
///
/// ### Type Parameters:
/// - [S]: The type of the value.
///
/// ### See Also:
/// - [Partition]: The operator that produces Split values.
class Split<S> {
  /// Creates a [Split] record with the given [matched] status and [value].
  const Split({required this.matched, required this.value});

  /// Whether the value matched the predicate.
  final bool matched;

  /// The original value.
  final S value;

  @override
  String toString() => 'Split(matched: $matched, value: $value)';

  @override
  bool operator ==(Object other) =>
      other is Split<S> && other.matched == matched && other.value == value;

  @override
  int get hashCode => Object.hash(matched, value);
}

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
      PartitionErrorHandler? onError,
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
// Partition - Tag Each Item with Match Status
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that tags each typed payload with its match
/// status (Rx `partition` flattened).
///
/// [Partition] transforms each value into a [Split] record containing
/// both the original value and a boolean indicating whether it passed
/// the predicate. This allows downstream operators to process values
/// with their match context.
///
/// ### When to use
/// Use [Partition] when you need to tag values with match information
/// without separating them.
///
/// - **Categorization**: Tagging items as matching or not.
/// - **Match Context**: Preserving match information for downstream.
/// - **Conditional Processing**: Processing based on match status.
/// - **Classification**: Classifying items into two categories.
/// - **Filtering by Status**: Filtering based on match status.
///
/// ### Choosing Between Partition Variants
/// - **Use [Partition]** for **Tagging**: When you just need to tag
///   each value with its match status.
/// - **Use [PartitionMap]** for **Mapping**: When you need to map
///   matched and unmatched values differently.
/// - **Use [PartitionCollect]** for **Accumulation**: When you need
///   to collect values into matched/unmatched lists.
/// - **Use [PartitionOnly]** for **Filtering**: When you only want
///   matched (or unmatched) values.
///
/// ### Comparison with Other Operators
/// | Operator | Output | State | Emits Per Item |
/// |----------|--------|-------|----------------|
/// | **Partition** | `Split<S>` | No | Yes |
/// | **PartitionMap** | `T` | No | Yes |
/// | **PartitionCollect** | `Map<String, List<S>>` | Yes (lists) | Yes |
/// | **PartitionOnly** | `S` | No | Only matches |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [test] is called with the payload.
/// 3. The result and value are wrapped in a [Split] record.
/// 4. The [Split] record is emitted.
/// 5. If [test] throws an error, the pulse is dropped.
/// 6. The emitted pulse gets the step `'Partition'` for provenance.
///
/// ### Non‑obvious
/// - **No State**: No state is maintained between pulses.
/// - **Per-Item Emit**: Emits one [Split] for each input.
/// - **Predicate Evaluation**: [test] is called for each value.
/// - **Type Safety**: Generic over value type [S].
/// - **Error Handling**: If [test] throws, the pulse is dropped.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Predicate**: [test] is synchronous.
///
/// ### Example: Partitioning by Parity
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final partitioned = Partition<int>(
///   (n) => n.isEven,
/// ).toHandle(source: input.cell);
///
/// input.emit(1); // -> Split(matched: false, value: 1)
/// input.emit(2); // -> Split(matched: true, value: 2)
/// input.emit(3); // -> Split(matched: false, value: 3)
/// ```
///
/// ### Example: Partitioning by Length
/// ```dart
/// final words = Cell.ingress<String>();
///
/// final longWords = Partition<String>(
///   (word) => word.length > 5,
/// ).toHandle(source: words.cell);
///
/// words.emit('hello');   // -> Split(matched: false, value: hello)
/// words.emit('world');   // -> Split(matched: false, value: world)
/// words.emit('banana');  // -> Split(matched: true, value: banana)
/// ```
///
/// ### Parameters:
/// - [test]: **Predicate Function.** Called with each typed payload,
///   returns `true` if the value matches the condition.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
///
/// ### Returns:
/// A [FlowInstruction] that tags each value with its match status.
///
/// ### See Also:
/// - [PartitionMap]: For mapping matched/unmatched values differently.
/// - [PartitionCollect]: For collecting values by match status.
/// - [PartitionOnly]: For filtering by match status.
/// - [Split]: The record type emitted.
class Partition<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Partition(
      bool Function(S value) test, {
        PartitionErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      try {
        final value = typed.payload as S;
        return _out<Split<S>>(
          Split(matched: test(value), value: value),
          typed,
          cell,
          'Partition',
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
// PartitionMap - Different Mapping for Each Side
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that projects matched and unmatched values
/// with different mappers (Rx `partition` + `map` on each side).
///
/// [PartitionMap] is similar to [Partition] but instead of emitting
/// a [Split] record, it applies different mapping functions to
/// matched and unmatched values.
///
/// ### When to use
/// Use [PartitionMap] when you need to transform matched and
/// unmatched values differently.
///
/// - **Conditional Formatting**: Formatting values based on predicate.
/// - **Different Processing**: Processing matched/unmatched differently.
/// - **Type Conversion**: Converting to different types based on status.
/// - **Labeling**: Labeling values based on match status.
/// - **Data Enrichment**: Enriching values differently based on status.
///
/// ### Example: Conditional Labeling
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final labeled = PartitionMap<int, String>(
///   (n) => n.isEven,
///   thenMap: (n) => 'even-$n',
///   elseMap: (n) => 'odd-$n',
/// ).toHandle(source: input.cell);
///
/// input.emit(1); // -> odd-1
/// input.emit(2); // -> even-2
/// ```
///
/// ### Example: Conditional Processing
/// ```dart
/// final data = Cell.ingress<Data>();
///
/// final processed = PartitionMap<Data, Result>(
///   (data) => data.isValid,
///   thenMap: (data) => processValid(data),
///   elseMap: (data) => processInvalid(data),
/// ).toHandle(source: data.cell);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [test] is called with the payload.
/// 3. If [test] returns `true`, [thenMap] is called with the value.
/// 4. If [test] returns `false`, [elseMap] is called with the value.
/// 5. The result is emitted.
/// 6. If [test], [thenMap], or [elseMap] throws, the pulse is dropped.
/// 7. The emitted pulse gets the step `'PartitionMap.then'` or
///    `'PartitionMap.else'` for provenance.
///
/// ### Non‑obvious
/// - **No State**: No state is maintained between pulses.
/// - **Per-Item Emit**: Emits one value for each input.
/// - **Different Mappers**: Two different mapping functions.
/// - **Type Safety**: Generic over value type [S] and output type [T].
/// - **Error Handling**: If any function throws, the pulse is dropped.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Operations**: All functions are synchronous.
///
/// ### Parameters:
/// - [test]: **Predicate Function.** Called with each typed payload,
///   returns `true` for matched values.
/// - [thenMap]: **Matched Mapper.** Called with values where [test]
///   returns `true`.
/// - [elseMap]: **Unmatched Mapper.** Called with values where [test]
///   returns `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maps matched/unmatched values differently.
///
/// ### See Also:
/// - [Partition]: For tagging values with match status.
/// - [PartitionCollect]: For collecting values by match status.
/// - [PartitionOnly]: For filtering by match status.
/// - [MapValue]: For simple mapping without partitioning.
class PartitionMap<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  PartitionMap(
      bool Function(S value) test, {
        required T Function(S value) thenMap,
        required T Function(S value) elseMap,
        PartitionErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      final value = typed.payload as S;
      try {
        final matched = test(value);
        final result = matched ? thenMap(value) : elseMap(value);
        return _out<T>(
          result,
          typed,
          cell,
          matched ? 'PartitionMap.then' : 'PartitionMap.else',
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
// PartitionCollect - Accumulate Matched and Unmatched
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits running lists of matched and
/// unmatched values.
///
/// [PartitionCollect] accumulates values into two lists: one for
/// matched values and one for unmatched values. It emits the complete
/// map after every pulse.
///
/// ### When to use
/// Use [PartitionCollect] when you need a running snapshot of all
/// partitioned values.
///
/// - **Real-time Dashboard**: Showing matched/unmatched counts.
/// - **Aggregation**: Aggregating values by match status.
/// - **State Monitoring**: Monitoring partitioned state.
/// - **Caching**: Maintaining caches of matched/unmatched values.
/// - **Batch Processing**: Processing batches by match status.
/// - **Reporting**: Generating reports on partitioned data.
///
/// ### Example: Running Partition Snapshot
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final collected = PartitionCollect<int>(
///   (n) => n.isEven,
/// ).toHandle(source: input.cell);
///
/// input.emit(1); // -> {matched: [], other: [1]}
/// input.emit(2); // -> {matched: [2], other: [1]}
/// input.emit(3); // -> {matched: [2], other: [1, 3]}
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [test] is called with the payload.
/// 3. The value is added to the appropriate list.
/// 4. The current lists are emitted as a map.
/// 5. If [test] throws an error, the pulse is dropped.
/// 6. The emitted pulse gets the step `'PartitionCollect'` for provenance.
///
/// ### Non‑obvious
/// - **Stateful**: Maintains two lists of all values.
/// - **Running Snapshot**: Emits the complete lists after every pulse.
/// - **Snapshot Copy**: The emitted lists are copies (not the internal lists).
/// - **Monotonic Growth**: Lists only grow; values are never removed.
/// - **External Access**: The [matched] and [other] lists can be accessed
///   externally.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Predicate**: [test] is synchronous.
///
/// ### Parameters:
/// - [test]: **Predicate Function.** Called with each typed payload,
///   returns `true` for matched values.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
///
/// ### Returns:
/// A [FlowInstruction] that accumulates values by match status.
///
/// ### See Also:
/// - [Partition]: For tagging values with match status.
/// - [PartitionMap]: For mapping matched/unmatched values differently.
/// - [PartitionOnly]: For filtering by match status.
/// - [GroupCollect]: For grouping by arbitrary keys.
class PartitionCollect<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  PartitionCollect(
      bool Function(S value) test, {
        PartitionErrorHandler? onError,
        dynamic user,
      }) : this._(test, <S>[], <S>[], onError, user);

  PartitionCollect._(
      bool Function(S value) test,
      this.matched,
      this.other,
      PartitionErrorHandler? onError,
      dynamic user,
      ) : super(
    (() {
      final yes = matched;
      final no = other;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        try {
          final value = typed.payload as S;
          if (test(value)) {
            yes.add(value);
          } else {
            no.add(value);
          }
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        return _out<Map<String, List<S>>>(
          {
            'matched': List<S>.from(yes),
            'other': List<S>.from(no),
          },
          typed,
          cell,
          'PartitionCollect',
        );
      };
    })(),
    user: user,
  );

  /// The list of matched values.
  final List<S> matched;

  /// The list of unmatched values.
  final List<S> other;
}

// ─────────────────────────────────────────────────────────────
// PartitionOnly - Filter by Match Status
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits the original value only when
/// [test] matches (drop the rest).
///
/// [PartitionOnly] is a filtering operator that only passes values
/// that match the predicate. It's similar to [Valve] but specialized
/// for partition-style filtering.
///
/// ### When to use
/// Use [PartitionOnly] when you only want values that match (or don't
/// match) a predicate.
///
/// - **Filtering**: Filtering values by a condition.
/// - **Positive Filtering**: Keeping only matching values.
/// - **Negative Filtering**: Keeping only non-matching values.
/// - **Validation**: Passing only valid values.
/// - **Data Cleaning**: Keeping only clean data.
///
/// ### Example: Only Even Numbers
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final evens = PartitionOnly<int>(
///   (n) => n.isEven,
/// ).toHandle(source: input.cell);
///
/// input.emit(1); // dropped
/// input.emit(2); // -> 2
/// input.emit(3); // dropped
/// input.emit(4); // -> 4
/// ```
///
/// ### Example: Only Non-Empty Strings
/// ```dart
/// final input = Cell.ingress<String>();
///
/// final nonEmpty = PartitionOnly<String>(
///   (s) => s.isNotEmpty,
/// ).toHandle(source: input.cell);
///
/// input.emit('');     // dropped
/// input.emit('hello'); // -> hello
/// ```
///
/// ### Example: Filter by Inverse
/// ```dart
/// final input = Cell.ingress<int>();
///
/// // Keep only odd numbers
/// final odds = PartitionOnly<int>(
///   (n) => n.isEven,
///   matched: false, // Keep values that don't match
/// ).toHandle(source: input.cell);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [test] is called with the payload.
/// 3. If [test] returns [matched] (default `true`), the value is emitted.
/// 4. If [test] returns the opposite, the value is dropped.
/// 5. If [test] throws an error, the pulse is dropped.
/// 6. The emitted pulse gets the step `'PartitionOnly'` for provenance.
///
/// ### Non‑obvious
/// - **No State**: No state is maintained between pulses.
/// - **Filtering**: Only values matching the condition are emitted.
/// - **Inverse Filtering**: With [matched] `false`, keeps non-matching values.
/// - **Type Safety**: Generic over value type [S].
/// - **Error Handling**: If [test] throws, the pulse is dropped.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Predicate**: [test] is synchronous.
///
/// ### Parameters:
/// - [test]: **Predicate Function.** Called with each typed payload,
///   returns `true` for values to be considered.
/// - [matched]: **Filter Mode.** If `true`, keeps values where [test]
///   returns `true`. If `false`, keeps values where [test] returns
///   `false`. Defaults to `true`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
///
/// ### Returns:
/// A [FlowInstruction] that filters by match status.
///
/// ### See Also:
/// - [Partition]: For tagging values with match status.
/// - [PartitionMap]: For mapping matched/unmatched values differently.
/// - [PartitionCollect]: For collecting values by match status.
/// - [Valve]: For general-purpose filtering.
class PartitionOnly<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  PartitionOnly(
      bool Function(S value) test, {
        bool matched = true,
        PartitionErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      try {
        final value = typed.payload as S;
        if (test(value) != matched) return null;
        return typed.withStep('PartitionOnly');
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

/// A demonstration of the [Partition] instruction and related operators
/// showing their behavior in various partitioning scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Partition Operators Demo ──────────────────────────────────
///
/// 1. Partition
///    [Partition] Split(matched: false, value: 1)
///    [Partition] Split(matched: true, value: 2)
///
/// 2. PartitionMap
///    [PartitionMap] odd-1
///    [PartitionMap] even-2
///
/// 3. PartitionCollect
///    [PartitionCollect] {matched: [], other: [1]}
///    [PartitionCollect] {matched: [2], other: [1]}
///
/// 4. PartitionOnly
///    [PartitionOnly] 2
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
/// 1. **Partition - Tagging**: Shows basic partitioning where each
///    value is tagged with its match status. Values are categorized
///    as matching (`true`) or not (`false`) and emitted as [Split]
///    records.
///
/// 2. **PartitionMap - Different Mapping**: Shows partitioning with
///    different mapping functions. Matching values get `'even-'`
///    labels, non-matching values get `'odd-'` labels.
///
/// 3. **PartitionCollect - Accumulation**: Shows running accumulation
///    of partitioned values. The matched and unmatched lists are
///    emitted after each pulse as a map.
///
/// 4. **PartitionOnly - Filtering**: Shows filtering by match status.
///    Only matching values (even numbers) are emitted; odd numbers
///    are dropped.
///
/// ### Key Takeaways
/// - Partition tags each value with its match status.
/// - PartitionMap applies different mappings to each side.
/// - PartitionCollect maintains running lists of both sides.
/// - PartitionOnly filters values by match status.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - The [Split] record preserves both status and value.
///
/// ### Note on State
/// PartitionCollect maintains state (the lists). Partition,
/// PartitionMap, and PartitionOnly are stateless.
Future<void> main() async {
  print('── Partition Operators Demo ──────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Partition - Tagging
  // ─────────────────────────────────────────────────────────────────────
  print('1. Partition');

  final nums = Cell.ingress<int>();

  final tagged = Partition<int>(
        (n) => n.isEven,
  ).toHandle(source: nums.cell);

  final pObs = Cell.observe(
    source: tagged.cell,
    effect: (Pulse p) => print('   [Partition] ${p.payload}'),
  );

  await nums.emitAsync(1);
  await nums.emitAsync(2);

  pObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. PartitionMap - Different Mapping
  // ─────────────────────────────────────────────────────────────────────
  print('2. PartitionMap');

  final mapped = Cell.ingress<int>();

  final labels = PartitionMap<int, String>(
        (n) => n.isEven,
    thenMap: (n) => 'even-$n',
    elseMap: (n) => 'odd-$n',
  ).toHandle(source: mapped.cell);

  final mObs = Cell.observe(
    source: labels.cell,
    effect: (Pulse p) => print('   [PartitionMap] ${p.payload}'),
  );

  await mapped.emitAsync(1);
  await mapped.emitAsync(2);

  mObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. PartitionCollect - Accumulation
  // ─────────────────────────────────────────────────────────────────────
  print('3. PartitionCollect');

  final seq = Cell.ingress<int>();

  final bags = PartitionCollect<int>(
        (n) => n.isEven,
  ).toHandle(source: seq.cell);

  final cObs = Cell.observe(
    source: bags.cell,
    effect: (Pulse p) => print('   [PartitionCollect] ${p.payload}'),
  );

  await seq.emitAsync(1);
  await seq.emitAsync(2);

  cObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. PartitionOnly - Filtering
  // ─────────────────────────────────────────────────────────────────────
  print('4. PartitionOnly');

  final only = Cell.ingress<int>();

  final evens = PartitionOnly<int>(
        (n) => n.isEven,
  ).toHandle(source: only.cell);

  final oObs = Cell.observe(
    source: evens.cell,
    effect: (Pulse p) => print('   [PartitionOnly] ${p.payload}'),
  );

  await only.emitAsync(1);
  await only.emitAsync(2);

  oObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}