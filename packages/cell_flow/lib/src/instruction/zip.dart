// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Zip Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that pair values by **index** (Rx `zip` family).
///
/// Unlike [CombineLatestWith], a value is held until every source has
/// produced the same ordinal event.
///
/// | Operator | Rx analogue | Pairing |
/// |---|---|---|
/// | [ZipWith] | `zipWith` | bound source + [others] |
/// | [Zip] | `zip` | extra Cells (bound source arms) |
/// | [ZipAll] | `zip` of lists | payload is `List` of inners |
///
/// Arm [Zip] with one `emitAsync` so `future` is available.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for zip operators.
///
/// Called when an error occurs during zipping operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = ZipErrorHandler((error, stack) {
///   print('Zip error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef ZipErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// Helper to create an output pulse with proper provenance.
Pulse<R> _out<R>(R value, Pulse trigger, Cell? cell, String step) {
  return Pulse<R>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// Internal state for async emission.
///
/// [_Emit] stores the continuation callback and context for operators
/// that emit asynchronously.
class _Emit {
  void Function({required Pulse? result, required dynamic token})? future;
  dynamic token;
  Cell? cell;
}

/// Internal queue for each lane in a zip operation.
///
/// [_Queue] holds pending values for a single source in a zip.
/// Each source in a zip operation has its own queue.
class _Queue {
  final values = <Object?>[];
}

/// Internal helper to try zipping values from all queues.
///
/// [_tryZip] attempts to zip values from all queues. If every queue
/// has at least one value, it removes one from each and emits the
/// zipped result.
///
/// ### Parameters:
/// - [queues]: The queues for each source.
/// - [emit]: The emission state.
/// - [trigger]: The trigger pulse for provenance.
/// - [step]: The provenance step.
/// - [project]: The projection function.
/// - [onError]: Optional error handler.
///
/// ### How it works
/// 1. Checks if any queue is empty.
/// 2. If all queues have values, removes one from each.
/// 3. Applies the project function to the row.
/// 4. Emits the result.
/// 5. If project throws, reports the error.
void _tryZip({
  required List<_Queue> queues,
  required _Emit emit,
  required Pulse trigger,
  required String step,
  required Object? Function(List<Object?> row) project,
  required ZipErrorHandler? onError,
}) {
  if (queues.any((q) => q.values.isEmpty)) return;
  final row = [for (final q in queues) q.values.removeAt(0)];
  try {
    final result = project(row);
    emit.future?.call(
      result: _out(result, trigger, emit.cell, step),
      token: emit.token,
    );
  } catch (e, stack) {
    onError?.call(e, stack);
  }
}

// ─────────────────────────────────────────────────────────────
// ZipWith - Zip Source with Other Cells
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that zips the bound source with [others]
/// (Rx `zipWith`).
///
/// [ZipWith] pairs values from the bound source with values from
/// other cells by index. A value is emitted when all sources have
/// produced a value at the same ordinal position.
///
/// ### When to use
/// Use [ZipWith] when you need to combine values from multiple
/// sources by index.
///
/// - **Combining Streams**: Combining multiple data streams.
/// - **Synchronization**: Synchronizing events from different sources.
/// - **Data Alignment**: Aligning data from different sources.
/// - **Join Operations**: Joining data from multiple sources.
/// - **Correlation**: Correlating events from different sources.
/// - **Multi-source Aggregation**: Aggregating data from multiple sources.
///
/// ### Choosing Between Zip Variants
/// - **Use [ZipWith]** for **Source + Others**: When you have a
///   bound source and other cells to zip with.
/// - **Use [Zip]** for **Extra Sources**: When you have a separate
///   arm source and extra sources.
/// - **Use [ZipAll]** for **Payload List**: When you want to zip
///   values from a single source by count.
///
/// ### Comparison with Other Operators
/// | Operator | Sources | Projection | Arm Required |
/// |----------|---------|------------|--------------|
/// | **ZipWith** | Bound source + others | Optional | No |
/// | **Zip** | Extra sources | Optional | Yes |
/// | **ZipAll** | Single source | No | No |
///
/// ### How it works
/// 1. Each source has a queue of pending values.
/// 2. When a value arrives, it's added to the corresponding queue.
/// 3. If every queue has at least one value:
///    a. One value is removed from each queue.
///    b. The values are combined using [project].
///    c. The result is emitted.
/// 4. If [project] is not provided, the row is emitted as-is.
/// 5. Each emitted value gets the step `'ZipWith'` for provenance.
///
/// ### Non‑obvious
/// - **Index Pairing**: Values are paired by position (index).
/// - **Queueing**: Values are queued until all sources have a value.
/// - **Synchronization**: The slowest source determines the emission rate.
/// - **Projection**: [project] can transform the row into any type.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Memory Usage**: Queues hold values until all sources have one.
///
/// ### Example: Zipping Two Sources
/// ```dart
/// final left = Cell.ingress<int>();
/// final right = Cell.ingress<String>();
///
/// final zipped = ZipWith<List<Object?>>(
///   [right.cell],
/// ).toHandle(source: left.cell);
///
/// left.emit(1); // queued
/// right.emit('a'); // -> [1, 'a']
/// left.emit(2); // queued
/// right.emit('b'); // -> [2, 'b']
/// ```
///
/// ### Example: Custom Projection
/// ```dart
/// final left = Cell.ingress<int>();
/// final right = Cell.ingress<String>();
///
/// final zipped = ZipWith<String>(
///   [right.cell],
///   project: (row) => '${row[0]}-${row[1]}',
/// ).toHandle(source: left.cell);
///
/// left.emit(1);
/// right.emit('a'); // -> '1-a'
/// ```
///
/// ### Parameters:
/// - [others]: **Other Sources.** The cells to zip with the bound source.
/// - [project]: **Projection Function.** Optional. Combines the row
///   of values into the output type. If not provided, the row is
///   emitted as a List.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [R]: The type of the output value.
///
/// ### Returns:
/// A [FlowInstruction] that zips the source with other cells.
///
/// ### See Also:
/// - [Zip]: For zipping extra sources with an arm.
/// - [ZipAll]: For zipping values from a single source by count.
/// - [CombineLatestWith]: For combining the latest values.
class ZipWith<R> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ZipWith(
      List<Cell> others, {
        R Function(List<Object?> row)? project,
        ZipErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final emit = _Emit();
      final queues = List<_Queue>.generate(others.length + 1, (_) => _Queue());
      var armed = false;
      Pulse? last;

      void listen(int index, Cell source) {
        Cell.observe(
          source: source,
          effect: (Pulse p) {
            queues[index].values.add(p.payload);
            last = p;
            _tryZip(
              queues: queues,
              emit: emit,
              trigger: last ?? p,
              step: 'ZipWith',
              project: project ?? (row) => row as R,
              onError: onError,
            );
          },
        );
      }

      return (pulse, {cell, user, future, token}) {
        emit.future = future;
        emit.token = token;
        emit.cell = cell;
        last = pulse;
        if (!armed) {
          armed = true;
          for (var i = 0; i < others.length; i++) {
            listen(i + 1, others[i]);
          }
        }
        queues[0].values.add(pulse.payload);
        _tryZip(
          queues: queues,
          emit: emit,
          trigger: pulse,
          step: 'ZipWith',
          project: project ?? (row) => row as R,
          onError: onError,
        );
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Zip - Zip Extra Sources with Arm
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that zips extra [sources]. The bound handle
/// only arms the zip.
///
/// [Zip] is similar to [ZipWith] but the bound source is only used
/// to arm the zip operation. The actual zipping happens between the
/// extra sources.
///
/// ### When to use
/// Use [Zip] when you need to arm a zip operation with a separate
/// trigger and zip multiple other sources.
///
/// - **Multiple Sources**: Zipping multiple sources together.
/// - **Triggered Zipping**: Starting zip on a trigger.
/// - **Synchronization**: Synchronizing multiple sources.
/// - **Data Alignment**: Aligning data from multiple sources.
///
/// ### Example: Zipping Multiple Sources
/// ```dart
/// final arm = Cell.ingress<void>();
/// final a = Cell.ingress<int>();
/// final b = Cell.ingress<int>();
///
/// final zipped = Zip<List<Object?>>([a.cell, b.cell])
///     .toHandle(source: arm.cell);
///
/// arm.emit(null); // Arms the zip
/// a.emit(10);
/// b.emit(20); // -> [10, 20]
/// ```
///
/// ### How it works
/// 1. The bound source arms the zip on its first pulse.
/// 2. Each extra source has a queue of pending values.
/// 3. When a value arrives from a source, it's added to its queue.
/// 4. If every queue has at least one value:
///    a. One value is removed from each queue.
///    b. The values are combined using [project].
///    c. The result is emitted.
/// 5. Each emitted value gets the step `'Zip'` for provenance.
///
/// ### Non‑obvious
/// - **Arm Only**: The bound source only arms the zip; its payload
///   is not included in the zipped output.
/// - **Index Pairing**: Values are paired by position (index).
/// - **Queueing**: Values are queued until all sources have a value.
/// - **Synchronization**: The slowest source determines the emission rate.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [sources]: **Sources to Zip.** The cells to zip together.
/// - [project]: **Projection Function.** Optional. Combines the row
///   of values into the output type. If not provided, the row is
///   emitted as a List.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [R]: The type of the output value.
///
/// ### Returns:
/// A [FlowInstruction] that zips extra sources.
///
/// ### See Also:
/// - [ZipWith]: For zipping the source with other cells.
/// - [ZipAll]: For zipping values from a single source by count.
class Zip<R> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Zip(
      List<Cell> sources, {
        R Function(List<Object?> row)? project,
        ZipErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final emit = _Emit();
      final queues = List<_Queue>.generate(sources.length, (_) => _Queue());
      var armed = false;
      Pulse? last;

      return (pulse, {cell, user, future, token}) {
        emit.future = future;
        emit.token = token;
        emit.cell = cell;
        last = pulse;
        if (!armed) {
          armed = true;
          for (var i = 0; i < sources.length; i++) {
            final index = i;
            Cell.observe(
              source: sources[i],
              effect: (Pulse p) {
                queues[index].values.add(p.payload);
                last = p;
                _tryZip(
                  queues: queues,
                  emit: emit,
                  trigger: last ?? p,
                  step: 'Zip',
                  project: project ?? (row) => row as R,
                  onError: onError,
                );
              },
            );
          }
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// ZipAll - Zip Values by Count
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that collects values into a list of [width] items.
///
/// [ZipAll] is the simplest zip operator. It collects values from a
/// single source into batches of [width] and emits them as a list.
///
/// ### When to use
/// Use [ZipAll] when you want to collect values from a single source
/// into batches by count.
///
/// - **Batching**: Batching values into fixed-size lists.
/// - **Chunking**: Chunking data into chunks of a fixed size.
/// - **Pagination**: Creating pages of data.
/// - **Collection**: Collecting values into groups.
/// - **Aggregation**: Aggregating values into lists.
///
/// ### Example: Batching Values
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final batches = ZipAll<int>(3).toHandle(source: input.cell);
///
/// input.emit(1); // no output
/// input.emit(2); // no output
/// input.emit(3); // -> [1, 2, 3]
/// input.emit(4); // no output
/// input.emit(5); // no output
/// input.emit(6); // -> [4, 5, 6]
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. The payload is added to the current row.
/// 3. When the row reaches [width], it's emitted as a list.
/// 4. The row is cleared.
/// 5. Each emitted value gets the step `'ZipAll'` for provenance.
///
/// ### Non‑obvious
/// - **Batching**: Values are batched by count.
/// - **Single Source**: Only one source is used.
/// - **No Overlap**: Each value appears in exactly one batch.
/// - **Provenance Preservation**: Each batch preserves the source
///   cell, type, and priority from the trigger pulse.
/// - **Memory Usage**: Only holds up to [width] values at a time.
///
/// ### Parameters:
/// - [width]: **Batch Size.** The number of values in each batch.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that batches values by count.
///
/// ### See Also:
/// - [ZipWith]: For zipping the source with other cells.
/// - [Zip]: For zipping extra sources with an arm.
/// - [BufferCount]: For more flexible count-based buffering.
class ZipAll<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ZipAll(
      int width, {
        ZipErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final row = <T>[];
      return (pulse, {cell, user}) {
        final payload = pulse.payload;
        if (payload is! T) {
          onError?.call(
            FormatException(
              'Expected payload of type $T, got ${payload.runtimeType}',
            ),
            StackTrace.current,
          );
          return null;
        }
        row.add(payload);
        if (row.length < width) return null;
        final out = List<T>.from(row);
        row.clear();
        return Pulse<List<T>>(
          out,
          source: cell ?? pulse.source,
          type: pulse.type,
          priority: pulse.priority,
          step: 'ZipAll',
        );
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [ZipWith] instruction and related operators
/// showing their behavior in various zipping scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Zip Operators Demo ────────────────────────────────────────
///
/// 1. ZipWith
///    [ZipWith] [1, a]
///
/// 2. Zip
///    [Zip] [10, 20]
///
/// 3. ZipAll
///    [ZipAll] [1, 2]
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
/// 1. **ZipWith - Source with Others**: Shows zipping the bound
///    source with another cell. The left source emits 1, and the
///    right source emits 'a', producing [1, 'a'].
///
/// 2. **Zip - Extra Sources with Arm**: Shows zipping extra sources
///    with an arm trigger. The arm is triggered, then sources a and c
///    emit 10 and 20, producing [10, 20].
///
/// 3. **ZipAll - Batch by Count**: Shows batching values from a
///    single source. Values 1 and 2 are batched into [1, 2].
///
/// ### Key Takeaways
/// - ZipWith zips the bound source with other cells.
/// - Zip zips extra sources with an arm trigger.
/// - ZipAll batches values from a single source by count.
/// - Values are paired by index (position).
/// - The slowest source determines the emission rate.
/// - Queues hold values until all sources have one.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Projection functions can transform the zipped row.
///
/// ### Note on Zipping
/// Unlike [CombineLatestWith], zip pairs values by index. The first
/// values from all sources are emitted together, then the second
/// values, and so on. This ensures a one-to-one correspondence
/// between values from different sources.
Future<void> main() async {
  print('── Zip Operators Demo ────────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. ZipWith - Source with Others
  // ─────────────────────────────────────────────────────────────────────
  print('1. ZipWith');

  final left = Cell.ingress<int>();
  final right = Cell.ingress<String>();

  final zipped = ZipWith<List<Object?>>(
    [right.cell],
  ).toHandle(source: left.cell);

  final zObs = Cell.observe(
    source: zipped.cell,
    effect: (Pulse p) => print('   [ZipWith] ${p.payload}'),
  );

  await left.emitAsync(1);
  await right.emitAsync('a');

  zObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. Zip - Extra Sources with Arm
  // ─────────────────────────────────────────────────────────────────────
  print('2. Zip');

  final arm = Cell.ingress<void>();
  final a = Cell.ingress<int>();
  final c = Cell.ingress<int>();

  final zipped2 = Zip<List<Object?>>(
    [a.cell, c.cell],
  ).toHandle(source: arm.cell);

  final zipObs = Cell.observe(
    source: zipped2.cell,
    effect: (Pulse p) => print('   [Zip] ${p.payload}'),
  );

  await arm.emitAsync(null);
  await a.emitAsync(10);
  await c.emitAsync(20);

  zipObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. ZipAll - Batch by Count
  // ─────────────────────────────────────────────────────────────────────
  print('3. ZipAll');

  final nums = Cell.ingress<int>();

  final rows = ZipAll<int>(2).toHandle(source: nums.cell);

  final rObs = Cell.observe(
    source: rows.cell,
    effect: (Pulse p) => print('   [ZipAll] ${p.payload}'),
  );

  await nums.emitAsync(1);
  await nums.emitAsync(2);

  rObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}