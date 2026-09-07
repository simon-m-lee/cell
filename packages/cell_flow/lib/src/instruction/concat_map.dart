// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';

/// Flow instructions that flatten inner sequences (Rx `concatMap` family).
///
/// | Operator | Rx analogue | Overlap | Order |
/// |---|---|---|---|
/// | [ConcatMap] | `concatMap` | no | trigger then inner |
/// | [ConcatMapTo] | `concatMapTo` | no | same inner every time |
/// | [ConcatMapLatest] | `switchMap` | cancel previous | latest inner |
/// | [ConcatMapFirst] | `exhaustMap` | drop while busy | first inner |
///
/// [mapper] / inner sources may return a [Stream], [Future], [Iterable],
/// a raw value, or `null` (drop). Nested values are drained recursively.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for flatten operations.
///
/// Called when an error occurs during flattening operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = FlattenErrorHandler((error, stack) {
///   print('Flatten error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef FlattenErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// Defines a **Pulse Expansion Orchestrator**—a specialized closure used to
/// transform a single stimulus into a complex **Inner Sequence**.
///
/// A [FlattenMapper] is responsible for the transition from a discrete
/// payload [S] to a materializable topography (e.g., [Stream], [Future],
/// [Iterable], or another [Pulse]).
///
/// ### Example
/// ```dart
/// final mapper = FlattenMapper<int>((id) async {
///   return await api.fetchUser(id);
/// });
/// ```
typedef FlattenMapper<S> = FutureOr<Object?> Function(S value);

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
/// sequences that flatten operators can produce.
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
    final value = await inner;
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

// ─────────────────────────────────────────────────────────────
// ConcatMap - Sequential Flattening
// ─────────────────────────────────────────────────────────────

/// Sequential flatten: each inner sequence finishes before the next starts
/// (Rx `concatMap`).
///
/// [ConcatMap] acts as a **Sequential Flattener**. Each incoming trigger
/// is transformed into an inner sequence, and the items are emitted in order.
/// Each inner sequence finishes before the next starts.
///
/// ### When to use
/// Use [ConcatMap] when you need to flatten sequences in order:
///
/// - **Multi-Phase Workflows**: Each trigger starts a workflow that must
///   complete before the next starts.
/// - **Unrolling Lists/Streams**: Expanding a list of items per command.
/// - **Ordered Processing**: When the order of results must match the
///   order of triggers.
/// - **Resource Constraints**: When you want to limit concurrent operations.
/// - **File Processing**: Processing files one at a time.
/// - **Database Transactions**: Sequential transactions.
///
/// ### Choosing Between Flatten Operators
/// - **Use [ConcatMap]** for **Sequential**: When order matters and
///   operations must run one at a time.
/// - **Use [ConcatMapTo]** for **Static Inner**: When the inner sequence
///   is the same for every trigger.
/// - **Use [ConcatMapLatest]** for **Latest Only**: When you only care
///   about the most recent operation.
/// - **Use [ConcatMapFirst]** for **Exhaust**: When you want to ignore
///   new triggers while busy.
///
/// ### Comparison with Other Operators
/// | Operator | Order | Cancels | Queues | Concurrency |
/// |----------|-------|---------|--------|-------------|
/// | **ConcatMap** | Preserved | No | Yes | 1 (sequential) |
/// | **ConcatMapTo** | Preserved | No | Yes | 1 (sequential) |
/// | **ConcatMapLatest** | N/A | Yes | No | 1 (latest only) |
/// | **ConcatMapFirst** | N/A | No | No | 1 (drop busy) |
///
/// ### How it works
/// 1. Each trigger pulse's payload is extracted and type-checked.
/// 2. The [mapper] function is called with the payload.
/// 3. The [mapper] returns an inner sequence (Stream, Future, Iterable, or value).
/// 4. The inner sequence is drained recursively, emitting each item.
/// 5. The next trigger is queued and only starts when the current sequence completes.
/// 6. Results are emitted in input order.
///
/// ### Supported Inner Types
/// The [mapper] can return any of the following:
/// - **[Stream\<T\>]**: Each event in the stream is emitted sequentially.
/// - **[Future\<T\>]**: The single value is emitted when the future completes.
/// - **[Iterable\<T\>]**: Each element is emitted in order.
/// - **[T]**: The value itself is emitted directly.
/// - **`null`**: No emission (the pulse is dropped).
/// - **Nested combinations**: `Future<Iterable<T>>`, etc., are recursively expanded.
///
/// ### Non‑obvious
/// - **Strict Sequencing**: The instruction processes inputs one at a time.
///   Each sequence must complete before the next starts.
/// - **Queueing**: If triggers arrive while a sequence is in progress,
///   they are queued in FIFO order.
/// - **Error Handling**: Errors in the [mapper] or during draining are
///   reported via [onError].
/// - **Backpressure**: The instruction processes inputs sequentially,
///   automatically providing backpressure.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Example: Sequential Order Processing
/// ```dart
/// final orders = Cell.ingress<String>();
///
/// final lifecycle = ConcatMap<String, String>((id) async* {
///   yield '$id:created';
///   yield '$id:paid';
///   yield '$id:shipped';
/// }).toHandle(source: orders.cell);
///
/// orders.emit('ORD-1');
/// // -> ORD-1:created, ORD-1:paid, ORD-1:shipped
/// orders.emit('ORD-2');
/// // starts after ORD-1 completes
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Flattening Logic.** Takes an input value and returns
///   an inner sequence (Stream, Future, Iterable, or value).
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that flattens sequences sequentially.
///
/// ### See Also:
/// - [ConcatMapTo]: For static inner sequences.
/// - [ConcatMapLatest]: For latest-only flattening.
/// - [ConcatMapFirst]: For exhaust flattening.
/// - [AsyncExpand]: For flattening with different strategies.
class ConcatMap<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Sequential Expansion Bridge**—a specialized orchestration
  /// instruction designed for ordered, one-by-one inner pulse evolution.
  ///
  /// This constructor initializes an orchestrator that treats each incoming
  /// stimulus as a trigger for an **Inner Sequence**. It enforces **Exhaustive
  /// Drainage**, ensuring that each sequence is fully evolved to completion
  /// before the next materialized sequence begins.
  ///
  /// **Parameters:**
  /// - [mapper]: **The Sequential Orchestrator.** A closure that maps the
  ///   input payload [S] to an inner sequence (Stream, Future, Iterable, or raw value).
  /// - [onError]: **Integrity Handler.** Invoked if an inner evolution
  ///   fails; the gate proceeds to the next queued sequence after handling.
  /// - [user]: **Flyweight Metadata.** Optional configuration data preserved
  ///   across the topography for auditing.
  ///
  /// ### Topographical Behavior:
  /// * **FIFO Queuing**: If a new stimulus arrives while an inner sequence
  ///   is still being drained, the new stimulus is queued to preserve causal order.
  /// * **Causal Integrity**: Guaranteed to emit all pulses from the first
  ///   sequence before starting the second.
  /// * **Provenance Preservation**: Every emitted value [T] inherits the
  ///   source and priority of the triggering stimulus, tagged with the
  ///   `'ConcatMap'` step.
  ///
  /// ### Example: Sequential Order Lifecycle
  /// ```dart
  /// final orders = Cell.ingress<String>();
  ///
  /// final lifecycle = ConcatMap<String, String>((id) async* {
  ///   yield '$id:created';
  ///   yield '$id:paid';
  /// }).toHandle(source: orders.cell);
  /// ```
  ///
  /// ### See Also:
  /// - [ConcatMapTo]: For static inner sequences.
  /// - [ConcatMapLatest]: For latest-only flattening.
  /// - [ConcatMapFirst]: For exhaust flattening.
  ConcatMap(
      FlattenMapper<S> mapper, {
        FlattenErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final queue = _ConcatQueue();
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
        queue.enqueue(() async {
          try {
            final inner = await Future.sync(() => mapper(payload));
            await _drain(inner, (value) {
              if (value is T) {
                future!(
                  result: _out<T>(value, cell, pulse, 'ConcatMap'),
                  token: token,
                );
              }
            });
          } catch (e, stack) {
            onError?.call(e, stack);
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// ConcatMapTo - Static Inner Sequence
// ─────────────────────────────────────────────────────────────

/// Rx `concatMapTo` — ignore the trigger payload and flatten the same
/// inner sequence after every pulse.
///
/// [ConcatMapTo] is similar to [ConcatMap] but the inner sequence is
/// fixed and does not depend on the trigger payload.
///
/// ### When to use
/// Use [ConcatMapTo] when you need to play the same sequence for every
/// trigger.
///
/// - **Static Workflows**: Playing the same workflow for every trigger.
/// - **Initialization**: Playing the same initialization sequence.
/// - **Test Data**: Playing the same test sequence repeatedly.
/// - **Polling**: Performing the same poll sequence each time.
/// - **Heartbeats**: Sending the same heartbeat sequence.
///
/// ### Example: Static Sequence
/// ```dart
/// final clicks = Cell.ingress<void>();
///
/// final echo = ConcatMapTo<void, String>(() async* {
///   yield 'ping';
///   yield 'pong';
/// }).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // -> ping, pong
/// clicks.emit(null); // -> ping, pong
/// ```
///
/// ### How it works
/// 1. Each trigger pulse starts the same inner sequence.
/// 2. The sequence is drained completely.
/// 3. The next trigger is queued until the current sequence completes.
/// 4. Each emitted value gets the step `'ConcatMapTo'` for provenance.
///
/// ### Parameters:
/// - [inner]: **Static Inner.** A function that returns the same inner
///   sequence for every trigger.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload (ignored).
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that flattens a static sequence.
///
/// ### See Also:
/// - [ConcatMap]: For dynamic inner sequences.
/// - [ConcatMapLatest]: For latest-only flattening.
/// - [ConcatMapFirst]: For exhaust flattening.
class ConcatMapTo<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Static Sequential Expansion Bridge**—a specialized
  /// orchestration instruction designed to flatten a constant inner sequence
  /// for every incoming pulse.
  ///
  /// [ConcatMapTo] (analogous to Rx `concatMapTo`) treats each incoming stimulus
  /// as a trigger to materialize the *same* [inner] sequence. It enforces
  /// **Exhaustive Drainage**, ensuring that if multiple pulses arrive in rapid
  /// succession, each expansion is fully completed in a **FIFO Queue** before
  /// the next begins.
  ///
  /// **Parameters:**
  /// - [inner]: **The Static Orchestrator.** A closure that returns the same
  ///   inner sequence (Stream, Future, Iterable, or raw value) to be
  ///   materialized on every stimulus.
  /// - [onError]: **Integrity Handler.** Invoked if an inner evolution fails;
  ///   the gate proceeds to the next queued sequence after handling.
  /// - [user]: **Flyweight Metadata.** Optional configuration data preserved
  ///   across the topography for auditing.
  ///
  /// ### Topographical Behavior:
  /// * **Payload Discarding**: The payload of the triggering pulse is ignored
  ///   in favor of the static [inner] definition.
  /// * **Sequential Queuing**: Even though the inner sequence is identical,
  ///   emissions are queued to prevent interleaving and maintain causal order.
  /// * **Provenance Preservation**: Every emitted value inherits the source
  ///   and priority of the pulse that triggered that specific expansion cycle,
  ///   tagged with the `'ConcatMapTo'` step.
  ///
  /// ### Example: Static Ping/Pong
  /// ```dart
  /// final clicks = Cell.ingress<void>();
  ///
  /// final echo = ConcatMapTo<void, String>(() async* {
  ///   yield 'ping';
  ///   yield 'pong';
  /// }).toHandle(source: clicks.cell);
  /// ```
  ///
  /// ### See Also:
  /// - [ConcatMap]: For dynamic inner sequences.
  /// - [ConcatMapLatest]: For latest-only flattening.
  /// - [ConcatMapFirst]: For exhaust flattening.
  ConcatMapTo(
      FutureOr<Object?> Function() inner, {
        FlattenErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final queue = _ConcatQueue();
      return (pulse, {cell, user, future, token}) {
        queue.enqueue(() async {
          try {
            final seq = await Future.sync(inner);
            await _drain(seq, (value) {
              if (value is T) {
                future!(
                  result: _out<T>(value, cell, pulse, 'ConcatMapTo'),
                  token: token,
                );
              }
            });
          } catch (e, stack) {
            onError?.call(e, stack);
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// ConcatMapLatest - Latest-Only Flattening
// ─────────────────────────────────────────────────────────────

/// Latest-only flatten (Rx `switchMap` semantics, concatMap naming).
///
/// A new trigger cancels emission from the previous inner sequence.
/// Use for search-as-you-type or selection changes.
///
/// ### When to use
/// Use [ConcatMapLatest] when you only care about the most recent
/// operation.
///
/// - **Search-as-you-type**: Only the latest search query matters.
/// - **Real-time Updates**: Only the most recent update is relevant.
/// - **Navigation**: Only the latest route matters.
/// - **User Input**: Only the latest user input matters.
/// - **Selection Changes**: Only the latest selection matters.
///
/// ### Example: Search-as-you-Type
/// ```dart
/// final query = Cell.ingress<String>();
///
/// final results = ConcatMapLatest<String, Result>(
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
/// 1. Each incoming pulse triggers the [mapper] function.
/// 2. A new generation ID is assigned to each trigger.
/// 3. Any previous in-flight operation is cancelled.
/// 4. Only the result from the latest generation is emitted.
/// 5. If [mapper] throws an error, it's reported only for the current
///    generation.
/// 6. Each emitted value gets the step `'ConcatMapLatest'` for provenance.
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
/// - [mapper]: **Mapping Function.** Called with each typed payload,
///   returns an inner sequence.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that flattens latest-only sequences.
///
/// ### See Also:
/// - [ConcatMap]: For sequential flattening.
/// - [ConcatMapTo]: For static inner sequences.
/// - [ConcatMapFirst]: For exhaust flattening.
/// - [AsyncExpandLatest]: For latest-only flattening.
class ConcatMapLatest<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes a **Static Sequential Expansion Bridge**—a specialized
  /// orchestration instruction designed to flatten a constant inner sequence
  /// for every incoming pulse.
  ///
  /// [ConcatMapTo] (analogous to Rx `concatMapTo`) treats each incoming stimulus
  /// as a trigger to materialize the *same* [inner] sequence. It enforces
  /// **Exhaustive Drainage**, ensuring that if multiple pulses arrive in rapid
  /// succession, each expansion is fully completed in a **FIFO Queue** before
  /// the next begins.
  ///
  /// **Parameters:**
  /// - [inner]: **The Static Orchestrator.** A closure that returns the same
  ///   inner sequence (Stream, Future, Iterable, or raw value) to be
  ///   materialized on every stimulus.
  /// - [onError]: **Integrity Handler.** Invoked if an inner evolution fails;
  ///   the gate proceeds to the next queued sequence after handling.
  /// - [user]: **Flyweight Metadata.** Optional configuration data preserved
  ///   across the topography for auditing.
  ///
  /// ### Topographical Behavior:
  /// * **Payload Discarding**: The payload of the triggering pulse is ignored
  ///   in favor of the static [inner] definition.
  /// * **Sequential Queuing**: Even though the inner sequence is identical,
  ///   emissions are queued to prevent interleaving and maintain causal order.
  /// * **Provenance Preservation**: Every emitted value inherits the source
  ///   and priority of the pulse that triggered that specific expansion cycle,
  ///   tagged with the `'ConcatMapTo'` step.
  ConcatMapLatest(
      FlattenMapper<S> mapper, {
        FlattenErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final gen = _GenerationState();
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
        final id = ++gen.generation;
        Future<void>(() async {
          try {
            final inner = await Future.sync(() => mapper(payload));
            if (id != gen.generation) return;
            await _drain(
              inner,
                  (item) {
                if (id != gen.generation) return;
                if (item is T) {
                  future!(
                    result: _out<T>(item, cell, pulse, 'ConcatMapLatest'),
                    token: token,
                  );
                }
              },
              stillLive: () => id == gen.generation,
            );
          } catch (e, stack) {
            if (id == gen.generation) onError?.call(e, stack);
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// ConcatMapFirst - Exhaust Flattening
// ─────────────────────────────────────────────────────────────

/// Rx `exhaustMap` semantics, concatMap naming.
///
/// [ConcatMapFirst] ignores (drops) new triggers while an inner
/// sequence is still running. This prevents overlapping operations.
///
/// ### When to use
/// Use [ConcatMapFirst] when you need to prevent overlapping operations:
///
/// - **Submit/Save Buttons**: Prevent double-submission
/// - **Form Submission**: Prevent duplicate form submissions
/// - **Idempotent Operations**: Operations that should only run once at a time
/// - **Rate Limiting**: You want to limit the rate of operations
/// - **Resource Protection**: You want to prevent resource exhaustion
/// - **Button Click Prevention**: Prevent double-click issues
/// - **API Calls**: Prevent concurrent API calls
/// - **File Uploads**: Prevent overlapping uploads
///
/// ### Example: Submit Protection
/// ```dart
/// final clicks = Cell.ingress<void>();
///
/// final submit = ConcatMapFirst<void, String>(
///   (_) async* {
///     await submitForm();
///     yield 'Submitted!';
///   },
/// ).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // Starts submission
/// clicks.emit(null); // Dropped (busy)
/// // Only the first submission is processed
/// ```
///
/// ### How it works
/// 1. The first trigger starts an inner sequence.
/// 2. While the sequence is in flight, all subsequent triggers are dropped.
/// 3. When the sequence completes, the instruction is ready for the next trigger.
/// 4. Results are emitted from the first sequence.
/// 5. Each emitted value gets the step `'ConcatMapFirst'` for provenance.
///
/// ### Non‑obvious
/// - **Drop While Busy**: Triggers while busy are silently dropped.
/// - **One at a Time**: Only one sequence can be in flight at a time.
/// - **Error Handling**: Errors are reported via [onError].
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [mapper]: **Mapping Function.** Called with each typed payload,
///   returns an inner sequence.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that flattens exhaust sequences.
///
/// ### See Also:
/// - [ConcatMap]: For sequential flattening.
/// - [ConcatMapTo]: For static inner sequences.
/// - [ConcatMapLatest]: For latest-only flattening.
/// - [AsyncExpandExhaust]: For exhaust flattening.
class ConcatMapFirst<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {

  /// Synthesizes an **Exclusive Sequential Expansion Gate**—a specialized
  /// orchestration instruction designed for prioritized, non-overlapping pulse evolution.
  ///
  /// [ConcatMapFirst] (analogous to Rx `exhaustMap`) treats each incoming stimulus
  /// as a trigger for an **Inner Sequence**. It implements an **Exhaustive Gating**
  /// strategy: while an inner sequence is being drained, the gate remains "busy"
  /// and silently discards all incoming stimuli. This ensures the topography
  /// reflects only atomic, uninterrupted evolutions.
  ///
  /// ### Topographical Behavior
  /// * **Exhaustive Isolation**: Protects downstream cells from redundant or
  ///   overlapping workloads by dropping pulses that arrive during an active materialization.
  /// * **Causal Integrity**: Guaranteed to evolve a single sequence to completion
  ///   before becoming available for a new stimulus.
  /// * **Provenance Preservation**: Every emitted value inherits the source
  ///   and priority of the stimulus that successfully opened the gate,
  ///   tagged with the `'ConcatMapFirst'` step.
  ///
  /// ### When to use
  /// - **Atomic Operations**: Ideal for "Submit" or "Save" actions where
  ///   subsequent clicks must be ignored until the first process finishes.
  /// - **Resource Protection**: Preventing expensive or state-sensitive
  ///   expansions from double-firing.
  ///
  /// ### Type Parameters
  /// * [S]: **Stimulus Payload Type.** The type of data contained within the incoming pulses.
  /// * [T]: **Expanded Payload Type.** The type of data yielded by the inner sequences.
  ///
  /// ### Example: Submit Protection
  /// ```dart
  /// final clicks = Cell.ingress<void>();
  ///
  /// final submit = ConcatMapFirst<void, String>(
  ///   (_) async* {
  ///     await submitForm();
  ///     yield 'Submitted!';
  ///   },
  /// ).toHandle(source: clicks.cell);
  /// ```
  ///
  /// ### See Also:
  /// - [ConcatMap]: For sequential flattening.
  /// - [ConcatMapTo]: For static inner sequences.
  /// - [ConcatMapLatest]: For latest-only flattening.
  ConcatMapFirst(
      FlattenMapper<S> mapper, {
        FlattenErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _BusyState();
      return (pulse, {cell, user, future, token}) {
        if (state.busy) return null;
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
        state.busy = true;
        Future<void>(() async {
          try {
            final inner = await Future.sync(() => mapper(payload));
            await _drain(inner, (item) {
              if (item is T) {
                future!(
                  result: _out<T>(item, cell, pulse, 'ConcatMapFirst'),
                  token: token,
                );
              }
            });
          } catch (e, stack) {
            onError?.call(e, stack);
          } finally {
            state.busy = false;
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

/// Internal state for sequential queuing.
///
/// Maintains a chain of async operations that run one after another.
class _ConcatQueue {
  /// The tail of the async queue.
  Future<void> tail = Future<void>.value();

  /// Enqueues a job to run after the current tail completes.
  void enqueue(Future<void> Function() job) {
    tail = tail.then((_) => job()).catchError((_) {});
  }
}

/// Internal state for generation-based operators.
///
/// Tracks the current generation ID for stale result detection.
class _GenerationState {
  /// The current generation ID. Incremented on each new pulse.
  int generation = 0;
}

/// Internal state for busy/flags.
///
/// Tracks whether an operation is currently in progress.
class _BusyState {
  /// Whether the gate is currently busy.
  bool busy = false;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// Demonstration of the concatMap family.
///
/// ### Expected console output:
/// ```text
/// ── ConcatMap Operators Demo ──────────────────────────────────
///
/// 1. ConcatMap - Sequential lifecycle
///    [ConcatMap] ORD-1:created
///    [ConcatMap] ORD-1:paid
///    [ConcatMap] ORD-2:created
///    [ConcatMap] ORD-2:paid
///
/// 2. ConcatMapTo - Same inner every trigger
///    [ConcatMapTo] ping
///    [ConcatMapTo] pong
///    [ConcatMapTo] ping
///    [ConcatMapTo] pong
///
/// 3. ConcatMapLatest - Latest inner only
///    [ConcatMapLatest] new-1
///    [ConcatMapLatest] new-2
///
/// 4. ConcatMapFirst - Ignore while busy
///    [ConcatMapFirst] 1-a
///    [ConcatMapFirst] 1-b
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
/// 1. **ConcatMap - Sequential Lifecycle**: Shows sequential flattening
///    where ORD-1 is fully processed before ORD-2 starts. Each order
///    emits 'created' and 'paid' events.
///
/// 2. **ConcatMapTo - Static Inner**: Shows static inner sequence
///    flattening where the same sequence ('ping', 'pong') is played
///    for every trigger.
///
/// 3. **ConcatMapLatest - Latest Inner Only**: Shows latest-only
///    flattening where the 'old' trigger is cancelled when 'new'
///    arrives. Only 'new' emits values.
///
/// 4. **ConcatMapFirst - Ignore While Busy**: Shows exhaust flattening
///    where triggers 2 and 3 are dropped while trigger 1 is still
///    processing. Only trigger 1 emits values.
///
/// ### Key Takeaways
/// - ConcatMap processes sequentially with queuing.
/// - ConcatMapTo uses the same inner sequence for every trigger.
/// - ConcatMapLatest cancels previous operations.
/// - ConcatMapFirst ignores new triggers while busy.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - _drain handles Future, Stream, Iterable, and raw values.
///
/// ### Note on Strategies
/// The four strategies (concat, static, latest, exhaust) cover the
/// common flattening patterns. Choose based on your ordering and
/// concurrency requirements.
Future<void> main() async {
  print('── ConcatMap Operators Demo ──────────────────────────────────\n');

  print('1. ConcatMap - Sequential lifecycle');
  final orders = Cell.ingress<String>();
  final life = ConcatMap<String, String>((id) async* {
    yield '$id:created';
    await Future<void>.delayed(const Duration(milliseconds: 25));
    yield '$id:paid';
  }).toHandle(source: orders.cell);
  final lifeObs = Cell.observe(
    source: life.cell,
    effect: (Pulse p) => print('   [ConcatMap] ${p.payload}'),
  );
  await orders.emitAsync('ORD-1');
  await orders.emitAsync('ORD-2');
  await Future<void>.delayed(const Duration(milliseconds: 120));
  lifeObs.stop();
  print('');

  print('2. ConcatMapTo - Same inner every trigger');
  final clicks = Cell.ingress<void>();
  final echo = ConcatMapTo<void, String>(() async* {
    yield 'ping';
    yield 'pong';
  }).toHandle(source: clicks.cell);
  final echoObs = Cell.observe(
    source: echo.cell,
    effect: (Pulse p) => print('   [ConcatMapTo] ${p.payload}'),
  );
  await clicks.emitAsync(null);
  await clicks.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  echoObs.stop();
  print('');

  print('3. ConcatMapLatest - Latest inner only');
  final query = Cell.ingress<String>();
  final latest = ConcatMapLatest<String, String>((q) async* {
    await Future<void>.delayed(Duration(milliseconds: q == 'old' ? 40 : 10));
    yield '$q-1';
    yield '$q-2';
  }).toHandle(source: query.cell);
  final latestObs = Cell.observe(
    source: latest.cell,
    effect: (Pulse p) => print('   [ConcatMapLatest] ${p.payload}'),
  );
  await query.emitAsync('old');
  await query.emitAsync('new');
  await Future<void>.delayed(const Duration(milliseconds: 80));
  latestObs.stop();
  print('');

  print('4. ConcatMapFirst - Ignore while busy');
  final taps = Cell.ingress<int>();
  final first = ConcatMapFirst<int, String>((n) async* {
    yield '$n-a';
    await Future<void>.delayed(const Duration(milliseconds: 40));
    yield '$n-b';
  }).toHandle(source: taps.cell);
  final firstObs = Cell.observe(
    source: first.cell,
    effect: (Pulse p) => print('   [ConcatMapFirst] ${p.payload}'),
  );
  await taps.emitAsync(1);
  await taps.emitAsync(2);
  await taps.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  firstObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}