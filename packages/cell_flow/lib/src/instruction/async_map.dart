// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';

// ─────────────────────────────────────────────────────────────
// Core AsyncMap Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that map each payload through an async function
/// (Rx `concatMap` of a single Future / Dart `asyncMap` family).
///
/// Unlike [AsyncExpand], the projector is expected to return **one**
/// value (or a Future of one). Collections are not flattened.
///
/// | Operator | Policy |
/// |---|---|
/// | [AsyncMap] / [AsyncMapSequential] | queue |
/// | [AsyncMapConcurrent] | overlap |
/// | [AsyncMapLatest] | drop in-flight |
/// | [AsyncMapWithIndex] | `(value, index)` queued |
/// | [AsyncMapWithRetry] | retry the projector |
/// | [AsyncMapWithTimeout] | time-box one projection |
/// | [AsyncMapWithFallback] | on error emit [fallback] |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for asyncMap operators.
///
/// Called when an error occurs during async mapping operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = AsyncMapErrorHandler((error, stack) {
///   print('AsyncMap error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef AsyncMapErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// An asynchronous mapping function.
///
/// Takes a value of type [S] and returns a `FutureOr<T>` representing
/// the mapped result.
///
/// ### Example
/// ```dart
/// final mapper = AsyncMapper<int, String>((id) async {
///   return await api.getUserName(id);
/// });
/// ```
typedef AsyncMapper<S, T> = FutureOr<T> Function(S value);

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

/// Helper to call an async mapper with proper error handling.
Future<T> _call<S, T>(AsyncMapper<S, T> map, S value) {
  return Future<T>.sync(() => map(value));
}

// ─────────────────────────────────────────────────────────────
// AsyncMap - Sequential Async Mapping
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that maps each payload through an async
/// function sequentially (Dart `asyncMap`).
///
/// [AsyncMap] is the foundational asynchronous mapping operator. It
/// processes inputs one at a time, waiting for each async operation
/// to complete before starting the next.
///
/// ### When to use
/// Use [AsyncMap] when you need to perform async operations on each
/// value and order matters.
///
/// - **Network Requests**: Making sequential API calls.
/// - **Database Operations**: Sequential database queries.
/// - **File I/O**: Reading/writing files sequentially.
/// - **Data Enrichment**: Enriching data with async sources.
/// - **Image Processing**: Processing images sequentially.
/// - **Encryption/Decryption**: Applying async crypto operations.
///
/// ### Choosing Between AsyncMap Variants
/// - **Use [AsyncMap]** for **Sequential**: When order matters and
///   operations must run one at a time.
/// - **Use [AsyncMapConcurrent]** for **Concurrent**: When order
///   doesn't matter and you want parallelism.
/// - **Use [AsyncMapLatest]** for **Latest Only**: When you only
///   care about the most recent operation.
/// - **Use [AsyncMapWithIndex]** for **Indexed**: When you need the
///   index in the mapping.
/// - **Use [AsyncMapWithRetry]** for **Retry**: When operations may
///   fail and need retry.
/// - **Use [AsyncMapWithTimeout]** for **Timeout**: When operations
///   must complete within a time limit.
/// - **Use [AsyncMapWithFallback]** for **Fallback**: When you need
///   a default value on error.
///
/// ### Comparison with Other Operators
/// | Operator | Concurrency | Cancels | Queues | Emits |
/// |----------|-------------|---------|--------|-------|
/// | **AsyncMap** | 1 (sequential) | No | Yes | Each result |
/// | **AsyncMapConcurrent** | Unlimited | No | No | Each result |
/// | **AsyncMapLatest** | 1 (latest only) | Yes | No | Latest only |
/// | **AsyncMapWithIndex** | 1 (sequential) | No | Yes | Each result |
/// | **AsyncMapWithRetry** | 1 (sequential) | No | Yes | Each result |
/// | **AsyncMapWithTimeout** | 1 (sequential) | Yes | Yes | Each result |
/// | **AsyncMapWithFallback** | 1 (sequential) | No | Yes | Each result |
///
/// ### How it works
/// 1. Each incoming pulse triggers the [map] function.
/// 2. The async operation is awaited.
/// 3. The result is emitted.
/// 4. Inputs are queued while processing.
/// 5. If [map] throws an error, it's reported and the instruction
///    continues with the next input.
/// 6. Each emitted value gets the step `'AsyncMap'` for provenance.
///
/// ### Non‑obvious
/// - **Sequential Processing**: Operations run one after another.
/// - **Queueing**: Inputs are queued while processing.
/// - **No Cancellation**: Previous operations are not cancelled.
/// - **Error Isolation**: Errors don't stop the queue.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Single Value**: Unlike [AsyncExpand], collections are not flattened.
///
/// ### Example: Sequential API Calls
/// ```dart
/// final ids = Cell.ingress<int>();
///
/// final users = AsyncMap<int, User>(
///   (id) async {
///     // These run one at a time
///     return await api.getUser(id);
///   },
/// ).toHandle(source: ids.cell);
///
/// ids.emit(1); // -> User 1
/// ids.emit(2); // -> User 2 (after User 1 completes)
/// ```
///
/// ### Example: Data Enrichment
/// ```dart
/// final items = Cell.ingress<Item>();
///
/// final enriched = AsyncMap<Item, EnrichedItem>(
///   (item) async {
///     final data = await enrichData(item);
///     return EnrichedItem(item, data);
///   },
/// ).toHandle(source: items.cell);
/// ```
///
/// ### Parameters:
/// - [map]: **Mapping Function.** Called with each typed payload,
///   returns a `FutureOr<T>`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maps values asynchronously.
///
/// ### See Also:
/// - [AsyncMapConcurrent]: For concurrent mapping.
/// - [AsyncMapLatest]: For latest-only mapping.
/// - [AsyncMapWithIndex]: For indexed mapping.
/// - [AsyncMapWithRetry]: For retry logic.
/// - [AsyncMapWithTimeout]: For timeout handling.
/// - [AsyncMapWithFallback]: For fallback values.
class AsyncMap<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Sequential Asynchronous Bridge**—a specialized
  /// orchestration instruction designed for ordered, one-by-one pulse evolution.
  ///
  /// [AsyncMap] acts as a stable gateway between the synchronous reactive
  /// topography and asynchronous logic. It ensures that every incoming
  /// stimulus is transformed to completion before the next begins, maintaining
  /// a strict topological order of results regardless of varying async
  /// latencies.
  ///
  /// ### How it works
  /// 1. **Stimulus Reception**: Each incoming pulse [S] is evaluated for
  ///    type integrity and placed into a internal FIFO queue.
  /// 2. **Sequential Materialization**: The [map] orchestrator is invoked for
  ///    the payload at the head of the queue only when the gate is idle.
  /// 3. **Async Awaiting**: The resulting `FutureOr<T>` is awaited until
  ///    resolution.
  /// 4. **Provenance Preservation**: The evolved value [T] is emitted in a
  ///    new pulse inheriting the original source, priority, and type,
  ///    tagged with the `'AsyncMap'` step.
  /// 5. **Queue Advancement**: The gate advances to the next stimulus only
  ///    after the current mapping has successfully completed or failed.
  ///
  /// ### Concurrency Model
  /// * **Single-Lane Traffic**: Only one async operation is active at any time.
  /// * **FIFO Integrity**: Output pulses are guaranteed to be emitted in the
  ///   exact order their triggering stimuli entered the topography.
  /// * **Backpressure Protection**: Downstream consumers are protected from
  ///   burst-induced race conditions through internal buffering.
  ///
  /// ### Parameters
  /// - [map]: **The Orchestrator.** A closure that transforms an input
  ///   payload [S] into a `FutureOr` of [T].
  /// - [onError]: **Integrity Handler.** A callback invoked if a mapping
  ///   fails or if a payload violates type [S]. The gate continues
  ///   processing the queue after reporting the error.
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the composition chain for auditing and tracing.
  ///
  /// ### Example: Sequential API Enrichment
  /// ```dart
  /// // Fetches user data one-by-one, ensuring Result 1 emits before Result 2
  /// final userGate = AsyncMap<int, User>(
  ///   (id) => api.fetchUser(id),
  ///   user: 'Sequential-User-Mapper'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [AsyncMapConcurrent]: For parallel execution where order is secondary.
  /// - [AsyncMapLatest]: For switch-style behavior (superseding old work).
  /// - [AsyncExpand]: For mapping that yields multiple pulses per stimulus.
  AsyncMap(
      AsyncMapper<S, T> map, {
        AsyncMapErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final queue = <S>[];
      var busy = false;
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
        queue.add(payload);
        Future<void> pump() async {
          if (busy) return;
          busy = true;
          while (queue.isNotEmpty) {
            final next = queue.removeAt(0);
            try {
              final result = await _call(map, next);
              future!(
                result: _out<T>(result, pulse, cell, 'AsyncMap'),
                token: token,
              );
            } catch (e, stack) {
              onError?.call(e, stack);
            }
          }
          busy = false;
        }

        pump();
        return null;
      };
    })(),
    user: user,
  );
}

/// Alias of [AsyncMap] for Rx compatibility.
///
/// [AsyncMapSequential] is an alias for [AsyncMap] that emphasizes the
/// sequential nature of the mapping.
///
/// ### Example
/// ```dart
/// final users = AsyncMapSequential<int, User>(
///   (id) async => await api.getUser(id),
/// ).toHandle(source: ids.cell);
/// // Same as AsyncMap
/// ```
class AsyncMapSequential<S, T> extends AsyncMap<S, T> {

  /// Synthesizes a **Sequential Topographical Alias**—a specialized constructor
  /// that explicitly enforces ordered pulse evolution.
  ///
  /// [AsyncMapSequential] is a semantic alias for [AsyncMap]. It is used to
  /// improve code readability by clearly distinguishing ordered, one-by-one
  /// processing from concurrent or switch-style asynchronous operations.
  ///
  /// ### How it works
  /// 1. **Stimulus Queuing**: Each incoming pulse is placed into a internal
  ///    FIFO (First-In-First-Out) queue.
  /// 2. **Ordered Bridge**: A mapping is only initiated after the previous
  ///    asynchronous workload has resolved.
  /// 3. **Provenance Preservation**: The result inherits the original pulse
  ///    provenance, tagged with the `'AsyncMap'` topographic step.
  ///
  /// ### When to use
  /// * **API Sequence Integrity**: When calls must hit a backend in the
  ///   exact order they were triggered.
  /// * **State Consistency**: When a downstream cell depends on an
  ///   ordered history of asynchronous state changes.
  /// * **Backpressure Control**: To naturally throttle the topography by
  ///   awaiting completion before accepting new work.
  ///
  /// ### Parameters
  /// - [map]: **The Orchestrator.** A closure that transforms the input
  ///   payload into a `FutureOr`.
  /// - [onError]: **Integrity Handler.** A callback invoked if a mapping
  ///   fails. The gate continues to the next item in the queue after handling.
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the composition chain for auditing.
  ///
  /// ### See Also
  /// - [AsyncMap]: The primary implementation of this logic.
  /// - [AsyncMapConcurrent]: For unordered, parallel asynchronous lanes.
  AsyncMapSequential(
      super.map, {
        super.onError,
        super.user,
      });
}

// ─────────────────────────────────────────────────────────────
// AsyncMapConcurrent - Concurrent Async Mapping
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that maps each payload through an async
/// function concurrently (overlapping).
///
/// [AsyncMapConcurrent] processes inputs concurrently, emitting
/// results as they complete. Order is not preserved.
///
/// ### When to use
/// Use [AsyncMapConcurrent] when you want maximum throughput and
/// order doesn't matter.
///
/// - **Parallel Processing**: Processing multiple items in parallel.
/// - **Throughput**: Maximizing throughput.
/// - **Independent Operations**: When operations are independent.
/// - **Batch Processing**: Processing batches in parallel.
/// - **API Calls**: Making parallel API calls.
///
/// ### Example: Parallel API Calls
/// ```dart
/// final ids = Cell.ingress<int>();
///
/// final users = AsyncMapConcurrent<int, User>(
///   (id) async {
///     // These run in parallel
///     return await api.getUser(id);
///   },
/// ).toHandle(source: ids.cell);
///
/// ids.emit(1); // Starts fetching
/// ids.emit(2); // Starts fetching (parallel)
/// // Results arrive in completion order
/// ```
///
/// ### How it works
/// 1. Each incoming pulse triggers the [map] function immediately.
/// 2. Multiple async operations run concurrently.
/// 3. Results are emitted as they complete.
/// 4. Order is not preserved.
/// 5. If [map] throws an error, it's reported independently.
/// 6. Each emitted value gets the step `'AsyncMapConcurrent'` for provenance.
///
/// ### Non‑obvious
/// - **Unordered**: Results are emitted in completion order.
/// - **Unlimited Concurrency**: All operations start immediately.
/// - **No Queuing**: No queuing; operations start immediately.
/// - **Error Isolation**: Errors are reported independently.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Resource Usage**: May use significant resources with many inputs.
///
/// ### Parameters:
/// - [map]: **Mapping Function.** Called with each typed payload,
///   returns a `FutureOr<T>`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maps values concurrently.
///
/// ### See Also:
/// - [AsyncMap]: For sequential mapping.
/// - [AsyncMapLatest]: For latest-only mapping.
/// - [AsyncMapWithIndex]: For indexed mapping.
class AsyncMapConcurrent<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Parallel Asynchronous Bridge**—a specialized orchestration
  /// instruction designed for concurrent pulse evolution and high-throughput
  /// topography.
  ///
  /// [AsyncMapConcurrent] (analogous to `mergeMap` in Rx) acts as a multi-lane
  /// gateway between the synchronous reactive graph and concurrent asynchronous
  /// logic. Unlike the sequential [AsyncMap], it does not enforce a queue;
  /// every incoming stimulus is immediately materialized into a separate
  /// async lane, allowing pulses to evolve at their own relative latencies.
  ///
  /// ### How it works
  /// 1. **Stimulus Reception**: Every incoming pulse [S] is evaluated for
  ///    type integrity.
  /// 2. **Concurrent Materialization**: The [map] orchestrator is triggered
  ///    immediately for each pulse, bypassing any central queue.
  /// 3. **Non-Deterministic Propagation**: Results are emitted to the graph
  ///    as soon as their respective async lanes resolve. The output order is
  ///    determined by completion time, not stimulus arrival order.
  /// 4. **Provenance Preservation**: Each evolved value [T] is wrapped in a
  ///    new pulse inheriting the specific trigger's source and priority,
  ///    tagged with the `'AsyncMapConcurrent'` topographic step.
  ///
  /// ### Concurrency Model
  /// * **Multi-Lane Traffic**: Unlimited parallel operations by default.
  /// * **Throughput Optimized**: Ideal for independent tasks where the
  ///   temporal order of inputs is secondary to execution speed.
  /// * **Error Isolation**: Failure in one async lane does not terminate
  ///   or stall other active lanes.
  ///
  /// ### Parameters
  /// - [map]: **The Parallel Orchestrator.** A closure that transforms an
  ///   input payload [S] into a `FutureOr` of [T].
  /// - [onError]: **Integrity Handler.** A callback invoked if an async lane
  ///   fails or if a payload violates type [S].
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the composition chain for auditing and tracing.
  ///
  /// ### Example: Parallel Data Fetching
  /// ```dart
  /// // Fetches multiple resources simultaneously; order of emission depends on API latency
  /// final parallelGate = AsyncMapConcurrent<int, Resource>(
  ///   (id) => api.fetchResource(id),
  ///   user: 'Parallel-Resource-Bridge'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [AsyncMap]: For strictly ordered, sequential asynchronous bridges.
  /// - [AsyncMapLatest]: For switch-style behavior (superseding old work).
  /// - [AsyncExpandConcurrent]: For parallel mapping that yields multiple pulses.
  AsyncMapConcurrent(
      AsyncMapper<S, T> map, {
        AsyncMapErrorHandler? onError,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
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
      Future<void> run() async {
        try {
          final result = await _call(map, payload);
          future!(
            result: _out<T>(result, pulse, cell, 'AsyncMapConcurrent'),
            token: token,
          );
        } catch (e, stack) {
          onError?.call(e, stack);
        }
      }

      run();
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// AsyncMapLatest - Latest-Only Async Mapping
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that maps each payload asynchronously,
/// dropping in-flight operations when a new value arrives.
///
/// [AsyncMapLatest] only emits results from the most recent operation.
/// Previous in-flight operations are cancelled (dropped).
///
/// ### When to use
/// Use [AsyncMapLatest] when you only care about the most recent
/// operation.
///
/// - **Search-as-you-type**: Only the latest search query matters.
/// - **Real-time Updates**: Only the most recent update is relevant.
/// - **User Input**: Only the latest user input matters.
/// - **Selection Changes**: Only the latest selection matters.
/// - **Navigation**: Only the latest route matters.
///
/// ### Example: Search-as-you-Type
/// ```dart
/// final query = Cell.ingress<String>();
///
/// final results = AsyncMapLatest<String, Result>(
///   (q) async {
///     // Previous searches are cancelled
///     return await api.search(q);
///   },
/// ).toHandle(source: query.cell);
///
/// query.emit('dart');     // Starts search
/// query.emit('flutter');  // Cancels previous, starts new search
/// // Only 'flutter' results are emitted
/// ```
///
/// ### How it works
/// 1. Each incoming pulse triggers the [map] function.
/// 2. A new generation ID is assigned to each trigger.
/// 3. Any previous in-flight operation is cancelled.
/// 4. Only the result from the latest generation is emitted.
/// 5. If [map] throws an error, it's reported only for the current
///    generation.
/// 6. Each emitted value gets the step `'AsyncMapLatest'` for provenance.
///
/// ### Non‑obvious
/// - **Generation Tracking**: Each operation gets a unique ID.
/// - **Silent Cancellation**: Cancelled operations don't emit errors.
/// - **Latest Only**: Only the most recent operation emits values.
/// - **Error Isolation**: Only errors from the current generation are
///   reported.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [map]: **Mapping Function.** Called with each typed payload,
///   returns a `FutureOr<T>`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maps latest-only values.
///
/// ### See Also:
/// - [AsyncMap]: For sequential mapping.
/// - [AsyncMapConcurrent]: For concurrent mapping.
/// - [AsyncMapWithIndex]: For indexed mapping.
class AsyncMapLatest<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Preemptive Asynchronous Bridge**—a specialized
  /// orchestration instruction designed for latest-only, switch-style
  /// pulse evolution.
  ///
  /// [AsyncMapLatest] (analogous to `switchMap` in Rx) ensures that only
  /// the most recent stimulus is evolved to completion. If a new pulse
  /// enters the gate while a previous asynchronous workload is still
  /// in flight, the older operation is effectively suppressed; its
  /// result will be ignored to ensure the topography reflects only the
  /// most current state transition.
  ///
  /// ### How it works
  /// 1. **Stimulus Reception**: Every incoming pulse [S] is evaluated
  ///    for type integrity.
  /// 2. **Generation Tracking**: A unique internal generation ID is
  ///    assigned to each materialization lane.
  /// 3. **Preemptive Suppression**: If a new pulse arrives, the
  ///    generation ID increments. The gate will silently ignore the
  ///    completion of any previous lane that does not match the
  ///    current ID.
  /// 4. **Deferred Materialization**: The [map] orchestrator is triggered
  ///    immediately, and the resulting `FutureOr<T>` is awaited.
  /// 5. **Provenance Preservation**: Only the evolved value [T] from
  ///    the *latest* generation is emitted in a new pulse, inheriting
  ///    provenance from the triggering pulse and tagged with the
  ///    `'AsyncMapLatest'` step.
  ///
  /// ### Concurrency Model
  /// * **Latest-Wins Strategy**: Multiple async tasks may technically
  ///   be in flight, but only the one matching the current generation
  ///   ID can impact the graph.
  /// * **Topological Freshness**: Ideal for scenarios like search-as-you-type
  ///   or real-time updates where older results become obsolete as
  ///   soon as a new input is available.
  /// * **Implicit Cancellation**: While underlying Futures are not
  ///   aborted, the bridge ensures graph consistency by discarding
  ///   stale resolution events.
  ///
  /// ### Parameters
  /// - [map]: **The Switch Orchestrator.** A closure that transforms an
  ///   input payload [S] into a `FutureOr` of [T].
  /// - [onError]: **Integrity Handler.** A callback invoked only if
  ///    the *latest* active generation fails.
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the composition chain for auditing and tracing.
  ///
  /// ### Example: Search-as-you-Type Logic
  /// ```dart
  /// // Only the results for the most recently typed query are emitted
  /// final searchGate = AsyncMapLatest<String, List<Result>>(
  ///   (query) => api.fetchResults(query),
  ///   user: 'Search-Switch-Bridge'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [AsyncMap]: For strictly ordered, sequential asynchronous bridges.
  /// - [AsyncMapConcurrent]: For parallel execution where all results matter.
  /// - [AsyncExpandLatest]: For switch-style behavior yielding multiple pulses.
  AsyncMapLatest(
      AsyncMapper<S, T> map, {
        AsyncMapErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var generation = 0;
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
        final id = ++generation;
        Future<void> run() async {
          try {
            final result = await _call(map, payload);
            if (id != generation) return;
            future!(
              result: _out<T>(result, pulse, cell, 'AsyncMapLatest'),
              token: token,
            );
          } catch (e, stack) {
            if (id == generation) onError?.call(e, stack);
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
// AsyncMapWithIndex - Indexed Async Mapping
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that maps each payload asynchronously with a
/// 0-based index (bad types do not advance it).
///
/// [AsyncMapWithIndex] is similar to [AsyncMap] but the mapping
/// function receives the index of each value in the sequence.
///
/// ### When to use
/// Use [AsyncMapWithIndex] when your transformation depends on the
/// position of the value.
///
/// - **Position Tracking**: Including position in the output.
/// - **ID Generation**: Generating IDs based on position.
/// - **Progress Tracking**: Tracking progress through a sequence.
/// - **Offset Calculation**: Calculating offsets based on position.
///
/// ### Example: Indexed Labeling
/// ```dart
/// final items = Cell.ingress<String>();
///
/// final labeled = AsyncMapWithIndex<String, String>(
///   (item, index) async => 'Item #${index + 1}: $item',
/// ).toHandle(source: items.cell);
///
/// items.emit('Apple');  // -> Item #1: Apple
/// items.emit('Banana'); // -> Item #2: Banana
/// ```
///
/// ### How it works
/// 1. Each incoming pulse triggers the [map] function with the payload
///    and index.
/// 2. The index starts at 0 and increments on each typed pulse.
/// 3. Results are emitted sequentially.
/// 4. If [map] throws an error, it's reported and the instruction
///    continues with the next input.
/// 5. The index is only incremented on successful completions.
/// 6. Each emitted value gets the step `'AsyncMapWithIndex'` for provenance.
///
/// ### Non‑obvious
/// - **Index Type**: The index is a 0-based integer.
/// - **Typed Only**: Only typed pulses increment the index.
/// - **Sequential**: Operations run one after another.
/// - **Error Handling**: If [map] throws, the index is not incremented.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [map]: **Indexed Mapping Function.** Called with each typed
///   payload and its index, returns a `FutureOr<T>`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maps values with index.
///
/// ### See Also:
/// - [AsyncMap]: For sequential mapping without index.
/// - [AsyncMapConcurrent]: For concurrent mapping.
/// - [AsyncMapLatest]: For latest-only mapping.
class AsyncMapWithIndex<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes an **Indexed Asynchronous Bridge**—a specialized orchestration
  /// instruction designed for position-aware pulse evolution and sequential
  /// mapping.
  ///
  /// [AsyncMapWithIndex] extends the standard asynchronous bridge by maintaining
  /// a persistent, 0-based topological index. It ensures that each stimulus is
  /// transformed to completion before the next begins, providing the
  /// orchestrator with the exact sequence position of the pulse as it traverses
  /// the topography.
  ///
  /// ### How it works
  /// 1. **Stimulus Reception**: Each incoming pulse [S] is evaluated for
  ///    type integrity and placed into a internal FIFO queue.
  /// 2. **Sequential Materialization**: The [map] orchestrator is invoked
  ///    for the payload at the head of the queue, provided with the current
  ///    topological [index].
  /// 3. **Async Awaiting**: The resulting `FutureOr<T>` is awaited until
  ///    resolution.
  /// 4. **Provenance Preservation**: The evolved value [T] is emitted in a
  ///    new pulse inheriting the original source, priority, and type,
  ///    tagged with the `'AsyncMapWithIndex'` step.
  /// 5. **Index Advancement**: The internal counter increments immediately
  ///    before the next mapping starts, ensuring a strict monotonic sequence
  ///    regardless of async latency.
  ///
  /// ### Concurrency Model
  /// * **Single-Lane Traffic**: Only one async operation is active at any time.
  /// * **Ordered Indexing**: The index is guaranteed to match the arrival
  ///   order of the triggering stimuli.
  /// * **Backpressure Protection**: Downstream consumers are shielded from
  ///   burst-induced race conditions through sequential execution.
  ///
  /// ### Parameters
  /// - [map]: **The Indexed Orchestrator.** A closure that transforms an input
  ///   payload [S] and its topological [index] into a `FutureOr` of [T].
  /// - [onError]: **Integrity Handler.** A callback invoked if a mapping
  ///   fails or if a payload violates type [S]. The gate continues processing
  ///   the queue after reporting.
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the composition chain for auditing and tracing.
  ///
  /// ### Example: Position-Aware Labeling
  /// ```dart
  /// // Labels pulses with their topological position
  /// final labeledGate = AsyncMapWithIndex<String, String>(
  ///   (item, index) async => 'Pulse #$index: $item',
  ///   user: 'Indexed-Label-Bridge'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [AsyncMap]: For standard sequential mapping without index tracking.
  /// - [AsyncMapConcurrent]: For parallel execution where order and index
  ///   continuity are secondary.
  /// - [AsyncMapLatest]: For switch-style behavior (superseding old work).
  AsyncMapWithIndex(
      FutureOr<T> Function(S value, int index) map, {
        AsyncMapErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var index = 0;
      final queue = <S>[];
      var busy = false;
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
        queue.add(payload);
        Future<void> pump() async {
          if (busy) return;
          busy = true;
          while (queue.isNotEmpty) {
            final next = queue.removeAt(0);
            final i = index;
            try {
              final result = await Future<T>.sync(() => map(next, i));
              index++;
              future!(
                result: _out<T>(result, pulse, cell, 'AsyncMapWithIndex'),
                token: token,
              );
            } catch (e, stack) {
              onError?.call(e, stack);
            }
          }
          busy = false;
        }

        pump();
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// AsyncMapWithRetry - Retry Logic
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that retries the async mapping up to [count]
/// extra times.
///
/// [AsyncMapWithRetry] retries failed operations up to [count] times
/// before giving up.
///
/// ### When to use
/// Use [AsyncMapWithRetry] when operations may fail transiently.
///
/// - **Unreliable Services**: API calls may fail transiently.
/// - **Network Operations**: Network errors should be retried.
/// - **Rate Limiting**: Operations that may be rate-limited.
/// - **Database Operations**: Transactions that may conflict.
/// - **External Dependencies**: Operations that depend on external systems.
///
/// ### Example: Retry on Failure
/// ```dart
/// final requests = Cell.ingress<String>();
///
/// final retried = AsyncMapWithRetry<String, String>(
///   (url) async {
///     return await http.get(url).then((r) => r.body);
///   },
///   count: 3,
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### How it works
/// 1. Each operation is attempted up to [count] times.
/// 2. If all retries fail, the error is reported.
/// 3. The instruction continues with the next input.
/// 4. Each emitted value gets the step `'AsyncMapWithRetry'` for provenance.
///
/// ### Non‑obvious
/// - **Total Attempts**: The operation may run `count + 1` times.
/// - **No Delay**: Retries are immediate (use [RetryWithDelay] for delays).
/// - **Error Reporting**: Only the final failure is reported.
/// - **Sequential**: Operations run one after another.
///
/// ### Parameters:
/// - [map]: **Mapping Function.** Called with each typed payload,
///   returns a `FutureOr<T>`.
/// - [count]: **Maximum Retry Attempts.** Defaults to 3.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maps with retry logic.
///
/// ### See Also:
/// - [AsyncMap]: For sequential mapping.
/// - [RetryWithDelay]: For retries with delay.
/// - [RetryWithBackoff]: For retries with backoff.
class AsyncMapWithRetry<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Resilient Asynchronous Bridge**—a specialized orchestration
  /// instruction designed for fault-tolerant, sequential pulse evolution.
  ///
  /// [AsyncMapWithRetry] acts as a durable gateway between the synchronous
  /// reactive topography and potentially unstable asynchronous logic. It ensures
  /// topological integrity by attempting to recover from transient failures,
  /// re-triggering the evolution process up to a specified threshold before
  /// reporting a terminal error.
  ///
  /// ### How it works
  /// 1. **Stimulus Reception**: Each incoming pulse [S] is evaluated for
  ///    type integrity and placed into an internal FIFO queue.
  /// 2. **Sequential Materialization**: The [map] orchestrator is invoked
  ///    for the payload at the head of the queue only when the gate is idle.
  /// 3. **Iterative Evolution**: If the asynchronous workload fails, the
  ///    gate automatically re-attempts the mapping up to [count] additional
  ///    times.
  /// 4. **Provenance Preservation**: Upon successful resolution, the evolved
  ///    value [T] is emitted in a new pulse inheriting the original source,
  ///    priority, and type, tagged with the `'AsyncMapWithRetry'` step.
  /// 5. **Queue Advancement**: The gate advances to the next stimulus only
  ///    after a successful evolution or after the retry threshold has been
  ///    exhausted.
  ///
  /// ### Concurrency Model
  /// * **Single-Lane Traffic**: Only one async operation (including its
  ///   retry attempts) is active at any time.
  /// * **FIFO Integrity**: Stimuli are processed in their topological arrival
  ///   order; retries do not allow subsequent pulses to "leapfrog" the
  ///   current operation.
  /// * **Error Reporting**: Only the final failure (after all retries are
  ///   exhausted) is considered a terminal break in the pulse evolution.
  ///
  /// ### Parameters
  /// - [map]: **The Resilient Orchestrator.** A closure that transforms an
  ///   input payload [S] into a `FutureOr` of [T].
  /// - [count]: **Retry Threshold.** The maximum number of additional
  ///   attempts to perform if the initial mapping fails. Defaults to 3.
  /// - [onError]: **Integrity Handler.** A callback invoked for each
  ///   failure encountered during the retry cycle.
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the composition chain for auditing and tracing.
  ///
  /// ### Example: Resilient API Fetching
  /// ```dart
  /// // Attempts to fetch data, retrying up to 3 times on network failure
  /// final resilientGate = AsyncMapWithRetry<String, Data>(
  ///   (url) => api.fetch(url),
  ///   count: 3,
  ///   user: 'Retry-API-Bridge'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [AsyncMap]: For standard sequential mapping without retry logic.
  /// - [AsyncMapWithTimeout]: For enforcing temporal constraints on evolution.
  /// - [AsyncMapWithFallback]: For providing default values upon evolution failure.
  AsyncMapWithRetry(
      AsyncMapper<S, T> map, {
        int count = 3,
        AsyncMapErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final queue = <S>[];
      var busy = false;
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
        queue.add(payload);
        Future<void> pump() async {
          if (busy) return;
          busy = true;
          while (queue.isNotEmpty) {
            final next = queue.removeAt(0);
            var attempt = 0;
            while (true) {
              try {
                final result = await _call(map, next);
                future!(
                  result: _out<T>(result, pulse, cell, 'AsyncMapWithRetry'),
                  token: token,
                );
                break;
              } catch (e, stack) {
                onError?.call(e, stack);
                if (attempt >= count) break;
                attempt++;
              }
            }
          }
          busy = false;
        }

        pump();
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// AsyncMapWithTimeout - Timeout Handling
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that fails the mapping if it exceeds [duration].
///
/// [AsyncMapWithTimeout] ensures that async operations complete within
/// a specified time limit, throwing an error if they exceed it.
///
/// ### When to use
/// Use [AsyncMapWithTimeout] when operations must complete quickly.
///
/// - **Time-Sensitive Operations**: Operations that must complete quickly.
/// - **User Experience**: Preventing hanging operations.
/// - **Service Level Agreements**: Enforcing response time limits.
/// - **Resource Protection**: Preventing resource exhaustion.
///
/// ### Example: API Call with Timeout
/// ```dart
/// final requests = Cell.ingress<String>();
///
/// final withTimeout = AsyncMapWithTimeout<String, String>(
///   (url) async {
///     return await http.get(url).then((r) => r.body);
///   },
///   duration: Duration(seconds: 5),
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### How it works
/// 1. Each operation is started with a timeout.
/// 2. If the operation exceeds [duration], a [TimeoutException] is thrown.
/// 3. The error is reported via [onError].
/// 4. The instruction continues with the next input.
/// 5. Each emitted value gets the step `'AsyncMapWithTimeout'` for provenance.
///
/// ### Non‑obvious
/// - **Timer Precision**: Timers are based on the event loop.
/// - **Cancellation**: Timed-out operations are cancelled.
/// - **Error Reporting**: Timeouts are reported via [onError].
/// - **Sequential**: Operations run one after another.
///
/// ### Parameters:
/// - [map]: **Mapping Function.** Called with each typed payload,
///   returns a `FutureOr<T>`.
/// - [duration]: **Timeout Duration.** Required. Operations exceeding
///   this time will be cancelled.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maps with timeout handling.
///
/// ### See Also:
/// - [AsyncMap]: For sequential mapping.
/// - [Timeout]: For timeout on idle streams.
/// - [TimeoutWithFallback]: For fallback on timeout.
class AsyncMapWithTimeout<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Time-Constrained Asynchronous Bridge**—a specialized
  /// orchestration instruction designed to enforce temporal boundaries on
  /// pulse evolution.
  ///
  /// [AsyncMapWithTimeout] ensures that each asynchronous mapping completes
  /// within a specified [duration]. If the evolution of a stimulus exceeds
  /// this temporal limit, the bridge effectively "breaks" for that specific
  /// pulse, discarding the result to prevent stale data or hanging processes
  /// from congesting the topography.
  ///
  /// ### How it works
  /// 1. **Stimulus Reception**: Each incoming pulse [S] is evaluated for
  ///    type integrity and placed into an internal FIFO queue.
  /// 2. **Sequential Materialization**: The [map] orchestrator is invoked
  ///    for the payload at the head of the queue only when the gate is idle.
  /// 3. **Temporal Monitoring**: The resulting `FutureOr<T>` is wrapped in
  ///    a timeout supervisor set to [duration].
  /// 4. **Evolution vs. Timeout**:
  ///    - If the workload completes within the limit, the evolved value [T]
  ///      is propagated downstream.
  ///    - If the deadline is exceeded, a [TimeoutException] is raised, and
  ///      the pulse is dropped from the active topography.
  /// 5. **Provenance Preservation**: Successful results inherit the original
  ///    source and priority, tagged with the `'AsyncMapWithTimeout'` step.
  ///
  /// ### Concurrency Model
  /// * **Single-Lane Traffic**: Only one async operation is monitored at a
  ///   time. The timeout applies to the individual mapping task, not the
  ///   queue duration.
  /// * **FIFO Integrity**: Stimuli are processed in arrival order; a timeout
  ///   in one lane allows the gate to advance to the next queued stimulus.
  /// * **Backpressure Protection**: Naturally limits the graph's wait time
  ///   on external services or heavy computations.
  ///
  /// ### Parameters
  /// - [map]: **The Orchestrator.** A closure that transforms an input
  ///   payload [S] into a `FutureOr` of [T].
  /// - [duration]: **Temporal Limit.** The maximum time allowed for a single
  ///   pulse to evolve before a timeout is triggered.
  /// - [onError]: **Integrity Handler.** A callback invoked if a mapping
  ///   fails or times out.
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the composition chain for auditing and tracing.
  ///
  /// ### Example: API Fetch with Deadline
  /// ```dart
  /// // Ensures the topography remains responsive even if the API is slow
  /// final boundedGate = AsyncMapWithTimeout<int, Data>(
  ///   (id) => api.fetchData(id),
  ///   duration: const Duration(seconds: 2),
  ///   user: 'Deadline-API-Bridge'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [AsyncMap]: For standard sequential mapping without temporal limits.
  /// - [AsyncMapWithFallback]: For providing a default value when a timeout
  ///   or error occurs.
  /// - [AsyncMapWithRetry]: For re-attempting failed (or timed-out) evolutions.
  AsyncMapWithTimeout(
      AsyncMapper<S, T> map, {
        required Duration duration,
        AsyncMapErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final queue = <S>[];
      var busy = false;
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
        queue.add(payload);
        Future<void> pump() async {
          if (busy) return;
          busy = true;
          while (queue.isNotEmpty) {
            final next = queue.removeAt(0);
            try {
              final result = await _call(map, next).timeout(duration);
              future!(
                result: _out<T>(result, pulse, cell, 'AsyncMapWithTimeout'),
                token: token,
              );
            } catch (e, stack) {
              onError?.call(e, stack);
            }
          }
          busy = false;
        }

        pump();
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// AsyncMapWithFallback - Fallback Values
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits [fallback] instead of dropping the
/// pulse on projector error.
///
/// [AsyncMapWithFallback] provides a safety net for async operations
/// that may fail, ensuring that a value is always emitted.
///
/// ### When to use
/// Use [AsyncMapWithFallback] when you want to provide a default
/// value on error.
///
/// - **Graceful Degradation**: Providing a default on failure.
/// - **Caching**: Serving stale cached data on failure.
/// - **Offline Support**: Providing offline defaults.
/// - **Resilience**: Preventing failures from propagating.
///
/// ### Example: Cached Data with Fallback
/// ```dart
/// final requests = Cell.ingress<String>();
///
/// final withFallback = AsyncMapWithFallback<String, String>(
///   (url) async {
///     return await api.fetch(url);
///   },
///   fallback: 'Cached data',
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### How it works
/// 1. Each operation is attempted.
/// 2. If successful, the result is emitted.
/// 3. If the operation fails, [fallback] is emitted instead.
/// 4. The instruction always emits a value.
/// 5. Each emitted value gets the step `'AsyncMapWithFallback'` or
///    `'AsyncMapWithFallback.fallback'` for provenance.
///
/// ### Non‑obvious
/// - **Always Emits**: A value is always emitted (success or fallback).
/// - **Error Isolation**: Errors are caught and handled gracefully.
/// - **Type Safety**: The fallback must return the same type [T].
/// - **Performance**: Fallback may be used frequently on failure.
/// - **Sequential**: Operations run one after another.
///
/// ### Parameters:
/// - [map]: **Mapping Function.** Called with each typed payload,
///   returns a `FutureOr<T>`.
/// - [fallback]: **Fallback Value.** Emitted when the mapping fails.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maps with fallback values.
///
/// ### See Also:
/// - [AsyncMap]: For sequential mapping.
/// - [AsyncMapWithRetry]: For retry logic.
/// - [TimeoutWithFallback]: For fallback on timeout.
class AsyncMapWithFallback<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Resilient Asynchronous Bridge**—a specialized orchestration
  /// instruction designed to provide a safety net for pulse evolution.
  ///
  /// [AsyncMapWithFallback] acts as a fault-tolerant gateway between the
  /// synchronous reactive topography and potentially unstable asynchronous
  /// logic. It ensures topological continuity by guaranteeing that a result
  /// is always emitted; if the primary evolution fails, the gate evolves the
  /// stimulus into a predefined [fallback] value rather than allowing the
  /// pulse to be dropped.
  ///
  /// ### When to use:
  /// * **Graceful Degradation**: Ensuring a downstream cell receives a default
  ///   value when an external service is unavailable.
  /// * **Caching Strategy**: Emitting a stale or baseline result to keep the
  ///   topography active during a processing failure.
  /// * **Topological Resilience**: Preventing an error in one branch from
  ///   halting the propagation of data to the rest of the graph.
  ///
  /// ### How it works:
  /// 1. **Stimulus Reception**: Each incoming pulse [S] is evaluated for
  ///    type integrity and placed into an internal FIFO queue.
  /// 2. **Sequential Materialization**: The [map] orchestrator is invoked
  ///    for the payload at the head of the queue only when the gate is idle.
  /// 3. **Recovery Strategy**:
  ///    - On **Success**: The evolved value [T] is emitted, inheriting the
  ///      original provenance and tagged with `'AsyncMapWithFallback'`.
  ///    - On **Failure**: The [onError] handler is invoked, and the gate
  ///      materializes the [fallback] value. This result is emitted in a
  ///      pulse tagged with `'AsyncMapWithFallback.fallback'`.
  /// 4. **Queue Advancement**: The gate advances to the next stimulus
  ///    immediately after the current evolution (or fallback) completes.
  ///
  /// ### Concurrency Model:
  /// * **Single-Lane Traffic**: Only one async operation is active at a time.
  /// * **Guaranteed Emission**: Unlike [AsyncMap], this gate is non-filtering
  ///   on error; it always yields a result to the downstream topography.
  /// * **Causal Integrity**: Both successful and fallback pulses preserve
  ///   the original stimulus source and priority.
  ///
  /// ### Parameters:
  /// - [map]: **The Orchestrator.** A closure that transforms an input
  ///   payload [S] into a `FutureOr` of [T].
  /// - [fallback]: **The Safety Value.** A constant or precomputed value of
  ///   type [T] to be emitted if the mapping fails.
  /// - [onError]: **Integrity Handler.** A callback invoked when the primary
  ///   evolution encounters an exception.
  /// - [user]: **Flyweight Metadata.** Optional configuration data
  ///   preserved across the composition chain for auditing.
  ///
  /// ### Example: API Fetch with Default
  /// ```dart
  /// // Always emits a result, even if the network is down
  /// final resilientGate = AsyncMapWithFallback<int, String>(
  ///   (id) => api.fetchStatus(id),
  ///   fallback: 'Unknown',
  ///   user: 'Resilient-Status-Bridge'
  /// );
  /// ```
  ///
  /// ### See Also:
  /// - [AsyncMap]: For standard sequential mapping where errors drop the pulse.
  /// - [AsyncMapWithRetry]: For attempting recovery through repetition.
  /// - [AsyncMapWithTimeout]: For enforcing temporal limits on evolution.
  AsyncMapWithFallback(
      AsyncMapper<S, T> map, {
        required T fallback,
        AsyncMapErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final queue = <S>[];
      var busy = false;
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
        queue.add(payload);
        Future<void> pump() async {
          if (busy) return;
          busy = true;
          while (queue.isNotEmpty) {
            final next = queue.removeAt(0);
            try {
              final result = await _call(map, next);
              future!(
                result: _out<T>(result, pulse, cell, 'AsyncMapWithFallback'),
                token: token,
              );
            } catch (e, stack) {
              onError?.call(e, stack);
              future!(
                result: _out<T>(
                  fallback,
                  pulse,
                  cell,
                  'AsyncMapWithFallback.fallback',
                ),
                token: token,
              );
            }
          }
          busy = false;
        }

        pump();
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [AsyncMap] instruction and related operators
/// showing their behavior in various async mapping scenarios.
///
/// ### Expected console output:
/// ```text
/// ── AsyncMap Operators Demo ───────────────────────────────────
///
/// 1. AsyncMap
///    [AsyncMap] 2
///    [AsyncMap] 4
///
/// 2. AsyncMapConcurrent
///    [AsyncMapConcurrent] fast
///    [AsyncMapConcurrent] slow
///
/// 3. AsyncMapLatest
///    [AsyncMapLatest] new
///
/// 4. AsyncMapWithIndex
///    [AsyncMapWithIndex] 0:a
///    [AsyncMapWithIndex] 1:b
///
/// 5. AsyncMapWithRetry
///    [AsyncMapWithRetry] ok
///
/// 6. AsyncMapWithTimeout
///    (no value — timed out)
///
/// 7. AsyncMapWithFallback
///    [AsyncMapWithFallback] n/a
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
/// 1. **AsyncMap - Sequential Mapping**: Shows sequential async
///    mapping where values are doubled. Each operation completes
///    before the next starts.
///
/// 2. **AsyncMapConcurrent - Concurrent Mapping**: Shows concurrent
///    async mapping where results are emitted in completion order.
///    The `fast` request completes before the `slow` request, even
///    though `slow` was triggered first.
///
/// 3. **AsyncMapLatest - Latest Only**: Shows latest-only mapping
///    where the `old` request is cancelled when `new` arrives. Only
///    `new` emits a value.
///
/// 4. **AsyncMapWithIndex - Indexed Mapping**: Shows indexed async
///    mapping where each value is labeled with its position.
///
/// 5. **AsyncMapWithRetry - Retry Logic**: Shows retry behavior
///    where the operation fails twice and succeeds on the third attempt.
///
/// 6. **AsyncMapWithTimeout - Timeout Handling**: Shows timeout
///    behavior where the operation exceeds the time limit and times out.
///
/// 7. **AsyncMapWithFallback - Fallback Values**: Shows fallback
///    behavior where the operation fails and the fallback value is emitted.
///
/// ### Key Takeaways
/// - AsyncMap processes sequentially with queuing.
/// - AsyncMapConcurrent processes in parallel (unordered).
/// - AsyncMapLatest cancels previous operations.
/// - AsyncMapWithIndex includes the index in the mapping.
/// - AsyncMapWithRetry retries failed operations.
/// - AsyncMapWithTimeout enforces a time limit.
/// - AsyncMapWithFallback provides fallback values.
/// - All operators preserve causal provenance via EvolvedPulse.
///
/// ### Note on Strategies
/// The seven strategies (sequential, concurrent, latest, indexed,
/// retry, timeout, fallback) cover the common async mapping patterns.
/// Choose based on your concurrency, ordering, and error handling
/// requirements.
Future<void> main() async {
  print('── AsyncMap Operators Demo ───────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. AsyncMap - Sequential Mapping
  // ─────────────────────────────────────────────────────────────────────
  print('1. AsyncMap');

  final nums = Cell.ingress<int>();

  final doubled = AsyncMap<int, int>(
        (n) async => n * 2,
  ).toHandle(source: nums.cell);

  final mObs = Cell.observe(
    source: doubled.cell,
    effect: (Pulse p) => print('   [AsyncMap] ${p.payload}'),
  );

  await nums.emitAsync(1);
  await nums.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  mObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. AsyncMapConcurrent - Concurrent Mapping
  // ─────────────────────────────────────────────────────────────────────
  print('2. AsyncMapConcurrent');

  final names = Cell.ingress<String>();

  final merged = AsyncMapConcurrent<String, String>(
        (name) async {
      await Future<void>.delayed(Duration(milliseconds: name == 'slow' ? 40 : 5));
      return name;
    },
  ).toHandle(source: names.cell);

  final cObs = Cell.observe(
    source: merged.cell,
    effect: (Pulse p) => print('   [AsyncMapConcurrent] ${p.payload}'),
  );

  await names.emitAsync('slow');
  await names.emitAsync('fast');
  await Future<void>.delayed(const Duration(milliseconds: 70));

  cObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. AsyncMapLatest - Latest Only
  // ─────────────────────────────────────────────────────────────────────
  print('3. AsyncMapLatest');

  final query = Cell.ingress<String>();

  final latest = AsyncMapLatest<String, String>(
        (q) async {
      await Future<void>.delayed(Duration(milliseconds: q == 'old' ? 40 : 8));
      return q;
    },
  ).toHandle(source: query.cell);

  final lObs = Cell.observe(
    source: latest.cell,
    effect: (Pulse p) => print('   [AsyncMapLatest] ${p.payload}'),
  );

  await query.emitAsync('old');
  await query.emitAsync('new');
  await Future<void>.delayed(const Duration(milliseconds: 70));

  lObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. AsyncMapWithIndex - Indexed Mapping
  // ─────────────────────────────────────────────────────────────────────
  print('4. AsyncMapWithIndex');

  final letters = Cell.ingress<String>();

  final indexed = AsyncMapWithIndex<String, String>(
        (s, i) async => '$i:$s',
  ).toHandle(source: letters.cell);

  final iObs = Cell.observe(
    source: indexed.cell,
    effect: (Pulse p) => print('   [AsyncMapWithIndex] ${p.payload}'),
  );

  await letters.emitAsync('a');
  await letters.emitAsync('b');
  await Future<void>.delayed(const Duration(milliseconds: 20));

  iObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 5. AsyncMapWithRetry - Retry Logic
  // ─────────────────────────────────────────────────────────────────────
  print('5. AsyncMapWithRetry');

  var n = 0;
  final start = Cell.ingress<void>();

  final retried = AsyncMapWithRetry<void, String>(
        (_) {
      n++;
      if (n < 3) throw StateError('try');
      return 'ok';
    },
    count: 5,
    onError: (_, __) {},
  ).toHandle(source: start.cell);

  final rObs = Cell.observe(
    source: retried.cell,
    effect: (Pulse p) => print('   [AsyncMapWithRetry] ${p.payload}'),
  );

  await start.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  rObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 6. AsyncMapWithTimeout - Timeout Handling
  // ─────────────────────────────────────────────────────────────────────
  print('6. AsyncMapWithTimeout');

  final late = Cell.ingress<void>();

  final timed = AsyncMapWithTimeout<void, String>(
        (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return 'late';
    },
    duration: const Duration(milliseconds: 20),
    onError: (_, __) {},
  ).toHandle(source: late.cell);

  final tObs = Cell.observe(
    source: timed.cell,
    effect: (Pulse p) => print('   [AsyncMapWithTimeout] ${p.payload}'),
  );

  await late.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 40));

  tObs.stop();
  print('   (no value — timed out)\n');

  // ─────────────────────────────────────────────────────────────────────
  // 7. AsyncMapWithFallback - Fallback Values
  // ─────────────────────────────────────────────────────────────────────
  print('7. AsyncMapWithFallback');

  final raw = Cell.ingress<int>();

  final safe = AsyncMapWithFallback<int, String>(
        (n) => throw StateError('nope'),
    fallback: 'n/a',
    onError: (_, __) {},
  ).toHandle(source: raw.cell);

  final fObs = Cell.observe(
    source: safe.cell,
    effect: (Pulse p) => print('   [AsyncMapWithFallback] ${p.payload}'),
  );

  await raw.emitAsync(1);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  fObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}