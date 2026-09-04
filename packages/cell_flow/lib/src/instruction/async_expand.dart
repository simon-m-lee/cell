// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core AsyncExpand Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that flatten an inner sequence per payload
/// (Dart `asyncExpand` / Rx `concatMap` family).
///
/// | Operator | Strategy | Overlap |
/// |---|---|---|
/// | [AsyncExpand] | concat | no — queue |
/// | [AsyncExpandConcurrent] | merge | yes |
/// | [AsyncExpandLatest] | switch | cancel previous |
/// | [AsyncExpandExhaust] | exhaust | drop while busy |
///
/// [expand] may return a [Stream], [Future], [Iterable], raw value, or
/// `null`. Same flattening as `concat_map` / `merge_map` / `switch_map`
/// / `exhaust_map`, under the Dart `asyncExpand` names.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for asyncExpand operators.
///
/// Called when an error occurs during expansion or flattening operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = ExpandErrorHandler((error, stack) {
///   print('AsyncExpand error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef ExpandErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// A function that expands a value into an inner sequence.
///
/// The inner sequence can be any object that can be drained:
/// - `Future<T>`: emits a single value
/// - `Stream<T>`: emits multiple values over time
/// - `Iterable<T>`: emits multiple values synchronously
/// - Any other value: emits that value directly
///
/// ### Example
/// ```dart
/// final expander = Expander<int>((id) async {
///   return await api.fetchUser(id);
/// });
/// ```
typedef Expander<S> = FutureOr<Object?> Function(S value);

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
/// sequences that asyncExpand operators can produce.
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

// ─────────────────────────────────────────────────────────────
// AsyncExpand - Sequential Flattening
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that flattens inner sequences sequentially
/// (Dart `asyncExpand` / Rx `concatMap`).
///
/// [AsyncExpand] processes inputs one at a time, waiting for each
/// inner sequence to complete before starting the next. This ensures
/// strict ordering but may be slower for long-running operations.
///
/// ### When to use
/// Use [AsyncExpand] when you need to preserve order and process
/// operations sequentially.
///
/// - **Order Matters**: When output order must match input order.
/// - **Resource Constraints**: When resources are limited.
/// - **Sequential Processing**: When operations must run one after another.
/// - **Transaction Ordering**: When transactions must be ordered.
/// - **File Processing**: Processing files in order.
/// - **API Calls**: Making sequential API calls.
///
/// ### Choosing Between AsyncExpand Variants
/// - **Use [AsyncExpand]** for **Sequential**: When order matters and
///   operations must run one at a time.
/// - **Use [AsyncExpandConcurrent]** for **Concurrent**: When order
///   doesn't matter and you want parallelism.
/// - **Use [AsyncExpandLatest]** for **Latest Only**: When you only
///   care about the most recent operation.
/// - **Use [AsyncExpandExhaust]** for **Exhaust**: When you want to
///   ignore new triggers while busy.
///
/// ### Comparison with Other Operators
/// | Operator | Order | Cancels | Queues | Concurrency |
/// |----------|-------|---------|--------|-------------|
/// | **AsyncExpand** | Preserved | No | Yes | 1 (sequential) |
/// | **AsyncExpandConcurrent** | Not preserved | No | No | Unlimited |
/// | **AsyncExpandLatest** | N/A | Yes | No | 1 (latest only) |
/// | **AsyncExpandExhaust** | N/A | No | No | 1 (drop busy) |
///
/// ### How it works
/// 1. Each incoming pulse triggers the [expand] function.
/// 2. The inner sequence is drained completely.
/// 3. Only after completion does the next input start.
/// 4. Values are emitted in the order of input.
/// 5. If [expand] throws an error, the error is reported and the
///    instruction continues with the next input.
/// 6. Each emitted value gets the step `'AsyncExpand'` for provenance.
///
/// ### Non‑obvious
/// - **Strict Ordering**: Output order matches input order.
/// - **Queueing**: Inputs are queued while processing.
/// - **No Cancellation**: Previous operations are not cancelled.
/// - **Error Isolation**: Errors don't stop the queue.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Memory Efficient**: Only one inner sequence is in flight.
///
/// ### Example: Sequential API Calls
/// ```dart
/// final ids = Cell.ingress<int>();
///
/// final users = AsyncExpand<int, User>(
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
/// ### Example: Sequential Stream Processing
/// ```dart
/// final items = Cell.ingress<Item>();
///
/// final processed = AsyncExpand<Item, Result>(
///   (item) async* {
///     // Process each item completely before the next
///     yield await processItem(item);
///   },
/// ).toHandle(source: items.cell);
/// ```
///
/// ### Parameters:
/// - [expand]: **Expansion Function.** Takes an input value and returns
///   a `FutureOr<Object?>` that can be drained (Future, Stream, Iterable,
///   or value).
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
/// - [AsyncExpandConcurrent]: For concurrent flattening.
/// - [AsyncExpandLatest]: For latest-only flattening.
/// - [AsyncExpandExhaust]: For exhaust flattening.
/// - [ConcatMap]: The Rx analogue (not yet implemented).
class AsyncExpand<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncExpand(
      Expander<S> expand, {
        ExpandErrorHandler? onError,
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
              final inner = await Future.sync(() => expand(next));
              await _drain(inner, (item) {
                if (item is T) {
                  future!(
                    result: _out<T>(item, cell, pulse, 'AsyncExpand'),
                    token: token,
                  );
                }
              });
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
// AsyncExpandConcurrent - Concurrent Flattening
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that flattens inner sequences concurrently
/// (Rx `mergeMap`).
///
/// [AsyncExpandConcurrent] processes inputs concurrently, emitting
/// results as they complete. Order is not preserved.
///
/// ### When to use
/// Use [AsyncExpandConcurrent] when you want maximum throughput and
/// order doesn't matter.
///
/// - **Parallel Processing**: Processing multiple items in parallel.
/// - **Throughput**: Maximizing throughput.
/// - **Independent Operations**: When operations are independent.
/// - **Batch Processing**: Processing batches in parallel.
/// - **API Calls**: Making parallel API calls.
/// - **Data Loading**: Loading data from multiple sources.
///
/// ### Example: Parallel API Calls
/// ```dart
/// final ids = Cell.ingress<int>();
///
/// final users = AsyncExpandConcurrent<int, User>(
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
/// ### Example: Parallel Data Loading
/// ```dart
/// final urls = Cell.ingress<String>();
///
/// final data = AsyncExpandConcurrent<String, String>(
///   (url) async {
///     final response = await http.get(url);
///     return response.body;
///   },
/// ).toHandle(source: urls.cell);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse triggers the [expand] function immediately.
/// 2. Multiple inner sequences run concurrently.
/// 3. Results are emitted as they complete.
/// 4. Order is not preserved.
/// 5. If [expand] throws an error, it's reported independently.
/// 6. Each emitted value gets the step `'AsyncExpandConcurrent'` for provenance.
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
/// - [expand]: **Expansion Function.** Takes an input value and returns
///   a `FutureOr<Object?>` that can be drained.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that flattens sequences concurrently.
///
/// ### See Also:
/// - [AsyncExpand]: For sequential flattening.
/// - [AsyncExpandLatest]: For latest-only flattening.
/// - [AsyncExpandExhaust]: For exhaust flattening.
/// - [MergeMap]: The Rx analogue.
class AsyncExpandConcurrent<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncExpandConcurrent(
      Expander<S> expand, {
        ExpandErrorHandler? onError,
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
          final inner = await Future.sync(() => expand(payload));
          await _drain(inner, (item) {
            if (item is T) {
              future!(
                result: _out<T>(item, cell, pulse, 'AsyncExpandConcurrent'),
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
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// AsyncExpandLatest - Latest-Only Flattening
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that flattens inner sequences, cancelling
/// previous ones when a new trigger arrives (Rx `switchMap`).
///
/// [AsyncExpandLatest] only emits values from the most recent inner
/// sequence. Previous sequences are cancelled (dropped) when a new
/// trigger arrives.
///
/// ### When to use
/// Use [AsyncExpandLatest] when you only care about the most recent
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
/// final results = AsyncExpandLatest<String, Result>(
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
/// 1. Each incoming pulse triggers the [expand] function.
/// 2. A new generation ID is assigned to each trigger.
/// 3. Any previous inner sequence is cancelled (dropped).
/// 4. Only values from the most recent generation are emitted.
/// 5. If [expand] throws an error, it's reported only for the current
///    generation.
/// 6. Each emitted value gets the step `'AsyncExpandLatest'` for provenance.
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
/// - [expand]: **Expansion Function.** Takes an input value and returns
///   a `FutureOr<Object?>` that can be drained.
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
/// - [AsyncExpand]: For sequential flattening.
/// - [AsyncExpandConcurrent]: For concurrent flattening.
/// - [AsyncExpandExhaust]: For exhaust flattening.
/// - [SwitchMap]: The Rx analogue.
class AsyncExpandLatest<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncExpandLatest(
      Expander<S> expand, {
        ExpandErrorHandler? onError,
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
            final inner = await Future.sync(() => expand(payload));
            if (id != generation) return;
            await _drain(
              inner,
                  (item) {
                if (id != generation) return;
                if (item is T) {
                  future!(
                    result: _out<T>(item, cell, pulse, 'AsyncExpandLatest'),
                    token: token,
                  );
                }
              },
              stillLive: () => id == generation,
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
// AsyncExpandExhaust - Exhaust Flattening
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that flattens inner sequences, ignoring new
/// triggers while an inner is running (Rx `exhaustMap`).
///
/// [AsyncExpandExhaust] ignores (drops) new triggers while an inner
/// sequence is still running. This prevents overlapping operations.
///
/// ### When to use
/// Use [AsyncExpandExhaust] when you want to ignore new inputs while
/// processing.
///
/// - **Rate Limiting**: Ignoring rapid inputs while processing.
/// - **Debouncing**: Ignoring inputs during processing.
/// - **Resource Protection**: Preventing resource exhaustion.
/// - **Single Operation**: Ensuring only one operation runs at a time.
/// - **Throttling**: Throttling inputs while busy.
///
/// ### Example: Rate-Limited Processing
/// ```dart
/// final clicks = Cell.ingress<String>();
///
/// final processed = AsyncExpandExhaust<String, Result>(
///   (input) async {
///     // While this runs, new inputs are ignored
///     await processInput(input);
///     return Result(input);
///   },
/// ).toHandle(source: clicks.cell);
///
/// clicks.emit('first');   // -> Result(first)
/// clicks.emit('second');  // ignored (busy)
/// clicks.emit('third');   // ignored (busy)
/// // Only 'first' is processed
/// ```
///
/// ### How it works
/// 1. The first incoming pulse triggers the [expand] function.
/// 2. While the inner sequence is running, new triggers are dropped.
/// 3. When the inner sequence completes, the next trigger is accepted.
/// 4. If [expand] throws an error, the busy flag is cleared.
/// 5. Each emitted value gets the step `'AsyncExpandExhaust'` for provenance.
///
/// ### Non‑obvious
/// - **Dropping**: New triggers are silently dropped while busy.
/// - **Single Operation**: Only one operation runs at a time.
/// - **No Queuing**: No queuing; dropped triggers are lost.
/// - **Error Clearing**: Errors clear the busy flag.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Drop First**: The first trigger is always processed.
///
/// ### Parameters:
/// - [expand]: **Expansion Function.** Takes an input value and returns
///   a `FutureOr<Object?>` that can be drained.
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
/// - [AsyncExpand]: For sequential flattening.
/// - [AsyncExpandConcurrent]: For concurrent flattening.
/// - [AsyncExpandLatest]: For latest-only flattening.
/// - [ExhaustMap]: The Rx analogue.
class AsyncExpandExhaust<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncExpandExhaust(
      Expander<S> expand, {
        ExpandErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
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
        if (busy) return null;
        busy = true;
        Future<void> run() async {
          try {
            final inner = await Future.sync(() => expand(payload));
            await _drain(inner, (item) {
              if (item is T) {
                future!(
                  result: _out<T>(item, cell, pulse, 'AsyncExpandExhaust'),
                  token: token,
                );
              }
            });
          } catch (e, stack) {
            onError?.call(e, stack);
          } finally {
            busy = false;
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

/// A demonstration of the [AsyncExpand] instruction and related operators
/// showing their behavior in various flattening scenarios.
///
/// ### Expected console output:
/// ```text
/// ── AsyncExpand Operators Demo ────────────────────────────────
///
/// 1. AsyncExpand - sequential
///    [AsyncExpand] a-1
///    [AsyncExpand] a-2
///    [AsyncExpand] b-1
///
/// 2. AsyncExpandConcurrent - completion order
///    [AsyncExpandConcurrent] fast
///    [AsyncExpandConcurrent] slow
///
/// 3. AsyncExpandLatest - drop stale
///    [AsyncExpandLatest] new-1
///
/// 4. AsyncExpandExhaust - ignore while busy
///    [AsyncExpandExhaust] first
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
/// 1. **AsyncExpand - Sequential**: Shows sequential flattening where
///    `a` is fully processed before `b` starts. Output order matches
///    input order.
///
/// 2. **AsyncExpandConcurrent - Completion Order**: Shows concurrent
///    flattening where results are emitted in completion order. The
///    `fast` request completes and emits before the `slow` request,
///    even though `slow` was triggered first.
///
/// 3. **AsyncExpandLatest - Drop Stale**: Shows latest-only flattening
///    where the `old` request is cancelled when `new` arrives. Only
///    `new` emits a value.
///
/// 4. **AsyncExpandExhaust - Ignore While Busy**: Shows exhaust
///    flattening where `ignored` is dropped while `first` is still
///    processing. Only `first` emits a value.
///
/// ### Key Takeaways
/// - AsyncExpand processes sequentially with queuing.
/// - AsyncExpandConcurrent processes in parallel (unordered).
/// - AsyncExpandLatest cancels previous operations.
/// - AsyncExpandExhaust ignores new triggers while busy.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - _drain handles Future, Stream, Iterable, and raw values.
///
/// ### Note on Strategies
/// The four strategies (concat, merge, switch, exhaust) cover the
/// common Rx flattening patterns. Choose based on your ordering
/// and concurrency requirements.
Future<void> main() async {
  print('── AsyncExpand Operators Demo ────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. AsyncExpand - Sequential
  // ─────────────────────────────────────────────────────────────────────
  print('1. AsyncExpand - sequential');

  final letters = Cell.ingress<String>();

  final concat = AsyncExpand<String, String>(
        (s) async* {
      yield '$s-1';
      yield '$s-2';
    },
  ).toHandle(source: letters.cell);

  final cObs = Cell.observe(
    source: concat.cell,
    effect: (Pulse p) => print('   [AsyncExpand] ${p.payload}'),
  );

  await letters.emitAsync('a');
  await letters.emitAsync('b');
  await Future<void>.delayed(const Duration(milliseconds: 20));

  cObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. AsyncExpandConcurrent - Completion Order
  // ─────────────────────────────────────────────────────────────────────
  print('2. AsyncExpandConcurrent - completion order');

  final names = Cell.ingress<String>();

  final merged = AsyncExpandConcurrent<String, String>(
        (name) async {
      await Future<void>.delayed(Duration(milliseconds: name == 'slow' ? 40 : 5));
      return name;
    },
  ).toHandle(source: names.cell);

  final mObs = Cell.observe(
    source: merged.cell,
    effect: (Pulse p) => print('   [AsyncExpandConcurrent] ${p.payload}'),
  );

  await names.emitAsync('slow');
  await names.emitAsync('fast');
  await Future<void>.delayed(const Duration(milliseconds: 70));

  mObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. AsyncExpandLatest - Drop Stale
  // ─────────────────────────────────────────────────────────────────────
  print('3. AsyncExpandLatest - drop stale');

  final query = Cell.ingress<String>();

  final latest = AsyncExpandLatest<String, String>(
        (q) async {
      await Future<void>.delayed(Duration(milliseconds: q == 'old' ? 40 : 8));
      return '$q-1';
    },
  ).toHandle(source: query.cell);

  final lObs = Cell.observe(
    source: latest.cell,
    effect: (Pulse p) => print('   [AsyncExpandLatest] ${p.payload}'),
  );

  await query.emitAsync('old');
  await query.emitAsync('new');
  await Future<void>.delayed(const Duration(milliseconds: 70));

  lObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. AsyncExpandExhaust - Ignore While Busy
  // ─────────────────────────────────────────────────────────────────────
  print('4. AsyncExpandExhaust - ignore while busy');

  final clicks = Cell.ingress<String>();

  final exhaust = AsyncExpandExhaust<String, String>(
        (s) async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return s;
    },
  ).toHandle(source: clicks.cell);

  final eObs = Cell.observe(
    source: exhaust.cell,
    effect: (Pulse p) => print('   [AsyncExpandExhaust] ${p.payload}'),
  );

  await clicks.emitAsync('first');
  await clicks.emitAsync('ignored');
  await Future<void>.delayed(const Duration(milliseconds: 70));

  eObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}