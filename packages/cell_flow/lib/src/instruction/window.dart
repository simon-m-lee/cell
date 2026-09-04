// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Window Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that batch values into windows (Rx `window` family).
///
/// Each closed window is emitted as a [List]. There is no inner Cell
/// per window — the list *is* the window.
///
/// | Operator | Rx analogue | Closes when |
/// |---|---|---|
/// | [WindowCount] | `windowCount` / `bufferCount` | [size] items ([skip] optional) |
/// | [WindowSize] | alias of [WindowCount] | same |
/// | [WindowTime] | `windowTime` / `bufferTime` | [duration] elapses |
/// | [WindowWhen] | `window` / `bufferWhen` | [closer] Cell pulses |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for window operators.
///
/// Called when an error occurs during window operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = WindowErrorHandler((error, stack) {
///   print('Window error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef WindowErrorHandler = void Function(Object error, StackTrace? stackTrace);

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
      WindowErrorHandler? onError,
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

/// Helper to create a window pulse with proper provenance.
Pulse<List<S>> _window<S>(
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

/// Internal state for window operators that need to emit asynchronously.
///
/// [_EmitState] stores the continuation callback and context for
/// operators that emit windows asynchronously, such as [WindowTime]
/// and [WindowWhen].
///
/// ### When to use
/// This is an internal implementation detail. You don't need to use it
/// directly in application code.
///
/// ### How it works
/// 1. Stores the [future] continuation callback.
/// 2. Stores the [token] for identifying the continuation.
/// 3. Stores the [cell] context for pulse creation.
///
/// ### Non‑obvious
/// - **Async Emission**: Used for operators that emit on a timer or
///   external trigger.
/// - **Continuation Token**: The token identifies which instruction
///   should receive the emitted pulse.
/// - **Cell Context**: The cell provides provenance information.
class _EmitState {
  void Function({required Pulse? result, required dynamic token})? future;
  dynamic token;
  Cell? cell;
}

// ─────────────────────────────────────────────────────────────
// WindowCount - Count-Based Window
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a list every [size] items
/// (Rx `bufferCount` / `windowCount`).
///
/// [WindowCount] batches incoming values into windows of size [size].
/// When the window is full, it's emitted as a list and cleared.
/// The [skip] parameter controls how far to advance the start of
/// the next window.
///
/// ### When to use
/// Use [WindowCount] when you need to batch values by count.
///
/// - **Batching**: Grouping items for batch processing.
/// - **Pagination**: Collecting items into pages.
/// - **Chunking**: Splitting data into chunks.
/// - **Aggregation**: Aggregating a fixed number of items.
/// - **Buffering**: Buffering items for efficient processing.
/// - **Bulk Operations**: Collecting items for bulk operations.
///
/// ### Choosing Between Window Operators
/// - **Use [WindowCount]** for **Count-Based Windows**: When you need
///   to batch by item count.
/// - **Use [WindowTime]** for **Time-Based Windows**: When you need
///   to batch by time duration.
/// - **Use [WindowWhen]** for **Trigger-Based Windows**: When you need
///   to batch based on external triggers.
/// - **Use [WindowSize]** as an alias of [WindowCount].
///
/// ### Comparison with Other Operators
/// | Operator | Trigger | Window Size | Overlap |
/// |----------|---------|-------------|---------|
/// | **WindowCount** | Item count | Fixed | Optional |
/// | **WindowTime** | Time duration | Variable | No |
/// | **WindowWhen** | External pulse | Variable | No |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. The payload is added to the current window buffer.
/// 3. When the buffer reaches [size], the window is emitted.
/// 4. The buffer is cleared or advanced by [skip].
/// 5. If [skip] is less than [size], windows overlap.
/// 6. If [skip] is greater than [size], items are skipped.
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
/// - **Overlap**: When [skip] < [size], windows overlap.
/// - **Gaps**: When [skip] > [size], some items are skipped.
/// - **Type Safety**: The instruction is generic over [S].
/// - **Provenance Preservation**: Each window preserves the source
///   cell, type, and priority from the trigger pulse.
/// - **List Copy**: The emitted list is a copy of the buffer.
///
/// ### Example: Tumbling Windows
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final windows = WindowCount<int>(3)
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
/// ### Example: Overlapping Windows
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final windows = WindowCount<int>(3, skip: 1)
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
/// - [size]: **Window Size.** The number of items in each window.
/// - [skip]: **Skip Count.** How many items to advance for the next
///   window. Defaults to [size] (tumbling).
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits windows of [size] items.
///
/// ### See Also:
/// - [WindowSize]: Alias of [WindowCount].
/// - [WindowTime]: For time-based windows.
/// - [WindowWhen]: For trigger-based windows.
class WindowCount<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  WindowCount(
      int size, {
        int? skip,
        WindowErrorHandler? onError,
        dynamic user,
      }) : super(
    (() {
      final step = skip == null || skip == size ? size : skip;
      final buf = <S>[];
      var seen = 0;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        buf.add(typed.payload as S);
        seen++;
        if (buf.length < size) return null;
        final window = List<S>.from(buf);
        final drop = step < 1 ? size : step;
        if (drop >= buf.length) {
          buf.clear();
        } else {
          buf.removeRange(0, drop);
        }
        return _window<S>(window, typed, cell, 'WindowCount');
      };
    })(),
    user: user,
  );
}

/// Alias of [WindowCount] for Rx compatibility.
///
/// [WindowSize] is an alias for [WindowCount] that provides the same
/// count-based windowing functionality. Use whichever name feels more
/// natural for your use case.
///
/// ### When to use
/// Use [WindowSize] when you prefer the name "size" over "count" for
/// describing the window capacity.
///
/// ### Example
/// ```dart
/// final windows = WindowSize<int>(3)
///     .toHandle(source: input.cell);
/// // Same as WindowCount<int>(3)
/// ```
///
/// ### See Also:
/// - [WindowCount]: The primary implementation.
class WindowSize<S> extends WindowCount<S> {
  WindowSize(
      super.size, {
        super.skip,
        super.onError,
        super.user,
      });
}

// ─────────────────────────────────────────────────────────────
// WindowTime - Time-Based Window
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits the current buffer every [duration]
/// (Rx `bufferTime` / `windowTime`).
///
/// [WindowTime] batches incoming values into time-based windows.
/// The clock starts on the first typed pulse and emits the accumulated
/// values every [duration].
///
/// ### When to use
/// Use [WindowTime] when you need to batch values by time.
///
/// - **Rate Limiting**: Limiting the rate of processed items.
/// - **Time-Based Batching**: Grouping items by time interval.
/// - **Sliding Windows**: Implementing sliding time windows.
/// - **Throttling**: Throttling processing to a fixed rate.
/// - **Metrics**: Aggregating metrics over time.
/// - **Logging**: Batching log entries by time.
///
/// ### Example: Time-Based Batching
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final windows = WindowTime<int>(
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
/// 5. If [emitEmpty] is `false`, empty windows are skipped.
/// 6. The timer continues until the instruction is disposed.
///
/// ### Non‑obvious
/// - **Lazy Start**: The timer starts on the first pulse, not on
///   instruction creation.
/// - **Continuous**: The timer continues indefinitely until disposed.
/// - **Empty Skip**: [emitEmpty] controls whether empty windows are
///   emitted.
/// - **Order Preservation**: Values are emitted in the order they
///   arrived within each window.
/// - **Provenance Preservation**: Each window preserves the source
///   cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [duration]: **Window Duration.** The time interval for each window.
/// - [emitEmpty]: **Emit Empty Windows.** If `true`, empty windows are
///   emitted as empty lists. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits time-based windows.
///
/// ### See Also:
/// - [WindowCount]: For count-based windows.
/// - [WindowWhen]: For trigger-based windows.
/// - [Interval]: For periodic emissions without batching.
class WindowTime<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  WindowTime(
      Duration duration, {
        bool emitEmpty = false,
        WindowErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final buf = <S>[];
      final emit = _EmitState();
      var armed = false;
      Pulse? last;

      void flush() {
        if (buf.isEmpty && !emitEmpty) return;
        final trigger = last;
        if (trigger == null || emit.future == null) return;
        emit.future!(
          result: _window<S>(buf, trigger, emit.cell, 'WindowTime'),
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

// ─────────────────────────────────────────────────────────────
// WindowWhen - Trigger-Based Window
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that collects values until a [closer] cell
/// pulses, then emits the buffer (Rx `buffer` / `window` with a
/// boundary notifier).
///
/// [WindowWhen] batches incoming values until an external trigger
/// pulses, then emits the accumulated values as a list.
///
/// ### When to use
/// Use [WindowWhen] when you need to batch values based on external
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
/// final windows = WindowWhen<String>(flush.cell)
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
/// 4. The closer can be triggered multiple times.
///
/// ### Non‑obvious
/// - **Multiple Closes**: The closer can be triggered repeatedly.
/// - **Continuous Batching**: After a close, batching continues.
/// - **Empty Control**: [emitEmpty] controls empty window emission.
/// - **Provenance Preservation**: Each window preserves the source
///   cell, type, and priority from the trigger pulse.
/// - **Closer Type**: The closer can be any [Cell] that emits pulses.
///
/// ### Parameters:
/// - [closer]: **Closer Cell.** The cell that triggers window emission
///   when it pulses.
/// - [emitEmpty]: **Emit Empty Windows.** If `true`, empty windows are
///   emitted as empty lists. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits trigger-based windows.
///
/// ### See Also:
/// - [WindowCount]: For count-based windows.
/// - [WindowTime]: For time-based windows.
/// - [Hub]: For routing pulses to different handlers.
class WindowWhen<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  WindowWhen(
      Cell closer, {
        bool emitEmpty = false,
        WindowErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final buf = <S>[];
      final emit = _EmitState();
      var armed = false;
      Pulse? last;

      void flush(Pulse boundary) {
        if (buf.isEmpty && !emitEmpty) return;
        emit.future?.call(
          result: _window<S>(
            buf,
            last ?? boundary,
            emit.cell,
            'WindowWhen',
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
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [WindowCount] instruction and related operators
/// showing their behavior in various batching scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Window Operators Demo ─────────────────────────────────────
///
/// 1. WindowCount - pairs
///    [WindowCount] [1, 2]
///    [WindowCount] [3, 4]
///
/// 2. WindowSize - overlapping
///    [WindowSize] [1, 2]
///    [WindowSize] [2, 3]
///
/// 3. WindowTime
///    [WindowTime] [1, 2]
///
/// 4. WindowWhen
///    [WindowWhen] [a, b]
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
/// 1. **WindowCount - Pairs**: Shows count-based windowing where
///    every 2 items are batched together. Values 1, 2, 3, 4 are
///    batched as [1, 2] and [3, 4].
///
/// 2. **WindowSize - Overlapping**: Shows overlapping windows where
///    `skip` is less than `size`. With size=2 and skip=1, values
///    1, 2, 3 produce [1, 2] and [2, 3].
///
/// 3. **WindowTime - Time-Based**: Shows time-based windowing where
///    values are batched by time. Values emitted within the time
///    window are batched together.
///
/// 4. **WindowWhen - Trigger-Based**: Shows trigger-based windowing
///    where the buffer is emitted when the closer cell pulses.
///    Values 'a' and 'b' are batched until the flush trigger.
///
/// ### Key Takeaways
/// - Window operators batch values into lists.
/// - WindowCount batches by item count.
/// - WindowTime batches by time duration.
/// - WindowWhen batches on external triggers.
/// - Overlapping windows with WindowCount's skip parameter.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Windows are emitted as lists for further processing.
///
/// ### Note on Timing
/// The demo uses short delays (40ms) for quick execution. In production,
/// you would typically use longer durations for time-based windows.
Future<void> main() async {
  print('── Window Operators Demo ─────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. WindowCount - Pairs
  // ─────────────────────────────────────────────────────────────────────
  print('1. WindowCount - pairs');

  final nums = Cell.ingress<int>();

  final pairs = WindowCount<int>(2).toHandle(source: nums.cell);

  final pObs = Cell.observe(
    source: pairs.cell,
    effect: (Pulse p) => print('   [WindowCount] ${p.payload}'),
  );

  for (final n in [1, 2, 3, 4]) {
    await nums.emitAsync(n);
  }

  pObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. WindowSize - Overlapping
  // ─────────────────────────────────────────────────────────────────────
  print('2. WindowSize - overlapping');

  final seq = Cell.ingress<int>();

  final slide = WindowSize<int>(2, skip: 1).toHandle(source: seq.cell);

  final sObs = Cell.observe(
    source: slide.cell,
    effect: (Pulse p) => print('   [WindowSize] ${p.payload}'),
  );

  for (final n in [1, 2, 3]) {
    await seq.emitAsync(n);
  }

  sObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. WindowTime - Time-Based
  // ─────────────────────────────────────────────────────────────────────
  print('3. WindowTime');

  final timed = Cell.ingress<int>();

  final buckets = WindowTime<int>(
    const Duration(milliseconds: 40),
  ).toHandle(source: timed.cell);

  final tObs = Cell.observe(
    source: buckets.cell,
    effect: (Pulse p) => print('   [WindowTime] ${p.payload}'),
  );

  await timed.emitAsync(1);
  await timed.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 60));

  tObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. WindowWhen - Trigger-Based
  // ─────────────────────────────────────────────────────────────────────
  print('4. WindowWhen');

  final letters = Cell.ingress<String>();
  final close = Cell.ingress<void>();

  final when = WindowWhen<String>(close.cell).toHandle(source: letters.cell);

  final wObs = Cell.observe(
    source: when.cell,
    effect: (Pulse p) => print('   [WindowWhen] ${p.payload}'),
  );

  await letters.emitAsync('a');
  await letters.emitAsync('b');
  await close.emitAsync(null);

  wObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}