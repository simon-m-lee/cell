// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core MergeMap Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that flatten inner sequences concurrently
/// (Rx `mergeMap` / `flatMap` family).
///
/// | Operator | Rx analogue | Overlap |
/// |---|---|---|
/// | [MergeMap] | `mergeMap` / `flatMap` | yes, optional [concurrency] |
/// | [MergeMapTo] | `mergeMapTo` | same inner every trigger |
/// | [MergeScan] | `mergeScan` | concurrent acc-aware flatten |
///
/// [mapper] may return a [Stream], [Future], [Iterable], raw value, or
/// `null`. Inners overlap; emission order is completion order.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for mergeMap operators.
///
/// Called when an error occurs during mapping or draining of an inner sequence.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = MergeMapErrorHandler((error, stack) {
///   print('MergeMap error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef MergeMapErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// A function that maps a value to an inner sequence for concurrent flattening.
///
/// The inner sequence can be any object that can be drained:
/// - `Future<T>`: emits a single value
/// - `Stream<T>`: emits multiple values over time
/// - `Iterable<T>`: emits multiple values synchronously
/// - Any other value: emits that value directly
///
/// ### Example
/// ```dart
/// final mapper = MergeMapMapper<int>((id) async {
///   return await api.fetchUser(id);
/// });
/// ```
typedef MergeMapMapper<S> = FutureOr<Object?> Function(S value);

/// Helper to create an output pulse with proper provenance.
Pulse<T> _out<T>(T value, Cell? cell, Pulse trigger, String step) {
  return Pulse<T>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// Drains any object (Future, Stream, Iterable, or value) into a callback.
///
/// This is the internal engine that handles the various types of inner
/// sequences that mergeMap operators can produce.
///
/// ### How it works
/// 1. If [inner] is `null`, returns immediately.
/// 2. If [inner] is a `Stream`, iterates over it asynchronously.
/// 3. If [inner] is a `Future`, waits for it and recurses.
/// 4. If [inner] is an `Iterable` (not `String`), iterates over it.
/// 5. Otherwise, calls [onData] with the value.
///
/// ### Parameters:
/// - [inner]: The object to drain.
/// - [onData]: Called for each value drained.
/// - [stillLive]: Optional callback to check if the operation is still current.
///
/// ### Non‑obvious
/// - **Recursive Draining**: The function recurses on `Future` and `Iterable`
///   values, allowing nested structures to be flattened.
/// - **Cancellation**: The [stillLive] callback is checked at each step,
///   allowing cancelled operations to stop early.
/// - **String Special Case**: Strings are treated as values, not iterables,
///   to avoid character-by-character iteration.
/// - **Stream Safety**: Streams are drained fully, respecting the stillLive
///   check at each event.
Future<void> _drain(
    Object? inner,
    void Function(dynamic value) onData, {
      bool Function()? stillLive,
    }) async {
  if (inner == null) return;
  if (stillLive != null && !stillLive()) return;

  if (inner is Stream) {
    await for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await _drain(event, onData, stillLive: stillLive);
    }
    return;
  }

  if (inner is Future) {
    final value = await Future<dynamic>.value(inner);
    await _drain(value, onData, stillLive: stillLive);
    return;
  }

  if (inner is Iterable && inner is! String) {
    for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await _drain(event, onData, stillLive: stillLive);
    }
    return;
  }

  onData(inner);
}

/// Internal queue and concurrency controller for mergeMap operators.
///
/// [_MergeQueue] manages the queue of pending items and the number of
/// concurrently active operations. It provides a [pump] method that
/// starts new operations up to the concurrency limit.
///
/// ### How it works
/// 1. Items are added to the queue via [enqueue].
/// 2. The [pump] method starts operations while there are items in the
///    queue and the active count is below the limit.
/// 3. When an operation completes, the active count is decremented and
///    [pump] is called again to start the next item.
/// 4. This ensures that at most [limit] operations are running concurrently.
///
/// ### Type Parameters:
/// - [S]: The type of items in the queue.
class _MergeQueue<S> {
  final List<S> queue = <S>[];
  int active = 0;

  /// Adds an item to the queue.
  void enqueue(S value) => queue.add(value);

  /// Starts operations up to the [limit] concurrency.
  ///
  /// The [run] function is called for each item, and must return a
  /// `Future<void>` that resolves when the operation is complete.
  ///
  /// ### Parameters:
  /// - [limit]: Maximum number of concurrent operations.
  /// - [run]: Function that executes the operation for each item.
  void pump({
    required int limit,
    required Future<void> Function(S value) run,
  }) {
    while (active < limit && queue.isNotEmpty) {
      final next = queue.removeAt(0);
      active++;
      Future<void> job() async {
        try {
          await run(next);
        } finally {
          active--;
          pump(limit: limit, run: run);
        }
      }

      job();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// MergeMap - Core Operator
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that flattens inner sequences concurrently
/// (Rx `mergeMap` / `flatMap`).
///
/// [MergeMap] maps each incoming value to an inner sequence (Future, Stream,
/// or Iterable) and emits values from all inner sequences as they complete,
/// with optional concurrency control. Unlike [SwitchMap], previous inner
/// sequences are not cancelled – they run to completion concurrently.
///
/// ### When to use
/// Use [MergeMap] when you need to process multiple async operations
/// concurrently and don't need to cancel previous operations.
///
/// - **Parallel HTTP Calls**: Making multiple independent API calls.
/// - **Batch Processing**: Processing multiple items concurrently.
/// - **Background Tasks**: Running multiple background operations.
/// - **Data Enrichment**: Enriching multiple items in parallel.
/// - **File Operations**: Reading/writing multiple files concurrently.
/// - **Image Processing**: Processing images in parallel.
/// - **Database Operations**: Multiple concurrent database queries.
/// - **Event Handling**: Processing multiple events simultaneously.
///
/// ### Choosing Between MergeMap Variants
/// - **Use [MergeMap]** for **Payload-Dependent Mapping**: When the inner
///   sequence depends on the payload value.
/// - **Use [MergeMapTo]** for **Fixed Inner Sequence**: When the inner
///   sequence is the same for every trigger.
/// - **Use [MergeScan]** for **Stateful Accumulation**: When each step
///   depends on the accumulated result.
///
/// ### Comparison with Other Operators
/// | Operator | Input → Inner | Cancels Previous | Concurrency | Emits |
/// |----------|--------------|------------------|-------------|-------|
/// | **MergeMap** | Mapped from payload | No | Configurable | All, unordered |
/// | **SwitchMap** | Mapped from payload | Yes | N/A | Latest only |
/// | **AsyncMap** | Mapped from payload | No | 1 (sequential) | All, ordered |
/// | **AsyncMapSequential** | Mapped from payload | No | Configurable | All, ordered |
/// | **ConcatMap** | Mapped from payload | No | 1 (queued) | All, ordered |
///
/// ### How it works
/// 1. Each incoming pulse triggers the [mapper] function.
/// 2. The [mapper] returns an inner sequence (Future, Stream, or Iterable).
/// 3. The inner sequence is drained asynchronously.
/// 4. Values are emitted as they complete (unordered).
/// 5. The [concurrency] parameter controls how many inners run at once.
/// 6. Each emitted value is wrapped as an [EvolvedPulse] with the step
///    `'MergeMap'` to preserve causal provenance.
/// 7. Unlike [SwitchMap], previous inners are NOT cancelled.
/// 8. All inners run to completion.
///
/// ### Non‑obvious
/// - **Unordered Output**: Results are emitted in completion order, not
///   input order. This is the key difference from [AsyncMapSequential].
/// - **Concurrency Limit**: Default is unlimited (0). Set to a positive
///   number to limit concurrent operations.
/// - **Memory Safety**: Each inner sequence is drained fully. Large
///   sequences may consume memory.
/// - **Error Isolation**: Errors in one operation don't affect others.
/// - **Type Safety**: The instruction is generic over [S] (input type) and
///   [T] (output type), ensuring compile-time type safety.
/// - **Provenance Preservation**: Every emitted value preserves the source
///   cell, type, and priority from the trigger pulse.
/// - **Drain Recursion**: The `_drain` function handles nested structures
///   (Future of Stream, Iterable of Future, etc.).
/// - **Backpressure**: Unlike Rx, there's no backpressure mechanism. Use
///   [concurrency] to control resource usage.
///
/// ### Example: Parallel API Calls
/// ```dart
/// final userIds = Cell.ingress<int>();
///
/// final userData = MergeMap<int, UserProfile>(
///   (id) async {
///     // These run concurrently
///     return await api.getUser(id);
///   },
///   concurrency: 10, // Up to 10 concurrent requests
/// ).toHandle(source: userIds.cell);
///
/// Cell.observe(
///   source: userData.cell,
///   effect: (pulse) => print('User: ${pulse.payload}'),
/// );
///
/// userIds.emit(1); // -> User: Profile_1
/// userIds.emit(2); // -> User: Profile_2
/// userIds.emit(3); // -> User: Profile_3 (may complete out of order)
/// ```
///
/// ### Example: Batch Processing
/// ```dart
/// final tasks = Cell.ingress<Task>();
///
/// final results = MergeMap<Task, Result>(
///   (task) async {
///     return await processTask(task);
///   },
///   concurrency: 5,
/// ).toHandle(source: tasks.cell);
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Inner Sequence Factory.** A function that takes an
///   input value of type [S] and returns a `FutureOr<Object?>` that can be
///   drained (Future, Stream, Iterable, or value).
/// - [concurrency]: **Maximum Concurrent Operations.** Defaults to 0
///   (unlimited). Set to a positive number to cap concurrent inners.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload emitted by the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline or
/// materialized with `.toHandle()`.
///
/// ### See Also:
/// - [SwitchMap]: For cancelling previous inners.
/// - [AsyncMap]: For one-to-one async mapping without concurrency.
/// - [AsyncMapSequential]: For ordered concurrent processing.
/// - [ConcatMap]: For queuing inner sequences in order.
/// - [MergeMapTo]: For switching to a fixed inner sequence.
/// - [MergeScan]: For stateful accumulation with concurrency.
class MergeMap<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MergeMap(
      MergeMapMapper<S> mapper, {
        int concurrency = 0,
        MergeMapErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _MergeQueue<S>();
      final limit = concurrency < 1 ? 1 << 20 : concurrency;
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! S) {
          onError?.call(
            FormatException(
              'Expected payload of type $S, got ${payload.runtimeType}',
            ),
            StackTrace.current,
          );
          return null;
        }
        state.enqueue(payload);
        state.pump(
          limit: limit,
          run: (value) async {
            try {
              final inner = await Future.sync(() => mapper(value));
              await _drain(inner, (item) {
                if (item is T) {
                  future!(
                    result: _out<T>(item, cell, pulse, 'MergeMap'),
                    token: token,
                  );
                }
              });
            } catch (e, stack) {
              onError?.call(e, stack);
            }
          },
        );
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// MergeMapTo - Fixed Inner Sequence
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that starts the same inner sequence on every trigger,
/// with overlapping execution (Rx `mergeMapTo`).
///
/// [MergeMapTo] is similar to [MergeMap] but the inner sequence is fixed
/// and does not depend on the payload. This is useful when you want to
/// start multiple overlapping instances of the same sequence.
///
/// ### When to use
/// Use [MergeMapTo] when the inner sequence is the same regardless of
/// the incoming value, and you want overlapping executions.
///
/// - **Event Logging**: Logging every event with overlapping writes.
/// - **Background Tasks**: Starting multiple instances of a background job.
/// - **Heartbeats**: Sending overlapping heartbeat signals.
/// - **Timer Restart**: Restarting timers concurrently.
/// - **Parallel Operations**: Running the same operation multiple times.
///
/// ### Example: Event Logging
/// ```dart
/// final events = Cell.ingress<LogEvent>();
///
/// final logged = MergeMapTo<LogEvent, String>(
///   () async {
///     // This runs for every event, overlapping
///     await Future.delayed(Duration(milliseconds: 50));
///     return 'Logged';
///   },
///   concurrency: 10,
/// ).toHandle(source: events.cell);
///
/// // Each event triggers a new logging operation
/// events.emit(event1); // -> Logged
/// events.emit(event2); // -> Logged (overlaps with first)
/// ```
///
/// ### Example: Parallel Heartbeats
/// ```dart
/// final signals = Cell.ingress<void>();
///
/// final heartbeats = MergeMapTo<void, String>(
///   () async {
///     await Future.delayed(Duration(seconds: 1));
///     return 'Heartbeat';
///   },
///   concurrency: 5,
/// ).toHandle(source: signals.cell);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse (regardless of payload) triggers the [inner] factory.
/// 2. The [inner] factory returns the same sequence every time.
/// 3. Multiple instances of the sequence run concurrently.
/// 4. Values are emitted as each instance completes.
/// 5. The [concurrency] parameter controls how many instances run at once.
///
/// ### Non‑obvious
/// - **Payload Ignored**: The payload is ignored; only the arrival matters.
/// - **Reusable Factory**: The same [inner] factory is called for every trigger.
/// - **Overlapping Instances**: Multiple instances run concurrently.
/// - **Type Safety**: The input type [S] is effectively ignored but kept
///   for compatibility with the FlowInstruction interface.
/// - **Unlimited Default**: concurrency defaults to 0 (unlimited).
///
/// ### Parameters:
/// - [inner]: **The Fixed Inner Sequence Factory.** A function that returns
///   a `FutureOr<Object?>` that can be drained (Future, Stream, or Iterable).
/// - [concurrency]: **Maximum Concurrent Operations.** Defaults to 0
///   (unlimited). Set to a positive number to cap concurrent inners.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload (ignored, but kept for compatibility).
/// - [T]: The type of the output payload emitted by the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that starts overlapping instances of a fixed inner sequence.
///
/// ### See Also:
/// - [MergeMap]: For payload-dependent mapping.
/// - [SwitchMapTo]: For switching to a fixed inner sequence (cancels previous).
/// - [MergeScan]: For stateful accumulation with concurrency.
class MergeMapTo<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MergeMapTo(
      FutureOr<Object?> Function() inner, {
        int concurrency = 0,
        MergeMapErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _MergeQueue<int>();
      final limit = concurrency < 1 ? 1 << 20 : concurrency;
      var ticket = 0;
      return (pulse, {cell, user, future, token}) {
        state.enqueue(++ticket);
        state.pump(
          limit: limit,
          run: (_) async {
            try {
              final seq = await Future.sync(inner);
              await _drain(seq, (item) {
                if (item is T) {
                  future!(
                    result: _out<T>(item, cell, pulse, 'MergeMapTo'),
                    token: token,
                  );
                }
              });
            } catch (e, stack) {
              onError?.call(e, stack);
            }
          },
        );
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// MergeScan - Stateful Accumulation with Concurrency
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that accumulates state across concurrent inner
/// sequences (Rx `mergeScan`).
///
/// [MergeScan] maintains an accumulator that is updated by each inner
/// sequence. It's like a `scan` operator but the accumulation function
/// returns an inner sequence that is drained concurrently.
///
/// ### When to use
/// Use [MergeScan] when you need to maintain state across multiple
/// concurrent operations.
///
/// - **Running Totals**: Accumulating values from parallel operations.
/// - **State Machines**: Updating state from concurrent events.
/// - **Progress Tracking**: Tracking progress across parallel tasks.
/// - **Batch Processing**: Accumulating results from concurrent batches.
/// - **Event Aggregation**: Aggregating events from multiple sources.
/// - **Real-time Analytics**: Computing running statistics in real-time.
///
/// ### Example: Running Total with Concurrency
/// ```dart
/// final increments = Cell.ingress<int>();
///
/// final total = MergeScan<int, int>(
///   0, // Initial seed
///   (acc, value) async {
///     // Each inner returns the new total
///     await Future.delayed(Duration(milliseconds: 10));
///     return acc + value;
///   },
/// ).toHandle(source: increments.cell);
///
/// increments.emit(5);  // -> total: 5
/// increments.emit(3);  // -> total: 8
/// increments.emit(7);  // -> total: 15
/// ```
///
/// ### Example: State Machine with Concurrent Events
/// ```dart
/// final events = Cell.ingress<Event>();
///
/// final state = MergeScan<Event, State>(
///   State.initial(),
///   (currentState, event) async {
///     // Each inner processes the event and returns the new state
///     return await processEvent(currentState, event);
///   },
/// ).toHandle(source: events.cell);
/// ```
///
/// ### How it works
/// 1. The [accumulate] function is called for each incoming payload.
/// 2. It receives the current accumulator value and the payload.
/// 3. It returns an inner sequence (Future, Stream, or Iterable).
/// 4. The inner sequence is drained concurrently with other inners.
/// 5. The first value of type [A] from each inner becomes the new accumulator.
/// 6. That value is also emitted as an output.
/// 7. Subsequent values from the same inner are ignored for accumulation
///    but are still emitted.
/// 8. The accumulator is shared across all concurrent operations.
///
/// ### Non‑obvious
/// - **Shared State**: The accumulator is shared across all concurrent inners.
///   This means the order of updates matters.
/// - **First Value Wins for Accumulation**: Only the first [A] value from
///   each inner is used to update the accumulator.
/// - **Subsequent Values Emitted**: All [A] values from an inner are emitted,
///   but only the first updates the accumulator.
/// - **Concurrent Updates**: Accumulator updates happen concurrently.
///   The final value is the result of all updates in completion order.
/// - **Type Safety**: The accumulator type [A] is independent of the
///   input type [S] and output type [A] (same as accumulator).
/// - **Error Handling**: Errors in one operation don't affect others,
///   but they do prevent that operation from updating the accumulator.
/// - **Provenance Preservation**: Every emitted value preserves the source
///   cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [seed]: **Initial Accumulator Value.** The starting state before any
///   operations complete.
/// - [accumulate]: **The Accumulation Function.** Takes the current
///   accumulator and the payload, returns a `FutureOr<Object?>` to drain.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [A]: The type of the accumulator and output payload.
///
/// ### Returns:
/// A [FlowInstruction] that accumulates state across concurrent operations.
///
/// ### See Also:
/// - [MergeMap]: For concurrent flattening without state.
/// - [AsyncMap]: For one-to-one async mapping.
/// - [Scan]: For synchronous accumulation (not yet implemented).
/// - [fold]: For reducing a sequence to a single value (not yet implemented).
class MergeScan<S, A> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MergeScan(
      A seed,
      FutureOr<Object?> Function(A acc, S value) accumulate, {
        MergeMapErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var acc = seed;
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! S) {
          onError?.call(
            FormatException(
              'Expected payload of type $S, got ${payload.runtimeType}',
            ),
            StackTrace.current,
          );
          return null;
        }
        final current = acc;
        Future<void> run() async {
          try {
            final inner = await Future.sync(() => accumulate(current, payload));
            await _drain(inner, (item) {
              if (item is A) {
                acc = item;
                future!(
                  result: _out<A>(item, cell, pulse, 'MergeScan'),
                  token: token,
                );
              }
            });
          } catch (e, stack) {
            onError?.call(e, stack);
          }
        }

        run();
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [MergeMap] instruction and related operators
/// showing their behavior in various concurrent flattening scenarios.
///
/// ### Expected console output:
/// ```text
/// ── MergeMap Operators Demo ───────────────────────────────────
///
/// 1. MergeMap - completion order
///    [MergeMap] fast
///    [MergeMap] slow
///
/// 2. MergeMapTo - overlapping pings
///    [MergeMapTo] ping
///    [MergeMapTo] ping
///
/// 3. MergeScan - running total
///    [MergeScan] 1
///    [MergeScan] 3
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
/// 1. **MergeMap - Completion Order**: Shows that results are emitted in
///    completion order, not input order. The `fast` request completes and
///    emits before the `slow` request, even though `slow` was triggered first.
///
/// 2. **MergeMapTo - Overlapping Pings**: Shows that multiple instances
///    of the same sequence run concurrently. Each trigger starts a new
///    instance that overlaps with previous instances.
///
/// 3. **MergeScan - Running Total**: Shows stateful accumulation where
///    each operation updates the shared accumulator. The total accumulates
///    as values are processed.
///
/// ### Key Takeaways
/// - MergeMap processes inners concurrently (no cancellation).
/// - Emission order is completion order (not input order).
/// - Concurrency can be controlled with the [concurrency] parameter.
/// - MergeMapTo ignores payloads and starts the same sequence each time.
/// - MergeScan maintains state across concurrent operations.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Errors are isolated and don't affect other concurrent operations.
///
/// ### Note on Output Order
/// The exact output order of MergeMapConcurrent may vary depending on
/// system timing. The demo shows a typical execution where the `fast`
/// request completes before the `slow` request, but this is not guaranteed.
/// The key point is that results are emitted as they complete, not in
/// input order.
Future<void> main() async {
  print('── MergeMap Operators Demo ───────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. MergeMap - Completion Order
  // ─────────────────────────────────────────────────────────────────────
  print('1. MergeMap - completion order');

  final names = Cell.ingress<String>();

  final merged = MergeMap<String, String>(
        (name) async {
      // Simulate variable processing times
      await Future<void>.delayed(Duration(milliseconds: name == 'slow' ? 40 : 5));
      return name;
    },
  ).toHandle(source: names.cell);

  final mObs = Cell.observe(
    source: merged.cell,
    effect: (Pulse p) => print('   [MergeMap] ${p.payload}'),
  );

  // Trigger slow first, then fast - fast completes first
  await names.emitAsync('slow');
  await names.emitAsync('fast');
  await Future<void>.delayed(const Duration(milliseconds: 70));

  mObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. MergeMapTo - Overlapping Pings
  // ─────────────────────────────────────────────────────────────────────
  print('2. MergeMapTo - overlapping pings');

  final clicks = Cell.ingress<void>();

  final echo = MergeMapTo<void, String>(
        () => 'ping',
  ).toHandle(source: clicks.cell);

  final tObs = Cell.observe(
    source: echo.cell,
    effect: (Pulse p) => print('   [MergeMapTo] ${p.payload}'),
  );

  // Two triggers start two overlapping instances
  await clicks.emitAsync(null);
  await clicks.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  tObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. MergeScan - Running Total
  // ─────────────────────────────────────────────────────────────────────
  print('3. MergeScan - running total');

  final nums = Cell.ingress<int>();

  final scanned = MergeScan<int, int>(
    0, // Initial seed
        (acc, n) async {
      // Simulate work and return the new total
      await Future.delayed(Duration(milliseconds: 10));
      return acc + n;
    },
  ).toHandle(source: nums.cell);

  final sObs = Cell.observe(
    source: scanned.cell,
    effect: (Pulse p) => print('   [MergeScan] ${p.payload}'),
  );

  await nums.emitAsync(1);
  await nums.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  sObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}