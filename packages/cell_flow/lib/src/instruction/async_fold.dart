// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core AsyncFold Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that accumulate with an async reducer
/// (Rx `reduce` / async `scan` family).
///
/// A Cell does not complete, so these emit the **running** fold after
/// each successful step (async `scan`), not a single terminal value.
///
/// | Operator | Seed | Concurrency |
/// |---|---|---|
/// | [AsyncFold] | required | queue (concat) |
/// | [AsyncReduce] | first value | queue |
/// | [AsyncFoldLatest] | required | new value drops in-flight step |
/// | [AsyncFoldExhaust] | required | drop while a step is running |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for asyncFold operators.
///
/// Called when an error occurs during accumulation.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = FoldErrorHandler((error, stack) {
///   print('AsyncFold error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef FoldErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// An asynchronous accumulation function.
///
/// Takes the current accumulator value and the next input value,
/// returns a `FutureOr<A>` representing the new accumulator value.
///
/// ### Example
/// ```dart
/// final accumulator = AsyncAccumulator<int, int>((acc, n) async {
///   return acc + n;
/// });
/// ```
typedef AsyncAccumulator<A, S> = FutureOr<A> Function(A acc, S value);

/// Helper to create an output pulse with proper provenance.
Pulse<A> _out<A>(A value, Pulse trigger, Cell? cell, String step) {
  return Pulse<A>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// Snapshot of the current fold state.
///
/// [FoldSnapshot] holds the current accumulator value and a generation
/// counter that increments on each successful update.
///
/// ### When to use
/// Use [FoldSnapshot] to access the current state of an async fold
/// operation from outside the instruction.
///
/// ### How it works
/// 1. [value] is the current accumulator value.
/// 2. [generation] increments on each successful update.
/// 3. The snapshot is shared between the instruction and external code.
///
/// ### Non‑obvious
/// - **Volatile**: The snapshot is in-memory only, not persisted.
/// - **Shared**: The snapshot is mutable and shared with the instruction.
/// - **Generation**: The generation counter helps detect updates.
///
/// ### Example: Inspecting State
/// ```dart
/// final snapshot = FoldSnapshot<int>(0);
/// final fold = AsyncFold<int, int>(
///   0,
///   (acc, n) async => acc + n,
///   snapshot: snapshot,
/// ).toHandle(source: input.cell);
///
/// // Later, inspect the state
/// print('Current sum: ${snapshot.value}');
/// print('Updates: ${snapshot.generation}');
/// ```
///
/// ### Type Parameters:
/// - [A]: The type of the accumulator value.
///
/// ### See Also:
/// - [AsyncFold]: The operator that uses this snapshot.
/// - [AsyncFoldLatest]: The latest-only variant.
/// - [AsyncFoldExhaust]: The exhaust variant.
class FoldSnapshot<A> {
  /// Creates a snapshot with an initial [value].
  FoldSnapshot(this.value);

  /// The current accumulator value.
  A value;

  /// The number of successful updates.
  int generation = 0;
}

// ─────────────────────────────────────────────────────────────
// AsyncFold - Seeded Async Scan
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that accumulates values asynchronously with
/// a seed, running steps one after another (async `scan`).
///
/// [AsyncFold] is the foundational asynchronous fold operator. It
/// maintains an accumulator that is updated by an async function
/// for each input, processing inputs sequentially.
///
/// ### When to use
/// Use [AsyncFold] when you need to maintain state across values
/// with asynchronous updates.
///
/// - **Running Totals**: Summing values as they arrive.
/// - **String Concatenation**: Building strings incrementally.
/// - **State Aggregation**: Aggregating state from async operations.
/// - **Data Processing**: Processing data with async transformations.
/// - **Caching**: Maintaining a cache with async updates.
/// - **Batch Processing**: Processing batches with async logic.
///
/// ### Choosing Between AsyncFold Variants
/// - **Use [AsyncFold]** for **Sequential**: When order matters and
///   steps must run one after another.
/// - **Use [AsyncReduce]** for **No Seed**: When the first value is
///   the seed.
/// - **Use [AsyncFoldLatest]** for **Latest Only**: When you only
///   care about the most recent accumulation.
/// - **Use [AsyncFoldExhaust]** for **Exhaust**: When you want to
///   ignore new triggers while busy.
///
/// ### Comparison with Other Operators
/// | Operator | Seed | Concurrency | Cancels | Emits |
/// |----------|------|-------------|---------|-------|
/// | **AsyncFold** | Required | 1 (sequential) | No | Each update |
/// | **AsyncReduce** | First value | 1 (sequential) | No | Each update |
/// | **AsyncFoldLatest** | Required | 1 (latest only) | Yes | Each update |
/// | **AsyncFoldExhaust** | Required | 1 (drop busy) | No | Each update |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. The [accumulate] function is called with the current accumulator
///    and the payload.
/// 3. The new accumulator value is stored in the snapshot.
/// 4. The new value is emitted.
/// 5. Steps are processed sequentially (queue).
/// 6. If [accumulate] throws an error, it's reported and the instruction
///    continues with the next input.
/// 7. Each emitted value gets the step `'AsyncFold'` for provenance.
///
/// ### Non‑obvious
/// - **Sequential Processing**: Steps run one after another.
/// - **Queueing**: Inputs are queued while processing.
/// - **No Cancellation**: Previous operations are not cancelled.
/// - **Error Isolation**: Errors don't stop the queue.
/// - **Snapshot Access**: The snapshot can be read externally.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Example: Running Sum
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final sum = AsyncFold<int, int>(
///   0,
///   (acc, n) async => acc + n,
/// ).toHandle(source: input.cell);
///
/// input.emit(5);  // -> 5
/// input.emit(3);  // -> 8
/// input.emit(7);  // -> 15
/// ```
///
/// ### Example: String Concatenation
/// ```dart
/// final words = Cell.ingress<String>();
///
/// final sentence = AsyncFold<String, String>(
///   '',
///   (acc, word) async => acc.isEmpty ? word : '$acc $word',
/// ).toHandle(source: words.cell);
///
/// words.emit('Hello');   // -> Hello
/// words.emit('World');   // -> Hello World
/// ```
///
/// ### Parameters:
/// - [seed]: **Initial State.** The starting accumulator value.
/// - [accumulate]: **Accumulation Function.** Called with the current
///   accumulator and the payload, returns the new accumulator.
/// - [snapshot]: **Shared Snapshot.** Optional. Creates a new one if
///   not provided.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [A]: The type of the accumulator and output payload.
///
/// ### Returns:
/// A [FlowInstruction] that accumulates values asynchronously.
///
/// ### See Also:
/// - [AsyncReduce]: For seedless accumulation.
/// - [AsyncFoldLatest]: For latest-only accumulation.
/// - [AsyncFoldExhaust]: For exhaust accumulation.
/// - [Reduce]: For synchronous accumulation.
class AsyncFold<S, A> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncFold(
      A seed,
      AsyncAccumulator<A, S> accumulate, {
        FoldSnapshot<A>? snapshot,
        FoldErrorHandler? onError,
        dynamic user,
      }) : this._(accumulate, snapshot ?? FoldSnapshot<A>(seed), onError, user);

  AsyncFold._(
      AsyncAccumulator<A, S> accumulate,
      this.snapshot,
      FoldErrorHandler? onError,
      dynamic user,
      ) : super.future(
    (() {
      final snap = snapshot;
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
              snap.value = await Future<A>.sync(
                    () => accumulate(snap.value, next),
              );
              snap.generation++;
              future!(
                result: _out<A>(snap.value, pulse, cell, 'AsyncFold'),
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

  /// The shared snapshot containing the current state.
  ///
  /// Use this to access the [value] and [generation] from outside
  /// the instruction.
  final FoldSnapshot<A> snapshot;
}

// ─────────────────────────────────────────────────────────────
// AsyncReduce - Seedless Async Scan
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that uses the first typed value as the seed,
/// then accumulates subsequent values asynchronously.
///
/// [AsyncReduce] is similar to [AsyncFold] but the seed is the first
/// value, not a separate seed parameter.
///
/// ### When to use
/// Use [AsyncReduce] when you want the first value to be the seed.
///
/// - **Running Totals**: Summing values as they arrive (no explicit seed).
/// - **First Value**: Using the first value as the starting point.
/// - **Data Processing**: Processing data with async transformations.
/// - **State Aggregation**: Aggregating state from async operations.
/// - **Reduction**: Reducing a sequence of values.
///
/// ### Example: Running Sum (No Seed)
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final sum = AsyncReduce<int>(
///   (acc, n) async => acc + n,
/// ).toHandle(source: input.cell);
///
/// input.emit(5);  // -> 5 (seed)
/// input.emit(3);  // -> 8
/// input.emit(7);  // -> 15
/// ```
///
/// ### How it works
/// 1. The first typed pulse becomes the seed and is emitted immediately.
/// 2. Subsequent pulses are accumulated using the [accumulate] function.
/// 3. Steps are processed sequentially (queue).
/// 4. If [accumulate] throws an error, it's reported and the instruction
///    continues with the next input.
/// 5. Each emitted value gets the step `'AsyncReduce'` (or `'AsyncReduce.seed'`
///    for the first value) for provenance.
///
/// ### Non‑obvious
/// - **First Value as Seed**: The first value is emitted as the seed.
/// - **No Seed Parameter**: No explicit seed is required.
/// - **Sequential Processing**: Steps run one after another.
/// - **Queueing**: Inputs are queued while processing.
/// - **Error Isolation**: Errors don't stop the queue.
/// - **Provenance Preservation**: The seed emission gets the step
///   `'AsyncReduce.seed'` to distinguish it from accumulated values.
///
/// ### Parameters:
/// - [accumulate]: **Accumulation Function.** Called with the current
///   accumulator and the payload, returns the new accumulator.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input and output payload.
///
/// ### Returns:
/// A [FlowInstruction] that accumulates values asynchronously.
///
/// ### See Also:
/// - [AsyncFold]: For seeded accumulation.
/// - [AsyncFoldLatest]: For latest-only accumulation.
/// - [AsyncFoldExhaust]: For exhaust accumulation.
/// - [Reduce]: For synchronous accumulation.
class AsyncReduce<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncReduce(
      FutureOr<S> Function(S acc, S value) accumulate, {
        FoldErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      S? acc;
      var has = false;
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
            if (!has) {
              has = true;
              acc = next;
              future!(
                result: _out<S>(next, pulse, cell, 'AsyncReduce.seed'),
                token: token,
              );
              continue;
            }
            try {
              acc = await Future<S>.sync(() => accumulate(acc as S, next));
              future!(
                result: _out<S>(acc as S, pulse, cell, 'AsyncReduce'),
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
// AsyncFoldLatest - Latest-Only Async Fold
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that accumulates values asynchronously,
/// cancelling in-flight accumulation when a new value arrives.
///
/// [AsyncFoldLatest] only updates the accumulator with the latest
/// value. Previous in-flight accumulation steps are cancelled.
///
/// ### When to use
/// Use [AsyncFoldLatest] when you only care about the latest
/// accumulation result.
///
/// - **Real-time Updates**: Only the latest update matters.
/// - **User Input**: Only the latest user input matters.
/// - **Fast-Changing Data**: When data changes faster than processing.
/// - **Search-as-you-type**: Only the latest search query matters.
/// - **UI State**: Only the latest UI state matters.
///
/// ### Example: Latest-Only Sum
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final sum = AsyncFoldLatest<int, int>(
///   0,
///   (acc, n) async {
///     await Future.delayed(Duration(milliseconds: 50));
///     return acc + n;
///   },
/// ).toHandle(source: input.cell);
///
/// input.emit(1); // Starts processing
/// input.emit(2); // Cancels previous, starts new
/// // Only the result from 2 is emitted
/// ```
///
/// ### How it works
/// 1. Each incoming pulse triggers the [accumulate] function.
/// 2. A new generation ID is assigned to each trigger.
/// 3. Any previous in-flight accumulation is cancelled.
/// 4. Only the result from the latest generation is emitted.
/// 5. The snapshot is updated only for the latest generation.
/// 6. If [accumulate] throws an error, it's reported only for the
///    current generation.
/// 7. Each emitted value gets the step `'AsyncFoldLatest'` for provenance.
///
/// ### Non‑obvious
/// - **Generation Tracking**: Each operation gets a unique ID.
/// - **Silent Cancellation**: Cancelled operations don't emit errors.
/// - **Latest Only**: Only the most recent operation emits values.
/// - **Error Isolation**: Only errors from the current generation are
///   reported.
/// - **Snapshot Update**: The snapshot is only updated for the latest
///   generation.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [seed]: **Initial State.** The starting accumulator value.
/// - [accumulate]: **Accumulation Function.** Called with the current
///   accumulator and the payload, returns the new accumulator.
/// - [snapshot]: **Shared Snapshot.** Optional. Creates a new one if
///   not provided.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [A]: The type of the accumulator and output payload.
///
/// ### Returns:
/// A [FlowInstruction] that accumulates latest-only values.
///
/// ### See Also:
/// - [AsyncFold]: For sequential accumulation.
/// - [AsyncReduce]: For seedless accumulation.
/// - [AsyncFoldExhaust]: For exhaust accumulation.
/// - [AsyncFoldLatest]: The latest-only variant.
class AsyncFoldLatest<S, A> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncFoldLatest(
      A seed,
      AsyncAccumulator<A, S> accumulate, {
        FoldSnapshot<A>? snapshot,
        FoldErrorHandler? onError,
        dynamic user,
      }) : this._(accumulate, snapshot ?? FoldSnapshot<A>(seed), onError, user);

  AsyncFoldLatest._(
      AsyncAccumulator<A, S> accumulate,
      this.snapshot,
      FoldErrorHandler? onError,
      dynamic user,
      ) : super.future(
    (() {
      final snap = snapshot;
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
        final base = snap.value;
        Future<void> run() async {
          try {
            final next = await Future<A>.sync(() => accumulate(base, payload));
            if (id != generation) return;
            snap.value = next;
            snap.generation++;
            future!(
              result: _out<A>(next, pulse, cell, 'AsyncFoldLatest'),
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

  /// The shared snapshot containing the current state.
  ///
  /// Use this to access the [value] and [generation] from outside
  /// the instruction.
  final FoldSnapshot<A> snapshot;
}

// ─────────────────────────────────────────────────────────────
// AsyncFoldExhaust - Exhaust Async Fold
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that accumulates values asynchronously,
/// ignoring source pulses while a step is running.
///
/// [AsyncFoldExhaust] drops new triggers while an accumulation step
/// is still running. This prevents overlapping accumulation.
///
/// ### When to use
/// Use [AsyncFoldExhaust] when you want to ignore new inputs while
/// processing.
///
/// - **Rate Limiting**: Ignoring rapid inputs while processing.
/// - **Debouncing**: Ignoring inputs during processing.
/// - **Resource Protection**: Preventing resource exhaustion.
/// - **Single Operation**: Ensuring only one operation runs at a time.
/// - **Throttling**: Throttling inputs while busy.
///
/// ### Example: Rate-Limited Accumulation
/// ```dart
/// final input = Cell.ingress<int>();
///
/// final sum = AsyncFoldExhaust<int, int>(
///   0,
///   (acc, n) async {
///     await Future.delayed(Duration(milliseconds: 50));
///     return acc + n;
///   },
/// ).toHandle(source: input.cell);
///
/// input.emit(1); // Starts processing
/// input.emit(2); // Ignored (busy)
/// input.emit(3); // Ignored (busy)
/// // Only 1 is accumulated
/// ```
///
/// ### How it works
/// 1. The first incoming pulse triggers the [accumulate] function.
/// 2. While the accumulation is running, new triggers are dropped.
/// 3. When the accumulation completes, the next trigger is accepted.
/// 4. The snapshot is updated on each successful accumulation.
/// 5. If [accumulate] throws an error, the busy flag is cleared.
/// 6. Each emitted value gets the step `'AsyncFoldExhaust'` for provenance.
///
/// ### Non‑obvious
/// - **Dropping**: New triggers are silently dropped while busy.
/// - **Single Operation**: Only one accumulation runs at a time.
/// - **No Queuing**: No queuing; dropped triggers are lost.
/// - **Error Clearing**: Errors clear the busy flag.
/// - **Snapshot Update**: The snapshot is updated on each successful
///   accumulation.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Drop First**: The first trigger is always processed.
///
/// ### Parameters:
/// - [seed]: **Initial State.** The starting accumulator value.
/// - [accumulate]: **Accumulation Function.** Called with the current
///   accumulator and the payload, returns the new accumulator.
/// - [snapshot]: **Shared Snapshot.** Optional. Creates a new one if
///   not provided.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [A]: The type of the accumulator and output payload.
///
/// ### Returns:
/// A [FlowInstruction] that accumulates with exhaust behavior.
///
/// ### See Also:
/// - [AsyncFold]: For sequential accumulation.
/// - [AsyncReduce]: For seedless accumulation.
/// - [AsyncFoldLatest]: For latest-only accumulation.
/// - [AsyncFoldExhaust]: The exhaust variant.
class AsyncFoldExhaust<S, A> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncFoldExhaust(
      A seed,
      AsyncAccumulator<A, S> accumulate, {
        FoldSnapshot<A>? snapshot,
        FoldErrorHandler? onError,
        dynamic user,
      }) : this._(accumulate, snapshot ?? FoldSnapshot<A>(seed), onError, user);

  AsyncFoldExhaust._(
      AsyncAccumulator<A, S> accumulate,
      this.snapshot,
      FoldErrorHandler? onError,
      dynamic user,
      ) : super.future(
    (() {
      final snap = snapshot;
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
            snap.value = await Future<A>.sync(
                  () => accumulate(snap.value, payload),
            );
            snap.generation++;
            future!(
              result: _out<A>(snap.value, pulse, cell, 'AsyncFoldExhaust'),
              token: token,
            );
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

  /// The shared snapshot containing the current state.
  ///
  /// Use this to access the [value] and [generation] from outside
  /// the instruction.
  final FoldSnapshot<A> snapshot;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [AsyncFold] instruction and related operators
/// showing their behavior in various asynchronous accumulation scenarios.
///
/// ### Expected console output:
/// ```text
/// ── AsyncFold Operators Demo ──────────────────────────────────
///
/// 1. AsyncFold
///    [AsyncFold] 1
///    [AsyncFold] 3
///
/// 2. AsyncReduce
///    [AsyncReduce] 1
///    [AsyncReduce] 3
///
/// 3. AsyncFoldLatest
///    [AsyncFoldLatest] 20
///
/// 4. AsyncFoldExhaust
///    [AsyncFoldExhaust] 1
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
/// 1. **AsyncFold - Seeded Accumulation**: Shows seeded async
///    accumulation where values are added sequentially. The seed is
///    0, and values 1 and 2 produce 1 and 3.
///
/// 2. **AsyncReduce - Seedless Accumulation**: Shows seedless async
///    accumulation where the first value (1) becomes the seed and is
///    emitted immediately. The second value (2) is added to produce 3.
///
/// 3. **AsyncFoldLatest - Latest Only**: Shows latest-only async
///    accumulation where the first value (1) is cancelled by the
///    second value (2). Only the result from the latest value is
///    emitted. The accumulation multiplies by 10, so 2 produces 20.
///
/// 4. **AsyncFoldExhaust - Exhaust Accumulation**: Shows exhaust
///    async accumulation where the second value (9) is dropped while
///    the first value (1) is still processing. Only 1 is accumulated.
///
/// ### Key Takeaways
/// - AsyncFold processes sequentially with queuing.
/// - AsyncReduce uses the first value as the seed.
/// - AsyncFoldLatest cancels in-flight accumulation.
/// - AsyncFoldExhaust drops new triggers while busy.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Snapshots provide external access to the current state.
/// - Generation counters track updates.
///
/// ### Note on Strategies
/// The four strategies (concat, seedless, latest, exhaust) cover the
/// common async accumulation patterns. Choose based on your
/// concurrency and ordering requirements.
Future<void> main() async {
  print('── AsyncFold Operators Demo ──────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. AsyncFold - Seeded Accumulation
  // ─────────────────────────────────────────────────────────────────────
  print('1. AsyncFold');

  final nums = Cell.ingress<int>();

  final folded = AsyncFold<int, int>(
    0,
        (acc, n) async => acc + n,
  ).toHandle(source: nums.cell);

  final fObs = Cell.observe(
    source: folded.cell,
    effect: (Pulse p) => print('   [AsyncFold] ${p.payload}'),
  );

  await nums.emitAsync(1);
  await nums.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  fObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. AsyncReduce - Seedless Accumulation
  // ─────────────────────────────────────────────────────────────────────
  print('2. AsyncReduce');

  final seq = Cell.ingress<int>();

  final reduced = AsyncReduce<int>(
        (acc, n) async => acc + n,
  ).toHandle(source: seq.cell);

  final rObs = Cell.observe(
    source: reduced.cell,
    effect: (Pulse p) => print('   [AsyncReduce] ${p.payload}'),
  );

  await seq.emitAsync(1);
  await seq.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  rObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. AsyncFoldLatest - Latest Only
  // ─────────────────────────────────────────────────────────────────────
  print('3. AsyncFoldLatest');

  final latestIn = Cell.ingress<int>();

  final latest = AsyncFoldLatest<int, int>(
    0,
        (acc, n) async {
      await Future<void>.delayed(Duration(milliseconds: n == 1 ? 40 : 5));
      return acc + n * 10;
    },
  ).toHandle(source: latestIn.cell);

  final lObs = Cell.observe(
    source: latest.cell,
    effect: (Pulse p) => print('   [AsyncFoldLatest] ${p.payload}'),
  );

  await latestIn.emitAsync(1);
  await latestIn.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 70));

  lObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. AsyncFoldExhaust - Exhaust Accumulation
  // ─────────────────────────────────────────────────────────────────────
  print('4. AsyncFoldExhaust');

  final clicks = Cell.ingress<int>();

  final exhaust = AsyncFoldExhaust<int, int>(
    0,
        (acc, n) async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return acc + n;
    },
  ).toHandle(source: clicks.cell);

  final eObs = Cell.observe(
    source: exhaust.cell,
    effect: (Pulse p) => print('   [AsyncFoldExhaust] ${p.payload}'),
  );

  await clicks.emitAsync(1);
  await clicks.emitAsync(9);
  await Future<void>.delayed(const Duration(milliseconds: 70));

  eObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}