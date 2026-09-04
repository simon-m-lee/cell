// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that flatten inner sequences (Rx `concatMap` family).
///
/// These operators transform each incoming trigger into an inner sequence
/// (Stream, Future, Iterable, or value) and flatten the results. The key
/// difference between them is how they handle overlapping sequences and
/// ordering.
///
/// | Operator | Rx analogue | Overlap | Order |
/// |---|---|---|---|
/// | [ConcatMap] | `concatMap` | no | trigger then inner |
/// | [ConcatMapTo] | `concatMapTo` | no | same inner every time |
/// | [ConcatAll] | `concatAll` | no | payload *is* the inner |
/// | [ConcatMapLatest] | `switchMap` | cancel previous | latest inner |
/// | [ConcatMapFirst] | `exhaustMap` | drop while busy | first inner |
///
/// [mapper] / inner sources may return a [Stream], [Future], [Iterable],
/// a raw value, or `null` (drop). Nested values are drained recursively.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef FlattenErrorHandler = void Function(Object error, StackTrace? stackTrace);
typedef FlattenMapper<S> = FutureOr<Object?> Function(S value);

Pulse<T> _out<T>(T value, Cell? cell, Pulse trigger, String step) {
  return Pulse<T>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

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
// ConcatMap
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that sequentially flattens inner sequences
/// (Rx `concatMap`).
///
/// [ConcatMap] acts as a **Sequential Flattener**. Each incoming trigger
/// is transformed into an inner sequence (Stream, Future, Iterable, or value),
/// and the items are emitted in order. Each inner sequence finishes before
/// the next starts, ensuring strict FIFO ordering.
///
/// ### When to use
/// Use [ConcatMap] when you need to flatten sequences in order:
///
/// - **Multi-Phase Workflows**: Each trigger starts a workflow that must
///   complete before the next starts.
/// - **Unrolling Lists/Streams**: Expanding a list of items per command
///   in FIFO order.
/// - **Ordered Processing**: When the order of results must match the
///   order of triggers.
/// - **Resource Constraints**: When you want to limit concurrent operations.
/// - **File Processing**: Processing files one at a time.
/// - **Database Transactions**: Sequential transactions that must not overlap.
/// - **API Rate Limiting**: Throttling API calls by processing them sequentially.
/// - **Stream Processing**: Processing ordered data streams.
///
/// ### Choosing Between Flattening Patterns
/// - **Use [ConcatMap]** for **Sequential Flattening**: When order matters
///   and you want to finish one sequence before starting the next.
/// - **Use [ConcatMapTo]** for **Same Inner**: When you want to flatten
///   the same inner sequence for every trigger.
/// - **Use [ConcatAll]** for **Payload as Inner**: When the payload itself
///   is the sequence to flatten.
/// - **Use [ConcatMapLatest]** for **Latest Only**: When you only care
///   about the most recent sequence (cancels previous).
/// - **Use [ConcatMapFirst]** for **First Wins**: When you want to drop
///   triggers while busy (exhaust).
///
/// ### Comparison with Other Operators
/// | Operator | Overlap | Order | Use Case |
/// |----------|---------|-------|----------|
/// | **ConcatMap** | no | trigger order | Sequential flattening |
/// | **ConcatMapTo** | no | trigger order | Same inner every time |
/// | **ConcatAll** | no | trigger order | Payload is the inner |
/// | **ConcatMapLatest** | cancel previous | latest | Latest only |
/// | **ConcatMapFirst** | drop while busy | first | First wins |
/// | **ConcatMapConcurrent** | yes (with limit) | completion order | Limited parallel |
/// | **ConcatMapMerge** | yes | completion order | Unordered parallel |
///
/// ### How it works
/// 1. Each trigger pulse's payload is extracted and type-checked against [S].
/// 2. The [mapper] function is called with the payload.
/// 3. The [mapper] returns an inner sequence (Stream, Future, Iterable, or value).
/// 4. The inner sequence is drained recursively, emitting each item as a [Pulse].
/// 5. The next trigger is queued and only starts when the current sequence completes.
/// 6. Results are emitted in input order (FIFO).
/// 7. The instruction preserves causal provenance.
///
/// ### Supported Inner Types
/// The [mapper] can return any of the following:
/// - **[Stream\<T\>]**: Each event in the stream is emitted sequentially.
/// - **[Future\<T\>]**: The single value is emitted when the future completes.
/// - **[Iterable\<T\>]**: Each element is emitted in order.
/// - **[T]**: The value itself is emitted directly.
/// - **`null`**: No emission (the pulse is dropped).
/// - **Nested combinations**: `Future<Iterable<T>>`, `Stream<Future<T>>`,
///   etc., are recursively expanded.
///
/// ### Non‑obvious
/// - **Strict Sequencing**: The instruction processes inputs one at a time.
///   Each sequence must complete before the next starts.
/// - **Queueing**: If triggers arrive while a sequence is in progress,
///   they are queued in FIFO order.
/// - **Type Safety**: The instruction is generic over [S] (input type) and
///   [T] (output type), ensuring compile-time type safety.
/// - **Error Handling**: Errors in the [mapper] or during draining are
///   reported via [onError]. The instruction continues with the next input.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
/// - **Backpressure**: The instruction processes inputs sequentially,
///   automatically providing backpressure.
/// - **Recursive Draining**: The instruction recursively drains nested
///   async types. For example, `Future<Stream<T>>` will wait for the future,
///   then drain the stream.
/// - **Memory Efficiency**: Only one inner sequence is in flight at a time.
///
/// ### Example: Order Lifecycle
/// ```dart
/// final orders = Cell.ingress<String>();
/// final lifecycle = ConcatMap<String, String>((id) async* {
///   yield '$id:created';
///   await Future.delayed(Duration(milliseconds: 100));
///   yield '$id:paid';
///   yield '$id:shipped';
/// }).toHandle(source: orders.cell);
///
/// orders.emit('ORD-1'); // -> ORD-1:created, ORD-1:paid, ORD-1:shipped
/// orders.emit('ORD-2'); // starts after ORD-1 completes
/// ```
///
/// ### Example: Document Processing
/// ```dart
/// final docIds = Cell.ingress<int>();
/// final pages = ConcatMap<int, String>((id) async* {
///   final doc = await fetchDocument(id);
///   for (final page in doc.pages) {
///     yield 'Page $page';
///   }
/// }).toHandle(source: docIds.cell);
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
///   and returns an inner sequence (Stream, Future, Iterable, or value).
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload from the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ConcatMapTo]: For flattening the same inner sequence every trigger.
/// - [ConcatAll]: For when the payload itself is the inner sequence.
/// - [ConcatMapLatest]: For latest-only flattening.
/// - [ConcatMapFirst]: For first-wins flattening.
/// - [AsyncExpand]: For a similar operator in the async expansion family.
class ConcatMap<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [ConcatMap] instruction with the specified [mapper].
  ///
  /// ### Parameters:
  /// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
  ///   and returns an inner sequence (Stream, Future, Iterable, or value).
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final concatMap = ConcatMap<String, String>(
  ///   (id) async* {
  ///     yield '$id:step-1';
  ///     yield '$id:step-2';
  ///   },
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
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
// ConcatMapTo
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that flattens the same inner sequence after every
/// trigger (Rx `concatMapTo`).
///
/// [ConcatMapTo] acts as a **Sequential Reusable Flattener**. Unlike
/// [ConcatMap], it ignores the trigger payload and flattens the same inner
/// sequence for every trigger. Each sequence must complete before the next
/// starts.
///
/// ### When to use
/// Use [ConcatMapTo] when:
/// - You want to flatten the same sequence for every trigger
/// - The trigger payload is irrelevant to the flattening
/// - You're implementing a repeated workflow
/// - You're polling the same data source repeatedly
/// - You're implementing a heartbeat or ping-pong pattern
///
/// ### How it works
/// 1. Each trigger pulse (regardless of payload) starts the same inner sequence.
/// 2. The [inner] function is called to produce the sequence.
/// 3. The sequence is drained, emitting each item as a [Pulse].
/// 4. The next trigger is queued and only starts when the current sequence completes.
/// 5. Results are emitted in input order (FIFO).
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Payload Ignored**: The trigger payload is ignored. Only the trigger
///   count matters.
/// - **Same Sequence**: The same inner sequence is flattened for every trigger.
/// - **Strict Sequencing**: The instruction processes inputs one at a time.
///   Each sequence must complete before the next starts.
/// - **Error Handling**: Errors in the [inner] function or during draining
///   are reported via [onError].
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Ping-Pong
/// ```dart
/// final clicks = Cell.ingress<void>();
/// final echo = ConcatMapTo<void, String>(() async* {
///   yield 'ping';
///   yield 'pong';
/// }).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // -> ping, pong
/// clicks.emit(null); // -> ping, pong (again)
/// ```
///
/// ### Example: Heartbeat
/// ```dart
/// final triggers = Cell.ingress<void>();
/// final heartbeat = ConcatMapTo<void, String>(() async* {
///   await Future.delayed(Duration(seconds: 1));
///   yield 'heartbeat';
/// }).toHandle(source: triggers.cell);
/// ```
///
/// ### Parameters:
/// - [inner]: **The Sequence Factory.** Returns the inner sequence to flatten.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload (ignored).
/// - [T]: The type of the output payload from the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ConcatMap]: For per-trigger sequences.
/// - [ConcatAll]: For when the payload itself is the inner sequence.
class ConcatMapTo<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [ConcatMapTo] instruction with the specified [inner].
  ///
  /// ### Parameters:
  /// - [inner]: **The Sequence Factory.** Returns the inner sequence to flatten.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final concatMapTo = ConcatMapTo<void, String>(
  ///   () async* { yield 'ping'; yield 'pong'; },
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
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
// ConcatAll
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that flattens the payload itself as the inner
/// sequence (Rx `concatAll`).
///
/// [ConcatAll] acts as a **Payload Flattener**. It treats the incoming
/// pulse's payload as the inner sequence (Stream, Future, Iterable, or value)
/// and flattens it. Each sequence must complete before the next starts.
///
/// ### When to use
/// Use [ConcatAll] when:
/// - The payload itself is the sequence to flatten
/// - You're receiving lists or streams as payloads
/// - You're implementing batch processing
/// - You're unrolling nested structures
/// - You're processing paginated results
///
/// ### How it works
/// 1. Each trigger pulse's payload is extracted.
/// 2. The payload is treated as an inner sequence.
/// 3. The sequence is drained, emitting each item as a [Pulse].
/// 4. The next trigger is queued and only starts when the current sequence completes.
/// 5. Results are emitted in input order (FIFO).
/// 6. The instruction preserves causal provenance.
///
/// ### Supported Payload Types
/// The payload can be any of the following:
/// - **[Stream\<T\>]**: Each event in the stream is emitted sequentially.
/// - **[Future\<T\>]**: The single value is emitted when the future completes.
/// - **[Iterable\<T\>]**: Each element is emitted in order.
/// - **[T]**: The value itself is emitted directly.
/// - **`null`**: No emission (the pulse is dropped).
/// - **Nested combinations**: `Future<Iterable<T>>`, `Stream<Future<T>>`,
///   etc., are recursively expanded.
///
/// ### Non‑obvious
/// - **Payload as Source**: The payload itself is the source of the emissions.
/// - **Strict Sequencing**: The instruction processes inputs one at a time.
///   Each sequence must complete before the next starts.
/// - **Type Safety**: The instruction is generic over [T] (output type).
/// - **Error Handling**: Errors during draining are reported via [onError].
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Batch Processing
/// ```dart
/// final batches = Cell.ingress<List<String>>();
/// final flat = ConcatAll<String>().toHandle(source: batches.cell);
///
/// batches.emit(['a', 'b']); // -> a, b
/// batches.emit(['c']);     // -> c
/// ```
///
/// ### Example: Pagination
/// ```dart
/// final pages = Cell.ingress<Stream<String>>();
/// final flat = ConcatAll<String>().toHandle(source: pages.cell);
/// ```
///
/// ### Parameters:
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [T]: The type of the output payload from the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ConcatMap]: For mapping payloads to sequences.
/// - [ConcatMapTo]: For the same sequence every trigger.
class ConcatAll<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [ConcatAll] instruction.
  ///
  /// ### Parameters:
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final concatAll = ConcatAll<String>(
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  ConcatAll({
    FlattenErrorHandler? onError,
    dynamic user,
  }) : super.future(
    (() {
      final queue = _ConcatQueue();
      return (pulse, {cell, user, future, token}) {
        queue.enqueue(() async {
          try {
            await _drain(pulse.payload, (value) {
              if (value is T) {
                future!(
                  result: _out<T>(value, cell, pulse, 'ConcatAll'),
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
// ConcatMapLatest
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that flattens only the latest inner sequence
/// (Rx `switchMap` semantics, concatMap naming).
///
/// [ConcatMapLatest] acts as a **Latest-Only Flattener**. A new trigger
/// cancels emission from the previous inner sequence. Only the most recent
/// sequence's items are emitted.
///
/// ### When to use
/// Use [ConcatMapLatest] when:
/// - **Search-as-you-type**: Only the latest search query matters
/// - **Real-time Filtering**: Only the most recent filter applies
/// - **Navigation**: Only the latest route matters
/// - **Form Validation**: Only the latest input should be validated
/// - **Live Updates**: Only the most recent update is relevant
/// - **Selection Changes**: Only the latest selection should be processed
/// - **Tab Switching**: Only the latest tab's data should be loaded
///
/// ### How it works
/// 1. Each trigger pulse starts a new inner sequence with a unique ID.
/// 2. If a new trigger arrives while a sequence is in flight, the previous
///    sequence's ID is marked as stale.
/// 3. Only the sequence with the current ID can emit results.
/// 4. Stale sequences' items are silently dropped.
/// 5. Results are emitted only from the latest sequence.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Silent Cancellation**: Cancelled sequences do not throw exceptions.
///   They simply don't emit results.
/// - **Generation ID Tracking**: Each sequence gets a unique ID. Only the
///   sequence with the current ID can emit.
/// - **Memory Safety**: The state only holds the current generation ID.
/// - **Error Handling**: Only errors from the latest sequence are reported.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Search-as-you-Type
/// ```dart
/// final searchInput = Cell.ingress<String>();
/// final results = ConcatMapLatest<String, String>((query) async* {
///   await Future.delayed(Duration(milliseconds: 100));
///   yield 'Results for: $query';
/// }).toHandle(source: searchInput.cell);
///
/// searchInput.emit('h'); // Starts search for 'h'
/// searchInput.emit('he'); // Cancels 'h', starts 'he'
/// searchInput.emit('hel'); // Cancels 'he', starts 'hel'
/// // Only the result for 'hel' is emitted
/// ```
///
/// ### Example: User Profile Switching
/// ```dart
/// final userIds = Cell.ingress<int>();
/// final profile = ConcatMapLatest<int, Profile>((id) async* {
///   final user = await fetchUser(id);
///   yield user;
/// }).toHandle(source: userIds.cell);
///
/// userIds.emit(1); // Starts loading user 1
/// userIds.emit(2); // Cancels user 1, loads user 2
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
///   and returns an inner sequence.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload from the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ConcatMap]: For sequential flattening.
/// - [ConcatMapFirst]: For first-wins flattening.
/// - [AsyncMapLatest]: For latest-only async mapping.
class ConcatMapLatest<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [ConcatMapLatest] instruction with the specified [mapper].
  ///
  /// ### Parameters:
  /// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
  ///   and returns an inner sequence.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final concatMapLatest = ConcatMapLatest<String, String>(
  ///   (q) async* { yield 'Result: $q'; },
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
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
// ConcatMapFirst
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that flattens only the first inner sequence
/// (Rx `exhaustMap` semantics, concatMap naming).
///
/// [ConcatMapFirst] acts as a **First-Wins Flattener**. Triggers that arrive
/// while an inner sequence is running are dropped. Only the first sequence
/// is processed until it completes.
///
/// ### When to use
/// Use [ConcatMapFirst] when:
/// - **Submit/Save Buttons**: Prevent double-submission
/// - **Form Submission**: Prevent duplicate form submissions
/// - **Idempotent Operations**: Operations that should only run once at a time
/// - **Rate Limiting**: You want to limit the rate of operations
/// - **Resource Protection**: You want to prevent resource exhaustion
/// - **Button Click Prevention**: Prevent double-click issues
/// - **Throttling User Actions**: Only process the first action
///
/// ### How it works
/// 1. The first trigger starts an inner sequence.
/// 2. While the sequence is in flight, all subsequent triggers are dropped.
/// 3. When the sequence completes, the instruction is ready for the next trigger.
/// 4. Results are emitted from the first sequence.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Drop While Busy**: Triggers while busy are silently dropped.
/// - **One at a Time**: Only one sequence can be in flight at a time.
/// - **Error Handling**: Errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Button Click Protection
/// ```dart
/// final clicks = Cell.ingress<void>();
/// final submit = ConcatMapFirst<void, String>((_) async* {
///   await submitForm();
///   yield 'Submitted!';
/// }).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // Starts submission
/// clicks.emit(null); // Dropped (busy)
/// clicks.emit(null); // Dropped (busy)
/// // Only the first submission is processed
/// ```
///
/// ### Example: File Upload
/// ```dart
/// final uploads = Cell.ingress<File>();
/// final uploadStatus = ConcatMapFirst<File, String>((file) async* {
///   yield 'Uploading ${file.name}...';
///   await uploadFile(file);
///   yield 'Upload complete!';
/// }).toHandle(source: uploads.cell);
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
///   and returns an inner sequence.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload from the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ConcatMap]: For sequential flattening.
/// - [ConcatMapLatest]: For latest-only flattening.
/// - [ExhaustFromFuture]: For exhaust future mapping.
class ConcatMapFirst<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [ConcatMapFirst] instruction with the specified [mapper].
  ///
  /// ### Parameters:
  /// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
  ///   and returns an inner sequence.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final concatMapFirst = ConcatMapFirst<int, String>(
  ///   (n) async* { yield '$n processed'; },
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
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

/// Internal state for [ConcatMap] and [ConcatMapTo].
class _ConcatQueue {
  Future<void> tail = Future<void>.value();

  void enqueue(Future<void> Function() job) {
    tail = tail.then((_) => job()).catchError((_) {});
  }
}

/// Internal state for [ConcatMapLatest].
class _GenerationState {
  int generation = 0;
}

/// Internal state for [ConcatMapFirst].
class _BusyState {
  bool busy = false;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [ConcatMap] instruction and related operators
/// showing their behavior in various flattening scenarios.
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
/// 3. ConcatAll - Payload is the inner list
///    [ConcatAll] a
///    [ConcatAll] b
///    [ConcatAll] c
///
/// 4. ConcatMapLatest - Latest inner only
///    [ConcatMapLatest] new-1
///    [ConcatMapLatest] new-2
///
/// 5. ConcatMapFirst - Ignore while busy
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
/// 1. **ConcatMap - Sequential lifecycle**: Shows sequential flattening.
///    Each order emits two states (created, paid) in order. ORD-1 completes
///    before ORD-2 starts (concat / sequential).
///
/// 2. **ConcatMapTo - Same inner every trigger**: Shows the same sequence
///    being flattened for every trigger. The trigger payload is ignored.
///
/// 3. **ConcatAll - Payload is the inner list**: Shows the payload itself
///    being treated as the inner sequence. Lists are flattened into
///    individual items.
///
/// 4. **ConcatMapLatest - Latest inner only**: Shows cancellation behavior.
///    Only the last sequence's items are emitted; previous sequences are
///    silently cancelled.
///
/// 5. **ConcatMapFirst - Ignore while busy**: Shows exhaust behavior.
///    Only the first sequence is processed; subsequent triggers are ignored
///    while busy.
///
/// ### Key Takeaways
/// - All concatMap operators preserve input order (FIFO).
/// - ConcatMap processes sequences sequentially.
/// - ConcatMapTo ignores the trigger payload.
/// - ConcatAll treats the payload as the sequence.
/// - ConcatMapLatest cancels previous sequences for the latest.
/// - ConcatMapFirst drops triggers while busy.
/// - All operators preserve causal provenance via EvolvedPulse.
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

  print('3. ConcatAll - Payload is the inner list');
  final batches = Cell.ingress<List<String>>();
  final flat = ConcatAll<String>().toHandle(source: batches.cell);
  final flatObs = Cell.observe(
    source: flat.cell,
    effect: (Pulse p) => print('   [ConcatAll] ${p.payload}'),
  );
  await batches.emitAsync(['a', 'b']);
  await batches.emitAsync(['c']);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  flatObs.stop();
  print('');

  print('4. ConcatMapLatest - Latest inner only');
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

  print('5. ConcatMapFirst - Ignore while busy');
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