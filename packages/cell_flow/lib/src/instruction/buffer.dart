// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Buffer Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that collect values into lists (Rx `buffer` family).
///
/// Same shape as `window.dart` — a closed buffer is a [List], not an
/// inner Cell. Prefer these names when you think “batch”, and window
/// when you think “pane”.
///
/// | Operator | Rx analogue | Closes when |
/// |---|---|---|
/// | [BufferCount] / [BufferWithCount] | `bufferCount` | [size] items |
/// | [BufferTime] / [BufferWithTime] | `bufferTime` | [duration] |
/// | [BufferWithTimeAndCount] | `bufferTime` + `count` | time **or** count |
/// | [BufferWhen] | `buffer` / `bufferWhen` | [closer] pulses |
/// | [BufferWithPredicate] | `buffer` + close | [test] is true |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for buffer operators.
///
/// Called when an error occurs during buffering operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = BufferErrorHandler((error, stack) {
///   print('Buffer error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef BufferErrorHandler = void Function(Object error, StackTrace? stackTrace);

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
      BufferErrorHandler? onError,
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

/// Helper to create a buffer pulse with proper provenance.
Pulse<List<S>> _buf<S>(
    List<S> items,
    Pulse trigger,
    Cell? cell,
    String step,
    ) {
  return Pulse<List<S>>(
    List<S>.from(items),
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// Internal state for async buffer emission.
///
/// [_Emit] stores the continuation callback and context for operators
/// that emit buffers asynchronously, such as [BufferTime] and
/// [BufferWhen].
///
/// ### When to use
/// This is an internal implementation detail. You don't need to use it
/// directly in application code.
class _Emit {
  void Function({required Pulse? result, required dynamic token})? future;
  dynamic token;
  Cell? cell;
}

// ─────────────────────────────────────────────────────────────
// BufferCount - Count-Based Buffering
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a list every [size] items
/// (Rx `bufferCount`).
///
/// [BufferCount] batches incoming values into lists of size [size].
/// When the buffer is full, it's emitted as a list and cleared.
/// The [skip] parameter controls how far to advance the start of
/// the next buffer.
///
/// ### When to use
/// Use [BufferCount] when you need to batch values by count.
///
/// - **Batching**: Grouping items for batch processing.
/// - **Pagination**: Collecting items into pages.
/// - **Chunking**: Splitting data into chunks.
/// - **Aggregation**: Aggregating a fixed number of items.
/// - **Buffering**: Buffering items for efficient processing.
/// - **Bulk Operations**: Collecting items for bulk operations.
///
/// ### Choosing Between Buffer Variants
/// - **Use [BufferCount]** for **Count-Based Buffering**: When you
///   need to batch by item count.
/// - **Use [BufferTime]** for **Time-Based Buffering**: When you need
///   to batch by time duration.
/// - **Use [BufferWhen]** for **Trigger-Based Buffering**: When you
///   need to batch based on external triggers.
/// - **Use [BufferWithPredicate]** for **Predicate-Based Buffering**:
///   When you need to batch based on a predicate condition.
/// - **Use [BufferWithTimeAndCount]** for **Time or Count**: When
///   either time or count can trigger a flush.
///
/// ### Comparison with Other Operators
/// | Operator | Trigger | Buffer Size | Overlap |
/// |----------|---------|-------------|---------|
/// | **BufferCount** | Item count | Fixed | Optional |
/// | **BufferTime** | Time duration | Variable | No |
/// | **BufferWhen** | External pulse | Variable | No |
/// | **BufferWithPredicate** | Predicate | Variable | No |
/// | **BufferWithTimeAndCount** | Time or count | Variable | No |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. The payload is added to the current buffer.
/// 3. When the buffer reaches [size], it's emitted as a list.
/// 4. The buffer is cleared or advanced by [skip].
/// 5. If [skip] is less than [size], buffers overlap.
/// 6. If [skip] is greater than [size], items are skipped.
/// 7. Each emitted buffer gets the step `'BufferCount'` for provenance.
///
/// ### Skip Behavior
/// | Skip | Behavior | Example (size=3) |
/// |------|----------|------------------|
/// | `skip == size` | Tumbling (no overlap) | [1,2,3], [4,5,6] |
/// | `skip < size` | Overlapping | [1,2,3], [2,3,4], [3,4,5] |
/// | `skip > size` | Gaps (items skipped) | [1,2,3], [5,6,7] (4 skipped) |
///
/// ### Non‑obvious
/// - **Tumbling Default**: [skip] defaults to [size] (no overlap).
/// - **Overlap**: When [skip] < [size], buffers overlap.
/// - **Gaps**: When [skip] > [size], some items are skipped.
/// - **Type Safety**: The instruction is generic over [S].
/// - **Provenance Preservation**: Each buffer preserves the source
///   cell, type, and priority from the trigger pulse.
/// - **List Copy**: The emitted list is a copy of the buffer.
///
/// ### Example: Tumbling Buffers
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final buffers = BufferCount<int>(3)
///     .toHandle(source: input.cell);
///
/// input.emit(1); // No output
/// input.emit(2); // No output
/// input.emit(3); // -> [1, 2, 3]
/// input.emit(4); // No output
/// input.emit(5); // No output
/// input.emit(6); // -> [4, 5, 6]
/// ```
///
/// ### Example: Overlapping Buffers
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final buffers = BufferCount<int>(3, skip: 1)
///     .toHandle(source: input.cell);
///
/// input.emit(1); // No output
/// input.emit(2); // No output
/// input.emit(3); // -> [1, 2, 3]
/// input.emit(4); // -> [2, 3, 4]
/// input.emit(5); // -> [3, 4, 5]
/// ```
///
/// ### Parameters:
/// - [size]: **Buffer Size.** The number of items in each buffer.
/// - [skip]: **Skip Count.** How many items to advance for the next
///   buffer. Defaults to [size] (tumbling).
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits buffers of [size] items.
///
/// ### See Also:
/// - [BufferWithCount]: Alias of [BufferCount].
/// - [BufferTime]: For time-based buffering.
/// - [BufferWhen]: For trigger-based buffering.
/// - [BufferWithPredicate]: For predicate-based buffering.
/// - [BufferWithTimeAndCount]: For time or count buffering.
class BufferCount<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Count-Based Logic Gate** designed to batch pulses
  /// into discrete topographical windows based on stimulus frequency.
  ///
  /// [BufferCount] (analogous to `bufferCount` in Rx) monitors the pulse
  /// stream and accumulates payloads into an internal buffer until a
  /// specified [size] is reached. Once the threshold is met, the gate
  /// evolves the accumulated stimuli into a single [Pulse<List<S>>].
  ///
  /// ### How it works
  /// 1. **Stimulus Reception**: Each incoming pulse is evaluated for
  ///    type integrity [S].
  /// 2. **Accumulation**: Validated payloads are added to the internal
  ///    logic buffer.
  /// 3. **Materialization**: When the buffer length equals [size], a
  ///    window pulse is materialized.
  /// 4. **Provenance Preservation**: The materialized pulse inherits
  ///    provenance (source, priority, type) from the pulse that
  ///    triggered the flush, tagged with the `'BufferCount'` step.
  /// 5. **Topographical Advance**: After emission, the internal buffer
  ///    is advanced by the [skip] count.
  ///
  /// ### Skip & Overlap Mechanics
  /// - **Tumbling** ([skip] == `null` or `size`): Windows are contiguous
  ///   with no overlap (e.g., `[1,2], [3,4]`).
  /// - **Overlapping** ([skip] < `size`): Windows share payloads,
  ///   creating a sliding effect (e.g., `[1,2], [2,3]`).
  /// - **Gapped** ([skip] > `size`): Certain stimuli are dropped between
  ///   windows (e.g., `[1,2], [4,5]` where `3` is lost).
  ///
  /// ### Parameters
  /// - [size]: **Window Capacity.** The number of stimuli required to
  ///   materialize a window.
  /// - [skip]: **Advance Offset.** Determines how many pulses to advance
  ///   the starting point of the next window. Defaults to [size].
  /// - [onError]: **Integrity Handler.** A specialized callback invoked if
  ///   a pulse payload fails to match the expected type [S].
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the instruction chain.
  ///
  /// ### Example: Tumbling Window
  /// ```dart
  /// // Batches integers into lists of 3
  /// final batchGate = BufferCount<int>(3);
  /// ```
  ///
  /// ### See Also
  /// - [BufferTime]: For batching based on temporal intervals.
  /// - [BufferWithPredicate]: For batching based on logic conditions.
  /// - [WindowCount]: A related operator that yields multiple output pulses.
  BufferCount(
      int size, {
        int? skip,
        BufferErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final step = skip == null || skip == size ? size : skip;
      final buf = <S>[];
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        buf.add(typed.payload as S);
        if (buf.length < size) return null;
        final window = List<S>.from(buf);
        final drop = step < 1 ? size : step;
        if (drop >= buf.length) {
          buf.clear();
        } else {
          buf.removeRange(0, drop);
        }
        return _buf<S>(window, typed, cell, 'BufferCount');
      };
    })(),
    user: user,
  );
}

/// Synthesizes a **Count-Based Topographical Alias**—a specialized
/// instruction wrapper designed for Rx-compatible pulse orchestration.
///
/// [BufferWithCount] is a semantic alias for [BufferCount]. It provides a
/// familiar entry point for developers transitioning from traditional
/// ReactiveX implementations, allowing them to batch pulses into discrete
/// topographical windows based on stimulus frequency.
///
/// Unlike a raw [Cell], this instruction represents a stateless **Logic Gate**
/// that evolves individual stimuli into collection-based pulses.
///
/// ### When to use
/// - **Batch Processing**: Grouping individual data pulses into chunks for
///   database writes or network payloads.
/// - **Sliding Windows**: Creating overlapping sequences of data to perform
///   rolling averages or trend analysis.
/// - **Topographical Throttling**: Naturally slowing down downstream
///   propagation by requiring multiple input pulses to produce one output.
///
/// ### How it works
/// 1. **Stimulus Reception**: Every incoming pulse is evaluated for
///    type integrity [S].
/// 2. **Logic Batching**: It inherits the tumbling or overlapping
///    mechanics of [BufferCount], accumulating stimuli until the
///    [size] threshold is reached.
/// 3. **Materialization**: Once the count is met, the gate evolves
///    the accumulated stimuli into a single windowed [Pulse<List<S>>].
/// 4. **Provenance Preservation**: The evolved pulse inherits the source,
///    priority, and metadata from the trigger pulse, tagged with
///    the `'BufferCount'` step.
///
/// ### Skip & Overlap Mechanics
/// - **Tumbling** ([skip] == `size`): Contiguous windows with no overlap.
/// - **Overlapping** ([skip] < `size`): Windows share payloads, creating
///   a sliding effect.
/// - **Gapped** ([skip] > `size`): Certain stimuli are dropped between
///   materialization cycles.
///
/// ### Type Parameters
/// * [S]: **Stimulus Payload Type.** The type of data contained within
///   the incoming pulses.
///
/// ### See Also
/// * [BufferCount]: The primary implementation for count-based logic batching.
/// * [FlowInstruction]: The base interface for logic blueprints.
class BufferWithCount<S> extends BufferCount<S> {

  /// Synthesizes a **Count-Based Topographical Alias**—a specialized
  /// constructor designed for Rx-compatible pulse orchestration.
  ///
  /// [BufferWithCount] is a semantic alias for [BufferCount]. It enables
  /// developers to batch pulses into discrete topographical windows
  /// based on stimulus frequency, providing a familiar entry point for
  /// those transitioning from traditional ReactiveX implementations.
  ///
  /// ### How it works
  /// 1. **Stimulus Reception**: Every incoming pulse is evaluated for
  ///    type integrity [S].
  /// 2. **Logic Batching**: It inherits the tumbling or overlapping
  ///    mechanics of [BufferCount], accumulating stimuli until the
  ///    [size] threshold is reached.
  /// 3. **Materialization**: Once the count is met, the gate evolves
  ///    the accumulated stimuli into a single windowed pulse tagged
  ///    with the `'BufferCount'` step.
  ///
  /// ### Parameters
  /// - [size]: **Window Capacity.** The number of stimuli required to
  ///   materialize a window.
  /// - [skip]: **Advance Offset.** Determines how many pulses to advance
  ///   the starting point of the next window. Defaults to [size].
  /// - [onError]: **Integrity Handler.** A specialized callback invoked if
  ///   a pulse payload fails to match the expected type [S].
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the instruction chain for auditing and tracing.
  ///
  /// ### See Also
  /// - [BufferCount]: The primary implementation for count-based logic batching.
  BufferWithCount(
      super.size, {
        super.skip,
        super.onError,
        super.user,
      });
}

// ─────────────────────────────────────────────────────────────
// BufferTime - Time-Based Buffering
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that flushes the buffer every [duration]
/// after the first typed pulse (Rx `bufferTime`).
///
/// [BufferTime] batches incoming values into time-based buffers.
/// The clock starts on the first typed pulse and flushes the buffer
/// every [duration].
///
/// ### When to use
/// Use [BufferTime] when you need to batch values by time.
///
/// - **Rate Limiting**: Limiting the rate of processed items.
/// - **Time-Based Batching**: Grouping items by time interval.
/// - **Sliding Windows**: Implementing sliding time windows.
/// - **Throttling**: Throttling processing to a fixed rate.
/// - **Metrics**: Aggregating metrics over time.
/// - **Logging**: Batching log entries by time.
///
/// ### Example: Time-Based Buffering
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final buffers = BufferTime<int>(
///   Duration(seconds: 1),
///   emitEmpty: false,
/// ).toHandle(source: input.cell);
///
/// // Emits accumulated values every second
/// // Outputs: [1, 2], [3, 4], [5]
/// ```
///
/// ### How it works
/// 1. The first typed pulse starts the timer.
/// 2. Each pulse's payload is added to the buffer.
/// 3. Every [duration], the buffer is emitted as a list.
/// 4. The buffer is cleared after emission.
/// 5. If [emitEmpty] is `false`, empty buffers are skipped.
/// 6. Each emitted buffer gets the step `'BufferTime'` for provenance.
///
/// ### Non‑obvious
/// - **Lazy Start**: The timer starts on the first pulse, not on
///   instruction creation.
/// - **Continuous**: The timer continues indefinitely until disposed.
/// - **Empty Skip**: [emitEmpty] controls whether empty buffers are
///   emitted.
/// - **Order Preservation**: Values are emitted in the order they
///   arrived within each buffer.
/// - **Provenance Preservation**: Each buffer preserves the source
///   cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [duration]: **Buffer Duration.** The time interval for each buffer.
/// - [emitEmpty]: **Emit Empty Buffers.** If `true`, empty buffers are
///   emitted as empty lists. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits time-based buffers.
///
/// ### See Also:
/// - [BufferCount]: For count-based buffering.
/// - [BufferWhen]: For trigger-based buffering.
/// - [BufferWithPredicate]: For predicate-based buffering.
/// - [BufferWithTimeAndCount]: For time or count buffering.
class BufferTime<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Temporal Logic Gate** designed to batch pulses
  /// into discrete topographical windows based on elapsed time.
  ///
  /// [BufferTime] (analogous to `bufferTime` in Rx) monitors the stimulus
  /// stream and accumulates payloads into an internal buffer. It utilizes
  /// a periodic materialization strategy, flushing the accumulated stimuli
  /// as a single [Pulse<List<S>>] every [duration].
  ///
  /// ### How it works
  /// 1. **Lazy Synchronization**: The internal temporal orchestrator is
  ///    materialized only upon the arrival of the first valid stimulus.
  /// 2. **Stimulus Accumulation**: Incoming pulses are evaluated for
  ///    type integrity [S] and stored within the gate's logic buffer.
  /// 3. **Periodic Materialization**: Every [duration], the accumulated
  ///    stimuli are evolved into a windowed pulse.
  /// 4. **Provenance Preservation**: The materialized pulse inherits the
  ///    source, priority, and metadata from the most recent stimulus in the
  ///    buffer, tagged with the `'BufferTime'` step.
  /// 5. **Topographical Reset**: The buffer is cleared immediately
  ///    following each materialization cycle.
  ///
  /// ### Non‑obvious
  /// - **Timer Materialization**: The timer is not active until the first
  ///   stimulus enters the topography, preventing unnecessary resource
  ///   consumption in idle branches.
  /// - **Vacuum Emission**: If [emitEmpty] is `false`, the gate suppresses
  ///   materialization if no pulses arrived during the interval.
  ///
  /// ### Parameters
  /// - [duration]: **Temporal Interval.** The time window between
  ///   materialization cycles.
  /// - [emitEmpty]: **Vacuum Emission.** If `true`, the gate will emit
  ///   empty pulses even when no stimuli have arrived during the interval.
  ///   Defaults to `false`.
  /// - [onError]: **Integrity Handler.** A specialized callback invoked if
  ///   a pulse payload fails to match the expected type [S].
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the instruction chain for auditing and tracing.
  ///
  /// ### Example: Temporal Batching
  /// ```dart
  /// // Batches events every 500ms
  /// final batchGate = BufferTime<Event>(Duration(milliseconds: 500));
  /// ```
  ///
  /// ### See Also
  /// - [BufferCount]: For batching based on stimulus frequency.
  /// - [BufferWithTimeAndCount]: For hybrid temporal and frequency constraints.
  /// - [BufferWhen]: For trigger-based topographical flushes.
  BufferTime(
      Duration duration, {
        bool emitEmpty = false,
        BufferErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final buf = <S>[];
      final emit = _Emit();
      var armed = false;
      Pulse? last;

      void flush() {
        if (buf.isEmpty && !emitEmpty) return;
        final trigger = last;
        if (trigger == null || emit.future == null) return;
        emit.future!(
          result: _buf<S>(buf, trigger, emit.cell, 'BufferTime'),
          token: emit.token,
        );
        buf.clear();
      }

      return (pulse, {cell, user, future, token}) {
        emit.future = future;
        emit.token = token;
        emit.cell = cell;
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        last = typed;
        buf.add(typed.payload as S);
        if (!armed) {
          armed = true;
          Timer.periodic(duration, (_) => flush());
        }
        return null;
      };
    })(),
    user: user,
  );
}

/// Synthesizes a **Temporal Topographical Alias**—a specialized
/// instruction wrapper designed for Rx-compatible pulse orchestration.
///
/// [BufferWithTime] is a semantic alias for [BufferTime]. It provides a
/// familiar entry point for developers transitioning from traditional
/// ReactiveX implementations, allowing them to batch pulses into discrete
/// topographical windows based on elapsed time.
///
/// Unlike a live node, this instruction represents a stateless **Logic Gate**
/// that evolves individual stimuli into collection-based pulses periodically.
///
/// ### When to use
/// - **Time-Based Batching**: Grouping items by a fixed temporal interval
///   for logging or metrics.
/// - **Temporal Throttling**: Controlling the rate of downstream propagation
///   by emitting results only at specific time intervals.
/// - **Resource Coordination**: Reducing the frequency of expensive operations
///   by processing stimuli in temporal chunks.
///
/// ### How it works
/// 1. **Lazy Synchronization**: The internal temporal orchestrator is
///    materialized only upon the arrival of the first valid stimulus.
/// 2. **Stimulus Accumulation**: Incoming pulses are evaluated for
///    type integrity [S] and stored within the gate's logic buffer.
/// 3. **Periodic Materialization**: Every [duration], the accumulated
///    stimuli are evolved into a windowed [Pulse<List<S>>].
/// 4. **Provenance Preservation**: The evolved pulse inherits the source,
///    priority, and metadata from the trigger pulse, tagged with the
///    `'BufferTime'` step.
/// 5. **Topographical Reset**: The buffer is cleared immediately
///    following each materialization cycle.
///
/// ### Non‑obvious
/// - **Resource Efficiency**: The timer is not active until the first
///   stimulus enters the topography, preventing waste in idle branches.
/// - **Vacuum Emission**: If [emitEmpty] is `false`, the gate suppresses
///   materialization if no pulses arrived during the interval.
///
/// ### Type Parameters
/// * [S]: **Stimulus Payload Type.** The type of data contained within
///   the incoming pulses.
///
/// ### See Also
/// * [BufferTime]: The primary implementation for temporal logic batching.
/// * [BufferCount]: For batching based on stimulus frequency.
class BufferWithTime<S> extends BufferTime<S> {

  /// Synthesizes a **Temporal Topographical Alias**—a specialized
  /// constructor designed for Rx-compatible pulse orchestration.
  ///
  /// [BufferWithTime] is a semantic alias for [BufferTime]. It enables
  /// developers to batch pulses into discrete topographical windows
  /// based on elapsed time.
  ///
  /// ### Parameters
  /// - [duration]: **Temporal Interval.** The time window between
  ///   materialization cycles.
  /// - [emitEmpty]: **Vacuum Emission.** If `true`, the gate will emit
  ///   empty pulses even when no stimuli have arrived during the interval.
  ///   Defaults to `false`.
  /// - [onError]: **Integrity Handler.** A specialized callback invoked if
  ///   a pulse payload fails to match the expected type [S].
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the instruction chain for auditing and tracing.
  BufferWithTime(
      super.duration, {
        super.emitEmpty,
        super.onError,
        super.user,
      });
}

// ─────────────────────────────────────────────────────────────
// BufferWithTimeAndCount - Time or Count Buffering
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that flushes when the buffer hits [count]
/// **or** [duration] elapses (Rx `bufferTime` with a max length).
///
/// [BufferWithTimeAndCount] combines time-based and count-based
/// buffering. The buffer flushes when either condition is met.
///
/// ### When to use
/// Use [BufferWithTimeAndCount] when you need to flush on time
/// or count, whichever comes first.
///
/// - **Maximum Latency**: Ensuring buffers don't get too old.
/// - **Maximum Size**: Ensuring buffers don't get too large.
/// - **Hybrid Batching**: Batching with both time and size constraints.
/// - **Resource Management**: Managing buffer memory and latency.
/// - **Performance**: Balancing throughput and latency.
///
/// ### Example: Time or Count Buffering
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final buffers = BufferWithTimeAndCount<int>(
///   duration: Duration(seconds: 1),
///   count: 10,
/// ).toHandle(source: input.cell);
///
/// // Flushes every second OR when 10 items accumulate
/// ```
///
/// ### How it works
/// 1. The first typed pulse starts the timer.
/// 2. Each pulse's payload is added to the buffer.
/// 3. If the buffer reaches [count], it flushes immediately.
/// 4. If [duration] elapses, it flushes (even if count not reached).
/// 5. The buffer is cleared after each flush.
/// 6. The timer resets after each flush.
/// 7. Each emitted buffer gets the step `'BufferWithTimeAndCount.time'`
///    or `'BufferWithTimeAndCount.count'` for provenance.
///
/// ### Non‑obvious
/// - **Two Triggers**: Either time or count can trigger a flush.
/// - **Timer Reset**: The timer resets after each flush.
/// - **Count Priority**: Count triggers flush immediately.
/// - **Provenance Preservation**: Each buffer preserves the source
///   cell, type, and priority from the trigger pulse.
/// - **Distinct Steps**: Different provenance steps for time and count.
///
/// ### Parameters:
/// - [duration]: **Time Limit.** The maximum time between flushes.
/// - [count]: **Size Limit.** The maximum number of items in a buffer.
/// - [emitEmpty]: **Emit Empty Buffers.** If `true`, empty buffers are
///   emitted as empty lists. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that flushes on time or count.
///
/// ### See Also:
/// - [BufferCount]: For count-based buffering.
/// - [BufferTime]: For time-based buffering.
/// - [BufferWhen]: For trigger-based buffering.
/// - [BufferWithPredicate]: For predicate-based buffering.
class BufferWithTimeAndCount<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Dual-Threshold Logic Gate** for hybrid pulse batching.
  ///
  /// This constructor initializes an orchestrator that materializes a window
  /// pulse as soon as either the specified [duration] elapses or the
  /// stimulus [count] is met.
  ///
  /// **Parameters:**
  /// - [duration]: The maximum **Temporal Limit** between flushes.
  /// - [count]: The maximum **Window Capacity** before an immediate flush.
  /// - [emitEmpty]: If `true`, materializes a pulse even if no stimuli
  ///   arrived during the interval.
  /// - [onError]: Invoked if a stimulus violates type integrity [S].
  /// - [user]: Optional metadata preserved across the topography.
  BufferWithTimeAndCount({
    required Duration duration,
    required int count,
    bool emitEmpty = false,
    BufferErrorHandler? onError,
    dynamic user,
  }) : super.future(
    (() {
      final buf = <S>[];
      final emit = _Emit();
      Timer? timer;
      Pulse? last;

      void flush(String step) {
        if (buf.isEmpty && !emitEmpty) return;
        final trigger = last;
        if (trigger == null || emit.future == null) return;
        emit.future!(
          result: _buf<S>(buf, trigger, emit.cell, step),
          token: emit.token,
        );
        buf.clear();
        timer?.cancel();
        timer = null;
      }

      void arm() {
        timer?.cancel();
        timer = Timer(duration, () => flush('BufferWithTimeAndCount.time'));
      }

      return (pulse, {cell, user, future, token}) {
        emit.future = future;
        emit.token = token;
        emit.cell = cell;
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        last = typed;
        final starting = buf.isEmpty;
        buf.add(typed.payload as S);
        if (starting) arm();
        if (buf.length >= count) {
          flush('BufferWithTimeAndCount.count');
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// BufferWhen - Trigger-Based Buffering
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that flushes the buffer when [closer] emits
/// (Rx `buffer` / `bufferWhen`).
///
/// [BufferWhen] batches incoming values until an external trigger
/// pulses, then emits the accumulated values as a list.
///
/// ### When to use
/// Use [BufferWhen] when you need to batch values based on external
/// triggers.
///
/// - **Manual Batching**: Batching on user action or button click.
/// - **Event-Driven**: Batching on specific events.
/// - **Request/Response**: Batching until a response arrives.
/// - **Conditional Batching**: Batching when a condition is met.
/// - **Interactive Batching**: Batching based on user interaction.
///
/// ### Example: Manual Batching
/// ```dart
/// final items = Cell.ingress<String>();
/// final flush = Cell.ingress<void>();
///
/// final buffers = BufferWhen<String>(flush.cell)
///     .toHandle(source: items.cell);
///
/// items.emit('a'); // buffered
/// items.emit('b'); // buffered
/// flush.emit(null); // -> ['a', 'b']
/// ```
///
/// ### How it works
/// 1. Each incoming pulse's payload is added to the buffer.
/// 2. When the [closer] cell emits a pulse:
///    a. The buffer is emitted as a list.
///    b. The buffer is cleared.
/// 3. If [emitEmpty] is `true`, empty buffers are emitted.
/// 4. Each emitted buffer gets the step `'BufferWhen'` for provenance.
///
/// ### Non‑obvious
/// - **Multiple Closes**: The closer can be triggered repeatedly.
/// - **Continuous Buffering**: After a close, buffering continues.
/// - **Empty Control**: [emitEmpty] controls empty buffer emission.
/// - **Provenance Preservation**: Each buffer preserves the source
///   cell, type, and priority from the trigger pulse.
/// - **Closer Type**: The closer can be any [Cell] that emits pulses.
///
/// ### Parameters:
/// - [closer]: **Closer Cell.** The cell that triggers buffer emission
///   when it pulses.
/// - [emitEmpty]: **Emit Empty Buffers.** If `true`, empty buffers are
///   emitted as empty lists. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits trigger-based buffers.
///
/// ### See Also:
/// - [BufferCount]: For count-based buffering.
/// - [BufferTime]: For time-based buffering.
/// - [BufferWithPredicate]: For predicate-based buffering.
/// - [BufferWithTimeAndCount]: For time or count buffering.
class BufferWhen<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Boundary-Driven Logic Gate** for manual pulse batching.
  ///
  /// This constructor initializes an orchestrator that materializes a window
  /// whenever the provided [closer] cell emits a pulse.
  ///
  /// **Parameters:**
  /// - [closer]: The **Boundary Stimulus.** A cell that triggers a flush.
  /// - [emitEmpty]: If `true`, materializes a pulse even if the buffer is
  ///   empty when the trigger arrives.
  /// - [onError]: Invoked if a stimulus violates type integrity [S].
  /// - [user]: Optional metadata preserved across the topography.
  BufferWhen(
      Cell closer, {
        bool emitEmpty = false,
        BufferErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final buf = <S>[];
      final emit = _Emit();
      var armed = false;
      Pulse? last;

      void flush(Pulse boundary) {
        if (buf.isEmpty && !emitEmpty) return;
        emit.future?.call(
          result: _buf<S>(
            buf,
            last ?? boundary,
            emit.cell,
            'BufferWhen',
          ),
          token: emit.token,
        );
        buf.clear();
      }

      return (pulse, {cell, user, future, token}) {
        emit.future = future;
        emit.token = token;
        emit.cell = cell;
        if (!armed) {
          armed = true;
          Cell.observe(
            source: closer,
            effect: (Pulse boundary) => flush(boundary),
          );
        }
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        last = typed;
        buf.add(typed.payload as S);
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// BufferWithPredicate - Predicate-Based Buffering
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that closes the buffer when [test] is true
/// (Rx `buffer` + close).
///
/// [BufferWithPredicate] batches incoming values until the predicate
/// returns `true`, then emits the accumulated values as a list.
///
/// ### When to use
/// Use [BufferWithPredicate] when you need to batch based on a
/// condition.
///
/// - **Conditional Batching**: Batching when a condition is met.
/// - **Data Validation**: Batching until validation passes.
/// - **State Changes**: Batching on state changes.
/// - **Thresholds**: Batching when thresholds are reached.
/// - **Pattern Detection**: Batching when patterns are detected.
///
/// ### Example: Batching Until Even Number
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final buffers = BufferWithPredicate<int>(
///   (n) => n.isEven,
/// ).toHandle(source: input.cell);
///
/// input.emit(1); // buffered
/// input.emit(2); // -> [1, 2] (even triggers flush)
/// input.emit(3); // buffered
/// input.emit(4); // -> [3, 4]
/// ```
///
/// ### Example: Batching on Threshold
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final buffers = BufferWithPredicate<int>(
///   (n) => n > 100,
/// ).toHandle(source: input.cell);
///
/// // Buffers until a value > 100 arrives
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. The [test] predicate is called with the payload.
/// 3. If [test] returns `false`, the value is added to the buffer.
/// 4. If [test] returns `true`:
///    a. If [includeTrigger] is `true`, the value is added.
///    b. The buffer is emitted as a list.
///    c. The buffer is cleared.
/// 5. Each emitted buffer gets the step `'BufferWithPredicate'` for provenance.
///
/// ### Non‑obvious
/// - **Trigger Inclusion**: [includeTrigger] controls whether the
///   triggering value is included in the buffer.
/// - **Empty Skip**: Empty buffers are not emitted.
/// - **Predicate Evaluation**: The predicate is evaluated on each value.
/// - **Provenance Preservation**: Each buffer preserves the source
///   cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [test]: **Predicate Function.** Called with each typed payload,
///   returns `true` to close the buffer.
/// - [includeTrigger]: **Include Trigger Value.** If `true`, the value
///   that triggers the close is included in the buffer. Defaults to `true`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that buffers until a predicate is true.
///
/// ### See Also:
/// - [BufferCount]: For count-based buffering.
/// - [BufferTime]: For time-based buffering.
/// - [BufferWhen]: For trigger-based buffering.
/// - [BufferWithTimeAndCount]: For time or count buffering.
class BufferWithPredicate<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Conditional Logic Gate** designed for predicate-driven
  /// pulse batching.
  ///
  /// This constructor initializes an orchestrator that accumulates stimuli
  /// into a logic buffer until the [test] predicate returns `true`, triggering
  /// the materialization of a windowed pulse.
  ///
  /// **Parameters:**
  /// - [test]: **The Predicate Orchestrator.** A closure evaluated against
  ///   each payload to determine the topographical boundary.
  /// - [includeTrigger]: If `true`, the stimulus that satisfied the predicate
  ///   is included in the buffer before materialization.
  /// - [onError]: Invoked if the predicate throws or a stimulus violates
  ///   type integrity [S].
  /// - [user]: Optional flyweight metadata preserved across the topography
  ///   for auditing.
  BufferWithPredicate(
      bool Function(S value) test, {
        bool includeTrigger = true,
        BufferErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final buf = <S>[];
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final value = typed.payload as S;
        late final bool close;
        try {
          close = test(value);
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        if (close) {
          if (includeTrigger) buf.add(value);
          if (buf.isEmpty) return null;
          final window = List<S>.from(buf);
          buf.clear();
          return _buf<S>(window, typed, cell, 'BufferWithPredicate');
        }
        buf.add(value);
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [BufferCount] instruction and related operators
/// showing their behavior in various buffering scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Buffer Operators Demo ─────────────────────────────────────
///
/// 1. BufferCount
///    [BufferCount] [1, 2]
///    [BufferCount] [3, 4]
///
/// 2. BufferTime
///    [BufferTime] [1, 2]
///
/// 3. BufferWhen
///    [BufferWhen] [a, b]
///
/// 4. BufferWithPredicate
///    [BufferWithPredicate] [1, 2]
///
/// 5. BufferWithTimeAndCount - count wins
///    [BufferWithTimeAndCount] [1, 2]
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
/// 1. **BufferCount - Count-Based Buffering**: Shows count-based
///    buffering where every 2 items are batched together. Values
///    1, 2, 3, 4 are batched as [1, 2] and [3, 4].
///
/// 2. **BufferTime - Time-Based Buffering**: Shows time-based
///    buffering where values are batched by time. Values emitted
///    within the time window are batched together.
///
/// 3. **BufferWhen - Trigger-Based Buffering**: Shows trigger-based
///    buffering where the buffer is emitted when the closer cell
///    pulses. Values 'a' and 'b' are batched until the flush trigger.
///
/// 4. **BufferWithPredicate - Predicate-Based Buffering**: Shows
///    predicate-based buffering where the buffer closes when an
///    even number arrives. Values 1 and 2 are batched as [1, 2].
///
/// 5. **BufferWithTimeAndCount - Time or Count**: Shows hybrid
///    buffering where count triggers the flush (count wins).
///    Values 1 and 2 reach the count of 2 and flush immediately.
///
/// ### Key Takeaways
/// - Buffer operators batch values into lists.
/// - BufferCount batches by item count.
/// - BufferTime batches by time duration.
/// - BufferWhen batches on external triggers.
/// - BufferWithPredicate batches until a predicate is true.
/// - BufferWithTimeAndCount flushes on time or count.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Buffers are emitted as lists for further processing.
///
/// ### Note on Timing
/// The demo uses short delays (40ms) for quick execution. In production,
/// you would typically use longer durations for time-based buffering.
Future<void> main() async {
  print('── Buffer Operators Demo ─────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. BufferCount - Count-Based Buffering
  // ─────────────────────────────────────────────────────────────────────
  print('1. BufferCount');

  final nums = Cell.ingress<int>();

  final pairs = BufferCount<int>(2).toHandle(source: nums.cell);

  final pObs = Cell.observe(
    source: pairs.cell,
    effect: (Pulse p) => print('   [BufferCount] ${p.payload}'),
  );

  for (final n in [1, 2, 3, 4]) {
    await nums.emitAsync(n);
  }

  pObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. BufferTime - Time-Based Buffering
  // ─────────────────────────────────────────────────────────────────────
  print('2. BufferTime');

  final timed = Cell.ingress<int>();

  final buckets = BufferTime<int>(
    const Duration(milliseconds: 40),
  ).toHandle(source: timed.cell);

  final tObs = Cell.observe(
    source: buckets.cell,
    effect: (Pulse p) => print('   [BufferTime] ${p.payload}'),
  );

  await timed.emitAsync(1);
  await timed.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 60));

  tObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. BufferWhen - Trigger-Based Buffering
  // ─────────────────────────────────────────────────────────────────────
  print('3. BufferWhen');

  final letters = Cell.ingress<String>();
  final close = Cell.ingress<void>();

  final when = BufferWhen<String>(close.cell).toHandle(source: letters.cell);

  final wObs = Cell.observe(
    source: when.cell,
    effect: (Pulse p) => print('   [BufferWhen] ${p.payload}'),
  );

  await letters.emitAsync('a');
  await letters.emitAsync('b');
  await close.emitAsync(null);

  wObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. BufferWithPredicate - Predicate-Based Buffering
  // ─────────────────────────────────────────────────────────────────────
  print('4. BufferWithPredicate');

  final seq = Cell.ingress<int>();

  final until = BufferWithPredicate<int>(
        (n) => n.isEven,
  ).toHandle(source: seq.cell);

  final uObs = Cell.observe(
    source: until.cell,
    effect: (Pulse p) => print('   [BufferWithPredicate] ${p.payload}'),
  );

  await seq.emitAsync(1);
  await seq.emitAsync(2);

  uObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 5. BufferWithTimeAndCount - Time or Count
  // ─────────────────────────────────────────────────────────────────────
  print('5. BufferWithTimeAndCount - count wins');

  final mixed = Cell.ingress<int>();

  final both = BufferWithTimeAndCount<int>(
    duration: const Duration(milliseconds: 80),
    count: 2,
  ).toHandle(source: mixed.cell);

  final bothObs = Cell.observe(
    source: both.cell,
    effect: (Pulse p) => print('   [BufferWithTimeAndCount] ${p.payload}'),
  );

  await mixed.emitAsync(1);
  await mixed.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  bothObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}