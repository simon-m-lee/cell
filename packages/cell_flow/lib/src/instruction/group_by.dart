// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core GroupBy Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that split a stream by key (Rx `groupBy` family).
///
/// There is no inner Cell per group. A group is either a tagged
/// record [Grouped] or a collected [List] / [Map].
///
/// | Operator | Rx analogue | Emits |
/// |---|---|---|
/// | [GroupBy] | `groupBy` | [Grouped] per item |
/// | [GroupCollect] | `groupBy` + buffer | running `Map<key, List>` |
/// | [GroupByCount] | `groupBy` + `take` | a group's list when it hits [size] |
///
/// Boolean split (`partition`) lives on [PartitionTag] in `routing.dart`.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for groupBy operators.
///
/// Called when an error occurs during key extraction or grouping operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = GroupErrorHandler((error, stack) {
///   print('GroupBy error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef GroupErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// One item tagged with its group key.
///
/// [Grouped] is a simple record that pairs a value with its group key.
/// It's the output of the [GroupBy] operator.
///
/// ### When to use
/// Use [Grouped] when you need to know which group a value belongs to.
/// It's created automatically by [GroupBy] and emitted as a pulse payload.
///
/// ### How it works
/// 1. [key] is the group identifier.
/// 2. [value] is the original payload.
/// 3. The combination preserves both the grouping and the original value.
///
/// ### Non‑obvious
/// - **Immutable**: [Grouped] is immutable.
/// - **Type Safety**: Generic over key type [K] and value type [S].
/// - **Equality**: Implements `==` and `hashCode` for value equality.
/// - **String Representation**: Provides a readable `toString()`.
///
/// ### Example: Accessing Grouped Values
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final grouped = GroupBy<int, String>(
///   (n) => n.isEven ? 'even' : 'odd',
/// ).toHandle(source: input.cell);
///
/// Cell.observe(
///   source: grouped.cell,
///   effect: (Pulse<Grouped<String, int>> p) {
///     final grouped = p.payload;
///     print('Key: ${grouped.key}, Value: ${grouped.value}');
///   },
/// );
/// ```
///
/// ### Type Parameters:
/// - [K]: The type of the group key.
/// - [S]: The type of the value.
///
/// ### See Also:
/// - [GroupBy]: The operator that produces Grouped values.
class Grouped<K, S> {
  /// Creates a [Grouped] record with the given [key] and [value].
  const Grouped(this.key, this.value);

  /// The group key.
  final K key;

  /// The original value.
  final S value;

  @override
  String toString() => 'Grouped($key, $value)';

  @override
  bool operator ==(Object other) =>
      other is Grouped<K, S> && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(key, value);
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
      GroupErrorHandler? onError,
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
// GroupBy - Tag Each Item with Its Group
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that tags each typed payload with its group key
/// (Rx `groupBy` flattened).
///
/// [GroupBy] transforms each value into a [Grouped] record containing
/// both the original value and its group key. This allows downstream
/// operators to process values with their group context.
///
/// ### When to use
/// Use [GroupBy] when you need to tag values with group information
/// without aggregating them.
///
/// - **Categorization**: Tagging items with their category.
/// - **Group Context**: Preserving group information for downstream.
/// - **Partitioning**: Preparing values for group-based processing.
/// - **Classification**: Classifying items into groups.
/// - **Filtering by Group**: Filtering based on group membership.
/// - **Group-Aware Processing**: Processing values with group context.
///
/// ### Choosing Between GroupBy Variants
/// - **Use [GroupBy]** for **Tagging**: When you just need to tag
///   each value with its group key.
/// - **Use [GroupCollect]** for **Accumulation**: When you need to
///   collect all values by group.
/// - **Use [GroupByCount]** for **Batching**: When you need to
///   batch values by group when they reach a size.
///
/// ### Comparison with Other Operators
/// | Operator | Output | State | Emits Per Item |
/// |----------|--------|-------|----------------|
/// | **GroupBy** | `Grouped<K, S>` | No | Yes |
/// | **GroupCollect** | `Map<K, List<S>>` | Yes (groups) | Yes |
/// | **GroupByCount** | `Grouped<K, List<S>>` | Yes (groups) | When full |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [keyOf] is called with the payload.
/// 3. The key and value are wrapped in a [Grouped] record.
/// 4. The [Grouped] record is emitted.
/// 5. If [keyOf] throws an error, the pulse is dropped.
/// 6. The emitted pulse gets the step `'GroupBy'` for provenance.
///
/// ### Non‑obvious
/// - **No State**: No state is maintained between pulses.
/// - **Per-Item Emit**: Emits one [Grouped] for each input.
/// - **Key Extraction**: [keyOf] is called for each value.
/// - **Type Safety**: Generic over value type [S] and key type [K].
/// - **Error Handling**: If [keyOf] throws, the pulse is dropped.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Key Extraction**: [keyOf] is synchronous.
///
/// ### Example: Grouping by Parity
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final grouped = GroupBy<int, String>(
///   (n) => n.isEven ? 'even' : 'odd',
/// ).toHandle(source: input.cell);
///
/// input.emit(1); // -> Grouped(odd, 1)
/// input.emit(2); // -> Grouped(even, 2)
/// input.emit(3); // -> Grouped(odd, 3)
/// ```
///
/// ### Example: Grouping by First Letter
/// ```dart
/// final words = Cell.ingress<String>();
///
/// final byLetter = GroupBy<String, String>(
///   (word) => word[0].toUpperCase(),
/// ).toHandle(source: words.cell);
///
/// words.emit('apple');  // -> Grouped(A, apple)
/// words.emit('banana'); // -> Grouped(B, banana)
/// words.emit('apricot'); // -> Grouped(A, apricot)
/// ```
///
/// ### Parameters:
/// - [keyOf]: **Key Extraction Function.** Called with each typed
///   payload, returns the group key.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [K]: The type of the group key.
///
/// ### Returns:
/// A [FlowInstruction] that tags each value with its group key.
///
/// ### See Also:
/// - [GroupCollect]: For collecting values by group.
/// - [GroupByCount]: For batching values by group.
/// - [Grouped]: The record type emitted.
class GroupBy<S, K> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  GroupBy(
      K Function(S value) keyOf, {
        GroupErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      try {
        final value = typed.payload as S;
        return _out<Grouped<K, S>>(
          Grouped(keyOf(value), value),
          typed,
          cell,
          'GroupBy',
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
// GroupCollect - Accumulate Groups
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a running `Map<K, List<S>>` after
/// every typed pulse (Rx `groupBy` + buffer).
///
/// [GroupCollect] accumulates values into groups and emits the
/// complete map after every pulse. This provides a running snapshot
/// of all grouped values.
///
/// ### When to use
/// Use [GroupCollect] when you need a running snapshot of all
/// grouped values.
///
/// - **Real-time Dashboard**: Showing real-time group summaries.
/// - **Aggregation**: Aggregating values by group over time.
/// - **State Monitoring**: Monitoring grouped state.
/// - **Caching**: Maintaining a cache of grouped values.
/// - **Batch Processing**: Preparing batches by group.
/// - **Reporting**: Generating reports on grouped data.
///
/// ### Example: Running Group Snapshot
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final collected = GroupCollect<int, String>(
///   (n) => n.isEven ? 'even' : 'odd',
/// ).toHandle(source: input.cell);
///
/// input.emit(1); // -> {odd: [1]}
/// input.emit(2); // -> {odd: [1], even: [2]}
/// input.emit(3); // -> {odd: [1, 3], even: [2]}
/// ```
///
/// ### Example: Grouping by Category
/// ```dart
/// final products = Cell.ingress<Product>();
///
/// final byCategory = GroupCollect<Product, String>(
///   (product) => product.category,
/// ).toHandle(source: products.cell);
///
/// // Emits a map of category -> list of products after each addition
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [keyOf] is called with the payload.
/// 3. The value is added to the group's list in the internal map.
/// 4. The current map is emitted as a snapshot.
/// 5. If [keyOf] throws an error, the pulse is dropped.
/// 6. The emitted pulse gets the step `'GroupCollect'` for provenance.
///
/// ### Non‑obvious
/// - **Stateful**: Maintains a map of all groups.
/// - **Running Snapshot**: Emits the complete map after every pulse.
/// - **Snapshot Copy**: The emitted map is a copy (not the internal map).
/// - **Monotonic Growth**: Groups only grow; values are never removed.
/// - **External Access**: The [groups] map can be accessed externally.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Key Extraction**: [keyOf] is synchronous.
///
/// ### Parameters:
/// - [keyOf]: **Key Extraction Function.** Called with each typed
///   payload, returns the group key.
/// - [groups]: **Initial Groups Map.** Optional. Use this to seed
///   the groups or to access the map externally.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [K]: The type of the group key.
///
/// ### Returns:
/// A [FlowInstruction] that accumulates values by group.
///
/// ### See Also:
/// - [GroupBy]: For tagging values with group keys.
/// - [GroupByCount]: For batching values by group.
/// - [Reduce]: For reducing values without grouping.
class GroupCollect<S, K> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  GroupCollect(
      K Function(S value) keyOf, {
        Map<K, List<S>>? groups,
        GroupErrorHandler? onError,
        dynamic user,
      }) : this._(keyOf, groups ?? <K, List<S>>{}, onError, user);

  GroupCollect._(
      K Function(S value) keyOf,
      this.groups,
      GroupErrorHandler? onError,
      dynamic user,
      ) : super(
    (() {
      final bucket = groups;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        try {
          final value = typed.payload as S;
          final key = keyOf(value);
          (bucket[key] ??= <S>[]).add(value);
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        return _out<Map<K, List<S>>>(
          {
            for (final e in bucket.entries) e.key: List<S>.from(e.value),
          },
          typed,
          cell,
          'GroupCollect',
        );
      };
    })(),
    user: user,
  );

  /// The internal groups map.
  ///
  /// Use this to access the current groups from outside the instruction.
  /// The map is mutable and updated on each pulse.
  final Map<K, List<S>> groups;
}

// ─────────────────────────────────────────────────────────────
// GroupByCount - Batch Groups by Size
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a group's list when it reaches
/// [size] items (Rx `groupBy` + `take`).
///
/// [GroupByCount] accumulates values by group and emits the list
/// when a group reaches the specified size. The group is then cleared.
///
/// ### When to use
/// Use [GroupByCount] when you need to batch values by group
/// and emit when a batch is full.
///
/// - **Batch Processing**: Processing items in batches by group.
/// - **Chunking**: Chunking values by group.
/// - **Pagination**: Paginating grouped items.
/// - **Bulk Operations**: Performing bulk operations by group.
/// - **Rate Limiting**: Limiting processing by group.
/// - **Windowed Processing**: Processing windows of grouped data.
///
/// ### Example: Batching by First Letter
/// ```dart
/// final words = Cell.ingress<String>();
///
/// final batches = GroupByCount<String, String>(
///   (word) => word[0].toUpperCase(),
///   3, // Emit when a group has 3 items
/// ).toHandle(source: words.cell);
///
/// words.emit('apple');   // no output
/// words.emit('apricot'); // no output
/// words.emit('avocado'); // -> Grouped(A, [apple, apricot, avocado])
/// ```
///
/// ### Example: Batching by Category
/// ```dart
/// final products = Cell.ingress<Product>();
///
/// final batches = GroupByCount<Product, String>(
///   (product) => product.category,
///   10, // Emit when a category has 10 products
/// ).toHandle(source: products.cell);
///
/// // Emits a Grouped record for each completed batch
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, [keyOf] is called with the payload.
/// 3. The value is added to the group's list.
/// 4. If the list reaches [size], it's emitted as a [Grouped] record.
/// 5. The group is cleared from the internal map.
/// 6. If [keyOf] throws an error, the pulse is dropped.
/// 7. The emitted pulse gets the step `'GroupByCount'` for provenance.
///
/// ### Non‑obvious
/// - **Stateful**: Maintains groups until they reach the size.
/// - **Clear on Emit**: Groups are removed after emission.
/// - **Per-Group Batching**: Each group batches independently.
/// - **Incomplete Groups**: Groups that never reach the size are kept.
/// - **Provenance Preservation**: The emitted pulse preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Key Extraction**: [keyOf] is synchronous.
///
/// ### Parameters:
/// - [keyOf]: **Key Extraction Function.** Called with each typed
///   payload, returns the group key.
/// - [size]: **Batch Size.** The number of items required to emit.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [K]: The type of the group key.
///
/// ### Returns:
/// A [FlowInstruction] that batches values by group.
///
/// ### See Also:
/// - [GroupBy]: For tagging values with group keys.
/// - [GroupCollect]: For accumulating values by group.
/// - [WindowCount]: For batching without grouping.
class GroupByCount<S, K> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  GroupByCount(
      K Function(S value) keyOf,
      int size, {
        GroupErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final bucket = <K, List<S>>{};
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        late final K key;
        late final List<S> list;
        try {
          final value = typed.payload as S;
          key = keyOf(value);
          list = bucket[key] ??= <S>[];
          list.add(value);
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        if (list.length < size) return null;
        final window = List<S>.from(list);
        bucket.remove(key);
        return _out<Grouped<K, List<S>>>(
          Grouped(key, window),
          typed,
          cell,
          'GroupByCount',
        );
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [GroupBy] instruction and related operators
/// showing their behavior in various grouping scenarios.
///
/// ### Expected console output:
/// ```text
/// ── GroupBy Operators Demo ────────────────────────────────────
///
/// 1. GroupBy
///    [GroupBy] Grouped(odd, 1)
///    [GroupBy] Grouped(even, 2)
///
/// 2. GroupCollect
///    [GroupCollect] {odd: [1]}
///    [GroupCollect] {odd: [1], even: [2]}
///
/// 3. GroupByCount
///    [GroupByCount] Grouped(a, [a1, a2])
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
/// 1. **GroupBy - Tagging**: Shows basic grouping where each value
///    is tagged with its group key. Values are categorized as
///    `'odd'` or `'even'` and emitted as [Grouped] records.
///
/// 2. **GroupCollect - Accumulation**: Shows running accumulation
///    of groups. After each pulse, the complete map of groups is
///    emitted. The map grows as more values arrive.
///
/// 3. **GroupByCount - Batching by Size**: Shows batching by group
///    size. Values are grouped by their first letter, and when a
///    group reaches size 2, it's emitted as a batch.
///
/// ### Key Takeaways
/// - GroupBy tags each value with its group key.
/// - GroupCollect maintains a running map of all groups.
/// - GroupByCount batches groups when they reach a size.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Groups are stateful across pulses.
/// - The [Grouped] record preserves both key and value.
///
/// ### Note on State
/// GroupCollect and GroupByCount maintain state (the groups).
/// GroupBy is stateless and simply tags each value.
Future<void> main() async {
  print('── GroupBy Operators Demo ────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. GroupBy - Tagging
  // ─────────────────────────────────────────────────────────────────────
  print('1. GroupBy');

  final nums = Cell.ingress<int>();

  final tagged = GroupBy<int, String>(
        (n) => n.isEven ? 'even' : 'odd',
  ).toHandle(source: nums.cell);

  final gObs = Cell.observe(
    source: tagged.cell,
    effect: (Pulse p) => print('   [GroupBy] ${p.payload}'),
  );

  await nums.emitAsync(1);
  await nums.emitAsync(2);

  gObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. GroupCollect - Accumulation
  // ─────────────────────────────────────────────────────────────────────
  print('2. GroupCollect');

  final seq = Cell.ingress<int>();

  final collected = GroupCollect<int, String>(
        (n) => n.isEven ? 'even' : 'odd',
  ).toHandle(source: seq.cell);

  final cObs = Cell.observe(
    source: collected.cell,
    effect: (Pulse p) => print('   [GroupCollect] ${p.payload}'),
  );

  await seq.emitAsync(1);
  await seq.emitAsync(2);

  cObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. GroupByCount - Batching by Size
  // ─────────────────────────────────────────────────────────────────────
  print('3. GroupByCount');

  final words = Cell.ingress<String>();

  final batches = GroupByCount<String, String>(
        (s) => s[0],
    2,
  ).toHandle(source: words.cell);

  final bObs = Cell.observe(
    source: batches.cell,
    effect: (Pulse p) => print('   [GroupByCount] ${p.payload}'),
  );

  await words.emitAsync('a1');
  await words.emitAsync('b1');
  await words.emitAsync('a2');

  bObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}